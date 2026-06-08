extends CanvasLayer

const C_CYAN := Color("#00e5ff")
const C_MAGENTA := Color("#ff00aa")
const C_PRESTIGE := Color("#b44cff")
const C_RED := Color("#ff4466")
const C_PANEL := Color(0.08, 0.06, 0.14, 0.88)
const C_MUTED := Color("#666688")
const C_TEXT := Color("#e8e0ff")

const UPGRADE_PANEL_WIDTH := 340.0
const UPGRADE_PANEL_MARGIN := 16.0
const FONT_STAT := 20
const FONT_UPGRADE_NAME := 18
const FONT_UPGRADE_PRICE := 16
const FONT_MEME := 13
const FONT_CATEGORY := 16
const FONT_BONUS := 14
const FONT_BONUS_SMALL := 13

const BULK_MODES := [1, 5, 10, 0]  # 0 = Макс
const BULK_TAB_LABELS := ["×1", "×5", "×10", "Макс"]

const HELLO_WORLD_ANSWER := "print(\"Hello World\")"
const ONBOARDING_INTRO := (
	"Колись ти захотів стати програмістом. Напиши свій перший рядок коду."
)
const ONBOARDING_SUCCESS := (
	"Воно працює! ...окей, це було важко. "
	+ "А що як просто... описати чого хочеш, і хай воно само пишеться?"
)
const ONBOARDING_SUCCESS_BUGGY := (
	"Хм, воно... запустилось. З помилкою, але запустилось. "
	+ "Норм, потім полагодимо."
)

const PASSIVE_POPUP_ANCHOR := Vector2(560, 380)
const PASSIVE_POPUP_BATCH_SEC := 1.0

const PRESTIGE_BRANCH_ORDER := ["core", "senior", "vibe", "qa"]

const DEBUG_SKILL_BUTTONS := [
	{"id": "", "label": "+10 refactor pts", "action": "grant_10"},
	{"id": "sk_caffeine", "label": "caffeine", "action": "buy"},
	{"id": "sk_fast_fingers", "label": "fast_fingers", "action": "buy"},
	{"id": "sk_autocomplete", "label": "autocomplete", "action": "buy"},
	{"id": "sk_bg_agent", "label": "bg_agent", "action": "buy"},
	{"id": "sk_cicd", "label": "cicd", "action": "buy"},
]

var _loc_label: Label
var _money_label: Label
var _bugs_label: Label
var _prod_label: Label
var _rate_label: Label
var _deploy_button: Button
var _prestige_button: Button
var _prestige_tree_button: Button
var _prestige_tree_overlay: Control
var _prestige_tree_points_label: Label
var _prestige_tree_rows: Dictionary = {}
var _prestige_dialog: ConfirmationDialog
var _reset_dialog: ConfirmationDialog
var _popup_layer: Control
var _upgrade_list: VBoxContainer
var _upgrade_rows: Dictionary = {}
var _bulk_mode_index := 0
var _bulk_tab_buttons: Array[Button] = []
var _bonuses_body: VBoxContainer
var _onboarding_panel: PanelContainer
var _onboarding_intro: Label
var _onboarding_input_row: HBoxContainer
var _onboarding_input: LineEdit
var _onboarding_hint: Label
var _upgrade_panel: PanelContainer
var _bulk_tabs_row: HBoxContainer
var _bonuses_panel: PanelContainer
var _bottom_bar: HBoxContainer
var _click_hint: Label
var _category_headers: Dictionary = {}
var _passive_pending_gain: float = 0.0
var _passive_popup_timer: float = 0.0
var _debug_skill_panel: PanelContainer
var _debug_skill_status: Label


func _ready() -> void:
	_build_ui()
	_build_prestige_dialog()
	_build_reset_dialog()
	GameState.stats_changed.connect(_refresh_all)
	GameState.passive_gain.connect(_on_passive_gain)
	_refresh_all()
	call_deferred("_show_offline_popup_if_needed")


func _process(delta: float) -> void:
	if _passive_pending_gain <= 0.0:
		return
	_passive_popup_timer += delta
	if _passive_popup_timer >= PASSIVE_POPUP_BATCH_SEC:
		show_passive_popup(_passive_pending_gain)
		_passive_pending_gain = 0.0
		_passive_popup_timer = 0.0


func _on_passive_gain(gain: float) -> void:
	if gain <= 0.0:
		return
	_passive_pending_gain += gain


func _show_offline_popup_if_needed() -> void:
	var summary: Dictionary = GameState.take_offline_summary()
	var loc_gain: float = summary.get("loc", 0.0)
	var bugs_added: float = summary.get("bugs_added", 0.0)
	if loc_gain <= 0.0 and bugs_added <= 0.0:
		return

	var dialog := AcceptDialog.new()
	dialog.title = "Поки тебе не було"
	dialog.dialog_text = "+%s рядків, +%s багів" % [
		GameState.format_num(loc_gain),
		GameState.format_num(bugs_added),
	]
	dialog.ok_button_text = "Nice"
	add_child(dialog)
	dialog.popup_centered()


