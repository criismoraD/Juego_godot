class_name Gargola
extends EnemyBase

## Gárgola voladora: aparece del spawn a altura 3.4–5.2, oscila arriba/abajo,
## usa FLY_IDLE para idle y desplazamiento. Ciclo de ataque:
##   CARGA_ATAQUE → esfera roja en manos crece → ATACAR → 2 proyectiles rectos con dispersión.
const PROJECTILE_POOL_REF = preload("res://System/Core/ProjectilePool.gd")
const GARGOLA_PROJECTILE_COLOR: Color = Color(1.0, 0.1, 0.05)
const PROJECTILE_SCALE: Vector3 = Vector3(0.5, 0.5, 0.5)

# === CONFIGURACIÓN VUELO ===
@export_category("Vuelo - Gargola")
@export var altura_min_spawn: float = 3.4
@export var altura_max_spawn: float = 5.2
@export var amplitud_oscilacion: float = 0.12
@export var velocidad_oscilacion: float = 1.8

# === CONFIGURACIÓN COMBATE ===
@export_category("Combate - Gargola")
@export var intervalo_disparo: float = 3.0
@export var velocidad_proyectil: float = 9.0
@export var dispersion_radianes: float = 0.12
@export var num_proyectiles: int = 2
@export var escala_inicial_esfera: float = 0.05
@export var escala_final_esfera: float = 0.4
@export var tiempo_disparo_en_atacar: float = 0.4
@export var tiempo_disolucion_muerte: float = 1.2
@export var velocidad_caida: float = 3.0
@export var altura_suelo_muerte: float = -1.0

# === ESTADO INTERNO ===
enum FaseCombate { IDLE, CARGA, ATAQUE }

var altura_base: float = 4.3
var oscilacion_fase: float = 0.0
var fase_combate: int = FaseCombate.IDLE
var timer_combate: float = 0.0
var ha_disparado_este_ciclo: bool = false

var cayendo: bool = false
var textura_piedra: StandardMaterial3D = null

# === VISUAL DE CARGA ===
var esfera_carga: MeshInstance3D = null
var bone_attachment_carga: BoneAttachment3D = null
var material_esfera: StandardMaterial3D = null

# === REFERENCIAS ===
var gargola_projectile_scene: PackedScene = preload("res://Entities/Projectiles/GargolaProjectile.tscn")


# ═══════════════════════════════════════════════════════════════════════════════
# HOOKS DE ENEMYBASE
# ═══════════════════════════════════════════════════════════════════════════════


func _on_enemy_ready():
	# Spawn en altura aleatoria entre los límites configurados
	altura_base = randf_range(altura_min_spawn, altura_max_spawn)
	oscilacion_fase = randf() * TAU  # Fase aleatoria para variar entre gárgolas

	# Apunta recto, no necesita tracking de torso (vuela)
	rastrear_jugador = false

	# Color místico para partículas de disolución
	color_borde_disolucion = Color(0.4, 0.2, 0.8)

	_crear_esfera_carga()
	_play_animation("FLY_IDLE")


func _on_state_walking():
	_play_animation("FLY_IDLE")
	fase_combate = FaseCombate.IDLE
	timer_combate = 0.0


func _on_state_shooting():
	fase_combate = FaseCombate.IDLE
	timer_combate = 0.0
	ha_disparado_este_ciclo = false
	if is_instance_valid(esfera_carga):
		esfera_carga.visible = false
	_play_animation("FLY_IDLE")


func take_damage(amount: float) -> void:
	if current_state == State.DYING or current_state == State.DEAD:
		return
	# Ya no pausa la animación al recibir daño, puede ser dañado en cualquier momento
	if is_instance_valid(esfera_carga):
		esfera_carga.visible = false
	fase_combate = FaseCombate.IDLE
	super.take_damage(amount)


func _on_state_dying():
	# No llamar a super._on_state_dying() para evitar que desactive colisiones
	# La Gárgola puede seguir siendo dañada mientras cae como piedra
	if is_instance_valid(esfera_carga):
		esfera_carga.visible = false
	_aplicar_textura_piedra()
	cayendo = true
	# Ya no hay disolución, se convierte en piedra y cae al suelo permanentemente


func _aplicar_textura_piedra():
	if not is_instance_valid(textura_piedra):
		textura_piedra = StandardMaterial3D.new()
		var tex = load("res://Entities/Enemies/GARGOLA/PIEDRA_D.jpg") as Texture2D
		if tex:
			textura_piedra.albedo_texture = tex
		textura_piedra.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	for mesh in _cached_mesh_instances:
		if is_instance_valid(mesh) and mesh is MeshInstance3D:
			mesh.material_override = textura_piedra


