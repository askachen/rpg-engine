extends "res://tests/platform_base.gd"
const LIMITS = {"startup_ms":5000,"load_ms":2000,"candidate_p95_ms":100,"save_load_p95_ms":250,"transition_p95_ms":1000,"frame_p95_ms":33.4,"static_growth_mb":32,"resource_growth":24,"node_growth":0,"orphan_growth":0}

func metrics() -> Dictionary:
	return {"bytes":int(Performance.get_monitor(Performance.MEMORY_STATIC)),"resources":int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),"nodes":int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),"orphans":int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))}

func percentile(samples: Array) -> float:
	samples.sort()
	return float(samples[maxi(0,int(ceil(samples.size()*0.95))-1)])

func fixture() -> void:
	# Scale an existing package in memory; this is synthetic load, never authored story progression.
	var map: Dictionary = app.core.content.maps[app.core.state.map].duplicate(true)
	map.width = 200
	map.height = 200
	map.walls = []
	map.furniture = []
	map.decorations = []
	map.spawns = {"entry":[2,2]}
	for id in ["stress_a","stress_b"]:
		var area := map.duplicate(true)
		area.objects = [{"id":id+"_exit","kind":"exit","position":[3,2],"label":"back","destination":"stress_b" if id == "stress_a" else "stress_a","spawn":"entry"}]
		app.core.content.maps[id] = area
	# Stress offscreen props and event lookup without adding a second rules engine.
	var prop: Dictionary = app.core.content.maps[app.core.state.map].furniture[0].duplicate(true)
	for id in ["stress_a","stress_b"]:
		for i in range(600):
			var copy := prop.duplicate(true)
			copy.position = [30+i%100,30+int(i/100)*3]
			app.core.content.maps[id].furniture.append(copy)
	for i in range(1000):
		var event: Dictionary = app.core.content.events.opening.duplicate(true)
		event.character = "guide"
		event.conditions = [{"kind":"day","op":">=","value":9999}]
		app.core.content.events["stress_event_%04d"%i] = event
	app.core.content.initial.map = "stress_a"
	app.core.content.initial.position = [2,2]
	app.core.new_game(false)
	app.show_game()

func cycle(index: int, timings: Array) -> void:
	var map_id: String = app.core.state.map
	var start := Time.get_ticks_usec()
	await app.change_map({"op":"interact","target":map_id+"_exit"})
	check(app.core.state.map != map_id,"Transition failed")
	timings.append((Time.get_ticks_usec()-start)/1000.0)
	# Exercise real dialogue/audio/visual node disposal by starting/cancelling opening.
	check(app.core.start_event("opening",{"source":"opening"}).ok,"Story start failed")
	app.story = app.Dialogue.new()
	app.story.setup(app,"opening")
	app.add_child(app.story)
	await process_frame
	app.execute_immediate({"op":"cancel_event"})
	# Repeated movie decoder creation/release from the existing media fixture.
	var video = load("res://engine/story_video.gd").new()
	video.setup({"path":"res://games/fog_harbor/assets/video-check-v1.ogv","loop":true,"volume":0.0})
	app.add_child(video)
	for frame in range(4): await process_frame
	check(video.error == "" and video.player.get_video_texture() != null,"Video resource missing")
	video.queue_free()
	app.show_game()
	await settle()
	check(not is_instance_valid(app.story),"Story node survived cancellation")
	check(app.core.active_event == "","Event stayed active")
	check(app.transition_layer == null and not app.transitioning,"Transition layer leaked")