func _build_prestige_dialog() -> void:
	_prestige_dialog = ConfirmationDialog.new()
	_prestige_dialog.title = "Рефакторинг з нуля"
	_prestige_dialog.dialog_text = (
		"Ти видалив усе і почав заново. Цього разу буде чисто. (Не буде.)"
	)
	_prestige_dialog.ok_button_text = "Так, refactor"
	_prestige_dialog.cancel_button_text = "Ні, ще покоджу"
	_prestige_dialog.confirmed.connect(_on_prestige_confirmed)
	add_child(_prestige_dialog)


func _build_reset_dialog() -> void:
	_reset_dialog = ConfirmationDialog.new()
	_reset_dialog.title = "git reset --hard"
	_reset_dialog.dialog_text = (
		"Видалити весь прогрес і почати з чистого репозиторію? "
		+ "Це незворотньо. (git reset --hard)"
	)
	_reset_dialog.ok_button_text = "Так, reset --hard"
	_reset_dialog.cancel_button_text = "Ні, ще покоджу"
	_reset_dialog.confirmed.connect(_on_reset_confirmed)
	add_child(_reset_dialog)


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_build_top_bar(root)
	_build_onboarding_panel(root)
	_build_upgrade_panel(root)
	_build_bonuses_panel(root)
	_build_bottom_bar(root)
	_build_reset_button(root)
	_build_prestige_tree_menu(root)
	if GameState.TESTER_MODE:
		_build_debug_skill_panel(root)

	_popup_layer = Control.new()
	_popup_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_popup_layer)


func _build_top_bar(root: Control) -> void:
	var top := PanelContainer.new()
	top.position = Vector2(16, 16)
	top.custom_minimum_size = Vector2(400, 0)
	top.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style(top)
	root.add_child(top)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	top.add_child(column)

	_loc_label = _make_stat_label("💾 Код: 0")
	_money_label = _make_stat_label("💰 Гроші: $0")
	_bugs_label = _make_stat_label("🐛 Баги: 0")
	_prod_label = _make_stat_label("⚡ Продуктивність: 100%")
	_rate_label = _make_stat_label("📈 +0 код/с")
	for label: Label in [_loc_label, _money_label, _bugs_label, _prod_label, _rate_label]:
		column.add_child(label)

	_prestige_button = Button.new()
	_prestige_button.text = "PRESTIGE — Refactor"
	_prestige_button.custom_minimum_size = Vector2(0, 40)
	_prestige_button.visible = false
	_style_button(_prestige_button, C_PRESTIGE)
	_prestige_button.pressed.connect(_on_prestige_pressed)
	column.add_child(_prestige_button)

	_prestige_tree_button = Button.new()
	_prestige_tree_button.text = "🌳 Refactor tree"
	_prestige_tree_button.custom_minimum_size = Vector2(0, 40)
	_prestige_tree_button.visible = false
	_style_button(_prestige_tree_button, C_PRESTIGE)
	_prestige_tree_button.pressed.connect(_open_prestige_tree)
	column.add_child(_prestige_tree_button)


func _build_onboarding_panel(root: Control) -> void:
	_onboarding_panel = PanelContainer.new()
	_onboarding_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_onboarding_panel.offset_left = -360.0
	_onboarding_panel.offset_top = -220.0
	_onboarding_panel.offset_right = 360.0
	_onboarding_panel.offset_bottom = -88.0
	_onboarding_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style(_onboarding_panel)
	root.add_child(_onboarding_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_onboarding_panel.add_child(column)

	_onboarding_intro = Label.new()
	_onboarding_intro.text = ONBOARDING_INTRO
	_onboarding_intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_onboarding_intro.add_theme_color_override("font_color", C_TEXT)
	_onboarding_intro.add_theme_font_size_override("font_size", 16)
	column.add_child(_onboarding_intro)

	_onboarding_input_row = HBoxContainer.new()
	_onboarding_input_row.add_theme_constant_override("separation", 8)
	column.add_child(_onboarding_input_row)

	_onboarding_input = LineEdit.new()
	_onboarding_input.placeholder_text = HELLO_WORLD_ANSWER
	_onboarding_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_onboarding_input.custom_minimum_size = Vector2(0, 36)
	_onboarding_input.add_theme_font_size_override("font_size", 15)
	_onboarding_input.text_submitted.connect(_on_hello_world_submitted)
	_onboarding_input_row.add_child(_onboarding_input)

	var submit := Button.new()
	submit.text = "Enter"
	submit.custom_minimum_size = Vector2(72, 36)
	_style_button(submit, C_CYAN)
	submit.pressed.connect(func() -> void: _on_hello_world_submitted(_onboarding_input.text))
	_onboarding_input_row.add_child(submit)

	_onboarding_hint = Label.new()
	_onboarding_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_onboarding_hint.add_theme_color_override("font_color", C_RED)
	_onboarding_hint.add_theme_font_size_override("font_size", 13)
	_onboarding_hint.visible = false
	column.add_child(_onboarding_hint)


func _build_upgrade_panel(root: Control) -> void:
	var panel := PanelContainer.new()
	_upgrade_panel = panel
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -(UPGRADE_PANEL_WIDTH + UPGRADE_PANEL_MARGIN)
	panel.offset_top = 16.0
	panel.offset_right = -UPGRADE_PANEL_MARGIN
	panel.offset_bottom = -76.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style(panel)
	root.add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)

	var title := Label.new()
	title.text = "Апгрейди"
	title.add_theme_color_override("font_color", C_CYAN)
	title.add_theme_font_size_override("font_size", 22)
	outer.add_child(title)

	_add_bulk_mode_tabs(outer)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	_upgrade_list = VBoxContainer.new()
	_upgrade_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_upgrade_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_upgrade_list)

	var last_category := ""
	for def: Dictionary in UpgradeCatalog.all():
		if def["category"] != last_category:
			last_category = def["category"]
			var header := _add_category_header(_upgrade_list, _category_title(last_category))
			_category_headers[last_category] = header
		_upgrade_rows[def["id"]] = _create_upgrade_row(def)
		_upgrade_list.add_child(_upgrade_rows[def["id"]])


