class_name HachaPerrenaProjectile
extends Area3D

## Proyectil de hacha arrojadiza rotatoria utilizado por la Defensora Perrena.
## - Física parabólica con gravedad balística estándar.
## - Detección CCD mediante RayCast para evitar tunneling a alta velocidad.
## - Daño base de 2.0 y bono de daño contra escudos/guardianes de +3.0 (Total 5.0).
## - Ataque especial (Ult): escala 2.0x, 100% de acierto guiado hacia el objetivo fijado,
##   daño base 3.0 + bono de 6.0 contra escudos/guardianes (Total 9.0),
##   activa efectos de flecha explosiva (murio_por_explosion) y levanta rocas en terreno.
## - REGLA OBLIGATORIA: El ult del hacha gigante NO puede parrearse ni desviarse
##   (se comporta como una flecha explosiva: penetra defensas, auras y parries).

signal impactado(objetivo: Node)

const DANO_BASE: float = 2.0
const BONO_ESCUDOS_Y_PILAR: float = 3.0
const DANO_BASE_ESPECIAL: float = 3.0
const BONO_ESPECIAL: float = 6.0
const VELOCIDAD_GIRO: float = 16.0  ## rad/s de giro del hacha
const VELOCIDAD_INICIAL_ESPECIAL: float = 26.0  ## Mayor velocidad y potencia para el ataque especial
const MAT_HACHA: Material = preload("res://Entities/Proyectil_Hacha_Perrena/HACHA_PERRENA_MAT.tres")
const SFX_IMPACTO: String = "res://Entities/Ambiente_Escudo/IMPACTO_ESCUDO_BALLESTA.mp3"
const SFX_IMPACTO_ESPECIAL: String = "res://TEST_/Hacha impacto ult.mp3"  ## Impacto del Ult
const SFX_REVENTADO_ULT: String = "res://TEST_/Sonido reventado.mp3"  ## Suena cuando el Ult mata a un enemigo
const SFX_FALLO_TIERRA_ULT: String = "res://TEST_/impacto fallo tierra.mp3"  ## El Ult falló: impactó en terreno o en el pilar de Lonko
const TEXTURA_ROCAS: Texture2D = preload("res://Entities/Enemigo_Lonko/ROCAS.png")  ## Mismo atlas del emerger del pilar de Lonko (4 rocas)

## Offset angular del filo: en el modelo local el filo se sitúa a +73.35° respecto al origen.
## Restar este ángulo orienta el filo exactamente hacia la dirección de vuelo.
const ANGULO_FILO_OFFSET_RAD: float = deg_to_rad(73.35)


@export_category("Fisica")
@export var velocidad_inicial: float = 12.0
@export var gravedad_escala: float = 1.0
@export var tiempo_vida_max: float = 6.0
@export var tiempo_pegada: float = 3.0  ## Tiempo que permanece clavada tras impactar antes de desvanecerse
@export var gracia_plataformas_metros: float = 1.5  ## Las plataformas aliadas solo se atraviesan cerca del lanzamiento (cobertura propia)

@export_category("Ataque Especial")
@export var es_hacha_especial: bool = false
@export var es_explosiva: bool = false  ## Compatible con lógica de flecha explosiva (no puede parrearse ni desviarse)
var objetivo_fijado = null

@export_category("Estela Fantasma (Ult)")
@export var estela_ult_activa: bool = true  ## Rastro morado sutil del hacha gigante, como la espada pirata
@export var intervalo_estela: float = 0.05  ## Segundos entre fantasmas
@export var vida_estela: float = 0.35  ## Duración del desvanecido de cada fantasma
@export var color_estela: Color = Color(0.6, 0.2, 1.0, 0.3)  ## Morado transparente y sutil

var velocity: Vector3 = Vector3.ZERO
var tirador: Node = null
var is_stuck: bool = false
var _gravity: float = 9.8
var _impacto_procesado: bool = false
var _desvaneciendose: bool = false
var _modelo_hacha: Node3D = null
var _ray_ccd: RayCast3D = null
var _vida_acumulada: float = 0.0
var _tiempo_estela: float = 0.0
var _distancia_recorrida: float = 0.0  ## Metros volados desde el lanzamiento (gracia de plataformas)
var _y_previa_agua: float = 9999.0  ## Y del paso anterior para detectar entrada al agua
var _agua_rect: Dictionary = {}  ## Rectángulo del plano de agua cacheado (vacío = sin agua)


func _ready() -> void:
	_gravity = ProjectSettings.get_setting("physics/3d/default_gravity") * gravedad_escala
	_modelo_hacha = find_child("HachaModel", true, false) as Node3D
	_aplicar_material()

	# Configuración de colisión: detecta enemigos (capa 3/4), escudos (capa 1/2) y entorno (capa 1).
	# Excluida capa 7 (bit 64) y capa 10 (bit 512, BarreraLimite) para no colisionar en el aire
	collision_layer = 0
	collision_mask = 1 | 2 | 4 | 8 | 16 | 32

	# Anti-tunneling con RayCast
	_ray_ccd = RayCast3D.new()
	_ray_ccd.name = "RayCastCCD"
	_ray_ccd.enabled = true
	_ray_ccd.collision_mask = collision_mask
	_ray_ccd.collide_with_areas = true
	_ray_ccd.collide_with_bodies = true
	_ray_ccd.exclude_parent = true
	add_child(_ray_ccd)

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


