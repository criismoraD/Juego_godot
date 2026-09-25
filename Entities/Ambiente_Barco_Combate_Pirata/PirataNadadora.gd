class_name PirataNadadora
extends Node3D

## Pirata goblin nadadora DECORATIVA que aparece al hundirse el BarcoCombatePirata.
## - NO es enemiga: jamÃ¡s entra a los grupos "enemies"/"enemigos", no tiene
##   colisiÃ³n (el GLB no trae ninguna) ni IA, estados o proyectiles.
## - Nada con el clip "Nadar" del propio modelo hacia direccion_x hasta salir
##   de cuadro (mismo patrÃ³n de distancia a cÃ¡mara que PezDeRio).
## - Si pasan tiempo_maximo_visible segundos (10.0) y sigue en cuadro, se
##   desvanece con la disoluciÃ³n de muerte enemiga (dissolve 0.0 -> 1.0).

const MODELO_PIRATA: PackedScene = preload("res://TEST_/Pirata Goba/PirataGoblin.glb")
const MAT_PIRATA: StandardMaterial3D = preload("res://Entities/Enemigo_Pirata_Goblin/MAT_PIRATA_GOBLIN.tres")
const SHADER_DISOLVER: Shader = preload("res://System/Shaders/dissolve.gdshader")
const COLOR_DESVANECIDO: Color = Color(0.44705883, 0.0, 0.06666667)  ## Borde de muerte del pirata (ImpEnemy.tscn)
const SFX_NADO: AudioStream = preload("res://TEST_/Nadar pirata.mp3")
const NOMBRE_AUDIO_NADO: String = "nadar_pirata"

@export_category("Nado")
@export var velocidad_nado: float = 0.9  ## m/s hacia direccion_x
@export var direccion_x: float = -1.0  ## -1 nada a la izquierda, +1 a la derecha
@export var amplitud_flote: float = 0.05  ## Sube y baja sobre el agua (metros)
@export var frecuencia_flote: float = 1.6  ## Ritmo del sube y baja (Hz)

@export_category("Salida de Cuadro")
@export var margen_salida_x: float = 6.5  ## Distancia tras la cÃ¡mara donde ya estÃ¡ fuera de cuadro (como PezDeRio)
@export var gracia_fuera_cuadro: float = 1.0  ## Segundos nadando fuera de cuadro antes de liberarse

@export_category("Desvanecido en Cuadro")
@export var tiempo_maximo_visible: float = 10.0  ## Si sigue en cuadro pasado este tiempo, se desvanece como al morir
@export var duracion_desvanecido: float = 1.2  ## DuraciÃ³n de la disoluciÃ³n enemiga

@export_category("Visual")
@export var capa_visual: int = 1  ## Frontal, como el barco y la tripulaciÃ³n

@export_category("Sonido")
@export var sonido_nado: bool = true  ## Reproduce "Nadar pirata.mp3" en bucle mientras nada
@export var volumen_nado_db: float = -4.0
@export var pitch_min_nado: float = 0.95  ## VariaciÃ³n para que 2 nadadoras no suenen idÃ©nticas
@export var pitch_max_nado: float = 1.05

var _tiempo: float = 0.0
var _base_y: float = 0.0
var _base_z: float = 0.0
var _base_lista: bool = false
var _tiempo_fuera: float = 0.0
var _desvaneciendo: bool = false
var _camara_cache: Camera3D = null
var _anim_player: AnimationPlayer = null
var _audio_nado: AudioStreamPlayer3D = null


func _ready() -> void:
	_instanciar_modelo()
	_orientar_nado()
	_iniciar_sonido_nado()
	set_process(true)


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	if not _base_lista:
		_base_y = global_position.y
		_base_z = global_position.z
		_base_lista = true
	_tiempo += delta
	_avanzar_nado(delta)
	if _desvaneciendo:
		return
	if _tiempo >= tiempo_maximo_visible:
		_iniciar_desvanecido()
		return
	_procesar_salida_cuadro(delta)


## Avance horizontal + flote sinusoidal (sigue nadando tambiÃ©n durante el desvanecido).
func _avanzar_nado(delta: float) -> void:
	var dir: float = -1.0 if direccion_x < 0.0 else 1.0
	var gp: Vector3 = global_position
	gp.x += dir * maxf(velocidad_nado, 0.0) * delta
	gp.y = _base_y + sin(_tiempo * frecuencia_flote * TAU) * amplitud_flote
	gp.z = _base_z
	global_position = gp


## Fuera de cuadro por el lado hacia el que nada: gracia y liberaciÃ³n directa.
func _procesar_salida_cuadro(delta: float) -> void:
	var cam := _obtener_camara()
	if not is_instance_valid(cam):
		return
	var dir: float = -1.0 if direccion_x < 0.0 else 1.0
	var fuera: bool = false
	if dir < 0.0:
		fuera = global_position.x < cam.global_position.x - margen_salida_x
	else:
		fuera = global_position.x > cam.global_position.x + margen_salida_x
	if not fuera:
		_tiempo_fuera = 0.0
		return
	_tiempo_fuera += delta
	if _tiempo_fuera >= gracia_fuera_cuadro:
		queue_free()


