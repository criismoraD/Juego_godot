class_name BalsaPirataCombate
extends BalsaPirata

## Balsa pirata de combate: plataforma flotante hostil que navega de derecha
## a izquierda. Hereda de BalsaPirata la flotación sinusoidal y la destrucción
## completa del nivel 5 (maderos, explosiones y hundimiento).
## - Se activa (flota, navega y despliega) solo al entrar en cámara.
## - La tripulación aparece ya posicionada en sus puestos (sin caminata) con el
##   mismo selector y mezcla del submarino (imp, pirata, arquera, embajador).
## - Se hunde si mueren todos los tripulantes o si el casco recibe 16 de daño.

signal enemigo_desplegado(enemigo: Node3D)
signal todos_tripulantes_muertos

enum TipoEnemigo {
	IMP,
	PIRATA_GOBLIN,
	GOBLIN_ARQUERA,
	PIRATA,
	IMP_EMBAJADOR
}

const ESCENA_IMP: String = "res://Entities/Enemigo_Imp/ImpEnemy.tscn"
const ESCENA_GOBLIN_ARQUERA: String = "res://Entities/Enemigo_Goblin_Girl/GoblinGirl.tscn"
const ESCENA_GOBLIN_BASE: String = "res://Entities/Enemigo_Goblin/Goblin.tscn"
const ESCENA_PIRATA: String = "res://Entities/Enemigo_Pirata_Goblin/PirataGoblin.tscn"
const ESCENA_IMP_EMBAJADOR: String = "res://Entities/Enemigo_Imp_Estandarte/ImpEnemyEstandarte.tscn"

@export_category("Activación por Cámara")
@export var activar_al_entrar_en_camara: bool = true  ## Flota, navega y despliega solo en cuadro
@export var distancia_activacion_x: float = 7.0  ## MAYOR que el freno de la canoa (5.4m): despierta y se agrupa antes de que ella deba frenar

@export_category("Navegación de Combate")
@export var navegar_al_activar: bool = true  ## Al activarse navega de derecha a izquierda
@export var x_destino_navegacion: float = -30.0  ## Punto de parada (menor = más a la izquierda)
@export var velocidad_navegacion_combate: float = 0.8  ## Velocidad horizontal (m/s), crucero lento
@export var distancia_frenado_canoa: float = 6.0  ## Desde aquí baja la velocidad ante la canoa
@export var distancia_detencion_canoa: float = 3.5  ## Aquí se detiene del todo (no la sobrepasa)
@export var nodo_referencia_frenado: Node3D = null  ## Arrastra aquí la canoa/jugadora (vacío = detección automática)

@export_category("Tripulación Enemiga")
@export var tipo_enemigo: TipoEnemigo = TipoEnemigo.GOBLIN_ARQUERA  ## Tipo único si la mezcla está vacía
@export_range(0, 6, 1) var cantidad_enemigos: int = 0  ## Total en modo de tipo único
@export_range(0, 6, 1) var cantidad_imp: int = 0
@export_range(0, 6, 1) var cantidad_pirata: int = 0
@export_range(0, 6, 1) var cantidad_goblin_arquera: int = 0
@export_range(0, 6, 1) var cantidad_imp_embajador: int = 0
@export var mezclar_orden_aleatorio: bool = true  ## Si false, salen agrupados por tipo
@export var intervalo_spawn: float = 1.0  ## Segundos entre apariciones en sus puestos
@export var escena_pirata_custom: PackedScene = null

@export_category("Cubierta (Puestos)")
@export var semi_ancho_cubierta: float = 0.5  ## Mitad útil de cubierta en X local (±0.54 real)
@export var margen_puestos: float = 0.08  ## Margen libre en cada borde
@export var altura_cubierta: float = 0.12  ## Altura Y local donde pisan los tripulantes
@export var separacion_puestos: float = 0.22  ## Distancia mínima entre puestos
@export var margen_bloqueo_proa: float = 3.0  ## La canoa se detiene antes de tocar el casco

@export_category("Vida del Casco")
@export var vida_maxima: float = 16.0  ## Impactos que aguanta antes de destruirse

@export_category("Desintegración del Casco")
@export var color_borde_balsa: Color = Color(1.0, 0.5, 0.2)  ## Brillo del borde al desintegrarse, como enemigos
@export var factor_oscurecer_casco: float = 0.45  ## El modelo se oscurece a esta fracción al destruirse
@export var duracion_desintegracion_casco: float = 4.0  ## Debe terminar antes del hundimiento (5.5s)