## NOTA: `p_objetivo` va sin tipar a propósito: puede llegar ya liberado
## (el blanco muere antes del impacto) y un `Node` tipado rompería en el
## binding; el guard de homing con is_instance_valid lo filtra.
func initialize(
	direccion_disparo: Vector3,
	potencia: float = 1.0,
	p_tirador: Node = null,
	p_es_especial: bool = false,
	p_objetivo = null
) -> void:
	tirador = p_tirador
	es_hacha_especial = p_es_especial
	es_explosiva = p_es_especial
	if p_es_especial:
		set_meta("es_explosiva", true)
	objetivo_fijado = p_objetivo
	_impacto_procesado = false
	is_stuck = false
	_distancia_recorrida = 0.0
	_tiempo_estela = 0.0

	var dir_norm := direccion_disparo.normalized()
	if es_hacha_especial:
		# Hacha de mayor tamaño (escala 2.0x), sin brillos ni partículas doradas
		scale = Vector3(2.0, 2.0, 2.0)
		velocity = dir_norm * (VELOCIDAD_INICIAL_ESPECIAL * maxf(0.5, potencia))
	else:
		velocity = dir_norm * (velocidad_inicial * maxf(0.1, potencia))


## Resuelve la entidad principal dueña en caso de colisionar con hitboxes o áreas hijas
func _resolver_entidad_objetivo(node: Node) -> Node:
	var curr: Node = node
	while curr and curr != get_tree().root:
		if curr is ImpShieldGirl or curr is GuardianaMoradita or curr is Lonko or curr is PilarLonkoBody:
			return curr
		if curr is EscudoPesadoArea:
			return curr
		if curr is SubmarinoRio or curr.is_in_group("submarinos") or curr.is_in_group("submarino") or curr.is_in_group("jefe_submarino"):
			return curr
		if curr.is_in_group("enemies") or curr.is_in_group("escudos") or curr.is_in_group("guardians") or curr.is_in_group("guardianes") or curr.is_in_group("shield_imps"):
			return curr
		curr = curr.get_parent()
	return node


## Comprueba si el objetivo califica como escudo, pilar o clase Guardián para el bono de daño
func _es_escudo_o_guardian(node: Node) -> bool:
	if not node or not is_instance_valid(node):
		return false

	# 1. Clase Guardián explícita (Imp con escudo, Guardiana Moradita)
	if node is ImpShieldGirl or node is GuardianaMoradita:
		return true

	# 2. Grupos de escudos o guardianes
	if node.is_in_group("escudos") or node.is_in_group("shield_imps") or node.is_in_group("guardians") or node.is_in_group("guardianes"):
		return true

	# 3. Propiedades y metadatos de escudos / pilares enemigos
	if ("es_escudo_enemigo" in node and node.es_escudo_enemigo) or (node.has_meta("es_escudo_enemigo") and node.get_meta("es_escudo_enemigo")):
		return true
	if node.get("es_escudo_enemigo") == true:
		return true
	if ("es_pilar_enemigo" in node and node.es_pilar_enemigo) or (node.has_meta("es_pilar_enemigo") and node.get_meta("es_pilar_enemigo")):
		return true
	if node.get("es_pilar_enemigo") == true or node is PilarLonkoBody:
		return true

	var n_lower: String = node.name.to_lower()
	if "escudo" in n_lower or "pilar" in n_lower:
		return true

	return false


## Calcula el daño exacto según el tipo de objetivo
func calcular_dano_para(target: Node) -> float:
	var dano_base: float = 3.0 if es_hacha_especial else 2.0
	var bono: float = 6.0 if es_hacha_especial else 3.0

	if _es_escudo_o_guardian(target):
		return dano_base + bono

	return dano_base


