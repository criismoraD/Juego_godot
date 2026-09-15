@tool
class_name ParallaxFondoRio
extends Node3D

## Controlador de Parallax 3D para el escenario 'Rio en canoa con paralax'.
## Gestiona dos capas de profundidad:
##   - Fondo lejano: Atardecer (Fondo nivel 6 atardecer) a Z profunda con deriva suave.
##   - Fondo intermedio: Rocas y tierra (Fondo terroso nivel 6) en loop continuo horizontal.
## Permite visualizar y editar los fondos directamente en el editor 3D de Godot.

# === CONSTANTES ===
const VIDEO_FONDO_OGV: VideoStream = preload("res://TEST_/Fondo estatico.ogv")
const TEX_PREVIEW_FONDO: Texture2D = preload("res://TEST_/Fondo_estatico_preview.png")
const TEX_ARBOLES: Texture2D = preload("res://TEST_/arboles prueba.png")
const TEX_NUBES: Texture2D = preload("res://TEST_/nube rosada.png")
const TEX_ATARDECER: Texture2D = preload("res://TEST_/Fondo nivel 6 atardecer.png")
const TEX_TERROSO: Texture2D = preload("res://TEST_/Fondo terroso nivel 6.png")
const ESCENA_CORDILLERA: PackedScene = preload("res://Levels/Rio_En_Canoa_Con_Parallax/PiedraFondoCordillera.tscn")
const ESCENA_REFLEJO: PackedScene = preload("res://Levels/Rio_En_Canoa_Con_Parallax/ReflejoCordillera.tscn")

const CANTIDAD_SEGMENTOS: int = 3
const CANTIDAD_SEGMENTOS_CORDILLERA: int = 12
const CANTIDAD_SEGMENTOS_ARBOLES: int = 8
const CANTIDAD_SEGMENTOS_NUBES: int = 5
const CANTIDAD_SEGMENTOS_ATARDECER: int = 1
const PROFUNDIDAD_ATARDECER: float = -38.0
const PROFUNDIDAD_CORDILLERA: float = -28.0
const PROFUNDIDAD_TERROSO: float = -20.0

# === EXPORTS ===
@export_category("Velocidad de Parallax")
@export var activo: bool = true  ## Si true, el fondo se desplaza continuamente
@export var velocidad_base: float = 1.0  ## Velocidad de avance de referencia en m/s hacia la izquierda
@export var velocidad_terroso: float = 1.0:  ## Compatibilidad hacia atrás
	set(v):
		velocidad_terroso = v
		velocidad_base = v
@export var factor_cordillera: float = 0.35  ## Capa más cercana del fondo (más rápida)
@export var factor_arboles: float = 0.18  ## Capa intermedia de árboles
@export var factor_nubes: float = 0.08  ## Capa lejana de nubes
@export var factor_fondo_video: float = 0.0  ## Fondo de video estático (0.0 = sin desplazamiento parallax)
@export var factor_atardecer: float = 0.0  ## Compatibilidad
@export var velocidad_reproduccion_video: float = 0.03  ## Velocidad absurdamente lenta del video de fondo

@export_category("Fondo de Video")
@export var seguir_camara_video: bool = true  ## Si true, el video acompaña el avance horizontal de la cámara
@export var offset_posicion_video: Vector3 = Vector3.ZERO:  ## Desplazamiento manual en X, Y, Z para encuadrar y posicionar el fondo a gusto
	set(v):
		var delta_offset: Vector3 = v - offset_posicion_video
		offset_posicion_video = v
		if is_instance_valid(_sprite_fondo_video):
			_sprite_fondo_video.position += delta_offset
			_guardar_offset_fondo_video()

@export_category("Dimensiones y Posicionamiento")
@export var ancho_segmento_cordillera: float = 8.5  ## Distancia horizontal entre centros de piedra
@export var ancho_segmento_arboles: float = 13.47  ## Ancho de cada mosaico de árboles
@export var ancho_segmento_nubes: float = 35.47  ## Ancho de cada panel de nubes
@export var ancho_segmento_terroso: float = 16.0  ## Ancho de cada mosaico de rocas en metros
@export var alto_segmento_terroso: float = 9.85  ## Alto proporcional del mosaico
@export var altura_y_terroso: float = 2.4  ## Cota Y del centro del terreno rocoso

@export var ancho_segmento_atardecer: float = 175.0  ## Ancho del panel panorámico de cielo con un único sol (m)
@export var alto_segmento_atardecer: float = 50.0  ## Alto proporcional del cielo
@export var altura_y_atardecer: float = 3.6  ## Cota Y del cielo
@export var altura_y_cordillera: float = 0.8  ## Cota Y base para la cordillera de piedras
@export var escala_cordillera: Vector3 = Vector3(10.0, 7.5, 10.0)  ## Escala 3D del modelo de cordillera

@export_category("Piso Aliado / Piso Nueva Version")
@export var sincronizar_piso_con_cordillera: bool = true  ## Si true, el piso (Piso nueva version / Piso Aliado) se desplaza a la misma velocidad de la cordillera
@export var ancho_segmento_piso: float = 5.4  ## Distancia horizontal entre piezas de piso para el wrap del loop
@export var sincronizar_reflejo_con_cordillera: bool = true  ## Si true, el reflejo de la cordillera en el agua se desplaza a la misma velocidad que ella

@export_category("Textura de agua")
@export var sincronizar_agua_textura_con_cordillera: bool = true  ## Si true, la TexturaAgua se desplaza a la misma velocidad de la cordillera
@export var ancho_segmento_agua_textura: float = 20.0  ## Ancho de cada panel de agua para el wrap del loop

@export_category("Casa boneta")
@export var sincronizar_casa_boneta_con_cordillera: bool = true  ## Si true, la CasaBoneta se desplaza a la misma velocidad de la cordillera

@export_category("Reciclaje parallax")
@export var margen_reciclaje_atras: float = 30.0  ## Distancia tras la cámara donde se recicla
@export var margen_reciclaje_adelante: float = 55.0  ## Distancia delante de la cámara donde reaparece (fuera de vista)

