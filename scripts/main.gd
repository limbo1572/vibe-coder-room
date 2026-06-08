extends Node2D

## Phase 1 — static isometric vibe-coder room, viewport-centered.

const TILE_W := 44.0
const TILE_H := 22.0
const FLOOR_W := 9
const FLOOR_H := 9
const WALL_TILES := 4

const TARGET_FILL := 0.70
const VIEW_MARGIN := 10.0

const ROOM_TEXTURE_PATH := "res://assets/sprites/room.png"
const ROOM_HEIGHT_FILL := 0.75
const ROOM_ISO_ORIGIN := Vector2(172.0, 70.0)

const SIGN_TEXTURE_PATH := "res://assets/sprites/sign.png"
const SIGN_SCALE := 0.45
const SIGN_TILE_X := 0.4
const SIGN_TILE_Y := 5.75
const SIGN_TILE_Z := 2.0

const DESK_TEXTURE_PATH := "res://assets/sprites/desk_with_pc.png"
const DESK_SCALE := 0.36
const DESK_TILE_X := 1.75
const DESK_TILE_Y := 3.8
const DESK_TILE_Z := 0.0
const DESK_ANCHOR_BOTTOM := 1.0
const DESK_BASE_SORT_Z := 0.05
const DESK_SCREEN_MODULATE := Color(1.0, 1.0, 1.0, 0.85)

const CODER_TEXTURE_PATH := "res://assets/sprites/coder.png"
var CODER_SCALE := 0.32
var CODER_TILE_X := 1.97
var CODER_TILE_Y := 3.88
const CODER_TILE_Z := 0.12
const CODER_SORT_Z := 0.15

const C_BG := Color("#0d0a18")
const C_FLOOR_A := Color("#1a1230")
const C_FLOOR_B := Color("#221a3a")
const C_WALL := Color("#161028")
const C_WALL_TOP := Color("#1e1638")
const C_NEON_CYAN := Color("#00e5ff")
const C_NEON_MAGENTA := Color("#ff00aa")
const C_NEON_GREEN := Color("#39ff14")
const C_NEON_PURPLE := Color("#b44cff")
const C_MONITOR := Color("#0a2a18")
const C_MONITOR_GLOW := Color("#1a6640")
const C_DESK := Color("#2a1f3d")
const C_CHAIR := Color("#331a55")
const C_COUCH := Color("#3d2255")
const C_CAT := Color("#c9a066")

var _origin := Vector2.ZERO
var _scene_scale := 1.0
var _scene_translation := Vector2.ZERO
var _sign_tex: Texture2D = null
var _desk_tex: Texture2D = null
var _coder_tex: Texture2D = null
var _room_tex: Texture2D = null
var _game_ui: CanvasLayer = null


func _ready() -> void:
	position = Vector2.ZERO
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(ROOM_TEXTURE_PATH):
		_room_tex = load(ROOM_TEXTURE_PATH) as Texture2D
	if ResourceLoader.exists(SIGN_TEXTURE_PATH):
		_sign_tex = load(SIGN_TEXTURE_PATH) as Texture2D
	if ResourceLoader.exists(DESK_TEXTURE_PATH):
		_desk_tex = load(DESK_TEXTURE_PATH) as Texture2D
	if ResourceLoader.exists(CODER_TEXTURE_PATH):
		_coder_tex = load(CODER_TEXTURE_PATH) as Texture2D
	_setup_game_ui()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_update_layout()
	queue_redraw()


func _setup_game_ui() -> void:
	_game_ui = CanvasLayer.new()
	_game_ui.name = "GameUI"
	_game_ui.set_script(load("res://scripts/game_ui.gd"))
	add_child(_game_ui)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if not GameState.click_unlocked:
				return
			if _click_hits_work_area(mb.position):
				var gain := GameState.click_code()
				if gain > 0.0 and _game_ui:
					_game_ui.show_click_popup(mb.position, gain)
				get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not GameState.TESTER_MODE:
		return
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	var changed := false
	match key_event.keycode:
		KEY_LEFT:
			CODER_TILE_X -= 0.02
			changed = true
		KEY_RIGHT:
			CODER_TILE_X += 0.02
			changed = true
		KEY_UP:
			CODER_TILE_Y -= 0.02
			changed = true
		KEY_DOWN:
			CODER_TILE_Y += 0.02
			changed = true
		KEY_BRACKETLEFT:
			CODER_SCALE = maxf(0.01, CODER_SCALE - 0.01)
			changed = true
		KEY_BRACKETRIGHT:
			CODER_SCALE += 0.01
			changed = true

	if changed:
		print("CODER x=%.2f y=%.2f scale=%.2f" % [CODER_TILE_X, CODER_TILE_Y, CODER_SCALE])
		queue_redraw()
		get_viewport().set_input_as_handled()


