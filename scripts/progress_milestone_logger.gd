extends RefCounted
class_name ProgressMilestoneLogger

const KEY_FIRST_UPGRADE := "first_upgrade"
const KEY_FIRST_DEPLOY := "first_deploy"
const KEY_MONEY_100 := "money_100"
const KEY_MONEY_1000 := "money_1000"
const KEY_MONEY_100K := "money_100k"
const KEY_MONEY_1M := "money_1m"
const KEY_FIRST_PRESTIGE := "first_prestige"

const MONEY_THRESHOLDS := [
	{"key": KEY_MONEY_100, "amount": 100.0, "label": "$100 reached"},
	{"key": KEY_MONEY_1000, "amount": 1000.0, "label": "$1000 reached"},
	{"key": KEY_MONEY_100K, "amount": 100_000.0, "label": "$100k reached"},
	{"key": KEY_MONEY_1M, "amount": 1_000_000.0, "label": "$1M (prestige) reached"},
]

var _enabled := false
var _session_start_msec: int = 0
var _clicks: int = 0
var _hit: Dictionary = {}
var _log_lines: PackedStringArray = []


func begin() -> void:
	_enabled = true
	_session_start_msec = Time.get_ticks_msec()
	_clicks = 0
	_hit.clear()
	_log_lines.clear()


func reset_session() -> void:
	if not _enabled:
		return
	_session_start_msec = Time.get_ticks_msec()
	_clicks = 0
	_hit.clear()
	_log_lines.clear()


func sync_from_save(state: Node) -> void:
	if not _enabled:
		return

	var total_upgrades := 0
	for upgrade_id: String in state.upgrade_owned:
		total_upgrades += int(state.upgrade_owned.get(upgrade_id, 0))
	if total_upgrades > 0:
		_hit[KEY_FIRST_UPGRADE] = true

	if float(state.money) > 0.0:
		_hit[KEY_FIRST_DEPLOY] = true

	_sync_money_milestones(float(state.money))

	if float(state.prestige_mult) > 1.001:
		_hit[KEY_FIRST_PRESTIGE] = true


func record_click() -> void:
	if not _enabled:
		return
	_clicks += 1


func on_upgrade_purchased(state: Node) -> void:
	_try_hit(KEY_FIRST_UPGRADE, "first upgrade purchased", state)


func on_deploy(state: Node) -> void:
	_try_hit(KEY_FIRST_DEPLOY, "first deploy", state)
	_check_money_milestones(state)


func on_prestige(state: Node) -> void:
	_try_hit(KEY_FIRST_PRESTIGE, "first prestige", state)


func _sync_money_milestones(money: float) -> void:
	for entry: Dictionary in MONEY_THRESHOLDS:
		if money >= float(entry["amount"]):
			_hit[entry["key"]] = true


func _try_hit(key: String, label: String, state: Node) -> void:
	if not _enabled or _hit.get(key, false):
		return
	_hit[key] = true
	_log(label, state)


func _check_money_milestones(state: Node) -> void:
	var money := float(state.money)
	for entry: Dictionary in MONEY_THRESHOLDS:
		var key: String = entry["key"]
		if _hit.get(key, false):
			continue
		if money >= float(entry["amount"]):
			_hit[key] = true
			_log(str(entry["label"]), state)


func _log(label: String, state: Node) -> void:
	var elapsed_sec := (Time.get_ticks_msec() - _session_start_msec) / 1000.0
	var loc_rate := _effective_loc_per_sec(state)
	var line := "[MILESTONE] %s at %s (clicks: %d, loc/s: %s)" % [
		label,
		_format_elapsed(elapsed_sec),
		_clicks,
		_format_loc_rate(loc_rate),
	]
	print(line)
	_log_lines.append(line)


func get_log_text() -> String:
	if _log_lines.is_empty():
		return "Поки немає віх. Грай далі — дані з'являться."
	return "\n".join(_log_lines)


func has_log() -> bool:
	return not _log_lines.is_empty()


func _effective_loc_per_sec(state: Node) -> float:
	var prod := 1.0
	if state.has_method("productivity_factor"):
		prod = float(state.productivity_factor())
	return float(state.loc_per_sec) * float(state.prestige_mult) * prod


func _format_elapsed(seconds: float) -> String:
	var total_sec := maxi(0, int(floor(seconds)))
	return "%d:%02d" % [total_sec / 60, total_sec % 60]


func _format_loc_rate(rate: float) -> String:
	if not is_finite(rate) or rate <= 0.0:
		return "0"
	return "%.1f" % snapped(rate, 0.1)
