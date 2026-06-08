extends Node

const SAVE_PATH := "user://achievements.json"

signal achievement_unlocked(id: String, def: Dictionary)

const DEFS: Array[Dictionary] = [
	{
		"id": "hello_bugs",
		"name": "Hello, Bugs!",
		"desc": "Перша програма. Перший баг. Гарний початок.",
		"hidden": false,
	},
	{
		"id": "clicker_1000",
		"name": "1000 клац",
		"desc": "Твій палець бачив речі.",
		"hidden": false,
	},
	{
		"id": "callus",
		"name": "Мозоль",
		"desc": "Звернись до лікаря. Або купи автоклікер. Ой, стоп.",
		"hidden": false,
	},
	{
		"id": "it_works",
		"name": "It works on my machine",
		"desc": "У проді розберуться.",
		"hidden": false,
	},
	{
		"id": "bug_collector",
		"name": "Баг-колекціонер",
		"desc": "Хтось колекціонує марки. Ти — технічний борг.",
		"hidden": false,
	},
	{
		"id": "tech_bankrupt",
		"name": "Технічний банкрут",
		"desc": "Це вже не код. Це місце злочину.",
		"hidden": false,
	},
	{
		"id": "it_self",
		"name": "Воно само",
		"desc": "Ти просто дивився. Як справжній сіньйор.",
		"hidden": false,
		"reward_loc_mult": 0.03,
	},
	{
		"id": "so_driven",
		"name": "Stack Overflow Driven Development",
		"desc": "Ctrl+C, Ctrl+V, Ctrl+гонорар.",
		"hidden": false,
		"reward_loc_mult": 0.03,
	},
	{
		"id": "cloud_guy",
		"name": "Лідер по даунлоадах",
		"desc": "Чужий компʼютер. Твоя совість.",
		"hidden": false,
		"reward_loc_mult": 0.03,
	},
	{
		"id": "manager",
		"name": "Менеджер",
		"desc": "Ти більше не кодиш. Ти проводиш стендапи.",
		"hidden": false,
		"reward_loc_mult": 0.03,
	},
	{
		"id": "speed_of_light",
		"name": "Швидше світла",
		"desc": "Якість? Не чули.",
		"hidden": false,
	},
	{
		"id": "first_upgrade",
		"name": "Перший рядок",
		"desc": "Гроші вирішують. Завжди вирішували.",
		"hidden": false,
	},
	{
		"id": "deploy_machine",
		"name": "Деплой-машина",
		"desc": "git push став рефлексом.",
		"hidden": false,
		"reward_loc_mult": 0.03,
	},
	{
		"id": "refactor_holic",
		"name": "Рефакторинг-голік",
		"desc": "Цього разу точно буде чисто.",
		"hidden": false,
		"reward_loc_mult": 0.03,
	},
	{
		"id": "honest_dev",
		"name": "Чесний розробник",
		"desc": "Серед нас ходить легенда.",
		"hidden": true,
	},
	{
		"id": "cheater",
		"name": "Читор",
		"desc": "Ми все бачили. Засуджуємо. Трохи.",
		"hidden": false,
	},
	{
		"id": "friday_deploy",
		"name": "Деплой у пʼятницю",
		"desc": "Що могло піти не так.",
		"hidden": false,
	},
	{
		"id": "perfectionist",
		"name": "Перфекціоніст",
		"desc": "Підозріло чисто. Ти точно щось приховуєш.",
		"hidden": true,
	},
	{
		"id": "spam_machine",
		"name": "Спам-машина",
		"desc": "Ми бачимо тебе. І твій autoclicker.",
		"hidden": false,
	},
	{
		"id": "near_prestige",
		"name": "Один клік від престижу",
		"desc": "Боїшся? Правильно.",
		"hidden": true,
	},
	{
		"id": "afk_return",
		"name": "Повернення блудного сина",
		"desc": "Код сумував. Брехня, не сумував.",
		"hidden": true,
	},
	{
		"id": "just_looking",
		"name": "Я просто подивлюсь",
		"desc": "Window shopping для бідних.",
		"hidden": false,
	},
]

var unlocked: Dictionary = {}
var _initial_scan_done: bool = false