# ═══════════════════════════════════════════════════════════════════════════════
# FÍSICA (Override: vuelo sin gravedad, oscilación vertical)
# ═══════════════════════════════════════════════════════════════════════════════


func _physics_process(delta):
	if cayendo:
		velocity.y -= abs(ProjectSettings.get_setting("physics/3d/default_gravity")) * delta
		velocity.x = 0.0
		velocity.z = 0.0
		if global_position.y <= altura_suelo_muerte:
			global_position.y = altura_suelo_muerte
			velocity.y = 0.0
		move_and_slide()
		return

	oscilacion_fase += delta * velocidad_oscilacion
	velocity.y = 0.0
	velocity.z = 0.0
	global_position.y = altura_base + sin(oscilacion_fase) * amplitud_oscilacion

	match current_state:
		State.WALKING:
			_procesar_vuelo(delta)
		State.SHOOTING:
			_procesar_combate(delta)
		State.DYING:
			_procesar_muerte()
		State.DEAD:
			pass

	_empujar_si_en_barrera()
	move_and_slide()


func _procesar_vuelo(delta):
	velocity.x = -velocidad_caminar
	walked_distance += velocidad_caminar * delta

	if modo_pacifico:
		if global_position.x <= limite_pacifico_x:
			velocity.x = 0
			if not pacifico_detenido:
				pacifico_detenido = true
				_on_pacifico_detenido()
		return

	if walked_distance >= target_walk_distance:
		if _check_spacing():
			_change_state(State.SHOOTING)
		else:
			target_walk_distance += 0.3


func _procesar_combate(delta):
	velocity.x = 0
	timer_combate += delta

	match fase_combate:
		FaseCombate.IDLE:
			_actualizar_esfera_carga(0.0)
			if timer_combate >= intervalo_disparo:
				fase_combate = FaseCombate.CARGA
				timer_combate = 0.0
				ha_disparado_este_ciclo = false
				_play_animation("CARGA_ATAQUE")

		FaseCombate.CARGA:
			var duracion_carga: float = _get_animation_duration("CARGA_ATAQUE")
			if duracion_carga <= 0.0:
				duracion_carga = 1.0
			var progreso: float = clamp(timer_combate / duracion_carga, 0.0, 1.0)
			_actualizar_esfera_carga(progreso)
			if timer_combate >= duracion_carga:
				fase_combate = FaseCombate.ATAQUE
				timer_combate = 0.0
				_play_animation("ATACAR")

		FaseCombate.ATAQUE:
			_actualizar_esfera_carga(1.0)
			var duracion_atacar: float = _get_animation_duration("ATACAR")
			if not ha_disparado_este_ciclo and timer_combate >= tiempo_disparo_en_atacar:
				_disparar_proyectiles()
				ha_disparado_este_ciclo = true
			if timer_combate >= duracion_atacar:
				fase_combate = FaseCombate.IDLE
				timer_combate = 0.0
				_actualizar_esfera_carga(0.0)
				_play_animation("FLY_IDLE")


func _procesar_muerte():
	velocity.x = 0
	velocity.y = 0


func _empujar_si_en_barrera():
	if current_state == State.DYING or current_state == State.DEAD:
		return
	var barreras: Array[Node] = []
	barreras.assign(get_tree().get_nodes_in_group("barrera_destruye_flechas"))
	if barreras.is_empty():
		return
	for barrera_untyped in barreras:
		if not is_instance_valid(barrera_untyped):
			continue
		var barrera := barrera_untyped as Node3D
		if not barrera:
			continue
		var tam_x: float = 1.0
		if "tamano" in barrera:
			tam_x = barrera.tamano.x
		var limite_izquierdo: float = barrera.global_position.x - (tam_x * 0.5)
		if global_position.x >= limite_izquierdo - 0.5:
			if current_state != State.WALKING:
				_change_state(State.WALKING)
			velocity.x = -velocidad_caminar
			return


# ═══════════════════════════════════════════════════════════════════════════════
# ESFERA DE CARGA (visual rojo en las manos)
# ═══════════════════════════════════════════════════════════════════════════════


