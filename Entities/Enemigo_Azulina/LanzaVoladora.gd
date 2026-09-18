class_name LanzaVoladora
extends GoblinPiezaFisica

## Lanza que Azulina suelta al morir: da un giro completo en el aire y cae
## clavada en el suelo con la punta hacia abajo, disolviéndose tras unos segundos.
## Hereda de GoblinPiezaFisica para el ciclo de vida y la disolución estética.

const COLOR_DISOLUCION_LANZA := Color(0.45, 0.85, 1.0)
const PROFUNDIDAD_CLAVADO: float = 0.12  ## Profundidad en metros que se entierra la punta en el suelo

var _clavada: bool = false


func _ready() -> void:
	super._ready()
	_tiempo_para_disolver = 2.5


func iniciar_disolucion(duracion: float = 1.2, _color_disolucion: Color = Color(0.2, 0.85, 0.2)) -> void:
	super.iniciar_disolucion(duracion, COLOR_DISOLUCION_LANZA)


func _physics_process(delta: float) -> void:
	_tiempo_vida += delta

	# Iniciar disolución automática a los 2.5 segundos
	if _tiempo_vida >= _tiempo_para_disolver and not _disolviendo:
		_disolviendo = true
		iniciar_disolucion(1.2)

	if not active or resting or _clavada:
		return

	velocity.y -= gravity * delta
	velocity.z = 0.0  # Mantener siempre en el plano 2.5D

	var move_step := velocity * delta
	var target_pos := global_position + move_step

	var tip_pos := global_position + global_transform.basis * Vector3(0.0, 1.0, 0.0)
	var next_basis := global_transform.basis.rotated(Vector3.FORWARD, rot_speed_z * delta)
	var next_tip := target_pos + next_basis * Vector3(0.0, 1.0, 0.0)

	var space_state := get_world_3d().direct_space_state
	# Raycast contra el suelo (Capa 1 y Capa 512 de límites/escenario)
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3(0.0, 0.2, 0.0), target_pos)
	query.collision_mask = 1 | 512
	if _static_body and is_instance_valid(_static_body):
		query.exclude = [_static_body.get_rid()]

	var hit := space_state.intersect_ray(query)
	if not hit or not hit.has("position"):
		var query_tip := PhysicsRayQueryParameters3D.create(tip_pos + Vector3(0.0, 0.2, 0.0), next_tip)
		query_tip.collision_mask = 1 | 512
		if _static_body and is_instance_valid(_static_body):
			query_tip.exclude = [_static_body.get_rid()]
		hit = space_state.intersect_ray(query_tip)

	if hit and hit.has("position"):
		_clavar_en_suelo(hit.position)
	else:
		global_position = target_pos
		rotate_z(rot_speed_z * delta)


func _clavar_en_suelo(pos_suelo: Vector3) -> void:
	_clavada = true
	active = false
	resting = true
	var dir_x: float = signf(velocity.x) if absf(velocity.x) > 0.1 else 1.0
	velocity = Vector3.ZERO
	rot_speed_z = 0.0

	# Orientar con la punta (eje local +Y) apuntando hacia abajo (-Y mundo)
	# con inclinación según la dirección del vuelo
	var angulo_clavado: float = PI + dir_x * randf_range(0.18, 0.26)
	rotation = Vector3(0.0, 0.0, angulo_clavado)

	# Ubicar el contenedor de modo que la punta (local (0, 1, 0)) quede enterrada en el punto de contacto
	var offset_punta: Vector3 = global_transform.basis * Vector3(0.0, 1.0, 0.0)
	global_position = pos_suelo + Vector3(0.0, -PROFUNDIDAD_CLAVADO, 0.0) - offset_punta
	global_position.z = pos_suelo.z

	# Efectos de impacto al clavarse
	VFXFactory.spawn_shield_break_smoke(self, pos_suelo)
	AudioManager.play_sfx("arrow_impact")