func _physics_process(delta: float) -> void:
	if is_stuck or _impacto_procesado:
		return

	_vida_acumulada += delta
	if _vida_acumulada >= tiempo_vida_max:
		queue_free()
		return

	# Si es hacha especial y tiene objetivo fijado válido, corregir trayectoria para asegurar 100% de acierto
	if es_hacha_especial and is_instance_valid(objetivo_fijado) and not objetivo_fijado.is_queued_for_deletion() and objetivo_fijado is Node3D:
		var target_node := objetivo_fijado as Node3D
		var target_pos := target_node.global_position + Vector3(0.0, 0.4, 0.0)
		var to_target := target_pos - global_position
		var dist := to_target.length()

		if dist > 0.05:
			var dir_deseada := to_target.normalized()
			var current_speed: float = maxf(velocity.length(), VELOCIDAD_INICIAL_ESPECIAL)
			# Guiado progresivo hacia el blanco
			velocity = velocity.lerp(dir_deseada * current_speed, clampf(delta * 14.0, 0.0, 1.0)).normalized() * current_speed

		# Si estamos a quemarropa del objetivo, impactar directamente
		if dist <= 0.65:
			_procesar_impacto(target_node, target_pos, -velocity.normalized())
			return
	else:
		# Aplicar gravedad balística estándar
		velocity.y -= _gravity * delta

	var paso: Vector3 = velocity * delta

	# Comprobación CCD antes de mover
	if _ray_ccd:
		_ray_ccd.target_position = to_local(global_position + paso)
		_ray_ccd.force_raycast_update()
		if _ray_ccd.is_colliding():
			var col_obj: Object = _ray_ccd.get_collider()
			var col_point: Vector3 = _ray_ccd.get_collision_point()
			var col_normal: Vector3 = _ray_ccd.get_collision_normal()
			if col_obj is Node:
				_procesar_impacto(col_obj as Node, col_point, col_normal)
				if _impacto_procesado:
					return

	global_position += paso
	_distancia_recorrida += paso.length()
	_y_previa_agua = global_position.y - paso.y
	_chequear_entrada_agua()

	# Giro del hacha en el aire
	var vel_giro: float = VELOCIDAD_GIRO * (1.5 if es_hacha_especial else 1.0)
	if _modelo_hacha and is_instance_valid(_modelo_hacha):
		_modelo_hacha.rotate_z(-vel_giro * delta)
	_actualizar_estela(delta)


## Solo el hacha gigante del ult deja fantasmas morados con su silueta exacta.
func _actualizar_estela(delta: float) -> void:
	if not estela_ult_activa or not es_hacha_especial:
		return
	if is_stuck or _impacto_procesado:
		return
	if not is_inside_tree() or get_tree() == null:
		return
	_tiempo_estela += delta
	if _tiempo_estela < intervalo_estela:
		return
	_tiempo_estela = 0.0
	_generar_fantasma_estela()


func _generar_fantasma_estela() -> void:
	var raiz: Node = _modelo_hacha if is_instance_valid(_modelo_hacha) else self
	var padre: Node = get_parent()
	if padre == null:
		return
	for m in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var fantasma := mi.duplicate() as MeshInstance3D
		fantasma.name = "EstelaHacha"
		fantasma.add_to_group("estela_hacha")
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = color_estela
		fantasma.material_override = mat
		fantasma.set_surface_override_material(0, null)
		padre.add_child(fantasma)
		fantasma.global_transform = mi.global_transform
		_desvanecer_fantasma(fantasma, mat)


func _desvanecer_fantasma(fantasma: MeshInstance3D, mat: StandardMaterial3D) -> void:
	var tw := fantasma.create_tween()
	tw.tween_method(
		func(alfa: float):
			if is_instance_valid(mat):
				var c := mat.albedo_color
				c.a = alfa
				mat.albedo_color = c
	, color_estela.a, 0.0, maxf(vida_estela, 0.05))
	tw.tween_callback(fantasma.queue_free)


## Si cae al agua (fosos entre islas): flota en superficie hasta desvanecerse
func _chequear_entrada_agua() -> void:
	if velocity.y >= -1.0:
		return
	_rect_agua_lazy()
	if _agua_rect.is_empty() or _agua_rect.has("vacio") or not _agua_rect.has("minx"):
		return
	var p := global_position
	if p.x < float(_agua_rect["minx"]) or p.x > float(_agua_rect["maxx"]):
		return
	if p.z < float(_agua_rect["minz"]) or p.z > float(_agua_rect["maxz"]):
		return
	var sup_y := float(_agua_rect["y"])
	if _y_previa_agua > sup_y and p.y <= sup_y:
		_flotar_en_agua(sup_y)


## Flota sobre el agua como un impacto: se queda hasta desvanecerse.
func _flotar_en_agua(sup_y: float) -> void:
	_impacto_procesado = true
	is_stuck = true
	velocity = Vector3.ZERO
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if _ray_ccd:
		_ray_ccd.enabled = false
	global_position.y = sup_y + 0.03
	if get_tree():
		get_tree().create_timer(tiempo_pegada).timeout.connect(
			func():
				if is_instance_valid(self) and is_inside_tree():
					_desvanecer_y_liberar()
		)


