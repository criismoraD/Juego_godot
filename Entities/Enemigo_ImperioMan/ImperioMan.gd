@tool
class_name ImperioMan
extends CharacterBody3D

## Defensor aliado Imperio Man (Clase Guardián, cuerpo a cuerpo).
## Funciona igual que GuardianaMoradita pero del lado del jugador: entra
## corriendo, busca posicionarse delante de sus aliados (protagonista y
## defensoras) para cubrirlos con su escudo y ataca en ciclos.
## Diferencias: ataca cuerpo a cuerpo con la espada imperial (mano derecha)
## en vez de lanzar tridentes, porta en la mano izquierda el escudo élfico
## (comparte la vida del cuerpo: los golpes al escudo dañan a Imperio Man),
## tiene 10 de vida, hace 2 de daño por tajo,
## NUNCA sufre daño crítico, JAMÁS ataca a la protagonista ni a aliadas,
## las flechas del jugador lo atraviesan sin dañarlo (él y su escudo están
## marcados como defensa aliada) y SOLO ataca cuando hay enemigos dentro
## del alcance de su espada. Al morir se disuelve en amarillo como los enemigos.

enum State { RUNNING, ATTACKING, DEFENDING, SHIELD_HIT, DYING, DEAD, TURNING }

signal died

const VIDA_MAXIMA_DEFAULT: int = 10
const VELOCIDAD_CARRERA_DEFAULT: float = 1.8
const DISTANCIA_PROTECCION_DEFAULT: float = 0.65
const DANO_CUERPO_A_CUERPO_DEFAULT: int = 2
const ALCANCE_MELEE_DEFAULT: float = 1.8
const MARGEN_Z_MELEE_DEFAULT: float = 1.5
const TIEMPO_GOLPE_MELEE_DEFAULT: float = 0.6
const DURACION_ATAQUE_DEFAULT: float = 1.2
const INTERVALO_ATAQUE_DEFENSA: float = 6.0
const DURACION_DISOLUCION: float = 1.2

const DISSOLVE_SHADER: Shader = preload("res://System/Shaders/dissolve.gdshader")
const SANGRE_SCENE: PackedScene = preload("res://VFX/Scenes/BloodSplashNormal.tscn")
const SANGRE_NO_LETAL_SCENE: PackedScene = preload("res://VFX/Scenes/BloodSplashNoLetal.tscn")
const MAT_IMPERIO: Material = preload("res://Entities/Enemigo_ImperioMan/ImperioMan_Mat.tres")
const MAT_ESPADA: Material = preload("res://Entities/Enemigo_ImperioMan/EspadaImperial_Mat.tres")
const MAT_ESCUDO_ELFICO: Material = preload("res://Levels/Nivel_Interior/MAT_EscudoPesadoElfico.tres")
const ESCENA_ESPADA: PackedScene = preload("res://Entities/Enemigo_ImperioMan/Espada imperial.glb")
const ESCENA_ESCUDO_MANO: PackedScene = preload("res://Entities/Enemigo_ImperioMan/Escudo pesado elfico.glb")
const ESCALA_ESPADA_MANO: float = 0.7
const ESCALA_ESCUDO_MANO: float = 0.55

@export_category("Estadísticas")
@export var vida_maxima: int = VIDA_MAXIMA_DEFAULT
@export var velocidad_carrera: float = VELOCIDAD_CARRERA_DEFAULT
@export var distancia_proteccion: float = DISTANCIA_PROTECCION_DEFAULT
@export var rotacion_y_modelo: float = 270.0
@export var color_borde_disolucion: Color = Color(1.0, 0.6, 0.2)  ## Amarillo de disolución como los enemigos (EnemyBase)
@export var dano_cuerpo_a_cuerpo: int = DANO_CUERPO_A_CUERPO_DEFAULT
@export var alcance_melee: float = ALCANCE_MELEE_DEFAULT
@export var margen_z_melee: float = MARGEN_Z_MELEE_DEFAULT
@export var tiempo_golpe_melee: float = TIEMPO_GOLPE_MELEE_DEFAULT
@export var duracion_ataque_total: float = DURACION_ATAQUE_DEFAULT
@export var estatico: bool = false  ## Si true, fija su posición: no se desplaza, ataca y defiende en el sitio
@export var rotacion_y_puesto: float = 270.0  ## Orientación fija al estar estatico (90 = mira derecha a los goblins, escudo al frente)
@export var inmortal: bool = false  ## Si true, ignora todo daño (defensor del tutorial)
@export var riposta_cada_bloqueos: int = 0  ## Si > 0: bloquea el melee y contrataca con espada cada N bloqueos (solo con enemigo a melee en rango). 0 = conducta clásica.
@export var plano_profundidad_z: float = 0.0  ## Plano Z del defensor Imperio Man (por delante de ballesteras y por detrás de la prota)