func _add_bulk_mode_tabs(parent: VBoxContainer) -> void:
	var tabs := HBoxContainer.new()
	_bulk_tabs_row = tabs
	tabs.add_theme_constant_override("separation", 6)
	parent.add_child(tabs)

	for i: int in BULK_MODES.size():
		var tab := Button.new()
		tab.text = BULK_TAB_LABELS[i]
		tab.custom_minimum_size = Vector2(0, 34)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.add_theme_font_size_override("font_size", 14)
		tab.pressed.connect(_on_bulk_tab_pressed.bind(i))
		tabs.add_child(tab)
		_bulk_tab_buttons.append(tab)

	_refresh_bulk_tabs()


func _on_bulk_tab_pressed(index: int) -> void:
	_bulk_mode_index = index
	_refresh_bulk_tabs()
	_refresh_upgrades()


func _refresh_bulk_tabs() -> void:
	for i: int in _bulk_tab_buttons.size():
		var tab := _bulk_tab_buttons[i]
		var active := i == _bulk_mode_index
		_style_tab_button(tab, active)


func _style_tab_button(button: Button, active: bool) -> void:
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


func _build_bonuses_panel(root: Control) -> void:
	var panel := PanelContainer.new()
	_bonuses_panel = panel
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = 16.0
	panel.offset_top = -300.0
	panel.offset_right = 336.0
	panel.offset_bottom = -80.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style(panel)
	root.add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	panel.add_child(outer)

	var title := Label.new()
	title.text = "Активні бонуси"
	title.add_theme_color_override("font_color", C_CYAN)
	title.add_theme_font_size_override("font_size", 16)
	outer.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	_bonuses_body = VBoxContainer.new()
	_bonuses_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bonuses_body.add_theme_constant_override("separation", 4)
	scroll.add_child(_bonuses_body)


func _purchase_count_for(upgrade_id: String) -> int:
	var mode: int = BULK_MODES[_bulk_mode_index]
	if mode == 0:
		return GameState.get_max_affordable_count(upgrade_id)
	return mode


func _category_title(category: String) -> String:
	match category:
		"onboarding":
			return "Старт"
		"generators":
			return "Генератори"
		"click":
			return "Клік"
		"qa":
			return "QA"
		"deploy":
			return "Deploy"
		_:
			return category


func _add_category_header(list: VBoxContainer, text: String) -> PanelContainer:
	var header := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(C_CYAN, 0.12)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	header.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", C_CYAN)
	label.add_theme_font_size_override("font_size", FONT_CATEGORY)
	header.add_child(label)
	list.add_child(header)
	return header


