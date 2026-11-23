extends RefCounted

var speaker_name: String
var parallel_world_text: bool
var _portraits: Dictionary
var _speakers: Dictionary
var _blocks: Dictionary
var _block_id: String
var _line_index := 0


func _init(display_name: String, portraits: Dictionary, blocks: Dictionary, entry: String, speakers: Dictionary = {}, parallel := false) -> void:
	speaker_name = display_name
	parallel_world_text = parallel
	_portraits = portraits
	_speakers = speakers
	_blocks = blocks
	_block_id = entry


func portrait_for(world: int) -> Texture2D:
	var speaker_id: String = _current_line().get("speaker_id", "")
	var portraits: Dictionary = _portraits if speaker_id.is_empty() else _speakers[speaker_id]["portraits"]
	return portraits.get(world) as Texture2D


func current_speaker_name() -> String:
	var speaker_id: String = _current_line().get("speaker_id", "")
	return speaker_name if speaker_id.is_empty() else _speakers[speaker_id]["name"]


func resume_at(previous: RefCounted) -> void:
	_block_id = previous.get("_block_id")
	_line_index = previous.get("_line_index")


func current_text() -> String:
	return _current_line()["text"]


func is_player_line() -> bool:
	return _current_line()["player"]


func is_narration() -> bool:
	return _current_line().get("speaker_id", "") == "narrator"


func option_labels() -> Array[String]:
	var labels: Array[String] = []
	for choice in _choices():
		labels.append(choice["text"])
	return labels


func has_choices() -> bool:
	return not _choices().is_empty()


func has_next_line() -> bool:
	return _has_more_lines() or _blocks[_block_id]["next"] != ""


func advance() -> bool:
	if _has_more_lines():
		_line_index += 1
		return true

	var next: String = _blocks[_block_id]["next"]
	if next.is_empty():
		return false

	_enter_block(next)
	return true


func choose(index: int) -> void:
	var choices := _choices()
	if index >= 0 and index < choices.size():
		_enter_block(choices[index]["next"])


func _current_line() -> Dictionary:
	return _blocks[_block_id]["lines"][_line_index]


func _has_more_lines() -> bool:
	var lines: Array[Dictionary] = _blocks[_block_id]["lines"]
	return _line_index + 1 < lines.size()


func _choices() -> Array[Dictionary]:
	if _has_more_lines():
		return []
	return _blocks[_block_id]["choices"]


func _enter_block(block_id: String) -> void:
	_block_id = block_id
	_line_index = 0
