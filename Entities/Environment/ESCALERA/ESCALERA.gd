extends Area3D


func _ready():
	# Conectar señales para detectar al jugador
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body):
	if body.is_in_group("player") and body.has_method("set_near_ladder"):
		body.set_near_ladder(true, self)


func _on_body_exited(body):
	if body.is_in_group("player") and body.has_method("set_near_ladder"):
		body.set_near_ladder(false, null)
