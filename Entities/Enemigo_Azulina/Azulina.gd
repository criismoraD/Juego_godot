class_name Azulina
extends EnemyBase

## Enemiga Azulina: emerge del agua con salto (squash & stretch), dispara
## su lanza a mitad del salto y al aterrizar, y muere con "Muerte 1" o "Muerte 3".
## Usa las animaciones del GLB: "Ataque salto del agua", "Correr", "Mirar" (quieta),
## "Ataque", "Daño", "Muerte 1" y "Muerte 3".

signal emergencia_completada

const ESCENA_LANZA: PackedScene = preload("res://Entities/Proyectil_Lanza_Azulina/LanzaAzulinaProjectile.tscn")
const ESCENA_SALPICADURA: PackedScene = preload("res://Entities/Enemigo_Azulina/SalpicaduraAgua.tscn")
const ESCENA_LANZA_SUELTA: PackedScene = preload("res://TEST_/Lanza Azulina/Lanza Azulina.glb")
const MATERIAL_AZULINA: Material = preload("res://Entities/Enemigo_Azulina/Azulina_MAT.tres")
const MATERIAL_LANZA: Material = preload("res://Entities/Enemigo_Azulina/LanzaAzulina_MAT.tres")
const ANIM_SALTO_AGUA: String = "Ataque salto del agua"  ## Nombre exacto en el GLB (salto de emergencia)

# === EXPORTS ===
@export_category("Emergencia del agua")
@export var emerger_del_agua: bool = true  ## Si true, entra con salto desde el agua hasta el terreno
@export var hundimiento_emergencia: float = 2.5  ## Metros bajo el punto de caída donde nace (en el agua)
@export var alcance_emergencia_x: float = 1.5  ## Metros a la derecha del punto de caída donde nace (salto casi vertical)
@export var deriva_fondo_z: float = 1.0  ## Metros hacia la cámara desde donde nace (cae hacia el fondo)
@export var altura_salto: float = 2.0  ## Altura máxima del arco de emergencia sobre la recta origen→caída
@export var duracion_emergencia: float = 1.4  ## Segundos del salto
@export var acelerar_tramo_final: bool = true  ## Si true, la animación se acelera al final para un aterrizaje con impacto
@export_range(0.0, 1.0, 0.05) var inicio_tramo_final: float = 0.55  ## Fracción del salto donde arranca la aceleración
@export var velocidad_tramo_final: float = 1.7  ## Multiplicador de velocidad en el tramo final
@export var emergencia_en_zona_aleatoria: bool = true  ## Si true, el punto de caida se sortea dentro de la zona (no sale siempre del mismo lugar)
@export var usar_centro_zona_personalizado: bool = false  ## Si false, la zona se centra en el punto de spawn
@export var zona_centro: Vector3 = Vector3.ZERO  ## Centro manual de la zona (solo si usar_centro_zona_personalizado)
@export var zona_extension: Vector3 = Vector3(4.0, 0.0, 0.0)  ## Semiextensiones XZ de la zona (Z en 0: fijo al plano enemigo para que las flechas impacten)
@export var aterrizar_en_centro: bool = false  ## Si true, cae en centro_aterrizaje_x aunque emerja en la zona
@export var centro_aterrizaje_x: float = 0.0  ## X del punto de caída (centro del eje)

@export_category("Salpicadura al emerger")
@export var salpicadura_al_emerger: bool = true  ## Si true, genera el splash donde rompe el agua al emerger
@export var profundidad_rotura: float = 0.2  ## Metros bajo el destino (orilla) donde nace el splash
@export var adelanto_camara_salpicadura: float = 1.5  ## Metros hacia la camara desde el origen para que el ledge no lo tape
@export var desplazamiento_lateral_salpicadura: float = -0.5  ## Metros en X desde el origen (negativo = izquierda en pantalla)

@export_category("Remate al aterrizar")
@export var disparar_al_aterrizar: bool = true  ## Si true, al caer al terreno pasa a SHOOTING y lanza de inmediato
@export_range(0.0, 1.0, 0.05) var momento_disparo_emergencia: float = 0.55  ## Fracción del salto donde dispara entrando (ella entra atacando)

@export_category("Squash and Stretch")
@export var squash_stretch: bool = true  ## Deforma el modelo en el salto: estira al subir, aplasta al caer
@export_range(0.0, 0.4, 0.01) var intensidad_squash: float = 0.18  ## Desviación máxima de escala (conserva volumen)
@export var duracion_recuperacion_squash: float = 0.35  ## Segundos para volver a la forma base tras aterrizar

@export_category("Presencia")
@export var animacion_quieta: String = "Idle"  ## Idle natural entre ataques (en vez de correr en el sitio)
@export var animaciones_muerte: Array[String] = ["Muerte 1", "Muerte 3"]  ## Muertes posibles, una al azar
@export_range(0.0, 1.0, 0.05) var fundido_transiciones: float = 0.3  ## Fundido al volver a la calma (quieta, correr, fin de parry)
@export_range(0.0, 1.0, 0.05) var fundido_ataque: float = 0.12  ## Fundido al entrar en acción (ataque, salto, giro)

@export_category("Parry de lanza")
@export var parry_habilitado: bool = true  ## Si true, puede girar la lanza para repeler proyectiles
@export var duracion_parry: float = 3.0  ## Segundos que dura el giro repelente
@export var ataques_para_parry_min: int = 4  ## Mínimo de ataques recibidos para activar al azar
@export var ataques_para_parry_max: int = 5  ## Máximo de ataques recibidos para activar al azar
@export var ventana_multidisparo: float = 0.6  ## Segundos: 2+ impactos en esta ventana activan de inmediato
@export var enfriamiento_parry: float = 5.0  ## Segundos vulnerables tras un parry antes de poder activar otro
@export var animacion_parry: String = "Giro de lanza parry"  ## Giro corto que se repite invertido en loop
@export_range(0.5, 3.0, 0.1) var velocidad_parry: float = 1.6  ## Velocidad del giro para un ciclo dinámico
@export var duracion_hold_parry: float = 1.5  ## Segundos congelado en el cuadro final antes de invertir
@export var escala_lanza_parry: float = 1.5  ## Tamaño del asta durante el giro (el reposo se restaura solo)
@export var forzar_parry_debug: bool = false:  ## DEBUG en juego (árbol Remoto): al activar fuerza el parry para verificar lanza y giro
	set(v):
		forzar_parry_debug = v
		if v and is_node_ready() and is_inside_tree() and not Engine.is_editor_hint():
			_activar_parry()