func _create_upgrade_row(def: Dictionary) -> PanelContainer:
	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0.12, 0.09, 0.18, 0.95)
	row_style.set_corner_radius_all(6)
	row_style.set_border_width_all(1)
	row_style.border_color = Color(C_CYAN, 0.15)
	row_style.content_margin_left = 12
	row_style.content_margin_right = 12
	row_style.content_margin_top = 10
	row_style.content_margin_bottom = 10
	row.add_theme_stylebox_override("panel", row_style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	row.add_child(box)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	box.add_child(title_row)

	var name := Label.new()
	name.name = "NameLabel"
	name.text = def["name"]
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.add_theme_color_override("font_color", Color("#f0e8ff"))
	name.add_theme_font_size_override("font_size", FONT_UPGRADE_NAME)
	title_row.add_child(name)

	var owned_badge := Label.new()
	owned_badge.name = "OwnedLabel"
	owned_badge.visible = false
	owned_badge.add_theme_color_override("font_color", C_MAGENTA)
	owned_badge.add_theme_font_size_override("font_size", FONT_UPGRADE_NAME)
	title_row.add_child(owned_badge)

	var total := Label.new()
	total.name = "TotalLabel"
	total.visible = false
	total.add_theme_color_override("font_color", C_MUTED)
	total.add_theme_font_size_override("font_size", FONT_MEME)
	box.add_child(total)

	var effect := Label.new()
	effect.name = "EffectLabel"
	effect.text = def["effect_label"]
	effect.add_theme_color_override("font_color", C_CYAN)
	effect.add_theme_font_size_override("font_size", FONT_UPGRADE_PRICE)
	box.add_child(effect)

	var meme := Label.new()
	meme.name = "MemeLabel"
	meme.text = "\"%s\"" % def["meme"]
	meme.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meme.add_theme_color_override("font_color", C_MUTED)
	meme.add_theme_font_size_override("font_size", FONT_MEME)
	box.add_child(meme)

	var buy := Button.new()
	buy.name = "BuyButton"
	buy.custom_minimum_size = Vector2(0, 38)
	buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(buy, C_MAGENTA)
	buy.add_theme_font_size_override("font_size", FONT_UPGRADE_PRICE)
	buy.pressed.connect(_on_upgrade_buy_pressed.bind(def["id"]))
	box.add_child(buy)

	row.set_meta("upgrade_id", def["id"])
	row.set_meta("upgrade_def", def)
	return row


func _build_bottom_bar(root: Control) -> void:
	var bottom := HBoxContainer.new()
	_bottom_bar = bottom
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 352.0
	bottom.offset_right = -(UPGRADE_PANEL_WIDTH + UPGRADE_PANEL_MARGIN + 8.0)
	bottom.offset_bottom = -16.0
	bottom.offset_top = -64.0
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 16)
	bottom.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(bottom)

	var hint := Label.new()
	_click_hint = hint
	hint.text = "Клік по кодеру / столу = git commit"
	hint.add_theme_color_override("font_color", Color("#8888aa"))
	hint.add_theme_font_size_override("font_size", 16)
	bottom.add_child(hint)

	_deploy_button = Button.new()
	_deploy_button.text = "git push — DEPLOY"
	_deploy_button.custom_minimum_size = Vector2(260, 48)
	_deploy_button.add_theme_font_size_override("font_size", 18)
	_style_button(_deploy_button, C_MAGENTA)
	_deploy_button.pressed.connect(_on_deploy_pressed)
	bottom.add_child(_deploy_button)


func _build_reset_button(root: Control) -> void:
	var btn := Button.new()
	btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	btn.offset_left = -(UPGRADE_PANEL_WIDTH + UPGRADE_PANEL_MARGIN + 180.0)
	btn.offset_top = -52.0
	btn.offset_right = -UPGRADE_PANEL_MARGIN
	btn.offset_bottom = -16.0
	btn.text = "Скинути прогрес"
	btn.add_theme_font_size_override("font_size", 13)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_button(btn, C_RED)
	btn.pressed.connect(_on_reset_pressed)
	root.add_child(btn)


func _build_prestige_tree_menu(root: Control) -> void:
	var overlay := Control.new()
	_prestige_tree_overlay = overlay
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(overlay)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_prestige_tree_dim_input)
	overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(920, 620)
	panel.offset_left = -460.0
	panel.offset_top = -310.0
	panel.offset_right = 460.0
	panel.offset_bottom = 310.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style(panel)
	var panel_style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	if panel_style != null:
		panel_style.border_color = Color(C_PRESTIGE, 0.55)
	overlay.add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	outer.add_child(header)

	var title := Label.new()
	title.text = "🌳 Refactor tree"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", C_PRESTIGE)
	title.add_theme_font_size_override("font_size", 24)
	header.add_child(title)

	_prestige_tree_points_label = Label.new()
	_prestige_tree_points_label.add_theme_color_override("font_color", C_TEXT)
	_prestige_tree_points_label.add_theme_font_size_override("font_size", 18)
	header.add_child(_prestige_tree_points_label)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(40, 36)
	_style_button(close_btn, C_MUTED)
	close_btn.pressed.connect(_close_prestige_tree)
	header.add_child(close_btn)

	var subtitle := Label.new()
	subtitle.text = (
		"Refactor points не зникають після prestige. "
		+ "Скіли лишаються назавжди."
	)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_color_override("font_color", C_MUTED)
	subtitle.add_theme_font_size_override("font_size", 13)
	outer.add_child(subtitle)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)

	for branch: String in PRESTIGE_BRANCH_ORDER:
		_add_category_header(list, _prestige_branch_title(branch))
		for def: Dictionary in PrestigeTree.branch_nodes(branch):
			var row := _create_skill_row(def)
			_prestige_tree_rows[def["id"]] = row
			list.add_child(row)

	if GameState.TESTER_MODE:
		_add_prestige_tree_tester_row(outer)


