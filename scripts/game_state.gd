extends Node

## Vibe Coder Tycoon — core economy state (see GAME_DESIGN.md).

const PrestigeTree = preload("res://scripts/prestige_tree.gd")
const ProgressMilestoneLogger = preload("res://scripts/progress_milestone_logger.gd")

signal stats_changed
signal passive_gain(loc_gain: float)
signal captcha_triggered

const SAVE_PATH := "user://save.json"
const REFLOG_PATH := "user://save_reflog.json"
const STASH_PATH := "user://save_stash.json"
const ACHIEVEMENTS_PATH := "user://achievements.json"
const ACH_STASH_PATH := "user://achievements_stash.json"
const CURRENT_SAVE_VERSION := 10
const ACTIVE_TICK_MAX := 2.0  # elapsed > this = offline gap, skip play-time accrual
const UI_REFRESH_INTERVAL := 0.1  # оновлювати UI 10 раз/сек, не 60
const AUTOSAVE_SEC := 10.0
const OFFLINE_CAP_SEC := 28800.0  # 8 hours

const CAPTCHA_CLICKS_PER_SEC := 25
const CAPTCHA_SUSTAIN_SEC := 3.0
const CAPTCHA_COOLDOWN_SEC := 60.0

const BUG_RATE_CLICK := 0.05
const BUG_RATE_PASSIVE := 0.03
const UPGRADE_COST_GROWTH := 1.15

const BASE_LOC_PER_CLICK := 1.0
const BASE_LOC_PER_SEC := 0.0
const BASE_DEPLOY_RATE := 0.10
const BASE_QA_POWER := 0.0
const COPILOT_TRIAL_MULT := 2.0  # буст новачка до 1-го престижу ("trial Копілота")
const CYCLE_KICKSTART_MULT := 2.0  # ×2 продакшн на старті циклу, поки money < cap

const PRESTIGE_BASE_THRESHOLD := 10_000.0
const CYCLE_KICKSTART_CAP := PRESTIGE_BASE_THRESHOLD
const PRESTIGE_THRESHOLD_STEP := 3.0
const STAT_SOFT_CAP := 1e100
const MEASURE_MODE := true   # логер віх для збору кривої балансу (заїзд: true, реліз: false)
const DEBUG_CHEATS := false  # чити+дебаг-панелі для розробки (заїзд: false, реліз: false)

var loc: float = 0.0
var money: float = 0.0
var bugs: float = 0.0
var loc_per_click: float = BASE_LOC_PER_CLICK
var loc_per_sec: float = BASE_LOC_PER_SEC
var deploy_rate: float = BASE_DEPLOY_RATE
var qa_power: float = BASE_QA_POWER
var prestige_mult: float = 1.0
var prestige_points: int = 0
var lifetime_prestige_points: int = 0   # сумарно зароблених очок престижу (ачівки, статистика)
var prestige_count: int = 0

var upgrade_owned: Dictionary = {}
var skill_owned: Dictionary = {}
var root_level: int = 0

var global_loc_mult: float = 1.0
var click_mult_add: float = 0.0
var sec_mult_add: float = 0.0
var deploy_mult_add: float = 0.0
var upgrade_cost_mult: float = 1.0
var bug_mult: float = 1.0
var skill_productivity_mult: float = 1.0
var skill_productivity_floor: float = 0.1
var prestige_start_money: float = 0.0
var cycle_kickstart_active: bool = false
var auto_click_per_sec: float = 0.0
var auto_qa_per_sec: float = 0.0
var offline_progress_enabled: bool = false

var click_unlocked: bool = false
var hello_world_done: bool = false
var hello_world_with_bug: bool = false
var hello_world_hint_seen: bool = false
var seen_prestige_intro: bool = false

var total_clicks: int = 0
var total_deploys: int = 0
var used_cheats: bool = false
var passive_loc_earned: float = 0.0
var max_loc_per_sec_seen: float = 0.0
var deployed_low_prod: bool = false

var friday_deploy: bool = false
var zero_bug_streak: float = 0.0
var spam_detected: bool = false
var near_prestige_time: float = 0.0
var near_prestige: bool = false
var afk_return: bool = false

var captcha_required: bool = false
var captcha_count: int = 0

var last_tick_time: float = 0.0
var total_play_time: float = 0.0  # сумарний активний ігровий час, сек

var _autosave_timer: Timer
var _offline_summary: Dictionary = {}
var _auto_click_timer: float = 0.0
var _ui_refresh_accum: float = 0.0
var _spam_clicks_in_window: int = 0
var _spam_window_elapsed: float = 0.0
var _flavor_bug_level_1: bool = false
var _flavor_bug_level_2: bool = false
var _flavor_bug_level_3: bool = false
var _flavor_bug_level_4: bool = false
var _flavor_bug_level_5: bool = false
var _captcha_rate_accum: float = 0.0
var _captcha_clicks_this_sec: int = 0
var _captcha_sec_elapsed: float = 0.0
var _captcha_cooldown: float = 0.0
var _milestone_logger: ProgressMilestoneLogger