## Busca el plano de agua (grupo "agua") una sola vez y cachea su rectángulo.
func _rect_agua_lazy() -> void:
	if not _agua_rect.is_empty() or get_tree() == null:
		return
	_agua_rect["vacio"] = true
	_y_previa_agua = global_position.y
	var minx := INF
	var maxx := -INF
	var minz := INF
	var maxz := -INF
	var supy := 0.0
	var hay := false
	for nodo in get_tree().get_nodes_in_group("agua"):
		if not (nodo is Node3D):
			continue
		supy = (nodo as Node3D).global_position.y
		for m in (nodo as Node).find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if mi == null or mi.mesh == null:
				continue
			var a: AABB = mi.global_transform * mi.mesh.get_aabb()
			minx = minf(minx, a.position.x)
			maxx = maxf(maxx, a.position.x + a.size.x)
			minz = minf(minz, a.position.z)
			maxz = maxf(maxz, a.position.z + a.size.z)
			hay = true
	if hay:
		_agua_rect = {"minx": minx, "maxx": maxx, "minz": minz, "maxz": maxz, "y": supy}


func _es_entidad_a_ignorar(target: Node) -> bool:
	if not target or not is_instance_valid(target):
		return true

	# Ignorar al tirador propio
	if tirador and (target == tirador or target.is_ancestor_of(tirador) or tirador.is_ancestor_of(target)):
		return true

	# Fuego amigo imposible: el hacha solo la lanza Perrena defensora
	# (aliada). Jamás daña a la jugadora ni a las aliadas: las atraviesa.
	if target.is_in_group("player") or target.is_in_group("allies"):
		return true

	# Ignorar otros proyectiles
	if target is Area3D and (target.name.begins_with("Arrow") or target.name.begins_with("Hacha") or target.name.begins_with("Proyectil")):
		return true

	# Ignorar triggers, detectores de rango y zonas
	var n_lower: String = target.name.to_lower()
	if n_lower == "rangodeataque" or n_lower == "hitbox" or n_lower == "hurtbox":
		return true
	if "detector" in n_lower or "rango" in n_lower or "trigger" in n_lower or "zonamov" in n_lower:
		return true
	if target.is_in_group("barreras_limite") or target.is_in_group("barrera_limite") or target.is_in_group("barrera_destruye_flechas"):
		return true
	if "barrera" in n_lower or "limit" in n_lower:
		return true

	if "es_escudo_enemigo" in target and not target.es_escudo_enemigo:
		return true
	if target.is_in_group("enemies"):
		if _es_enemigo_muerto_o_muriendo(target):
			return true
	# Plataformas aliadas: solo se atraviesan dentro de la gracia de lanzamiento
	# (cobertura propia al salir de la mano); más lejos el hacha se clava en ellas
	if _distancia_recorrida < gracia_plataformas_metros and _es_plataforma_aliada(target):
		return true
	return false


func _es_enemigo_muerto_o_muriendo(target: Node) -> bool:
	if not is_instance_valid(target):
		return true
	if target.get("is_dead") == true or target.get("is_dying") == true or target.get("muerto") == true:
		return true
	if target.get("is_dissolving") == true or target.get("_died_emitted") == true:
		return true
	if "health" in target and float(target.get("health")) <= 0.0:
		return true
	if "vida_actual" in target and float(target.get("vida_actual")) <= 0.0:
		return true
	if target is EnemyBase:
		var eb := target as EnemyBase
		if eb.current_state == EnemyBase.State.DYING or eb.current_state == EnemyBase.State.DEAD:
			return true
	elif target is GuardianaMoradita:
		var gm := target as GuardianaMoradita
		if gm.current_state == GuardianaMoradita.State.DYING or gm.current_state == GuardianaMoradita.State.DEAD:
			return true
	elif target is ImpShieldGirl:
		var isg := target as ImpShieldGirl
		if isg.current_state == ImpShieldGirl.State.DYING or isg.current_state == ImpShieldGirl.State.DEAD:
			return true
	elif "current_state" in target:
		var st_str: String = str(target.get("current_state")).to_upper()
		if "DYING" in st_str or "DEAD" in st_str or "MUERTO" in st_str:
			return true
	return false


func _on_body_entered(body: Node3D) -> void:
	if _impacto_procesado or _es_entidad_a_ignorar(body):
		return
	_procesar_impacto(body, global_position, -velocity.normalized())


func _on_area_entered(area: Area3D) -> void:
	if _impacto_procesado or _es_entidad_a_ignorar(area):
		return
	var target: Node = area.get_parent() if area.get_parent() else area
	if _es_entidad_a_ignorar(target):
		return

	# Solo procesar áreas que pertenezcan a enemigos, escudos o tengan métodos para recibir daño
	var es_valido: bool = (
		target.is_in_group("enemies") or
		target.is_in_group("escudos") or
		area.is_in_group("enemies") or
		area.is_in_group("escudos") or
		_es_escudo_o_guardian(target) or
		_es_escudo_o_guardian(area) or
		target.has_method("recibir_golpe") or
		target.has_method("take_damage") or
		target.has_method("recibir_dano") or
		area.has_method("recibir_golpe") or
		area.has_method("take_damage") or
		area.has_method("recibir_dano")
	)
	if not es_valido:
		return

	_procesar_impacto(target, global_position, -velocity.normalized())