func _add_prestige_tree_tester_row(outer: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	outer.add_child(row)

	var hint := Label.new()
	hint.text = "Тест:"
	hint.add_theme_color_override("font_color", C_MUTED)
	hint.add_theme_font_size_override("font_size", 12)
	row.add_child(hint)

	var grant_btn := Button.new()
	grant_btn.text = "+10 refactor pts"
	grant_btn.custom_minimum_size = Vector2(160, 36)
	grant_btn.add_theme_font_size_override("font_size", 14)
	_style_button(grant_btn, C_PRESTIGE)
	grant_btn.pressed.connect(func() -> void:
		GameState.grant_prestige_points(10)
	)
	row.add_child(grant_btn)


func _prestige_branch_title(branch: String) -> String:
	match branch:
		"core":
			return "Core · Основа"
		"senior":
			return "Senior · Клік"
		"vibe":
			return "Vibe · Пасив"
		"qa":
			return "QA · Якість"
		_:
			return branch


func _create_skill_row(def: Dictionary) -> PanelContainer:
	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.set_meta("skill_def", def)
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0.12, 0.09, 0.18, 0.95)
	row_style.set_corner_radius_all(6)
	row_style.set_border_width_all(1)
	row_style.border_color = Color(C_PRESTIGE, 0.2)
	row_style.content_margin_left = 12
	row_style.content_margin_right = 12
	row_style.content_margin_top = 10
	row_style.content_margin_bottom = 10
	row.add_theme_stylebox_override("panel", row_style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	row.add_child(box)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	box.add_child(title_row)

	var name := Label.new()
	name.name = "NameLabel"
	name.text = def["name"]
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.add_theme_color_override("font_color", Color("#f0e8ff"))
	name.add_theme_font_size_override("font_size", FONT_UPGRADE_NAME)
	title_row.add_child(name)

	var cost := Label.new()
	cost.name = "CostLabel"
	cost.text = "%d pts" % int(def["cost"])
	cost.add_theme_color_override("font_color", C_PRESTIGE)
	cost.add_theme_font_size_override("font_size", FONT_UPGRADE_PRICE)
	title_row.add_child(cost)

	var meme := Label.new()
	meme.name = "MemeLabel"
	meme.text = def["meme"]
	meme.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meme.add_theme_color_override("font_color", C_MUTED)
	meme.add_theme_font_size_override("font_size", FONT_MEME)
	box.add_child(meme)

	var effect := Label.new()
	effect.name = "EffectLabel"
	effect.text = PrestigeTree.effect_summary(def)
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect.add_theme_color_override("font_color", Color(C_CYAN, 0.85))
	effect.add_theme_font_size_override("font_size", FONT_BONUS_SMALL)
	box.add_child(effect)

	var lock := Label.new()
	lock.name = "LockLabel"
	lock.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lock.add_theme_color_override("font_color", C_RED)
	lock.add_theme_font_size_override("font_size", FONT_BONUS_SMALL)
	lock.visible = false
	box.add_child(lock)

	var buy := Button.new()
	buy.name = "BuyButton"
	buy.custom_minimum_size = Vector2(0, 36)
	buy.add_theme_font_size_override("font_size", FONT_UPGRADE_PRICE)
	_style_button(buy, C_PRESTIGE)
	buy.pressed.connect(_on_skill_buy_pressed.bind(def["id"]))
	box.add_child(buy)

	return row


func _skill_lock_text(def: Dictionary) -> String:
	if GameState.has_skill(def["id"]):
		return ""
	var missing: PackedStringArray = []
	for req_id: String in def.get("requires", []):
		if not GameState.has_skill(req_id):
			var req_def := PrestigeTree.find(req_id)
			missing.append(str(req_def.get("name", req_id)))
	if missing.is_empty():
		return ""
	return "Потрібно: " + ", ".join(missing)


func _open_prestige_tree() -> void:
	if _prestige_tree_overlay == null:
		return
	_refresh_prestige_tree()
	_prestige_tree_overlay.visible = true


func _close_prestige_tree() -> void:
	if _prestige_tree_overlay != null:
		_prestige_tree_overlay.visible = false


func _on_prestige_tree_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_close_prestige_tree()


func _on_skill_buy_pressed(skill_id: String) -> void:
	GameState.buy_skill(skill_id)


func _refresh_prestige_tree() -> void:
	if _prestige_tree_points_label != null:
		_prestige_tree_points_label.text = "%d refactor pts" % GameState.prestige_points

	for skill_id: String in _prestige_tree_rows:
		var row: PanelContainer = _prestige_tree_rows[skill_id]
		var def: Dictionary = row.get_meta("skill_def")
		var buy := row.find_child("BuyButton", true, false) as Button
		var lock := row.find_child("LockLabel", true, false) as Label
		if buy == null:
			continue

		var lock_text := _skill_lock_text(def)
		if lock != null:
			lock.text = lock_text
			lock.visible = not lock_text.is_empty()

		if GameState.has_skill(skill_id):
			buy.text = "✓ Куплено"
			buy.disabled = true
			continue

		if not lock_text.is_empty():
			buy.text = "🔒 Заблоковано"
			buy.disabled = true
			continue

		var cost := int(def["cost"])
		if GameState.prestige_points < cost:
			buy.text = "Купити · %d pts" % cost
			buy.disabled = true
			continue

		buy.text = "Купити · %d pts" % cost
		buy.disabled = false


func _build_debug_skill_panel(root: Control) -> void:
	var panel := PanelContainer.new()
	_debug_skill_panel = panel
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 432.0
	panel.offset_top = 16.0
	panel.offset_right = 432.0 + 280.0
	panel.offset_bottom = 16.0 + 200.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.08, 0.06, 0.92)
	style.set_corner_radius_all(6)
	style.set_border_width_all(1)
	style.border_color = Color("#ffaa44", 0.75)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)

	var title := Label.new()
	title.text = "DEBUG · Prestige tree"
	title.add_theme_color_override("font_color", Color("#ffaa44"))
	title.add_theme_font_size_override("font_size", 14)
	column.add_child(title)

	_debug_skill_status = Label.new()
	_debug_skill_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_debug_skill_status.add_theme_color_override("font_color", C_MUTED)
	_debug_skill_status.add_theme_font_size_override("font_size", 12)
	column.add_child(_debug_skill_status)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	column.add_child(grid)

	for entry: Dictionary in DEBUG_SKILL_BUTTONS:
		var btn := Button.new()
		btn.text = entry["label"]
		btn.custom_minimum_size = Vector2(128, 32)
		btn.add_theme_font_size_override("font_size", 12)
		_style_button(btn, Color("#ffaa44"))
		btn.pressed.connect(_on_debug_skill_pressed.bind(entry))
		grid.add_child(btn)