func _crear_esfera_carga():
	esfera_carga = MeshInstance3D.new()
	esfera_carga.name = "EsferaCarga"
	var sphere := SphereMesh.new()
	sphere.radius = 0.4
	sphere.height = 0.8
	esfera_carga.mesh = sphere

	material_esfera = StandardMaterial3D.new()
	material_esfera.albedo_color = GARGOLA_PROJECTILE_COLOR
	material_esfera.emission_enabled = true
	material_esfera.emission = GARGOLA_PROJECTILE_COLOR
	material_esfera.emission_energy_multiplier = 3.0
	material_esfera.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material_esfera.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	esfera_carga.material_override = material_esfera

	var skeleton := find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton:
		var bone_idx := _buscar_hueso_mano(skeleton)
		if bone_idx != -1:
			bone_attachment_carga = BoneAttachment3D.new()
			bone_attachment_carga.name = "AttachmentCarga"
			bone_attachment_carga.bone_name = skeleton.get_bone_name(bone_idx)
			skeleton.add_child(bone_attachment_carga)
			bone_attachment_carga.add_child(esfera_carga)
			esfera_carga.position = Vector3(0, 0.1, 0.3)
			esfera_carga.scale = Vector3.ONE * escala_inicial_esfera
			esfera_carga.visible = false
			return

	# Fallback: raíz del enemigo
	add_child(esfera_carga)
	esfera_carga.position = Vector3(0, 0.3, 0.3)
	esfera_carga.scale = Vector3.ONE * escala_inicial_esfera
	esfera_carga.visible = false


func _buscar_hueso_mano(skeleton: Skeleton3D) -> int:
	# Rig de la Gárgola usa nombres Blender (hand.r/hand.l)
	for nombre in ["hand.r", "hand.l", "Hand_R", "Hand_L", "mixamorig_RightHand", "mixamorig_LeftHand"]:
		var idx := skeleton.find_bone(nombre)
		if idx != -1:
			return idx
	# Fallback: hueso upper spine (entre las manos)
	for nombre in ["spine_02.x", "spine_01.x", "neck.x", "Spine2", "mixamorig_Spine2"]:
		var idx := skeleton.find_bone(nombre)
		if idx != -1:
			return idx
	return -1


func _actualizar_esfera_carga(progreso: float):
	if not is_instance_valid(esfera_carga):
		return
	if progreso <= 0.0:
		esfera_carga.visible = false
		return
	esfera_carga.visible = true
	var t_eased: float = _ease_out_back(progreso)
	var escala: float = lerp(escala_inicial_esfera, escala_final_esfera, t_eased)
	esfera_carga.scale = Vector3.ONE * escala


# ═══════════════════════════════════════════════════════════════════════════════
# DISPARO (2 proyectiles rectos con dispersión)
# ═══════════════════════════════════════════════════════════════════════════════


func _disparar_proyectiles():
	if not player_ref:
		player_ref = get_tree().get_first_node_in_group("player")
		if not player_ref:
			return
	if player_ref.get("is_dead"):
		return
	if not gargola_projectile_scene:
		return

	var spawn_pos: Vector3 = global_position
	if is_instance_valid(esfera_carga) and esfera_carga.visible:
		spawn_pos = esfera_carga.global_position
	var target_pos := player_ref.global_position + Vector3(0, 0.5, 0)
	var direccion_base := (target_pos - spawn_pos).normalized()

	var power := (velocidad_proyectil - 10.0) / 20.0
	for i in range(num_proyectiles):
		var offset_angulo := 0.0
		if num_proyectiles > 1:
			offset_angulo = (i - (num_proyectiles - 1) / 2.0) * dispersion_radianes
		var direccion_rotada := _rotar_direccion_xy(direccion_base, offset_angulo)
		var proyectil := PROJECTILE_POOL_REF.acquire(gargola_projectile_scene) as GargolaProjectile
		if not proyectil:
			continue
		proyectil.scale = PROJECTILE_SCALE
		proyectil.initialize(direccion_rotada, power)
		proyectil.speed = velocidad_proyectil
		PROJECTILE_POOL_REF.activate(proyectil, get_tree().root, spawn_pos)

	# Ocultar esfera tras soltar los proyectiles
	if is_instance_valid(esfera_carga):
		esfera_carga.visible = false


func _rotar_direccion_xy(dir: Vector3, angulo: float) -> Vector3:
	var cos_a := cos(angulo)
	var sin_a := sin(angulo)
	return Vector3(
		dir.x * cos_a - dir.y * sin_a,
		dir.x * sin_a + dir.y * cos_a,
		0.0
	).normalized()


# ═══════════════════════════════════════════════════════════════════════════════
# EASING (juice de crecimiento igual a flechas de la arquera)
# ═══════════════════════════════════════════════════════════════════════════════


func _ease_out_back(x: float) -> float:
	var c1: float = 1.70158
	var c3: float = c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)