func _ready() -> void:
	_init_milestone_logger()
	load_game()
	if MEASURE_MODE and _milestone_logger != null:
		_milestone_logger.sync_from_save(self)
	_autosave_timer = Timer.new()
	_autosave_timer.wait_time = AUTOSAVE_SEC
	_autosave_timer.autostart = true
	_autosave_timer.timeout.connect(save_game)
	add_child(_autosave_timer)


func _init_milestone_logger() -> void:
	_milestone_logger = ProgressMilestoneLogger.new()
	if MEASURE_MODE:
		_milestone_logger.begin()


func get_milestone_log() -> String:
	if _milestone_logger == null:
		return ""
	return _milestone_logger.get_log_text()


func _process(delta: float) -> void:
	tick_passive_realtime()
	_tick_achievement_timers(delta)
	_ui_refresh_accum += delta
	if _ui_refresh_accum >= UI_REFRESH_INTERVAL:
		_ui_refresh_accum = 0.0
		stats_changed.emit()
	_tick_auto_click(delta)


func _tick_achievement_timers(delta: float) -> void:
	if click_unlocked and bugs < 1.0:
		zero_bug_streak += delta
	else:
		zero_bug_streak = 0.0

	if can_prestige():
		near_prestige_time += delta
		if near_prestige_time >= 600.0:
			near_prestige = true
	else:
		near_prestige_time = 0.0

	_spam_window_elapsed += delta
	if _spam_window_elapsed >= 1.0:
		_spam_window_elapsed = 0.0
		_spam_clicks_in_window = 0

	_check_flavor_bug_thresholds()
	_tick_captcha_detection(delta)


func _tick_captcha_detection(delta: float) -> void:
	_captcha_cooldown = maxf(0.0, _captcha_cooldown - delta)
	_captcha_sec_elapsed += delta
	if _captcha_sec_elapsed >= 1.0:
		if _captcha_clicks_this_sec >= CAPTCHA_CLICKS_PER_SEC:
			_captcha_rate_accum += 1.0
		else:
			_captcha_rate_accum = 0.0
		_captcha_clicks_this_sec = 0
		_captcha_sec_elapsed = 0.0
	if (
		_captcha_rate_accum >= CAPTCHA_SUSTAIN_SEC
		and not captcha_required
		and _captcha_cooldown <= 0.0
	):
		captcha_required = true
		captcha_count += 1
		_captcha_rate_accum = 0.0
		captcha_triggered.emit()


func resolve_captcha() -> void:
	captcha_required = false
	_captcha_cooldown = CAPTCHA_COOLDOWN_SEC
	_captcha_rate_accum = 0.0
	_captcha_clicks_this_sec = 0
	stats_changed.emit()


func _check_flavor_bug_thresholds() -> void:
	if bugs < 1.0:
		return
	var prod := productivity_factor()
	if not _flavor_bug_level_1 and prod < 0.95:
		_flavor_bug_level_1 = true
		FlavorLines.trigger("bug_threshold", {"level": 1})
	if not _flavor_bug_level_2 and prod < 0.80:
		_flavor_bug_level_2 = true
		FlavorLines.trigger("bug_threshold", {"level": 2})
	if not _flavor_bug_level_3 and prod < 0.65:
		_flavor_bug_level_3 = true
		FlavorLines.trigger("bug_threshold", {"level": 3})
	if not _flavor_bug_level_4 and prod < 0.50:
		_flavor_bug_level_4 = true
		FlavorLines.trigger("bug_threshold", {"level": 4})
	if not _flavor_bug_level_5 and prod < 0.35:
		_flavor_bug_level_5 = true
		FlavorLines.trigger("bug_threshold", {"level": 5})


func _check_flavor_money() -> void:
	if money >= 1000.0:
		FlavorLines.trigger("money_1000")


func _total_owned_upgrades() -> int:
	var total := 0
	for key: Variant in upgrade_owned:
		total += int(upgrade_owned[key])
	return total


func _record_click_for_spam() -> void:
	_spam_clicks_in_window += 1
	if _spam_clicks_in_window >= 20:
		spam_detected = true


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_IN:
			tick_passive_realtime()
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED:
			save_game()


func _clamp_stats() -> void:
	loc = _sanitize_stat(loc)
	money = _sanitize_stat(money)
	bugs = _sanitize_stat(bugs)


func _sanitize_stat(value: float) -> float:
	if is_nan(value):
		return 0.0
	if is_inf(value):
		return STAT_SOFT_CAP
	return clampf(value, 0.0, STAT_SOFT_CAP)