@export_category("Bosque rojo")
@export var sincronizar_bosque_rojo_con_fondo: bool = true  ## Si true, el BosqueRojo hace scroll parallax detrás de la cordillera
@export var factor_bosque_rojo: float = 0.28  ## Más lento que la cordillera (0.35): está más lejos
@export var ancho_segmento_bosque_rojo: float = 100.0  ## Ancho de cada franja de bosque para el wrap del loop

@export_category("Niebla sutil")
@export var sincronizar_niebla_con_cordillera: bool = true  ## Si true, la NieblaSutil se desplaza a la misma velocidad de la cordillera
@export var ancho_segmento_niebla: float = 120.0  ## Ancho de cada franja de niebla para el wrap del loop

@export_category("Árboles de cordillera")
@export var sincronizar_arbol_cordillera: bool = true  ## Si true, los ArbolLow(cordillera) se desplazan con la cordillera

@export_category("Renderizado")
@export var capa_visual: int = 3  ## Capa de renderizado (Fondo = 2, Editor = 1, Ambas = 3)

@export_category("Capas de fondo lejano")
@export var capa_cordillera: int = 2  ## Capa visual de la cordillera (2 = fondo, se difumina por la distancia)
@export var capa_piso_fondo: int = 2  ## Capa visual del piso de fondo (2 = fondo, se difumina por la distancia)

# === VARIABLES PRIVADAS ===
var _sprites_terroso: Array[Sprite3D] = []
var _sprites_atardecer: Array[Sprite3D] = []
var _segmentos_cordillera: Array[Node3D] = []
var _segmentos_reflejo: Array[Node3D] = []
var _segmentos_piso_aliado: Array[Node3D] = []
var _sprites_arboles: Array[Sprite3D] = []
var _sprites_nubes: Array[Sprite3D] = []
var _sprites_agua_textura: Array[Sprite3D] = []
var _sprites_bosque_rojo: Array[Sprite3D] = []
var _segmentos_niebla: Array[Node3D] = []
var _segmentos_casa_boneta: Array[Node3D] = []
var _segmentos_arbol_cordillera: Array[Node3D] = []
var _sprite_fondo_video: Sprite3D = null
var _video_player: VideoStreamPlayer = null

var _nodo_capa_terroso: Node3D = null
var _nodo_capa_reflejo: Node3D = null
var _nodo_capa_atardecer: Node3D = null
var _nodo_capa_cordillera: Node3D = null
var _camara_referencia: Camera3D = null
var _offset_fondo_video_x: float = 8.06


# === FUNCIONES BUILT-IN ===
func _ready() -> void:
	_inicializar_capas()
	_aplicar_capa_visual_recursiva(self)
	_aplicar_capas_fondo()


func _process(delta: float) -> void:
	# En el editor de Godot no desplazamos las capas para permitir edición cómoda
	if Engine.is_editor_hint():
		return

	# Actualizar frame de video en Sprite3D
	_actualizar_video_frame()

	# El fondo de video es 100% estático en el encuadre de la cámara
	_mantener_fondo_video_estatico()

	if not activo or delta <= 0.0:
		return

	_actualizar_loop_cordillera(delta)
	_actualizar_loop_reflejo(delta)
	_actualizar_loop_piso_aliado(delta)
	_actualizar_loop_agua_textura(delta)
	_actualizar_loop_casa_boneta(delta)
	_actualizar_loop_bosque_rojo(delta)
	_actualizar_loop_niebla(delta)
	_actualizar_loop_arbol_cordillera(delta)
	_actualizar_loop_arboles(delta)
	_actualizar_loop_nubes(delta)
	_actualizar_loop_terroso(delta)


# === FUNCIONES PÚBLICAS ===
## Retorna la lista de nodos 3D de la cordillera de piedras.
func obtener_segmentos_cordillera() -> Array[Node3D]:
	return _segmentos_cordillera


## Retorna la lista de nodos 3D del reflejo espejado de la cordillera sobre el agua.
func obtener_segmentos_reflejo() -> Array[Node3D]:
	if _segmentos_reflejo.is_empty():
		_inicializar_capa_reflejo()
	return _segmentos_reflejo


## Retorna la lista de nodos 3D del piso aliado sincronizados con la cordillera.
func obtener_segmentos_piso_aliado() -> Array[Node3D]:
	if _segmentos_piso_aliado.is_empty():
		_inicializar_capa_piso_aliado()
	return _segmentos_piso_aliado


## Permite registrar un nodo de piso aliado dinámicamente.
func registrar_segmento_piso_aliado(nodo_piso: Node3D) -> void:
	if is_instance_valid(nodo_piso) and not _segmentos_piso_aliado.has(nodo_piso):
		_segmentos_piso_aliado.append(nodo_piso)
		_segmentos_piso_aliado.sort_custom(func(a: Node3D, b: Node3D) -> bool:
			return a.position.x < b.position.x
		)


## Retorna la lista de sprites que componen la capa de árboles.
func obtener_sprites_arboles() -> Array[Sprite3D]:
	return _sprites_arboles


## Retorna la lista de sprites que componen la capa de nubes rosa.
func obtener_sprites_nubes() -> Array[Sprite3D]:
	return _sprites_nubes


## Retorna los sprites de textura de agua sincronizados con la cordillera.
func obtener_sprites_agua_textura() -> Array[Sprite3D]:
	if _sprites_agua_textura.is_empty():
		_inicializar_capa_agua_textura()
	return _sprites_agua_textura


## Permite registrar un sprite de textura de agua dinámicamente.
func registrar_sprite_agua_textura(sprite_agua: Sprite3D) -> void:
	if is_instance_valid(sprite_agua) and not _sprites_agua_textura.has(sprite_agua):
		_sprites_agua_textura.append(sprite_agua)
		_sprites_agua_textura.sort_custom(func(a: Sprite3D, b: Sprite3D) -> bool:
			return a.position.x < b.position.x
		)