const SHADER_DISOLVER: Shader = preload("res://System/Shaders/dissolve.gdshader")

var vida_actual: float = 16.0
var _activa: bool = false  ## Ya entró en cámara y opera
var _canoa_ref: Node3D = null  ## Referencia de frenado (jugadora o canoa, cacheada)
var _aviso_freno_dado: bool = false  ## Para diagnosticar una sola vez en Salida
var _mats_desintegracion: Array = []  ## Materiales de disolver del casco en curso
var _cola_mezcla: Array = []  ## Cola de TipoEnemigo por desplegar
var _total_tripulacion: int = 0
var _timer_spawn: float = 0.0
var _enemigos_vivos: Array[Node3D] = []


func _ready() -> void:
	# La balsa de combate respeta la rotación del editor tal cual (sin el giro
	# de proa de la balsa ambiental, que la volteaba al ejecutar).
	rotacion_y_proa = 0.0
	super._ready()
	vida_actual = vida_maxima
	if is_in_group("enemies"):
		remove_from_group("enemies")
	if is_in_group("enemigos"):
		remove_from_group("enemigos")
	# El _process SIEMPRE corre: antes de activarse solo vigila la cámara.
	set_process(true)


func _process(delta: float) -> void:
	if _destruida:
		return
	if not _activa:
		_procesar_activacion_camara()
		return
	super._process(delta)
	if _destruida:
		return
	if _navegando:
		_moderar_marcha_ante_canoa()
	_fijar_tripulacion_puestos()
	_procesar_spawn_tripulacion(delta)


## Clava a la tripulación viva en su puesto LOCAL (viaja con la balsa: los
## empujones y la navegación no la sacan del deck). A los moribundos no se les
## toca: caen y se disuelven con normalidad.
func _fijar_tripulacion_puestos() -> void:
	for e in _enemigos_vivos:
		if not is_instance_valid(e) or e.is_queued_for_deletion():
			continue
		if not (e is Node3D):
			continue
		if not e.has_meta("puesto_balsa"):
			continue
		if "health" in e and float(e.get("health")) <= 0.0:
			continue
		if e.get("is_dead") == true or e.get("is_dying") == true:
			continue
		if e is EnemyBase:
			var st: int = (e as EnemyBase).current_state
			if st == EnemyBase.State.DYING or st == EnemyBase.State.DEAD:
				continue
		var puesto: Vector3 = e.get_meta("puesto_balsa")
		(e as Node3D).global_position = to_global(puesto)


## Baja la velocidad al acercarse a la canoa y se detiene del todo antes de
## alcanzarla (no la sobrepasa mientras navega). Referencia robusta: la
## jugadora viaja dentro de la canoa (grupo "player", como todo enemigo);
## si no hay jugadora, recurre a la canoa por clase.
func _moderar_marcha_ante_canoa() -> void:
	if not is_instance_valid(_canoa_ref):
		if is_instance_valid(nodo_referencia_frenado):
			_canoa_ref = nodo_referencia_frenado
		else:
			_canoa_ref = _buscar_referencia_frenado()
		if not is_instance_valid(_canoa_ref):
			_velocidad_navegacion = velocidad_navegacion_combate
			return
	var dx: float = global_position.x - _canoa_ref.global_position.x
	if dx < 0.0:
		_velocidad_navegacion = velocidad_navegacion_combate
		return
	var rango: float = maxf(distancia_frenado_canoa - distancia_detencion_canoa, 0.1)
	var factor: float = clampf((dx - distancia_detencion_canoa) / rango, 0.0, 1.0)
	if factor <= 0.0:
		if not _aviso_freno_dado:
			_aviso_freno_dado = true
			print("[BalsaPirataCombate] Detenida ante la canoa en x=", snappedf(global_position.x, 0.1))
		detener_navegacion()
	else:
		_velocidad_navegacion = velocidad_navegacion_combate * factor


## Jugadora primero (robusto), canoa por clase como respaldo.
func _buscar_referencia_frenado() -> Node3D:
	if get_tree() != null:
		var jugador := get_tree().get_first_node_in_group("player") as Node3D
		if is_instance_valid(jugador):
			return jugador
	return _buscar_canoa()


