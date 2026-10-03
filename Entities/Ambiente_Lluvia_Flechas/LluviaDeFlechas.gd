@tool
class_name LluviaDeFlechas
extends Node3D

## Controlador de efecto decorativo de Lluvia de Flechas para ambientación de batalla.
## Simula andanadas de flechas de arqueras Goblin moradas en el fondo con balística parabólica,
## selectores de frecuencia, color, capas de render y profundidad Z.

signal rafaga_iniciada(cantidad: int)
signal rafaga_completada()

# ═══════════════════════════════════════════════════════════════════════════════
# ENUMS Y CONSTANTES
# ═══════════════════════════════════════════════════════════════════════════════

enum FrecuenciaModo {
	LENTA,        ## Cada ~6.0 segundos
	MEDIA,        ## Cada ~3.5 segundos (Recomendado)
	RAPIDA,       ## Cada ~1.8 segundos
	CONTINUA,     ## Cada ~0.8 segundos
	PERSONALIZADA ## Utiliza intervalo_segundos
}

enum ColorPreset {
	GOBLIN_MORADA,    ## Magenta característico: Color(1.0, 0.38, 0.72)
	ROSA_NEON,        ## Rosa eléctrico brillante: Color(1.0, 0.08, 0.58)
	VERDE_VENENO,     ## Verde tóxico: Color(0.2, 1.0, 0.3)
	ROJO_FUEGO,       ## Rojo escarlata: Color(1.0, 0.28, 0.12)
	DORADO_IMPERIO,   ## Oro imperial: Color(1.0, 0.82, 0.2)
	AZUL_MISTICO,     ## Azul celeste mágico: Color(0.2, 0.65, 1.0)
	BLANCO_PURO,      ## Blanco fantasmal: Color(1.0, 1.0, 1.0)
	PERSONALIZADO     ## Libre según color_flechas
}

enum PlanoProfundidad {
	FONDO_LEJANO,    ## Z = -16.0
	FONDO_MEDIO,     ## Z = -8.0 (Ideal para nivel tutorial)
	FONDO_CERCANO,   ## Z = -3.5
	PLANO_JUGABLE,   ## Z = 0.0
	PRIMER_PLANO,    ## Z = 3.0
	PERSONALIZADO    ## Utiliza profundidad_z_personalizada
}

enum DireccionPreset {
	DERECHA_A_IZQUIERDA, ## Vector3(-1.0, 0.42, 0.0) — Ataque clásico goblin desde el flanco derecho
	IZQUIERDA_A_DERECHA, ## Vector3(1.0, 0.42, 0.0)  — Ataque desde el flanco izquierdo
	DESDE_EL_CIELO,      ## Vector3(-0.6, -0.8, 0.0) — Lluvia en ángulo desde lo alto
	PERSONALIZADA        ## Utiliza direccion_personalizada
}

const SHADER_OUTLINE: Shader = preload("res://System/Shaders/TOON_PROYECTIL_LINEA.gdshader")
const SCRIPT_FLECHA_DECORATIVA: Script = preload("res://Entities/Ambiente_Lluvia_Flechas/FlechaDecorativa.gd")
const COLOR_GOBLIN_MORADA: Color = Color(1.0, 0.38, 0.72, 1.0)
const COLOR_ROSA_NEON: Color = Color(1.0, 0.08, 0.58, 1.0)
const COLOR_VERDE_VENENO: Color = Color(0.2, 1.0, 0.3, 1.0)
const COLOR_ROJO_FUEGO: Color = Color(1.0, 0.28, 0.12, 1.0)
const COLOR_DORADO_IMPERIO: Color = Color(1.0, 0.82, 0.2, 1.0)
const COLOR_AZUL_MISTICO: Color = Color(0.2, 0.65, 1.0, 1.0)
const COLOR_BLANCO_PURO: Color = Color(1.0, 1.0, 1.0, 1.0)

const Z_FONDO_LEJANO: float = -16.0
const Z_FONDO_MEDIO: float = -8.0
const Z_FONDO_CERCANO: float = -3.5
const Z_PLANO_JUGABLE: float = 0.0
const Z_PRIMER_PLANO: float = 3.0