@export_category("Zona de Entrada (Zona Roja)")
@export var zona_roja_min_x: float = -2.2
@export var zona_roja_max_x: float = 0.2

var current_state: State = State.RUNNING
var health: int = VIDA_MAXIMA_DEFAULT
var es_estructura: bool = false
var murio_por_explosion: bool = false
var murio_por_critico: bool = false
var last_hit_position: Vector3 = Vector3.ZERO
var last_hit_direction: Vector3 = Vector3.ZERO
var ultimo_atacante: Node = null

var aliado_protegido: Node3D = null
var posicion_objetivo_zona_roja: float = -1.0
var primer_ataque_realizado: bool = false
var tiempo_defensa_primer_ataque: float = 0.0

var _ha_atacado_en_animacion: bool = false
var _attack_timer: float = 0.0
var _bloqueos_acumulados: int = 0
var _timer_defensa: float = 0.0
var _check_enemigos_timer: float = 0.0
var _shield_hit_timer: float = 0.0
var _turn_timer: float = 0.0
var _velocidad_actual: float = 0.0
var _angulo_giro_inicio: float = 90.0
var _angulo_giro_destino: float = -90.0
var _is_dissolving: bool = false
var _dissolve_materials: Array = []
var _flash_mat: StandardMaterial3D = null

var model_root: Node3D = null
var anim_player: AnimationPlayer = null
var _cuerpo_meshes: Array[MeshInstance3D] = []


# === FUNCIONES BUILT-IN ===
func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	add_to_group("allies")
	add_to_group("defensoras")

	health = vida_maxima
	posicion_objetivo_zona_roja = randf_range(zona_roja_min_x, zona_roja_max_x)
	model_root = find_child("Modelo", true, false) as Node3D
	if model_root:
		model_root.position.z = 0.15
	_aplicar_prioridad_renderizado(4.0)
	if is_zero_approx(global_position.z):
		global_position.z = plano_profundidad_z
	_setup_anim_player()
	_setup_materiales()
	_aplicar_rotacion_modelo()
	_equipar_espada_mano_derecha()
	_equipar_escudo_mano_izquierda()

	if Engine.is_editor_hint():
		return

	_configurar_excepciones_colision_aliadas()
	_buscar_aliado_a_proteger()
	_excluir_escudo_mano()
	_marcar_escudo_mano_como_aliado()
	_cambiar_estado(State.RUNNING)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta

	_asegurar_orientacion_derecha()

	match current_state:
		State.RUNNING:
			_process_running(delta)
		State.ATTACKING:
			_process_attacking(delta)
		State.DEFENDING:
			_process_defending(delta)
		State.SHIELD_HIT:
			_process_shield_hit(delta)
		State.TURNING:
			_process_turning(delta)
		State.DYING, State.DEAD:
			pass

	move_and_slide()
	global_position.z = plano_profundidad_z


func _configurar_excepciones_colision_aliadas() -> void:
	var tree := get_tree()
	if not tree:
		return
	var excepciones := get_collision_exceptions()
	for grupo in [&"player", &"allies", &"defensoras"]:
		for ent in tree.get_nodes_in_group(grupo):
			if ent != self and ent is CollisionObject3D:
				var col_obj := ent as CollisionObject3D
				if not excepciones.has(col_obj):
					add_collision_exception_with(col_obj)


func _aplicar_prioridad_renderizado(offset: float) -> void:
	for node in find_children("*", "VisualInstance3D", true, false):
		if node is VisualInstance3D:
			node.sorting_offset = offset


## Retorna el escudo de la mano izquierda (hijo del BoneAttachment_Escudo,
## sea cual sea su nombre de nodo).
func _nodo_escudo_mano() -> Node3D:
	var attach := find_child("BoneAttachment_Escudo", true, false) as Node
	if not is_instance_valid(attach):
		return find_child("EscudoMano", true, false) as Node3D
	for hijo in attach.get_children():
		if hijo is Node3D:
			return hijo as Node3D
	return find_child("EscudoMano", true, false) as Node3D


