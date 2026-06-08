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





static func all() -> Array[Dictionary]:

	return [

		# CORE

		{

			"id": "sk_caffeine",

			"name": "Кофеїн IV",

			"branch": "core",

			"cost": 1,

			"requires": [],

			"meme": "Кров стала кавою",

			"effects": [{"type": EffectType.GLOBAL_LOC_MULT, "value": 1.2}],

		},

		{

			"id": "sk_so_premium",

			"name": "Stack Overflow Premium",

			"branch": "core",

			"cost": 2,

			"requires": [],

			"meme": "Копіпаст без капчі, назавжди",

			"effects": [{"type": EffectType.UPGRADE_COST_MULT, "value": 0.9}],

		},

		{

			"id": "sk_copilot",

			"name": "GitHub Copilot",

			"branch": "core",

			"cost": 2,

			"requires": [],

			"meme": "Твій друг уже на $500",

			"effects": [{"type": EffectType.PRESTIGE_START_MONEY, "value": 500.0}],

		},

		# SENIOR

		{

			"id": "sk_fast_fingers",

			"name": "Швидкі пальці",

			"branch": "senior",

			"cost": 1,

			"requires": ["sk_caffeine"],

			"meme": "Ctrl+C Ctrl+V на стероїдах",

			"effects": [{"type": EffectType.LOC_CLICK_MULT, "value": 1.5}],

		},

		{

			"id": "sk_deadline_stress",

			"name": "Дедлайн завтра",

			"branch": "senior",

			"cost": 2,

			"requires": ["sk_fast_fingers"],

			"meme": "Працює краще під тиском (коли вже пізно)",

			"effects": [{"type": EffectType.LOC_CLICK_MULT, "value": 1.5}],

		},

		{

			"id": "sk_mech_keyboard",

			"name": "Механічна клавіатура",

			"branch": "senior",

			"cost": 3,

			"requires": ["sk_fast_fingers"],

			"meme": "Клац-клац навіть коли ти AFK",

			"effects": [{"type": EffectType.AUTO_CLICK, "value": 1.0}],

		},

		{

			"id": "sk_rsi",

			"name": "RSI",

			"branch": "senior",

			"cost": 3,

			"requires": ["sk_deadline_stress"],

			"meme": "Біль = продуктивність. Ну, майже.",

			"effects": [

				{"type": EffectType.LOC_CLICK_MULT, "value": 2.0},

				{"type": EffectType.PRODUCTIVITY_MULT, "value": 0.9},

			],

		},

		{

			"id": "sk_he_is_different",

			"name": "He is different",

			"branch": "senior",

			"cost": 5,

			"requires": ["sk_rsi", "sk_mech_keyboard"],

			"meme": "10x engineer energy",

			"effects": [{"type": EffectType.LOC_CLICK_MULT, "value": 2.5}],

		},

		# VIBE

		{

			"id": "sk_autocomplete",

			"name": "Autocomplete++",

			"branch": "vibe",

			"cost": 1,

			"requires": ["sk_caffeine"],

			"meme": "Tab tab tab tab tab",

			"effects": [{"type": EffectType.LOC_SEC_MULT, "value": 1.3}],

		},

		{

			"id": "sk_prompt_eng",

			"name": "Prompt engineering",

			"branch": "vibe",

			"cost": 2,

			"requires": ["sk_autocomplete"],

			"meme": "Напиши мені код, але epic",

			"effects": [{"type": EffectType.LOC_SEC_MULT, "value": 1.3}],

		},

		{

			"id": "sk_bg_agent",

			"name": "Background agent",

			"branch": "vibe",

			"cost": 3,

			"requires": ["sk_autocomplete"],

			"meme": "Кодиться навіть коли ти в душі",

			"effects": [{"type": EffectType.OFFLINE_PROGRESS, "value": 1.0}],

		},

		{

			"id": "sk_generate_all",

			"name": "Generate all",

			"branch": "vibe",

			"cost": 2,

			"requires": ["sk_prompt_eng"],

			"meme": "Accept all. Regret later.",

			"effects": [{"type": EffectType.DEPLOY_RATE_MULT, "value": 1.5}],

		},

		{

			"id": "sk_singularity",

			"name": "Singularity",

			"branch": "vibe",

			"cost": 5,

			"requires": ["sk_bg_agent", "sk_generate_all"],

			"meme": "AGI написав баги швидше за тебе",

			"effects": [

				{"type": EffectType.LOC_SEC_MULT, "value": 2.2},

				{"type": EffectType.BUG_RATE_MULT, "value": 1.2},

			],

		},

		# QA

		{

			"id": "sk_ide_linter",

			"name": "IDE linter",

			"branch": "qa",

			"cost": 1,

			"requires": ["sk_caffeine"],

			"meme": "Червона лінія = особиста образа",

			"effects": [{"type": EffectType.QA_POWER_MULT, "value": 1.5}],

		},

		{

			"id": "sk_code_review",

			"name": "Code review",

			"branch": "qa",

			"cost": 2,

			"requires": ["sk_ide_linter"],

			"meme": "LGTM (Looks Good To Me)",

			"effects": [{"type": EffectType.BUG_GROWTH_MULT, "value": 0.75}],

		},

		{

			"id": "sk_cicd",

			"name": "CI/CD pipeline",

			"branch": "qa",

			"cost": 3,

			"requires": ["sk_code_review"],

			"meme": "Build passed. Prod on fire.",

			"effects": [{"type": EffectType.AUTO_QA, "value": 2.0}],

		},

		{

			"id": "sk_zero_bugs",

			"name": "Zero bugs policy",

			"branch": "qa",

			"cost": 5,

			"requires": ["sk_cicd"],

			"meme": "Продуктивність ніколи не падає нижче 50%",

			"effects": [{"type": EffectType.PRODUCTIVITY_FLOOR, "value": 0.5}],

		},

	]





static func find(id: String) -> Dictionary:

	for def: Dictionary in all():

		if def["id"] == id:

			return def

	return {}





static func branch_nodes(branch: String) -> Array[Dictionary]:

	var result: Array[Dictionary] = []

	for def: Dictionary in all():

		if def["branch"] == branch:

			result.append(def)

	return result





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

