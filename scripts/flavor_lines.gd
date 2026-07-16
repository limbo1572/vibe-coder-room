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

const SAVE_PATH := "user://flavor_seen.json"

var _shown: Dictionary = {}


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