func _es_plataforma_aliada(target: Node) -> bool:
	if not target or not is_instance_valid(target):
		return false
	if target is PlataformaOneway:
		return true
	if target.is_in_group("plataformas") or target.is_in_group("allied_platforms"):
		return true
	var n_lower: String = target.name.to_lower()
	if "plataforma" in n_lower or "oneway" in n_lower or "muro_plataforma" in n_lower or "debris" in n_lower or "arrowdetector" in n_lower or "insidedetector" in n_lower:
		return true
	var p: Node = target.get_parent()
	while p and p != get_tree().root:
		if p is PlataformaOneway:
			return true
		var pn_lower: String = p.name.to_lower()
		if "plataforma" in pn_lower or "oneway" in pn_lower or "muro_plataforma" in pn_lower:
			return true
		p = p.get_parent()
	return false


func _procesar_impacto(target: Node, punto: Vector3, _normal: Vector3) -> void:
	if _impacto_procesado or not is_instance_valid(target):
		return

	if _es_entidad_a_ignorar(target):
		if _ray_ccd and target is CollisionObject3D:
			_ray_ccd.add_exception(target as CollisionObject3D)
		return

	# Capturar dirección de vuelo real antes de anular la velocidad
	var dir_vuelo: Vector3 = velocity.normalized()
	if dir_vuelo.length_squared() < 0.001:
		dir_vuelo = Vector3.RIGHT

	_impacto_procesado = true
	is_stuck = true
	velocity = Vector3.ZERO
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if _ray_ccd:
		_ray_ccd.enabled = false

	# ═══════════════════════════════════════════════════════════════════════════
	# ORIENTACIÓN DE IMPACTO: EL FILO DEL HACHA (+X DEL MODELO) DEBE IMPACTAR
	# Y CLAVARSE SIEMPRE DIRECTAMENTE EN EL BLANCO
	# ═══════════════════════════════════════════════════════════════════════════
	var ang_filo: float = atan2(dir_vuelo.y, dir_vuelo.x) - ANGULO_FILO_OFFSET_RAD
	if _modelo_hacha and is_instance_valid(_modelo_hacha):
		_modelo_hacha.rotation = Vector3(0.0, 0.0, ang_filo)

	# Clavar ligeramente la hoja hacia el objetivo
	global_position += dir_vuelo * 0.08

	impactado.emit(target)

	var real_target: Node = _resolver_entidad_objetivo(target)
	var dano: float = calcular_dano_para(real_target)

	# ═══════════════════════════════════════════════════════════════════════════
	# INTERACCIÓN CON AURA REPELENTE / PARRY (Arquera Rosa, Azulina, Lonko, General):
	# REGLA: El ult de perrena (hacha gigante especial) NO se puede parrear ni desviar
	# (es como si fuera una flecha explosiva).
	# ═══════════════════════════════════════════════════════════════════════════
	if es_hacha_especial or es_explosiva:
		# Avisar al target para que rompa su aura o reaccione, pero NUNCA rebotar ni destruirse
		if real_target.has_method("manejar_impacto_aura"):
			real_target.manejar_impacto_aura(self)
		elif target.has_method("manejar_impacto_aura"):
			target.manejar_impacto_aura(self)
	else:
		if real_target.has_method("manejar_impacto_aura") and real_target.manejar_impacto_aura(self):
			_rebotar_y_destruir()
			return
		if target.has_method("manejar_impacto_aura") and target.manejar_impacto_aura(self):
			_rebotar_y_destruir()
			return

	# Registrar metadatos de golpe para efectos de sangre / dirección
	if "last_hit_position" in real_target:
		real_target.set("last_hit_position", punto)
	elif "last_hit_position" in target:
		target.set("last_hit_position", punto)

	if "last_hit_direction" in real_target:
		real_target.set("last_hit_direction", dir_vuelo)
	elif "last_hit_direction" in target:
		target.set("last_hit_direction", dir_vuelo)

	if "ultimo_atacante" in real_target:
		real_target.set("ultimo_atacante", tirador)
	elif "ultimo_atacante" in target:
		target.set("ultimo_atacante", tirador)

	# Si es hacha especial, activa murio_por_explosion para que los enemigos
	# reaccionen con su animación/física especial de muerte explosiva
	if es_hacha_especial:
		if "murio_por_explosion" in real_target:
			real_target.set("murio_por_explosion", true)
		elif real_target.has_meta("murio_por_explosion"):
			real_target.set_meta("murio_por_explosion", true)
		elif "murio_por_explosion" in target:
			target.set("murio_por_explosion", true)
		elif target.has_meta("murio_por_explosion"):
			target.set_meta("murio_por_explosion", true)

		var game_feel = get_tree().root.get_node_or_null("GameFeel") if get_tree() else null
		if game_feel and game_feel.has_method("on_player_shoot"):
			game_feel.on_player_shoot()

		# Sacudir el submarino con bamboleo de oleaje si el impacto del Ult fue hacia él o sobre su cubierta
		_sacudir_submarino_si_aplica(real_target, target)
		# Igual con el barco combate pirata: bamboleo de oleaje ante el Ult
		_sacudir_barco_si_aplica(real_target, target)

	# Aplicar daño al objetivo resuelto o al nodo directo
	var vida_antes: float = _obtener_vida_enemigo(real_target, target)
	if real_target.has_method("recibir_golpe"):
		real_target.call("recibir_golpe", dano)
	elif real_target.has_method("take_damage"):
		real_target.call("take_damage", dano)
	elif real_target.has_method("recibir_dano"):
		real_target.call("recibir_dano", int(dano))
	elif target.has_method("recibir_golpe"):
		target.call("recibir_golpe", dano)
	elif target.has_method("take_damage"):
		target.call("take_damage", dano)
	elif target.has_method("recibir_dano"):
		target.call("recibir_dano", int(dano))

	_reproducir_sfx_impacto(punto)

	# Si el Ult mató al enemigo con este golpe, suena el reventado
	if es_hacha_especial and vida_antes > 0.0 and _murio_por_este_golpe(real_target, target):
		_reproducir_sfx_reventado(punto)

	# Si el Ult falló (terreno o pilar de Lonko, no enemigos), suena el fallo a tierra
	if es_hacha_especial and not _fue_impacto_a_enemigo(real_target, target):
		_reproducir_sfx_fallo_tierra(punto)

	# El Ult al impactar en terreno levanta pequeñas piedras
	# (efecto del emerger del pilar de la arquera Lonko)
	if es_hacha_especial and _es_terreno_para_rocas(real_target, target):
		_levantar_piedras_impacto(punto)

	# Pegarse al objetivo si es un nodo 3D válido.
	# Solo emparentar a geometría estática (terrenos, objetos, escudos fijos):
	# los enemigos mueren y se liberan, y se llevarían el hacha clavada con ellos.
	var target_pegar: Node = real_target if (real_target is Node3D) else target
	if target_pegar is StaticBody3D or target_pegar is AnimatableBody3D:
		if is_instance_valid(target_pegar) and not (target_pegar as Node3D).is_queued_for_deletion():
			call_deferred("_pegar_a_nodo", target_pegar as Node3D)
	# Enemigos y demás: queda congelada en el mundo (is_stuck detiene el vuelo)
	# hasta desvanecerse, sin atarse a un cuerpo que va a desaparecer.

	# Si el impacto mató al enemigo, desvanecer rápidamente tras un breve instante (0.35s)
	# para que no quede flotando en el aire vacío tras desaparecer el cadáver.
	var enemigo_murio: bool = _murio_por_este_golpe(real_target, target)
	var dur_pegada: float = 0.35 if enemigo_murio else (2.0 if es_hacha_especial else tiempo_pegada)

	# Si el enemigo sobrevivió pero se libera/destruye antes, limpiar el hacha inmediatamente
	if _fue_impacto_a_enemigo(real_target, target):
		var enemigo_nodo: Node = real_target if is_instance_valid(real_target) else target
		if is_instance_valid(enemigo_nodo):
			enemigo_nodo.tree_exiting.connect(func():
				if is_instance_valid(self) and is_inside_tree() and not _desvaneciendose:
					_desvanecer_y_liberar(0.2)
			)

	if get_tree():
		get_tree().create_timer(dur_pegada).timeout.connect(
			func():
				if is_instance_valid(self) and is_inside_tree():
					_desvanecer_y_liberar()
		)