func recalculate_stats() -> void:
	loc_per_click = BASE_LOC_PER_CLICK
	loc_per_sec = BASE_LOC_PER_SEC
	deploy_rate = BASE_DEPLOY_RATE
	qa_power = BASE_QA_POWER
	_reset_skill_modifiers()

	for def: Dictionary in UpgradeCatalog.all():
		var owned := get_upgrade_owned(def["id"])
		if owned <= 0:
			continue
		match def["effect_type"]:
			UpgradeCatalog.EffectType.LOC_PER_SEC:
				loc_per_sec += def["effect_value"] * owned
			UpgradeCatalog.EffectType.LOC_PER_CLICK_ADD:
				loc_per_click += def["effect_value"] * owned
			UpgradeCatalog.EffectType.QA_POWER:
				qa_power += def["effect_value"] * owned
			UpgradeCatalog.EffectType.DEPLOY_RATE:
				deploy_rate += def["effect_value"] * owned

	for def: Dictionary in UpgradeCatalog.all():
		var owned := get_upgrade_owned(def["id"])
		if owned <= 0:
			continue
		if def["effect_type"] == UpgradeCatalog.EffectType.LOC_PER_CLICK_MULT:
			loc_per_click *= pow(def["effect_value"], owned)

	_apply_skill_stat_modifiers()
	if Engine.has_singleton("Achievements") or typeof(Achievements) != TYPE_NIL:
		if Achievements != null and Achievements.has_method("total_loc_mult_bonus"):
			global_loc_mult *= (1.0 + Achievements.total_loc_mult_bonus())

	loc_per_click *= (1.0 + click_mult_add)
	loc_per_sec *= (1.0 + sec_mult_add)
	deploy_rate *= (1.0 + deploy_mult_add)
	loc_per_click *= global_loc_mult
	loc_per_sec *= global_loc_mult
	max_loc_per_sec_seen = maxf(max_loc_per_sec_seen, loc_per_sec)


func _reset_skill_modifiers() -> void:
	global_loc_mult = 1.0
	click_mult_add = 0.0
	sec_mult_add = 0.0
	deploy_mult_add = 0.0
	upgrade_cost_mult = 1.0
	bug_mult = 1.0
	skill_productivity_mult = 1.0
	skill_productivity_floor = 0.1
	prestige_start_money = 0.0
	auto_click_per_sec = 0.0
	auto_qa_per_sec = 0.0
	offline_progress_enabled = false


func _apply_skill_stat_modifiers() -> void:
	for def: Dictionary in PrestigeTree.all():
		if def.get("is_root", false):
			continue
		if not has_skill(def["id"]):
			continue
		for effect: Dictionary in def["effects"]:
			var effect_type: int = effect["type"]
			var value: float = float(effect["value"])
			match effect_type:
				PrestigeTree.EffectType.GLOBAL_LOC_MULT:
					global_loc_mult *= value
				PrestigeTree.EffectType.UPGRADE_COST_MULT:
					upgrade_cost_mult *= value
				PrestigeTree.EffectType.PRESTIGE_START_MONEY:
					prestige_start_money = maxf(prestige_start_money, value)
				PrestigeTree.EffectType.LOC_CLICK_MULT:
					click_mult_add += (value - 1.0)
				PrestigeTree.EffectType.LOC_SEC_MULT:
					sec_mult_add += (value - 1.0)
				PrestigeTree.EffectType.DEPLOY_RATE_MULT:
					deploy_mult_add += (value - 1.0)
				PrestigeTree.EffectType.QA_POWER_MULT:
					qa_power *= value
				PrestigeTree.EffectType.BUG_RATE_MULT:
					bug_mult *= value
				PrestigeTree.EffectType.BUG_GROWTH_MULT:
					bug_mult *= value
				PrestigeTree.EffectType.PRODUCTIVITY_MULT:
					skill_productivity_mult *= value
				PrestigeTree.EffectType.PRODUCTIVITY_FLOOR:
					skill_productivity_floor = maxf(skill_productivity_floor, value)
				PrestigeTree.EffectType.AUTO_CLICK:
					auto_click_per_sec += value
				PrestigeTree.EffectType.AUTO_QA:
					auto_qa_per_sec += value
				PrestigeTree.EffectType.OFFLINE_PROGRESS:
					offline_progress_enabled = true
	if root_level > 0:
		global_loc_mult *= PrestigeTree.root_loc_mult(root_level)
	if prestige_count == 0:
		global_loc_mult *= COPILOT_TRIAL_MULT
	if cycle_kickstart_active:
		global_loc_mult *= CYCLE_KICKSTART_MULT


func copilot_trial_active() -> bool:
	return prestige_count == 0


func root_next_cost() -> int:
	return 1 + int(floor(float(root_level) / 3.0))


func buy_root_level() -> bool:
	var c := root_next_cost()
	if prestige_points < c:
		return false
	prestige_points -= c
	root_level += 1
	recalculate_stats()
	_clamp_stats()
	stats_changed.emit()
	save_game()
	return true


func mark_prestige_intro_seen() -> void:
	seen_prestige_intro = true
	save_game()


func has_skill(skill_id: String) -> bool:
	return bool(skill_owned.get(skill_id, false))


func can_buy_skill(skill_id: String) -> bool:
	if has_skill(skill_id):
		return false
	var def := PrestigeTree.find(skill_id)
	if def.is_empty():
		return false
	if def.get("is_root", false):
		return false
	if root_level < int(def.get("root_req", 0)):
		return false
	if prestige_points < int(def["cost"]):
		return false
	for req_id: String in def["requires"]:
		if not has_skill(req_id):
			return false
	return true


