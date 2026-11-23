extends RefCounted

const ORDER := [&"briefing", &"repair", &"meal", &"ritual", &"alchemy", &"return", &"complete"]
const LESSONS := {
	&"briefing": [&"hub", 0, "早班交接", "机械姬", "前往空港站房，听取今天的站务安排。"],
	&"repair": [&"workshop", 0, "检修通风机", "机械姬", "检查扇叶的损伤，选用零件和工具完成检修。"],
	&"meal": [&"restaurant", 0, "接待午间船员", "船员", "听取船员的要求，准备热乎而清淡的餐食。"],
	&"ritual": [&"workshop", 1, "引导平风术式", "机械姬（人造人）", "到术式工坊尝试引导魔力，平息附近的风。"],
	&"alchemy": [&"shop", 1, "调和锈蚀样本", "机械姬（人造人）", "到炼药工房调配药剂，使锈化的叶片恢复正常。"],
	&"return": [&"hub", 0, "回站房复命", "机械姬", "回表世界空港站房，结束今日站务。"],
}
const EXERCISES := [&"repair", &"meal", &"ritual", &"alchemy"]


static func initial_state() -> Dictionary:
	return {"stage": "briefing", "step": "intro", "draft": {}, "started": false}


static func is_valid(progress: Variant) -> bool:
	if not progress is Dictionary or not progress.get("stage") is String:
		return false
	var stage := StringName(progress["stage"])
	return (
		stage in ORDER
		and progress.get("step") in (["intro", "exercise", "debrief"] if stage in EXERCISES else ["intro"])
		and progress.get("draft", {}) is Dictionary
		and progress.get("started", false) is bool
	)


static func restore_progress(progress: Dictionary) -> void:
	var draft: Dictionary = progress.get("draft", {})
	for key: String in draft:
		var value: Variant = draft[key]
		if value is float and value >= 0 and value <= 2147483647 and value == floor(value):
			draft[key] = int(value)
	progress["draft"] = draft
	progress["started"] = progress.get("started", false)


static func task_entries(progress: Dictionary) -> Array[Dictionary]:
	var current: StringName = StringName(progress["stage"])
	var entries: Array[Dictionary] = []
	for stage: StringName in ORDER:
		if stage == &"complete":
			break
		var lesson: Array = LESSONS[stage]
		var reached := stage == current
		var active: bool = reached and progress.get("started", false)
		entries.append({
			"id": StringName("ch2_" + String(stage)),
			"title": lesson[2],
			"issuer": lesson[3],
			"summary": lesson[4],
			"required": true,
			"group": ("active" if active else "offered") if reached else "settled",
			"available": reached,
		})
		if reached:
			break
	return entries