## Solo terreno / superficies fijas sin ser enemigos ni escudos (no Lonko, no Azulina,
## ni pilares): ahí el Ult levanta piedritas.
func _es_terreno_para_rocas(real_target: Node, target: Node) -> bool:
	var estatico: bool = (real_target is StaticBody3D or real_target is AnimatableBody3D)
	if not estatico and (target is StaticBody3D or target is AnimatableBody3D):
		return not _es_escudo_o_guardian(target)
	if not estatico:
		return false
	if real_target.is_in_group("enemies"):
		return false
	return not _es_escudo_o_guardian(real_target)


## Ráfaga pequeña de rocas al estilo del emerger del pilar Lonko (mismo atlas).
func _levantar_piedras_impacto(punto: Vector3) -> void:
	if not TEXTURA_ROCAS or get_tree() == null:
		return
	var parts := GPUParticles3D.new()
	parts.name = "ParticulasRocasHacha"
	parts.amount = 12
	parts.lifetime = 1.1
	parts.one_shot = true
	parts.explosiveness = 0.9

	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(0.12, 0.03, 0.12)
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 35.0
	pmat.initial_velocity_min = 1.5
	pmat.initial_velocity_max = 3.5
	pmat.gravity = Vector3(0, -12.0, 0)
	pmat.scale_min = 0.15
	pmat.scale_max = 0.35
	pmat.anim_offset_min = 0.0
	pmat.anim_offset_max = 1.0
	pmat.angle_min = 0.0
	pmat.angle_max = 360.0
	pmat.angular_velocity_min = -180.0
	pmat.angular_velocity_max = 180.0
	parts.process_material = pmat

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = TEXTURA_ROCAS
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.particles_anim_h_frames = 4
	mat.particles_anim_v_frames = 1
	mat.particles_anim_loop = false
	var quad := QuadMesh.new()
	quad.size = Vector2(0.22, 0.22)
	quad.material = mat
	parts.draw_pass_1 = quad

	var root: Node = get_tree().current_scene
	if root == null:
		root = get_tree().root
	root.add_child(parts)
	parts.global_position = punto + Vector3(0, 0.05, 0)
	parts.emitting = true

	get_tree().create_timer(2.5).timeout.connect(func():
		if is_instance_valid(parts):
			parts.queue_free()
	)


