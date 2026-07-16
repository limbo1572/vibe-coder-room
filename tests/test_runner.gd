extends Node

## Headless smoke/logic tests. Run:
##   godot --headless --path . res://tests/test_runner.tscn
## Exit code = number of failed asserts (0 = all green).
## Backs up and restores user:// save files, safe to run on a dev machine.

const USER_FILES := [
	"user://save.json",
	"user://achievements.json",
	"user://flavor_seen.json",
	"user://save_reflog.json",
	"user://save_stash.json",
	"user://achievements_stash.json",
]

var _backup: Dictionary = {}
var _fails := 0
var _count := 0


func _ready() -> void:
	_backup_user_files()
	GameState._autosave_timer.stop()

	_run_all()

	_restore_user_files()
	# Order matters: real achievements must be in memory BEFORE load_game
	# emits stats_changed, otherwise _check_all re-saves test-era unlocks.
	Achievements.load_unlocked()
	GameState.load_game()
	print("==== %d/%d passed, %d failed ====" % [_count - _fails, _count, _fails])
	get_tree().quit(_fails)


func check(cond: bool, name: String) -> void:
	_count += 1
	if cond:
		print("PASS  %s" % name)
	else:
		_fails += 1
		print("FAIL  %s" % name)


func approx(a: float, b: float, eps: float = 1e-6) -> bool:
	return absf(a - b) <= eps * maxf(1.0, maxf(absf(a), absf(b)))


func _run_all() -> void:
	_test_fresh_state()
	_test_onboarding_and_achievements()
	_test_click_unlock_and_manual_clicks()
	_test_prestige_points_overshoot()
	_test_prestige_reset()
	_test_meta_prestige_chain()
	_test_format_num()
	_test_max_affordable()
	_test_generator_tiers()
	_test_bug_dilution()
	_test_buffs_and_hype()
	_test_perfectionist_gate()
	_test_deploy_risk()
	_test_save_load_roundtrip()


func _fresh() -> void:
	GameState._apply_default_state()
	Achievements.reset_unlocked()


func _test_fresh_state() -> void:
	_fresh()
	check(not GameState.click_unlocked, "fresh: click locked")
	check(not GameState.hello_world_done, "fresh: hello world not done")
	check(GameState.loc == 0.0 and GameState.money == 0.0, "fresh: zero resources")
	check(GameState.meta_level == 0, "fresh: meta level 0")


func _test_onboarding_and_achievements() -> void:
	_fresh()
	GameState.complete_hello_world(false)
	check(GameState.hello_world_done, "onboarding: hello world done")
	check(approx(GameState.loc, 1.0), "onboarding: got 1 LoC")
	check(Achievements._is_unlocked("hello_bugs"), "ach: hello_bugs on clean path")
	check(not Achievements._is_unlocked("first_fail"), "ach: first_fail NOT on clean path")

	_fresh()
	GameState.complete_hello_world(true)
	check(Achievements._is_unlocked("hello_bugs"), "ach: hello_bugs on buggy path")
	check(Achievements._is_unlocked("first_fail"), "ach: first_fail on buggy path")


func _test_click_unlock_and_manual_clicks() -> void:
	_fresh()
	GameState.complete_hello_world(false)
	check(GameState.can_buy_upgrade("vibecode_click", 1), "unlock: can afford click unlock")
	check(GameState.buy_upgrade("vibecode_click", 1), "unlock: bought")
	check(GameState.click_unlocked, "unlock: click unlocked")

	var before := GameState.total_clicks
	var gain := GameState.click_code(true)
	check(gain > 0.0, "click: manual gain > 0")
	check(GameState.total_clicks == before + 1, "click: manual counted")
	GameState.click_code(false)
	check(GameState.total_clicks == before + 1, "click: auto NOT counted")


func _test_prestige_points_overshoot() -> void:
	_fresh()
	var thr := GameState.prestige_threshold()
	GameState.money = thr
	check(GameState.can_prestige(), "prestige: threshold reached")
	check(GameState.preview_prestige_points() == 1, "prestige: +1 at 1x")
	GameState.money = thr * 3.0
	check(GameState.preview_prestige_points() == 2, "prestige: +2 at exactly 3x (epsilon)")
	GameState.money = thr * 9.0
	check(GameState.preview_prestige_points() == 3, "prestige: +3 at 9x")
	GameState.money = thr
	check(approx(GameState.money_for_next_prestige_point(), thr * 3.0), "prestige: next point hint at 3x")


