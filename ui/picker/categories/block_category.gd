extends RefCounted

var name: String
var color: Color
var order: int


func _init(p_name: String = "", p_color: Color = Color.WHITE, p_order: int = 0):
	name = p_name
	color = p_color
	order = p_order


## Compare block categories for sorting. Compare by order then name.
static func sort_by_order(a, b) -> bool:
	var a_is_custom := _is_custom_category(a.name)
	var b_is_custom := _is_custom_category(b.name)
	if a_is_custom != b_is_custom:
		return not a_is_custom
	if a.order != b.order:
		return a.order < b.order
	return a.name.naturalcasecmp_to(b.name) < 0


static func _is_custom_category(category_name: String) -> bool:
	return category_name.get_slice(" |", 0) == "Custom"