## El escudo de mano es un StaticBody3D hijo: excluirlo para no auto-colisionar.
func _excluir_escudo_mano() -> void:
	var escudo := _nodo_escudo_mano() as StaticBody3D
	if is_instance_valid(escudo):
		add_collision_exception_with(escudo)


## El escudo de mano reutiliza EscudoPesadoArea (pensado para enemigas,
## con es_escudo_enemigo en true): marcarlo como defensa ALIADA para que
## las flechas del jugador y las explosiones lo atraviesen sin dañarlo.
## Los proyectiles enemigos sí lo alcanzan y dañan a Imperio Man.
func _marcar_escudo_mano_como_aliado() -> void:
	var areas: Array[Node] = []
	var attach := find_child("BoneAttachment_Escudo", true, false)
	if is_instance_valid(attach):
		areas = (attach as Node).find_children("*", "Area3D", true, false)
	if areas.is_empty():
		areas = find_children("*", "Area3D", true, false)
	for area in areas:
		if "es_escudo_enemigo" in area:
			area.set("es_escudo_enemigo", false)
		if "es_pilar_enemigo" in area:
			area.set("es_pilar_enemigo", false)


## Busca el Skeleton3D del modelo sin depender de rutas fijas.
func _buscar_skeleton() -> Skeleton3D:
	var esqueletos := find_children("*", "Skeleton3D", true, false)
	if not esqueletos.is_empty():
		return esqueletos[0] as Skeleton3D
	return null


## Resuelve el hueso de la mano (derecha/izquierda) aunque el importador
## haya variado los nombres: prueba exactos y luego búsqueda difusa.
func _resolver_hueso_mano(esqueleto: Skeleton3D, lado: String) -> int:
	if not is_instance_valid(esqueleto):
		return -1
	var exactos: Array[String] = []
	if lado == "Right":
		exactos = ["mixamorig:RightHand", "RightHand", "Hand_R", "R_Hand", "mixamorigR:RightHand"]
	else:
		exactos = ["mixamorig:LeftHand", "LeftHand", "Hand_L", "L_Hand"]
	for candidato in exactos:
		var idx: int = esqueleto.find_bone(candidato)
		if idx >= 0:
			return idx
	for i in range(esqueleto.get_bone_count()):
		var nl: String = esqueleto.get_bone_name(i).to_lower()
		if "finger" in nl or "index" in nl or "thumb" in nl:
			continue
		if lado == "Right" and ("righthand" in nl or "hand.r" in nl or "r_hand" in nl):
			return i
		if lado == "Left" and ("lefthand" in nl or "hand.l" in nl or "l_hand" in nl):
			return i
	return -1


## Enlaza un BoneAttachment3D al hueso por índice y nombre real.
func _enlazar_attachment(attach: BoneAttachment3D, esqueleto: Skeleton3D, idx_hueso: int) -> void:
	attach.bone_idx = idx_hueso
	attach.bone_name = esqueleto.get_bone_name(idx_hueso)


## Ata la espada imperial a la mano derecha (espada imperial de Enemigo_ImperioMan).
## Si el TSCN ya la trae, repara su enlace al hueso real.
func _equipar_espada_mano_derecha() -> void:
	var existente := find_child("EspadaImperial", true, false) as Node3D
	var esqueleto := _buscar_skeleton()
	if not is_instance_valid(esqueleto):
		push_warning("[ImperioMan] Sin Skeleton3D: espada sin atar.")
		return
	var idx_hueso: int = _resolver_hueso_mano(esqueleto, "Right")
	if idx_hueso < 0:
		push_warning("[ImperioMan] Sin hueso de mano derecha: espada sin atar.")
		return
	if is_instance_valid(existente):
		var attach_existente := existente.get_parent() as BoneAttachment3D
		if is_instance_valid(attach_existente):
			_enlazar_attachment(attach_existente, esqueleto, idx_hueso)
		_aplicar_material_espada()
		return
	var attach := BoneAttachment3D.new()
	attach.name = "BoneAttachment_Espada"
	esqueleto.add_child(attach)
	_enlazar_attachment(attach, esqueleto, idx_hueso)
	var espada: Node3D = ESCENA_ESPADA.instantiate() as Node3D
	if espada == null:
		return
	espada.name = "EspadaImperial"
	espada.scale = Vector3.ONE * ESCALA_ESPADA_MANO
	attach.add_child(espada)
	_aplicar_material_espada()


