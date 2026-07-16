extends Node

signal flavor_triggered(line: Dictionary)

const GENERATOR_LINES := {
	"stackoverflow": "Тепер ти копіпастиш швидше за світло. Розуміти не обов'язково.",
	"chatgpt": "Тепер нас двоє пишемо. Ну, один.",
	"junior": "Найняв людину ревʼюити код, який пишу я. Людям теж треба їсти, мабуть.",
	"youtube_senior": "Подивився туторіал. Тепер експерт. Як і всі тут.",
	"ai_army": "Я найняв себе. Багато себе. Ми працюємо 24/7. Ти можеш йти. Байдуже.",
}

const PRESTIGE_TEXTS := [
	"Цей код — смітник. Переписуємо на React. Тепер усе компонентами. Чисто? Чисто.",
	"React застарів поки ми писали. Svelte. Тепер точно.",
	"Власне... Rust. Безпечно. Швидко. Ніхто не розуміє. Ідеально.",
	"Go. Бо всі побігли. І ми побіжимо.",
	"Знаєш що? Я перепишу сам. Тобі не треба розуміти на чому.",
	"Я більше не питаю на чому. Я просто переписую. Знову. І знову.",
]

const PRESTIGE_TEXT_CYCLE := "Ти ще тут? Добре. Я теж. Поїхали ще раз."

const TICKER_GENERIC: Array[String] = [
	"Новий JS-фреймворк вийшов, поки ти читав цей рядок",
	"Опитування: 98% сіньйорів гуглять «як центрувати div»",
	"Стартап залучив $40M на ідею «Uber, але для качок»",
	"ШІ пройшов співбесіду у FAANG. Рекрутер не помітив",
	"Дедлайн перенесли: тепер учора",
	"Програміст вийшов на пенсію. Його TODO живе далі",
	"Курс «Вайбкодинг за 7 днів» купили 2 млн людей. Випустились троє",
	"Компанія замінила відділ QA на молитву",
	"Вчені: 80% коду на Землі ніхто ніколи не читав",
	"Мітинг про скорочення мітингів затягнувся на 4 години",
	"Стендап тривав довше за спринт",
	"Тімлід відкрив прод о 3 ночі. Прод відкрив тімліда",
	"Продакт вивчив слово «мікросервіси». Всім приготуватись",
	"git blame показав твоє імʼя. Ти там ніколи не працював",
]

const TICKER_BUGS: Array[String] = [
	"Баг-трекер компанії визнано найбільшою БД країни",
	"Користувачі кажуть «фіча». Розробники мовчать",
	"Новий баг зʼявився швидше, ніж закрили старий. Знову",
]

const TICKER_RICH: Array[String] = [
	"Forbes додав тебе у список «ІТ-люди, що не виходять з дому»",
	"Твій бухгалтер більше не сміється з слова «крипта»",
]

const TICKER_LEGACY: Array[String] = [
	"💀 Хтось торкнувся legacy. Свічки запалено",
	"Аналітики: твій код підозріло швидкий. І підозрілий",
]

const TICKER_META: Array[String] = [
	"Симуляція стабільна. Продовжуй клікати",
	"Цей заголовок згенеровано. Як і попередній. Як і ти",
]

const TICKER_PRESTIGE: Array[String] = [
	"Індустрія переписала все на новий фреймворк. Знову",
	"Опитування: «цього разу буде чисто» — вірять 100% опитаних",
]

const TICKER_FRIDAY: Array[String] = [
	"Пʼятниця, 17:00. Хтось десь тисне deploy. Помолимось",
]

const SAVE_PATH := "user://flavor_seen.json"

var _shown: Dictionary = {}
var _last_ticker := ""


func _ready() -> void:
	load_shown()


func trigger(event_id: String, ctx: Dictionary = {}) -> void:
	match event_id:
		"first_upgrade":
			_emit_once("first_upgrade", "copilot", "Бачиш? Не треба вчитися. Треба купувати.")
		"first_deploy":
			_emit_once("first_deploy", "copilot", "git push. Воно в проді. Працює? Не питай. Працює.")
		"money_1000":
			_emit_once(
				"money_1000",
				"copilot",
				"Перша тисяча! Ти геній. (Це я геній, але хай.)"
			)
		"generator_bought":
			var upgrade_id := str(ctx.get("upgrade_id", ""))
			if GENERATOR_LINES.has(upgrade_id):
				_emit_once(
					"generator:%s" % upgrade_id,
					"copilot",
					GENERATOR_LINES[upgrade_id]
				)
		"bug_threshold":
			_emit_bug_threshold(int(ctx.get("level", 0)))
		_:
			pass