func buy_skill(skill_id: String) -> bool:
	if not can_buy_skill(skill_id):
		return false
	var def := PrestigeTree.find(skill_id)
	prestige_points -= int(def["cost"])
	skill_owned[skill_id] = true
	recalculate_stats()
	_clamp_stats()
	stats_changed.emit()
	save_game()
	print("Prestige skill purchased: %s (%s)" % [skill_id, def["name"]])
	return true


func debug_buy_skill(skill_id: String) -> bool:
	if not DEBUG_CHEATS:
		return false
	used_cheats = true
	return buy_skill(skill_id)


func grant_prestige_points(amount: int) -> void:
	if not DEBUG_CHEATS:
		return
	if amount <= 0:
		return
	used_cheats = true
	prestige_points += amount
	lifetime_prestige_points += amount
	save_game()
	stats_changed.emit()
	print("Granted %d prestige points (total: %d)" % [amount, prestige_points])


func productivity_factor() -> float:
	var raw := clampf(1.0 - (bugs / (bugs + 100.0)), 0.1, 1.0)
	raw *= skill_productivity_mult
	return clampf(raw, skill_productivity_floor, 1.0)


func get_upgrade_cost(upgrade_id: String) -> float:
	return get_bulk_cost(upgrade_id, 1)


func get_bulk_cost(upgrade_id: String, count: int) -> float:
	if count <= 0:
		return 0.0
	var def := UpgradeCatalog.find(upgrade_id)
	if def.is_empty():
		return INF
	var owned: int = upgrade_owned.get(upgrade_id, 0)
	var base := float(def["base_cost"])
	var growth := UPGRADE_COST_GROWTH
	return base * pow(growth, owned) * (pow(growth, count) - 1.0) / (growth - 1.0) * upgrade_cost_mult


func get_max_affordable_count(upgrade_id: String) -> int:
	var def := UpgradeCatalog.find(upgrade_id)
	if def.is_empty():
		return 0
	var owned := get_upgrade_owned(upgrade_id)
	var cap := UpgradeCatalog.get_max_owned(def) - owned
	if cap <= 0:
		return 0
	var count := 0
	while count < cap and can_buy_upgrade(upgrade_id, count + 1):
		count += 1
	return count


func get_upgrade_owned(upgrade_id: String) -> int:
	return int(upgrade_owned.get(upgrade_id, 0))


func is_upgrade_maxed(upgrade_id: String) -> bool:
	var def := UpgradeCatalog.find(upgrade_id)
	if def.is_empty():
		return true
	return get_upgrade_owned(upgrade_id) >= UpgradeCatalog.get_max_owned(def)


func can_buy_upgrade(upgrade_id: String, count: int = 1) -> bool:
	if count <= 0:
		return false
	var def := UpgradeCatalog.find(upgrade_id)
	if def.is_empty():
		return false
	var owned := get_upgrade_owned(upgrade_id)
	var max_owned := UpgradeCatalog.get_max_owned(def)
	if owned >= max_owned or owned + count > max_owned:
		return false
	var cost := get_bulk_cost(upgrade_id, count)
	if UpgradeCatalog.costs_loc(def):
		return loc >= cost
	return money >= cost


func buy_upgrade(upgrade_id: String, count: int = 1) -> bool:
	if count <= 0:
		return false
	var def := UpgradeCatalog.find(upgrade_id)
	if def.is_empty():
		return false
	var owned := get_upgrade_owned(upgrade_id)
	var max_owned := UpgradeCatalog.get_max_owned(def)
	if owned >= max_owned or owned + count > max_owned:
		return false
	var was_first_ever := _total_owned_upgrades() == 0
	var was_first_of_type := owned == 0
	var cost := get_bulk_cost(upgrade_id, count)
	if UpgradeCatalog.costs_loc(def):
		if loc < cost:
			return false
		loc -= cost
	else:
		if money < cost:
			return false
		money -= cost
	upgrade_owned[upgrade_id] = owned + count
	if def["effect_type"] == UpgradeCatalog.EffectType.UNLOCK_CLICK:
		click_unlocked = true
	recalculate_stats()
	_clamp_stats()
	stats_changed.emit()
	if _milestone_logger != null:
		_milestone_logger.on_upgrade_purchased(self)
	if was_first_ever:
		FlavorLines.trigger("first_upgrade")
	if was_first_of_type:
		FlavorLines.trigger("generator_bought", {"upgrade_id": upgrade_id})
	_check_flavor_money()
	return true


