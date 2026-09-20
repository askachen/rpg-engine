extends RefCounted
## Bounded BFS over actual core.act transitions. No alternate gameplay rules.
func commands(core) -> Array:
	var output: Array = []
	if core.active_event != "":
		for choice in core.event_view().choices: output.append({"op":"choose","choice":choice.id})
		output.append({"op":"cancel_event"})
		return output
	for offset in [[1,0],[-1,0],[0,1],[0,-1]]: output.append({"op":"move","dx":offset[0],"dy":offset[1]})
	output.append({"op":"wait"})
	for target in core.map_objects():
		if not core.adjacent(target.position): continue
		var command := {"op":"interact","target":target.id}
		if target.has("required_item"): command.item = target.required_item.id
		output.append(command)
		if target.kind == "shop":
			for item in core.content.shops[target.shop]: output.append({"op":"buy","shop":target.shop,"item":item})
	return output

func snapshot(core) -> Dictionary:
	return {"state":core.state.duplicate(true),"event":core.active_event,"node":core.active_node,"pending":core.pending_effects.duplicate(true),"context":core.event_context.duplicate(true)}

func clone(core, saved: Dictionary):
	var next = core.get_script().new()
	next.content = core.content
	next.state = saved.state.duplicate(true)
	next.active_event = saved.event
	next.active_node = saved.node
	next.pending_effects = saved.pending.duplicate(true)
	next.event_context = saved.context.duplicate(true)
	return next

func route(nodes: Array, index: int) -> Array:
	var steps: Array = []
	while nodes[index].parent >= 0:
		steps.push_front(nodes[index].command)
		index = nodes[index].parent
	return steps

func search(core, limits: Dictionary) -> Dictionary:
	var started := Time.get_ticks_msec()
	var deadline: int = started + int(float(limits.seconds)*1000)
	var first := snapshot(core)
	var nodes: Array = [{"snapshot":first,"parent":-1,"depth":0}]
	var seen := {JSON.stringify(first):true}
	var cursor := 0
	var transitions := 0
	var deepest := 0
	var cutoff := false
	var reason := "frontier_exhausted"
	var status := "exhausted_no_goal"
	var evidence := 0
	var blocked := {}
	while cursor < nodes.size():
		if Time.get_ticks_msec() >= deadline: reason = "time_limit"; status = "inconclusive"; break
		var node: Dictionary = nodes[cursor]
		var current = clone(core,node.snapshot)
		evidence = cursor
		if current.active_event == "" and current.current_ending() != "" and (limits.get("goal","") == "" or current.current_ending() == limits.goal):
			status = "witness_found"; reason = "one_reachable_ending"; break
		if node.depth >= int(limits.max_depth): cutoff = true; cursor += 1; continue
		for command in commands(current):
			if Time.get_ticks_msec() >= deadline: reason = "time_limit"; break
			var next = clone(core,node.snapshot)
			var response: Dictionary = next.act(command)
			transitions += 1
			if not response.ok:
				blocked[response.message] = blocked.get(response.message,0)+1
				continue
			var saved := snapshot(next)
			var key := JSON.stringify(saved)
			if seen.has(key): continue
			if nodes.size() >= int(limits.max_states): reason = "state_limit"; break
			seen[key] = true
			nodes.append({"snapshot":saved,"parent":cursor,"command":command,"depth":node.depth+1})
			deepest = maxi(deepest,int(node.depth)+1)
		if reason in ["time_limit","state_limit"]: status = "inconclusive"; break
		cursor += 1
	if status == "exhausted_no_goal" and cutoff: status = "inconclusive"; reason = "depth_limit"
	var steps := route(nodes,evidence)
	return {"status":status,"reason":reason,"guarantees_all_routes":false,"limits":limits,"states":nodes.size(),"expanded":cursor,"transitions":transitions,"max_depth_reached":deepest,"seconds":float(Time.get_ticks_msec()-started)/1000.0,"blocked_reasons":blocked,"steps":steps,"state":nodes[evidence].snapshot.state,"active_event":nodes[evidence].snapshot.event}
