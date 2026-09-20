extends RefCounted
## The tracking list never participates in route gating.

func add_checks(app, box: VBoxContainer, checks: Array, depth: int = 0) -> void:
	for check in checks:
		var c: Dictionary = check.condition
		var detail := "%s %s: %s / %s" % [app.t(c.kind), app.t(str(c.get("id", ""))), str(check.actual), app.t(str(check.expected))]
		match c.kind:
			"all": detail = "全部條件 (AND)" if app.language == "zh_TW" else "All conditions (AND)"
			"any": detail = "任一條件 (OR)" if app.language == "zh_TW" else "Any condition (OR)"
			"stat", "variable": detail = app.numeric_view.condition_text(app,check)
			"day": detail = "%s %s (%s)" % [symbol(c.op),app.core.format_day(int(check.expected),app.language),app.core.format_day(int(check.actual),app.language)]
			"action_count":
				detail = "%s: %d %s %d" % [", ".join(c.tags),int(check.actual),symbol(c.op),int(check.expected)]
				if c.has("window"):
					detail += " [%d %s; %s]" % [c.window.size, c.window.unit, ("含目前" if app.language == "zh_TW" else "include current") if c.window.include_current else ("不含目前" if app.language == "zh_TW" else "exclude current")]
			"flag", "completed": detail = app.t(str(c.id)) + (" = false" if not c.get("value",true) else "")
			"period": detail = app.t("period") + " · " + app.t(str(check.expected))
			"map", "zone", "target": detail = "%s: %s" % [app.t(c.kind),app.t(str(check.expected))]
		var line: Label = app.label("  ".repeat(depth) + ("✓ " if check.passed else "○ ") + detail,17)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(line)
		if check.has("children"): add_checks(app,box,check.children,depth+1)

func symbol(op: String) -> String:
	return {"eq":"=","ne":"≠","lt":"<","lte":"≤","gt":">","gte":"≥"}.get(op,op)

func add_tracking(app, box: VBoxContainer) -> void:
	for who in app.core.content.get("tracking",{}):
		box.add_child(app.label(app.t(who) + (" · 事件追蹤" if app.language == "zh_TW" else " · Events"),23))
		for entry in app.core.content.tracking[who]:
			var done: bool = entry.event in app.core.state.completed
			var context: Dictionary = app.core.context_for_event(entry.event)
			var available: bool = app.core.event_available(entry.event,context)
			var reveal: String = entry.get("reveal","always")
			if not app.debug_open and ((reveal == "completed" and not done) or (reveal == "available" and not available and not done)):
				box.add_child(app.label(app.t("locked"),18))
				continue
			var event: Dictionary = app.core.content.events[entry.event]
			var title: Label = app.label(("✓ " if done else "○ ") + app.t(event.title),19)
			title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box.add_child(title)
			if not done: add_checks(app,box,app.core.checks(event.conditions,context))