## Ata el escudo élfico a la mano izquierda (el que trae el TSCN).
## Si el TSCN ya lo trae, repara su enlace al hueso real y su textura.
func _equipar_escudo_mano_izquierda() -> void:
	var existente := _nodo_escudo_mano()
	var esqueleto := _buscar_skeleton()
	if not is_instance_valid(esqueleto):
		push_warning("[ImperioMan] Sin Skeleton3D: escudo sin atar.")
		return
	var idx_hueso: int = _resolver_hueso_mano(esqueleto, "Left")
	if idx_hueso < 0:
		push_warning("[ImperioMan] Sin hueso de mano izquierda: escudo sin atar.")
		return
	if is_instance_valid(existente):
		var attach_existente := existente.get_parent() as BoneAttachment3D
		if is_instance_valid(attach_existente):
			_enlazar_attachment(attach_existente, esqueleto, idx_hueso)
		_aplicar_material_escudo_elfico(existente)
		return
	push_warning("[ImperioMan] Sin escudo en TSCN: coloca el escudo élfico bajo BoneAttachment_Escudo.")


# === MÁQUINA DE ESTADOS ===
func _cambiar_estado(nuevo_estado: State) -> void:
	if current_state == State.DYING or current_state == State.DEAD:
		return

	current_state = nuevo_estado

	match nuevo_estado:
		State.RUNNING:
			_play_anim("Correr", 0.2, 1.2)
		State.ATTACKING:
			velocity.x = 0.0
			velocity.z = 0.0
			_attack_timer = 0.0
			_ha_atacado_en_animacion = false
			_play_anim("Ataque", 0.15, 1.0)
		State.DEFENDING:
			velocity.x = 0.0
			velocity.z = 0.0
			_timer_defensa = 0.0
			_play_anim("Idle", 0.25, 1.0)
		State.SHIELD_HIT:
			_shield_hit_timer = 0.45
			_play_anim("Bloqueo escudo", 0.1, 1.1)
		State.TURNING:
			# Siempre debe mirar a la derecha para bloquear con el escudo
			_asegurar_orientacion_derecha()
			_cambiar_estado(State.DEFENDING)
			return
		State.DYING:
			_morir()


func _process_running(delta: float) -> void:
	_check_enemigos_timer -= delta
	if _check_enemigos_timer <= 0.0:
		_check_enemigos_timer = 0.35
		_buscar_aliado_a_proteger()

	if not is_instance_valid(aliado_protegido) or not aliado_protegido.is_inside_tree():
		_buscar_aliado_a_proteger()

	_asegurar_orientacion_derecha()

	if estatico:
		# Puesto fijo: no se desplaza; ataca si hay enemigo al alcance.
		# En modo riposta no inicia ataques: solo contrataca por bloqueos.
		velocity.x = 0.0
		if riposta_cada_bloqueos <= 0 and _enemigo_en_alcance_melee():
			_cambiar_estado(State.ATTACKING)
		else:
			_cambiar_estado(State.DEFENDING)
		return

	var destino_x: float = posicion_objetivo_zona_roja
	if is_instance_valid(aliado_protegido):
		destino_x = min(aliado_protegido.global_position.x - distancia_proteccion, zona_roja_max_x)
	else:
		destino_x = posicion_objetivo_zona_roja

	var diff_x: float = destino_x - global_position.x

	if abs(diff_x) <= 0.15 and global_position.x <= zona_roja_max_x:
		velocity.x = 0.0
		_asegurar_orientacion_derecha()
		# SOLO ataca si hay enemigos dentro del alcance de la espada;
		# sin enemigos queda defendiendo (idle) en su puesto.
		if _enemigo_en_alcance_melee():
			_cambiar_estado(State.ATTACKING)
		else:
			_cambiar_estado(State.DEFENDING)
		return

	if global_position.x > zona_roja_max_x:
		velocity.x = -velocidad_carrera
		_asegurar_orientacion_derecha()
	else:
		var dir: float = sign(diff_x)
		velocity.x = dir * velocidad_carrera
		_asegurar_orientacion_derecha()