## Localiza la canoa protagonista por clase (no va en grupos).
func _buscar_canoa() -> Node3D:
	if get_tree() == null or get_tree().root == null:
		return null
	var pila: Array[Node] = get_tree().root.get_children()
	while not pila.is_empty():
		var n: Node = pila.pop_back()
		if n is CanoaProtagonistaRio:
			return n as Node3D
		pila.append_array(n.get_children())
	return null


## Activa la balsa: flota, navega y empieza a desplegar tripulación.
func activar() -> void:
	if _activa or _destruida:
		return
	_activa = true
	print("[BalsaPirataCombate] Activada en x=", snappedf(global_position.x, 0.1))
	_construir_cola_mezcla()
	flotar()
	if navegar_al_activar:
		navegar_hacia_x(x_destino_navegacion, velocidad_navegacion_combate)
	add_to_group("enemies")
	add_to_group("enemigos")


## Daño por impactos (flechas, hachas): a 0 se destruye como en el nivel 5.
func take_damage(amount: float) -> void:
	if _destruida or not _activa:
		return
	vida_actual -= maxf(amount, 0.0)
	if vida_actual <= 0.0:
		_hundir_por_dano()


func recibir_dano(amount: int) -> void:
	take_damage(float(amount))


## Destrucción con desintegración enemiga: primero la secuencia heredada del
## nivel 5 (maderos, explosiones, hundimiento) y encima el modelo se oscurece
## y se disuelve como los enemigos.
func destruir_balsa() -> void:
	if _destruida:
		return
	super.destruir_balsa()
	if not is_inside_tree():
		return
	_aplicar_desintegracion_casco()


## Cubre las mallas del casco con el shader de disolver (textura original
## oscurecida + borde de color) y lo anima hasta desaparecer.
func _aplicar_desintegracion_casco() -> void:
	if not is_instance_valid(SHADER_DISOLVER):
		return
	_mats_desintegracion.clear()
	for m in find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi == null or not is_instance_valid(mi):
			continue
		var mat := ShaderMaterial.new()
		mat.shader = SHADER_DISOLVER
		mat.set_shader_parameter("dissolve_amount", 0.0)
		mat.set_shader_parameter("glow_color", color_borde_balsa)
		mat.set_shader_parameter("glow_intensity", 6.0)
		mat.set_shader_parameter("edge_thickness", 0.05)
		mat.set_shader_parameter("noise_scale", 20.0)
		var orig: Material = mi.material_override
		if orig == null:
			orig = mi.get_surface_override_material(0)
		if orig == null and mi.mesh:
			orig = mi.mesh.surface_get_material(0)
		if orig is StandardMaterial3D:
			var std_mat := orig as StandardMaterial3D
			if std_mat.albedo_texture:
				mat.set_shader_parameter("albedo_texture", std_mat.albedo_texture)
			var col := std_mat.albedo_color
			var f: float = clampf(factor_oscurecer_casco, 0.05, 1.0)
			mat.set_shader_parameter("albedo_tint", Vector3(col.r * f, col.g * f, col.b * f))
		mi.material_override = mat
		_mats_desintegracion.append(mat)
	if _mats_desintegracion.is_empty() or get_tree() == null:
		return
	var tw := create_tween()
	tw.tween_method(
		func(val: float):
			for sm in _mats_desintegracion:
				if is_instance_valid(sm):
					sm.set_shader_parameter("dissolve_amount", val)
	, 0.0, 1.0, maxf(duracion_desintegracion_casco, 0.5))


## Retorna true si la balsa opera como obstáculo hostil.
func es_enemigo_activo() -> bool:
	return _activa and not _destruida


## Arma la cola de despliegue: mezcla por cantidades o modo de tipo único.
func _construir_cola_mezcla() -> void:
	_cola_mezcla.clear()
	for i in range(maxi(cantidad_imp, 0)):
		_cola_mezcla.append(TipoEnemigo.IMP)
	for i in range(maxi(cantidad_pirata, 0)):
		_cola_mezcla.append(TipoEnemigo.PIRATA)
	for i in range(maxi(cantidad_goblin_arquera, 0)):
		_cola_mezcla.append(TipoEnemigo.GOBLIN_ARQUERA)
	for i in range(maxi(cantidad_imp_embajador, 0)):
		_cola_mezcla.append(TipoEnemigo.IMP_EMBAJADOR)
	if _cola_mezcla.is_empty():
		for i in range(maxi(cantidad_enemigos, 0)):
			_cola_mezcla.append(tipo_enemigo)
	elif mezclar_orden_aleatorio:
		_cola_mezcla.shuffle()
	_total_tripulacion = _cola_mezcla.size()


