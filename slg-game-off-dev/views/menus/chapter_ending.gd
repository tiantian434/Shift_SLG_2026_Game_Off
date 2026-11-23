extends Control

@onready var _status: Label = %SaveStatus
@onready var _retry: Button = %RetrySave


func _ready() -> void:
	%ReturnHome.pressed.connect(_return_to_home)
	%Quit.pressed.connect(get_tree().quit)
	_retry.pressed.connect(_retry_save)
	_update_save_status(GameSession.chapter_save_error())
	create_tween().tween_property($Fade, "color:a", 0.0, 0.75)
	%ReturnHome.grab_focus()


func _retry_save() -> void:
	_update_save_status(GameSession.retry_chapter_save())


func _update_save_status(error: Error) -> void:
	_retry.visible = error != OK
	_status.text = "通关进度已保存" if error == OK else "通关进度保存失败"


func _return_to_home() -> void:
	await SceneRouter.open_home()