func _process_attacking(delta: float) -> void:
	_attack_timer += delta
	_asegurar_orientacion_derecha()

	if not _ha_atacado_en_animacion and _attack_timer >= tiempo_golpe_melee:
		_ha_atacado_en_animacion = true
		_golpe_espada()

	if _attack_timer >= duracion_ataque_total:
		_attack_timer = 0.0
		_timer_defensa = 0.0
		if not primer_ataque_realizado:
			primer_ataque_realizado = true
			tiempo_defensa_primer_ataque = 0.0

		# En puesto fijo no gira ni se desplaza tras atacar: mantiene su
		# orientación a la derecha con el escudo al frente.
		if estatico:
			_cambiar_estado(State.DEFENDING)
			return

		var otro_enemigo := _buscar_otro_enemigo_cercano()
		if otro_enemigo != null:
			aliado_protegido = otro_enemigo
			var destino_x: float = min(aliado_protegido.global_position.x - distancia_proteccion, zona_roja_max_x)
			var diff_x: float = destino_x - global_position.x
			if abs(diff_x) > 0.2:
				_cambiar_estado(State.RUNNING)
				return

		_cambiar_estado(State.DEFENDING)


func _process_defending(delta: float) -> void:
	tiempo_defensa_primer_ataque += delta
	_asegurar_orientacion_derecha()

	_check_enemigos_timer -= delta
	if _check_enemigos_timer <= 0.0:
		_check_enemigos_timer = 0.35
		if not is_instance_valid(aliado_protegido) or not aliado_protegido.is_inside_tree():
			_buscar_aliado_a_proteger()

	if is_instance_valid(aliado_protegido) and aliado_protegido.is_inside_tree():
		_timer_defensa += delta
		# SOLO ataca si hay enemigos en alcance de espada (pasea el ciclo
		# con el intervalo para no encadenar tajos sin pausa). En modo
		# riposta el ataque lo dictan los bloqueos, no el temporizador.
		if riposta_cada_bloqueos <= 0 and _timer_defensa >= INTERVALO_ATAQUE_DEFENSA \
				and _enemigo_en_alcance_melee():
			_timer_defensa = 0.0
			_cambiar_estado(State.ATTACKING)
			return

		if estatico:
			return

		var destino_x: float = min(aliado_protegido.global_position.x - distancia_proteccion, zona_roja_max_x)
		var diff_x: float = destino_x - global_position.x
		if abs(diff_x) > 1.2:
			_cambiar_estado(State.RUNNING)
	else:
		_timer_defensa = 0.0
		# Sin aliado que proteger: solo ataca si un enemigo entra en alcance;
		# en caso contrario queda defendiendo en idle en su puesto.
		# En modo riposta no inicia ataques por su cuenta.
		if riposta_cada_bloqueos <= 0 and _enemigo_en_alcance_melee():
			_cambiar_estado(State.ATTACKING)
			return


func _process_shield_hit(delta: float) -> void:
	_shield_hit_timer -= delta
	_asegurar_orientacion_derecha()
	if _shield_hit_timer <= 0.0:
		_cambiar_estado(State.DEFENDING)


func _process_turning(_delta: float) -> void:
	_asegurar_orientacion_derecha()
	_cambiar_estado(State.DEFENDING)


# === ATAQUE CUERPO A CUERPO ===
## Tajo de espada imperial al frente (+X hacia la derecha): daña solo a UN enemigo
## a la vez (el más cercano dentro de alcance). JAMÁS daña a la protagonista ni a aliadas.
func _golpe_espada() -> void:
	AudioManager.play_sfx("lanzar_espada_pirata")
	if get_tree() == null:
		return

	# Solo puede causar daño a un enemigo a la vez cuando ataca:
	# busca el enemigo válido más cercano dentro del alcance melee
	var mejor_objetivo: Node3D = null
	var menor_dist: float = INF

	for grupo in ["enemies", "enemigos"]:
		for objetivo in get_tree().get_nodes_in_group(grupo):
			if not is_instance_valid(objetivo) or not (objetivo is Node3D):
				continue
			if objetivo == self:
				continue
			var victima := objetivo as Node3D
			var dx: float = absf(global_position.x - victima.global_position.x)
			if dx > alcance_melee:
				continue
			if absf(victima.global_position.z - global_position.z) > margen_z_melee:
				continue
			if "health" in victima and int(victima.get("health")) <= 0:
				continue
			if (victima.has_method("recibir_golpe_melee") or victima.has_method("take_damage") or victima.has_method("recibir_golpe")) and dx < menor_dist:
				menor_dist = dx
				mejor_objetivo = victima

	if is_instance_valid(mejor_objetivo):
		if "last_hit_position" in mejor_objetivo:
			mejor_objetivo.set("last_hit_position", mejor_objetivo.global_position)
		if "ultimo_atacante" in mejor_objetivo:
			mejor_objetivo.set("ultimo_atacante", self)
		if mejor_objetivo.has_method("recibir_golpe_melee"):
			mejor_objetivo.call("recibir_golpe_melee", float(dano_cuerpo_a_cuerpo), self)
		elif mejor_objetivo.has_method("take_damage"):
			mejor_objetivo.call("take_damage", dano_cuerpo_a_cuerpo)
		elif mejor_objetivo.has_method("recibir_golpe"):
			mejor_objetivo.call("recibir_golpe", float(dano_cuerpo_a_cuerpo))


