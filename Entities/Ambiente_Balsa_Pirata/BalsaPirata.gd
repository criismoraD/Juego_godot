class_name BalsaPirata
extends Node3D
## Balsa pirata de ambientación: flota sobre el agua con vaivén continuo
## y puede navegar a lo largo del eje X hacia un punto de parada.
##
## Al igual que la Canoa Aliada, el modelo GLB no trae animaciones horneadas,
## por lo que la flotación se genera por código mediante ondas sinusoidales:
##   - Flotación (Y): oscilación vertical respecto a la línea de flotación.
##   - Balanceo (Roll Z): mecida lateral.
##   - Cabeceo (Pitch X): proa y popa suben alternadamente.
##   - Deriva (X/Z): leve oscilación por corrientes de agua.
##   - Guinada (Yaw Y): giro suave sobre la superficie.
##
## Permite desplazamiento guiado en X hacia un punto de parada mediante `navegar_hacia_x()`,
## emitiendo la señal `destino_alcanzado` al llegar y manteniendo la flotación.

# === SEÑALES ===
signal destino_alcanzado
signal balsa_destruida

# === CONSTANTES ===
const FASE_ALEATORIA: float = -1.0  ## Centinela: al iniciar, genera una fase aleatoria
const UMBRAL_LLEGADA_X: float = 0.05  ## Tolerancia en metros para considerar destino alcanzado
const MAT_BALSA: Material = preload("res://TEST_/Balsa piarata/Balsa piarata_MAT.tres")
const ESCENA_BALSA_DESTRUIDA: PackedScene = preload("res://TEST_/Balsa pirata destruida/Balsa pirata destruida.glb")
const MAT_BALSA_DESTRUIDA: Material = preload("res://TEST_/Balsa pirata destruida/Balsa pirata destruida_MAT.tres")
const SCRIPT_MADERO_VOLADOR: Script = preload("res://Entities/Ambiente_Balsa_Pirata/MaderoVolador.gd")
const CANTIDAD_MADEROS_VOLADORES: int = 3
const CONFIG_MADEROS_VOLADORES: Array[Dictionary] = [
	{
		"offset": Vector3(0.25, 0.25, 0.1),
		"impulso": Vector3(3.4, 7.2, 0.25)
	},
	{
		"offset": Vector3(0.0, 0.35, -0.15),
		"impulso": Vector3(1.9, 8.2, -0.3)
	},
	{
		"offset": Vector3(-0.25, 0.3, 0.05),
		"impulso": Vector3(-3.2, 7.5, 0.15)
	}
]
const ESCENA_EXPLOSION_PILAR: PackedScene = preload("res://Entities/Enemigo_Lonko/Explocion_Pilar.tscn")
const TEXTURA_ROCAS_NEGRAS: Texture2D = preload("res://Entities/Enemigo_Lonko/PIEDRAS_NEGRAS_ DESTRUCION.png")
const SFX_EXPLOSION_01: AudioStream = preload("res://Entities/Enemigo_Lonko/EXPLOSION01.mp3")
const SFX_EXPLOSION_02: AudioStream = preload("res://Entities/Enemigo_Lonko/EXPLOSION02.mp3")
const CANTIDAD_EXPLOSIONES: int = 3
const INTERVALO_EXPLOSIONES: float = 0.35
const DURACION_HUNDIMIENTO: float = 5.5
const PROFUNDIDAD_HUNDIMIENTO: float = 2.4
const INCLINACION_ROLL_Z: float = 28.0
const INCLINACION_PITCH_X: float = -12.0
const OFFSETS_EXPLOSION: Array[Vector3] = [
	Vector3(-0.9, 0.25, 0.15),
	Vector3(0.0, 0.35, -0.1),
	Vector3(0.9, 0.25, 0.1)
]
const ESCALA_EXPLOSION_VFX: float = 1.1
const DURACION_VFX_EXPLOSION: float = 1.4
const DURACION_PARTICULAS_ROCAS: float = 3.0

# === FLOTACIÓN VERTICAL (Y) ===
@export_category("Flotación Vertical (Y)")
@export var amplitud_flotacion: float = 0.06  ## Amplitud del sube y baja sobre el agua (metros)
@export var frecuencia_flotacion: float = 0.32  ## Velocidad de oscilación vertical (Hz)