func _on_debug_skill_pressed(entry: Dictionary) -> void:
	match entry["action"]:
		"grant_10":
			GameState.grant_prestige_points(10)
		"buy":
			GameState.buy_skill(entry["id"])
	_refresh_debug_skill_panel()


func _refresh_debug_skill_panel() -> void:
	if _debug_skill_status == null:
		return
	var owned: Array[String] = []
	for skill_id: String in GameState.skill_owned:
		if GameState.has_skill(skill_id):
			owned.append(skill_id)
	owned.sort()
	_debug_skill_status.text = (
		"pts: %s · owned: %s\n×loc all: %s · click: %s · passive: %s\n%s"
		% [
			str(GameState.prestige_points),
			str(owned.size()),
			GameState.format_num(GameState.global_loc_mult),
			GameState.format_num(GameState.loc_per_click),
			GameState.format_num(GameState.loc_per_sec),
			", ".join(owned) if not owned.is_empty() else "(none)",
		]
	)


func _apply_panel_style(panel: PanelContainer) -> void:
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


func _make_stat_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", C_TEXT)
	label.add_theme_font_size_override("font_size", FONT_STAT)
	return label


func _style_button(button: Button, accent: Color) -> void:
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


func _refresh_all() -> void:
	_refresh_stats()
	_refresh_onboarding()
	_refresh_upgrades()
	_refresh_bonuses()
	_refresh_prestige_tree()
	_refresh_debug_skill_panel()


func _refresh_onboarding() -> void:
	if _onboarding_panel == null:
		return

	var show_code_step := not GameState.hello_world_done
	_onboarding_panel.visible = not GameState.click_unlocked
	_onboarding_input_row.visible = show_code_step
	if not show_code_step:
		_onboarding_hint.visible = false

	if GameState.hello_world_done:
		if GameState.hello_world_with_bug:
			_onboarding_intro.text = ONBOARDING_SUCCESS_BUGGY
		else:
			_onboarding_intro.text = ONBOARDING_SUCCESS
	else:
		_onboarding_intro.text = ONBOARDING_INTRO

	if _upgrade_panel != null:
		_upgrade_panel.visible = GameState.hello_world_done
	if _bulk_tabs_row != null:
		_bulk_tabs_row.visible = GameState.click_unlocked
	if _bonuses_panel != null:
		_bonuses_panel.visible = GameState.click_unlocked
	if _click_hint != null:
		_click_hint.visible = GameState.click_unlocked
	if _deploy_button != null:
		_deploy_button.visible = GameState.click_unlocked

	_refresh_upgrade_visibility()


