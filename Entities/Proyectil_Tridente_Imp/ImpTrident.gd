class_name ImpTridentProjectile
extends "res://System/Core/EnemyProjectileBase.gd"

const TRIDENT_EMISSION_ENERGY: float = 4.0

@export_category("Movimiento")
@export var velocidad: float = 8.0
@export var gravedad: float = 1.2

var disparado_por_jugador: bool = false
var tirador: Node = null
var _velocidad_base: float = 8.0
var _velocidad_base_capturada: bool = false


func _init() -> void:
	color_proyectil = Color(1.0, 0.15, 0.05)
	offscreen_margin_x = 400.0
	offscreen_margin_top = 2000.0
	offscreen_margin_bottom = 300.0


func _ready() -> void:
	_capturar_velocidad_base_si_necesario()
	if disparado_por_jugador:
		collision_layer = 4
		collision_mask = 71
	super._ready()


func initialize(shoot_direction: Vector3, potencia: float = 1.0) -> void:
	_capturar_velocidad_base_si_necesario()
	_inicializar_direccion(shoot_direction)
	velocidad = _velocidad_base * max(0.0, potencia)
	if disparado_por_jugador:
		collision_layer = 4
		collision_mask = 71


func _on_body_entered(body: Node) -> void:
	if is_stuck:
		return

	if disparado_por_jugador:
		# Ignorar jugador y aliados
		if body.is_in_group("player") or body.is_in_group("allies"):
			return

		# Enemigos
		if body.is_in_group("enemies") or body.has_method("take_damage") or body.has_method("recibir_dano"):
			if body.has_method("manejar_impacto_aura") and body.manejar_impacto_aura(self):
				_safe_destroy()
				return

			if ("_is_invulnerable" in body and body._is_invulnerable) or ("is_invulnerable" in body and body.is_invulnerable):
				return

			if body.has_method("set") and "last_hit_position" in body:
				body.last_hit_position = global_position
			if body.has_method("set") and "last_hit_direction" in body:
				body.last_hit_direction = direction
			if body.has_method("set") and "ultimo_atacante" in body:
				body.ultimo_atacante = tirador

			if body.has_method("take_damage"):
				body.take_damage(2.0)
			elif body.has_method("recibir_dano"):
				body.recibir_dano(2)

			AudioManager.play_sfx("arrow_impact")
			_safe_destroy()
			return

		# Escudos y superficies sólidas
		if body is StaticBody3D or body is AnimatableBody3D:
			if body.has_method("recibir_golpe"):
				if body.has_method("es_reflejante") and body.es_reflejante():
					body.recibir_golpe_reflejo(self)
					AudioManager.play_sfx("parry")
					_safe_destroy()
					return
				body.recibir_golpe()
				AudioManager.play_sfx("shield_hit_arrow")
				_stick_to_shield(body)
				return

			AudioManager.play_sfx("arrow_impact")
			_stick_to_surface()
			return

		return

	# Comportamiento original si lo dispara el enemigo Imp
	super._on_body_entered(body)


func _actualizar_movimiento(delta: float) -> void:
	_aplicar_movimiento_parabolico(delta, velocidad, gravedad)


func _preparar_visuales() -> void:
	_create_material(TRIDENT_EMISSION_ENERGY)


func _aplicar_visuales_cacheados() -> void:
	for mesh in _cached_mesh_instances:
		if not is_instance_valid(mesh):
			continue

		if mesh is MeshInstance3D:
			mesh.visible = true
			mesh.add_to_group("outline_meshes")
			mesh.material_override = projectile_material


func _restaurar_visuales_desde_pool() -> void:
	_create_material(TRIDENT_EMISSION_ENERGY)
	_aplicar_visuales_cacheados()


func _capturar_velocidad_base_si_necesario() -> void:
	if _velocidad_base_capturada:
		return

	_velocidad_base = velocidad
	_velocidad_base_capturada = true