## Retorna los segmentos de casa boneta sincronizados con la cordillera.
func obtener_segmentos_casa_boneta() -> Array[Node3D]:
	if _segmentos_casa_boneta.is_empty():
		_inicializar_capa_casa_boneta()
	return _segmentos_casa_boneta


## Permite registrar un segmento de casa boneta dinámicamente.
func registrar_segmento_casa_boneta(nodo_casa: Node3D) -> void:
	if is_instance_valid(nodo_casa) and not _segmentos_casa_boneta.has(nodo_casa):
		_segmentos_casa_boneta.append(nodo_casa)
		_segmentos_casa_boneta.sort_custom(func(a: Node3D, b: Node3D) -> bool:
			return a.position.x < b.position.x
		)


## Retorna los sprites de bosque rojo con scroll parallax propio.
func obtener_sprites_bosque_rojo() -> Array[Sprite3D]:
	if _sprites_bosque_rojo.is_empty():
		_inicializar_capa_bosque_rojo()
	return _sprites_bosque_rojo


## Permite registrar un sprite de bosque rojo dinámicamente.
func registrar_sprite_bosque_rojo(sprite_bosque: Sprite3D) -> void:
	if is_instance_valid(sprite_bosque) and not _sprites_bosque_rojo.has(sprite_bosque):
		_sprites_bosque_rojo.append(sprite_bosque)
		_sprites_bosque_rojo.sort_custom(func(a: Sprite3D, b: Sprite3D) -> bool:
			return a.position.x < b.position.x
		)


## Retorna los segmentos de niebla sutil sincronizados con la cordillera.
func obtener_segmentos_niebla() -> Array[Node3D]:
	if _segmentos_niebla.is_empty():
		_inicializar_capa_niebla()
	return _segmentos_niebla


## Permite registrar un segmento de niebla dinámicamente.
func registrar_segmento_niebla(nodo_niebla: Node3D) -> void:
	if is_instance_valid(nodo_niebla) and not _segmentos_niebla.has(nodo_niebla):
		_segmentos_niebla.append(nodo_niebla)
		_segmentos_niebla.sort_custom(func(a: Node3D, b: Node3D) -> bool:
			return a.position.x < b.position.x
		)


## Retorna los árboles acoplados a la cordillera (nodos ArbolLow con "(cordillera)").
func obtener_segmentos_arbol_cordillera() -> Array[Node3D]:
	if _segmentos_arbol_cordillera.is_empty():
		_inicializar_capa_arbol_cordillera()
	return _segmentos_arbol_cordillera


## Permite registrar un árbol de cordillera dinámicamente.
func registrar_segmento_arbol_cordillera(nodo_arbol: Node3D) -> void:
	if is_instance_valid(nodo_arbol) and not _segmentos_arbol_cordillera.has(nodo_arbol):
		_segmentos_arbol_cordillera.append(nodo_arbol)
		_segmentos_arbol_cordillera.sort_custom(func(a: Node3D, b: Node3D) -> bool:
			return a.position.x < b.position.x
		)


## Retorna el sprite donde se reproduce el fondo de video.
func obtener_sprite_fondo_video() -> Sprite3D:
	return _sprite_fondo_video


## Retorna el reproductor de video de fondo.
func obtener_video_player() -> VideoStreamPlayer:
	return _video_player


## Retorna los sprites de atardecer (compatibilidad con tests anteriores).
func obtener_sprites_atardecer() -> Array[Sprite3D]:
	if _sprites_atardecer.is_empty() and is_instance_valid(_sprite_fondo_video):
		return [_sprite_fondo_video]
	return _sprites_atardecer


## Retorna los sprites terrosos/arboles (compatibilidad).
func obtener_sprites_terroso() -> Array[Sprite3D]:
	if not _sprites_terroso.is_empty():
		return _sprites_terroso
	return _sprites_arboles


## Retorna el nodo contenedor de la cordillera.
func obtener_nodo_cordillera() -> Node3D:
	return _nodo_capa_cordillera


## Fija la referencia a la cámara principal.
func fijar_camara_referencia(cam: Camera3D) -> void:
	_camara_referencia = cam
	if is_instance_valid(_camara_referencia) and is_instance_valid(_sprite_fondo_video):
		_offset_fondo_video_x = _sprite_fondo_video.global_position.x - _camara_referencia.global_position.x


## Pausa o reanuda el desplazamiento de las capas.
func set_desplazamiento_activo(nuevo_estado: bool) -> void:
	activo = nuevo_estado


## Reaplica las capas de fondo lejano (cordillera y piso) tras recolecciones externas.
func aplicar_capas_fondo() -> void:
	_aplicar_capas_fondo()


# === FUNCIONES PRIVADAS ===
func _inicializar_capas() -> void:
	_inicializar_capa_fondo_video()
	_inicializar_capa_cordillera()
	_inicializar_capa_reflejo()
	_inicializar_capa_piso_aliado()
	_inicializar_capa_agua_textura()
	_inicializar_capa_casa_boneta()
	_inicializar_capa_bosque_rojo()
	_inicializar_capa_niebla()
	_inicializar_capa_arbol_cordillera()
	_inicializar_capas_arboles_y_nubes()