# ═══════════════════════════════════════════════════════════════════════════════
# PROPIEDADES EXPORTADAS
# ═══════════════════════════════════════════════════════════════════════════════

@export_group("Ráfagas y Frecuencia")
@export var modo_frecuencia: FrecuenciaModo = FrecuenciaModo.MEDIA:
	set(val):
		modo_frecuencia = val
		_actualizar_intervalo_por_modo()

@export_range(0.2, 30.0, 0.1) var intervalo_segundos: float = 3.5
@export_range(0.0, 5.0, 0.1) var variacion_intervalo_segundos: float = 0.5
@export_range(1, 60, 1) var flechas_por_rafaga: int = 15
@export_range(0, 10, 1) var variacion_flechas_rafaga: int = 2
@export_range(0.0, 0.5, 0.01) var cadencia_entre_flechas: float = 0.04
@export var disparar_al_iniciar: bool = true
@export var en_bucle_continuo: bool = true

@export_group("Color y Aspecto")
@export var preset_color: ColorPreset = ColorPreset.GOBLIN_MORADA:
	set(val):
		preset_color = val
		_actualizar_color_por_preset()

@export var color_flechas: Color = COLOR_GOBLIN_MORADA:
	set(val):
		color_flechas = val
		_reconstruir_materiales()

@export_range(0.5, 8.0, 0.5) var energia_emision: float = 3.0:
	set(val):
		energia_emision = val
		_reconstruir_materiales()

@export_range(5.0, 50.0, 1.0) var grosor_outline_toon: float = 20.0:
	set(val):
		grosor_outline_toon = val
		_reconstruir_materiales()

@export var con_estela_particulas: bool = true

@export_group("Capas y Profundidad 2.5D")
## Selecciona la capa visual de renderizado 3D para la flecha y sus partículas
@export_flags_3d_render var capa_visual_render: int = 1:
	set(val):
		capa_visual_render = val

## Selección del plano de fondo Z para simular la batalla a distancia
@export var plano_profundidad: PlanoProfundidad = PlanoProfundidad.FONDO_MEDIO:
	set(val):
		plano_profundidad = val
		_actualizar_profundidad_por_preset()

@export var profundidad_z_personalizada: float = Z_FONDO_MEDIO
@export_range(0.0, 5.0, 0.1) var variacion_profundidad_z: float = 1.0

@export_group("Dirección y Balística")
@export var preset_direccion: DireccionPreset = DireccionPreset.DERECHA_A_IZQUIERDA
@export var direccion_personalizada: Vector3 = Vector3(-1.0, 0.42, 0.0)
@export_range(4.0, 35.0, 0.5) var velocidad_base: float = 14.0
@export_range(0.0, 3.0, 0.05) var gravedad: float = 0.85
@export_range(0.0, 30.0, 0.5) var dispersion_angulo_grados: float = 7.5
@export_range(0.0, 10.0, 0.2) var dispersion_velocidad: float = 2.0
@export var tamano_caja_origen: Vector3 = Vector3(4.0, 2.5, 1.0):
	set(val):
		tamano_caja_origen = val
		_actualizar_gizmo_editor()

@export_range(1.0, 15.0, 0.5) var tiempo_vida_flecha: float = 4.5
@export var usar_suelo_impacto: bool = true
@export var altura_suelo_impacto: float = -4.0
@export_range(0.2, 5.0, 0.1) var duracion_clavada: float = 1.2

@export_group("Sonido / SFX")
@export var reproducir_sfx: bool = true
@export_range(-40.0, 0.0, 1.0) var volumen_sfx_db: float = -14.0
@export_range(0.0, 1.0, 0.05) var probabilidad_sfx_por_flecha: float = 0.2

@export_group("Optimización / Pool")
@export_range(15, 100, 5) var tamano_pool: int = 45

@export_group("Editor")
## Activa la previsualización de ráfagas en vivo directamente en el visor 3D del editor
@export var previsualizar_en_editor: bool = false:
	set(val):
		previsualizar_en_editor = val
		if not val:
			detener_lluvia()

# ═══════════════════════════════════════════════════════════════════════════════
# VARIABLES DE ESTADO Y CACHE
# ═══════════════════════════════════════════════════════════════════════════════