func run() -> void:
	var startup := Time.get_ticks_usec()
	await configure()
	var startup_ms := (Time.get_ticks_usec()-startup)/1000.0
	fixture()
	var file := FileAccess.open(str(request.directory).path_join("stress-content.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(app.core.content))
	file.close()
	var load_start := Time.get_ticks_usec()
	var other = app.Core.new()
	check(other.load_content(str(request.directory).path_join("stress-content.json")),"Scaled content load failed")
	var load_ms := (Time.get_ticks_usec()-load_start)/1000.0
	other = null
	var candidates: Array = []
	for i in range(20):
		var stamp := Time.get_ticks_usec()
		check(app.core.event_candidates("guide",{"source":"npc","target":"guide_npc"}).size() >= 1000,"Large event corpus was not exercised")
		candidates.append((Time.get_ticks_usec()-stamp)/1000.0)
	var warm: Array = []
	for i in range(6): await cycle(i,warm)
	var baseline := metrics()
	FileAccess.open(str(request.directory).path_join("baseline.ready"),FileAccess.WRITE).close()
	var samples: Array = []
	var save_times: Array = []
	var transitions: Array = []
	for i in range(int(request.cycles)):
		await cycle(i,transitions)
		var before: Dictionary = app.core.state.duplicate(true)
		var stamp := Time.get_ticks_usec()
		check(app.saves.save(1),"Save failed during stress")
		check(app.core.act({"op":"wait"}).ok,"Wait failed")
		check(app.saves.load_slot(1),"Load failed during stress")
		check(JSON.parse_string(JSON.stringify(app.core.state)) == JSON.parse_string(JSON.stringify(before)),"Stress save/load changed JSON state")
		save_times.append((Time.get_ticks_usec()-stamp)/1000.0)
		app.show_game()
		await settle()
		samples.append(metrics())
	# Bound the diagnostic snapshots even across a long session.
	for i in range(1500): app.core.act({"op":"wait"})
	check(app.core.history.size() == app.core.history_limit,"History is unbounded")
	check(app.core.history[-1].step == app.core.history_step-1,"History sequence lost monotonicity")
	var trace = app.Core.new()
	trace.content = app.core.content
	trace.history_limit = 0
	trace.new_game(false)
	for i in range(300): trace.act({"op":"wait"})
	check(trace.history.size() == 300 and trace.history[-1].step == 299,"Offline full trace was truncated")
	trace = null
	app.show_game()
	await settle()
	var frames: Array = []
	var last := Time.get_ticks_usec()
	for i in range(180):
		await process_frame
		var now := Time.get_ticks_usec()
		frames.append((now-last)/1000.0)
		last = now
	var final := metrics()
	FileAccess.open(str(request.directory).path_join("finished.ready"),FileAccess.WRITE).close()
	await create_timer(0.3).timeout # Allow the external native-memory sampler to observe the end state.
	var growth_mb: float = (final.bytes-baseline.bytes)/1048576.0
	check(growth_mb <= LIMITS.static_growth_mb,"Static allocation growth exceeds budget")
	check(final.resources-baseline.resources <= LIMITS.resource_growth,"Resource count growth exceeds budget")
	check(final.nodes-baseline.nodes <= LIMITS.node_growth,"Node count grows after disposal")
	check(final.orphans-baseline.orphans <= LIMITS.orphan_growth,"Orphan node leak")
	var gpu := DisplayServer.get_name() != "headless"
	var measurements := {"startup_ms":startup_ms,"load_ms":load_ms,"candidate_p95_ms":percentile(candidates),"save_load_p95_ms":percentile(save_times),"transition_p95_ms":percentile(transitions),"frame_p95_ms":percentile(frames),"static_growth_mb":growth_mb}
	if gpu:
		for key in measurements: check(measurements[key] <= LIMITS[key],key+" exceeded performance budget")
	await screenshot("stress-final")
	finish({"performance_verified":gpu and failures.is_empty(),"fixture":{"maps":2,"width":200,"height":200,"extra_events":1000,"offscreen_props_per_map":600,"cycles":request.cycles,"warmup_cycles":6,"history_actions":1500},"limits":LIMITS,"measurements":measurements,"baseline":baseline,"final":final,"samples":samples,"frame_ms":frames})
