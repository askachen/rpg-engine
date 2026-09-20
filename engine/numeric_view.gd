extends RefCounted

func title(app) -> String:
	var translated: String = app.t("numeric_status")
	return translated if translated != "numeric_status" else ("能力狀態" if app.language == "zh_TW" else "Attributes")

func visible_entries(core) -> Array:
	var entries: Array = []
	for group in ["stats", "variables"]:
		for id in core.content.get(group, {}):
			var spec: Dictionary = core.content[group][id]
			if spec.get("visible", group == "stats"):
				entries.append({"group":group,"id":id,"spec":spec,"value":core.state[group][id]})
	return entries

func show_status(app) -> void:
	var box: VBoxContainer = app.modal(title(app))
	for entry in visible_entries(app.core):
		var line: Label = app.label("%s: %s" % [app.t(entry.spec.name), str(entry.value)], 26)
		line.name = "Numeric_%s_%s" % [entry.group, entry.id]
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(line)
	box.add_child(app.button(app.t("back"), app.close_modal))

func condition_text(app, check: Dictionary) -> String:
	var c: Dictionary = check.condition
	var group := "stats" if c.kind == "stat" else "variables"
	var spec: Dictionary = app.core.content.get(group, {}).get(c.id, {})
	var symbols := {"eq":"=", "ne":"≠", "lt":"<", "lte":"≤", "gt":">", "gte":"≥"}
	return "%s %s %s (%s)" % [app.t(spec.get("name", c.id)), symbols.get(c.op, "?"), str(check.expected), str(check.actual)]
