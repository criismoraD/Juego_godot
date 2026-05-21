extends Node
## Logger centralizado para todo el proyecto
## Proporciona logging estructurado con niveles, colores y opcionalmente escritura a archivo

signal log_message(level: String, message: String, data: Dictionary)

enum LogLevel {
	DEBUG,
	INFO,
	WARNING,
	ERROR,
	CRITICAL
}

var _log_to_file: bool = false
var _log_file_path: String = ""
var _file: FileAccess
var _colors: Dictionary = {
	LogLevel.DEBUG: Color.CYAN,
	LogLevel.INFO: Color.GREEN,
	LogLevel.WARNING: Color.YELLOW,
	LogLevel.ERROR: Color.RED,
	LogLevel.CRITICAL: Color.DARK_RED
}
var _level_names: Dictionary = {
	LogLevel.DEBUG: "DEBUG",
	LogLevel.INFO: "INFO",
	LogLevel.WARNING: "WARN",
	LogLevel.ERROR: "ERROR",
	LogLevel.CRITICAL: "CRIT"
}

func _ready() -> void:
	_initialize_log_file()


func _initialize_log_file() -> void:
	if _log_to_file and _log_file_path.is_empty():
		_log_file_path = OS.get_executable_path().get_base_dir() + "/game.log"
		_open_log_file()


func _open_log_file() -> void:
	_file = FileAccess.open(_log_file_path, FileAccess.WRITE)
	if not _file:
		push_error("Logger: No se pudo abrir el archivo de log: " + _log_file_path)
		_log_to_file = false


func enable_file_logging(enable: bool, path: String = "") -> void:
	_log_to_file = enable
	if enable and not path.is_empty():
		_log_file_path = path
		_open_log_file()
	elif enable:
		_initialize_log_file()
	elif _file:
		_file.close()
		_file = null


func debug(message: String, data: Dictionary = {}) -> void:
	_log(LogLevel.DEBUG, message, data)


func info(message: String, data: Dictionary = {}) -> void:
	_log(LogLevel.INFO, message, data)


func warning(message: String, data: Dictionary = {}) -> void:
	_log(LogLevel.WARNING, message, data)


func error(message: String, data: Dictionary = {}) -> void:
	_log(LogLevel.ERROR, message, data)


func critical(message: String, data: Dictionary = {}) -> void:
	_log(LogLevel.CRITICAL, message, data)


func _log(level: LogLevel, message: String, data: Dictionary) -> void:
	var timestamp: String = Time.get_datetime_string_from_system(true)
	var level_name: String = _level_names[level]
	var color: Color = _colors[level]
	
	var formatted_message: String = "[%s] [%s] %s" % [timestamp, level_name, message]
	
	if not data.is_empty():
		formatted_message += " | " + str(data)
	
	_print_colored(formatted_message, color)
	
	if _log_to_file and _file:
		_file.store_line(formatted_message)
	
	log_message.emit(level_name, message, data)
	
	if level == LogLevel.CRITICAL:
		push_error(formatted_message)


func _print_colored(message: String, color: Color) -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_TERM_COLORS):
		var color_code: String = _get_ansi_color_code(color)
		print("%s%s%s" % [color_code, message, "\033[0m"])
	else:
		print(message)


func _get_ansi_color_code(color: Color) -> String:
	if color == Color.CYAN:
		return "\033[36m"
	elif color == Color.GREEN:
		return "\033[32m"
	elif color == Color.YELLOW:
		return "\033[33m"
	elif color == Color.RED or color == Color.DARK_RED:
		return "\033[31m"
	return "\033[37m"


func get_recent_logs(count: int = 50) -> Array[String]:
	if not _file:
		return []
	
	_file.seek(0)
	var all_lines: Array[String] = []
	while not _file.eof_reached():
		all_lines.append(_file.get_line())
	
	var start_index: int = max(0, all_lines.size() - count)
	return all_lines.slice(start_index)


func clear_log_file() -> void:
	if _file:
		_file.close()
		_file = FileAccess.open(_log_file_path, FileAccess.WRITE)
		if _file:
			_file.close()
			_open_log_file()


func _exit_tree() -> void:
	if _file:
		_file.close()
