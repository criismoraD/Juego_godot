class_name BarcoCombatePirata
extends BalsaPirataCombate

## Barco pirata de combate: mismo comportamiento que la balsa de combate
## (navegación derecha-izquierda con freno, mezcla pre-posicionada, vida 16,
## destrucción con desintegración). Diferencias: modelo y textura propios.
## No tiene modelo destruido: al hundirse se disuelve intacto (no aparece
## el pecio de balsa).

const MAT_BARCO: Material = preload("res://Entities/Ambiente_Barco_Combate_Pirata/MAT_BARCO_COMBATE_PIRATA.tres")
const SFX_HUNDIMIENTO: String = "hundimiento_barco_pirata"
const ESCENA_ONDA_SPLASH: PackedScene = preload("res://TEST_/swimming-in-godot-from-scracth/SCENES/splash_vfx.tscn")
const SCRIPT_ESCOMBRO_MADERO: Script = preload("res://Entities/Ambiente_Barco_Combate_Pirata/EscombroMaderoVolador.gd")

## Configuración de los 6 escombros que salen volando al destruir el barco pirata.
## Offsets locales y vectores de impulso para una dispersión orgánica en 3D.
const CONFIG_ESCOMBROS_MADEROS: Array[Dictionary] = [
	{"indice": 0, "offset": Vector3(-1.8, 0.35, -0.2), "impulso": Vector3(-4.8, 9.5, 0.4)},
	{"indice": 1, "offset": Vector3(-0.9, 0.45, 0.3), "impulso": Vector3(-2.2, 11.2, -0.5)},
	{"indice": 2, "offset": Vector3(0.0, 0.55, -0.1), "impulso": Vector3(1.2, 12.0, 0.6)},
	{"indice": 3, "offset": Vector3(0.8, 0.45, 0.2), "impulso": Vector3(3.2, 10.0, -0.4)},
	{"indice": 4, "offset": Vector3(1.6, 0.35, -0.3), "impulso": Vector3(5.2, 8.8, 0.3)},
	{"indice": 5, "offset": Vector3(0.3, 0.6, 0.1), "impulso": Vector3(2.5, 10.5, 0.5)},
]

## Cubiertas medidas del modelo (unidades GLB): {x_min, x_max, y_cima, z_mitad}.
## Largo, alto y ancho iguales a las cajas rosadas de la escena (test lo amarra).
const CUBIERTAS_GLB: Array = [
	{"x_min": -0.463, "x_max": -0.091, "y": 0.1175, "z": 0.19},
	{"x_min": -0.126, "x_max": 0.197, "y": 0.0825, "z": 0.19},
	{"x_min": 0.2546, "x_max": 0.3616, "y": 0.2246, "z": 0.16},
]

## Piratas nadadoras decorativas al hundirse: mismo GLB de la tripulación con
## su clip "Nadar". No cuentan como enemigas ni colisionan (PirataNadadora).
@export_category("Nadadoras al Hundirse")
@export_range(0, 4, 1) var cantidad_nadadoras: int = 2
@export var velocidad_nado: float = 0.9  ## m/s de cada nadadora
@export var offset_y_agua: float = -0.13  ## Del origen del casco al agua (semisumergidas a la altura del pecho)
@export var escala_nadadoras: float = 0.8  ## Igual que la tripulación embarcada (PirataGoblin.tscn)
@export var tiempo_nadadoras_en_cuadro: float = 10.0  ## Si siguen en cuadro, se desvanecen como al morir

@export_category("Onda al Hundirse")
@export var mostrar_onda_al_hundirse: bool = true  ## Anillo de onda del submarino al romper la superficie
@export var escala_onda_hundirse: float = 2.2  ## Tamaño de la onda respecto al casco (reducida para que no se vea gigante)
@export var bajar_onda_y: float = -0.12  ## Extra hacia abajo sobre offset_y_agua para pegarla al agua (se veía elevada)
@export var duracion_onda_hundirse: float = 3.0  ## Segundos visible la onda (su animación es en loop)

var _puestos: Array[Vector3] = []  ## Puestos locales precalculados por cubierta
var _nadadoras: Array = []  ## Nadadoras decorativas sueltas al hundirse (no enemigas)