func _refresh_upgrade_visibility() -> void:
	var visible_categories: Dictionary = {}
	for upgrade_id: String in _upgrade_rows:
		var row: PanelContainer = _upgrade_rows[upgrade_id]
		var def: Dictionary = row.get_meta("upgrade_def")
		var category: String = def["category"]
		var show := false
		if category == "onboarding":
			show = GameState.hello_world_done and not GameState.click_unlocked
		else:
			show = GameState.click_unlocked
		row.visible = show
		if show:
			visible_categories[category] = true

	for category: String in _category_headers:
		var header: PanelContainer = _category_headers[category]
		header.visible = visible_categories.get(category, false)


func _on_hello_world_submitted(raw_text: String) -> void:
	if GameState.hello_world_done:
		return
	var text := raw_text.strip_edges()
	if text == HELLO_WORLD_ANSWER:
		_onboarding_hint.visible = false
		GameState.complete_hello_world(false)
		return

	if GameState.hello_world_hint_seen:
		_onboarding_hint.visible = false
		GameState.complete_hello_world(true)
		return

	GameState.hello_world_hint_seen = true
	GameState.save_game()
	_onboarding_hint.text = _hello_world_hint(text)
	_onboarding_hint.visible = true
	_shake_onboarding_input()


func _hello_world_hint(text: String) -> String:
	if text.is_empty():
		return "Кажуть, усе починається з print(\"Hello World\"). Спробуй."
	var normalized := text.to_lower().replace(" ", "")
	if normalized.contains("helloworld"):
		return "Майже. Це ж програма — обгорни у print(\"...\")"
	return "Кажуть, усе починається з print(\"Hello World\"). Спробуй."


func _shake_onboarding_input() -> void:
	if _onboarding_input == null:
		return
	var base := _onboarding_input.position
	var tween := create_tween()
	tween.tween_property(_onboarding_input, "position:x", base.x + 8.0, 0.05)
	tween.tween_property(_onboarding_input, "position:x", base.x - 8.0, 0.05)
	tween.tween_property(_onboarding_input, "position:x", base.x + 4.0, 0.05)
	tween.tween_property(_onboarding_input, "position:x", base.x, 0.05)


func _refresh_stats() -> void:
	_loc_label.text = "💾 Код: %s" % GameState.format_num(GameState.loc)
	_money_label.text = "💰 Гроші: $%s" % GameState.format_num(GameState.money)
	_bugs_label.text = "🐛 Баги: %s" % GameState.format_num(GameState.bugs)

	var prod := GameState.productivity_factor()
	_prod_label.text = "⚡ Продуктивність: %.0f%%" % (prod * 100.0)

	var raw_rate := GameState.loc_per_sec * GameState.prestige_mult
	var effective := raw_rate * prod
	var rate_text := "📈 +%s код/с" % GameState.format_num(effective)
	if raw_rate > 0.0 and prod < 0.999:
		var penalty := (1.0 - prod) * 100.0
		rate_text += " (−%.0f%% від багів)" % penalty
	if GameState.prestige_mult > 1.0:
		rate_text += "  · ×%.1f prestige" % GameState.prestige_mult
	_rate_label.text = rate_text

	_bugs_label.add_theme_color_override(
		"font_color",
		C_RED if prod < 0.70 else C_TEXT
	)
	_deploy_button.disabled = GameState.loc <= 0.0

	if _prestige_button != null:
		var can := GameState.can_prestige()
		_prestige_button.visible = can
		if can:
			var pts := GameState.preview_prestige_points()
			_prestige_button.text = "PRESTIGE — +%d refactor pts ($%s+)" % [
				pts,
				GameState.format_num(GameState.PRESTIGE_MONEY_THRESHOLD),
			]

	if _prestige_tree_button != null:
		_prestige_tree_button.visible = GameState.click_unlocked
		_prestige_tree_button.text = "🌳 Refactor tree · %d pts" % GameState.prestige_points


func _refresh_upgrades() -> void:
	for upgrade_id: String in _upgrade_rows:
		var row: PanelContainer = _upgrade_rows[upgrade_id]
		var def: Dictionary = row.get_meta("upgrade_def")
		var buy := row.find_child("BuyButton", true, false) as Button
		var owned_lbl := row.find_child("OwnedLabel", true, false) as Label
		var total_lbl := row.find_child("TotalLabel", true, false) as Label
		if buy == null:
			continue

		var owned := GameState.get_upgrade_owned(upgrade_id)
		var max_owned := UpgradeCatalog.get_max_owned(def)

		if owned_lbl != null:
			if owned > 0:
				owned_lbl.text = "×%d" % owned
				owned_lbl.visible = true
			else:
				owned_lbl.visible = false

		if total_lbl != null:
			var total_text := UpgradeCatalog.format_total_effect(
				def, owned, GameState.format_num
			)
			total_lbl.text = total_text
			total_lbl.visible = not total_text.is_empty()

		if owned >= max_owned:
			buy.text = "Куплено"
			buy.disabled = true
			continue

		var count := _purchase_count_for(upgrade_id)
		var bulk_mode: int = BULK_MODES[_bulk_mode_index]
		var cost := GameState.get_bulk_cost(upgrade_id, count) if count > 0 else INF
		var loc_cost := UpgradeCatalog.costs_loc(def)

		if bulk_mode == 0:
			if count > 0:
				if loc_cost:
					buy.text = "Купити Макс ×%d — %s LoC" % [count, GameState.format_num(cost)]
				else:
					buy.text = "Купити Макс ×%d — $%s" % [count, GameState.format_num(cost)]
			else:
				buy.text = "Макс — не вистачає $" if not loc_cost else "Макс — не вистачає LoC"
		elif count > 0:
			if loc_cost:
				buy.text = "Купити ×%d — %s LoC" % [count, GameState.format_num(cost)]
			else:
				buy.text = "Купити ×%d — $%s" % [count, GameState.format_num(cost)]
		else:
			var preview_cost := GameState.get_bulk_cost(upgrade_id, bulk_mode)
			if loc_cost:
				buy.text = "Купити ×%d — %s LoC" % [bulk_mode, GameState.format_num(preview_cost)]
			else:
				buy.text = "Купити ×%d — $%s" % [bulk_mode, GameState.format_num(preview_cost)]

		buy.disabled = count <= 0 or not GameState.can_buy_upgrade(upgrade_id, count)


