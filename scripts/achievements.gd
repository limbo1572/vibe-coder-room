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
	},
	{
		"id": "so_driven",
		"name": "Stack Overflow Driven Development",
		"desc": "Ctrl+C, Ctrl+V, Ctrl+гонорар.",
		"hidden": false,
	},
	{
		"id": "cloud_guy",
		"name": "Лідер по даунлоадах",
		"desc": "Чужий компʼютер. Твоя совість.",
		"hidden": false,
	},
	{
		"id": "manager",
		"name": "Менеджер",
		"desc": "Ти більше не кодиш. Ти проводиш стендапи.",
		"hidden": false,
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
	},
	{
		"id": "refactor_holic",
		"name": "Рефакторинг-голік",
		"desc": "Цього разу точно буде чисто.",
		"hidden": false,
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
]

var unlocked: Dictionary = {}


func _ready() -> void:
	load_unlocked()
	GameState.stats_changed.connect(_check_all)
	_check_all()


func _check_all() -> void:
	for def: Dictionary in DEFS:
		var id: String = def["id"]
		if unlocked.get(id, false):
			continue
		if not _is_unlocked(id):
			continue
		unlocked[id] = true
		achievement_unlocked.emit(id, def)
		save_unlocked()
		print("[ACHIEVEMENT] %s" % id)


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
			return gs.prestige_points >= 10
		"honest_dev":
			return gs.prestige_points >= 1 and not gs.used_cheats
		"cheater":
			return gs.used_cheats
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
