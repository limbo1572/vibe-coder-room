extends RefCounted
class_name UITheme

const C_CYAN := Color("#00e5ff")
const C_MAGENTA := Color("#ff00aa")
const C_PRESTIGE := Color("#b44cff")
const C_RED := Color("#ff4466")
const C_PANEL := Color(0.08, 0.06, 0.14, 0.88)
const C_MUTED := Color("#9a9ac8")
const C_TEXT := Color("#e8e0ff")

const FONT_STAT := 23
const FONT_UPGRADE_NAME := 21
const FONT_UPGRADE_PRICE := 18
const FONT_MEME := 16
const FONT_CATEGORY := 18
const FONT_BONUS := 17
const FONT_BONUS_SMALL := 16


static func style_button(button: Button, accent: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(accent, 0.18)
	normal.set_corner_radius_all(6)
	normal.set_border_width_all(1)
	normal.border_color = Color(accent, 0.65)
	button.add_theme_stylebox_override("normal", normal)
	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.15, 0.13, 0.2, 0.6)
	disabled.border_color = Color(C_MUTED, 0.4)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("pressed", normal)
	button.add_theme_color_override("font_color", accent)
	button.add_theme_color_override("font_disabled_color", C_MUTED)


static func style_tab_button(button: Button, active: bool) -> void:
	var accent := C_CYAN if active else C_MUTED
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(accent, 0.28 if active else 0.08)
	normal.set_corner_radius_all(6)
	normal.set_border_width_all(1)
	normal.border_color = Color(accent, 0.9 if active else 0.35)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("pressed", normal)
	button.add_theme_color_override("font_color", accent if active else C_TEXT)


static func apply_panel_style(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = C_PANEL
	style.set_corner_radius_all(8)
	style.set_border_width_all(1)
	style.border_color = Color(C_CYAN, 0.35)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)


static func make_stat_label(text: String, font: Font = null) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", C_TEXT)
	label.add_theme_font_size_override("font_size", FONT_STAT)
	if font != null:
		label.add_theme_font_override("font", font)
	return label
