extends RefCounted
## Presentation state only. Gameplay position and saves remain owned by core.
var facing: Dictionary = {}
var elapsed := 0.0
var remaining := 0.0
var speed := 1.0

func reset() -> void:
	facing.clear()
	stop()

func stop() -> void:
	elapsed = 0.0
	remaining = 0.0

func face(who: String, delta: Vector2i) -> void:
	if delta == Vector2i.ZERO: return
	facing[who] = ("right" if delta.x > 0 else "left") if absi(delta.x) >= absi(delta.y) else ("down" if delta.y > 0 else "up")

func step(who: String, delta: Vector2i, duration: float, succeeded: bool) -> void:
	face(who, delta)
	if succeeded:
		remaining = duration
		speed = 0.11 / duration
	else: stop()

func tick(delta: float, paused: bool) -> void:
	if paused:
		stop()
		return
	if remaining > 0:
		elapsed += delta * speed
		remaining = maxf(0, remaining - delta)
	else: elapsed = 0

func image_spec(avatar: Dictionary, who: String, moving: bool):
	if not avatar.has("walk"): return avatar.sprite
	var cycle: Dictionary = avatar.walk
	var frames: Array = cycle[facing.get(who, "down")]
	var index := int(floor(elapsed * float(cycle.fps))) % frames.size() if moving else int(cycle.idle_frame)
	return frames[index]