func _ready() -> void:
	super._ready()
	# La tripulación del barco aparece con el efecto del escudo del jugador
	# al reconstruirse (dissolve + crecimiento vertical), pero en morado.
	efecto_aparicion_morado = true


func _asegurar_materiales() -> void:
	if not MAT_BARCO:
		return
	var modelo := find_child("BarcoModel", true, false)
	if not modelo:
		return
	for m in modelo.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi:
			mi.material_override = MAT_BARCO
			if not mi.is_in_group("outline_meshes"):
				mi.add_to_group("outline_meshes")



## Sin pecio propio: se hunde y disuelve intacto.
func _sustituir_por_modelo_destruido() -> void:
	pass


## El barco suena al hundirse, por casco (16 impactos) o por tripulación exterminada.
func _hundir_por_dano() -> void:
	_reproducir_hundimiento()
	super._hundir_por_dano()


## Al destruirse (por daño o tripulación exterminada) suelta las nadadoras
## decorativas en el agua antes de que el casco se hunda.
func destruir_balsa() -> void:
	if esta_destruida():
		return
	# La secuencia de hundimiento anima la posición del casco: capturar el
	# punto de naufragio y el rumbo ANTES de que el barco empiece a hundirse.
	var dir: float = _direccion_navegacion if _navegando else -1.0
	var pos_naufragio: Vector3 = global_position
	super.destruir_balsa()
	_generar_onda_hundirse(pos_naufragio)
	_soltar_nadadoras(pos_naufragio, dir)


## Sobrescribe la expulsión de maderos de la balsa para lanzar los 6 escombros
## de madera propios del barco de combate pirata con físicas acrobáticas y ondas en agua.
func _lanzar_maderos_voladores() -> void:
	var root_scene: Node = get_tree().current_scene if is_inside_tree() and get_tree() else null
	if root_scene == null and is_inside_tree() and get_tree():
		root_scene = get_tree().root
	if root_scene == null:
		root_scene = get_parent()
	if root_scene == null:
		root_scene = self

	var altura_agua: float = _posicion_base.y + offset_y_agua + bajar_onda_y
	if _posicion_base.is_zero_approx():
		altura_agua = global_position.y + offset_y_agua + bajar_onda_y

	_maderos_lanzados.clear()
	for cfg: Dictionary in CONFIG_ESCOMBROS_MADEROS:
		var escombro: Node3D = SCRIPT_ESCOMBRO_MADERO.new() as Node3D
		if escombro == null:
			continue
		root_scene.add_child(escombro)
		var indice: int = int(cfg.get("indice", 0))
		var offset: Vector3 = cfg.get("offset", Vector3.ZERO)
		var impulso: Vector3 = cfg.get("impulso", Vector3(0.0, 8.0, 0.0))
		var spawn_pos: Vector3 = global_position + global_transform.basis * offset
		if escombro.has_method("lanzar"):
			escombro.call("lanzar", spawn_pos, impulso, altura_agua, capa_visual, indice)
		_aplicar_capa_visual_recursiva(escombro)
		_maderos_lanzados.append(escombro)


## Onda del submarino al hundirse: solo el anillo sobre la superficie
## (sin gotas, burbujas, impacto, pilar ni remate). Mismo patrón que
## SubmarinoRio._generar_onda_emerger.
func _generar_onda_hundirse(pos_origen: Vector3) -> void:
	if not mostrar_onda_al_hundirse:
		return
	if not is_inside_tree() or get_tree() == null:
		return
	if ESCENA_ONDA_SPLASH == null:
		return
	var onda := ESCENA_ONDA_SPLASH.instantiate() as Node3D
	if onda == null:
		return
	var raiz: Node = get_tree().current_scene
	if raiz == null:
		raiz = get_tree().root
	raiz.add_child(onda)
	onda.global_position = pos_origen + Vector3(0.0, offset_y_agua + bajar_onda_y, 0.0)
	onda.scale = Vector3.ONE * maxf(escala_onda_hundirse, 0.1)
	# Solo el anillo de onda (1); fuera gotas, burbujas, impacto, pilar y remate
	if onda.has_method("toggle_layer_index"):
		for i in range(6):
			onda.toggle_layer_index(i, i == 1)
	if onda.has_method("play_splash"):
		onda.play_splash()
	get_tree().create_timer(maxf(duracion_onda_hundirse, 0.1)).timeout.connect(func() -> void:
		if is_instance_valid(onda):
			onda.queue_free()
	)


