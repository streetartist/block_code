#!/usr/bin/env python3
"""Single-file marketplace server for Block Code custom blocks."""

from __future__ import annotations

import argparse
import hashlib
import hmac
import json
import re
import secrets
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import unquote, urlparse


NAME_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
SAFE_FILE_RE = re.compile(r"[^A-Za-z0-9_\-]+")
USERNAME_RE = re.compile(r"^[A-Za-z0-9_\-]{3,32}$")
BLOCK_TYPES = {"ENTRY", "STATEMENT", "VALUE", "CONTROL"}
VARIANT_TYPES = {
    "BOOL",
    "INT",
    "FLOAT",
    "STRING",
    "STRING_NAME",
    "VECTOR2",
    "VECTOR3",
    "COLOR",
    "NODE_PATH",
    "OBJECT",
    "NIL",
}


def now() -> int:
    return int(time.time())


def safe_file_name(name: str) -> str:
    file_name = SAFE_FILE_RE.sub("_", name.strip().lower())
    return file_name or "custom_block"


def password_hash(password: str, salt: str) -> str:
    digest = hashlib.sha256((salt + password).encode("utf-8")).hexdigest()
    return digest


def public_user(user: dict[str, Any]) -> dict[str, Any]:
    return {
        "username": user["username"],
        "created_at": user.get("created_at", 0),
    }


def normalize_block(payload: dict[str, Any], owner: str) -> dict[str, Any]:
    block_type = str(payload.get("type", "STATEMENT")).strip().upper()
    variant_type = str(payload.get("variant_type", "NIL")).strip().upper()
    if block_type != "VALUE":
        variant_type = "NIL"

    block = {
        "schema_version": int(payload.get("schema_version", 1)),
        "name": str(payload.get("name", "")).strip(),
        "target_node_class": str(payload.get("target_node_class", "")).strip(),
        "description": str(payload.get("description", "")),
        "category": str(payload.get("category", "Custom")).strip(),
        "type": block_type,
        "variant_type": variant_type,
        "display_template": str(payload.get("display_template", "")),
        "code_template": str(payload.get("code_template", "")),
        "defaults": payload.get("defaults", {}),
        "signal_name": str(payload.get("signal_name", "")).strip(),
        "is_advanced": bool(payload.get("is_advanced", False)),
        "owner": owner,
        "updated_at": now(),
    }

    errors: list[str] = []
    if not NAME_RE.match(block["name"]):
        errors.append("name must start with a letter or underscore and contain only letters, numbers, and underscores")
    if not block["category"]:
        errors.append("category is required")
    if block["type"] not in BLOCK_TYPES:
        errors.append("type must be ENTRY, STATEMENT, VALUE, or CONTROL")
    if block["variant_type"] not in VARIANT_TYPES:
        errors.append("variant_type is invalid")
    if not block["display_template"].strip():
        errors.append("display_template is required")
    if not block["code_template"].strip():
        errors.append("code_template is required")
    if not isinstance(block["defaults"], dict):
        errors.append("defaults must be an object")
    if len(block["display_template"]) > 4000:
        errors.append("display_template is too large")
    if len(block["code_template"]) > 30000:
        errors.append("code_template is too large")

    if errors:
        raise ValueError("; ".join(errors))
    return block


