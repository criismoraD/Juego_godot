class_name CanoaProtagonistaRio
extends CanoaAliada

## Canoa aliada que transporta a la protagonista en travesía fluvial continua hacia la derecha.
## Hereda toda la cinemática de flotación sinusoidal y balanceo sobre el agua de CanoaAliada.
## Modula su velocidad automáticamente ante la presencia o contacto de enemigos en el cauce.

# === CONSTANTES ===
const Y_PISO_CANOA: float = 0.3  ## Altura del piso de la canoa donde se posa la protagonista
const OFFSET_MINIMO_DETECCION_X: float = -1.0  ## Límite detrás de la canoa para descartar enemigos superados
const MULTIPLICADOR_PITCH_CAUTELOSO: float = 0.85  ## Ritmo de remada más lento ante presencia de enemigos
const MARGEN_HISTERESIS_CONTACTO: float = 0.5  ## Margen para evitar oscilaciones por el oleaje y deriva horizontal
const VELOCIDAD_CORRECCION_FRENO: float = 8.0  ## Velocidad de retroceso continuo al corregir sobrepaso (m/s, sin saltos)

# === EXPORTS ===
@export_category("Travesía Fluvial")
@export var velocidad_avance: float = 0.65  ## Velocidad de avance horizontal hacia la derecha (m/s)
@export var navegacion_continua: bool = true  ## Si true, navega permanentemente hacia la derecha
@export var limite_derecho_reinicio: float = 14.0  ## Si supera esta X, reaparece suavemente por la izquierda si es cíclico
@export var limite_izquierdo_reinicio: float = -14.0
@export var es_ciclica: bool = false  ## Si true, reinicia su posición en X al salir de pantalla

@export_category("Reacción a Enemigos")
@export var modular_velocidad_por_enemigos: bool = true  ## Si true, reduce velocidad ante presencia y se frena ante contacto con enemigos
@export var distancia_presencia_enemigos: float = 8.0  ## Distancia en X adelante para detectar presencia y reducir velocidad
@export var distancia_contacto_enemigos: float = 2.4  ## Distancia en X proa-enemigo para detenerse por completo
@export var factor_velocidad_presencia: float = 0.5  ## Multiplicador de velocidad al estar en presencia de enemigos (50%)
@export var margen_profundidad_z_enemigos: float = 4.0  ## Rango en Z para considerar que un enemigo está en el cauce del río

@export_category("Tramo Fluvial Acelerado")
@export var aceleracion_tramo_activa: bool = true  ## Si true, la canoa acelera automáticamente en el tramo si no hay enemigos
@export var x_inicio_tramo_aceleracion: float = 60.395  ## X de inicio (PuenteMaderaParaPosicionar8 aceleracion)
@export var x_fin_tramo_aceleracion: float = 126.01  ## X de fin (BarcoCombatePirata3 Check point)
@export var velocidad_tramo_acelerado: float = 1.8  ## Velocidad acelerada en el tramo cuando no detecta enemigos (m/s)

@export_category("Pasajera (Protagonista)")
@export var limitar_pasajera_a_canoa: bool = true  ## Si true, la protagonista no puede salir de la canoa al moverse
@export var limite_pasajera_x: Vector2 = Vector2(-0.5, 0.4)  ## Rango local X donde puede moverse
@export var limite_pasajera_z: Vector2 = Vector2(-0.15, 0.15)  ## Rango local Z donde puede moverse

@export_category("Sonido de Travesía (sonido_canoa_por_el_rio)")
## Control directo del volumen del sonido de la canoa en el Inspector (dB)
@export_range(-30.0, 12.0, 0.5) var volumen_sonido_canoa_db: float = -3.0:
	set(v):
		volumen_sonido_canoa_db = v
		volumen_navegacion_db = v

## Tono / pitch del sonido de navegación
@export_range(0.5, 2.0, 0.05) var pitch_sonido_canoa: float = 1.0:
	set(v):
		pitch_sonido_canoa = v
		pitch_navegacion = v