# === BALANCEO DE COSTADO (ROLL Z) ===
@export_category("Balanceo Lateral (Roll Z)")
@export var amplitud_balanceo: float = 2.2  ## Amplitud del balanceo lateral (grados)
@export var frecuencia_balanceo: float = 0.25  ## Velocidad del balanceo (Hz)

# === CABECEO PROA-POPA (PITCH X) ===
@export_category("Cabeceo Frontal (Pitch X)")
@export var amplitud_cabeceo: float = 1.8  ## Amplitud del cabeceo frontal (grados)
@export var frecuencia_cabeceo: float = 0.38  ## Velocidad del cabeceo (Hz)

# === DERIVA HORIZONTAL (X / Z) ===
@export_category("Deriva Horizontal")
@export var amplitud_deriva_x: float = 0.04  ## Amplitud de la deriva por corriente (metros)
@export var frecuencia_deriva_x: float = 0.10  ## Velocidad de la deriva en X (Hz)
@export var amplitud_deriva_z: float = 0.05  ## Amplitud de la deriva transversal (metros)
@export var frecuencia_deriva_z: float = 0.08  ## Velocidad de la deriva en Z (Hz)

# === GUINADA (YAW Y) ===
@export_category("Guinada (Yaw Y)")
@export var amplitud_guinada: float = 1.6  ## Amplitud del giro lento sobre el agua (grados)
@export var frecuencia_guinada: float = 0.12  ## Velocidad de la guinada (Hz)

# === COMPORTAMIENTO Y NAVEGACIÓN ===
@export_category("Comportamiento")
@export var capa_visual: int = 2  ## Capa de renderizado (Fondo = 2)
@export var flotar_al_iniciar: bool = true  ## Si true, comienza a flotar desde el primer frame
@export var escala_tiempo: float = 1.0  ## Multiplicador global de la velocidad de animación
@export var fase_flotacion: float = FASE_ALEATORIA
@export var fase_balanceo: float = FASE_ALEATORIA
@export var fase_cabeceo: float = FASE_ALEATORIA
@export var fase_deriva_x: float = FASE_ALEATORIA
@export var fase_deriva_z: float = FASE_ALEATORIA
@export var fase_guinada: float = FASE_ALEATORIA

# === ROTACIÓN Y ORIENTACIÓN ===
@export_category("Orientación")
@export var rotacion_y_proa: float = 180.0  ## Grados Y para que la balsa apunte hacia la izquierda

# === ESTADO PRIVADO ===
var _tiempo: float = 0.0
var _posicion_base: Vector3 = Vector3.ZERO
var _rotacion_base: Vector3 = Vector3.ZERO
var _flotando: bool = false
var _fase_flotacion: float = 0.0
var _fase_balanceo: float = 0.0
var _fase_cabeceo: float = 0.0
var _fase_deriva_x: float = 0.0
var _fase_deriva_z: float = 0.0
var _fase_guinada: float = 0.0

var _navegando: bool = false
var _x_destino: float = 0.0
var _velocidad_navegacion: float = 0.0
var _direccion_navegacion: float = 1.0

var _destruida: bool = false
var _en_hundimiento: bool = false
var _tween_hundimiento: Tween = null
var _maderos_lanzados: Array[Node3D] = []

# === FUNCIONES BUILT-IN ===
func _ready() -> void:
	if not is_zero_approx(rotacion_y_proa) and is_zero_approx(rotation_degrees.y):
		rotation_degrees.y = rotacion_y_proa
	_posicion_base = position
	_rotacion_base = rotation_degrees
	_asegurar_materiales()
	_inicializar_fases()
	_aplicar_capa_visual_recursiva(self)
	_flotando = flotar_al_iniciar
	set_process(_flotando or _navegando)


func _process(delta: float) -> void:
	if delta <= 0.0 or _destruida:
		return

	if _navegando:
		_actualizar_navegacion(delta)

	if not _flotando:
		return

	_tiempo += delta * escala_tiempo
	_aplicar_flotacion()


# === FUNCIONES PÚBLICAS ===
## Ordena a todos los tripulantes a bordo que comiencen el combate estético.
func iniciar_combate_tripulacion() -> void:
	if _destruida:
		return
	for hijo in find_children("*", "TripulanteBarcoFondoGoblinGirl", true, false):
		if hijo.has_method("iniciar_combate"):
			hijo.iniciar_combate()