var _pool_flechas: Array[Node3D] = []
var _flechas_activas: Array[Node3D] = []
var _tiempo_para_siguiente_rafaga: float = 0.0
var _en_rafaga_activa: bool = false
var _flechas_restantes_en_rafaga: int = 0
var _tiempo_cadencia_acumulado: float = 0.0
var _esta_pausado: bool = false

var _material_flecha: StandardMaterial3D = null
var _material_proceso_estela: ParticleProcessMaterial = null
var _malla_estela: SphereMesh = null
var _nodo_gizmo_box: MeshInstance3D = null


# ═══════════════════════════════════════════════════════════════════════════════
# CICLO DE VIDA BUILT-IN
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_reconstruir_materiales()
	_crear_pool_flechas()
	_configurar_gizmo_editor()

	if Engine.is_editor_hint():
		if not previsualizar_en_editor:
			return

	if disparar_al_iniciar:
		_programar_proxima_rafaga(0.1)
	else:
		_programar_proxima_rafaga()


func _process(delta: float) -> void:
	if _esta_pausado:
		return

	if Engine.is_editor_hint() and not previsualizar_en_editor:
		return

	# 1. Procesar cadencia dentro de la ráfaga actual
	if _en_rafaga_activa:
		_procesar_rafaga_activa(delta)

	# 2. Procesar temporizador entre ráfagas
	if en_bucle_continuo and not _en_rafaga_activa:
		_tiempo_para_siguiente_rafaga -= delta
		if _tiempo_para_siguiente_rafaga <= 0.0:
			disparar_rafaga()


func _exit_tree() -> void:
	_limpiar_pool()


# ═══════════════════════════════════════════════════════════════════════════════
# MÉTODOS PÚBLICOS
# ═══════════════════════════════════════════════════════════════════════════════

## Dispara una ráfaga inmediata de flechas. Si cantidad < 0, usa la configuración de inspector.
func disparar_rafaga(cantidad: int = -1) -> void:
	var total: int = cantidad
	if total <= 0:
		var var_flechas := randi_range(-variacion_flechas_rafaga, variacion_flechas_rafaga)
		total = max(1, flechas_por_rafaga + var_flechas)

	_flechas_restantes_en_rafaga = total
	_en_rafaga_activa = true
	_tiempo_cadencia_acumulado = 0.0
	rafaga_iniciada.emit(total)

	# Si no hay cadencia, dispara toda la salva instantáneamente
	if cadencia_entre_flechas <= 0.0:
		while _flechas_restantes_en_rafaga > 0:
			_disparar_una_flecha()
			_flechas_restantes_en_rafaga -= 1
		_finalizar_rafaga()


## Detiene el ciclo continuo y oculta todas las flechas en vuelo regresándolas al pool.
func detener_lluvia() -> void:
	_esta_pausado = true
	_en_rafaga_activa = false
	_flechas_restantes_en_rafaga = 0
	for flecha in _flechas_activas.duplicate():
		if is_instance_valid(flecha):
			flecha.desactivar()
			_on_flecha_finalizada(flecha)


## Reanuda el ciclo de lluvia de flechas.
func reanudar_lluvia() -> void:
	_esta_pausado = false
	_programar_proxima_rafaga(0.2)


## Asigna un color dinámico a la lluvia de flechas y actualiza los materiales.
func establecer_color(nuevo_color: Color) -> void:
	preset_color = ColorPreset.PERSONALIZADO
	color_flechas = nuevo_color


## Ajusta el intervalo entre ráfagas en segundos.
func establecer_frecuencia_segundos(segundos: float) -> void:
	modo_frecuencia = FrecuenciaModo.PERSONALIZADA
	intervalo_segundos = max(0.1, segundos)


## Ajusta la capa visual de renderizado (1 a 20).
func establecer_capa_visual(capa: int) -> void:
	capa_visual_render = capa


## Ajusta el plano de profundidad Z del efecto 2.5D.
func establecer_profundidad_z(z: float) -> void:
	plano_profundidad = PlanoProfundidad.PERSONALIZADO
	profundidad_z_personalizada = z


## Retorna la cantidad de flechas actualmente en vuelo o clavadas.
func obtener_flechas_activas() -> int:
	return _flechas_activas.size()


## Retorna la capacidad total de flechas en el pool.
func obtener_tamano_pool() -> int:
	return _pool_flechas.size() + _flechas_activas.size()