@export var barrer_agarre_debug: bool = false  ## DEBUG: gira la lanza en la mano durante el parry para buscar el agarre visible
@export var velocidad_barrido: float = 0.6  ## Radianes por segundo del barrido de agarre
@export var imprimir_agarre_debug: bool = false  ## DEBUG: imprime el transform actual de la lanza (para fijarlo en el tscn)
@export var circulo_parry: bool = true  ## Si true, muestra el aro protector animado durante el parry
@export var tamano_circulo: float = 1.4:  ## Diámetro en metros del aro protector
	set(v):
		tamano_circulo = maxf(0.5, v)
		_aplicar_tamano_circulo()
@export var fps_circulo: float = 20.0  ## Cuadros por segundo del aro
@export var offset_circulo: Vector3 = Vector3(0.0, 0.65, 0.6):  ## Posición manual del aro respecto a sus pies (Z+ = hacia la cámara)
	set(v):
		offset_circulo = v
		if is_instance_valid(_circulo):
			_circulo.position = v
@export_range(0.1, 1.0, 0.05) var opacidad_circulo: float = 1.0  ## 1.0 = sólido
@export var brillo_circulo: float = 1.2  ## Energía de la luz celeste del aro

@export_category("Ataque de lanza")
@export var tiempo_lanzamiento: float = 0.9  ## Segundo de la animación donde sale la lanza
@export var pausa_entre_lanzamientos_min: float = 1.2
@export var pausa_entre_lanzamientos_max: float = 2.0
@export var velocidad_lanza: float = 14.0  ## Más rápida que el tridente del imp (8)
@export var gravedad_lanza: float = 0.6  ## Más tensa que el tridente (1.2)
@export var dispersion_rad: float = 0.03  ## Dispersión mínima: precisión alta
@export var duracion_reaparicion_lanza: float = 0.5  ## Segundos de la disolución celeste al volver a la mano

# === ESTADO PRIVADO ===
var _emergiendo: bool = false
var _tiempo_emergencia: float = 0.0
var _origen_emergencia: Vector3 = Vector3.ZERO
var _destino_emergencia: Vector3 = Vector3.ZERO
var _lanzando: bool = false
var _lanzo_proyectil: bool = false
var _timer_lanzamiento: float = 0.0
var _pausa_lanzamiento: float = 1.5
var _modelo: Node3D = null  ## AzulinaModel cacheado para el squash & stretch
var _escala_modelo_base: float = 0.9  ## Escala de mundo del modelo (se captura en _ready)
var _memoria_squash: float = 0.0  ## Deformación remanente (-1 aplastada .. +1 estirada), decae a 0
var _lanzo_en_emergencia: bool = false  ## Disparo único a mitad del salto de entrada
var _velocidad_salto_base: float = 1.0  ## speed_scale previo al salto (se restaura al aterrizar)
var _lanza_arrojada: bool = false  ## La lanza salió volando: se oculta hasta volver a idle
var murio_por_explosion: bool = false  ## Marcado por FlechaExplosiva: impulso en parábola al morir
var _impulso_explosivo_activo: bool = false  ## True durante el vuelo parabólico del cadáver
var _impulso_muerte_activo: bool:
	get: return _impulso_explosivo_activo
	set(v): _impulso_explosivo_activo = v
var _tiempo_flinch: float = 0.0  ## Segundos restantes de la animación de daño (bloquea el ataque para que se vea)
var _parry_activo: bool = false  ## Giro de lanza repelente en curso
var _tiempo_parry: float = 0.0  ## Segundos restantes del parry
var _tiempo_enfriamiento: float = 0.0  ## Segundos restantes vulnerables antes del próximo parry
var _contador_ataques: int = 0  ## Ataques recibidos en el ciclo actual (para el sorteo 4-5)
var _umbral_parry: int = 4  ## Ataques necesarios para activar (se sortea 4-5 por ciclo)
var _impactos_recientes: Array[float] = []  ## Tiempos de impactos (para detectar multidisparo)
var _anim_parry_loop: String = ""  ## Nombre del giro duplicado para alternar normal/invertido
var _giro_hacia_atras: bool = false  ## Dirección actual de la alternancia
var _tiempo_hold_parry: float = 0.0  ## Congelado restante en el cuadro final
var _velocidad_previa_parry: float = 1.0  ## speed_scale anterior para restaurarlo al terminar
var _mano: Node3D = null  ## Soporte de lanzas (attachment: cubre LanzaMano y lanza giro parry)
var _circulo: AnimatedSprite3D = null  ## Aro protector animado cuadro por cuadro durante el parry
var _luz_circulo: OmniLight3D = null  ## Brillo celeste del aro
var _escala_lanza_base: Vector3 = Vector3.ZERO  ## Escala de reposo del asta (se restaura tras el parry)
var _esqueleto: Skeleton3D = null  ## Esqueleto cacheado para congelar piernas en el parry
var _huesos_piernas: Array[int] = []  ## Índices resueltos de HUESOS_PIERNAS
var _pose_piernas_fija: Array[Quaternion] = []  ## Postura de piernas capturada al activar (se mantiene)


# === HOOKS DE ENEMYBASE ===
func _on_enemy_ready() -> void:
	rastrear_jugador = false
	_modelo = find_child("AzulinaModel", true, false) as Node3D
	if _modelo:
		_escala_modelo_base = _modelo.scale.x
	_aplicar_material_azulina()
	_forzar_loop_movimiento()
	_umbral_parry = _sortear_umbral_parry()
	_resolver_hueso_mano()
	_crear_circulo_parry()
	_mostrar_lanza(false)
	if emerger_del_agua:
		_iniciar_emergencia()
	else:
		_play_animation("Correr")


func _process_walking(delta: float) -> void:
	if _emergiendo:
		_procesar_emergencia(delta)
		return
	if _procesar_parry(delta):
		return
	if _tiempo_flinch > 0.0:
		_tiempo_flinch -= delta
		if _tiempo_flinch <= 0.0:
			_play_animation("Correr", fundido_transiciones)
	_recuperar_squash(delta)
	super._process_walking(delta)