## DisoluciÃ³n de muerte enemiga (0.0 -> 1.0) y liberaciÃ³n.
func _iniciar_desvanecido() -> void:
	if _desvaneciendo:
		return
	_desvaneciendo = true
	if not is_instance_valid(SHADER_DISOLVER):
		queue_free()
		return
	var mats: Array = []
	for nodo in find_children("*", "MeshInstance3D", true, false):
		var mi := nodo as MeshInstance3D
		if mi == null or not is_instance_valid(mi):
			continue
		var mat := ShaderMaterial.new()
		mat.shader = SHADER_DISOLVER
		mat.set_shader_parameter("dissolve_amount", 0.0)
		mat.set_shader_parameter("glow_color", COLOR_DESVANECIDO)
		mat.set_shader_parameter("glow_intensity", 6.0)
		mat.set_shader_parameter("edge_thickness", 0.05)
		mat.set_shader_parameter("noise_scale", 20.0)
		var orig: Material = mi.material_override
		if orig == null and mi.mesh and mi.mesh.get_surface_count() > 0:
			orig = mi.mesh.surface_get_material(0)
		if orig is StandardMaterial3D:
			var std := orig as StandardMaterial3D
			if std.albedo_texture:
				mat.set_shader_parameter("albedo_texture", std.albedo_texture)
			var col := std.albedo_color
			mat.set_shader_parameter("albedo_tint", Vector3(col.r, col.g, col.b))
		mi.material_override = mat
		mats.append(mat)
	if mats.is_empty() or get_tree() == null:
		queue_free()
		return
	var tw := create_tween()
	tw.tween_method(
		func(val: float) -> void:
			for sm in mats:
				if is_instance_valid(sm):
					(sm as ShaderMaterial).set_shader_parameter("dissolve_amount", val),
		0.0, 1.0, maxf(duracion_desvanecido, 0.1)
	)
	tw.finished.connect(func() -> void: queue_free())


## Retorna true cuando ya empezÃ³ el desvanecido de los 10 segundos.
func esta_desvaneciendo() -> bool:
	return _desvaneciendo


func _instanciar_modelo() -> void:
	if MODELO_PIRATA == null:
		return
	var modelo := MODELO_PIRATA.instantiate() as Node3D
	if modelo == null:
		return
	add_child(modelo)
	var frontal := _crear_material_frontal()
	if frontal:
		for nodo in modelo.find_children("*", "MeshInstance3D", true, false):
			(nodo as MeshInstance3D).material_override = frontal
	_aplicar_capa_visual_recursiva(modelo)
	_anim_player = modelo.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim_player == null:
		for n in find_children("*", "AnimationPlayer", true, false):
			_anim_player = n as AnimationPlayer
			break
	_reproducir_nadar()


## Duplicado frontal del material pirata: cola transparente + sin test de
## profundidad + prioridad mÃ¡xima (127), para que las nadadoras pasen POR
## DELANTE de la canoa en vez de atravesarla. No toca el MAT_PIRATA compartido.
func _crear_material_frontal() -> StandardMaterial3D:
	if MAT_PIRATA == null:
		return null
	var frontal := MAT_PIRATA.duplicate() as StandardMaterial3D
	frontal.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	frontal.no_depth_test = true
	frontal.render_priority = 127
	var contorno_src: Material = MAT_PIRATA.next_pass
	if contorno_src:
		var contorno := contorno_src.duplicate() as Material
		contorno.render_priority = 127
		frontal.next_pass = contorno
	return frontal


## Localiza el clip de nado por nombre (tolerante) y lo deja en bucle.
func _reproducir_nadar() -> void:
	if _anim_player == null:
		return
	var objetivo: StringName = StringName("")
	for a in _anim_player.get_animation_list():
		if "nadar" in a.to_lower():
			objetivo = StringName(a)
			break
	if objetivo == StringName(""):
		return
	var clip := _anim_player.get_animation(objetivo)
	if clip:
		clip.loop_mode = Animation.LOOP_LINEAR
	_anim_player.play(objetivo)


## Sonido de nado en bucle 3D (hijo: se libera solo con la nadadora).
func _iniciar_sonido_nado() -> void:
	if not sonido_nado:
		return
	var stream: AudioStream = SFX_NADO
	if stream == null:
		var manager := get_node_or_null("/root/AudioManager")
		if manager and manager.has_method("obtener_stream_sfx"):
			stream = manager.obtener_stream_sfx(NOMBRE_AUDIO_NADO) as AudioStream
	if stream == null:
		return
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	_audio_nado = AudioStreamPlayer3D.new()
	_audio_nado.name = "AudioNadoPirata"
	_audio_nado.stream = stream
	_audio_nado.bus = "Master"
	_audio_nado.volume_db = volumen_nado_db
	_audio_nado.unit_size = 8.0
	_audio_nado.max_distance = 40.0
	_audio_nado.pitch_scale = randf_range(minf(pitch_min_nado, pitch_max_nado), maxf(pitch_min_nado, pitch_max_nado))
	add_child(_audio_nado)
	_audio_nado.play()


## El GLB mira a +Z de fÃ¡brica (de frente a cÃ¡mara): se gira âˆ“90Â° para verlo
## de lado encarando el rumbo (-90Â° nada a la izquierda, como PezDeRio).
func _orientar_nado() -> void:
	rotation.y = -PI * 0.5 if direccion_x < 0.0 else PI * 0.5


func _aplicar_capa_visual_recursiva(nodo: Node) -> void:
	if nodo is VisualInstance3D:
		(nodo as VisualInstance3D).layers = capa_visual
	for hijo in nodo.get_children():
		_aplicar_capa_visual_recursiva(hijo)


func _obtener_camara() -> Camera3D:
	if is_instance_valid(_camara_cache):
		return _camara_cache
	if get_viewport():
		_camara_cache = get_viewport().get_camera_3d()
	return _camara_cache
