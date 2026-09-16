extends Control
## Child of the clipped map window. World coordinates stay independent of the HUD.
var host: Control

func _draw() -> void:
	if is_instance_valid(host): host.world.draw(host, self)