func _procesar_activacion_camara() -> void:
	if not activar_al_entrar_en_camara:
		return
	var cam := _obtener_camara_activa()
	if cam == null:
		return
	var dx: float = global_position.x - cam.global_position.x
	if dx <= distancia_activacion_x and dx >= -8.0:
		activar()


func _procesar_spawn_tripulacion(delta: float) -> void:
	_asegurar_combate_tripulacion()
	if _cola_mezcla.is_empty():
		if _enemigos_vivos.is_empty():
			_tripulacion_exterminada()
		return
	_timer_spawn -= delta
	if _timer_spawn <= 0.0:
		_timer_spawn = intervalo_spawn
		_spawnear_tripulante()


## Perro guardián: quien siga en WALKING (entrada a combate perdida por el
## motivo que sea) entra a SHOOTING. Solo toca WALKING, jamás un ciclo en curso.
func _asegurar_combate_tripulacion() -> void:
	for e in _enemigos_vivos:
		if not is_instance_valid(e) or e.is_queued_for_deletion():
			continue
		if e is EnemyBase and (e as EnemyBase).current_state == EnemyBase.State.WALKING:
			_iniciar_combate_tripulante(e)


func _spawnear_tripulante() -> void:
	if _cola_mezcla.is_empty():
		return
	var tipo: TipoEnemigo = _cola_mezcla.pop_front()
	var packed := _resolver_escena_enemigo(tipo)
	if not packed:
		return
	var enemigo_inst: Node = packed.instantiate()
	if not (enemigo_inst is Node3D):
		enemigo_inst.queue_free()
		return
	var enemigo := enemigo_inst as Node3D
	_preconfigurar_tripulante(enemigo)
	var padre_destino: Node = get_parent() if get_parent() else self
	padre_destino.add_child(enemigo)
	# Aparece ya posicionado en su puesto (sin caminata de llegada).
	# El puesto se guarda en LOCAL de la balsa para viajar con ella.
	var puesto_local: Vector3 = _puesto_local(_cola_mezcla.size())
	enemigo.global_position = to_global(puesto_local)
	# Embarcado: sigue el vaivén y la navegación de la balsa
	enemigo.reparent(self)
	enemigo.set_meta("puesto_balsa", puesto_local)
	_configurar_tripulante_para_rio(enemigo)
	_iniciar_combate_tripulante(enemigo)
	_enemigos_vivos.append(enemigo)
	enemigo.tree_exited.connect(_verificar_tripulacion)
	enemigo_desplegado.emit(enemigo)


## Puesto en LOCAL de la balsa para los que faltan por spawnear (centrados y separados).
func _puesto_local(restantes_despues: int) -> Vector3:
	var total: int = maxi(_total_tripulacion, 1)
	var indice: int = total - 1 - restantes_despues
	var x: float = 0.0
	if total > 1:
		x = (float(indice) - float(total - 1) * 0.5) * separacion_puestos
	var limite: float = maxf(semi_ancho_cubierta - margen_puestos, 0.0)
	x = clampf(x, -limite, limite)
	return Vector3(x, altura_cubierta, 0.0)


func _resolver_escena_enemigo(tipo: TipoEnemigo) -> PackedScene:
	match tipo:
		TipoEnemigo.IMP:
			if ResourceLoader.exists(ESCENA_IMP):
				return load(ESCENA_IMP) as PackedScene
		TipoEnemigo.PIRATA_GOBLIN:
			if escena_pirata_custom != null:
				return escena_pirata_custom
			if ResourceLoader.exists(ESCENA_GOBLIN_BASE):
				return load(ESCENA_GOBLIN_BASE) as PackedScene
		TipoEnemigo.GOBLIN_ARQUERA:
			if ResourceLoader.exists(ESCENA_GOBLIN_ARQUERA):
				return load(ESCENA_GOBLIN_ARQUERA) as PackedScene
		TipoEnemigo.PIRATA:
			if ResourceLoader.exists(ESCENA_PIRATA):
				return load(ESCENA_PIRATA) as PackedScene
		TipoEnemigo.IMP_EMBAJADOR:
			if ResourceLoader.exists(ESCENA_IMP_EMBAJADOR):
				return load(ESCENA_IMP_EMBAJADOR) as PackedScene
	if ResourceLoader.exists(ESCENA_GOBLIN_ARQUERA):
		return load(ESCENA_GOBLIN_ARQUERA) as PackedScene
	return null