func _inicializar_capa_fondo_video() -> void:
	_nodo_capa_atardecer = get_node_or_null("CapaAtardecer") as Node3D
	if _nodo_capa_atardecer == null:
		_nodo_capa_atardecer = Node3D.new()
		_nodo_capa_atardecer.name = "CapaAtardecer"
		_nodo_capa_atardecer.position = Vector3(0.0, altura_y_atardecer, PROFUNDIDAD_ATARDECER)
		add_child(_nodo_capa_atardecer)

	altura_y_atardecer = _nodo_capa_atardecer.position.y
	_sprite_fondo_video = _nodo_capa_atardecer.get_node_or_null("Atardecer_0") as Sprite3D

	if _sprite_fondo_video == null:
		_sprite_fondo_video = Sprite3D.new()
		_sprite_fondo_video.name = "Atardecer_0"
		_sprite_fondo_video.pixel_size = 0.005
		_sprite_fondo_video.scale = Vector3(7.0, 5.0, 1.0)
		_sprite_fondo_video.position = Vector3(0.0, 4.5, -73.49036)
		_nodo_capa_atardecer.add_child(_sprite_fondo_video)

	_sprite_fondo_video.visible = true
	_sprite_fondo_video.shaded = false
	_sprite_fondo_video.double_sided = true
	_sprite_fondo_video.render_priority = -10
	_sprite_fondo_video.layers = capa_visual

	# Guardar el offset inicial respecto a la cámara basado en la posición colocada por el usuario
	_guardar_offset_fondo_video()

	var mat_fondo := StandardMaterial3D.new()
	mat_fondo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_fondo.disable_fog = true
	mat_fondo.render_priority = -10
	if TEX_PREVIEW_FONDO:
		mat_fondo.albedo_texture = TEX_PREVIEW_FONDO
	_sprite_fondo_video.material_override = mat_fondo

	# Desactivar cualquier panel duplicado
	for hijo in _nodo_capa_atardecer.get_children():
		if hijo is Sprite3D and hijo != _sprite_fondo_video and hijo.name != "agua textura":
			hijo.visible = false

	_sprites_atardecer.clear()
	_sprites_atardecer.append(_sprite_fondo_video)

	# Asignar vista previa en editor
	if Engine.is_editor_hint():
		if TEX_PREVIEW_FONDO:
			_sprite_fondo_video.texture = TEX_PREVIEW_FONDO
		return

	# Instanciar VideoStreamPlayer para reproducción lenta en tiempo de juego
	if VIDEO_FONDO_OGV:
		_video_player = VideoStreamPlayer.new()
		_video_player.name = "VideoStreamPlayerFondo"
		_video_player.stream = VIDEO_FONDO_OGV
		_video_player.speed_scale = velocidad_reproduccion_video
		_video_player.autoplay = true
		_video_player.loop = false
		_video_player.visible = false
		_video_player.finished.connect(_on_video_finished)
		add_child(_video_player)
		_video_player.play()

	if TEX_PREVIEW_FONDO and _sprite_fondo_video.texture == null:
		_sprite_fondo_video.texture = TEX_PREVIEW_FONDO


func _inicializar_capa_cordillera() -> void:
	_nodo_capa_cordillera = get_node_or_null("CapaCordillera") as Node3D
	if _nodo_capa_cordillera == null:
		_construir_capa_cordillera()
		return

	altura_y_cordillera = _nodo_capa_cordillera.position.y
	_segmentos_cordillera.clear()

	for hijo in _nodo_capa_cordillera.get_children():
		if hijo is Node3D and hijo.visible:
			_segmentos_cordillera.append(hijo)

	_segmentos_cordillera.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.position.x < b.position.x)

	# Completar hasta 12 segmentos para cobertura infinita sin cortes
	var ult_x: float = _segmentos_cordillera[-1].position.x if not _segmentos_cordillera.is_empty() else 0.0
	var base_y: float = _segmentos_cordillera[-1].position.y if not _segmentos_cordillera.is_empty() else -2.3
	var base_z: float = _segmentos_cordillera[-1].position.z if not _segmentos_cordillera.is_empty() else -54.0

	while _segmentos_cordillera.size() < CANTIDAD_SEGMENTOS_CORDILLERA:
		var idx: int = _segmentos_cordillera.size()
		var piedra: Node3D = ESCENA_CORDILLERA.instantiate() as Node3D
		piedra.name = "PiedraCordillera_" + str(idx)
		piedra.scale = Vector3(10.0, 7.5, 10.0)
		ult_x += ancho_segmento_cordillera
		piedra.position = Vector3(ult_x, base_y, base_z)
		_nodo_capa_cordillera.add_child(piedra)
		_segmentos_cordillera.append(piedra)

	# Alinear las coordenadas X de forma equidistante partiendo de la posición inicial colocada por el usuario
	var inicio_x: float = _segmentos_cordillera[0].position.x
	for i in range(_segmentos_cordillera.size()):
		_segmentos_cordillera[i].position.x = inicio_x + float(i) * ancho_segmento_cordillera


func _construir_capa_cordillera() -> void:
	_nodo_capa_cordillera = Node3D.new()
	_nodo_capa_cordillera.name = "CapaCordillera"
	_nodo_capa_cordillera.position = Vector3(0.0, altura_y_cordillera, PROFUNDIDAD_CORDILLERA)
	add_child(_nodo_capa_cordillera)

	for i in range(CANTIDAD_SEGMENTOS_CORDILLERA):
		var piedra: Node3D = ESCENA_CORDILLERA.instantiate() as Node3D
		piedra.name = "PiedraCordillera_" + str(i)
		piedra.scale = Vector3(10.0, 7.5, 10.0)
		var x_pos: float = -21.25 + float(i) * ancho_segmento_cordillera
		piedra.position = Vector3(x_pos, -2.3, -54.5)
		_nodo_capa_cordillera.add_child(piedra)
		_segmentos_cordillera.append(piedra)


func _inicializar_capa_reflejo() -> void:
	_nodo_capa_reflejo = get_node_or_null("CapaReflejoCordillera") as Node3D
	if _nodo_capa_reflejo == null:
		_construir_capa_reflejo()
		return

	_segmentos_reflejo.clear()
	for hijo in _nodo_capa_reflejo.get_children():
		if hijo is Node3D and (hijo as Node3D).visible:
			_segmentos_reflejo.append(hijo)

	_segmentos_reflejo.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.position.x < b.position.x
	)


func _construir_capa_reflejo() -> void:
	_nodo_capa_reflejo = Node3D.new()
	_nodo_capa_reflejo.name = "CapaReflejoCordillera"
	_nodo_capa_reflejo.position = Vector3(0.0, altura_y_cordillera, PROFUNDIDAD_CORDILLERA)
	add_child(_nodo_capa_reflejo)

	_segmentos_reflejo.clear()
	for i in range(CANTIDAD_SEGMENTOS_CORDILLERA):
		var reflejo: Node3D = ESCENA_REFLEJO.instantiate() as Node3D
		reflejo.name = "ReflejoCordillera_" + str(i)
		reflejo.scale = Vector3(10.0, -7.5, 10.0)
		var x_pos: float = -21.25 + float(i) * ancho_segmento_cordillera
		reflejo.position = Vector3(x_pos, -1.7, -52.5)
		_nodo_capa_reflejo.add_child(reflejo)
		_segmentos_reflejo.append(reflejo)