func _on_viewport_size_changed() -> void:
	_update_layout()
	queue_redraw()


func _local_iso(tx: float, ty: float, tz: float = 0.0) -> Vector2:
	return Vector2(
		(tx - ty) * (TILE_W * 0.5),
		(tx + ty) * (TILE_H * 0.5) - tz * TILE_H
	)


func _iso_offset() -> Vector2:
	return ROOM_ISO_ORIGIN if _room_tex != null else Vector2.ZERO


func _room_bounds_local() -> Rect2:
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	var points: Array[Vector2] = []

	if _room_tex != null:
		var room_size := _room_tex.get_size()
		points.append(Vector2.ZERO)
		points.append(Vector2(room_size.x, 0.0))
		points.append(Vector2(room_size.x, room_size.y))
		points.append(Vector2(0.0, room_size.y))
	else:
		for x in FLOOR_W:
			for y in FLOOR_H:
				var c := _local_iso(x, y)
				points.append(c + Vector2(0.0, -TILE_H * 0.5))
				points.append(c + Vector2(TILE_W * 0.5, 0.0))
				points.append(c + Vector2(0.0, TILE_H * 0.5))
				points.append(c + Vector2(-TILE_W * 0.5, 0.0))

		for y in FLOOR_H:
			for h in WALL_TILES + 1:
				points.append(_local_iso(0, y, h))
				if y + 1 < FLOOR_H:
					points.append(_local_iso(0, y + 1, h))

		for x in FLOOR_W:
			for h in WALL_TILES + 1:
				points.append(_local_iso(x, 0, h))
				if x + 1 < FLOOR_W:
					points.append(_local_iso(x + 1, 0, h))

	var sign_base := _local_iso(SIGN_TILE_X, SIGN_TILE_Y, SIGN_TILE_Z) + _iso_offset()
	var sign_half := Vector2(72.0, 72.0)
	points.append(sign_base - sign_half)
	points.append(sign_base + sign_half)

	var desk_foot := _local_iso(DESK_TILE_X, DESK_TILE_Y, DESK_TILE_Z) + _iso_offset()
	var desk_size := Vector2(256.0, 256.0) * DESK_SCALE
	if _desk_tex != null:
		desk_size = _desk_tex.get_size() * DESK_SCALE
	points.append(desk_foot - Vector2(desk_size.x * 0.5, desk_size.y * DESK_ANCHOR_BOTTOM))
	points.append(desk_foot + Vector2(desk_size.x * 0.5, desk_size.y * (1.0 - DESK_ANCHOR_BOTTOM)))

	for p in points:
		min_p = min_p.min(p)
		max_p = max_p.max(p)

	return Rect2(min_p, max_p - min_p)


func _update_layout() -> void:
	var vp := get_viewport_rect().size

	if _room_tex != null:
		var room_size := _room_tex.get_size()
		_scene_scale = vp.y * ROOM_HEIGHT_FILL / room_size.y
		var scaled := room_size * _scene_scale
		_scene_translation = Vector2(
			(vp.x - scaled.x) * 0.5,
			(vp.y - scaled.y) * 0.5
		)
		return

	var bounds := _room_bounds_local()
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		_scene_scale = 1.0
		_scene_translation = Vector2.ZERO
		return

	_scene_scale = min(
		vp.x * TARGET_FILL / bounds.size.x,
		vp.y * TARGET_FILL / bounds.size.y
	)

	var scaled_size := bounds.size * _scene_scale
	var scaled_pos := bounds.position * _scene_scale

	# Center horizontally; vertically anchor near upper third, then clamp to viewport.
	_scene_translation.x = (vp.x - scaled_size.x) * 0.5 - scaled_pos.x
	_scene_translation.y = vp.y / 3.0 - bounds.position.y * _scene_scale

	var margin := VIEW_MARGIN
	var bottom := _scene_translation.y + scaled_pos.y + scaled_size.y
	var right := _scene_translation.x + scaled_pos.x + scaled_size.x
	if _scene_translation.y < margin:
		_scene_translation.y = margin
	if _scene_translation.x < margin:
		_scene_translation.x = margin
	if bottom > vp.y - margin:
		_scene_translation.y -= bottom - (vp.y - margin)
	if right > vp.x - margin:
		_scene_translation.x -= right - (vp.x - margin)

	var top := _scene_translation.y + scaled_pos.y
	if top < margin:
		_scene_translation.y = margin - scaled_pos.y


