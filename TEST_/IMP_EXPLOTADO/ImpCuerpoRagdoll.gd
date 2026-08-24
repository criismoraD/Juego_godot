class_name ImpCuerpoRagdoll
extends Node3D

## Controlador de Ragdoll para el modelo IMP_CUERPO.
## El GLB viene horneado a escala real (0.55 m, sin escalas de nodo),
## por lo que las PhysicalBone3D y sus cápsulas viven en metros directamente.
## Administra PhysicalBoneSimulator3D y PhysicalBone3D para simulación física realista.

signal ragdoll_activado
signal ragdoll_detenido

@export var masa_total: float = 16.0
@export var impulso_inicial_defecto: Vector3 = Vector3(0.0, 3.5, 0.0)
@export var tiempo_antes_disolver: float = 3.0  ## Segundos tras iniciar_disolucion_automatica()
@export var velocidad_maxima_hueso: float = 20.0  ## Límite de velocidad lineal por hueso (m/s) anti-divergencia
@export var radio_contencion_metros: float = 4.0  ## Radio máximo desde el origen del ragdoll (anti-estiramiento)

const DISSOLVE_SHADER: Shader = preload("res://System/Shaders/dissolve.gdshader")

var skeleton: Skeleton3D = null
var simulator: PhysicalBoneSimulator3D = null
var is_ragdoll_active: bool = false
var _physical_bones: Array[PhysicalBone3D] = []
var _initial_transform: Transform3D

# === Partículas moradas al desaparecer (configuradas por ImpEnemy) ===
var p_configurado: bool = false
var p_color: Color = Color(0.4, 0.0, 0.5)
var p_cantidad: int = 240
var p_vida: float = 2.0
var p_caja: Vector3 = Vector3(0.2, 0.5, 0.1)
var p_dispersion: float = 20.0
var p_vel_min: float = 0.1
var p_vel_max: float = 0.5
var p_gravedad: Vector3 = Vector3(0, 0.1, 0)
var p_intensidad: float = 3.0
var p_offset_y: float = 0.3
var p_escala_min: float = 0.005
var p_escala_max: float = 0.02


func _ready() -> void:
	_initial_transform = global_transform
	_buscar_nodos()


func _buscar_nodos() -> void:
	for child in find_children("*", "Skeleton3D", true, false):
		skeleton = child as Skeleton3D
		break

	if skeleton:
		for child in skeleton.get_children():
			if child is PhysicalBoneSimulator3D:
				simulator = child as PhysicalBoneSimulator3D
				break

	if simulator:
		_physical_bones.clear()
		for child in simulator.get_children():
			if child is PhysicalBone3D:
				var pb := child as PhysicalBone3D
				pb.collision_layer = 4
				pb.collision_mask = 1  # Colisiona contra el suelo
				_physical_bones.append(pb)
		_aplicar_masas()


## Distribuye masa_total entre los huesos proporcional al volumen de su cápsula.
func _aplicar_masas() -> void:
	if masa_total <= 0.0 or _physical_bones.is_empty():
		return
	var volumenes: Array[float] = []
	var total_volumen: float = 0.0
	for pb in _physical_bones:
		var vol := _volumen_capsula(pb)
		volumenes.append(vol)
		total_volumen += vol
	if total_volumen <= 0.0:
		return
	for i in _physical_bones.size():
		_physical_bones[i].mass = maxf(masa_total * volumenes[i] / total_volumen, 0.001)


func _volumen_capsula(pb: PhysicalBone3D) -> float:
	for child in pb.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape is CapsuleShape3D:
			var capsula := ((child as CollisionShape3D).shape as CapsuleShape3D)
			var r := capsula.radius
			var cilindro := PI * r * r * maxf(capsula.height - 2.0 * r, 0.0)
			var esferas := (4.0 / 3.0) * PI * r * r * r
			return cilindro + esferas
	return 0.0


## Activa la simulación física (ragdoll)
func activar_ragdoll(impulso: Vector3 = Vector3.ZERO) -> void:
	if not simulator:
		_buscar_nodos()
		if not simulator:
			push_warning("[ImpCuerpoRagdoll] No se encontró PhysicalBoneSimulator3D.")
			return

	is_ragdoll_active = true
	simulator.physical_bones_start_simulation()

	for pb in _physical_bones:
		if is_instance_valid(pb):
			PhysicsServer3D.body_set_collision_layer(pb.get_rid(), 4)
			PhysicsServer3D.body_set_collision_mask(pb.get_rid(), 1)
			if impulso != Vector3.ZERO:
				pb.linear_velocity = impulso
			elif impulso_inicial_defecto != Vector3.ZERO:
				pb.linear_velocity = impulso_inicial_defecto

	ragdoll_activado.emit()


## Detiene la simulación física (ragdoll)
func detener_ragdoll() -> void:
	if not simulator:
		return
	simulator.physical_bones_stop_simulation()
	is_ragdoll_active = false
	ragdoll_detenido.emit()