## Inicia el desplazamiento horizontal hacia una coordenada X objetivo.
func navegar_hacia_x(x_destino: float, velocidad: float) -> void:
	if _destruida:
		return
	_x_destino = x_destino
	_velocidad_navegacion = absf(velocidad)
	_direccion_navegacion = 1.0 if _x_destino > _posicion_base.x else -1.0
	_navegando = true
	_flotando = true
	set_process(true)


## Detiene la navegación horizontal sin frenar la flotación.
func detener_navegacion() -> void:
	_navegando = false


## Indica si la balsa está en movimiento horizontal hacia su destino.
func esta_navegando() -> bool:
	return _navegando


## Inicia (o reanuda) el vaivén de la balsa.
func flotar() -> void:
	if _destruida:
		return
	_flotando = true
	set_process(true)


## Detiene el vaivén y devuelve la balsa a su transformada base.
func detener() -> void:
	_flotando = false
	_navegando = false
	set_process(false)
	_restaurar_transformada_base()


## Indica si la balsa se está meciendo actualmente sobre el agua.
func esta_flotando() -> bool:
	return _flotando


## Reinicia el ciclo de flotación desde cero, regenerando las fases aleatorias.
func reiniciar() -> void:
	_tiempo = 0.0
	_inicializar_fases()
	_restaurar_transformada_base()


## Fija la posición base (sin desfase sinusoidal).
func fijar_posicion_base(nueva_pos: Vector3) -> void:
	_posicion_base = nueva_pos
	position = _posicion_base


## Retorna la posición base actual.
func obtener_posicion_base() -> Vector3:
	return _posicion_base


## Desplazamiento (en metros) respecto a la posición base para un instante dado.
func calcular_desplazamiento(tiempo: float) -> Vector3:
	var onda_x: float = sin(tiempo * frecuencia_deriva_x * TAU + _fase_deriva_x)
	var onda_y: float = sin(tiempo * frecuencia_flotacion * TAU + _fase_flotacion)
	var onda_z: float = sin(tiempo * frecuencia_deriva_z * TAU + _fase_deriva_z)

	return Vector3(
		amplitud_deriva_x * onda_x,
		amplitud_flotacion * onda_y,
		amplitud_deriva_z * onda_z
	)


## Rotación absoluta (en grados) de la balsa para un instante dado.
func calcular_rotacion_grados(tiempo: float) -> Vector3:
	var onda_cabeceo: float = sin(tiempo * frecuencia_cabeceo * TAU + _fase_cabeceo)
	var onda_guinada: float = sin(tiempo * frecuencia_guinada * TAU + _fase_guinada)
	var onda_balanceo: float = sin(tiempo * frecuencia_balanceo * TAU + _fase_balanceo)

	return Vector3(
		_rotacion_base.x + amplitud_cabeceo * onda_cabeceo,
		_rotacion_base.y + amplitud_guinada * onda_guinada,
		_rotacion_base.z + amplitud_balanceo * onda_balanceo
	)


## Inicia la destrucción de la balsa pirata: detiene movimiento, mata a los tripulantes,
## sustituye el modelo por la versión destruida, detona 3 explosiones en cadena
## y se hunde lentamente inclinándose a un costado.
func destruir_balsa() -> void:
	if _destruida:
		return
	_destruida = true
	_flotando = false
	_navegando = false
	set_process(false)

	_matar_tripulacion()
	_sustituir_por_modelo_destruido()
	_lanzar_maderos_voladores()
	_explotar_en_cadena()
	_iniciar_hundimiento()
	balsa_destruida.emit()


## Retorna true si la balsa ha iniciado o completado su destrucción.
func esta_destruida() -> bool:
	return _destruida


## Retorna los maderos voladores expulsados durante la destrucción.
func obtener_maderos_lanzados() -> Array[Node3D]:
	return _maderos_lanzados


# === FUNCIONES PRIVADAS ===
func _actualizar_navegacion(delta: float) -> void:
	var paso: float = _velocidad_navegacion * delta * _direccion_navegacion
	var nueva_x: float = _posicion_base.x + paso

	var llego: bool = false
	if _direccion_navegacion > 0.0 and nueva_x >= _x_destino:
		llego = true
	elif _direccion_navegacion < 0.0 and nueva_x <= _x_destino:
		llego = true

	if llego:
		_posicion_base.x = _x_destino
		_navegando = false
		destino_alcanzado.emit()
	else:
		_posicion_base.x = nueva_x


