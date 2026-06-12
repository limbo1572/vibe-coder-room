extends RefCounted
class_name ProgressMilestoneLogger

const KEY_FIRST_UPGRADE := "first_upgrade"
const KEY_FIRST_DEPLOY := "first_deploy"
const KEY_MONEY_100 := "money_100"
const KEY_MONEY_1000 := "money_1000"
const KEY_MONEY_100K := "money_100k"
const KEY_MONEY_1M := "money_1m"
const KEY_PRESTIGE_THRESHOLD := "prestige_threshold"
const KEY_FIRST_PRESTIGE := "first_prestige"

const MONEY_THRESHOLDS := [
	{"key": KEY_MONEY_100, "amount": 100.0, "label": "$100 reached"},
	{"key": KEY_MONEY_1000, "amount": 1000.0, "label": "$1000 reached"},
	{"key": KEY_MONEY_100K, "amount": 100_000.0, "label": "$100k reached"},
	{"key": KEY_MONEY_1M, "amount": 1_000_000.0, "label": "$1M reached"},
]

var _enabled := false
var _clicks: int = 0
var _hit: Dictionary = {}
var _log_lines: PackedStringArray = []


func begin() -> void:
	_enabled = true
	_clicks = 0


func serialize() -> Dictionary:
	var lines: Array = []
	for line in _log_lines:
		lines.append(line)
	return {
		"log_lines": lines,
		"hit": _hit.duplicate(),
	}


func restore(data: Dictionary) -> void:
	var lines: Array = data.get("log_lines", [])
	_log_lines = PackedStringArray()
	for l in lines:
		_log_lines.append(str(l))
	var hit_raw: Dictionary = data.get("hit", {})
	_hit.clear()
	for k in hit_raw:
		_hit[str(k)] = bool(hit_raw[k])


func reset_session(state: Node = null) -> void:
	if not _enabled:
		return
	_clicks = 0
	_hit.clear()
	_log_lines.append(_cycle_marker_line(state))


func sync_from_save(state: Node) -> void:
	if not _enabled:
		return
	if not _hit.is_empty():
		return

	var total_upgrades := 0
	for upgrade_id: String in state.upgrade_owned:
		total_upgrades += int(state.upgrade_owned.get(upgrade_id, 0))
	if total_upgrades > 0:
		_mark_offline_hit(KEY_FIRST_UPGRADE, "first upgrade purchased", state)

	if float(state.money) > 0.0:
		_mark_offline_hit(KEY_FIRST_DEPLOY, "first deploy", state)

	var money := float(state.money)
	for entry: Dictionary in MONEY_THRESHOLDS:
		if money >= float(entry["amount"]):
			_mark_offline_hit(str(entry["key"]), str(entry["label"]), state)

	if state.has_method("prestige_threshold") and money >= float(state.prestige_threshold()):
		_mark_offline_prestige_threshold(state)

	if float(state.prestige_mult) > 1.001:
		_mark_offline_hit(KEY_FIRST_PRESTIGE, "first prestige", state)


func record_click() -> void:
	if not _enabled:
		return
	_clicks += 1


func on_upgrade_purchased(state: Node) -> void:
	_try_hit(KEY_FIRST_UPGRADE, "first upgrade purchased", state)


func on_deploy(state: Node) -> void:
	_try_hit(KEY_FIRST_DEPLOY, "first deploy", state)
	_check_money_milestones(state)
	_check_prestige_threshold_milestone(state)


func on_prestige(state: Node) -> void:
	_try_hit(KEY_FIRST_PRESTIGE, "first prestige", state)
	_hit.erase(KEY_PRESTIGE_THRESHOLD)
	_log_lines.append(_cycle_marker_line(state))


func _mark_offline_hit(key: String, label: String, state: Node) -> void:
	if _hit.get(key, false):
		return
	_hit[key] = true
	_log(label, state, true)


func _mark_offline_prestige_threshold(state: Node) -> void:
	if _hit.get(KEY_PRESTIGE_THRESHOLD, false):
		return
	_hit[KEY_PRESTIGE_THRESHOLD] = true
	_log_prestige_threshold(state, true)


func _try_hit(key: String, label: String, state: Node) -> void:
	if not _enabled or _hit.get(key, false):
		return
	_hit[key] = true
	_log(label, state)


func _check_money_milestones(state: Node) -> void:
	if not _enabled:
		return
	var money := float(state.money)
	for entry: Dictionary in MONEY_THRESHOLDS:
		var key: String = entry["key"]
		if _hit.get(key, false):
			continue
		if money >= float(entry["amount"]):
			_hit[key] = true
			_log(str(entry["label"]), state)


func _check_prestige_threshold_milestone(state: Node) -> void:
	if not _enabled or _hit.get(KEY_PRESTIGE_THRESHOLD, false):
		return
	if not state.has_method("prestige_threshold"):
		return
	if float(state.money) < float(state.prestige_threshold()):
		return
	_hit[KEY_PRESTIGE_THRESHOLD] = true
	_log_prestige_threshold(state)


func _log_prestige_threshold(state: Node, offline: bool = false) -> void:
	var threshold := float(state.prestige_threshold())
	var label := "prestige threshold ($%s) reached" % _format_money(state, threshold)
	_log(label, state, offline)


func _cycle_marker_line(state: Node) -> String:
	if state == null or not state.has_method("prestige_threshold"):
		return "--- prestige, new cycle ---"
	var count := int(state.get("prestige_count"))
	var next_threshold := _format_money(state, float(state.prestige_threshold()))
	return "--- prestige #%d, new cycle (next threshold $%s) ---" % [count, next_threshold]


func _log(label: String, state: Node, offline: bool = false) -> void:
	var elapsed_sec := float(state.total_play_time)
	var time_str := _format_elapsed(elapsed_sec)
	if offline:
		time_str += " [offline]"
	var clicks_str := "-" if offline else str(_clicks)
	var loc_rate := _effective_loc_per_sec(state)
	var line := "[MILESTONE] %s at %s (clicks: %s, loc/s: %s)" % [
		label,
		time_str,
		clicks_str,
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


func _format_money(state: Node, amount: float) -> String:
	if state.has_method("format_num"):
		return str(state.format_num(amount))
	return str(amount)


func _format_elapsed(seconds: float) -> String:
	var total_sec := maxi(0, int(floor(seconds)))
	return "%d:%02d" % [total_sec / 60, total_sec % 60]


func _format_loc_rate(rate: float) -> String:
	if not is_finite(rate) or rate <= 0.0:
		return "0"
	return "%.1f" % snapped(rate, 0.1)