func _actualizar_loop_reflejo(delta: float) -> void:
	if not sincronizar_reflejo_con_cordillera or _segmentos_reflejo.is_empty():
		return

	# Velocidad idéntica a la cordillera para que el reflejo la acompañe
	var paso: float = velocidad_base * factor_cordillera * delta
	for seg in _segmentos_reflejo:
		if is_instance_valid(seg):
			seg.position.x -= paso

	var x_cam: float = _obtener_x_camara()
	var x_cam_local: float = _nodo_capa_reflejo.to_local(Vector3(x_cam, 0.0, 0.0)).x if _nodo_capa_reflejo else x_cam
	var limite_izquierdo: float = x_cam_local - 30.0

	var x_maxima: float = -INF
	for seg in _segmentos_reflejo:
		if is_instance_valid(seg) and seg.position.x > x_maxima:
			x_maxima = seg.position.x

	for seg in _segmentos_reflejo:
		if is_instance_valid(seg) and seg.position.x <= limite_izquierdo:
			seg.position.x = x_maxima + ancho_segmento_cordillera
			x_maxima = seg.position.x


func _inicializar_capa_piso_aliado() -> void:
	_segmentos_piso_aliado.clear()

	# 1. Buscar en CapaPisoAliado o CapaPiso dentro de ParallaxFondo si existiera
	var contenedor := get_node_or_null("CapaPisoAliado") as Node3D
	if not is_instance_valid(contenedor):
		contenedor = get_node_or_null("CapaPiso") as Node3D

	if is_instance_valid(contenedor):
		for hijo in contenedor.get_children():
			if hijo is Node3D and hijo.visible and not (hijo is Light3D or hijo is Camera3D):
				_segmentos_piso_aliado.append(hijo)

	# 2. Si no hay contenedor hijo, buscar en el nodo padre (el nivel)
	if _segmentos_piso_aliado.is_empty():
		var padre: Node = get_parent()
		if is_instance_valid(padre):
			var cont_padre := padre.find_child("CapaPisoAliado", false, false) as Node3D
			if not is_instance_valid(cont_padre):
				cont_padre = padre.find_child("CapaPiso", false, false) as Node3D
			if not is_instance_valid(cont_padre):
				cont_padre = padre.find_child("Pisos", false, false) as Node3D

			if is_instance_valid(cont_padre):
				for hijo in cont_padre.get_children():
					if hijo is Node3D and hijo.visible and not (hijo is Light3D or hijo is Camera3D):
						_segmentos_piso_aliado.append(hijo)
			else:
				for hijo in padre.get_children():
					if hijo is Node3D and hijo.visible and _es_segmento_piso(hijo):
						_segmentos_piso_aliado.append(hijo)

	# Ordenar de izquierda a derecha por posición X
	_segmentos_piso_aliado.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.position.x < b.position.x
	)


func _es_segmento_piso(nodo: Node) -> bool:
	if not (nodo is Node3D) or nodo is Light3D or nodo is Camera3D:
		return false
	var n: String = nodo.name.to_lower()
	if n.begins_with("piso"):
		return true
	return false


func _inicializar_capas_arboles_y_nubes() -> void:
	_nodo_capa_terroso = get_node_or_null("CapaTerroso") as Node3D
	if _nodo_capa_terroso == null:
		_construir_capa_terroso()

	# 1. Árboles
	_sprites_arboles.clear()
	var arbol_base: Sprite3D = null
	if _nodo_capa_terroso:
		for hijo in _nodo_capa_terroso.get_children():
			if hijo is Sprite3D and hijo.name.begins_with("Arbol"):
				_sprites_arboles.append(hijo)
				if arbol_base == null:
					arbol_base = hijo

	if arbol_base == null:
		arbol_base = find_child("Arboles", true, false) as Sprite3D

	if arbol_base:
		arbol_base.layers = capa_visual
		var contenedor_arboles: Node = arbol_base.get_parent()
		var base_pos: Vector3 = arbol_base.position
		var base_scale: Vector3 = arbol_base.scale

		if _sprites_arboles.size() <= 1:
			_sprites_arboles.clear()
			_sprites_arboles.append(arbol_base)
			var x_start: float = base_pos.x - 3.0 * ancho_segmento_arboles
			arbol_base.position.x = x_start
			for i in range(1, CANTIDAD_SEGMENTOS_ARBOLES):
				var clon: Sprite3D = arbol_base.duplicate() as Sprite3D
				clon.name = "Arboles_" + str(i)
				clon.position = Vector3(x_start + float(i) * ancho_segmento_arboles, base_pos.y, base_pos.z)
				clon.scale = base_scale
				clon.layers = capa_visual
				contenedor_arboles.add_child(clon)
				_sprites_arboles.append(clon)

	# 2. Nubes rosa
	_sprites_nubes.clear()
	var nube_base: Sprite3D = null
	if _nodo_capa_terroso:
		for hijo in _nodo_capa_terroso.get_children():
			if hijo is Sprite3D and (hijo.name.begins_with("Nube") or hijo.name.begins_with("nube")):
				_sprites_nubes.append(hijo)
				if nube_base == null:
					nube_base = hijo

	if nube_base == null:
		nube_base = find_child("Nube rosa", true, false) as Sprite3D

	if nube_base == null and _nodo_capa_terroso:
		nube_base = Sprite3D.new()
		nube_base.name = "NubeRosa_0"
		nube_base.texture = TEX_NUBES
		nube_base.pixel_size = 0.0035
		nube_base.scale = Vector3(70.373566, 11.935594, 7.4582386)
		nube_base.position = Vector3(-28.208498, -0.83228993, -89.70932)
		nube_base.layers = capa_visual
		_nodo_capa_terroso.add_child(nube_base)
		_sprites_nubes.append(nube_base)

	if nube_base:
		nube_base.layers = capa_visual
		var contenedor_nubes: Node = nube_base.get_parent()
		var base_pos_n: Vector3 = nube_base.position
		var base_scale_n: Vector3 = nube_base.scale

		if _sprites_nubes.size() <= 1:
			_sprites_nubes.clear()
			_sprites_nubes.append(nube_base)
			var x_start_n: float = base_pos_n.x - 1.0 * ancho_segmento_nubes
			nube_base.position.x = x_start_n
			for i in range(1, CANTIDAD_SEGMENTOS_NUBES):
				var clon_n: Sprite3D = nube_base.duplicate() as Sprite3D
				clon_n.name = "NubeRosa_" + str(i)
				clon_n.position = Vector3(x_start_n + float(i) * ancho_segmento_nubes, base_pos_n.y, base_pos_n.z)
				clon_n.scale = base_scale_n
				clon_n.layers = capa_visual
				contenedor_nubes.add_child(clon_n)
				_sprites_nubes.append(clon_n)

		# Limpiar cualquier ShaderMaterial residual en las nubes
		for s in _sprites_nubes:
			if s.material_override is ShaderMaterial:
				s.material_override = null