func _inicializar_fases() -> void:
	_fase_flotacion = _resolver_fase(fase_flotacion)
	_fase_balanceo = _resolver_fase(fase_balanceo)
	_fase_cabeceo = _resolver_fase(fase_cabeceo)
	_fase_deriva_x = _resolver_fase(fase_deriva_x)
	_fase_deriva_z = _resolver_fase(fase_deriva_z)
	_fase_guinada = _resolver_fase(fase_guinada)


func _resolver_fase(fase_configurada: float) -> float:
	if fase_configurada >= 0.0:
		return fase_configurada
	return randf() * TAU


func _aplicar_flotacion() -> void:
	position = _posicion_base + calcular_desplazamiento(_tiempo)
	rotation_degrees = calcular_rotacion_grados(_tiempo)


func _restaurar_transformada_base() -> void:
	position = _posicion_base
	rotation_degrees = _rotacion_base


func _asegurar_materiales() -> void:
	if not MAT_BALSA:
		return
	var modelo_balsa := find_child("BalsaPirataModel", true, false)
	if not modelo_balsa:
		return
	for m in modelo_balsa.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if is_instance_valid(mi) and mi.mesh:
			for s in range(mi.mesh.get_surface_count()):
				mi.set_surface_override_material(s, MAT_BALSA)


func _aplicar_capa_visual_recursiva(nodo: Node) -> void:
	if nodo is VisualInstance3D:
		nodo.layers = capa_visual
	for hijo in nodo.get_children():
		_aplicar_capa_visual_recursiva(hijo)


func _matar_tripulacion() -> void:
	for hijo in find_children("*", "TripulanteBarcoFondoGoblinGirl", true, false):
		if hijo.has_method("morir"):
			hijo.morir()


func _sustituir_por_modelo_destruido() -> void:
	if not ESCENA_BALSA_DESTRUIDA:
		return

	var modelo_actual: Node3D = find_child("BalsaPirataModel", true, false) as Node3D
	var transform_modelo: Transform3D = Transform3D.IDENTITY
	if is_instance_valid(modelo_actual):
		transform_modelo = modelo_actual.transform
		modelo_actual.name = "BalsaPirataModel_Old"
		modelo_actual.queue_free()

	var nuevo_modelo: Node3D = ESCENA_BALSA_DESTRUIDA.instantiate() as Node3D
	if not nuevo_modelo:
		return

	nuevo_modelo.name = "BalsaPirataModel"
	nuevo_modelo.transform = transform_modelo
	add_child(nuevo_modelo)

	if MAT_BALSA_DESTRUIDA:
		for m in nuevo_modelo.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if is_instance_valid(mi) and mi.mesh:
				for s in range(mi.mesh.get_surface_count()):
					mi.set_surface_override_material(s, MAT_BALSA_DESTRUIDA)

	_aplicar_capa_visual_recursiva(nuevo_modelo)


func _lanzar_maderos_voladores() -> void:
	var root_scene: Node = get_tree().current_scene if is_inside_tree() and get_tree() else null
	if root_scene == null and is_inside_tree() and get_tree():
		root_scene = get_tree().root
	if root_scene == null:
		root_scene = get_parent()
	if root_scene == null:
		root_scene = self

	var altura_agua: float = _posicion_base.y - 0.05
	if _posicion_base.is_zero_approx():
		altura_agua = global_position.y - 0.05

	_maderos_lanzados.clear()
	for cfg in CONFIG_MADEROS_VOLADORES:
		var madero: Node3D = SCRIPT_MADERO_VOLADOR.new() as Node3D
		root_scene.add_child(madero)
		var offset: Vector3 = cfg["offset"]
		var impulso: Vector3 = cfg["impulso"]
		var spawn_pos: Vector3 = global_position + global_transform.basis * offset
		madero.lanzar(spawn_pos, impulso, altura_agua, capa_visual)
		_aplicar_capa_visual_recursiva(madero)
		_maderos_lanzados.append(madero)


func _explotar_en_cadena() -> void:
	_explotar_paso(0)


func _explotar_paso(indice: int) -> void:
	if indice >= CANTIDAD_EXPLOSIONES:
		return
	if not is_inside_tree():
		return

	_spawn_explosion(indice)

	if indice + 1 < CANTIDAD_EXPLOSIONES:
		get_tree().create_timer(INTERVALO_EXPLOSIONES).timeout.connect(
			func() -> void:
				if is_instance_valid(self) and is_inside_tree():
					_explotar_paso(indice + 1)
		)