# === VARIABLES PRIVADAS ===
var _factor_velocidad_actual: float = 1.0
var _detenida_por_contacto: bool = false
var _enemigo_bloqueando: Node3D = null
var _enemigos_en_area_contacto: Array[Node3D] = []
## Control manual del viento (debug Z): mientras está activo, el automatismo no lo pisa.
var _viento_manual_debug: bool = false

# === ONREADY ===
@onready var pasajera: Node3D = find_child("Protagonista", true, false) as Node3D
@onready var efecto_viento: EfectoVientoCanoa = find_child("EfectoVientoCanoa", true, false) as EfectoVientoCanoa
@onready var detector_contacto: Area3D = find_child("DetectorContactoEnemigos", true, false) as Area3D

# === FUNCIONES BUILT-IN ===
func _ready() -> void:
	super._ready()
	add_to_group("canoa_protagonista")
	_sincronizar_plano_z_pasajera()
	if is_instance_valid(pasajera):
		pasajera.position.z = 0.0
	_fijar_idle_canoa_defensoras()
	_inicializar_detector_contacto()
	if navegacion_continua:
		iniciar_travesia()


func _physics_process(_delta: float) -> void:
	_sincronizar_plano_z_pasajera()
	_sujetar_pasajera()


func _process(delta: float) -> void:
	_actualizar_reaccion_enemigos()

	super._process(delta)

	_aplicar_freno_contacto_enemigos(delta)

	# Control de recorrido cíclico opcional
	if es_ciclica and _posicion_base.x >= limite_derecho_reinicio:
		_posicion_base.x = limite_izquierdo_reinicio
		position.x = _posicion_base.x
	# Nota: _sujetar_pasajera() solo se llama en _physics_process para coherencia con la física


# === FUNCIONES PÚBLICAS ===
## Inicia la travesía hacia la derecha a velocidad constante y activa el sonido.
func iniciar_travesia(vel: float = -1.0) -> void:
	var v: float = vel if vel > 0.0 else velocidad_avance
	velocidad_avance = v
	_velocidad_navegacion = v * _factor_velocidad_actual
	navegar_hacia_x(100000.0, _velocidad_navegacion)
	_actualizar_sonido_navegacion()


## Reanuda la navegación fluida de la travesía hacia adelante tras una pausa.
func reanudar_navegacion() -> void:
	_navegacion_bloqueada = false
	_frenado_suave = false
	_detenida_por_contacto = false
	_enemigo_bloqueando = null
	_factor_velocidad_actual = 1.0
	iniciar_travesia(velocidad_avance)


## Retorna el factor de velocidad actual (1.0 libre, 0.5 presencia, 0.0 detenido por contacto).
func obtener_factor_velocidad_actual() -> float:
	return _factor_velocidad_actual


## Indica si la canoa se encuentra completamente detenida por contacto con un enemigo.
func esta_detenida_por_enemigo() -> bool:
	return _detenida_por_contacto


## Indica si la canoa navega a velocidad reducida por presencia de un enemigo adelante.
func esta_en_presencia_de_enemigo() -> bool:
	return _factor_velocidad_actual > 0.0 and _factor_velocidad_actual < 1.0


## Retorna la referencia al enemigo que está bloqueando o frenando el avance.
func obtener_enemigo_bloqueando() -> Node3D:
	return _enemigo_bloqueando


## Retorna el reproductor de audio de navegación de la canoa.
func obtener_audio_navegacion() -> AudioStreamPlayer:
	if not is_instance_valid(_audio_navegacion):
		_inicializar_sonido_navegacion()
	return _audio_navegacion


## Activa o desactiva las estelas cinemáticas de viento de la canoa (tecla Z).
## Si la canoa está detenida por un enemigo, se mantiene desactivado.
## Es control manual (debug): mientras está activo, el automatismo por tramo no lo pisa.
func set_efecto_viento_activo(activo: bool) -> void:
	_viento_manual_debug = activo
	if is_instance_valid(efecto_viento):
		var activo_final: bool = activo and not _detenida_por_contacto
		efecto_viento.set_activo(activo_final)