func _process_shooting(delta: float) -> void:
	velocity.x = 0
	_recuperar_squash(delta)
	if _procesar_parry(delta):
		return
	if _tiempo_flinch > 0.0:
		_tiempo_flinch -= delta
		if _tiempo_flinch <= 0.0 and not _lanzando:
			_play_animation(animacion_quieta, fundido_transiciones)
		if anim_player != null and not String(anim_player.current_animation).contains("Daño"):
			_play_animation("Daño")
		return
	if _lanzando:
		_timer_lanzamiento += delta
		if not _lanzo_proyectil and _timer_lanzamiento >= tiempo_lanzamiento:
			_lanzar_lanza()
			_lanzo_proyectil = true
		if _timer_lanzamiento >= _duracion_anim_ataque():
			_lanzando = false
			_pausa_lanzamiento = randf_range(pausa_entre_lanzamientos_min, pausa_entre_lanzamientos_max)
			if _lanza_arrojada and not _parry_activo:
				_reaparecer_lanza()
			_play_animation(animacion_quieta, fundido_transiciones)
	else:
		_pausa_lanzamiento -= delta
		if _pausa_lanzamiento <= 0.0:
			_iniciar_ataque()


## Humo celeste a ambos lados al iniciar el giro (como al romperse escudos).
## Humo celeste a ambos lados de un punto (parry,ruptura o muerte del aro).
func _spawn_humo_celeste(centro: Vector3) -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	var tex: Texture2D = load("res://VFX/Textures/Smoke/Smoke_2A-2.png") as Texture2D
	if tex == null:
		return
	var raiz: Node = get_tree().current_scene
	if raiz == null:
		raiz = get_tree().root
	for lado in [-1.0, 1.0]:
		var puf := GPUParticles3D.new()
		puf.amount = 4
		puf.lifetime = 0.75
		puf.one_shot = true
		puf.explosiveness = 0.3
		puf.randomness = 0.3
		puf.visibility_aabb = AABB(Vector3(-1.5, -1.2, -1.5), Vector3(3.0, 3.0, 3.0))
		var pmat := ParticleProcessMaterial.new()
		pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
		pmat.direction = Vector3(lado * 0.8, 0.35, 0.0)
		pmat.spread = 22.0
		pmat.initial_velocity_min = 0.8
		pmat.initial_velocity_max = 1.4
		pmat.gravity = Vector3(0.0, -0.3, 0.0)
		pmat.scale_min = 0.55
		pmat.scale_max = 0.85
		var grad := Gradient.new()
		grad.set_color(0, Color(0.45, 0.85, 1.0, 0.9))
		grad.set_color(1, Color(0.45, 0.85, 1.0, 0.0))
		var grad_tex := GradientTexture1D.new()
		grad_tex.gradient = grad
		pmat.color_ramp = grad_tex
		puf.process_material = pmat
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.vertex_color_use_as_albedo = true
		mat.albedo_color = Color(0.5, 0.85, 1.0)
		mat.albedo_texture = tex
		mat.particles_anim_h_frames = 6
		mat.particles_anim_v_frames = 1
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.billboard_keep_scale = true
		var quad := QuadMesh.new()
		quad.size = Vector2(0.85, 0.85)
		quad.material = mat
		puf.draw_pass_1 = quad
		raiz.add_child(puf)
		puf.global_position = centro + Vector3(lado * 0.3, 0.05, 0.0)
		puf.emitting = true
		get_tree().create_timer(2.0).timeout.connect(_liberar_humo.bind(puf))


## Humo del parry a ambos lados de sus pies.
func _spawn_humo_parry() -> void:
	_spawn_humo_celeste(global_position)


func _liberar_humo(puf: GPUParticles3D) -> void:
	if is_instance_valid(puf):
		puf.queue_free()


## Suelta la lanza al morir con física de la misma manera que la arquera goblin:
## sale volando en parábola (LanzaVoladora que hereda de GoblinPiezaFisica),
## rebota contra el suelo y se disuelve tras un tiempo con efecto celeste.
func _soltar_lanza_al_morir() -> void:
	if get_tree() == null:
		return
	var root_scene: Node = get_tree().current_scene
	if not root_scene:
		root_scene = get_tree().root
	if not root_scene:
		return

	# Dirección de expulsión según el punto de impacto de la explosión o golpe
	var push_dir: float = 1.0
	if last_hit_position != Vector3.ZERO:
		var dx: float = global_position.x - last_hit_position.x
		if absf(dx) > 0.05:
			push_dir = signf(dx)
	elif is_instance_valid(player_ref):
		var dx: float = global_position.x - (player_ref as Node3D).global_position.x
		if absf(dx) > 0.05:
			push_dir = signf(dx)

	var lanza_mano := find_child("LanzaMano", true, false) as Node3D
	var lanza_parry := find_child("lanza giro parry", true, false) as Node3D
	if is_instance_valid(lanza_parry):
		lanza_parry.visible = false

	var tr_lanza: Transform3D = global_transform
	var pieza_visual: Node3D = null

	if is_instance_valid(lanza_mano):
		tr_lanza = lanza_mano.global_transform
		if lanza_mano.get_parent():
			lanza_mano.get_parent().remove_child(lanza_mano)
		pieza_visual = lanza_mano
	elif is_instance_valid(_mano):
		tr_lanza = (_mano as Node3D).global_transform
		if ESCENA_LANZA_SUELTA:
			pieza_visual = ESCENA_LANZA_SUELTA.instantiate() as Node3D
	else:
		tr_lanza = global_transform * Transform3D(Basis(), Vector3(0.0, 0.5, 0.0))
		if ESCENA_LANZA_SUELTA:
			pieza_visual = ESCENA_LANZA_SUELTA.instantiate() as Node3D

	if not is_instance_valid(pieza_visual):
		return

	var contenedor := LanzaVoladora.new()
	root_scene.add_child(contenedor)
	contenedor.global_transform = tr_lanza

	pieza_visual.transform = Transform3D.IDENTITY
	pieza_visual.visible = true
	# Aplicar MATERIAL_LANZA para asegurar el aspecto correcto sin tintes de daño residuales
	for m in pieza_visual.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		mi.visible = true
		if MATERIAL_LANZA:
			mi.material_override = MATERIAL_LANZA
	if pieza_visual is MeshInstance3D:
		(pieza_visual as MeshInstance3D).visible = true
		if MATERIAL_LANZA:
			(pieza_visual as MeshInstance3D).material_override = MATERIAL_LANZA
	contenedor.add_child(pieza_visual)

	contenedor.iniciar_vuelo(
		Vector3(push_dir * randf_range(2.0, 3.6), randf_range(3.8, 5.6), 0.0),
		randf_range(-14.0, 14.0)
	)