func _spawn_explosion(indice: int) -> void:
	var root_scene: Node = get_tree().current_scene
	if root_scene == null:
		root_scene = get_tree().root

	var offset: Vector3 = OFFSETS_EXPLOSION[clampi(indice, 0, OFFSETS_EXPLOSION.size() - 1)]
	var spawn_pos: Vector3 = global_position + global_transform.basis * offset

	_spawn_vfx_explosion(root_scene, spawn_pos)
	_spawn_particulas_rocas(root_scene, spawn_pos)
	_spawn_sfx_explosion(root_scene, spawn_pos)


func _spawn_vfx_explosion(root_scene: Node, spawn_pos: Vector3) -> void:
	if not ESCENA_EXPLOSION_PILAR:
		return
	var exp_node := ESCENA_EXPLOSION_PILAR.instantiate() as Node3D
	if not exp_node:
		return
	root_scene.add_child(exp_node)
	exp_node.global_position = spawn_pos
	exp_node.scale = Vector3(ESCALA_EXPLOSION_VFX, ESCALA_EXPLOSION_VFX, ESCALA_EXPLOSION_VFX)
	_aplicar_capa_visual_recursiva(exp_node)

	get_tree().create_timer(DURACION_VFX_EXPLOSION).timeout.connect(func() -> void:
		if is_instance_valid(exp_node):
			exp_node.queue_free()
	)


func _spawn_particulas_rocas(root_scene: Node, spawn_pos: Vector3) -> void:
	if not TEXTURA_ROCAS_NEGRAS:
		return
	var parts := GPUParticles3D.new()
	parts.name = "ParticulasRocasBalsa"
	parts.amount = 14
	parts.lifetime = 2.4
	parts.one_shot = true
	parts.explosiveness = 0.85

	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(0.4, 0.15, 0.4)
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 45.0
	pmat.initial_velocity_min = 2.0
	pmat.initial_velocity_max = 5.0
	pmat.gravity = Vector3(0, -11.0, 0)
	pmat.scale_min = 0.25
	pmat.scale_max = 0.6
	pmat.angle_min = 0.0
	pmat.angle_max = 360.0
	pmat.angular_velocity_min = -180.0
	pmat.angular_velocity_max = 180.0
	parts.process_material = pmat

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = TEXTURA_ROCAS_NEGRAS
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.particles_anim_h_frames = 4
	mat.particles_anim_v_frames = 1
	mat.particles_anim_loop = false

	var quad := QuadMesh.new()
	quad.size = Vector2(0.35, 0.35)
	quad.material = mat
	parts.draw_pass_1 = quad

	root_scene.add_child(parts)
	parts.global_position = spawn_pos
	_aplicar_capa_visual_recursiva(parts)
	parts.emitting = true

	get_tree().create_timer(DURACION_PARTICULAS_ROCAS).timeout.connect(func() -> void:
		if is_instance_valid(parts):
			parts.queue_free()
	)


func _spawn_sfx_explosion(root_scene: Node, spawn_pos: Vector3) -> void:
	var stream: AudioStream = SFX_EXPLOSION_01 if randf() < 0.5 else SFX_EXPLOSION_02
	if not stream:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = -1.0
	player.unit_size = 12.0
	player.max_distance = 60.0
	player.bus = "Master"
	root_scene.add_child(player)
	player.global_position = spawn_pos
	player.play()
	player.finished.connect(player.queue_free)


func _iniciar_hundimiento() -> void:
	_en_hundimiento = true
	if not is_inside_tree():
		return

	if _tween_hundimiento and _tween_hundimiento.is_valid():
		_tween_hundimiento.kill()

	_tween_hundimiento = create_tween()
	_tween_hundimiento.set_parallel(true)

	var y_final: float = position.y - PROFUNDIDAD_HUNDIMIENTO
	var rot_z_final: float = rotation_degrees.z + INCLINACION_ROLL_Z
	var rot_x_final: float = rotation_degrees.x + INCLINACION_PITCH_X

	_tween_hundimiento.tween_property(self, "position:y", y_final, DURACION_HUNDIMIENTO)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween_hundimiento.tween_property(self, "rotation_degrees:z", rot_z_final, DURACION_HUNDIMIENTO)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween_hundimiento.tween_property(self, "rotation_degrees:x", rot_x_final, DURACION_HUNDIMIENTO)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_tween_hundimiento.chain().tween_callback(func() -> void:
		queue_free()
	)