func _iso(tx: float, ty: float, tz: float = 0.0) -> Vector2:
	return Vector2(
		_origin.x + (tx - ty) * (TILE_W * 0.5),
		_origin.y + (tx + ty) * (TILE_H * 0.5) - tz * TILE_H
	) + _iso_offset()


func _sort_key(tx: float, ty: float, tz: float = 0.0) -> float:
	return tx + ty + tz * 0.01


func _scene_transform() -> Transform2D:
	return Transform2D(Vector2(_scene_scale, 0.0), Vector2(0.0, _scene_scale), _scene_translation)


func _screen_to_scene_local(screen_pos: Vector2) -> Vector2:
	_update_layout()
	_origin = Vector2.ZERO
	return _scene_transform().affine_inverse() * screen_pos


func _coder_draw_rect() -> Rect2:
	var foot := _iso(CODER_TILE_X, CODER_TILE_Y, CODER_TILE_Z)
	var tex_size := Vector2(128.0, 128.0) * CODER_SCALE
	if _coder_tex != null:
		tex_size = _coder_tex.get_size() * CODER_SCALE
	var draw_pos := foot - Vector2(tex_size.x * 0.5, tex_size.y)
	return Rect2(draw_pos, tex_size)


func _click_hits_work_area(screen_pos: Vector2) -> bool:
	var local := _screen_to_scene_local(screen_pos)
	return _desk_draw_rect().has_point(local) or _coder_draw_rect().has_point(local)


func _draw() -> void:
	_update_layout()
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), C_BG)

	draw_set_transform_matrix(
		Transform2D(Vector2(_scene_scale, 0.0), Vector2(0.0, _scene_scale), _scene_translation)
	)
	_origin = Vector2.ZERO

	if _room_tex != null:
		draw_texture_rect(_room_tex, Rect2(Vector2.ZERO, _room_tex.get_size()), false)

	var items: Array[Dictionary] = []
	_collect_room(items)
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["sort"] < b["sort"]
	)
	for item: Dictionary in items:
		item["fn"].call()

	draw_set_transform_matrix(Transform2D.IDENTITY)


func _collect_room(items: Array[Dictionary]) -> void:
	if _room_tex == null:
		_collect_procedural_room(items)
	_collect_objects(items)


func _collect_procedural_room(items: Array[Dictionary]) -> void:
	for x in FLOOR_W:
		for y in FLOOR_H:
			var sk := _sort_key(x, y, -0.2)
			items.append({"sort": sk, "fn": _draw_floor_tile.bind(x, y)})

	for y in FLOOR_H:
		for h in WALL_TILES:
			var sk := _sort_key(0, y, h * 0.08)
			items.append({"sort": sk, "fn": _draw_left_wall_tile.bind(y, h)})

	for x in FLOOR_W:
		for h in WALL_TILES:
			var sk := _sort_key(x, 0, h * 0.08)
			items.append({"sort": sk, "fn": _draw_back_wall_tile.bind(x, h)})

	items.append({"sort": _sort_key(6, 0, 1.5), "fn": _draw_window})
	items.append({"sort": _sort_key(FLOOR_W - 1, 0, WALL_TILES), "fn": _draw_rgb_strip})
	items.append({"sort": _sort_key(0, 3, 1.8), "fn": _draw_shelves})


func _collect_objects(items: Array[Dictionary]) -> void:
	items.append({"sort": _sort_key(SIGN_TILE_X, SIGN_TILE_Y, SIGN_TILE_Z), "fn": _draw_neon_sign})
	items.append({"sort": _sort_key(DESK_TILE_X, DESK_TILE_Y, DESK_BASE_SORT_Z), "fn": _draw_desk_base})
	items.append({"sort": _sort_key(CODER_TILE_X, CODER_TILE_Y, CODER_SORT_Z), "fn": _draw_coder})