# === PROTECCIÓN DE ALIADOS (protagonista y defensoras) ===
func _aliado_vivo(nodo: Node) -> bool:
	if not is_instance_valid(nodo) or not (nodo is Node3D):
		return false
	if not (nodo as Node3D).is_inside_tree():
		return false
	if "health" in nodo and int(nodo.get("health")) <= 0:
		return false
	if nodo is EnemyBase:
		return false
	return true


func _buscar_aliado_a_proteger() -> void:
	if get_tree() == null:
		aliado_protegido = null
		return
	var mejor_aliado: Node3D = null
	var menor_distancia: float = INF

	for grupo in ["player", "allies", "defensoras"]:
		for aliado in get_tree().get_nodes_in_group(grupo):
			if aliado == self or not _aliado_vivo(aliado):
				continue
			var punto_proteccion_x: float = min((aliado as Node3D).global_position.x - distancia_proteccion, zona_roja_max_x)
			var dist: float = abs(punto_proteccion_x - global_position.x)
			if dist < menor_distancia:
				menor_distancia = dist
				mejor_aliado = aliado as Node3D

	aliado_protegido = mejor_aliado


func _buscar_otro_enemigo_cercano() -> Node3D:
	if get_tree() == null:
		return null
	var candidato_otro: Node3D = null
	var dist_min_otro: float = INF
	var candidato_mismo: Node3D = null
	var dist_min_mismo: float = INF

	for grupo in ["player", "allies", "defensoras"]:
		for aliado in get_tree().get_nodes_in_group(grupo):
			if aliado == self or not _aliado_vivo(aliado):
				continue

			var punto_proteccion_x: float = min((aliado as Node3D).global_position.x - distancia_proteccion, zona_roja_max_x)
			var dist: float = abs(punto_proteccion_x - global_position.x)

			if aliado != aliado_protegido:
				if dist < dist_min_otro:
					dist_min_otro = dist
					candidato_otro = aliado as Node3D
			else:
				if dist < dist_min_mismo:
					dist_min_mismo = dist
					candidato_mismo = aliado as Node3D

	if candidato_otro != null:
		return candidato_otro
	return candidato_mismo


# === DAÑO Y MUERTE (sin daño crítico: la API existe por compatibilidad) ===
## Siempre retorna false: este defensor no tiene momento vulnerable.
func es_momento_golpe_critico() -> bool:
	return false


func take_damage(amount: float, golpe_en_escudo: bool = false) -> void:
	if inmortal:
		return
	if current_state == State.DYING or current_state == State.DEAD:
		return

	var dano_total: float = amount
	health -= int(dano_total)

	if health <= 0:
		health = 0
		murio_por_critico = false
		_cambiar_estado(State.DYING)
	else:
		if golpe_en_escudo:
			_flash_impacto_escudo()
		else:
			_spawn_sangre_no_letal()
		if current_state == State.DEFENDING:
			_cambiar_estado(State.SHIELD_HIT)


func recibir_golpe(amount: float = 1.0) -> void:
	take_damage(amount, false)


## Bloqueo de melee con riposta: si el modo riposta está activo, el tajo se
## bloquea sin daño y cada N bloqueos contrataca con espada (solo con enemigo
## a melee en su rango). Retorna true si bloqueó.
func recibir_golpe_melee(amount: float, atacante: Node = null) -> bool:
	if current_state == State.DYING or current_state == State.DEAD:
		return false
	if amount <= 0.0:
		return false
	if inmortal:
		_registrar_bloqueo()
		return true
	if riposta_cada_bloqueos <= 0:
		take_damage(amount, false)
		return false
	_registrar_bloqueo()
	return true


func _registrar_bloqueo() -> void:
	if current_state == State.DYING or current_state == State.DEAD:
		return
	_bloqueos_acumulados += 1
	_flash_impacto_escudo()
	if current_state != State.ATTACKING:
		_cambiar_estado(State.SHIELD_HIT)
	if riposta_cada_bloqueos > 0 and _bloqueos_acumulados >= riposta_cada_bloqueos \
			and _enemigo_en_alcance_melee():
		_bloqueos_acumulados = 0
		_cambiar_estado(State.ATTACKING)


