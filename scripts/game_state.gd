extends Node

## Vibe Coder Tycoon — core economy state (see GAME_DESIGN.md).

const PrestigeTree = preload("res://scripts/prestige_tree.gd")
const ProgressMilestoneLogger = preload("res://scripts/progress_milestone_logger.gd")

signal stats_changed
signal passive_gain(loc_gain: float)

const SAVE_PATH := "user://save.json"
const CURRENT_SAVE_VERSION := 8
const ACTIVE_TICK_MAX := 2.0  # elapsed > this = offline gap, skip play-time accrual
const UI_REFRESH_INTERVAL := 0.1  # оновлювати UI 10 раз/сек, не 60
const AUTOSAVE_SEC := 10.0
const OFFLINE_CAP_SEC := 28800.0  # 8 hours

const BUG_RATE_CLICK := 0.05
const BUG_RATE_PASSIVE := 0.03
const UPGRADE_COST_GROWTH := 1.15

const BASE_LOC_PER_CLICK := 1.0
const BASE_LOC_PER_SEC := 0.0
const BASE_DEPLOY_RATE := 0.10
const BASE_QA_POWER := 0.0

const PRESTIGE_MONEY_THRESHOLD := 1_000_000.0
const STAT_SOFT_CAP := 1e100
const TESTER_MODE := true  # true для тестерів на itch, false для публічного релізу

var loc: float = 0.0
var money: float = 0.0
var bugs: float = 0.0
var loc_per_click: float = BASE_LOC_PER_CLICK
var loc_per_sec: float = BASE_LOC_PER_SEC
var deploy_rate: float = BASE_DEPLOY_RATE
var qa_power: float = BASE_QA_POWER
var prestige_mult: float = 1.0
var prestige_points: int = 0
var prestige_count: int = 0

var upgrade_owned: Dictionary = {}
var skill_owned: Dictionary = {}

var global_loc_mult: float = 1.0
var click_mult_add: float = 0.0
var sec_mult_add: float = 0.0
var deploy_mult_add: float = 0.0
var upgrade_cost_mult: float = 1.0
var bug_mult: float = 1.0
var skill_productivity_mult: float = 1.0
var skill_productivity_floor: float = 0.1
var prestige_start_money: float = 0.0
var auto_click_per_sec: float = 0.0
var auto_qa_per_sec: float = 0.0
var offline_progress_enabled: bool = false

var click_unlocked: bool = false
var hello_world_done: bool = false
var hello_world_with_bug: bool = false
var hello_world_hint_seen: bool = false

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
var _milestone_logger: ProgressMilestoneLogger


func _ready() -> void:
	_init_milestone_logger()
	load_game()
	if TESTER_MODE and _milestone_logger != null:
		_milestone_logger.sync_from_save(self)
	_autosave_timer = Timer.new()
	_autosave_timer.wait_time = AUTOSAVE_SEC
	_autosave_timer.autostart = true
	_autosave_timer.timeout.connect(save_game)
	add_child(_autosave_timer)


func _init_milestone_logger() -> void:
	_milestone_logger = ProgressMilestoneLogger.new()
	if TESTER_MODE:
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
	if bugs < 1.0:
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


func _check_flavor_bug_thresholds() -> void:
	if bugs < 1.0:
		return
	var prod := productivity_factor()
	if not _flavor_bug_level_1 and prod < 0.95:
		_flavor_bug_level_1 = true
		FlavorLines.trigger("bug_threshold", {"level": 1})
	if not _flavor_bug_level_2 and prod < 0.70:
		_flavor_bug_level_2 = true
		FlavorLines.trigger("bug_threshold", {"level": 2})
	if not _flavor_bug_level_3 and prod < 0.40:
		_flavor_bug_level_3 = true
		FlavorLines.trigger("bug_threshold", {"level": 3})


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


func has_skill(skill_id: String) -> bool:
	return bool(skill_owned.get(skill_id, false))


func can_buy_skill(skill_id: String) -> bool:
	if has_skill(skill_id):
		return false
	var def := PrestigeTree.find(skill_id)
	if def.is_empty():
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
	if not TESTER_MODE:
		return false
	used_cheats = true
	return buy_skill(skill_id)


func grant_prestige_points(amount: int) -> void:
	if not TESTER_MODE:
		return
	if amount <= 0:
		return
	used_cheats = true
	prestige_points += amount
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
		"prestige_count": prestige_count,
		"prestige_mult": prestige_mult,
		"upgrade_owned": upgrade_owned.duplicate(),
		"skill_owned": skill_owned.duplicate(),
		"last_tick_time": last_tick_time,
		"total_play_time": total_play_time,
		"click_unlocked": click_unlocked,
		"hello_world_done": hello_world_done,
		"hello_world_with_bug": hello_world_with_bug,
		"hello_world_hint_seen": hello_world_hint_seen,
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
	_abort_save_and_reset("manual reset")


func _apply_default_state() -> void:
	loc = 0.0
	money = 0.0
	bugs = 0.0
	prestige_points = 0
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
	_spam_clicks_in_window = 0
	_spam_window_elapsed = 0.0
	upgrade_owned.clear()
	skill_owned.clear()
	_offline_summary = {}
	_auto_click_timer = 0.0
	last_tick_time = _now()
	total_play_time = 0.0
	recalculate_stats()
	if _milestone_logger != null and TESTER_MODE:
		_milestone_logger.reset_session()


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


func _validate_save_data(data: Dictionary) -> bool:
	var version := int(data.get("save_version", 0))
	if version < 2:
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
	var gains := _apply_passive_for_elapsed(elapsed)
	if gains.loc > 0.0:
		passive_gain.emit(gains.loc)


func _apply_passive_for_elapsed(elapsed: float) -> Dictionary:
	var result := {"loc": 0.0, "bugs_added": 0.0}
	if elapsed <= 0.0:
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


func click_code() -> float:
	if not click_unlocked:
		return 0.0
	var gain := loc_per_click * prestige_mult * productivity_factor()
	loc += gain
	bugs += gain * BUG_RATE_CLICK * bug_mult
	_clamp_stats()
	if _milestone_logger != null and gain > 0.0:
		_milestone_logger.record_click()
	total_clicks += 1
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
		click_code()


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
	return money >= PRESTIGE_MONEY_THRESHOLD


func preview_prestige_points() -> int:
	if not can_prestige():
		return 0
	return int(floor(sqrt(money / PRESTIGE_MONEY_THRESHOLD)))


func prestige() -> int:
	if not can_prestige():
		return 0
	var new_points := preview_prestige_points()
	prestige_points += new_points
	prestige_mult = 1.0 + prestige_points * 0.1

	loc = 0.0
	bugs = 0.0
	upgrade_owned.clear()
	recalculate_stats()
	money = prestige_start_money
	prestige_count += 1

	stats_changed.emit()
	save_game()
	last_tick_time = _now()
	if _milestone_logger != null:
		_milestone_logger.on_prestige(self)
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