func _draw_floor_tile(tx: int, ty: int) -> void:
	var c := _iso(tx, ty)
	var hw := TILE_W * 0.5
	var hh := TILE_H * 0.5
	var pts := PackedVector2Array([
		c + Vector2(0, -hh),
		c + Vector2(hw, 0),
		c + Vector2(0, hh),
		c + Vector2(-hw, 0),
	])
	var col := C_FLOOR_A if (tx + ty) % 2 == 0 else C_FLOOR_B
	draw_colored_polygon(pts, col)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color("#120d22"), 1.0)


func _draw_left_wall_tile(ty: int, h: int) -> void:
	var base := _iso(0, ty, h)
	var top := _iso(0, ty, h + 1)
	var right_base := _iso(0, ty + 1, h) if ty + 1 < FLOOR_H else base + Vector2(TILE_W * 0.5, TILE_H * 0.5)
	var right_top := _iso(0, ty + 1, h + 1) if ty + 1 < FLOOR_H else top + Vector2(TILE_W * 0.5, TILE_H * 0.5)
	var col := C_WALL if h < WALL_TILES - 1 else C_WALL_TOP
	draw_colored_polygon(PackedVector2Array([base, top, right_top, right_base]), col)


func _draw_back_wall_tile(tx: int, h: int) -> void:
	var base := _iso(tx, 0, h)
	var top := _iso(tx, 0, h + 1)
	var right_base := _iso(tx + 1, 0, h) if tx + 1 < FLOOR_W else base + Vector2(-TILE_W * 0.5, TILE_H * 0.5)
	var right_top := _iso(tx + 1, 0, h + 1) if tx + 1 < FLOOR_W else top + Vector2(-TILE_W * 0.5, TILE_H * 0.5)
	var col := C_WALL if h < WALL_TILES - 1 else C_WALL_TOP
	draw_colored_polygon(PackedVector2Array([base, top, right_top, right_base]), col)


func _draw_window() -> void:
	var tl := _iso(6, 0, 1.2)
	var tr := _iso(7.2, 0, 1.2)
	var bl := _iso(6, 0, 2.4)
	var br := _iso(7.2, 0, 2.4)
	draw_colored_polygon(PackedVector2Array([tl, tr, br, bl]), Color("#0a1528"))
	draw_colored_polygon(PackedVector2Array([tl, tr, br, bl]), Color("#1a3050", 0.35))
	# Night city lights
	draw_circle(tl + Vector2(8, 14), 2.0, Color("#ffcc66", 0.8))
	draw_circle(tl + Vector2(18, 22), 1.5, C_NEON_CYAN)
	draw_circle(tl + Vector2(28, 10), 1.5, C_NEON_MAGENTA)


func _draw_neon_sign() -> void:
	var base := _iso(SIGN_TILE_X, SIGN_TILE_Y, SIGN_TILE_Z)
	if _sign_tex != null:
		var tex_size := _sign_tex.get_size() * SIGN_SCALE
		draw_texture_rect(_sign_tex, Rect2(base - tex_size * 0.5, tex_size), false)
	else:
		_draw_neon_sign_procedural(base)


func _draw_neon_sign_procedural(base: Vector2) -> void:
	var w := 130.0
	var h := 18.0
	var rect := Rect2(base.x - w * 0.5, base.y - h * 0.5, w, h)
	for i in 3:
		var expand := float(i + 1) * 3.0
		var alpha := 0.12 - i * 0.03
		draw_rect(rect.grow(expand), Color(C_NEON_MAGENTA, alpha))
	draw_rect(rect, Color("#1a0a28"))
	draw_rect(rect, C_NEON_MAGENTA, false, 2.0)
	draw_rect(Rect2(base.x - 58, base.y - 4, 116, 8), Color(C_NEON_CYAN, 0.55))


func _draw_rgb_strip() -> void:
	for x in FLOOR_W:
		var p := _iso(x, 0, WALL_TILES + 0.15)
		var q := _iso(x + 1, 0, WALL_TILES + 0.15) if x + 1 < FLOOR_W else p + Vector2(-TILE_W * 0.5, TILE_H * 0.5)
		var hue := fmod(x * 0.35, 1.0)
		draw_line(p, q, Color.from_hsv(hue, 0.9, 1.0), 3.0)
	for y in FLOOR_H:
		var p := _iso(0, y, WALL_TILES + 0.15)
		var q := _iso(0, y + 1, WALL_TILES + 0.15) if y + 1 < FLOOR_H else p + Vector2(TILE_W * 0.5, TILE_H * 0.5)
		var hue := fmod(y * 0.35 + 0.5, 1.0)
		draw_line(p, q, Color.from_hsv(hue, 0.9, 1.0), 3.0)