func recibir_golpe_escudo(amount: float = 1.0) -> void:
	take_damage(amount, true)


func _morir() -> void:
	velocity = Vector3.ZERO
	_play_anim("Muerte", 0.2, 1.0)
	AudioManager.play_sfx("imp_death")
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if is_instance_valid(col):
		col.set_deferred("disabled", true)
	_start_dissolve()


func _flash_impacto() -> void:
	if _flash_mat == null:
		_flash_mat = StandardMaterial3D.new()
		_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)

	for mesh in _cuerpo_meshes:
		if is_instance_valid(mesh):
			mesh.material_overlay = _flash_mat

	await get_tree().create_timer(0.08, false).timeout

	for mesh in _cuerpo_meshes:
		if is_instance_valid(mesh):
			mesh.material_overlay = null


func _flash_impacto_escudo() -> void:
	if current_state == State.DYING or current_state == State.DEAD:
		return
	_play_anim("Bloqueo escudo", 0.1, 1.1)


func _spawn_sangre() -> void:
	if SANGRE_SCENE:
		var sangre: Node3D = SANGRE_SCENE.instantiate() as Node3D
		if sangre:
			var target_parent = get_tree().current_scene if get_tree() else get_parent()
			target_parent.add_child(sangre)
			var pos_sangre = last_hit_position if last_hit_position != Vector3.ZERO else global_position + Vector3(0.0, 0.5, 0.0)
			sangre.global_position = pos_sangre


func _mostrar_texto_critico() -> void:
	var lbl := Label3D.new()
	lbl.text = tr("CRITICO")
	lbl.font_size = 48
	lbl.pixel_size = 0.003
	lbl.modulate = Color(1.0, 0.1, 0.1, 1.0)
	lbl.outline_size = 0
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	var root := get_tree().current_scene
	if not root:
		root = get_tree().root
	root.add_child(lbl)
	lbl.global_position = global_position + Vector3(0.0, 2.0, 0.0)
	var tw := lbl.create_tween().set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y + 0.6, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_LINEAR)
	tw.chain().tween_callback(func():
		if is_instance_valid(lbl):
			lbl.queue_free()
	)


func _spawn_sangre_no_letal() -> void:
	if SANGRE_NO_LETAL_SCENE:
		var sangre: Node3D = SANGRE_NO_LETAL_SCENE.instantiate() as Node3D
		if sangre:
			var target_parent = get_tree().current_scene if get_tree() else get_parent()
			if not target_parent:
				target_parent = self
			target_parent.add_child(sangre)
			var pos_sangre = last_hit_position if last_hit_position != Vector3.ZERO else global_position + Vector3(0.0, 0.5, 0.0)
			if sangre.has_method("setup"):
				sangre.setup(pos_sangre, last_hit_direction)
			elif sangre is Node3D:
				sangre.global_position = pos_sangre


## Enemigos en alcance de tajo para el modo estático.
func _enemigo_en_alcance_melee() -> bool:
	if get_tree() == null:
		return false
	for grupo in ["enemies", "enemigos"]:
		for objetivo in get_tree().get_nodes_in_group(grupo):
			if not is_instance_valid(objetivo) or not (objetivo is Node3D):
				continue
			if objetivo == self:
				continue
			var victima := objetivo as Node3D
			var dx: float = absf(global_position.x - victima.global_position.x)
			if dx > alcance_melee + 0.3:
				continue
			if absf(victima.global_position.z - global_position.z) > margen_z_melee:
				continue
			if "health" in victima and int(victima.get("health")) <= 0:
				continue
			return true
	return false