# ═══════════════════════════════════════════════════════════════════════════════
# GESTIÓN DE RÁFAGA Y DISPARO
# ═══════════════════════════════════════════════════════════════════════════════

func _procesar_rafaga_activa(delta: float) -> void:
	_tiempo_cadencia_acumulado += delta
	while _tiempo_cadencia_acumulado >= cadencia_entre_flechas and _flechas_restantes_en_rafaga > 0:
		_tiempo_cadencia_acumulado -= cadencia_entre_flechas
		_disparar_una_flecha()
		_flechas_restantes_en_rafaga -= 1

	if _flechas_restantes_en_rafaga <= 0:
		_finalizar_rafaga()


func _finalizar_rafaga() -> void:
	_en_rafaga_activa = false
	_flechas_restantes_en_rafaga = 0
	_programar_proxima_rafaga()
	rafaga_completada.emit()


func _disparar_una_flecha() -> void:
	var flecha := _adquirir_flecha_del_pool()
	if not flecha:
		return

	var pos_origen := _calcular_posicion_origen()
	var dir_flecha := _calcular_direccion_con_dispersion()
	var vel_flecha := velocidad_base + randf_range(-dispersion_velocidad, dispersion_velocidad)

	flecha.lanzar(
		pos_origen,
		dir_flecha,
		vel_flecha,
		gravedad,
		tiempo_vida_flecha,
		altura_suelo_impacto,
		usar_suelo_impacto,
		duracion_clavada,
		_material_flecha,
		_material_proceso_estela,
		_malla_estela,
		capa_visual_render,
		con_estela_particulas
	)

	_flechas_activas.append(flecha)
	_reproducir_sfx_disparo_si_corresponde()


func _calcular_posicion_origen() -> Vector3:
	var pos_base: Vector3 = global_position
	var offset_x: float = randf_range(-tamano_caja_origen.x * 0.5, tamano_caja_origen.x * 0.5)
	var offset_y: float = randf_range(-tamano_caja_origen.y * 0.5, tamano_caja_origen.y * 0.5)

	var z_objetivo := _obtener_profundidad_z_actual()
	var offset_z: float = randf_range(-variacion_profundidad_z * 0.5, variacion_profundidad_z * 0.5)

	return Vector3(pos_base.x + offset_x, pos_base.y + offset_y, z_objetivo + offset_z)


func _calcular_direccion_con_dispersion() -> Vector3:
	var dir_base := _obtener_direccion_base()
	if dispersion_angulo_grados <= 0.0:
		return dir_base.normalized()

	var angulo_rad: float = atan2(dir_base.y, dir_base.x)
	var dispersion_rad: float = deg_to_rad(dispersion_angulo_grados)
	var angulo_final: float = angulo_rad + randf_range(-dispersion_rad, dispersion_rad)

	return Vector3(cos(angulo_final), sin(angulo_final), 0.0).normalized()


func _obtener_direccion_base() -> Vector3:
	match preset_direccion:
		DireccionPreset.DERECHA_A_IZQUIERDA:
			return Vector3(-1.0, 0.42, 0.0)
		DireccionPreset.IZQUIERDA_A_DERECHA:
			return Vector3(1.0, 0.42, 0.0)
		DireccionPreset.DESDE_EL_CIELO:
			return Vector3(-0.6, -0.8, 0.0)
		DireccionPreset.PERSONALIZADA:
			return direccion_personalizada
		_:
			return Vector3(-1.0, 0.42, 0.0)


func _obtener_profundidad_z_actual() -> float:
	match plano_profundidad:
		PlanoProfundidad.FONDO_LEJANO:
			return Z_FONDO_LEJANO
		PlanoProfundidad.FONDO_MEDIO:
			return Z_FONDO_MEDIO
		PlanoProfundidad.FONDO_CERCANO:
			return Z_FONDO_CERCANO
		PlanoProfundidad.PLANO_JUGABLE:
			return Z_PLANO_JUGABLE
		PlanoProfundidad.PRIMER_PLANO:
			return Z_PRIMER_PLANO
		PlanoProfundidad.PERSONALIZADO:
			return profundidad_z_personalizada
		_:
			return Z_FONDO_MEDIO