## Instancia las nadadoras en la escena (NO hijas del barco: no se hunden con él).
func _soltar_nadadoras(pos_origen: Vector3, dir: float) -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	var raiz: Node = get_tree().current_scene
	if raiz == null:
		raiz = get_tree().root
	for i in range(maxi(cantidad_nadadoras, 0)):
		var nadadora := PirataNadadora.new()
		nadadora.direccion_x = dir
		nadadora.velocidad_nado = maxf(velocidad_nado, 0.1) + 0.12 * float(i)
		nadadora.tiempo_maximo_visible = tiempo_nadadoras_en_cuadro
		raiz.add_child(nadadora)
		var lateral: float = 0.35 if i % 2 == 0 else -0.35
		nadadora.global_position = pos_origen + Vector3(-0.4 - 0.55 * float(i), offset_y_agua, lateral)
		nadadora.scale = Vector3.ONE * maxf(escala_nadadoras, 0.1)
		_nadadoras.append(nadadora)


## Nadadoras decorativas aún en escena (las liberadas por cuadro o tiempo salen solas).
func obtener_nadadoras() -> Array:
	var vivas: Array = []
	for n in _nadadoras:
		if is_instance_valid(n) and not (n as Node).is_queued_for_deletion():
			vivas.append(n)
	_nadadoras = vivas
	return _nadadoras


func _tripulacion_exterminada() -> void:
	_reproducir_hundimiento()
	super._tripulacion_exterminada()


func _reproducir_hundimiento() -> void:
	if _destruida:
		return
	AudioManager.play_sfx_3d(SFX_HUNDIMIENTO, global_position)


## Cubiertas en local del barco (GLB x escala del modelo).
func _cubiertas_local() -> Array:
	var s: float = 1.3
	var modelo := find_child("BarcoModel", true, false) as Node3D
	if is_instance_valid(modelo):
		s = modelo.scale.x
	var decks: Array = []
	for d in CUBIERTAS_GLB:
		decks.append({
			"x_min": float(d["x_min"]) * s,
			"x_max": float(d["x_max"]) * s,
			"y": float(d["y"]) * s,
		})
	return decks


func _construir_cola_mezcla() -> void:
	super._construir_cola_mezcla()
	_construir_puestos_cubiertas()


## Reparte los puestos round-robin entre las 3 cubiertas, centrados en cada una.
func _construir_puestos_cubiertas() -> void:
	_puestos.clear()
	var decks := _cubiertas_local()
	if decks.is_empty() or _total_tripulacion <= 0:
		return
	var por_deck: Array = []
	for d in decks:
		por_deck.append([])
	for i in range(_total_tripulacion):
		(por_deck[i % decks.size()] as Array).append(i)
	var pos_por_indice := {}
	for di in range(decks.size()):
		var miembros: Array = por_deck[di]
		var n: int = miembros.size()
		var z_mitad: float = float(decks[di].get("z", 0.0))
		for k in range(n):
			var t: float = 0.5 if n <= 1 else float(k) / float(n - 1)
			var x: float = lerpf(float(decks[di]["x_min"]), float(decks[di]["x_max"]), t)
			# Zigzag en profundidad: la fila india (todo z=0) apila los cuerpos
			# en la línea de tiro y la popa queda imposible de impactar.
			var z: float = 0.0 if n <= 1 else (z_mitad if k % 2 == 0 else -z_mitad)
			pos_por_indice[miembros[k]] = Vector3(x, float(decks[di]["y"]), z)
	for i in range(_total_tripulacion):
		if pos_por_indice.has(i):
			_puestos.append(pos_por_indice[i])
		else:
			_puestos.append(Vector3(0.0, float(decks[0]["y"]), 0.0))


func _puesto_local(restantes_despues: int) -> Vector3:
	var total: int = maxi(_total_tripulacion, 1)
	var indice: int = clampi(total - 1 - restantes_despues, 0, maxi(_puestos.size() - 1, 0))
	if indice >= 0 and indice < _puestos.size():
		return _puestos[indice]
	return super._puesto_local(restantes_despues)