func _on_state_dying() -> void:
	super._on_state_dying()
	_parry_activo = false
	_soltar_lanza_al_morir()
	_mostrar_lanza(false)
	_desvanecer_circulo_muerte()
	AudioManager.play_sfx("azulina_muerte")
	_aplicar_squash_stretch(0.0)

	# Muerte por explosión: reactiva física y aplica el impulso cinético lateral
	# igual que la arquera goblin
	if murio_por_explosion:
		_aplicar_impulso_explosivo()
		murio_por_explosion = false

	var anim_muerte := elegir_animacion_muerte()
	var duracion_muerte := _get_animation_duration(anim_muerte)
	_play_animation(anim_muerte)

	get_tree().create_timer(duracion_muerte + 0.5).timeout.connect(
		func():
			if is_instance_valid(self) and is_inside_tree():
				_die()
	)


## Existe la animación en el player (nombre directo o con prefijo Armature).
func _tiene_animacion(nombre_anim: String) -> bool:
	if anim_player == null:
		return false
	for variante in [nombre_anim, "Armature|" + nombre_anim, "Armature|Armature|" + nombre_anim]:
		if anim_player.has_animation(variante):
			return true
	return false


## Impulso de la explosión idéntico a la arquera goblin: reactiva la física del cuerpo
## y le da un salto hacia arriba con empuje lateral según el punto de explosión.
## La gravedad del EnemyBase dibuja la parábola mientras suena su animación de muerte normal.
func _aplicar_impulso_explosivo() -> void:
	_impulso_explosivo_activo = true
	set_physics_process(true)
	collision_layer = 0  ## Nadie colisiona contra el cadáver
	collision_mask = 1   ## Pero él sí colisiona contra el suelo para aterrizar

	# Dirección de expulsión según el punto de impacto de la explosión
	var push_dir: float = 1.0
	if last_hit_position != Vector3.ZERO:
		var dx: float = global_position.x - last_hit_position.x
		if absf(dx) > 0.05:
			push_dir = signf(dx)
	elif is_instance_valid(player_ref):
		var dx: float = global_position.x - (player_ref as Node3D).global_position.x
		if absf(dx) > 0.05:
			push_dir = signf(dx)

	velocity.x = push_dir * randf_range(1.6, 2.4)
	velocity.y = randf_range(2.0, 2.8)
	velocity.z = 0.0


func _aplicar_impulso_muerte() -> void:
	_aplicar_impulso_explosivo()


## Durante la muerte con impulso: conserva el empuje lateral en el aire y
## frena al aterrizar para que no patine; la gravedad la aplica el EnemyBase.
func _process_dying(delta: float) -> void:
	if not _impulso_explosivo_activo:
		velocity.x = 0
		return
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, delta * 8.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, delta * 0.8)


func take_damage(amount: float) -> void:
	var viva_antes: bool = health > 0
	super.take_damage(amount)
	if viva_antes and health > 0 and not _parry_activo and current_state != State.DYING and current_state != State.DEAD:
		if _tiene_animacion("Daño"):
			_tiempo_flinch = maxf(0.25, _get_animation_duration("Daño"))
			_play_animation("Daño")


# === PARRY DE LANZA ===
const MARGEN_GIRO_PARRY: float = 0.03  ## Ventana (s) para invertir el giro en los extremos
const HUESOS_PIERNAS: Array[String] = [  ## Cadera y piernas fijas en su postura: el giro queda en torso y brazos
	"mixamorig_Hips",
	"mixamorig_LeftUpLeg", "mixamorig_RightUpLeg",
	"mixamorig_LeftLeg", "mixamorig_RightLeg",
	"mixamorig_LeftFoot", "mixamorig_RightFoot",
	"mixamorig_LeftToeBase", "mixamorig_RightToeBase",
]
const RUTA_CIRCULO_PARRY: String = "res://TEST_/circulo protector lanza.png"

static var _tex_circulo_cache: Texture2D = null
static var _aviso_circulo_mostrado: bool = false


## Carga diferida del aro: si falta el PNG avisa una vez y el parry sigue sin aro.
static func _textura_circulo() -> Texture2D:
	if _tex_circulo_cache != null:
		return _tex_circulo_cache
	if ResourceLoader.exists(RUTA_CIRCULO_PARRY):
		_tex_circulo_cache = ResourceLoader.load(RUTA_CIRCULO_PARRY) as Texture2D
	if _tex_circulo_cache == null and not _aviso_circulo_mostrado:
		_aviso_circulo_mostrado = true
		push_warning("[Azulina] falta " + RUTA_CIRCULO_PARRY + ": reponer el PNG para ver el aro")
	return _tex_circulo_cache
const SHADER_DISOLUCION: Shader = preload("res://System/Shaders/dissolve.gdshader")
const COLOR_DISOLUCION_LANZA := Color(0.45, 0.85, 1.0)  ## Brillo celeste al reaparecer la lanza


## Hook del aura repelente (igual que Arquera Rosa): lo llaman los proyectiles al impactar.
## Devuelve true si el proyectil fue repelido (no hace daño).
func manejar_impacto_aura(flecha: Node) -> bool:
	if not parry_habilitado:
		return false
	if current_state == State.DYING or current_state == State.DEAD:
		return false
	if _parry_activo:
		AudioManager.play_sfx("parry")
		return true
	if _tiempo_enfriamiento > 0.0:
		return false
	if not is_inside_tree():
		return false
	var ahora: float = Time.get_ticks_msec() / 1000.0
	_impactos_recientes.append(ahora)
	while not _impactos_recientes.is_empty() and ahora - _impactos_recientes[0] > ventana_multidisparo:
		_impactos_recientes.pop_front()
	if _impactos_recientes.size() >= 2:
		_activar_parry()
		AudioManager.play_sfx("parry")
		return true
	_contador_ataques += 1
	if _contador_ataques >= _umbral_parry:
		_activar_parry()
		AudioManager.play_sfx("parry")
		return true
	return false