func get_active_bonuses() -> Dictionary:
	var click_add := 0.0
	var click_mult := 1.0
	var generators: Array[Dictionary] = []

	for def: Dictionary in UpgradeCatalog.all():
		var owned := get_upgrade_owned(def["id"])
		if owned <= 0:
			continue
		match def["effect_type"]:
			UpgradeCatalog.EffectType.LOC_PER_SEC:
				generators.append({
					"name": def["name"],
					"owned": owned,
					"rate": def["effect_value"] * owned,
				})
			UpgradeCatalog.EffectType.LOC_PER_CLICK_ADD:
				click_add += def["effect_value"] * owned
			UpgradeCatalog.EffectType.LOC_PER_CLICK_MULT:
				click_mult *= pow(def["effect_value"], owned)

	var click_total := (BASE_LOC_PER_CLICK + click_add) * click_mult
	return {
		"click_base": BASE_LOC_PER_CLICK,
		"click_add": click_add,
		"click_mult": click_mult,
		"click_total": click_total,
		"loc_per_sec": loc_per_sec,
		"generators": generators,
		"qa_power": qa_power,
		"deploy_rate": deploy_rate,
		"prestige_mult": prestige_mult,
	}


func save_game() -> void:
	var data := {
		"save_version": CURRENT_SAVE_VERSION,
		"loc": loc,
		"money": money,
		"bugs": bugs,
		"deploy_rate": deploy_rate,
		"prestige_points": prestige_points,
		"lifetime_prestige_points": lifetime_prestige_points,
		"prestige_count": prestige_count,
		"prestige_mult": prestige_mult,
		"upgrade_owned": upgrade_owned.duplicate(),
		"skill_owned": skill_owned.duplicate(),
		"root_level": root_level,
		"cycle_kickstart_active": cycle_kickstart_active,
		"last_tick_time": last_tick_time,
		"total_play_time": total_play_time,
		"click_unlocked": click_unlocked,
		"hello_world_done": hello_world_done,
		"hello_world_with_bug": hello_world_with_bug,
		"hello_world_hint_seen": hello_world_hint_seen,
		"seen_prestige_intro": seen_prestige_intro,
		"total_clicks": total_clicks,
		"total_deploys": total_deploys,
		"used_cheats": used_cheats,
		"passive_loc_earned": passive_loc_earned,
		"max_loc_per_sec_seen": max_loc_per_sec_seen,
		"deployed_low_prod": deployed_low_prod,
		"friday_deploy": friday_deploy,
		"zero_bug_streak": zero_bug_streak,
		"spam_detected": spam_detected,
		"near_prestige_time": near_prestige_time,
		"near_prestige": near_prestige,
		"afk_return": afk_return,
		"captcha_count": captcha_count,
		"milestone_log": (
			_milestone_logger.serialize() if (_milestone_logger != null and MEASURE_MODE) else {}
		),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning(
			"GameState: failed to save %s (err %d)" % [SAVE_PATH, FileAccess.get_open_error()]
		)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func load_game() -> bool:
	var now := _now()
	if not FileAccess.file_exists(SAVE_PATH):
		_apply_default_state()
		last_tick_time = now
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning(
			"GameState: failed to load %s (err %d)" % [SAVE_PATH, FileAccess.get_open_error()]
		)
		_abort_save_and_reset("read error")
		return false

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("GameState: invalid save file")
		_abort_save_and_reset("invalid json")
		return false

	var data: Dictionary = parsed
	if not _validate_save_data(data):
		_abort_save_and_reset("incompatible or corrupt save")
		return false

	loc = float(data.get("loc", 0.0))
	money = float(data.get("money", 0.0))
	bugs = float(data.get("bugs", 0.0))
	prestige_points = int(data.get("prestige_points", 0))
	prestige_count = int(data.get("prestige_count", 0))
	prestige_mult = float(data.get("prestige_mult", 1.0))
	var saved_lifetime := int(data.get("lifetime_prestige_points", -1))
	if saved_lifetime < 0:
		# старий сейв: відновити lifetime з множника (mult = 1 + lifetime*0.1)
		var from_mult := int(round((prestige_mult - 1.0) / 0.1))
		lifetime_prestige_points = maxi(from_mult, prestige_points)
	else:
		lifetime_prestige_points = saved_lifetime
	# авто-множник прибрано в новій системі престижу; у старих сейвах
	# (включно з уже мігрованими на v10) могло лишитись значення > 1
	prestige_mult = 1.0
	total_play_time = float(data.get("total_play_time", 0.0))

	var save_version := int(data.get("save_version", 0))
	if save_version < 3:
		click_unlocked = true
		hello_world_done = true
	else:
		click_unlocked = bool(data.get("click_unlocked", false))
		hello_world_done = bool(data.get("hello_world_done", false))
		hello_world_with_bug = bool(data.get("hello_world_with_bug", false))
		hello_world_hint_seen = bool(data.get("hello_world_hint_seen", false))

	seen_prestige_intro = bool(data.get("seen_prestige_intro", false))

	total_clicks = int(data.get("total_clicks", 0))
	total_deploys = int(data.get("total_deploys", 0))
	used_cheats = bool(data.get("used_cheats", false))
	passive_loc_earned = float(data.get("passive_loc_earned", 0.0))
	max_loc_per_sec_seen = float(data.get("max_loc_per_sec_seen", 0.0))
	deployed_low_prod = bool(data.get("deployed_low_prod", false))
	friday_deploy = bool(data.get("friday_deploy", false))
	zero_bug_streak = float(data.get("zero_bug_streak", 0.0))
	spam_detected = bool(data.get("spam_detected", false))
	near_prestige_time = float(data.get("near_prestige_time", 0.0))
	near_prestige = bool(data.get("near_prestige", false))
	afk_return = bool(data.get("afk_return", false))
	captcha_count = int(data.get("captcha_count", 0))
	captcha_required = false

	upgrade_owned.clear()
	var owned_raw: Variant = data.get("upgrade_owned", {})
	if typeof(owned_raw) == TYPE_DICTIONARY:
		for key: Variant in owned_raw:
			upgrade_owned[str(key)] = int(owned_raw[key])

	skill_owned.clear()
	var skills_raw: Variant = data.get("skill_owned", {})
	if typeof(skills_raw) == TYPE_DICTIONARY:
		for key: Variant in skills_raw:
			var skill_id := str(key)
			if not skill_id.begins_with("sk_"):
				skill_id = "sk_" + skill_id
			skill_owned[skill_id] = bool(skills_raw[key])

	root_level = int(data.get("root_level", 0))
	cycle_kickstart_active = bool(data.get("cycle_kickstart_active", false))
	if save_version < 10:
		skill_owned.clear()
		prestige_points = lifetime_prestige_points
		root_level = 0

	if _milestone_logger != null and MEASURE_MODE:
		var ml: Dictionary = data.get("milestone_log", {})
		if not ml.is_empty():
			_milestone_logger.restore(ml)

	recalculate_stats()
	_clamp_stats()

	var saved_tick := float(data.get("last_tick_time", 0.0))
	if saved_tick > 0.0:
		var offline_gap := now - saved_tick
		if offline_gap >= 172800.0:
			afk_return = true
	if saved_tick > 0.0 and offline_progress_enabled:
		var elapsed := minf(now - saved_tick, OFFLINE_CAP_SEC)
		if elapsed > 0.0:
			var gains := _apply_passive_for_elapsed(elapsed)
			if elapsed >= 1.0 and (gains.loc > 0.0 or gains.bugs_added > 0.0):
				_offline_summary = gains

	last_tick_time = now
	stats_changed.emit()
	return true


func reset_progress() -> void:
	save_game()
	_copy_user_file(SAVE_PATH, REFLOG_PATH)
	_abort_save_and_reset("manual reset")


func has_stash() -> bool:
	return FileAccess.file_exists(STASH_PATH)


func start_greenfield() -> bool:
	if has_stash():
		return false
	save_game()
	if not _copy_user_file(SAVE_PATH, STASH_PATH):
		return false
	if FileAccess.file_exists(ACHIEVEMENTS_PATH):
		_copy_user_file(ACHIEVEMENTS_PATH, ACH_STASH_PATH)
	if Achievements != null:
		Achievements.reset_unlocked()
		recalculate_stats()
		Achievements.unlock_by_event("ach_greenfield")
		recalculate_stats()
	if _milestone_logger != null:
		_milestone_logger.mark_greenfield_start()
	_abort_save_and_reset("greenfield clean run")
	return true


func stash_pop() -> bool:
	if not has_stash():
		return false
	var archived := PackedStringArray()
	if _milestone_logger != null:
		archived = _milestone_logger.copy_lines_since_greenfield()
	if not _copy_user_file(STASH_PATH, SAVE_PATH):
		return false
	if not load_game():
		return false
	if FileAccess.file_exists(ACH_STASH_PATH):
		_copy_user_file(ACH_STASH_PATH, ACHIEVEMENTS_PATH)
		if Achievements != null:
			Achievements.load_unlocked()
	if Achievements != null:
		Achievements.unlock_by_event("ach_greenfield")
		recalculate_stats()
	if _milestone_logger != null:
		_milestone_logger.append_archive(archived)
	_delete_stash_file()
	_delete_ach_stash_file()
	save_game()
	stats_changed.emit()
	return true


func has_reflog() -> bool:
	return FileAccess.file_exists(REFLOG_PATH)


func restore_from_reflog() -> bool:
	if not has_reflog():
		return false
	if not _copy_user_file(REFLOG_PATH, SAVE_PATH):
		return false
	if not load_game():
		return false
	stats_changed.emit()
	return true


func _apply_default_state() -> void:
	loc = 0.0
	money = 0.0
	bugs = 0.0
	prestige_points = 0
	lifetime_prestige_points = 0
	prestige_count = 0
	prestige_mult = 1.0
	click_unlocked = false
	hello_world_done = false
	hello_world_with_bug = false
	hello_world_hint_seen = false
	total_clicks = 0
	total_deploys = 0
	used_cheats = false
	passive_loc_earned = 0.0
	max_loc_per_sec_seen = 0.0
	deployed_low_prod = false
	friday_deploy = false
	zero_bug_streak = 0.0
	spam_detected = false
	near_prestige_time = 0.0
	near_prestige = false
	afk_return = false
	captcha_required = false
	captcha_count = 0
	_captcha_rate_accum = 0.0
	_captcha_clicks_this_sec = 0
	_captcha_sec_elapsed = 0.0
	_captcha_cooldown = 0.0
	_spam_clicks_in_window = 0
	_spam_window_elapsed = 0.0
	upgrade_owned.clear()
	skill_owned.clear()
	root_level = 0
	cycle_kickstart_active = false
	seen_prestige_intro = false
	_offline_summary = {}
	_auto_click_timer = 0.0
	last_tick_time = _now()
	total_play_time = 0.0
	recalculate_stats()
	if _milestone_logger != null and MEASURE_MODE:
		_milestone_logger.reset_session(self)


func _abort_save_and_reset(reason: String = "") -> void:
	if not reason.is_empty():
		push_warning("GameState: %s — starting fresh" % reason)
	_delete_save_file()
	_apply_default_state()
	save_game()
	stats_changed.emit()


func _delete_save_file() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	if dir.file_exists("save.json"):
		var err := dir.remove("save.json")
		if err != OK:
			push_warning("GameState: failed to delete save (err %d)" % err)


func _copy_user_file(from_path: String, to_path: String) -> bool:
	if not FileAccess.file_exists(from_path):
		return false
	var src := FileAccess.open(from_path, FileAccess.READ)
	if src == null:
		return false
	var bytes := src.get_buffer(src.get_length())
	src.close()
	var dst := FileAccess.open(to_path, FileAccess.WRITE)
	if dst == null:
		return false
	dst.store_buffer(bytes)
	dst.close()
	return true


func _delete_stash_file() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	if dir.file_exists("save_stash.json"):
		var err := dir.remove("save_stash.json")
		if err != OK:
			push_warning("GameState: failed to delete stash (err %d)" % err)


func _delete_ach_stash_file() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	if dir.file_exists("achievements_stash.json"):
		var err := dir.remove("achievements_stash.json")
		if err != OK:
			push_warning("GameState: failed to delete achievements stash (err %d)" % err)


func _validate_save_data(data: Dictionary) -> bool:
	var version := int(data.get("save_version", 0))
	if version < 9:
		return false

	if not _is_valid_nonneg_finite(float(data.get("loc", 0.0))):
		return false
	if not _is_valid_nonneg_finite(float(data.get("money", 0.0))):
		return false
	if not _is_valid_nonneg_finite(float(data.get("bugs", 0.0))):
		return false

	if int(data.get("prestige_points", 0)) < 0:
		return false

	var mult := float(data.get("prestige_mult", 1.0))
	if not is_finite(mult) or mult < 1.0:
		return false

	var owned_raw: Variant = data.get("upgrade_owned", {})
	if typeof(owned_raw) != TYPE_DICTIONARY:
		return false
	for key: Variant in owned_raw:
		if int(owned_raw[key]) < 0:
			return false

	var skills_raw: Variant = data.get("skill_owned", {})
	if skills_raw != null and typeof(skills_raw) != TYPE_DICTIONARY:
		return false
	if typeof(skills_raw) == TYPE_DICTIONARY:
		for key: Variant in skills_raw:
			if typeof(skills_raw[key]) != TYPE_BOOL:
				return false

	var saved_tick := float(data.get("last_tick_time", 0.0))
	if saved_tick != 0.0 and not is_finite(saved_tick):
		return false

	return true


func _is_valid_nonneg_finite(value: float) -> bool:
	return is_finite(value) and value >= 0.0


func take_offline_summary() -> Dictionary:
	var summary := _offline_summary
	_offline_summary = {}
	return summary


func _now() -> float:
	return Time.get_unix_time_from_system()


func tick_passive_realtime() -> void:
	var now := _now()
	var elapsed := minf(now - last_tick_time, OFFLINE_CAP_SEC)
	if elapsed <= 0.0:
		return
	if elapsed <= ACTIVE_TICK_MAX:
		total_play_time += elapsed
	last_tick_time = now
	var is_offline := elapsed > ACTIVE_TICK_MAX
	var gains := _apply_passive_for_elapsed(elapsed, is_offline)
	if gains.loc > 0.0:
		passive_gain.emit(gains.loc)


func _apply_passive_for_elapsed(elapsed: float, is_offline: bool = false) -> Dictionary:
	var result := {"loc": 0.0, "bugs_added": 0.0}
	if elapsed <= 0.0:
		return result
	if is_offline and not offline_progress_enabled:
		return result

	var changed := false
	if loc_per_sec > 0.0:
		var prod := productivity_factor()
		var loc_gain := loc_per_sec * prestige_mult * prod * elapsed
		if loc_gain > 0.0:
			loc += loc_gain
			passive_loc_earned += loc_gain
			var bug_add := loc_gain * BUG_RATE_PASSIVE * bug_mult
			bugs += bug_add
			result.loc = loc_gain
			result.bugs_added = bug_add
			changed = true

	if qa_power > 0.0 and bugs > 0.0:
		var before := bugs
		bugs = maxf(0.0, bugs - qa_power * elapsed)
		if bugs != before:
			changed = true

	if auto_qa_per_sec > 0.0 and bugs > 0.0:
		var before_qa := bugs
		bugs = maxf(0.0, bugs - auto_qa_per_sec * elapsed)
		if bugs != before_qa:
			changed = true

	if changed:
		_clamp_stats()
	return result


func complete_hello_world(with_bug: bool = false) -> void:
	if hello_world_done:
		return
	hello_world_done = true
	hello_world_with_bug = with_bug
	loc += 1.0
	if with_bug:
		bugs += 1.0
	_clamp_stats()
	stats_changed.emit()
	save_game()


func click_code(is_manual: bool = true) -> float:
	if is_manual and captcha_required:
		return 0.0
	if not click_unlocked:
		return 0.0
	var gain := loc_per_click * prestige_mult * productivity_factor()
	loc += gain
	bugs += gain * BUG_RATE_CLICK * bug_mult
	_clamp_stats()
	if _milestone_logger != null and gain > 0.0:
		_milestone_logger.record_click()
	if is_manual:
		total_clicks += 1
		_captcha_clicks_this_sec += 1
		_record_click_for_spam()
	stats_changed.emit()
	return gain


func _tick_auto_click(delta: float) -> void:
	if auto_click_per_sec <= 0.0 or not click_unlocked:
		return
	_auto_click_timer += delta
	var interval := 1.0 / auto_click_per_sec
	while _auto_click_timer >= interval:
		_auto_click_timer -= interval
		click_code(false)


func deploy() -> float:
	if loc <= 0.0:
		return 0.0
	if productivity_factor() < 0.3:
		deployed_low_prod = true
	var dt := Time.get_datetime_dict_from_system()
	if int(dt.get("weekday", 0)) == 5 and int(dt.get("hour", 0)) >= 17:
		friday_deploy = true
	var earned := loc * deploy_rate * prestige_mult * sqrt(productivity_factor())
	money += earned
	if cycle_kickstart_active and money >= CYCLE_KICKSTART_CAP:
		cycle_kickstart_active = false
		recalculate_stats()
	loc = 0.0
	_clamp_stats()
	total_deploys += 1
	stats_changed.emit()
	if _milestone_logger != null:
		_milestone_logger.on_deploy(self)
	if total_deploys == 1:
		FlavorLines.trigger("first_deploy")
	_check_flavor_money()
	return earned


func can_prestige() -> bool:
	return money >= prestige_threshold()


func prestige_threshold() -> float:
	return PRESTIGE_BASE_THRESHOLD * pow(PRESTIGE_THRESHOLD_STEP, prestige_count)


func preview_prestige_points() -> int:
	if not can_prestige():
		return 0
	return 1


func prestige() -> int:
	if not can_prestige():
		return 0
	var new_points := preview_prestige_points()
	prestige_points += new_points
	lifetime_prestige_points += new_points
	prestige_count += 1

	loc = 0.0
	bugs = 0.0
	upgrade_owned.clear()
	_flavor_bug_level_1 = false
	_flavor_bug_level_2 = false
	_flavor_bug_level_3 = false
	_flavor_bug_level_4 = false
	_flavor_bug_level_5 = false
	money = prestige_start_money
	cycle_kickstart_active = true
	recalculate_stats()

	stats_changed.emit()
	if _milestone_logger != null:
		_milestone_logger.on_prestige(self)
	save_game()
	last_tick_time = _now()
	return new_points


static func format_num(value: float) -> String:
	if not is_finite(value):
		return "∞"
	if value == 0.0:
		return "0"

	var sign := ""
	var n := value
	if value < 0.0:
		sign = "-"
		n = -value

	if n < 1.0:
		var text := "%.2f" % n
		if text.contains("."):
			while text.ends_with("0"):
				text = text.substr(0, text.length() - 1)
			if text.ends_with("."):
				text = text.substr(0, text.length() - 1)
		return sign + text

	if n < 1000.0:
		var whole := int(round(n))
		if absf(n - float(whole)) < 1e-6:
			return sign + str(whole)
		var dec_text := "%.1f" % n
		if dec_text.contains("."):
			while dec_text.ends_with("0"):
				dec_text = dec_text.substr(0, dec_text.length() - 1)
			if dec_text.ends_with("."):
				dec_text = dec_text.substr(0, dec_text.length() - 1)
		return sign + dec_text

	var suffixes := ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]
	var tier := int(floor(log(n) / log(1000.0)))
	if tier >= suffixes.size():
		return "%.2e" % value
	var scaled := value / pow(1000.0, tier)
	return "%.2f%s" % [scaled, suffixes[tier]]


static func format_gain(value: float) -> String:
	if not is_finite(value) or value <= 0.0:
		return ""
	var n := absf(value)
	if n < 10.0:
		var decimals := 4 if n < 0.01 else (2 if n < 1.0 else 1)
		var text := ("%%.%df" % decimals) % value
		if text.contains("."):
			while text.ends_with("0"):
				text = text.substr(0, text.length() - 1)
			if text.ends_with("."):
				text = text.substr(0, text.length() - 1)
		if text == "0":
			return ""
		return text
	return format_num(value)