func _construir_capa_terroso() -> void:
	if _nodo_capa_terroso:
		return

	_nodo_capa_terroso = Node3D.new()
	_nodo_capa_terroso.name = "CapaTerroso"
	_nodo_capa_terroso.position = Vector3(0.0, altura_y_terroso, PROFUNDIDAD_TERROSO)
	add_child(_nodo_capa_terroso)

	for i in range(CANTIDAD_SEGMENTOS):
		var sprite := Sprite3D.new()
		sprite.name = "Terroso_" + str(i)
		sprite.texture = TEX_TERROSO
		sprite.shaded = false
		sprite.double_sided = true
		sprite.render_priority = -5
		sprite.layers = capa_visual

		var tam_textura := TEX_TERROSO.get_size() if TEX_TERROSO else Vector2(6500, 4000)
		var pixel_size: float = ancho_segmento_terroso / tam_textura.x
		sprite.pixel_size = pixel_size

		var x_pos: float = (float(i) - 1.0) * ancho_segmento_terroso
		sprite.position = Vector3(x_pos, 0.0, 0.0)
		_nodo_capa_terroso.add_child(sprite)
		_sprites_terroso.append(sprite)


func _on_video_finished() -> void:
	if is_instance_valid(_video_player):
		_video_player.paused = true


func _actualizar_video_frame() -> void:
	if is_instance_valid(_video_player) and is_instance_valid(_sprite_fondo_video):
		var v_tex: Texture2D = _video_player.get_video_texture()
		if v_tex:
			_sprite_fondo_video.texture = v_tex
			if _sprite_fondo_video.material_override is StandardMaterial3D:
				(_sprite_fondo_video.material_override as StandardMaterial3D).albedo_texture = v_tex


func _mantener_fondo_video_estatico() -> void:
	if not seguir_camara_video or not is_instance_valid(_sprite_fondo_video):
		return
	var x_cam: float = _obtener_x_camara()
	_sprite_fondo_video.global_position.x = x_cam + _offset_fondo_video_x


func _obtener_x_camara() -> float:
	if not is_instance_valid(_camara_referencia):
		var vp := get_viewport()
		if vp:
			_camara_referencia = vp.get_camera_3d()
		if not is_instance_valid(_camara_referencia):
			var raiz := get_tree().root if get_tree() else null
			if raiz:
				_camara_referencia = raiz.find_child("CamaraPrincipal", true, false) as Camera3D
	if is_instance_valid(_camara_referencia):
		return _camara_referencia.global_position.x
	return global_position.x


func _actualizar_loop_cordillera(delta: float) -> void:
	if _segmentos_cordillera.is_empty():
		return

	var paso: float = velocidad_base * factor_cordillera * delta
	for seg in _segmentos_cordillera:
		seg.position.x -= paso

	var x_cam: float = _obtener_x_camara()
	var x_cam_local: float = _nodo_capa_cordillera.to_local(Vector3(x_cam, 0.0, 0.0)).x if _nodo_capa_cordillera else x_cam
	var limite_izquierdo: float = x_cam_local - 30.0

	var x_maxima: float = -INF
	for seg in _segmentos_cordillera:
		if seg.position.x > x_maxima:
			x_maxima = seg.position.x

	for seg in _segmentos_cordillera:
		if seg.position.x <= limite_izquierdo:
			seg.position.x = x_maxima + ancho_segmento_cordillera
			x_maxima = seg.position.x


func _actualizar_loop_piso_aliado(delta: float) -> void:
	if not sincronizar_piso_con_cordillera or _segmentos_piso_aliado.is_empty():
		return

	# Velocidad idéntica a la cordillera para que se muevan como si fuera uno solo
	var paso: float = velocidad_base * factor_cordillera * delta
	for piso in _segmentos_piso_aliado:
		if is_instance_valid(piso):
			piso.position.x -= paso

	var x_cam: float = _obtener_x_camara()
	var contenedor: Node = _segmentos_piso_aliado[0].get_parent() if is_instance_valid(_segmentos_piso_aliado[0]) else null
	var x_cam_local: float = (contenedor as Node3D).to_local(Vector3(x_cam, 0.0, 0.0)).x if (contenedor is Node3D and contenedor != self and contenedor != get_parent()) else x_cam
	var limite_izquierdo: float = x_cam_local - 30.0

	var x_maxima: float = -INF
	for piso in _segmentos_piso_aliado:
		if is_instance_valid(piso) and piso.position.x > x_maxima:
			x_maxima = piso.position.x

	for piso in _segmentos_piso_aliado:
		if is_instance_valid(piso) and piso.position.x <= limite_izquierdo:
			piso.position.x = x_maxima + ancho_segmento_piso
			x_maxima = piso.position.x


