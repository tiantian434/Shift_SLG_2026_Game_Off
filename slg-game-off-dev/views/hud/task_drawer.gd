extends PanelContainer

signal task_selected(task_id: StringName)
signal close_requested

const ENTRY_SCENE := preload("res://views/hud/task_drawer_entry.tscn")
const GROUPS := [
	{ "id": "offered", "title": "待处理" },
	{ "id": "active", "title": "进行中" },
	{ "id": "settled", "title": "已结算" },
	{ "id": "event", "title": "独立事件" },
]
const DEFAULT_EXPANDED := {"offered": true, "active": true, "settled": false, "event": true}

static var _expanded := DEFAULT_EXPANDED.duplicate()
static var _saved_scroll := 0

var _opening: Tween

@onready var _scroll: ScrollContainer = %TaskScroll
@onready var _list: VBoxContainer = %TaskList
@onready var _empty: Label = %EmptyTasks


func _ready() -> void:
	%CloseTasks.pressed.connect(close_requested.emit)


func open_drawer() -> void:
	if visible:
		return
	modulate.a = 0.0
	show()
	_opening = create_tween()
	_opening.tween_property(self, "modulate:a", 1.0, 0.16)
	_restore_scroll.call_deferred(_saved_scroll)


func close_drawer() -> void:
	if visible:
		_saved_scroll = _scroll.scroll_vertical
	if _opening != null:
		_opening.kill()
		_opening = null
	hide()


func reset_memory() -> void:
	close_drawer()
	_expanded.assign(DEFAULT_EXPANDED)
	_saved_scroll = 0


func set_entries(entries: Array[Dictionary]) -> void:
	var position_before := _scroll.scroll_vertical
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()

	_empty.visible = entries.is_empty()
	_scroll.visible = not entries.is_empty()
	for group: Dictionary in GROUPS:
		var key: String = group["id"]
		var items := entries.filter(func(entry: Dictionary) -> bool: return entry.get("group") == key)
		if items.is_empty():
			continue
		if key == "offered":
			items = (
				items.filter(func(entry: Dictionary) -> bool: return entry.get("required", false))
				+ items.filter(func(entry: Dictionary) -> bool: return not entry.get("required", false))
			)
		elif key == "event":
			items.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
				return left.get("deadline_days", 0) < right.get("deadline_days", 0)
			)
		_add_group(key, group["title"], items)

	if visible:
		_restore_scroll.call_deferred(position_before)


func _restore_scroll(position_to_restore: int) -> void:
	if visible:
		_scroll.scroll_vertical = position_to_restore


func _add_group(key: String, caption: String, entries: Array[Dictionary]) -> void:
	var heading := Button.new()
	heading.custom_minimum_size.y = 25.0
	heading.theme_type_variation = &"TaskGroup"
	heading.alignment = HORIZONTAL_ALIGNMENT_LEFT
	heading.toggle_mode = true
	heading.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_list.add_child(heading)

	var items := VBoxContainer.new()
	items.add_theme_constant_override(&"separation", 4)
	_list.add_child(items)
	for entry in entries:
		var card: PanelContainer = ENTRY_SCENE.instantiate()
		items.add_child(card)
		_populate_card(card, entry, key)

	var is_expanded: bool = _expanded[key]
	heading.set_pressed_no_signal(is_expanded)
	_set_group_open(key, caption, heading, items, is_expanded)
	heading.toggled.connect(func(open: bool) -> void:
		_set_group_open(key, caption, heading, items, open)
	)


func _set_group_open(key: String, caption: String, heading: Button, items: Control, open: bool) -> void:
	_expanded[key] = open
	items.visible = open
	heading.text = ("▾  " if open else "▸  ") + caption


func _populate_card(card: PanelContainer, entry: Dictionary, group: String) -> void:
	var title: Label = card.get_node("%EntryTitle")
	var note: Label = card.get_node("%EntryNote")
	var summary: Label = card.get_node("%EntrySummary")
	var hit: Button = card.get_node("%EntryHit")
	title.text = entry.get("title", "")
	summary.text = entry.get("summary", "")
	summary.visible = not summary.text.is_empty()

	var metadata := PackedStringArray()
	if group == "event":
		var days: int = entry.get("deadline_days", 0)
		metadata.append("今日截止" if days <= 0 else "剩余 %d 天" % days)
		if days <= 0:
			note.add_theme_color_override(&"font_color", Color("#9e382b"))
	else:
		metadata.append("必做" if entry.get("required", false) else "可选")
		var issuer: String = entry.get("issuer", "")
		if not issuer.is_empty():
			metadata.append(issuer)
	note.text = " · ".join(metadata)

	hit.visible = group != "settled" and entry.get("available", true)
	hit.tooltip_text = title.text
	hit.pressed.connect(task_selected.emit.bind(StringName(entry["id"])))