## Inicia el giro repelente de 3 segundos con la lanza visible.
func _activar_parry() -> void:
	_parry_activo = true
	_tiempo_parry = duracion_parry
	_contador_ataques = 0
	_impactos_recientes.clear()
	_umbral_parry = _sortear_umbral_parry()
	_mostrar_lanza(true)
	_mostrar_circulo(true)
	AudioManager.play_sfx("girar_lanza")
	_spawn_humo_parry()
	_capturar_pose_piernas()
	_iniciar_anim_parry()
	if forzar_parry_debug:
		_diag_parry()


## Avanza el parry y su enfriamiento; retorna true para congelar marcha y ataque mientras dura.
func _procesar_parry(delta: float) -> bool:
	if _tiempo_enfriamiento > 0.0:
		_tiempo_enfriamiento -= delta
	if not _parry_activo:
		return false
	_tiempo_parry -= delta
	velocity.x = 0
	if barrer_agarre_debug and is_instance_valid(_mano):
		_mano.rotate_x(velocidad_barrido * delta)
	if imprimir_agarre_debug and is_instance_valid(_mano):
		push_warning("[Azulina] agarre actual: " + str(_mano.transform))
	_alternar_giro_parry(delta)
	_congelar_piernas_parry()
	if _tiempo_parry <= 0.0:
		_desactivar_parry()
	return true


## Resuelve los huesos de las piernas una vez (tolera ambas variantes de nombre).
func _resolver_huesos_piernas() -> void:
	if is_instance_valid(_esqueleto) and not _huesos_piernas.is_empty():
		return
	_huesos_piernas.clear()
	_pose_piernas_fija.clear()
	var esqueletos := find_children("*", "Skeleton3D", true, false)
	if esqueletos.is_empty():
		return
	_esqueleto = esqueletos[0] as Skeleton3D
	if _esqueleto == null:
		return
	for nombre_hueso in HUESOS_PIERNAS:
		var idx: int = _esqueleto.find_bone(nombre_hueso)
		if idx < 0:
			idx = _esqueleto.find_bone(nombre_hueso.replace("_", ":"))
		if idx >= 0:
			_huesos_piernas.append(idx)
			_pose_piernas_fija.append(Quaternion.IDENTITY)


## Guarda la postura actual de piernas para mantenerla durante todo el giro.
func _capturar_pose_piernas() -> void:
	_resolver_huesos_piernas()
	if _esqueleto == null or not is_instance_valid(_esqueleto):
		return
	for i in range(_huesos_piernas.size()):
		_pose_piernas_fija[i] = _esqueleto.get_bone_pose_rotation(_huesos_piernas[i])


## Fija las piernas tras la animación (diferido al final del cuadro para imponerse).
func _congelar_piernas_parry() -> void:
	if _esqueleto == null or not is_instance_valid(_esqueleto):
		return
	if _huesos_piernas.is_empty():
		return
	call_deferred("_aplicar_piernas_estaticas")


func _aplicar_piernas_estaticas() -> void:
	if not _parry_activo or _esqueleto == null or not is_instance_valid(_esqueleto):
		return
	for i in range(_huesos_piernas.size()):
		_esqueleto.set_bone_pose_rotation(_huesos_piernas[i], _pose_piernas_fija[i])


## Termina el giro, oculta la lanza, abre la ventana vulnerable y retoma el ciclo de combate.
func _desactivar_parry() -> void:
	_parry_activo = false
	_tiempo_enfriamiento = enfriamiento_parry
	_mostrar_lanza(false)
	_mostrar_circulo(false)
	if anim_player != null:
		anim_player.speed_scale = _velocidad_previa_parry
	if current_state == State.DYING or current_state == State.DEAD:
		return
	if _lanzando:
		_play_animation("Ataque", fundido_transiciones)
	elif current_state == State.SHOOTING:
		_play_animation(animacion_quieta, fundido_transiciones)
	else:
		_play_animation("Correr", fundido_transiciones)


func _sortear_umbral_parry() -> int:
	var minimo: int = maxi(1, ataques_para_parry_min)
	var maximo: int = maxi(minimo, ataques_para_parry_max)
	return randi_range(minimo, maximo)


## Fija el attachment al hueso de la mano por NOMBRE (el índice grabado queda obsoleto si se reimporta).
func _resolver_hueso_mano() -> void:
	var attach := find_child("BoneAttachment3D", true, false) as BoneAttachment3D
	if attach == null:
		_mano = find_child("LanzaMano", true, false) as Node3D
		return
	_mano = attach
	var skel := attach.get_parent() as Skeleton3D
	if skel == null:
		return
	var idx: int = skel.find_bone("mixamorig_RightHand")
	if idx < 0:
		idx = skel.find_bone("mixamorig:RightHand")
	if idx < 0:
		push_warning("[Azulina] hueso de mano no encontrado en el esqueleto")
		return
	if attach.bone_idx != idx:
		attach.bone_idx = idx


## Crea el aro protector (billboard) que gira durante el parry para reforzar el giro.
## Crea el aro protector animado cuadro por cuadro (grilla 3x3 de la hoja).
## Todos los cuadros comparten caja común centrada para reemplazo en el mismo lugar.
func _crear_circulo_parry() -> void:
	if is_instance_valid(_circulo):
		return
	var aro := AnimatedSprite3D.new()
	aro.name = "CirculoParry"
	aro.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	aro.shaded = false
	aro.position = offset_circulo
	aro.visible = false
	add_child(aro)
	_circulo = aro
	var luz := OmniLight3D.new()
	luz.name = "LuzCirculo"
	luz.light_color = Color(0.45, 0.85, 1.0)
	luz.light_energy = brillo_circulo
	luz.omni_range = 2.5
	luz.omni_attenuation = 1.2
	luz.shadow_enabled = false
	luz.visible = false
	aro.add_child(luz)
	_luz_circulo = luz
	_construir_frames_circulo()
	_aplicar_tamano_circulo()