func _desvanecer_y_liberar(tiempo_fade: float = 0.45) -> void:
	# Como las flechas: desvanecido gradual por alfa, sin encoger.
	if _desvaneciendose:
		return
	_desvaneciendose = true

	var meshes: Array = []
	if _modelo_hacha and is_instance_valid(_modelo_hacha):
		meshes = _modelo_hacha.find_children("*", "MeshInstance3D", true, false)
	else:
		meshes = find_children("*", "MeshInstance3D", true, false)

	var materiales: Array[StandardMaterial3D] = []
	for node in meshes:
		var mi := node as MeshInstance3D
		if mi == null or not is_instance_valid(mi):
			continue
		var orig: Material = mi.material_override
		if orig == null and mi.mesh:
			orig = mi.mesh.surface_get_material(0)
		var mat := StandardMaterial3D.new()
		if orig is StandardMaterial3D:
			# Copia por hacha para no teñir a las demás (MAT_HACHA es compartido)
			mat = (orig as StandardMaterial3D).duplicate()
		# Sin contorno durante el desvanecimiento y con alfa animable
		mat.next_pass = null
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mi.material_override = mat
		materiales.append(mat)

	if materiales.is_empty():
		queue_free()
		return

	var tw := create_tween()
	tw.tween_method(
		func(alfa: float):
			for m in materiales:
				if is_instance_valid(m):
					var c := m.albedo_color
					c.a = alfa
					m.albedo_color = c
	, 1.0, 0.0, tiempo_fade)
	tw.tween_callback(queue_free)


func _rebotar_y_destruir() -> void:
	velocity = -velocity * 0.4 + Vector3(0, 3, 0)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ZERO, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


func _reproducir_sfx_impacto(pos: Vector3) -> void:
	var sfx_path: String = SFX_IMPACTO_ESPECIAL if (es_hacha_especial and ResourceLoader.exists(SFX_IMPACTO_ESPECIAL)) else SFX_IMPACTO
	if not ResourceLoader.exists(sfx_path):
		return
	var stream := load(sfx_path) as AudioStream
	if not stream:
		return
	var audio := AudioStreamPlayer3D.new()
	audio.stream = stream
	audio.unit_size = 18.0 if es_hacha_especial else 15.0
	audio.volume_db = 4.5 if es_hacha_especial else 1.0
	audio.bus = "Master"
	var root := get_tree().current_scene if get_tree() else get_tree().root
	if root:
		root.add_child(audio)
		audio.global_position = pos
		audio.play()
		audio.finished.connect(audio.queue_free)
	else:
		audio.queue_free()


## Reventado que suena cuando el Ult mata a un enemigo con el golpe.
func _reproducir_sfx_reventado(pos: Vector3) -> void:
	if not ResourceLoader.exists(SFX_REVENTADO_ULT):
		return
	var stream := load(SFX_REVENTADO_ULT) as AudioStream
	if not stream:
		return
	var audio := AudioStreamPlayer3D.new()
	audio.name = "SfxReventadoUlt"
	audio.stream = stream
	audio.unit_size = 15.0
	audio.volume_db = 3.0
	audio.bus = "Master"
	var root := get_tree().current_scene if get_tree() else get_tree().root
	if root:
		root.add_child(audio)
		audio.global_position = pos
		audio.play()
		audio.finished.connect(audio.queue_free)
	else:
		audio.queue_free()


## True si el impacto fue contra un enemigo (clase o grupo); el pilar de Lonko
## y el terreno NO cuentan como enemigo (ahí el Ult falló).
func _fue_impacto_a_enemigo(real_target: Node, target: Node) -> bool:
	for nodo in [real_target, target]:
		if not is_instance_valid(nodo):
			continue
		if nodo.is_in_group("enemies") or nodo.is_in_group("enemigos") or nodo.is_in_group("submarinos") or nodo.is_in_group("submarino") or nodo.is_in_group("jefe_submarino"):
			return true
		var script_obj = nodo.get_script()
		if script_obj is Script:
			var s_name: String = (script_obj as Script).get_global_name()
			if s_name in ["EnemyBase", "Lonko", "ArqueraRosa", "Azulina", "ImpShieldGirl", "GuardianaMoradita", "ImpEnemy", "Goblin", "GoblinGirl", "GoblinGeneral", "LimoCuadrado", "SubmarinoRio", "JefeSubmarinoRio"]:
				return true
	return false