func _ready() -> void:
	load_unlocked()
	GameState.stats_changed.connect(_check_all)
	_check_all()
	_initial_scan_done = true
	if GameState.has_method("recalculate_stats"):
		GameState.recalculate_stats()
		GameState.stats_changed.emit()


func _check_all() -> void:
	for def: Dictionary in DEFS:
		var id: String = def["id"]
		if unlocked.get(id, false):
			continue
		if not _is_unlocked(id):
			continue
		_unlock(id, def)


func unlock_by_event(id: String) -> void:
	if unlocked.get(id, false):
		return
	var def := find_def(id)
	if def.is_empty():
		return
	_unlock(id, def)


func _unlock(id: String, def: Dictionary) -> void:
	unlocked[id] = true
	save_unlocked()
	print("[ACHIEVEMENT] %s" % id)
	if _initial_scan_done:
		achievement_unlocked.emit(id, def)
	if float(def.get("reward_loc_mult", 0.0)) > 0.0:
		if GameState.has_method("recalculate_stats"):
			GameState.recalculate_stats()
			GameState.stats_changed.emit()


func find_def(id: String) -> Dictionary:
	for def: Dictionary in DEFS:
		if def["id"] == id:
			return def
	return {}


func get_unlocked_count() -> int:
	var count := 0
	for def: Dictionary in DEFS:
		if unlocked.get(def["id"], false):
			count += 1
	return count


func get_total_count() -> int:
	return DEFS.size()


func is_unlocked(id: String) -> bool:
	return bool(unlocked.get(id, false))


func total_loc_mult_bonus() -> float:
	var bonus := 0.0
	for def: Dictionary in DEFS:
		if unlocked.get(def["id"], false):
			bonus += float(def.get("reward_loc_mult", 0.0))
	return bonus


func _is_unlocked(id: String) -> bool:
	var gs := GameState
	match id:
		"hello_bugs":
			return gs.hello_world_with_bug
		"clicker_1000":
			return gs.total_clicks >= 1000
		"callus":
			return gs.total_clicks >= 100000
		"it_works":
			return gs.deployed_low_prod
		"bug_collector":
			return gs.bugs >= 10000.0
		"tech_bankrupt":
			return gs.bugs >= 100000.0
		"it_self":
			return gs.passive_loc_earned >= 1000000.0
		"so_driven":
			return gs.is_upgrade_maxed("stackoverflow")
		"cloud_guy":
			return gs.get_upgrade_owned("cloud_hosting") > 0
		"manager":
			return (
				gs.get_upgrade_owned("junior") > 0
				and gs.get_upgrade_owned("youtube_senior") > 0
				and gs.get_upgrade_owned("ai_army") > 0
			)
		"speed_of_light":
			return gs.max_loc_per_sec_seen >= 1000.0
		"first_upgrade":
			return _has_any_upgrade(gs)
		"deploy_machine":
			return gs.total_deploys >= 100
		"refactor_holic":
			return gs.lifetime_prestige_points >= 10
		"honest_dev":
			return gs.lifetime_prestige_points >= 1 and not gs.used_cheats
		"cheater":
			return gs.used_cheats
		"friday_deploy":
			return gs.friday_deploy
		"perfectionist":
			return gs.zero_bug_streak >= 60.0
		"spam_machine":
			return gs.spam_detected
		"near_prestige":
			return gs.near_prestige
		"afk_return":
			return gs.afk_return
		"just_looking":
			return false
		_:
			return false


func _has_any_upgrade(gs: Node) -> bool:
	for key: Variant in gs.upgrade_owned:
		if int(gs.upgrade_owned[key]) > 0:
			return true
	return false


func save_unlocked() -> void:
	var data := {"unlocked": unlocked.duplicate()}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning(
			"Achievements: failed to save %s (err %d)" % [SAVE_PATH, FileAccess.get_open_error()]
		)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func load_unlocked() -> void:
	unlocked.clear()
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning(
			"Achievements: failed to load %s (err %d)" % [SAVE_PATH, FileAccess.get_open_error()]
		)
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return

	var raw: Variant = parsed.get("unlocked", {})
	if typeof(raw) != TYPE_DICTIONARY:
		return

	for key: Variant in raw:
		if bool(raw[key]):
			unlocked[str(key)] = true
