extends RefCounted
class_name UpgradeCatalog

enum EffectType {
	LOC_PER_SEC,
	LOC_PER_CLICK_ADD,
	LOC_PER_CLICK_MULT,
	QA_POWER,
	DEPLOY_RATE,
	UNLOCK_CLICK,
}

const DEFAULT_MAX_OWNED := 999_999


static func all() -> Array[Dictionary]:
	return [
		# Onboarding
		{
			"id": "vibecode_click",
			"name": "Почати вайбкодити",
			"base_cost": 1.0,
			"effect_type": EffectType.UNLOCK_CLICK,
			"effect_value": 0.0,
			"effect_label": "1 LoC",
			"meme": "Нащо писати код, коли можна просто клікати?",
			"category": "onboarding",
			"max_owned": 1,
		},
		# Generators
		{
			"id": "stackoverflow",
			"name": "Stack Overflow Premium",
			"base_cost": 5.0,
			"effect_type": EffectType.LOC_PER_SEC,
			"effect_value": 0.2,
			"effect_label": "+0.2 LoC/s",
			"meme": "Копіпаст без капчі",
			"category": "generators",
			"max_owned": 150,
		},
		{
			"id": "chatgpt",
			"name": "ChatGPT Plus",
			"base_cost": 100.0,
			"effect_type": EffectType.LOC_PER_SEC,
			"effect_value": 1.0,
			"effect_label": "+1 LoC/s",
			"meme": "Він пише, ти кермуєш",
			"category": "generators",
		},
		{
			"id": "junior",
			"name": "Молодший джун",
			"base_cost": 500.0,
			"effect_type": EffectType.LOC_PER_SEC,
			"effect_value": 4.0,
			"effect_label": "+4 LoC/s",
			"meme": "Дешевий, але треба ревʼюити",
			"category": "generators",
		},
		{
			"id": "youtube_senior",
			"name": "Сіньйор з YouTube",
			"base_cost": 3000.0,
			"effect_type": EffectType.LOC_PER_SEC,
			"effect_value": 20.0,
			"effect_label": "+20 LoC/s",
			"meme": "Подивився туторіал — вже експерт",
			"category": "generators",
		},
		{
			"id": "ai_army",
			"name": "Армія AI-агентів",
			"base_cost": 20000.0,
			"effect_type": EffectType.LOC_PER_SEC,
			"effect_value": 120.0,
			"effect_label": "+120 LoC/s",
			"meme": "Вони не сплять, вони деплоять",
			"category": "generators",
		},
		# Click
		{
			"id": "mech_keyboard",
			"name": "Механічна клава",
			"base_cost": 50.0,
			"effect_type": EffectType.LOC_PER_CLICK_ADD,
			"effect_value": 1.0,
			"effect_label": "+1 LoC/click",
			"meme": "Клац-клац дофамін",
			"category": "click",
		},
		{
			"id": "two_hands",
			"name": "Дві руки",
			"base_cost": 300.0,
			"effect_type": EffectType.LOC_PER_CLICK_MULT,
			"effect_value": 2.0,
			"effect_label": "×2 LoC/click",
			"meme": "Хто сказав що одна?",
			"category": "click",
			"max_owned": 1,
		},
		{
			"id": "autocomplete",
			"name": "Tab-tab-tab автокомпліт",
			"base_cost": 2000.0,
			"effect_type": EffectType.LOC_PER_CLICK_ADD,
			"effect_value": 5.0,
			"effect_label": "+5 LoC/click",
			"meme": "IntelliSense головного мозку",
			"category": "click",
		},
		# QA
		{
			"id": "linter",
			"name": "Лінтер",
			"base_cost": 200.0,
			"effect_type": EffectType.QA_POWER,
			"effect_value": 0.5,
			"effect_label": "+0.5 QA/s",
			"meme": "Червоні підкреслення сорому",
			"category": "qa",
		},
		{
			"id": "unit_tests",
			"name": "Юніт-тести",
			"base_cost": 1500.0,
			"effect_type": EffectType.QA_POWER,
			"effect_value": 3.0,
			"effect_label": "+3 QA/s",
			"meme": "Зелененькі галочки = дофамін",
			"category": "qa",
		},
		{
			"id": "qa_engineer",
			"name": "QA-інженер",
			"base_cost": 10000.0,
			"effect_type": EffectType.QA_POWER,
			"effect_value": 15.0,
			"effect_label": "+15 QA/s",
			"meme": "Той хто знаходить твій сором",
			"category": "qa",
		},
		# Deploy
		{
			"id": "cicd",
			"name": "CI/CD пайплайн",
			"base_cost": 800.0,
			"effect_type": EffectType.DEPLOY_RATE,
			"effect_value": 0.05,
			"effect_label": "+0.05 $/LoC",
			"meme": "Деплой у пʼятницю? Сміливо",
			"category": "deploy",
		},
		{
			"id": "cloud_hosting",
			"name": "Хмарний хостинг",
			"base_cost": 5000.0,
			"effect_type": EffectType.DEPLOY_RATE,
			"effect_value": 0.15,
			"effect_label": "+0.15 $/LoC",
			"meme": "Чужий компʼютер за твої гроші",
			"category": "deploy",
		},
	]


static func find(id: String) -> Dictionary:
	for def: Dictionary in all():
		if def["id"] == id:
			return def
	return {}


static func get_max_owned(def: Dictionary) -> int:
	return int(def.get("max_owned", DEFAULT_MAX_OWNED))


static func costs_loc(def: Dictionary) -> bool:
	return def.get("effect_type") == EffectType.UNLOCK_CLICK


static func format_total_effect(def: Dictionary, owned: int, format_num: Callable) -> String:
	if owned <= 0:
		return ""
	var value := float(def["effect_value"])
	match def["effect_type"]:
		EffectType.LOC_PER_SEC:
			return "разом: +%s код/с" % format_num.call(value * owned)
		EffectType.LOC_PER_CLICK_ADD:
			return "разом: +%s код/клік" % format_num.call(value * owned)
		EffectType.LOC_PER_CLICK_MULT:
			return "разом: ×%s клік" % format_num.call(pow(value, owned))
		EffectType.QA_POWER:
			return "разом: +%s QA/с" % format_num.call(value * owned)
		EffectType.DEPLOY_RATE:
			return "разом: +%s $/код" % format_num.call(value * owned)
		EffectType.UNLOCK_CLICK:
			return ""
	return ""