func _inicializar_capa_agua_textura() -> void:
	_sprites_agua_textura.clear()
	var padre: Node = get_parent()
	if not is_instance_valid(padre):
		return
	for hijo in padre.get_children():
		if hijo is Sprite3D and (hijo as Node3D).visible and _es_sprite_agua_textura(hijo):
			_sprites_agua_textura.append(hijo as Sprite3D)

	_sprites_agua_textura.sort_custom(func(a: Sprite3D, b: Sprite3D) -> bool:
		return a.position.x < b.position.x
	)


func _es_sprite_agua_textura(nodo: Node) -> bool:
	if not (nodo is Sprite3D):
		return false
	var nombre_llano: String = nodo.name.to_lower()
	if nombre_llano.contains("fijo"):
		return false  ## "TexturaAgua(fijo)": sombra colocada a mano, no la mueve el parallax
	return nombre_llano.begins_with("texturaagua")


func _actualizar_loop_agua_textura(delta: float) -> void:
	if not sincronizar_agua_textura_con_cordillera or _sprites_agua_textura.is_empty():
		return

	# Velocidad idéntica a la cordillera para completar el efecto parallax
	var paso: float = velocidad_base * factor_cordillera * delta
	for sprite in _sprites_agua_textura:
		if is_instance_valid(sprite):
			sprite.position.x -= paso

	_reciclar_fuera_de_vista(_sprites_agua_textura, ancho_segmento_agua_textura)


func _inicializar_capa_casa_boneta() -> void:
	_segmentos_casa_boneta.clear()
	_recolectar_casas_boneta(self)
	var padre: Node = get_parent()
	if is_instance_valid(padre) and padre != self:
		_recolectar_casas_boneta(padre)

	_segmentos_casa_boneta.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.position.x < b.position.x
	)


func _recolectar_casas_boneta(contenedor: Node) -> void:
	for hijo in contenedor.get_children():
		if hijo is Node3D and not (hijo is Light3D or hijo is Camera3D) and _es_casa_boneta(hijo):
			if not _segmentos_casa_boneta.has(hijo):
				_segmentos_casa_boneta.append(hijo as Node3D)


func _es_casa_boneta(nodo: Node) -> bool:
	return nodo.name.to_lower().begins_with("casaboneta")


func _actualizar_loop_casa_boneta(delta: float) -> void:
	if not sincronizar_casa_boneta_con_cordillera or _segmentos_casa_boneta.is_empty():
		return

	# Velocidad idéntica a la cordillera para no romper el efecto parallax
	var paso: float = velocidad_base * factor_cordillera * delta
	for casa in _segmentos_casa_boneta:
		if is_instance_valid(casa):
			casa.position.x -= paso

	_reciclar_fuera_de_vista(_segmentos_casa_boneta, ancho_segmento_cordillera)


func _inicializar_capa_bosque_rojo() -> void:
	_sprites_bosque_rojo.clear()
	var padre: Node = get_parent()
	if not is_instance_valid(padre):
		return
	for hijo in padre.get_children():
		if hijo is Sprite3D and (hijo as Node3D).visible and _es_sprite_bosque_rojo(hijo):
			_sprites_bosque_rojo.append(hijo as Sprite3D)

	_sprites_bosque_rojo.sort_custom(func(a: Sprite3D, b: Sprite3D) -> bool:
		return a.position.x < b.position.x
	)


func _es_sprite_bosque_rojo(nodo: Node) -> bool:
	if not (nodo is Sprite3D):
		return false
	return nodo.name.to_lower().begins_with("bosquerojo")


func _actualizar_loop_bosque_rojo(delta: float) -> void:
	if not sincronizar_bosque_rojo_con_fondo or _sprites_bosque_rojo.is_empty():
		return

	# Más lento que la cordillera: el bosque está más lejos
	var paso: float = velocidad_base * factor_bosque_rojo * delta
	for sprite in _sprites_bosque_rojo:
		if is_instance_valid(sprite):
			sprite.position.x -= paso

	_reciclar_fuera_de_vista(_sprites_bosque_rojo, ancho_segmento_bosque_rojo)


func _inicializar_capa_niebla() -> void:
	_segmentos_niebla.clear()
	_recolectar_niebla(self)
	var padre: Node = get_parent()
	if is_instance_valid(padre) and padre != self:
		_recolectar_niebla(padre)

	_segmentos_niebla.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.position.x < b.position.x
	)


func _recolectar_niebla(contenedor: Node) -> void:
	for hijo in contenedor.get_children():
		if hijo is Node3D and not (hijo is Light3D or hijo is Camera3D) and _es_niebla(hijo):
			if not _segmentos_niebla.has(hijo):
				_segmentos_niebla.append(hijo as Node3D)


func _es_niebla(nodo: Node) -> bool:
	return nodo.name.to_lower().begins_with("nieblasutil")


func _actualizar_loop_niebla(delta: float) -> void:
	if not sincronizar_niebla_con_cordillera or _segmentos_niebla.is_empty():
		return

	# Velocidad idéntica a la cordillera
	var paso: float = velocidad_base * factor_cordillera * delta
	for niebla in _segmentos_niebla:
		if is_instance_valid(niebla):
			niebla.position.x -= paso

	_reciclar_fuera_de_vista(_segmentos_niebla, ancho_segmento_niebla)


## Reciclaje genérico sin pops: lo que sale por la izquierda reaparece
## fuera de vista a la derecha (conserva el grupo si sigue delante).
func _reciclar_fuera_de_vista(segmentos: Array, ancho: float) -> void:
	if segmentos.is_empty():
		return
	var primero := segmentos[0] as Node3D
	if not is_instance_valid(primero):
		return
	var contenedor: Node3D = primero.get_parent() as Node3D
	var x_cam_local: float = contenedor.to_local(Vector3(_obtener_x_camara(), 0.0, 0.0)).x if contenedor else _obtener_x_camara()
	var limite_izq: float = x_cam_local - margen_reciclaje_atras

	var x_max: float = -INF
	for seg in segmentos:
		var nodo := seg as Node3D
		if is_instance_valid(nodo) and nodo.position.x > x_max:
			x_max = nodo.position.x

	var destino: float = maxf(x_max + ancho, x_cam_local + margen_reciclaje_adelante)
	for seg in segmentos:
		var nodo := seg as Node3D
		if is_instance_valid(nodo) and nodo.position.x <= limite_izq:
			nodo.position.x = destino
			destino += ancho