func _programar_proxima_rafaga(tiempo_fijo: float = -1.0) -> void:
	if tiempo_fijo >= 0.0:
		_tiempo_para_siguiente_rafaga = tiempo_fijo
		return

	var delta_var: float = randf_range(-variacion_intervalo_segundos, variacion_intervalo_segundos)
	_tiempo_para_siguiente_rafaga = max(0.1, intervalo_segundos + delta_var)


func _reproducir_sfx_disparo_si_corresponde() -> void:
	if not reproducir_sfx or Engine.is_editor_hint():
		return
	if randf() > probabilidad_sfx_por_flecha:
		return
	if not has_node("/root/AudioManager"):
		return

	var am = get_node("/root/AudioManager")
	if "sfx_bloqueados" in am and am.sfx_bloqueados:
		return

	# Usar sonido de disparo de arquera goblin con atenuación de batalla de fondo
	am.play_sfx("goblin_girl_shoot", volumen_sfx_db)


# ═══════════════════════════════════════════════════════════════════════════════
# OBJECT POOLING
# ═══════════════════════════════════════════════════════════════════════════════

func _crear_pool_flechas() -> void:
	_limpiar_pool()
	for i in range(tamano_pool):
		var flecha := SCRIPT_FLECHA_DECORATIVA.new() as Node3D
		flecha.name = "FlechaDecorativa_%d" % i
		flecha.finalizada.connect(_on_flecha_finalizada)
		add_child(flecha)
		_pool_flechas.append(flecha)


func _adquirir_flecha_del_pool() -> Node3D:
	if _pool_flechas.is_empty():
		# Si el pool se agotó, crear una flecha extra dinámicamente
		var extra := SCRIPT_FLECHA_DECORATIVA.new() as Node3D
		extra.name = "FlechaDecorativa_Extra_%d" % _flechas_activas.size()
		extra.finalizada.connect(_on_flecha_finalizada)
		add_child(extra)
		return extra

	return _pool_flechas.pop_back()


func _on_flecha_finalizada(flecha: Node3D) -> void:
	var idx := _flechas_activas.find(flecha)
	if idx != -1:
		_flechas_activas.remove_at(idx)
	if not _pool_flechas.has(flecha):
		_pool_flechas.append(flecha)


func _limpiar_pool() -> void:
	for flecha in _flechas_activas:
		if is_instance_valid(flecha):
			flecha.queue_free()
	_flechas_activas.clear()

	for flecha in _pool_flechas:
		if is_instance_valid(flecha):
			flecha.queue_free()
	_pool_flechas.clear()


# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURACIÓN DINÁMICA DE MATERIALES Y PRESETS
# ═══════════════════════════════════════════════════════════════════════════════

func _actualizar_intervalo_por_modo() -> void:
	match modo_frecuencia:
		FrecuenciaModo.LENTA:
			intervalo_segundos = 6.0
			variacion_intervalo_segundos = 0.8
		FrecuenciaModo.MEDIA:
			intervalo_segundos = 3.5
			variacion_intervalo_segundos = 0.5
		FrecuenciaModo.RAPIDA:
			intervalo_segundos = 1.8
			variacion_intervalo_segundos = 0.3
		FrecuenciaModo.CONTINUA:
			intervalo_segundos = 0.8
			variacion_intervalo_segundos = 0.15
		FrecuenciaModo.PERSONALIZADA:
			pass


func _actualizar_color_por_preset() -> void:
	match preset_color:
		ColorPreset.GOBLIN_MORADA:
			color_flechas = COLOR_GOBLIN_MORADA
		ColorPreset.ROSA_NEON:
			color_flechas = COLOR_ROSA_NEON
		ColorPreset.VERDE_VENENO:
			color_flechas = COLOR_VERDE_VENENO
		ColorPreset.ROJO_FUEGO:
			color_flechas = COLOR_ROJO_FUEGO
		ColorPreset.DORADO_IMPERIO:
			color_flechas = COLOR_DORADO_IMPERIO
		ColorPreset.AZUL_MISTICO:
			color_flechas = COLOR_AZUL_MISTICO
		ColorPreset.BLANCO_PURO:
			color_flechas = COLOR_BLANCO_PURO
		ColorPreset.PERSONALIZADO:
			pass


