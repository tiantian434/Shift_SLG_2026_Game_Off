extends RefCounted

const SPECTRUM_MIN := Vector2(0.08, 0.16)
const SPECTRUM_MAX := Vector2(0.44, 0.56)
const RUNES := 4
const RITUAL_PERIOD := 5.2
const RITUAL_LEAD := 0.125
const RITUAL_WINDOW := 0.072

const LESSONS := {
	&"repair": {
		"title": "通风机检修",
		"case": "设备症状",
		"brief": "通风机停转。先观察风机，再选择替换件与工具。",
		"inspect": "扇叶有一道凹痕，转起来会撞击外壳。扇叶由六角螺母固定。",
		"action": "检修",
		"options": [
			{"id": "part", "label": "替换零件", "choices": ["新扇叶", "皮带", "轴承"]},
			{"id": "tool", "label": "维修工具", "choices": ["开口扳手", "木槌", "油壶"]},
		],
	},
	&"meal": {
		"title": "餐馆上菜",
		"case": "船员的要求",
		"brief": "“船上颠了一路，胃里难受得很。有没有什么热乎又清淡的东西？”",
		"action": "上菜",
		"options": [
			{"id": "dish", "label": "主菜", "choices": ["热蔬菜汤", "烤肉", "冷面"]},
			{"id": "seasoning", "label": "佐料", "choices": ["葱花", "辣油", "浓酱"]},
		],
	},
	&"ritual": {
		"title": "止风术式",
		"case": "符文法阵",
		"brief": "跟随光标的节奏。光标靠近亮起的符文时引导魔力。",
		"action": "启动法阵",
		"options": [
			{"id": "spell", "label": "已解锁术式", "choices": ["止风术式"]},
		],
	},
	&"alchemy": {
		"title": "调和异常植物",
		"case": "样本与光谱",
		"brief": "叶片沾满铁锈。搭配材料，让光点落在浅绿色的目标区。",
		"action": "炼成",
		"options": [
			{"id": "base", "label": "基底药材", "choices": ["露苔", "月叶", "炭根"]},
			{"id": "sample", "label": "表之质（可选）", "choices": ["不添加", "金属屑", "煤烟残渣"]},
			{"id": "catalyst", "label": "调和辅料", "choices": ["清露", "盐晶", "温灰"]},
		],
	},
}

const MATERIAL_EFFECTS := {
	"base": [Vector2(0.14, 0.45), Vector2(0.42, 0.30), Vector2(-0.28, -0.12)],
	"sample": [Vector2.ZERO, Vector2(0.36, -0.28), Vector2(0.15, -0.40)],
	"catalyst": [Vector2(-0.10, 0.17), Vector2(-0.28, 0.32), Vector2(0.15, -0.13)],
}


static func spectrum(draft: Dictionary) -> Vector2:
	var point := Vector2.ZERO
	for kind: String in MATERIAL_EFFECTS:
		if draft.has(kind):
			point += MATERIAL_EFFECTS[kind][draft[kind]]
	return point


static func evaluate(exercise: StringName, draft: Dictionary) -> String:
	match exercise:
		&"repair":
			if draft["part"] == 1:
				return "换了皮带后风机仍有撞击声，扇叶边缘的凹痕还在。"
			if draft["part"] == 2:
				return "轴承转动更顺畅了，但每转一圈仍会刮到外壳。"
			if draft["tool"] == 1:
				return "敲击后机壳发出闷响，固定扇叶的六角螺母没有松动。"
			if draft["tool"] == 2:
				return "油让转轴更顺滑，变形的扇叶却还是会撞上外壳。"
		&"meal":
			if draft["dish"] == 1:
				return "船员：这肉倒是热的，可有些油腻。能来点清淡的吗？"
			if draft["dish"] == 2:
				return "船员：这碗太凉了。我的胃不太舒服，想吃点热的。"
			if draft["seasoning"] != 0:
				return "船员：汤是热的，可这个味道太重了。清淡一些就好。"
		&"alchemy":
			var point := spectrum(draft)
			if point.y < SPECTRUM_MIN.y or point.y > SPECTRUM_MAX.y:
				return "药液仍然浑浊。调和度偏%s，可以调整样本或辅料。" % ("低" if point.y < SPECTRUM_MIN.y else "高")
			if point.x < SPECTRUM_MIN.x or point.x > SPECTRUM_MAX.x:
				return "叶片的锈斑没有完全消退。药剂活性偏%s，试着换一种配料。" % ("低" if point.x < SPECTRUM_MIN.x else "高")
	return ""