## Recorta los 9 aros de la hoja en una animación con caja común de 225x214.
## Si falta el PNG avisa una vez y deja el aro sin cuadros (el parry sigue sin aro).
func _construir_frames_circulo() -> void:
	if not is_instance_valid(_circulo):
		return
	var tira := _textura_circulo()
	if tira == null:
		return
	var sf := SpriteFrames.new()
	if not sf.has_animation(&"giro"):
		sf.add_animation(&"giro")
	sf.set_animation_loop(&"giro", true)
	sf.set_animation_speed(&"giro", fps_circulo)
	var celdas: Array[Rect2i] = [
		Rect2i(1, 0, 225, 191), Rect2i(248, 0, 201, 191), Rect2i(463, 0, 206, 191),
		Rect2i(1, 209, 225, 214), Rect2i(248, 209, 201, 214), Rect2i(463, 209, 206, 214),
		Rect2i(1, 453, 225, 205), Rect2i(248, 453, 201, 205), Rect2i(463, 453, 206, 205),
	]
	for celda in celdas:
		var atlas := AtlasTexture.new()
		atlas.atlas = tira
		atlas.region = Rect2(Vector2(celda.position), Vector2(celda.size))
		atlas.margin = Rect2(
			Vector2((225.0 - float(celda.size.x)) * 0.5, (214.0 - float(celda.size.y)) * 0.5),
			Vector2(225.0, 214.0)
		)
		sf.add_frame(&"giro", atlas)
	_circulo.sprite_frames = sf


func _aplicar_tamano_circulo() -> void:
	if not is_instance_valid(_circulo):
		return
	_circulo.pixel_size = maxf(0.5, tamano_circulo) / 225.0


## La lanza vuelve a la mano en idle con disolución celeste (efecto de muerte invertido).
func _reaparecer_lanza() -> void:
	_lanza_arrojada = false
	if not is_instance_valid(_mano):
		_mano = find_child("LanzaMano", true, false) as Node3D
	if not is_instance_valid(_mano):
		return
	(_mano as Node3D).visible = true
	var mallas: Array[MeshInstance3D] = []
	if _mano is MeshInstance3D:
		mallas.append(_mano as MeshInstance3D)
	for m in _mano.find_children("*", "MeshInstance3D", true, false):
		mallas.append(m as MeshInstance3D)
	if mallas.is_empty():
		return
	for mi in mallas:
		var mat := ShaderMaterial.new()
		mat.shader = SHADER_DISOLUCION
		mat.set_shader_parameter("dissolve_amount", 1.0)
		mat.set_shader_parameter("glow_color", COLOR_DISOLUCION_LANZA)
		mi.material_override = mat
	var tween := create_tween()
	tween.tween_method(_actualizar_disolucion_lanza.bind(mallas), 1.0, 0.0, maxf(0.1, duracion_reaparicion_lanza))
	tween.tween_callback(_restaurar_material_lanza.bind(mallas))


