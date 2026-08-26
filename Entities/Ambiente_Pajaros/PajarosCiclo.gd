extends GPUParticles3D

const TIEMPO_VISIBLE: float = 90.0 # 1:30
const TIEMPO_OCULTO: float = 120.0 # 2:00

func _ready() -> void:
	emitting = true
	_restart_emision()
	_iniciar_ciclo()

func _restart_emision() -> void:
	restart()
	emitting = true

func _iniciar_ciclo() -> void:
	while is_inside_tree():
		# Visible
		emitting = true
		_restart_emision()
		await get_tree().create_timer(TIEMPO_VISIBLE).timeout
		if not is_inside_tree():
			return
		# Oculto - deja que expiren partículas (lifetime 18s)
		emitting = false
		await get_tree().create_timer(TIEMPO_OCULTO).timeout
		if not is_inside_tree():
			return