func _test_prestige_reset() -> void:
	_fresh()
	GameState.money = GameState.prestige_threshold()
	GameState.upgrade_owned["stackoverflow"] = 5
	var pts := GameState.prestige()
	check(pts == 1, "prestige: earned 1 pt")
	check(GameState.prestige_count == 1, "prestige: count 1")
	check(GameState.upgrade_owned.is_empty(), "prestige: upgrades wiped")
	check(GameState.cycle_kickstart_active, "prestige: kickstart on")


func _test_meta_prestige_chain() -> void:
	_fresh()
	GameState.complete_hello_world(false)
	GameState.buy_upgrade("vibecode_click", 1)
	GameState.prestige_points = 5
	GameState.skill_owned["sk_fast_fingers"] = true
	GameState.root_level = 2
	GameState.prestige_count = 9
	check(not GameState.can_meta_prestige(), "meta: gate closed at 9")
	GameState.prestige_count = 10
	check(GameState.can_meta_prestige(), "meta: gate open at 10")

	GameState.meta_prestige()
	check(GameState.meta_level == 1, "meta: level 1")
	check(GameState.prestige_count == 0, "meta: prestige count reset")
	check(GameState.prestige_points == 0, "meta: points wiped")
	check(GameState.skill_owned.is_empty(), "meta: skills wiped")
	check(GameState.root_level == 0, "meta: root wiped")
	check(not GameState.click_unlocked, "meta: click locked again")
	check(not GameState.hello_world_done, "meta: onboarding back")
	check(Achievements._is_unlocked("meta_first"), "ach: meta_first")
	check(not Achievements._is_unlocked("meta_sisyphus"), "ach: sisyphus not yet")

	GameState.recalculate_stats()
	check(approx(GameState.global_loc_mult, 2.0 * 3.0), "meta: mult = trial x meta (6.0)")

	GameState.meta_level = GameState.META_FINAL_LEVEL
	GameState.stats_changed.emit()
	check(Achievements._is_unlocked("meta_sisyphus"), "ach: sisyphus at final level")


func _test_format_num() -> void:
	check(GameState.format_num(999999.0) == "1.00M", "format: 999999 rolls to 1.00M")
	check(GameState.format_num(1500.0) == "1.50K", "format: 1500 = 1.50K")
	check(GameState.format_num(999.0) == "999", "format: 999 plain")
	check(GameState.format_num(0.0) == "0", "format: zero")


func _test_max_affordable() -> void:
	_fresh()
	GameState.money = 10_000.0
	var n := GameState.get_max_affordable_count("stackoverflow")
	check(n > 0, "bulk: affordable count > 0")
	check(GameState.can_buy_upgrade("stackoverflow", n), "bulk: can buy n")
	check(not GameState.can_buy_upgrade("stackoverflow", n + 1), "bulk: cannot buy n+1")
	GameState.money = 0.0
	check(GameState.get_max_affordable_count("stackoverflow") == 0, "bulk: zero funds = 0")


func _test_generator_tiers() -> void:
	_fresh()
	GameState.upgrade_owned["stackoverflow"] = 10
	GameState.recalculate_stats()
	var base_lps := GameState.loc_per_sec
	GameState.upgrade_owned["tier_stackoverflow_10"] = 1
	GameState.recalculate_stats()
	check(approx(GameState.generator_mult("stackoverflow"), 2.0), "tiers: mult x2")
	check(approx(GameState.loc_per_sec, base_lps * 2.0), "tiers: lps doubled")


func _test_bug_dilution() -> void:
	_fresh()
	GameState.bugs = 100.0
	GameState.recalculate_stats()
	var prod_small := GameState.productivity_factor()
	GameState.upgrade_owned["stackoverflow"] = 50
	GameState.recalculate_stats()
	var prod_big := GameState.productivity_factor()
	check(prod_big > prod_small, "dilution: bigger codebase hurts less")
	check(approx(prod_small, 0.5, 1e-3), "dilution: 100 bugs @ k=100 = 50%")