func _preconfigurar_tripulante(enemigo: Node3D) -> void:
	if "distancia_minima_caminar" in enemigo:
		enemigo.set("distancia_minima_caminar", 0.0)
	if "distancia_maxima_caminar" in enemigo:
		enemigo.set("distancia_maxima_caminar", 0.0)
	if "velocidad_caminar" in enemigo:
		enemigo.set("velocidad_caminar", 0.0)
	if "solo_atacar_en_pantalla" in enemigo:
		enemigo.set("solo_atacar_en_pantalla", true)
	if "activar_al_entrar_en_camara" in enemigo:
		enemigo.set("activar_al_entrar_en_camara", false)


func _configurar_tripulante_para_rio(enemigo: Node3D) -> void:
	enemigo.add_to_group("enemies")
	if "solo_atacar_en_pantalla" in enemigo:
		enemigo.set("solo_atacar_en_pantalla", true)
	if "activar_al_entrar_en_camara" in enemigo:
		enemigo.set("activar_al_entrar_en_camara", false)
	if "_dormida_por_camara" in enemigo:
		enemigo.set("_dormida_por_camara", false)
	if "_dormido_por_camara" in enemigo:
		enemigo.set("_dormido_por_camara", false)

	enemigo.set_physics_process(true)
	enemigo.set_process(true)

	var cam := _obtener_camara_activa()
	if cam and "_camara_cache_pantalla" in enemigo:
		enemigo.set("_camara_cache_pantalla", cam)

func _iniciar_combate_tripulante(enemigo: Node3D) -> void:
	if not is_instance_valid(enemigo):
		return
	# Miran y atacan hacia la marcha: a la izquierda si navega a -X, a la
	# derecha si navega a +X (relativo a la rotación del editor de la balsa).
	# Quieta: hacia el lado de la jugadora/canoa, izquierda por defecto.
	# Igual que el submarino: 0.0/PI para todos, piratas incluidos.
	var dir: float = _direccion_navegacion if _navegando else -1.0
	if not _navegando and is_instance_valid(_canoa_ref):
		dir = 1.0 if _canoa_ref.global_position.x >= global_position.x else -1.0
	var yaw_mundo: float = 0.0 if dir < 0.0 else PI
	enemigo.rotation.y = wrapf(yaw_mundo - rotation.y, -PI, PI)
	if enemigo is EnemyBase:
		var eb := enemigo as EnemyBase
		if eb.current_state >= EnemyBase.State.DYING:
			return
		eb.velocidad_caminar = 0.0
		eb.target_walk_distance = 0.0
		eb.walked_distance = 1.0
		eb._change_state(EnemyBase.State.SHOOTING)
	elif enemigo.has_method("_change_state"):
		enemigo.call("_change_state", 1)


func _verificar_tripulacion() -> void:
	var vivos: Array[Node3D] = []
	for e in _enemigos_vivos:
		if is_instance_valid(e) and not e.is_queued_for_deletion():
			var muerto: bool = false
			if "health" in e and float(e.get("health")) <= 0.0:
				muerto = true
			if e.get("is_dead") == true or e.get("is_dying") == true:
				muerto = true
			if not muerto:
				vivos.append(e)
	_enemigos_vivos = vivos
	if _enemigos_vivos.is_empty() and _cola_mezcla.is_empty():
		_tripulacion_exterminada()


func _tripulacion_exterminada() -> void:
	if _destruida:
		return
	todos_tripulantes_muertos.emit()
	_remover_grupos()
	destruir_balsa()


func _hundir_por_dano() -> void:
	if _destruida:
		return
	_remover_grupos()
	destruir_balsa()


func _remover_grupos() -> void:
	if is_in_group("enemies"):
		remove_from_group("enemies")
	if is_in_group("enemigos"):
		remove_from_group("enemigos")
	for e in _enemigos_vivos:
		if is_instance_valid(e):
			if e.is_in_group("enemies"):
				e.remove_from_group("enemies")
			if e.is_in_group("enemigos"):
				e.remove_from_group("enemigos")


func _obtener_camara_activa() -> Camera3D:
	if get_viewport():
		var cam := get_viewport().get_camera_3d()
		if cam:
			return cam
	var cam_main = get_tree().get_first_node_in_group("camara_principal") if get_tree() else null
	if cam_main is Camera3D:
		return cam_main as Camera3D
	return null