class UserStore:
    def __init__(self, data_dir: Path):
        self.path = data_dir / "users.json"
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.users = self._load()

    def _load(self) -> dict[str, dict[str, Any]]:
        if not self.path.exists():
            return {}
        try:
            data = json.loads(self.path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return {}
        if not isinstance(data, dict):
            return {}
        return data

    def _save(self) -> None:
        self.path.write_text(json.dumps(self.users, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    def register(self, username: str, password: str) -> dict[str, Any]:
        username = username.strip()
        if not USERNAME_RE.match(username):
            raise ValueError("username must be 3-32 characters and contain only letters, numbers, underscores, or hyphens")
        if not password:
            raise ValueError("password is required")
        if username in self.users:
            raise ValueError("username already exists")

        salt = secrets.token_hex(16)
        user = {
            "username": username,
            "salt": salt,
            "password_hash": password_hash(password, salt),
            "token": secrets.token_urlsafe(32),
            "created_at": now(),
        }
        self.users[username] = user
        self._save()
        return user

    def login(self, username: str, password: str) -> dict[str, Any]:
        user = self.users.get(username.strip())
        if not user:
            raise ValueError("invalid username or password")
        expected = user.get("password_hash", "")
        actual = password_hash(password, user.get("salt", ""))
        if not hmac.compare_digest(expected, actual):
            raise ValueError("invalid username or password")
        if not user.get("token"):
            user["token"] = secrets.token_urlsafe(32)
            self._save()
        return user

    def authenticate(self, authorization: str | None) -> dict[str, Any] | None:
        if not authorization or not authorization.startswith("Bearer "):
            return None
        token = authorization.removeprefix("Bearer ").strip()
        for user in self.users.values():
            if hmac.compare_digest(str(user.get("token", "")), token):
                return user
        return None


class BlockStore:
    def __init__(self, data_dir: Path):
        self.blocks_dir = data_dir / "blocks"
        self.blocks_dir.mkdir(parents=True, exist_ok=True)

    def path_for(self, name: str) -> Path:
        return self.blocks_dir / f"{safe_file_name(name)}.json"

    def list_blocks(self, owner: str | None = None) -> list[dict[str, Any]]:
        blocks: list[dict[str, Any]] = []
        for path in sorted(self.blocks_dir.glob("*.json")):
            try:
                block = json.loads(path.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                continue
            if owner and block.get("owner") != owner:
                continue
            blocks.append(block)
        return blocks

    def get_block(self, name: str) -> dict[str, Any] | None:
        path = self.path_for(name)
        if not path.exists():
            return None
        try:
            return json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return None

    def save_block(self, payload: dict[str, Any], owner: str) -> dict[str, Any]:
        block = normalize_block(payload, owner)
        existing = self.get_block(block["name"])
        if existing and existing.get("owner") != owner:
            raise PermissionError("a block with this name already belongs to another user")

        if existing and existing.get("created_at"):
            block["created_at"] = existing["created_at"]
        else:
            block["created_at"] = now()

        path = self.path_for(block["name"])
        path.write_text(json.dumps(block, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        return block

    def delete_block(self, name: str, owner: str) -> bool:
        block = self.get_block(name)
        if not block:
            return False
        if block.get("owner") != owner:
            raise PermissionError("only the owner can delete this block")
        self.path_for(name).unlink()
        return True


class BlockCodeHandler(BaseHTTPRequestHandler):
    server_version = "BlockCodeMarket/1.0"

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self._send_cors_headers()
        self.end_headers()

    def do_GET(self) -> None:
        path = urlparse(self.path).path
        if path == "/":
            self._send_html()
            return
        if path == "/api/health":
            self._send_json(200, {"ok": True})
            return
        if path == "/api/me":
            user = self._require_user()
            if not user:
                return
            self._send_json(200, {"user": public_user(user), "username": user["username"]})
            return
        if path == "/api/blocks":
            self._send_json(200, {"blocks": self.server.blocks.list_blocks()})
            return
        if path == "/api/me/blocks":
            user = self._require_user()
            if not user:
                return
            self._send_json(200, {"blocks": self.server.blocks.list_blocks(user["username"])})
            return
        if path.startswith("/api/blocks/"):
            name = unquote(path.removeprefix("/api/blocks/"))
            block = self.server.blocks.get_block(name)
            if block is None:
                self._send_json(404, {"error": "block not found"})
            else:
                self._send_json(200, block)
            return
        self._send_json(404, {"error": "not found"})

    def do_POST(self) -> None:
        path = urlparse(self.path).path
        if path in {"/api/auth/register", "/api/register"}:
            self._handle_register()
            return
        if path in {"/api/auth/login", "/api/login"}:
            self._handle_login()
            return
        if path == "/api/blocks":
            self._handle_block_upload()
            return
        self._send_json(404, {"error": "not found"})

    def do_DELETE(self) -> None:
        path = urlparse(self.path).path
        if not path.startswith("/api/blocks/"):
            self._send_json(404, {"error": "not found"})
            return
        user = self._require_user()
        if not user:
            return

        name = unquote(path.removeprefix("/api/blocks/"))
        try:
            if self.server.blocks.delete_block(name, user["username"]):
                self._send_json(200, {"ok": True})
            else:
                self._send_json(404, {"error": "block not found"})
        except PermissionError as exc:
            self._send_json(403, {"error": str(exc)})

    def log_message(self, fmt: str, *args: Any) -> None:
        if self.server.quiet:
            return
        super().log_message(fmt, *args)

    def _handle_register(self) -> None:
        try:
            payload = self._read_json_body()
            user = self.server.users.register(str(payload.get("username", "")), str(payload.get("password", "")))
        except ValueError as exc:
            self._send_json(400, {"error": str(exc)})
            return
        self._send_json(201, {"ok": True, "username": user["username"], "token": user["token"], "user": public_user(user)})

    def _handle_login(self) -> None:
        try:
            payload = self._read_json_body()
            user = self.server.users.login(str(payload.get("username", "")), str(payload.get("password", "")))
        except ValueError as exc:
            self._send_json(401, {"error": str(exc)})
            return
        self._send_json(200, {"ok": True, "username": user["username"], "token": user["token"], "user": public_user(user)})

    def _handle_block_upload(self) -> None:
        user = self._require_user()
        if not user:
            return
        try:
            payload = self._read_json_body()
            if "block" in payload and isinstance(payload["block"], dict):
                payload = payload["block"]
            block = self.server.blocks.save_block(payload, user["username"])
        except ValueError as exc:
            self._send_json(400, {"error": str(exc)})
            return
        except PermissionError as exc:
            self._send_json(403, {"error": str(exc)})
            return
        except OSError as exc:
            self._send_json(500, {"error": str(exc)})
            return
        self._send_json(201, {"ok": True, "block": block})

    def _require_user(self) -> dict[str, Any] | None:
        user = self.server.users.authenticate(self.headers.get("Authorization"))
        if not user:
            self._send_json(401, {"error": "login required"})
            return None
        return user

    def _read_json_body(self) -> dict[str, Any]:
        length = int(self.headers.get("Content-Length", "0"))
        if length <= 0:
            raise ValueError("request body is required")
        if length > self.server.max_body_bytes:
            raise ValueError("request body is too large")

        raw = self.rfile.read(length)
        try:
            payload = json.loads(raw.decode("utf-8"))
        except json.JSONDecodeError as exc:
            raise ValueError(f"invalid JSON: {exc}") from exc
        if not isinstance(payload, dict):
            raise ValueError("request body must be a JSON object")
        return payload

    def _send_json(self, status: int, payload: dict[str, Any]) -> None:
        body = json.dumps(payload, ensure_ascii=False, indent=2).encode("utf-8")
        self.send_response(status)
        self._send_cors_headers()
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_html(self) -> None:
        html = """<!doctype html>
<meta charset="utf-8">
<title>Block Code Market</title>
<body style="font-family: system-ui, sans-serif; max-width: 760px; margin: 40px auto; line-height: 1.5">
<h1>Block Code Market</h1>
<p>Use this server from the Block Code plugin's Block Market window.</p>
<ul>
<li><code>POST /api/auth/register</code> registers a user and returns a token.</li>
<li><code>POST /api/auth/login</code> logs in and returns a token.</li>
<li><code>GET /api/blocks</code> lists public market blocks.</li>
<li><code>POST /api/blocks</code> uploads a block owned by the logged-in user.</li>
<li><code>GET /api/me/blocks</code> lists the logged-in user's blocks.</li>
</ul>
</body>
"""
        body = html.encode("utf-8")
        self.send_response(200)
        self._send_cors_headers()
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_cors_headers(self) -> None:
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run a Block Code custom block marketplace server.")
    parser.add_argument("--host", default="127.0.0.1", help="Host to bind. Use 0.0.0.0 for LAN access.")
    parser.add_argument("--port", type=int, default=8787, help="TCP port to bind.")
    parser.add_argument("--data-dir", default="block_code_server_data", help="Directory used to persist users and block JSON files.")
    parser.add_argument("--max-body-bytes", type=int, default=1_000_000, help="Maximum upload request size.")
    parser.add_argument("--quiet", action="store_true", help="Disable per-request logs.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    data_dir = Path(args.data_dir)
    server = ThreadingHTTPServer((args.host, args.port), BlockCodeHandler)
    server.users = UserStore(data_dir)
    server.blocks = BlockStore(data_dir)
    server.max_body_bytes = args.max_body_bytes
    server.quiet = args.quiet

    print(f"Block Code market listening on http://{args.host}:{args.port}")
    print(f"Data directory: {data_dir.resolve()}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping server.")
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