func _refresh_bonuses() -> void:
	if _bonuses_body == null:
		return
	for child in _bonuses_body.get_children():
		child.queue_free()

	var b: Dictionary = GameState.get_active_bonuses()
	var click_total: float = b["click_total"]
	var click_base: float = b["click_base"]
	var click_add: float = b["click_add"]
	var click_mult: float = b["click_mult"]

	var click_line := "Клік: +%s код/тап" % GameState.format_num(click_total)
	if click_add > 0.0 or click_mult > 1.0:
		var detail := "(%s база" % GameState.format_num(click_base)
		if click_add > 0.0:
			detail += " + %s апгрейди" % GameState.format_num(click_add)
		if click_mult > 1.0:
			detail += ", ×%.0f" % click_mult
		detail += ")"
		click_line += " " + detail
	_add_bonus_line(click_line, C_TEXT)

	var loc_sec: float = b["loc_per_sec"]
	_add_bonus_line(
		"Пасив: +%s код/с" % GameState.format_num(loc_sec),
		C_CYAN if loc_sec > 0.0 else C_MUTED
	)

	var generators: Array = b["generators"]
	for gen: Dictionary in generators:
		_add_bonus_line(
			"  · %s ×%d → +%s/с" % [
				gen["name"],
				gen["owned"],
				GameState.format_num(gen["rate"]),
			],
			C_MUTED,
			FONT_BONUS_SMALL
		)

	var qa: float = b["qa_power"]
	if qa > 0.0:
		_add_bonus_line(
			"QA: −%s багів/с" % GameState.format_num(qa),
			Color("#39ff14")
		)

	var deploy: float = b["deploy_rate"]
	_add_bonus_line(
		"Deploy: $%s за 1 код" % GameState.format_num(deploy),
		C_MAGENTA
	)

	var prestige: float = b["prestige_mult"]
	if prestige > 1.0:
		_add_bonus_line("Престиж: ×%.1f" % prestige, Color("#b44cff"))


func _add_bonus_line(text: String, color: Color, font_size: int = FONT_BONUS) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	_bonuses_body.add_child(label)


func _on_deploy_pressed() -> void:
	GameState.deploy()


func _on_prestige_pressed() -> void:
	_prestige_dialog.dialog_text = (
		"Ти видалив усе і почав заново. Цього разу буде чисто. (Не буде.)"
	)
	_prestige_dialog.popup_centered()


func _on_prestige_confirmed() -> void:
	GameState.prestige()


func _on_reset_pressed() -> void:
	_reset_dialog.popup_centered()


func _on_reset_confirmed() -> void:
	GameState.reset_progress()


func _on_upgrade_buy_pressed(upgrade_id: String) -> void:
	var count := _purchase_count_for(upgrade_id)
	if count > 0:
		GameState.buy_upgrade(upgrade_id, count)


func show_click_popup(screen_pos: Vector2, gain: float) -> void:
	_show_gain_popup(screen_pos + Vector2(-24, -28), gain, "LoC", C_CYAN)


func show_passive_popup(gain: float) -> void:
	_show_gain_popup(PASSIVE_POPUP_ANCHOR, gain, "LoC", C_MAGENTA)


func _show_gain_popup(screen_pos: Vector2, gain: float, suffix: String, color: Color) -> void:
	if gain <= 0.0:
		return
	var amount := GameState.format_gain(gain)
	if amount.is_empty():
		return

	var label := Label.new()
	label.text = "+%s %s" % [amount, suffix]
	label.position = screen_pos
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 20)
	_popup_layer.add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 36.0, 0.55)
	tween.tween_property(label, "modulate:a", 0.0, 0.55)
	tween.chain().tween_callback(label.queue_free)