func _sacudir_submarino_si_aplica(real_target: Node, target: Node) -> void:
	var sub: Node = _buscar_submarino(real_target)
	if not is_instance_valid(sub):
		sub = _buscar_submarino(target)
	if is_instance_valid(sub) and sub.has_method("sacudida_oleaje"):
		sub.call("sacudida_oleaje", 2.2, 4.5)


## Bamboleo del barco combate pirata ante el Ult (casco o tripulación embarcada).
func _sacudir_barco_si_aplica(real_target: Node, target: Node) -> void:
	var barco: Node = _buscar_barco_combate(real_target)
	if not is_instance_valid(barco):
		barco = _buscar_barco_combate(target)
	if is_instance_valid(barco) and barco.has_method("sacudida_oleaje"):
		barco.call("sacudida_oleaje", 2.2, 4.5)


## Sube por los padres hasta el barco/balsa de combate (cubre casco, cubierta
## y tripulantes embarcados, como _buscar_submarino con el submarino).
func _buscar_barco_combate(nodo: Node) -> Node:
	if get_tree() == null:
		return null
	var curr: Node = nodo
	while curr and curr != get_tree().root:
		if curr is BalsaPirataCombate:
			return curr
		var s_name := ""
		var scr = curr.get_script()
		if scr is Script:
			s_name = (scr as Script).get_global_name()
		if s_name == "BalsaPirataCombate" or s_name == "BarcoCombatePirata":
			return curr
		curr = curr.get_parent()
	return null


func _buscar_submarino(nodo: Node) -> Node:
	var curr: Node = nodo
	while curr and curr != get_tree().root:
		if curr is SubmarinoRio or curr.is_in_group("submarino") or curr.is_in_group("submarinos") or curr.is_in_group("jefe_submarino"):
			return curr
		var s_name := ""
		var scr = curr.get_script()
		if scr is Script:
			s_name = (scr as Script).get_global_name()
		if s_name == "SubmarinoRio" or s_name == "JefeSubmarinoRio":
			return curr
		curr = curr.get_parent()
	return null


## Fallo a tierra del Ult (impactó en terreno o en el pilar de Lonko).
func _reproducir_sfx_fallo_tierra(pos: Vector3) -> void:
	if not ResourceLoader.exists(SFX_FALLO_TIERRA_ULT):
		return
	var stream := load(SFX_FALLO_TIERRA_ULT) as AudioStream
	if not stream:
		return
	var audio := AudioStreamPlayer3D.new()
	audio.name = "SfxFalloTierraUlt"
	audio.stream = stream
	audio.unit_size = 15.0
	audio.volume_db = 2.5
	audio.bus = "Master"
	var root := get_tree().current_scene if get_tree() else get_tree().root
	if root:
		root.add_child(audio)
		audio.global_position = pos
		audio.play()
		audio.finished.connect(audio.queue_free)
	else:
		audio.queue_free()


## Vida actual del enemigo (real o directo); -1 si no es enemigo con vida legible.
func _obtener_vida_enemigo(real_target: Node, target: Node) -> float:
	var real_es_enemigo: bool = is_instance_valid(real_target) and real_target.is_in_group("enemies")
	var dir_es_enemigo: bool = is_instance_valid(target) and target.is_in_group("enemies")
	if not real_es_enemigo and not dir_es_enemigo:
		return -1.0
	for nodo in [real_target, target]:
		if is_instance_valid(nodo) and "health" in nodo:
			var v = nodo.get("health")
			if v is int or v is float:
				return float(v)
	return -1.0


## True si el enemigo quedó muerto tras el golpe (tenía vida antes).
func _murio_por_este_golpe(real_target: Node, target: Node) -> bool:
	for nodo in [real_target, target]:
		if not is_instance_valid(nodo):
			continue
		if "health" in nodo:
			var v = nodo.get("health")
			if (v is int or v is float) and float(v) <= 0.0:
				return true
		if nodo.get("is_dead") == true or nodo.get("is_dying") == true or nodo.get("muerto") == true:
			return true
		if nodo.get("current_state") != null:
			var st_str: String = str(nodo.current_state).to_upper()
			if "DYING" in st_str or "DEAD" in st_str or "MUERTO" in st_str:
				return true
	return false


func _aplicar_material() -> void:
	if not _modelo_hacha:
		return
	for child in _modelo_hacha.find_children("*", "MeshInstance3D", true, false):
		if child is MeshInstance3D:
			(child as MeshInstance3D).material_override = MAT_HACHA


func _pegar_a_nodo(nodo_padre: Node3D) -> void:
	if not is_instance_valid(nodo_padre) or not nodo_padre.is_inside_tree():
		return

	var xform_global: Transform3D = global_transform
	var parent_actual := get_parent()
	if parent_actual:
		parent_actual.remove_child(self)
	nodo_padre.add_child(self)
	global_transform = xform_global