## Retorna si el efecto de estelas de viento está actualmente activo.
func esta_efecto_viento_activo() -> bool:
	if is_instance_valid(efecto_viento):
		return efecto_viento.esta_activo()
	return false


## Retorna la referencia al nodo del efecto de viento.
func obtener_efecto_viento() -> EfectoVientoCanoa:
	if not is_instance_valid(efecto_viento):
		efecto_viento = find_child("EfectoVientoCanoa", true, false) as EfectoVientoCanoa
	return efecto_viento


## Configura dinámicamente los límites en X del tramo fluvial acelerado.
func configurar_tramo_aceleracion(x_inicio: float, x_fin: float, vel_acel: float = -1.0) -> void:
	x_inicio_tramo_aceleracion = minf(x_inicio, x_fin)
	x_fin_tramo_aceleracion = maxf(x_inicio, x_fin)
	if vel_acel > 0.0:
		velocidad_tramo_acelerado = vel_acel


## Indica si la canoa se encuentra navegando dentro de los límites del tramo acelerado.
func esta_en_tramo_aceleracion() -> bool:
	var pos_x: float = global_position.x
	return pos_x >= x_inicio_tramo_aceleracion and pos_x <= x_fin_tramo_aceleracion


# === FUNCIONES PRIVADAS ===
func _inicializar_detector_contacto() -> void:
	if not is_instance_valid(detector_contacto):
		detector_contacto = find_child("DetectorContactoEnemigos", true, false) as Area3D
	if is_instance_valid(detector_contacto):
		if not detector_contacto.body_entered.is_connected(_al_entrar_cuerpo_detector):
			detector_contacto.body_entered.connect(_al_entrar_cuerpo_detector)
		if not detector_contacto.body_exited.is_connected(_al_salir_cuerpo_detector):
			detector_contacto.body_exited.connect(_al_salir_cuerpo_detector)


func _al_entrar_cuerpo_detector(body: Node3D) -> void:
	if not (body is Node3D):
		return
	if not _enemigos_en_area_contacto.has(body):
		if _es_o_cuelga_de_enemigo(body):
			_enemigos_en_area_contacto.append(body)


## El cuerpo o alguno de sus padres es enemigo (cubre cascos/hitboxes hijas
## como el submarino, cuyos grupos están en la raíz).
func _es_o_cuelga_de_enemigo(nodo: Node) -> bool:
	var p: Node = nodo
	while is_instance_valid(p):
		if p is MinaAcuatica or p.is_in_group("mina_acuatica") or p.is_in_group("minas"):
			return false
		if p.is_in_group("enemies") or p.is_in_group("enemigos") or (p is EnemyBase):
			return true
		p = p.get_parent()
	return false


## Margen extra de frenado según el tamaño del bloqueador (ej. medio casco
## del submarino): la proa se detiene antes de tocarlo, no en su centro.
func _margen_bloqueo(enemigo: Node) -> float:
	if is_instance_valid(enemigo) and "margen_bloqueo_proa" in enemigo:
		var m = enemigo.get("margen_bloqueo_proa")
		if m is int or m is float:
			return maxf(float(m), 0.0)
	return 0.0


func _al_salir_cuerpo_detector(body: Node3D) -> void:
	_enemigos_en_area_contacto.erase(body)


func _limpiar_enemigos_invalidos_area() -> void:
	for i in range(_enemigos_en_area_contacto.size() - 1, -1, -1):
		var e: Node3D = _enemigos_en_area_contacto[i]
		if not is_instance_valid(e) or not _es_enemigo_activo_y_vivo(e):
			_enemigos_en_area_contacto.remove_at(i)