func _start_dissolve() -> void:
	if _is_dissolving:
		return
	_is_dissolving = true

	var meshes: Array[Node] = find_children("*", "MeshInstance3D", true, false)
	for m in meshes:
		var mesh := m as MeshInstance3D
		if not is_instance_valid(mesh):
			continue
		if mesh.find_parent("BoneAttachment_Escudo") != null:
			continue
		var mat := ShaderMaterial.new()
		mat.shader = DISSOLVE_SHADER
		mat.set_shader_parameter("dissolve_amount", 0.0)
		mat.set_shader_parameter("glow_color", color_borde_disolucion)
		mat.set_shader_parameter("glow_intensity", 8.0)
		mat.set_shader_parameter("edge_thickness", 0.05)
		mat.set_shader_parameter("noise_scale", 20.0)

		var orig: Material = mesh.material_override
		if orig == null and mesh.mesh != null and mesh.mesh.get_surface_count() > 0:
			orig = mesh.mesh.surface_get_material(0)
		if orig is StandardMaterial3D:
			var tex: Texture2D = (orig as StandardMaterial3D).albedo_texture
			if tex:
				mat.set_shader_parameter("albedo_texture", tex)
			var col: Color = (orig as StandardMaterial3D).albedo_color
			mat.set_shader_parameter("albedo_tint", Vector3(col.r, col.g, col.b))

		mesh.material_override = mat
		_dissolve_materials.append(mat)

	var tween: Tween = create_tween()
	tween.tween_method(_update_dissolve, 0.0, 1.0, DURACION_DISOLUCION)
	tween.tween_callback(_finish_dissolve)


func _update_dissolve(val: float) -> void:
	for mat in _dissolve_materials:
		if is_instance_valid(mat) and mat is ShaderMaterial:
			mat.set_shader_parameter("dissolve_amount", val)


func _finish_dissolve() -> void:
	died.emit()
	queue_free()


# === ANIMACIÓN Y MATERIALES ===
func _setup_anim_player() -> void:
	var players = find_children("*", "AnimationPlayer", true, false)
	for p in players:
		var player := p as AnimationPlayer
		if player.has_animation("Ataque") or player.has_animation("Idle"):
			anim_player = player
			break

	if anim_player:
		for anim_name in anim_player.get_animation_list():
			if "Correr" in anim_name or "Caminar" in anim_name or "Idle" in anim_name:
				var a = anim_player.get_animation(anim_name)
				if a:
					a.loop_mode = Animation.LOOP_LINEAR


func _setup_materiales() -> void:
	_cuerpo_meshes.clear()

	var all_meshes: Array[Node] = find_children("*", "MeshInstance3D", true, false)
	for m in all_meshes:
		var mesh := m as MeshInstance3D
		if not mesh.is_in_group("outline_meshes"):
			mesh.add_to_group("outline_meshes")
		if mesh.find_parent("BoneAttachment_Escudo") != null:
			continue
		if mesh.find_parent("EspadaImperial") != null:
			continue
		mesh.material_override = MAT_IMPERIO
		_cuerpo_meshes.append(mesh)

	_aplicar_material_espada()


func _aplicar_material_espada() -> void:
	var espada := find_child("EspadaImperial", true, false)
	if not is_instance_valid(espada):
		return
	for m in (espada as Node).find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if is_instance_valid(mi):
			mi.material_override = MAT_ESPADA
			if mi.mesh != null and mi.mesh.get_surface_count() > 0:
				mi.set_surface_override_material(0, MAT_ESPADA)


## Textura élfica al escudo salvo que pongas la tuya a mano
## (material_override en el editor): el gris importado del GLB sí se reemplaza.
func _aplicar_material_escudo_elfico(escudo: Node) -> void:
	if not is_instance_valid(escudo):
		return
	for m in (escudo as Node).find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if not is_instance_valid(mi) or mi.mesh == null:
			continue
		if mi.material_override != null:
			continue
		mi.material_override = MAT_ESCUDO_ELFICO
		if mi.mesh.get_surface_count() > 0:
			mi.set_surface_override_material(0, MAT_ESCUDO_ELFICO)


func _obtener_rotacion_derecha() -> float:
	return rotacion_y_puesto if estatico else rotacion_y_modelo


func _asegurar_orientacion_derecha() -> void:
	if is_instance_valid(model_root):
		var rot_deseada: float = _obtener_rotacion_derecha()
		if absf(model_root.rotation_degrees.y - rot_deseada) > 0.05:
			model_root.rotation_degrees.y = rot_deseada


func _aplicar_rotacion_modelo() -> void:
	_asegurar_orientacion_derecha()


func _play_anim(anim_name: String, blend_time: float = 0.2, speed: float = 1.0) -> void:
	if not anim_player:
		return
	if anim_player.has_animation(anim_name):
		anim_player.play(anim_name, blend_time, speed)
		return
	var anim_name_lower := anim_name.to_lower()
	for a in anim_player.get_animation_list():
		var a_lower := a.to_lower()
		if a_lower == anim_name_lower or anim_name_lower in a_lower:
			anim_player.play(a, blend_time, speed)
			return
