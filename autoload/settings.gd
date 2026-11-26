class_name Settings
extends RefCounted
## The player's settings (volumes, tutorial done...), kept in PATH from one session to the next.
## Every setting goes through here, so the file is read once and written whole by one owner.

const PATH := "user://settings.cfg"

static var _file: ConfigFile


static func get_value(section: String, key: String, default: Variant) -> Variant:
	return _config().get_value(section, key, default)


## Sets the value and saves the file at once.
static func set_value(section: String, key: String, value: Variant) -> void:
	_config().set_value(section, key, value)
	_file.save(PATH)


static func _config() -> ConfigFile:
	if _file == null:
		_file = ConfigFile.new()
		_file.load(PATH)
	return _file