func _es_enemigo_activo_y_vivo(nodo: Node) -> bool:
	if not is_instance_valid(nodo):
		return false
	if nodo is MinaAcuatica or nodo.is_in_group("mina_acuatica") or nodo.is_in_group("minas"):
		return false
	if not (nodo is Node3D):
		return false
	var n3d := nodo as Node3D
	if not n3d.is_inside_tree():
		return false
	if not n3d.visible:
		return false
	if n3d.has_meta("ahogado_en_agua") and bool(n3d.get_meta("ahogado_en_agua")):
		return false
	if not (n3d is SubmarinoRio or n3d.has_method("esta_en_superficie")):
		# Los StaticBody3D (pilares, escudos enemigos) no tienen is_on_floor().
		# Se consideran siempre "en piso" para no ser descartados como bloqueadores
		# cuando su Y toca el umbral del agua (flotan en la plataforma/barco).
		var es_cuerpo_estatico: bool = n3d is StaticBody3D
		var esta_en_piso: bool = es_cuerpo_estatico or (n3d.has_method("is_on_floor") and bool(n3d.call("is_on_floor")))
		if not esta_en_piso and n3d.global_position.y <= -0.45:
			return false
	if n3d.has_method("esta_en_superficie") and not bool(n3d.call("esta_en_superficie")):
		return false
	if n3d.has_method("es_enemigo_activo") and not bool(n3d.call("es_enemigo_activo")):
		return false
	var padre: Node = n3d.get_parent()
	while is_instance_valid(padre):
		if padre.has_method("esta_en_superficie") and not bool(padre.call("esta_en_superficie")):
			return false
		if padre.has_method("es_enemigo_activo") and not bool(padre.call("es_enemigo_activo")):
			return false
		padre = padre.get_parent()
	# Si es SubmarinoRio o implementa es_enemigo_activo / esta_en_superficie, ya validamos su estado arriba
	if n3d is SubmarinoRio or n3d.has_method("es_enemigo_activo") or n3d.has_method("esta_en_superficie"):
		return true

	if "health" in n3d and int(n3d.get("health")) <= 0:
		return false
	if "vida_actual" in n3d and int(n3d.get("vida_actual")) <= 0:
		return false
	if n3d is EnemyBase:
		var eb := n3d as EnemyBase
		if eb.current_state == EnemyBase.State.DYING or eb.current_state == EnemyBase.State.DEAD:
			return false
	elif "current_state" in n3d:
		var st = n3d.get("current_state")
		if st == 2 or st == 3 or str(st) == "DYING" or str(st) == "DEAD":
			return false
	if "_died_signal_emitted" in n3d and bool(n3d.get("_died_signal_emitted")):
		return false
	if "is_dissolving" in n3d and bool(n3d.get("is_dissolving")):
		return false
	if "is_dead" in n3d and bool(n3d.get("is_dead")):
		return false
	if "is_dying" in n3d and bool(n3d.get("is_dying")):
		return false
	if "_dormida_por_camara" in n3d and bool(n3d.get("_dormida_por_camara")):
		return false
	if "_dormido_por_camara" in n3d and bool(n3d.get("_dormido_por_camara")):
		return false
	if n3d.has_method("esta_en_pantalla_o_rango_camara") and not bool(n3d.call("esta_en_pantalla_o_rango_camara")):
		return false
	return true


