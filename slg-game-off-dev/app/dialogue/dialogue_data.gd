extends RefCounted

const DialogueSession := preload("res://app/dialogue/dialogue_session.gd")
const DATA_DIRECTORY := "res://data/dialogue"
const WORLD_NAMES := {
	SceneRouter.World.SURFACE: "surface",
	SceneRouter.World.INNER: "inner",
}


static func load_session(dialogue_id: StringName, world: int, facts: Dictionary, locale: String) -> DialogueSession:
	var file_name := String(dialogue_id)
	if not file_name.is_valid_filename():
		push_error("Invalid dialogue ID: %s" % dialogue_id)
		return null

	var path := DATA_DIRECTORY.path_join(file_name + ".json")
	if not ResourceLoader.exists(path, "JSON"):
		push_error("Dialogue file not found: %s" % path)
		return null

	var resource := ResourceLoader.load(path, "JSON") as JSON
	if resource == null or not resource.data is Dictionary or resource.data.get("id") != file_name:
		push_error("%s must contain a dialogue object with matching id." % path)
		return null

	return create_session(resource.data, world, facts, locale)


static func create_session(definition: Dictionary, world: int, facts: Dictionary, locale: String) -> DialogueSession:
	var id := String(definition.get("id", "<unnamed>"))
	var blocks: Variant = definition.get("blocks")
	var entry: Variant = definition.get("entry")
	if not blocks is Dictionary or not entry is String or not blocks.has(entry):
		push_error("%s: entry must name an existing dialogue block." % id)
		return null
	if not WORLD_NAMES.has(world):
		push_error("%s: invalid world %s." % [id, world])
		return null

	var conditions := facts.duplicate()
	conditions["world"] = WORLD_NAMES[world]
	var english := TranslationServer.standardize_locale(locale).get_slice("_", 0) == "en"
	var speaker_name := _resolve_text(definition.get("speaker_name"), conditions, english, id + ".speaker_name")
	if speaker_name.is_empty():
		return null

	var portraits: Variant = _load_portraits(definition.get("portraits", {}), id)
	if portraits == null:
		return null
	var speakers: Variant = _prepare_speakers(definition.get("speakers", {}), conditions, english, id)
	if speakers == null:
		return null
	var parallel: Variant = definition.get("parallel_world_text", false)
	if not parallel is bool:
		push_error("%s.parallel_world_text must be a boolean." % id)
		return null

	var resolved_blocks := {}
	for block_id: String in blocks:
		var location := "%s.blocks.%s" % [id, block_id]
		var block := _prepare_block(blocks[block_id], blocks, conditions, english, location, speakers)
		if block.is_empty():
			return null
		resolved_blocks[block_id] = block
	return DialogueSession.new(speaker_name, portraits, resolved_blocks, entry, speakers, parallel)


static func _prepare_speakers(value: Variant, conditions: Dictionary, english: bool, id: String) -> Variant:
	if not value is Dictionary:
		push_error("%s.speakers must be an object." % id)
		return null
	var speakers := {}
	for key: String in value:
		var profile: Variant = value[key]
		var location := "%s.speakers.%s" % [id, key]
		if not profile is Dictionary:
			push_error("%s must be an object." % location)
			return null
		var display := _resolve_text(profile.get("name"), conditions, english, location + ".name")
		var portraits: Variant = _load_portraits(profile.get("portraits", {}), location)
		if display.is_empty() or portraits == null:
			return null
		speakers[key] = {"name": display, "portraits": portraits}
	return speakers


static func _prepare_block(block: Variant, blocks: Dictionary, conditions: Dictionary, english: bool, location: String, speakers: Dictionary) -> Dictionary:
	if not block is Dictionary:
		push_error("%s must be an object." % location)
		return {}

	var authored_lines: Variant = block.get("lines")
	var authored_choices: Variant = block.get("choices", [])
	var next: Variant = block.get("next", "")
	if not authored_lines is Array or authored_lines.is_empty() or not authored_choices is Array:
		push_error("%s requires a nonempty lines array and an optional choices array." % location)
		return {}
	if not next is String or (not next.is_empty() and (not blocks.has(next) or not authored_choices.is_empty())):
		push_error("%s.next must name an existing block and cannot coexist with choices." % location)
		return {}

	var lines: Array[Dictionary] = []
	for index in authored_lines.size():
		var line: Variant = authored_lines[index]
		var line_location := "%s.lines[%d]" % [location, index]
		var text := _resolve_text(line, conditions, english, line_location)
		if text.is_empty():
			return {}
		var speaker: Variant = line.get("speaker", "npc")
		if speaker not in ["npc", "player"]:
			push_error("%s.speaker must be npc or player." % line_location)
			return {}
		var speaker_id: Variant = line.get("speaker_id", "")
		if not speaker_id is String or (not speaker_id.is_empty() and not speakers.has(speaker_id)):
			push_error("%s.speaker_id must name an existing speaker." % line_location)
			return {}
		lines.append({"text": text, "player": speaker == "player", "speaker_id": speaker_id})

	var choices: Array[Dictionary] = []
	for index in authored_choices.size():
		var choice: Variant = authored_choices[index]
		var choice_location := "%s.choices[%d]" % [location, index]
		var text := _resolve_text(choice, conditions, english, choice_location)
		if text.is_empty():
			return {}
		var target: Variant = choice.get("next")
		if not target is String or target.is_empty() or not blocks.has(target):
			push_error("%s.next must name an existing block." % choice_location)
			return {}
		choices.append({"text": text, "next": target})
	return {"lines": lines, "choices": choices, "next": next}


static func _resolve_text(value: Variant, conditions: Dictionary, english: bool, location: String) -> String:
	if not _has_valid_text(value):
		push_error("%s requires nonempty zh_CN text and optional en text." % location)
		return ""

	var variants: Variant = value.get("variants", [])
	if not variants is Array:
		push_error("%s.variants must be an array." % location)
		return ""

	var selected: Dictionary = value
	var matched := false
	for index in variants.size():
		var variant: Variant = variants[index]
		if not _has_valid_text(variant):
			push_error("%s.variants[%d] requires localized text." % [location, index])
			return ""
		var when: Variant = variant.get("when")
		if not when is Dictionary or when.is_empty():
			push_error("%s.variants[%d].when must be a nonempty object." % [location, index])
			return ""
		if not matched and _matches(when, conditions):
			selected = variant
			matched = true

	var translated: String = selected.get("en", "")
	return translated if english and not translated.strip_edges().is_empty() else selected["zh_CN"]


static func _has_valid_text(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var chinese: Variant = value.get("zh_CN")
	return chinese is String and not chinese.strip_edges().is_empty() and value.get("en", "") is String


static func _matches(required: Dictionary, conditions: Dictionary) -> bool:
	for key in required:
		if not conditions.has(key) or conditions[key] != required[key]:
			return false
	return true


static func _load_portraits(paths: Variant, id: String) -> Variant:
	if not paths is Dictionary:
		push_error("%s.portraits must be an object keyed by world." % id)
		return null

	var portraits := {}
	for world in WORLD_NAMES:
		var world_name: String = WORLD_NAMES[world]
		if not paths.has(world_name):
			continue
		var path: Variant = paths[world_name]
		if not path is String or not path.begins_with("res://") or not ResourceLoader.exists(path, "Texture2D"):
			push_error("%s.portraits.%s must point to a project texture." % [id, world_name])
			return null
		var portrait := ResourceLoader.load(path, "Texture2D") as Texture2D
		if portrait == null:
			push_error("%s.portraits.%s could not load a texture: %s" % [id, world_name, path])
			return null
		portraits[world] = portrait
	return portraits