func _actualizar_disolucion_lanza(valor: float, mallas: Array) -> void:
	for mi in mallas:
		if is_instance_valid(mi) and (mi as MeshInstance3D).material_override is ShaderMaterial:
			((mi as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("dissolve_amount", valor)


func _restaurar_material_lanza(mallas: Array) -> void:
	for mi in mallas:
		if is_instance_valid(mi):
			(mi as MeshInstance3D).material_override = MATERIAL_LANZA


## Al morir, el aro se deshace como la muerte enemiga: humo celeste + fundido.
func _desvanecer_circulo_muerte() -> void:
	if not is_instance_valid(_circulo) or not _circulo.visible:
		return
	_spawn_humo_celeste(_circulo.global_position)
	if is_instance_valid(_luz_circulo):
		_luz_circulo.visible = false
	var tween := create_tween()
	tween.tween_property(_circulo, "modulate:a", 0.0, 0.5)
	tween.tween_callback(_ocultar_circulo_muerte)


func _ocultar_circulo_muerte() -> void:
	if is_instance_valid(_circulo):
		_circulo.stop()
		_circulo.visible = false


func _mostrar_circulo(visible: bool) -> void:
	if not is_instance_valid(_circulo):
		_crear_circulo_parry()
	if not is_instance_valid(_circulo):
		return
	if not circulo_parry:
		_circulo.visible = false
		_circulo.stop()
		if is_instance_valid(_luz_circulo):
			_luz_circulo.visible = false
		return
	_circulo.visible = visible
	if is_instance_valid(_luz_circulo):
		_luz_circulo.visible = visible
		_luz_circulo.light_energy = brillo_circulo
	if not visible:
		_circulo.stop()
		return
	if _circulo.sprite_frames == null or not _circulo.sprite_frames.has_animation(&"giro"):
		_circulo.visible = false
		return
	_circulo.modulate = Color(1.0, 1.0, 1.0, clampf(opacidad_circulo, 0.1, 1.0))
	_circulo.frame = 0
	_circulo.play(&"giro")


func _mostrar_lanza(visible: bool) -> void:
	if not is_instance_valid(_mano):
		_mano = find_child("LanzaMano", true, false) as Node3D
	if not is_instance_valid(_mano):
		return
	if visible:
		if _escala_lanza_base == Vector3.ZERO:
			_escala_lanza_base = _mano.scale
		_mano.scale = Vector3.ONE * escala_lanza_parry
	else:
		if _escala_lanza_base != Vector3.ZERO:
			_mano.scale = _escala_lanza_base
	_mano.visible = visible


## Diagnóstico del parry forzado: imprime dónde quedó la lanza y con qué mallas.
func _diag_parry() -> void:
	if not is_instance_valid(_mano):
		push_warning("[Azulina] diag parry: LanzaMano NO encontrada")
		return
	var detalle: Array[String] = []
	for m in _mano.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		detalle.append(str(mi.name) + " vis=" + str(mi.visible) + " mat=" + str(mi.material_override != null))
	if _mano is MeshInstance3D:
		detalle.append("SELF vis=" + str((_mano as MeshInstance3D).visible))
	var info_hueso := "sin_attachment"
	var attach := find_child("BoneAttachment3D", true, false) as BoneAttachment3D
	if attach == null and is_instance_valid(_mano):
		attach = _mano.get_parent() as BoneAttachment3D
	if attach != null:
		var skel := attach.get_parent() as Skeleton3D
		var idx_nombre: int = -1
		if skel != null:
			idx_nombre = skel.find_bone("mixamorig_RightHand")
			if idx_nombre < 0:
				idx_nombre = skel.find_bone("mixamorig:RightHand")
		info_hueso = "attach_idx=" + str(attach.bone_idx) + " nombre_idx=" + str(idx_nombre)
	push_warning("[Azulina] diag parry: mano_global=" + str((_mano as Node3D).global_position) + " visible=" + str(_mano.visible) + " escala=" + str(_mano.scale) + " cuerpo_global=" + str(global_position) + " " + info_hueso + " mallas=[" + ", ".join(detalle) + "]")
	push_warning("[Azulina] diag parry: huesos_piernas=" + str(_huesos_piernas.size()) + " de " + str(HUESOS_PIERNAS.size()))
	push_warning("[Azulina] diag parry: circulo=" + str(is_instance_valid(_circulo)) + " visible=" + str(_circulo.visible if is_instance_valid(_circulo) else false) + " pos=" + str(_circulo.position if is_instance_valid(_circulo) else Vector3.ZERO))


## El giro es una revolución completa: se duplica en loop lineal fluido hacia adelante.
func _iniciar_anim_parry() -> void:
	if anim_player == null:
		return
	var original: String = ""
	for nombre: String in anim_player.get_animation_list():
		if nombre == animacion_parry:
			original = nombre
			break
	if original.is_empty():
		for nombre: String in anim_player.get_animation_list():
			if nombre.contains(animacion_parry):
				original = nombre
				break
	if original.is_empty():
		push_warning("[Azulina] animación de parry no encontrada: " + animacion_parry)
		return
	_anim_parry_loop = original.replace(" ", "").replace("|", "") + "ParryLoop"
	if not anim_player.has_animation(_anim_parry_loop):
		var giro := anim_player.get_animation(original).duplicate() as Animation
		giro.loop_mode = Animation.LOOP_NONE
		_agregar_animacion(anim_player, _anim_parry_loop, giro)
	_velocidad_previa_parry = anim_player.speed_scale
	anim_player.speed_scale = velocidad_parry
	_giro_hacia_atras = false
	_tiempo_hold_parry = 0.0
	anim_player.play(_anim_parry_loop, fundido_ataque)


## Alterna el giro normal e invertido en los extremos para un ciclo continuo.
## Al llegar al cuadro final lo congela duracion_hold_parry antes de invertir.
func _alternar_giro_parry(delta: float) -> void:
	if anim_player == null or _anim_parry_loop.is_empty():
		return
	if anim_player.current_animation != _anim_parry_loop:
		return
	if _tiempo_hold_parry > 0.0:
		_tiempo_hold_parry -= delta
		if _tiempo_hold_parry <= 0.0:
			_giro_hacia_atras = true
			anim_player.play_backwards(_anim_parry_loop)
		return
	if not anim_player.is_playing():
		return
	var anim := anim_player.get_animation(_anim_parry_loop)
	if anim == null or anim.length <= MARGEN_GIRO_PARRY:
		return
	if not anim_player.is_playing():
		return
	var pos: float = anim_player.current_animation_position
	if not _giro_hacia_atras and pos >= anim.length - MARGEN_GIRO_PARRY:
		anim_player.pause()
		_tiempo_hold_parry = duracion_hold_parry
		return
	elif _giro_hacia_atras and pos <= MARGEN_GIRO_PARRY:
		_giro_hacia_atras = false
		anim_player.play(_anim_parry_loop)


## En Godot 4 las animaciones viven en AnimationLibrary (igual que AzulinaPosando).
func _agregar_animacion(player: AnimationPlayer, nombre: String, anim: Animation) -> void:
	var listas: PackedStringArray = player.get_animation_library_list()
	var libreria: String = ""
	if listas.has(""):
		libreria = ""
	elif listas.size() > 0:
		libreria = listas[0]
	player.get_animation_library(libreria).add_animation(nombre, anim)


# === FUNCIONES PÚBLICAS ===
## Inicia la emergencia desde el agua hacia la posición actual.
## El origen queda bajo el punto de caída (en el agua), el ápice
## se alcanza a mitad del salto y la caída es el destino en el terreno.
func emerger_en(destino: Vector3) -> void:
	var punto_caida := destino
	if emergencia_en_zona_aleatoria:
		var centro := zona_centro if usar_centro_zona_personalizado else destino
		punto_caida = Vector3(
			centro.x + randf_range(-zona_extension.x, zona_extension.x),
			centro.y,
			centro.z + randf_range(-zona_extension.z, zona_extension.z)
		)
	if aterrizar_en_centro:
		punto_caida.x = centro_aterrizaje_x
	_destino_emergencia = punto_caida
	_origen_emergencia = punto_caida + Vector3(alcance_emergencia_x, -hundimiento_emergencia, deriva_fondo_z)
	global_position = _origen_emergencia
	_tiempo_emergencia = 0.0
	_emergiendo = true
	_lanzo_en_emergencia = false
	_memoria_squash = 0.0
	velocity = Vector3.ZERO
	_spawnear_salpicadura()
	if anim_player != null:
		_velocidad_salto_base = anim_player.speed_scale
	_play_animation(ANIM_SALTO_AGUA, fundido_ataque)


## Elige al azar una de las animaciones de muerte configuradas.
func elegir_animacion_muerte() -> String:
	if animaciones_muerte.is_empty():
		return "Muerte 1"
	return animaciones_muerte[randi() % animaciones_muerte.size()]


## Genera el splash donde rompe el agua al emerger (igual que Fuego2D es
## la versión productiva de su escena de pruebas).
func _spawnear_salpicadura() -> void:
	if not salpicadura_al_emerger:
		return
	if not is_inside_tree() or get_tree() == null:
		return
	var sal := ESCENA_SALPICADURA.instantiate() as SalpicaduraAgua
	if sal == null:
		return
	var raiz: Node = get_tree().current_scene
	if raiz == null:
		raiz = get_tree().root
	raiz.add_child(sal)
	# Punto de rotura: XZ del origen sumergido adelantado a camara, Y apenas bajo la orilla.
	var punto_rotura := Vector3(
		_origen_emergencia.x + desplazamiento_lateral_salpicadura,
		_destino_emergencia.y - profundidad_rotura,
		_origen_emergencia.z + adelanto_camara_salpicadura
	)
	sal.disparar_impacto(punto_rotura, false)


## Punto más alto del salto: mitad del recorrido + altura del arco.
func calcular_apice_salto() -> Vector3:
	var apice: Vector3 = _origen_emergencia.lerp(_destino_emergencia, 0.5)
	apice.y += sin(0.5 * PI) * altura_salto
	return apice


# === FUNCIONES PRIVADAS ===
func _iniciar_emergencia() -> void:
	emerger_en(global_position)


func _procesar_emergencia(delta: float) -> void:
	velocity = Vector3.ZERO
	_tiempo_emergencia += delta
	var avance: float = clampf(_tiempo_emergencia / maxf(duracion_emergencia, 0.01), 0.0, 1.0)
	var pos: Vector3 = _origen_emergencia.lerp(_destino_emergencia, avance)
	pos.y += sin(avance * PI) * altura_salto
	global_position = pos
	_aplicar_envolvente_salto(avance)
	_acelerar_tramo_final(avance)
	if not _lanzo_en_emergencia and avance >= momento_disparo_emergencia:
		_lanzo_en_emergencia = true
		_lanzar_lanza()
	if avance >= 1.0:
		_emergiendo = false
		global_position = _destino_emergencia
		_memoria_squash = -1.0
		_aplicar_squash_stretch(_memoria_squash)
		if anim_player != null:
			anim_player.speed_scale = _velocidad_salto_base
		VFXFactory.spawn_shield_break_smoke(self, _destino_emergencia)
		emergencia_completada.emit()
		_al_aterrizar()


## Envolvente del salto: estira al despegar (+1), relaja en el ápice (0)
## y aplasta al tocar suelo (-1). Con entrada suavizada para no arrancar de golpe.
func _aplicar_envolvente_salto(avance: float) -> void:
	if not squash_stretch:
		return
	var entrada: float = clampf(avance / 0.08, 0.0, 1.0)
	_aplicar_squash_stretch(cos(avance * PI) * entrada)


## Acelera la animación en el tramo final del salto para un aterrizaje con impacto.
## No toca el parry: si está girando, su velocidad manda.
func _acelerar_tramo_final(avance: float) -> void:
	if not acelerar_tramo_final or anim_player == null:
		return
	if _parry_activo:
		return
	if avance >= inicio_tramo_final:
		anim_player.speed_scale = _velocidad_salto_base * velocidad_tramo_final
	else:
		anim_player.speed_scale = _velocidad_salto_base


## Aplica la deformación conservando volumen (lo que crece en Y encoge en XZ).
func _aplicar_squash_stretch(k: float) -> void:
	if _modelo == null:
		return
	var deformacion: float = intensidad_squash * k if squash_stretch else 0.0
	var escala_y: float = 1.0 + deformacion
	var escala_xz: float = 1.0 - deformacion * 0.5
	_modelo.scale = Vector3(_escala_modelo_base * escala_xz, _escala_modelo_base * escala_y, _escala_modelo_base * escala_xz)


## Tras aterrizar, la deformación remanente decae a la forma base.
func _recuperar_squash(delta: float) -> void:
	if _memoria_squash == 0.0:
		return
	_memoria_squash = move_toward(_memoria_squash, 0.0, delta / maxf(duracion_recuperacion_squash, 0.01))
	_aplicar_squash_stretch(_memoria_squash)


## Al caer al terreno (punto 2): dispara la lanza de inmediato o retoma la marcha.
func _al_aterrizar() -> void:
	if current_state == State.DYING or current_state == State.DEAD:
		return
	if disparar_al_aterrizar:
		_change_state(State.SHOOTING)
		_iniciar_ataque()
	else:
		_play_animation("Correr", fundido_transiciones)


func _iniciar_ataque() -> void:
	_lanzando = true
	_lanzo_proyectil = false
	_timer_lanzamiento = 0.0
	_play_animation("Ataque", fundido_ataque)


func _duracion_anim_ataque() -> float:
	return _get_animation_duration("Ataque")


func _lanzar_lanza() -> void:
	if _parry_activo:
		return
	var objetivo: Node3D = player_ref as Node3D
	if not is_instance_valid(objetivo):
		objetivo = get_tree().get_first_node_in_group("player") as Node3D
	var origen: Vector3 = global_position + Vector3(-0.2, 0.5, 0.0)  ## Mano de una Azulina de ~0.9 m
	var direccion := Vector3.LEFT
	if is_instance_valid(objetivo):
		direccion = ((objetivo.global_position + Vector3(0.0, 0.8, 0.0)) - origen).normalized()
	direccion = direccion.rotated(Vector3.UP, randf_range(-dispersion_rad, dispersion_rad))
	var lanza := ESCENA_LANZA.instantiate() as LanzaAzulinaProjectile
	if lanza == null:
		return
	_lanza_arrojada = true
	if not _parry_activo and is_instance_valid(_mano):
		(_mano as Node3D).visible = false
	var raiz: Node = get_tree().current_scene
	if raiz == null:
		raiz = get_tree().root
	raiz.add_child(lanza)
	lanza.global_position = origen
	lanza.initialize(direccion, 1.0)
	lanza.velocidad = velocidad_lanza
	lanza.gravedad = gravedad_lanza
	AudioManager.play_sfx("trident_shot")


func _aplicar_material_azulina() -> void:
	if MATERIAL_AZULINA:
		for m in find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if mi and mi.find_parent("LanzaMano") == null:
				mi.material_override = MATERIAL_AZULINA
	if MATERIAL_LANZA:
		var mano := find_child("LanzaMano", true, false)
		if mano:
			var candidatos: Array[Node] = [mano]
			candidatos.append_array(mano.find_children("*", "MeshInstance3D", true, false))
			for m in candidatos:
				if m is MeshInstance3D:
					(m as MeshInstance3D).material_override = MATERIAL_LANZA


func _forzar_loop_movimiento() -> void:
	if anim_player == null:
		return
	var en_bucle: Array[String] = ["Correr", "Correr agachado", "Nadar"]
	if not en_bucle.has(animacion_quieta):
		en_bucle.append(animacion_quieta)
	for nombre_anim in en_bucle:
		for variante in [nombre_anim, "Armature|" + nombre_anim]:
			if anim_player.has_animation(variante):
				anim_player.get_animation(variante).loop_mode = Animation.LOOP_LINEAR
