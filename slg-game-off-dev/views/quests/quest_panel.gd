extends Control

const STATUS_LABELS := {
	"offered": "待接取",
	"active": "进行中",
	"ready": "可交付",
	"succeeded": "已结算",
}
const REASON_LABELS := {
	&"wrong_world": "请回表世界办理这份委托。",
	&"wrong_issuer": "请找发布委托的人办理。",
	&"already_accepted": "这份委托已经接取。",
	&"not_accepted": "请先接取委托。",
	&"not_ready": "当前条件已经改变，请重新查看委托。",
	&"already_settled": "这份委托已经结算。",
	&"unknown_quest": "这份委托暂不可用。",
	&"busy": "请等待当前操作完成。",
}

var _quest_id: StringName
var _issuer_id: StringName
var _facility_id: StringName
var _world: int
var _previous_focus: Control

@onready var _title: Label = %QuestTitle
@onready var _objective: Label = %QuestObjective
@onready var _status: Label = %QuestStatus
@onready var _route: Label = %QuestRoute
@onready var _tokens: Label = %FlightTokenCount
@onready var _message: Label = %QuestMessage
@onready var _action: Button = %QuestAction
@onready var _close_button: Button = %CloseQuest


func open(quest_id: StringName, issuer_id: StringName, facility_id: StringName, world: int) -> void:
	if UIManager.has_modal() or SceneRouter.is_changing_scene():
		queue_free()
		return

	_quest_id = quest_id
	_issuer_id = issuer_id
	_facility_id = facility_id
	_world = world
	_previous_focus = UIManager.get_viewport().gui_get_focus_owner()
	UIManager.mount_modal(self, _handle_input)
	get_tree().current_scene.tree_exiting.connect(_close, CONNECT_ONE_SHOT)


func _ready() -> void:
	_close_button.pressed.connect(_close)
	_action.pressed.connect(_perform_action)
	GameSession.state_changed.connect(_refresh)
	_refresh()
	if _action.visible:
		_action.grab_focus()
	else:
		_close_button.grab_focus()


func _refresh() -> void:
	var view: Dictionary = GameSession.quest_view(_quest_id)
	var phase: String = view.get("status", "")
	var route: String = view.get("route_label", "")
	_title.text = view.get("title", "委托暂不可用")
	_objective.text = view.get("objective", "")
	_status.text = STATUS_LABELS.get(phase, "")
	_route.text = route
	_route.visible = not route.is_empty()
	_tokens.text = "通行凭证 × %d" % GameSession.flight_token_count()
	_action.visible = phase == "offered" or phase == "ready"
	_action.text = "接取委托" if phase == "offered" else "提交委托"


func _perform_action() -> void:
	var phase: String = GameSession.quest_view(_quest_id).get("status", "")
	_message.hide()
	if phase == "offered":
		var result: Dictionary = GameSession.accept_quest(_quest_id, _issuer_id)
		if not result.get("ok", false):
			_show_error(result)
		elif not _action.visible:
			_close_button.grab_focus()
	elif phase == "ready":
		var result: Dictionary = GameSession.turn_in_quest(_quest_id, _issuer_id)
		if not result.get("ok", false):
			_show_error(result)
			return

		var feedback := StringName(result.get("feedback_dialogue_id", ""))
		_close()
		if not feedback.is_empty():
			DialogueSystem.start(feedback, _facility_id, _world)


func _show_error(result: Dictionary) -> void:
	_message.text = REASON_LABELS.get(StringName(result.get("reason", "")), "委托操作未完成。")
	_message.show()
	_refresh()


func _handle_input(event: InputEvent) -> bool:
	if event.is_action(&"ui_cancel"):
		if event.is_action_pressed(&"ui_cancel"):
			_close()
		return true
	return event.is_action(&"shift_world")


func _close() -> void:
	if not is_inside_tree():
		return
	UIManager.unmount_modal(self)
	if is_instance_valid(_previous_focus) and _previous_focus.is_visible_in_tree():
		_previous_focus.grab_focus()
	queue_free()