func _actualizar_reaccion_enemigos() -> void:
	# Travesía en pausa suave: mantener objetivo 0 sin reimponer velocidad.
	if _navegacion_bloqueada:
		_velocidad_navegacion = 0.0
		_factor_velocidad_actual = 0.0
		_detenida_por_contacto = false
		_enemigo_bloqueando = null
		_modular_audio_por_velocidad()
		return
	if not modular_velocidad_por_enemigos:
		_factor_velocidad_actual = 1.0
		_detenida_por_contacto = false
		_enemigo_bloqueando = null
		return

	var hay_contacto: bool = false
	var hay_presencia: bool = false
	var enemigo_mas_cercano: Node3D = null
	var menor_distancia_x: float = INF

	# 1. Comprobar enemigos en el detector de contacto físico
	_limpiar_enemigos_invalidos_area()
	for enemigo in _enemigos_en_area_contacto:
		if _es_enemigo_activo_y_vivo(enemigo):
			hay_contacto = true
			enemigo_mas_cercano = enemigo
			menor_distancia_x = enemigo.global_position.x - global_position.x
			break

	# 2. Comprobar enemigos en grupos en escena
	var grupos: Array[String] = ["enemies", "enemigos"]
	for grupo in grupos:
		if get_tree() == null:
			break
		var lista: Array[Node] = get_tree().get_nodes_in_group(grupo)
		for enemigo_nodo in lista:
			if not (enemigo_nodo is Node3D):
				continue
			var enemigo := enemigo_nodo as Node3D
			if not _es_enemigo_activo_y_vivo(enemigo):
				continue

			var dz: float = absf(enemigo.global_position.z - global_position.z)
			if dz > margen_profundidad_z_enemigos:
				continue

			var dx_base: float = enemigo.global_position.x - _posicion_base.x
			var dx_visual: float = enemigo.global_position.x - global_position.x
			var dx: float = minf(dx_base, dx_visual)
			# Descartar enemigos que ya quedaron atrás
			if dx < OFFSET_MINIMO_DETECCION_X:
				continue

			var umbral_contacto: float = distancia_contacto_enemigos + _margen_bloqueo(enemigo)
			if _detenida_por_contacto and _enemigo_bloqueando == enemigo:
				umbral_contacto += MARGEN_HISTERESIS_CONTACTO

			if dx <= umbral_contacto:
				hay_contacto = true
				if dx < menor_distancia_x:
					menor_distancia_x = dx
					enemigo_mas_cercano = enemigo
			elif dx <= distancia_presencia_enemigos:
				hay_presencia = true
				if dx < menor_distancia_x:
					menor_distancia_x = dx
					enemigo_mas_cercano = enemigo

	if hay_contacto:
		_factor_velocidad_actual = 0.0
		_detenida_por_contacto = true
		_enemigo_bloqueando = enemigo_mas_cercano
	elif hay_presencia:
		_factor_velocidad_actual = factor_velocidad_presencia
		_detenida_por_contacto = false
		_enemigo_bloqueando = enemigo_mas_cercano
	else:
		_factor_velocidad_actual = 1.0
		_detenida_por_contacto = false
		_enemigo_bloqueando = null

	var vel_objetivo: float = velocidad_avance
	var va_acelerada: bool = aceleracion_tramo_activa and esta_en_tramo_aceleracion() and not hay_contacto and not hay_presencia
	if va_acelerada:
		vel_objetivo = maxf(velocidad_avance, velocidad_tramo_acelerado)

	_velocidad_navegacion = vel_objetivo * _factor_velocidad_actual
	_modular_audio_por_velocidad()

	# Viento automático al acelerar sin enemigos (el manual de debug no se pisa)
	if not _viento_manual_debug and is_instance_valid(efecto_viento):
		efecto_viento.set_activo(va_acelerada and not _detenida_por_contacto)

	if _detenida_por_contacto and is_instance_valid(efecto_viento) and efecto_viento.esta_activo():
		efecto_viento.set_activo(false)