## Watchdog anti-divergencia: mientras el ragdoll está activo, limita la velocidad
## de cada hueso y los mantiene dentro del radio de contención. Si una articulación
## diverge (modelo estirado por toda la pantalla), este guardia lo frena al frame
## siguiente sin esperar a que la física se rompa visualmente.
func _physics_process(_delta: float) -> void:
	if not is_ragdoll_active:
		return

	var origen := global_position
	var velocidad_max_cuad: float = velocidad_maxima_hueso * velocidad_maxima_hueso
	for pb in _physical_bones:
		if not is_instance_valid(pb):
			continue

		if pb.linear_velocity.length_squared() > velocidad_max_cuad:
			pb.linear_velocity = pb.linear_velocity.limit_length(velocidad_maxima_hueso)

		var desvio := pb.global_position - origen
		if desvio.length() > radio_contencion_metros:
			pb.global_position = origen + desvio.limit_length(radio_contencion_metros)
			pb.linear_velocity = -desvio.normalized() * minf(pb.linear_velocity.length(), 2.0)


## Reinicia el modelo a su posición original
func reiniciar() -> void:
	detener_ragdoll()
	global_transform = _initial_transform
	if skeleton:
		for i in range(skeleton.get_bone_count()):
			skeleton.reset_bone_pose(i)
	if simulator:
		for pb in _physical_bones:
			if is_instance_valid(pb):
				pb.linear_velocity = Vector3.ZERO
				pb.angular_velocity = Vector3.ZERO


## Centro actual del cadáver: promedio de las posiciones globales de los huesos físicos.
## Útil para colocar efectos en la última posición del cuerpo mientras yace en el suelo.
func obtener_centro_cadaver() -> Vector3:
	var suma := Vector3.ZERO
	var cantidad := 0
	for pb in _physical_bones:
		if is_instance_valid(pb):
			suma += pb.global_position
			cantidad += 1
	return suma / float(cantidad) if cantidad > 0 else global_position


## Programa la disolución del ragdoll (llamado por el enemigo al morir desmembrado).
func iniciar_disolucion_automatica(color_disolucion: Color = Color(0.4, 0.0, 0.5)) -> void:
	get_tree().create_timer(tiempo_antes_disolver).timeout.connect(
		func():
			if is_instance_valid(self) and is_inside_tree():
				_disolver(color_disolucion)
	)


## Recibe la configuración de las partículas de disolución (mismo efecto que la
## muerte normal del Imp) para emitirlas en la última posición del cadáver.
func configurar_particulas_desaparicion(
	color_: Color,
	cantidad_: int,
	vida_: float,
	caja_: Vector3,
	dispersion_: float,
	vel_min_: float,
	vel_max_: float,
	gravedad_: Vector3,
	intensidad_: float,
	offset_y_: float,
	escala_min_: float,
	escala_max_: float
) -> void:
	p_color = color_
	p_cantidad = cantidad_
	p_vida = vida_
	p_caja = caja_
	p_dispersion = dispersion_
	p_vel_min = vel_min_
	p_vel_max = vel_max_
	p_gravedad = gravedad_
	p_intensidad = intensidad_
	p_offset_y = offset_y_
	p_escala_min = escala_min_
	p_escala_max = escala_max_
	p_configurado = true


func _disolver(color_disolucion: Color) -> void:
	# Partículas moradas en la ÚLTIMA posición del cadáver al momento de desaparecer
	if p_configurado:
		ImpEnemy.crear_particulas_disolucion(
			self,
			obtener_centro_cadaver(),
			p_color,
			p_cantidad,
			p_vida,
			p_caja,
			p_dispersion,
			p_vel_min,
			p_vel_max,
			p_gravedad,
			p_escala_min,
			p_escala_max,
			p_intensidad,
			p_offset_y
		)
	var materiales: Array[Dictionary] = []
	for m in find_children("*", "MeshInstance3D", true, false):
		var mesh_inst := m as MeshInstance3D
		if not is_instance_valid(mesh_inst):
			continue
		var mat := ShaderMaterial.new()
		mat.shader = DISSOLVE_SHADER
		mat.set_shader_parameter("dissolve_amount", 0.0)
		mat.set_shader_parameter("glow_color", color_disolucion)
		mat.set_shader_parameter("glow_intensity", 6.0)
		mat.set_shader_parameter("edge_thickness", 0.05)
		mat.set_shader_parameter("noise_scale", 20.0)
		var orig_mat: Material = mesh_inst.get_surface_override_material(0)
		if orig_mat == null and mesh_inst.mesh:
			orig_mat = mesh_inst.mesh.surface_get_material(0)
		if orig_mat is StandardMaterial3D:
			var std_mat := orig_mat as StandardMaterial3D
			if std_mat.albedo_texture:
				mat.set_shader_parameter("albedo_texture", std_mat.albedo_texture)
			var col := std_mat.albedo_color
			mat.set_shader_parameter("albedo_tint", Vector3(col.r, col.g, col.b))
		mesh_inst.material_override = mat
		materiales.append({"mesh": mesh_inst, "mat": mat})

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(func(val: float):
		for item in materiales:
			if is_instance_valid(item["mesh"]) and is_instance_valid(item["mat"]):
				item["mat"].set_shader_parameter("dissolve_amount", val)
	, 0.0, 1.0, 1.2)
	tween.tween_property(self, "scale", Vector3.ZERO, 0.8) \
		.set_delay(0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.finished.connect(func():
		queue_free()
	)