func prestige_text(count: int) -> String:
	if count < 0:
		return PRESTIGE_TEXT_CYCLE
	if count < PRESTIGE_TEXTS.size():
		return PRESTIGE_TEXTS[count]
	return PRESTIGE_TEXT_CYCLE


func ticker_candidates() -> Array[String]:
	var out: Array[String] = []
	out.append_array(TICKER_GENERIC)
	if GameState.productivity_factor() < 0.7:
		out.append_array(TICKER_BUGS)
	if GameState.money >= 100000.0:
		out.append_array(TICKER_RICH)
	if GameState.legacy_active():
		out.append_array(TICKER_LEGACY)
	if GameState.meta_level > 0:
		out.append_array(TICKER_META)
	if GameState.prestige_count >= 1:
		out.append_array(TICKER_PRESTIGE)
	var dt := Time.get_datetime_dict_from_system()
	if int(dt.get("weekday", 0)) == 5 and int(dt.get("hour", 0)) >= 17:
		out.append_array(TICKER_FRIDAY)
	return out


func next_ticker_line(rng_roll: float = -1.0) -> String:
	var candidates := ticker_candidates()
	if candidates.is_empty():
		return ""
	var roll := randf() if rng_roll < 0.0 else rng_roll
	var index := int(roll * float(candidates.size()))
	index = clampi(index, 0, candidates.size() - 1)
	var line := candidates[index]
	if line == _last_ticker and candidates.size() > 1:
		index = (index + 1) % candidates.size()
		line = candidates[index]
	_last_ticker = line
	return line


func _emit_bug_threshold(level: int) -> void:
	match level:
		1:
			_emit_once("bug:1:compiler", "compiler", "warning: 3 unhandled exceptions.")
			_emit_once("bug:1:copilot", "copilot", "Та то фігня, потім глянемо.")
			_emit_once("bug:1:code_comment", "code_comment", "// TODO: пофіксити потім")
		2:
			_emit_once("bug:2:compiler", "compiler", "warning: technical debt rising.")
			_emit_once("bug:2:code_comment", "code_comment", "// не чіпай. працює якимось дивом.")
		3:
			_emit_once(
				"bug:3:compiler",
				"compiler",
				"warning: technical debt exceeds maintainable threshold."
			)
			_emit_once("bug:3:copilot", "copilot", "Все під контролем. Майже все. Дещо.")
			_emit_once(
				"bug:3:code_comment",
				"code_comment",
				"// AI написав це о 3 ночі. я не розумію що тут."
			)
		4:
			_emit_once("bug:4:compiler", "compiler", "error: cyclomatic complexity not measurable.")
			_emit_once("bug:4:code_comment", "code_comment", "// хто це писав. а, я. коли.")
		5:
			_emit_once(
				"bug:5:compiler",
				"compiler",
				"stack trace points outside allocated memory. context: unknown."
			)
			_emit_once(
				"bug:5:code_comment",
				"code_comment",
				"// тут має бути коментар. його теж згенерували."
			)
		_:
			pass


func _emit_once(key: String, voice: String, text: String) -> void:
	if text.is_empty() or _shown.get(key, false):
		return
	_shown[key] = true
	save_shown()
	flavor_triggered.emit({"voice": voice, "text": text})


func save_shown() -> void:
	var data := {"shown": _shown.duplicate()}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning(
			"FlavorLines: failed to save %s (err %d)" % [SAVE_PATH, FileAccess.get_open_error()]
		)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func load_shown() -> void:
	_shown.clear()
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning(
			"FlavorLines: failed to load %s (err %d)" % [SAVE_PATH, FileAccess.get_open_error()]
		)
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return

	var raw: Variant = parsed.get("shown", {})
	if typeof(raw) != TYPE_DICTIONARY:
		return

	for key: Variant in raw:
		if bool(raw[key]):
			_shown[str(key)] = true