func _test_buffs_and_hype() -> void:
	_fresh()
	GameState.buff_type = "hype"
	check(approx(GameState.buff_loc_mult(), GameState.BUFF_HYPE_MULT), "buff: hype x7")
	check(approx(GameState.buff_click_mult(), 1.0), "buff: hype does not touch click mult")
	GameState.buff_type = "flow"
	check(approx(GameState.buff_click_mult(), GameState.BUFF_FLOW_MULT), "buff: flow x27")
	GameState.buff_type = ""

	var before := GameState.hype_events_clicked
	GameState.click_hype_event()
	check(GameState.hype_events_clicked == before + 1, "hype: click counted")


func _test_perfectionist_gate() -> void:
	_fresh()
	GameState._tick_achievement_timers(61.0)
	check(GameState.zero_bug_streak == 0.0, "perfectionist: no streak before unlock")
	GameState.click_unlocked = true
	GameState._tick_achievement_timers(61.0)
	check(GameState.zero_bug_streak >= 60.0, "perfectionist: streak after unlock")
	check(Achievements._is_unlocked("perfectionist"), "ach: perfectionist condition")


func _test_deploy_risk() -> void:
	_fresh()
	GameState.recalculate_stats()
	var chance_clean := GameState.deploy_incident_chance()
	if chance_clean == 0.0:
		check(true, "deploy risk: safe at full prod (no friday bonus)")
	else:
		check(approx(chance_clean, 0.10), "deploy risk: only friday bonus at full prod")

	GameState.bugs = 10000.0
	GameState.recalculate_stats()
	check(GameState.productivity_factor() < 0.5, "deploy risk: prod below safe")
	var chance_risky := GameState.deploy_incident_chance()
	check(chance_risky > 0.0, "deploy risk: chance > 0 when prod low")

	GameState.loc = 100.0
	GameState.money = 0.0
	GameState.incidents_survived = 0
	var bugs_before := GameState.bugs
	var safe_earned := GameState.deploy(0.99)
	check(safe_earned > 0.0, "deploy risk: high roll pays out")
	check(GameState.incidents_survived == 0, "deploy risk: high roll no incident")
	check(approx(GameState.bugs, bugs_before), "deploy risk: high roll bugs unchanged")

	GameState.loc = 100.0
	GameState.money = 0.0
	bugs_before = GameState.bugs
	var bad_earned := GameState.deploy(0.0)
	check(approx(bad_earned, safe_earned * 0.5), "deploy risk: incident halves payout")
	check(GameState.bugs > bugs_before, "deploy risk: incident adds bugs")
	check(GameState.incidents_survived == 1, "deploy risk: survived counter +1")
	check(Achievements._is_unlocked("incident_10") == false, "deploy risk: ach not yet at 1")


func _test_save_load_roundtrip() -> void:
	_fresh()
	GameState.loc = 123.0
	GameState.money = 456.0
	GameState.meta_level = 2
	GameState.hype_events_clicked = 7
	GameState.save_game()
	GameState.loc = 0.0
	GameState.money = 0.0
	GameState.meta_level = 0
	GameState.hype_events_clicked = 0
	check(GameState.load_game(), "save: load ok")
	check(approx(GameState.loc, 123.0), "save: loc restored")
	check(approx(GameState.money, 456.0), "save: money restored")
	check(GameState.meta_level == 2, "save: meta level restored")
	check(GameState.hype_events_clicked == 7, "save: hype counter restored")


func _backup_user_files() -> void:
	for path: String in USER_FILES:
		if FileAccess.file_exists(path):
			var f := FileAccess.open(path, FileAccess.READ)
			if f != null:
				_backup[path] = f.get_buffer(f.get_length())
				f.close()


func _restore_user_files() -> void:
	for path: String in USER_FILES:
		if _backup.has(path):
			var f := FileAccess.open(path, FileAccess.WRITE)
			if f != null:
				f.store_buffer(_backup[path])
				f.close()
		else:
			var dir := DirAccess.open("user://")
			var fname := path.trim_prefix("user://")
			if dir != null and dir.file_exists(fname):
				dir.remove(fname)