func _actualizar_profundidad_por_preset() -> void:
	match plano_profundidad:
		PlanoProfundidad.FONDO_LEJANO:
			profundidad_z_personalizada = Z_FONDO_LEJANO
		PlanoProfundidad.FONDO_MEDIO:
			profundidad_z_personalizada = Z_FONDO_MEDIO
		PlanoProfundidad.FONDO_CERCANO:
			profundidad_z_personalizada = Z_FONDO_CERCANO
		PlanoProfundidad.PLANO_JUGABLE:
			profundidad_z_personalizada = Z_PLANO_JUGABLE
		PlanoProfundidad.PRIMER_PLANO:
			profundidad_z_personalizada = Z_PRIMER_PLANO
		PlanoProfundidad.PERSONALIZADO:
			pass


func _reconstruir_materiales() -> void:
	# 1. Material del cuerpo de la flecha con outline toon negro
	_material_flecha = StandardMaterial3D.new()
	_material_flecha.albedo_color = color_flechas
	_material_flecha.emission_enabled = true
	_material_flecha.emission = color_flechas
	_material_flecha.emission_energy_multiplier = energia_emision
	_material_flecha.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	if SHADER_OUTLINE:
		var outline_mat := ShaderMaterial.new()
		outline_mat.shader = SHADER_OUTLINE
		outline_mat.set_shader_parameter("outline_color", Color(0.0, 0.0, 0.0, 1.0))
		outline_mat.set_shader_parameter("outline_width", grosor_outline_toon)
		_material_flecha.next_pass = outline_mat

	# 2. Material de proceso para partículas de estela
	_material_proceso_estela = ParticleProcessMaterial.new()
	_material_proceso_estela.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	_material_proceso_estela.direction = Vector3.ZERO
	_material_proceso_estela.spread = 10.0
	_material_proceso_estela.initial_velocity_min = 0.0
	_material_proceso_estela.initial_velocity_max = 0.2
	_material_proceso_estela.gravity = Vector3.ZERO
	_material_proceso_estela.scale_min = 0.005
	_material_proceso_estela.scale_max = 0.012

	var gradiente := Gradient.new()
	gradiente.set_color(0, Color(color_flechas.r, color_flechas.g, color_flechas.b, 0.85))
	gradiente.set_color(1, Color(color_flechas.r * 0.8, color_flechas.g * 0.6, color_flechas.b * 0.5, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = gradiente
	_material_proceso_estela.color_ramp = grad_tex

	# 3. Malla de cada partícula de estela
	_malla_estela = SphereMesh.new()
	_malla_estela.radius = 0.013
	_malla_estela.height = 0.026

	var mat_esfera := StandardMaterial3D.new()
	mat_esfera.albedo_color = color_flechas
	mat_esfera.emission_enabled = true
	mat_esfera.emission = color_flechas
	mat_esfera.emission_energy_multiplier = 4.0
	mat_esfera.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_esfera.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_malla_estela.material = mat_esfera


# ═══════════════════════════════════════════════════════════════════════════════
# GIZMO VISUAL PARA EL EDITOR
# ═══════════════════════════════════════════════════════════════════════════════

func _configurar_gizmo_editor() -> void:
	if not Engine.is_editor_hint():
		if is_instance_valid(_nodo_gizmo_box):
			_nodo_gizmo_box.queue_free()
		return

	if not is_instance_valid(_nodo_gizmo_box):
		_nodo_gizmo_box = MeshInstance3D.new()
		_nodo_gizmo_box.name = "GizmoEditorArea"
		var box_mesh := BoxMesh.new()
		_nodo_gizmo_box.mesh = box_mesh

		var mat_box := StandardMaterial3D.new()
		mat_box.albedo_color = Color(1.0, 0.38, 0.72, 0.25)
		mat_box.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat_box.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_nodo_gizmo_box.material_override = mat_box
		add_child(_nodo_gizmo_box)

	_actualizar_gizmo_editor()


func _actualizar_gizmo_editor() -> void:
	if not Engine.is_editor_hint() or not is_instance_valid(_nodo_gizmo_box):
		return

	var box_mesh = _nodo_gizmo_box.mesh as BoxMesh
	if box_mesh:
		box_mesh.size = tamano_caja_origen