func _inicializar_capa_arbol_cordillera() -> void:
	_segmentos_arbol_cordillera.clear()
	_recolectar_arboles_cordillera(self)
	var padre: Node = get_parent()
	if is_instance_valid(padre) and padre != self:
		_recolectar_arboles_cordillera(padre)

	_segmentos_arbol_cordillera.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.position.x < b.position.x
	)


func _recolectar_arboles_cordillera(contenedor: Node) -> void:
	for hijo in contenedor.get_children():
		if hijo is Node3D and not (hijo is Light3D or hijo is Camera3D) and _es_arbol_cordillera(hijo):
			if not _segmentos_arbol_cordillera.has(hijo):
				_segmentos_arbol_cordillera.append(hijo as Node3D)


func _es_arbol_cordillera(nodo: Node) -> bool:
	var nombre_llano: String = nodo.name.to_lower().replace(" ", "")
	return nombre_llano.contains("arbollow") and nombre_llano.contains("cordillera")


func _actualizar_loop_arbol_cordillera(delta: float) -> void:
	if not sincronizar_arbol_cordillera or _segmentos_arbol_cordillera.is_empty():
		return

	# Velocidad idéntica a la cordillera para no romper el efecto parallax
	var paso: float = velocidad_base * factor_cordillera * delta
	for arbol in _segmentos_arbol_cordillera:
		if is_instance_valid(arbol):
			arbol.position.x -= paso

	_reciclar_fuera_de_vista(_segmentos_arbol_cordillera, ancho_segmento_cordillera)


func _actualizar_loop_arboles(delta: float) -> void:
	if _sprites_arboles.is_empty():
		return

	var paso: float = velocidad_base * factor_arboles * delta
	for s in _sprites_arboles:
		s.position.x -= paso

	var x_cam: float = _obtener_x_camara()
	var contenedor: Node3D = _sprites_arboles[0].get_parent() as Node3D
	var x_cam_local: float = contenedor.to_local(Vector3(x_cam, 0.0, 0.0)).x if contenedor else x_cam
	var limite_izq: float = x_cam_local - 35.0

	var x_max: float = -INF
	for s in _sprites_arboles:
		if s.position.x > x_max:
			x_max = s.position.x

	for s in _sprites_arboles:
		if s.position.x <= limite_izq:
			s.position.x = x_max + ancho_segmento_arboles
			x_max = s.position.x


func _actualizar_loop_nubes(delta: float) -> void:
	if _sprites_nubes.is_empty():
		return

	var paso: float = velocidad_base * factor_nubes * delta
	for s in _sprites_nubes:
		s.position.x -= paso

	var x_cam: float = _obtener_x_camara()
	var contenedor: Node3D = _sprites_nubes[0].get_parent() as Node3D
	var x_cam_local: float = contenedor.to_local(Vector3(x_cam, 0.0, 0.0)).x if contenedor else x_cam
	var limite_izq: float = x_cam_local - 55.0

	var x_max: float = -INF
	for s in _sprites_nubes:
		if s.position.x > x_max:
			x_max = s.position.x

	for s in _sprites_nubes:
		if s.position.x <= limite_izq:
			s.position.x = x_max + ancho_segmento_nubes
			x_max = s.position.x


func _actualizar_loop_terroso(delta: float) -> void:
	if _sprites_terroso.is_empty():
		return

	var paso: float = velocidad_base * delta
	for s in _sprites_terroso:
		s.position.x -= paso

	var x_cam: float = _obtener_x_camara()
	var x_cam_local: float = _nodo_capa_terroso.to_local(Vector3(x_cam, 0.0, 0.0)).x if _nodo_capa_terroso else x_cam
	var limite_izquierdo: float = x_cam_local - ancho_segmento_terroso * 1.5
	var x_maxima: float = -INF

	for s in _sprites_terroso:
		if s.position.x > x_maxima:
			x_maxima = s.position.x

	for s in _sprites_terroso:
		if s.position.x <= limite_izquierdo:
			s.position.x = x_maxima + ancho_segmento_terroso
			x_maxima = s.position.x


func _guardar_offset_fondo_video() -> void:
	if is_instance_valid(_sprite_fondo_video):
		var x_cam: float = _obtener_x_camara()
		_offset_fondo_video_x = _sprite_fondo_video.global_position.x - x_cam


func _aplicar_capa_visual_recursiva(nodo: Node) -> void:
	if nodo is VisualInstance3D:
		if Engine.is_editor_hint():
			nodo.layers = capa_visual | 1
		else:
			nodo.layers = capa_visual
	for hijo in nodo.get_children():
		_aplicar_capa_visual_recursiva(hijo)


## Mueve la cordillera y el piso de fondo a su capa lejana (2 por defecto).
func _aplicar_capas_fondo() -> void:
	for seg in _segmentos_cordillera:
		if is_instance_valid(seg):
			_fijar_capa_recursiva(seg, capa_cordillera)
	for seg in _segmentos_reflejo:
		if is_instance_valid(seg):
			_fijar_capa_recursiva(seg, capa_cordillera)
	for piso in _segmentos_piso_aliado:
		if is_instance_valid(piso):
			_fijar_capa_recursiva(piso, capa_piso_fondo)


func _fijar_capa_recursiva(nodo: Node, capa: int) -> void:
	if nodo is VisualInstance3D and not (nodo is Light3D or nodo is Camera3D):
		if Engine.is_editor_hint():
			(nodo as VisualInstance3D).layers = capa | 1
		else:
			(nodo as VisualInstance3D).layers = capa
	for hijo in nodo.get_children():
		_fijar_capa_recursiva(hijo, capa)
