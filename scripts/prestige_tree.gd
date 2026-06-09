extends RefCounted
class_name PrestigeTree

enum EffectType {
	GLOBAL_LOC_MULT,
	UPGRADE_COST_MULT,
	PRESTIGE_START_MONEY,
	LOC_CLICK_MULT,
	LOC_SEC_MULT,
	DEPLOY_RATE_MULT,
	QA_POWER_MULT,
	BUG_RATE_MULT,
	BUG_GROWTH_MULT,
	PRODUCTIVITY_MULT,
	PRODUCTIVITY_FLOOR,
	AUTO_CLICK,
	AUTO_QA,
	OFFLINE_PROGRESS,
}

const ROOT_ID := "sk_root"
const ROOT_LOC_MULT := 1.1


static func all() -> Array[Dictionary]:
	return [
		{
			"id": ROOT_ID,
			"name": "Стартап-енергія",
			"desc": "Кофеїн, дедлайни і повна відсутність сну. Працює.",
			"branch": "root",
			"is_root": true,
			"repeatable": true,
			"cost": 0,
			"requires": [],
			"root_req": 0,
			"effects": [{"type": EffectType.GLOBAL_LOC_MULT, "value": ROOT_LOC_MULT}],
		},
		# Клік — «Карпальний тунель»
		{
			"id": "sk_fast_fingers",
			"name": "Швидкі пальці",
			"desc": "Ctrl+C Ctrl+V на стероїдах",
			"branch": "click",
			"cost": 1,
			"requires": [],
			"root_req": 1,
			"effects": [{"type": EffectType.LOC_CLICK_MULT, "value": 1.5}],
		},
		{
			"id": "sk_mech_kb",
			"name": "Механічна клава",
			"desc": "Клац-клац навіть коли ти AFK",
			"branch": "click",
			"cost": 2,
			"requires": ["sk_fast_fingers"],
			"root_req": 1,
			"effects": [{"type": EffectType.AUTO_CLICK, "value": 1.0}],
		},
		{
			"id": "sk_different",
			"name": "Він інакший",
			"desc": "10x engineer energy",
			"branch": "click",
			"cost": 3,
			"requires": ["sk_mech_kb"],
			"root_req": 3,
			"effects": [{"type": EffectType.LOC_CLICK_MULT, "value": 2.5}],
		},
		# Пасив — «Промпт-інженер»
		{
			"id": "sk_autocomplete",
			"name": "Автокомпліт",
			"desc": "Tab tab tab tab tab",
			"branch": "passive",
			"cost": 1,
			"requires": [],
			"root_req": 1,
			"effects": [{"type": EffectType.LOC_SEC_MULT, "value": 1.3}],
		},
		{
			"id": "sk_bg_agent",
			"name": "Фоновий агент",
			"desc": "Кодиться навіть коли ти в душі",
			"branch": "passive",
			"cost": 2,
			"requires": ["sk_autocomplete"],
			"root_req": 1,
			"effects": [{"type": EffectType.OFFLINE_PROGRESS, "value": 1.0}],
		},
		{
			"id": "sk_generate_all",
			"name": "Generate All",
			"desc": "Accept all. Regret later.",
			"branch": "passive",
			"cost": 4,
			"requires": ["sk_bg_agent"],
			"root_req": 4,
			"effects": [{"type": EffectType.LOC_SEC_MULT, "value": 3.0}],
		},
		# Баги — «Staging — це прод»
		{
			"id": "sk_linter",
			"name": "Лінтер",
			"desc": "Червона лінія = особиста образа",
			"branch": "bugs",
			"cost": 1,
			"requires": [],
			"root_req": 2,
			"effects": [{"type": EffectType.QA_POWER_MULT, "value": 1.5}],
		},
		{
			"id": "sk_one_test",
			"name": "Тести (один)",
			"desc": "LGTM (Looks Good To Me)",
			"branch": "bugs",
			"cost": 2,
			"requires": ["sk_linter"],
			"root_req": 2,
			"effects": [{"type": EffectType.BUG_RATE_MULT, "value": 0.7}],
		},
		{
			"id": "sk_auto_qa",
			"name": "Auto-QA бот",
			"desc": "Build passed. Prod on fire.",
			"branch": "bugs",
			"cost": 3,
			"requires": ["sk_one_test"],
			"root_req": 4,
			"effects": [{"type": EffectType.AUTO_QA, "value": 2.0}],
		},
		# Економіка — «Раунд фінансування»
		{
			"id": "sk_seed",
			"name": "Сід-раунд",
			"desc": "Pre-seed з дивану",
			"branch": "economy",
			"cost": 1,
			"requires": [],
			"root_req": 2,
			"effects": [{"type": EffectType.PRESTIGE_START_MONEY, "value": 500.0}],
		},
		{
			"id": "sk_cloud_discount",
			"name": "Знижка на хмару",
			"desc": "Credits expire never (almost)",
			"branch": "economy",
			"cost": 2,
			"requires": ["sk_seed"],
			"root_req": 2,
			"effects": [{"type": EffectType.UPGRADE_COST_MULT, "value": 0.9}],
		},
		{
			"id": "sk_series_b",
			"name": "Серія B",
			"desc": "Burn rate is a mindset",
			"branch": "economy",
			"cost": 3,
			"requires": ["sk_cloud_discount"],
			"root_req": 5,
			"effects": [{"type": EffectType.DEPLOY_RATE_MULT, "value": 1.5}],
		},
	]