func _aplicar_freno_contacto_enemigos(delta: float = 0.016) -> void:
	if not _detenida_por_contacto or not is_instance_valid(_enemigo_bloqueando):
		return

	# Si el bloqueador dejó de ser un enemigo activo y vivo (ej. muerto, sumergido o en fase 2), liberar el freno
	if not _es_enemigo_activo_y_vivo(_enemigo_bloqueando):
		_detenida_por_contacto = false
		_enemigo_bloqueando = null
		return

	# Si el enemigo quedó detrás o se aleja hacia la izquierda, liberar el freno inmediatamente
	var dx: float = _enemigo_bloqueando.global_position.x - global_position.x
	if dx < OFFSET_MINIMO_DETECCION_X:
		_detenida_por_contacto = false
		_enemigo_bloqueando = null
		return

	# Frenado absoluto e infranqueable: la proa no traspasa al enemigo.
	# Corrección por deslizamiento (move_toward), nunca por salto: si la canoa
	# ya sobrepasó la línea (p. ej. el jefe emergió encima), retrocede de forma
	# continua en vez de reposicionarse de golpe con la cámara.
	var x_maxima_permitida: float = _enemigo_bloqueando.global_position.x - distancia_contacto_enemigos - _margen_bloqueo(_enemigo_bloqueando)
	if _posicion_base.x > x_maxima_permitida:
		_posicion_base.x = move_toward(_posicion_base.x, x_maxima_permitida, maxf(VELOCIDAD_CORRECCION_FRENO, 0.5) * maxf(delta, 0.001))
		position.x = _posicion_base.x + calcular_desplazamiento(_tiempo).x


func _modular_audio_por_velocidad() -> void:
	if not is_instance_valid(_audio_navegacion):
		return

	if _factor_velocidad_actual <= 0.0:
		_audio_navegacion.volume_db = VOLUMEN_SILENCIO_DB
		if is_instance_valid(_audio_navegacion_b):
			_audio_navegacion_b.volume_db = VOLUMEN_SILENCIO_DB
	else:
		if _factor_velocidad_actual < 1.0:
			_audio_navegacion.pitch_scale = pitch_sonido_canoa * MULTIPLICADOR_PITCH_CAUTELOSO
			if is_instance_valid(_audio_navegacion_b):
				_audio_navegacion_b.pitch_scale = pitch_sonido_canoa * MULTIPLICADOR_PITCH_CAUTELOSO
		else:
			_audio_navegacion.pitch_scale = pitch_sonido_canoa
			if is_instance_valid(_audio_navegacion_b):
				_audio_navegacion_b.pitch_scale = pitch_sonido_canoa


## Las defensoras a bordo usan "Idle Canoa" como reposo. Se refuerza desde la
## canoa porque su _ready corre después que el de sus hijas (doble cobertura
## junto a la autodetección de la propia defensora).
func _fijar_idle_canoa_defensoras() -> void:
	var vistas: Array = []
	var directa := get_node_or_null("DefensoraPerrena")
	if is_instance_valid(directa) and directa.has_method("fijar_modo_canoa"):
		vistas.append(directa)
	for n in find_children("*", "Node", true, false):
		if is_instance_valid(n) and not vistas.has(n) and n.has_method("fijar_modo_canoa"):
			vistas.append(n)
	for n in vistas:
		(n as Node).call("fijar_modo_canoa", true)


func _sincronizar_plano_z_pasajera() -> void:
	if not is_instance_valid(pasajera):
		pasajera = find_child("Protagonista", true, false) as Node3D
	if not is_instance_valid(pasajera):
		return
	if "plano_profundidad_z" in pasajera:
		pasajera.set("plano_profundidad_z", global_position.z)


func _sujetar_pasajera() -> void:
	if not limitar_pasajera_a_canoa:
		return
	if not is_instance_valid(pasajera):
		pasajera = find_child("Protagonista", true, false) as Node3D
		if not is_instance_valid(pasajera):
			return

	_sincronizar_plano_z_pasajera()

	pasajera.position.x = clampf(pasajera.position.x, limite_pasajera_x.x, limite_pasajera_x.y)
	pasajera.position.z = clampf(pasajera.position.z, limite_pasajera_z.x, limite_pasajera_z.y)

	# Prevenir caídas al vacío si la física de la canoa en movimiento pierde contacto con el piso
	if pasajera.position.y < 0.1:
		pasajera.position.y = Y_PISO_CANOA
		if "velocity" in pasajera:
			pasajera.velocity.y = 0.0