func _draw_shelves() -> void:
	var base := _iso(0, 3, 1.0)
	var shelf_w := 28.0
	for i in 3:
		var y_off := i * 14.0
		draw_rect(Rect2(base.x - 4, base.y - 20 - y_off, shelf_w, 4), Color("#2a2040"))
		draw_rect(Rect2(base.x + 2, base.y - 24 - y_off, 6, 6), C_NEON_PURPLE)
		draw_rect(Rect2(base.x + 12, base.y - 24 - y_off, 6, 6), C_NEON_GREEN)


func _desk_draw_rect() -> Rect2:
	# Floor object: no rotation — sprite is pre-drawn in isometric floor projection.
	var foot := _iso(DESK_TILE_X, DESK_TILE_Y, DESK_TILE_Z)
	var tex_size := Vector2(256.0, 256.0) * DESK_SCALE
	if _desk_tex != null:
		tex_size = _desk_tex.get_size() * DESK_SCALE
	var draw_pos := foot - Vector2(tex_size.x * 0.5, tex_size.y * DESK_ANCHOR_BOTTOM)
	return Rect2(draw_pos, tex_size)


func _draw_desk_base() -> void:
	if _desk_tex != null:
		draw_texture_rect(_desk_tex, _desk_draw_rect(), false, DESK_SCREEN_MODULATE)
	else:
		_draw_desk_procedural()


func _draw_desk_procedural() -> void:
	var c := _iso(DESK_TILE_X, DESK_TILE_Y, 0.1)
	var hw := 36.0
	var hh := 14.0
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-hw, -hh * 0.3),
		c + Vector2(hw, -hh * 0.3),
		c + Vector2(hw * 0.85, hh),
		c + Vector2(-hw * 0.85, hh),
	]), C_DESK)


func _draw_coder() -> void:
	if _coder_tex != null:
		var foot := _iso(CODER_TILE_X, CODER_TILE_Y, CODER_TILE_Z)
		var tex_size := _coder_tex.get_size() * CODER_SCALE
		var draw_pos := foot - Vector2(tex_size.x * 0.5, tex_size.y)
		draw_texture_rect(_coder_tex, Rect2(draw_pos, tex_size), false)
	else:
		_draw_coder_procedural()


func _draw_coder_procedural() -> void:
	var c := _iso(CODER_TILE_X, CODER_TILE_Y, CODER_TILE_Z)
	# Back view — spine to wall/monitor, no face.
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-11, -6),
		c + Vector2(11, -6),
		c + Vector2(9, 20),
		c + Vector2(-9, 20),
	]), Color("#3a5070"))
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-13, -4),
		c + Vector2(13, -4),
		c + Vector2(10, 14),
		c + Vector2(-10, 14),
	]), Color("#2244aa"))
	draw_circle(c + Vector2(0, -14), 7.0, Color("#2a2040"))
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-8, -20), c + Vector2(8, -20), c + Vector2(6, -12), c + Vector2(-6, -12),
	]), Color("#1a1830"))


func _draw_couch() -> void:
	var c := _iso(2, 6, 0.15)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-28, -8),
		c + Vector2(28, -8),
		c + Vector2(24, 14),
		c + Vector2(-24, 14),
	]), C_COUCH)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-28, -8),
		c + Vector2(-28, -20),
		c + Vector2(-20, -8),
	]), Color("#502a70"))
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(28, -8),
		c + Vector2(28, -20),
		c + Vector2(20, -8),
	]), Color("#502a70"))


func _draw_cat() -> void:
	var c := _iso(2.3, 6.2, 0.45)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-10, 0),
		c + Vector2(10, 0),
		c + Vector2(8, 8),
		c + Vector2(-8, 8),
	]), C_CAT)
	draw_circle(c + Vector2(-6, -2), 1.5, Color("#111111"))
	draw_circle(c + Vector2(6, -2), 1.5, Color("#111111"))
	# Ears
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-8, -2), c + Vector2(-12, -10), c + Vector2(-4, -4),
	]), C_CAT)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(8, -2), c + Vector2(12, -10), c + Vector2(4, -4),
	]), C_CAT)