static func find(id: String) -> Dictionary:
	for def: Dictionary in all():
		if def["id"] == id:
			return def
	return {}


static func root_def() -> Dictionary:
	return find(ROOT_ID)


static func branch_nodes(branch: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for def: Dictionary in all():
		if def.get("is_root", false):
			continue
		if def["branch"] == branch:
			result.append(def)
	return result


static func root_loc_mult(level: int) -> float:
	if level <= 0:
		return 1.0
	return pow(ROOT_LOC_MULT, level)


static func effect_summary(def: Dictionary) -> String:
	var parts: PackedStringArray = []
	for eff: Dictionary in def.get("effects", []):
		var value: float = float(eff["value"])
		match eff["type"]:
			EffectType.GLOBAL_LOC_MULT:
				parts.append("×%.2f LoC (усюди)" % value)
			EffectType.UPGRADE_COST_MULT:
				parts.append("апгрейди ×%.0f%%" % (value * 100.0))
			EffectType.PRESTIGE_START_MONEY:
				parts.append("старт після prestige $%s" % str(int(value)))
			EffectType.LOC_CLICK_MULT:
				parts.append("×%.2f клік" % value)
			EffectType.LOC_SEC_MULT:
				parts.append("×%.2f код/с" % value)
			EffectType.DEPLOY_RATE_MULT:
				parts.append("×%.2f deploy" % value)
			EffectType.QA_POWER_MULT:
				parts.append("×%.2f QA" % value)
			EffectType.BUG_RATE_MULT:
				parts.append("×%.2f баги" % value)
			EffectType.BUG_GROWTH_MULT:
				parts.append("ріст багів ×%.0f%%" % (value * 100.0))
			EffectType.PRODUCTIVITY_MULT:
				parts.append("продуктивність ×%.0f%%" % (value * 100.0))
			EffectType.PRODUCTIVITY_FLOOR:
				parts.append("мін. продуктивність %.0f%%" % (value * 100.0))
			EffectType.AUTO_CLICK:
				parts.append("+%.1f LoC/с (авто-клік)" % value)
			EffectType.AUTO_QA:
				parts.append("+%.1f QA/с" % value)
			EffectType.OFFLINE_PROGRESS:
				parts.append("офлайн-прогрес")
	return ", ".join(parts)
