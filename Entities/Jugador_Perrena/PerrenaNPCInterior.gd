class_name PerrenaNPCInterior
extends Node3D

## Perrena NPC en el interior de la torre (Levels/Player_Interior.tscn).
## Exhibición + conversación: alterna suave entre la pose de
## gala ("Pose feemenina fija", 10 s, nombre tal cual trae el GLB) e "Idle"
## con crossfade del AnimationTree, para que el cambio sea natural.
## Además ofrece "[E] Hablar": menú con 4 opciones (Plan de asalto /
## Sobre los civiles / Consejos / Salir) navegable con W/S (E activa,
## ESC sale) que disparan eventos de conversación como el de la
## cinemática (DialogoComic dual Eryn-Perrena).
##
## AISLAMIENTO (no poda): la librería "" del AnimationPlayer del GLB es
## un recurso COMPARTIDO por todas sus instancias (la Perrena jugable de
## la cinemática de oleada 5 usa el mismo GLB). Retirar clips de ella
## mutaba el recurso y la cinemática se quedaba sin Caminar/Correr. Aquí
## se REEMPLAZA la librería del player del NPC por una privada con COPIAS
## de solo sus 2 clips: el NPC no puede reproducir nada más y el GLB
## queda intacto para el resto del juego.

const ANIM_POSE := "Pose feemenina fija"
const ANIM_IDLE := "Idle"
## La pose de gala se mantiene 10 s antes de pasar al idle; el idle dura lo
## mismo y vuelve a la pose: ciclo continuo, siempre con crossfade suave.
const DURACION_POSE: float = 10.0
const DURACION_IDLE: float = 10.0
const XFADE: float = 0.6
## Mismo material que la Perrena jugable (el GLB crudo trae el suyo embebido).
const MAT_PERRENA: Material = preload("res://Entities/Jugador_Perrena/PERRENA_MAT.tres")
## Colisión: radio de la cápsula entre el grueso real del cuerpo y un mínimo
## para que el jugador no la atraviese en el cuarto estrecho de la torre.
const FACTOR_RADIO: float = 0.5
const RADIO_MIN: float = 0.01
const RADIO_MAX: float = 0.05
const MARGEN_ALTO: float = 0.02

## ---------------------------------------------------------------
## Conversación "[E] Hablar" (Perrena, NPC permanente de la torre).
## Detección por DISTANCIA en _process (sin Area3D: el corral de
## colisiones y la física no deben poder romperla) + prompt 2D sobre
## su cabeza (un Label en CanvasLayer reposicionado cada frame con la
## proyección de la cámara: la vía de UI, que sí renderiza) y menú
## CanvasLayer con 4 opciones (3 temas + Salir).
## Cada opción de diálogo instancia la escena de conversación de la
## cinemática (DialogoComic dual Eryn-Perrena) con sus páginas por
## clave de traducción. Los consejos salen de una cola mezclada sin
## repetición que se rellena al agotarse: la lista se amplía en
## CONSEJOS_CLAVES.
const ESCENA_DIALOGO_TORRE: PackedScene = preload("res://UI/DialogoConversacionNivel5.tscn")
## Radio amplio: Perrena está tras el corral de colisiones y el jugador no
## puede pegarse a ella; debe poder hablar desde fuera del corral.
## Solapa con la zona de la mesa (a 0.42 m): si su menú está abierto la
## mesa tiene prioridad (ver _mesa_menu_abierto).
const RADIO_INTERACCION: float = 0.85
## Ancla del prompt sobre la cabeza (se proyecta a pantalla cada frame).
const ALTURA_PROMPT: float = 0.9
const TAMANO_FUENTE_PROMPT: int = 24
const CAPA_PROMPT: int = 55
const CAPA_MENU: int = 60
const ALTURA_BOTON_MENU: float = 48.0
const TAMANO_FUENTE_MENU: int = 20
const TAMANO_FUENTE_TITULO: int = 24
const CLAVE_PROMPT_HABLAR := "PERRENA_PROMPT_HABLAR"
const CLAVE_NOMBRE_PERRENA := "NIVEL5_PERRENA_NOMBRE"
const HABLANTE_PERRENA := "perrena"
const HABLANTE_ERYN := "eryn"
const OPCIONES_CLAVES: Array[String] = [
	"PERRENA_OPCION_ASALTO",
	"PERRENA_OPCION_CIVILES",
	"PERRENA_OPCION_CONSEJOS",
	"MENU_SALIR",
]
const DIALOGO_ASALTO_PAGINAS: Array[String] = [
	"PERRENA_ASALTO_1",
	"PERRENA_ASALTO_2",
	"PERRENA_ASALTO_3",
	"PERRENA_ASALTO_4",
]
const DIALOGO_ASALTO_HABLANTES: Array[String] = [
	HABLANTE_PERRENA,
	HABLANTE_PERRENA,
	HABLANTE_ERYN,
	HABLANTE_PERRENA,
]
const DIALOGO_CIVILES_PAGINAS: Array[String] = [
	"PERRENA_CIVILES_1",
	"PERRENA_CIVILES_2",
]
const DIALOGO_CIVILES_HABLANTES: Array[String] = [
	HABLANTE_PERRENA,
	HABLANTE_PERRENA,
]
const CONSEJOS_CLAVES: Array[String] = [
	"PERRENA_CONSEJO_1",
	"PERRENA_CONSEJO_2",
	"PERRENA_CONSEJO_3",
	"PERRENA_CONSEJO_4",
	"PERRENA_CONSEJO_5",
	"PERRENA_CONSEJO_6",
	"PERRENA_CONSEJO_7",
	"PERRENA_CONSEJO_8",
]

var _anim_tree: AnimationTree
var _en_pose: bool = true
var _t_fase: float = 0.0
var _prompt_hablar: Label
var _capa_prompt: CanvasLayer
var _menu_conversacion: CanvasLayer
var _titulo_menu: Label
var _botones_opciones: Array[Button] = []
var _jugador_cerca: bool = false
var _jugador_nodo: Node3D
var _opcion_foco: int = 0
var _menu_abierto: bool = false
var _dialogo_activo: bool = false
var _consejos_cola: Array[int] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_aplicar_material()
	_ajustar_linea_negra()
	_construir_arbol()
	_construir_colision()
	_rng.randomize()
	_rellenar_consejos()
	_construir_interaccion()


## Colisión sólida para el jugador: StaticBody3D en layer 1 (la misma de la
## estructura) con cápsula dimensionada al modelo, centrada. Se mide por
## HUESOS (el AABB de una malla skinneada es el de bind y sale diminuto) y
## el cuerpo vive bajo el esqueleto (hereda SOLO su escala uniforme del
## GLB, no la no-uniforme del nodo NPC: Jolt la rechaza).
func _construir_colision() -> void:
	var skel := find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		push_warning("[PerrenaNPC] Sin esqueleto para la colisión.")
		return
	var aabb := _aabb_huesos(skel)
	if aabb == AABB():
		push_warning("[PerrenaNPC] Sin huesos para la colisión.")
		return

	var cuerpo := StaticBody3D.new()
	cuerpo.name = "ColisionNPC"
	cuerpo.collision_layer = 1
	cuerpo.collision_mask = 0
	skel.add_child(cuerpo)

	var forma := CollisionShape3D.new()
	forma.name = "ColisionShape"
	cuerpo.add_child(forma)
	var capsula := CapsuleShape3D.new()
	# Radio por la dimensión delgada del cuerpo (la T-pose del rest abre los
	# brazos en X; Z sigue siendo el grosor real de perfil).
	var radio: float = minf(aabb.size.x, aabb.size.z) * 0.5 * FACTOR_RADIO
	capsula.radius = clampf(radio, RADIO_MIN, RADIO_MAX)
	capsula.height = aabb.size.y + MARGEN_ALTO
	forma.shape = capsula
	cuerpo.global_position = aabb.get_center()


## AABB en mundo de todos los huesos del esqueleto (pose de reposo del GLB):
## medida fiable del cuerpo para la cápsula (la malla skinneada no lo es).
func _aabb_huesos(skel: Skeleton3D) -> AABB:
	var caja := AABB()
	var primera := true
	for i in skel.get_bone_count():
		var pos_mundo: Vector3 = skel.global_transform * skel.get_bone_global_pose(i).origin
		if primera:
			caja = AABB(pos_mundo, Vector3.ZERO)
			primera = false
		else:
			caja = caja.expand(pos_mundo)
	return caja


## Material de Perrena (igual que la jugable: override en todas las mallas
## del modelo; el GLB crudo trae el embebido).
func _aplicar_material() -> void:
	for mesh in find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_override = MAT_PERRENA


## Contorno fino dentro de la torre (mismo criterio que PlayerInterior).
func _ajustar_linea_negra() -> void:
	for node in find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if not mi:
			continue
		var count: int = mi.get_surface_override_material_count()
		if count == 0 and mi.mesh:
			count = mi.mesh.get_surface_count()
		for i in range(maxi(count, 1)):
			var mat: Material = mi.get_active_material(i)
			if mat and mat is StandardMaterial3D:
				var dup := mat.duplicate() as StandardMaterial3D
				if dup.next_pass and dup.next_pass is ShaderMaterial:
					var np := dup.next_pass.duplicate() as ShaderMaterial
					np.set_shader_parameter("outline_width", 2.0)
					dup.next_pass = np
				mi.set_surface_override_material(i, dup)
		if mi.material_override and mi.material_override is StandardMaterial3D:
			var dup := mi.material_override.duplicate() as StandardMaterial3D
			if dup.next_pass and dup.next_pass is ShaderMaterial:
				var np := dup.next_pass.duplicate() as ShaderMaterial
				np.set_shader_parameter("outline_width", 2.0)
				dup.next_pass = np
			mi.material_override = dup


## Árbol dinámico con dos nodos de animación y una transición con xfade:
## el cambio pose -> idle es un fundido suave, no un salto de fotograma.
## Antes de nada se AISLA la librería del AnimationPlayer (copias privadas
## de solo los 2 clips): el interior de la torre es seguro y el NPC no
## conoce más animaciones (sin aislar, autoplay del GLB y árboles previos
## podían disparar "Disparo arco").
func _construir_arbol() -> void:
	var tree := find_child("AnimationTree", true, false) as AnimationTree
	if tree:
		tree.active = false
		tree.queue_free()
	tree = AnimationTree.new()
	tree.name = "AnimationTree"
	add_child(tree)
	_anim_tree = tree
	var anim_p := find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim_p == null:
		push_warning("[PerrenaNPC] Sin AnimationPlayer; NPC estática.")
		return

	var nombre_pose := _resolver_anim_sufijo(anim_p, ANIM_POSE)
	var nombre_idle := _resolver_anim_idle(anim_p, ANIM_IDLE)
	if nombre_pose.is_empty() or nombre_idle.is_empty():
		push_warning("[PerrenaNPC] Sin clips '%s'/'%s'." % [ANIM_POSE, ANIM_IDLE])
		return
	if not _aislar_animaciones(anim_p, [nombre_pose, nombre_idle]):
		push_warning("[PerrenaNPC] Sin librería por defecto que aislar.")
	tree.anim_player = tree.get_path_to(anim_p)

	var raiz := AnimationNodeBlendTree.new()
	var nodo_pose := AnimationNodeAnimation.new()
	nodo_pose.animation = nombre_pose
	var nodo_idle := AnimationNodeAnimation.new()
	nodo_idle.animation = nombre_idle
	var trans := AnimationNodeTransition.new()
	trans.input_count = 2
	trans.set_input_name(0, "pose")
	trans.set_input_name(1, "idle")
	trans.xfade_time = XFADE
	raiz.add_node("Pose", nodo_pose)
	raiz.add_node("Idle", nodo_idle)
	raiz.add_node("Alterna", trans)
	raiz.connect_node("Alterna", 0, "Pose")
	raiz.connect_node("Alterna", 1, "Idle")
	raiz.connect_node("output", 0, "Alterna")
	tree.tree_root = raiz
	tree.active = true
	_en_pose = true
	_t_fase = 0.0
	tree.set("parameters/Alterna/transition_request", "pose")


## Resuelve un clip por sufijo insensible a mayúsculas. Solo para nombres
## únicos del GLB (la pose "Pose feemenina fija" no admite colisiones).
func _resolver_anim_sufijo(anim_p: AnimationPlayer, buscar: String) -> StringName:
	var buscar_bajo := buscar.to_lower()
	for lib_nombre in anim_p.get_animation_library_list():
		var lib := anim_p.get_animation_library(lib_nombre)
		if lib == null:
			continue
		for anim_nombre in lib.get_animation_list():
			var completo := String(lib_nombre + "/" + anim_nombre) if lib_nombre != "" else String(anim_nombre)
			if completo.to_lower().ends_with(buscar_bajo):
				return StringName(completo)
	return &""


## Resuelve el IDLE por coincidencia EXACTA (tras quitar el prefijo de
## librería), no por sufijo: la Perrena jugable registra en la librería
## COMPARTIDA del GLB el alias "Armature|Armature|APUNTAR_IDLE" (una copia
## del ataque "Disparo arco") que también termina en "idle" — por sufijo
## el NPC lo adoptaría como idle y se pondría a atacar tras la cinemática.
func _resolver_anim_idle(anim_p: AnimationPlayer, buscar: String) -> StringName:
	var buscar_bajo := buscar.to_lower()
	for lib_nombre in anim_p.get_animation_library_list():
		var lib := anim_p.get_animation_library(lib_nombre)
		if lib == null:
			continue
		for anim_nombre in lib.get_animation_list():
			if String(anim_nombre).to_lower() == buscar_bajo:
				# Nombre completo con librería (el árbol lo resuelve así).
				var completo := String(lib_nombre + "/" + anim_nombre) if lib_nombre != "" else String(anim_nombre)
				return StringName(completo)
	return &""


## Reemplaza la librería por defecto del player del NPC por una PRIVADA
## con copias de SOLO las 2 animaciones permitidas (ambas en loop). El
## NPC no puede atacar ni reproducir nada más: el interior de la torre
## es seguro. A diferencia de una poda, NADA se retira del recurso
## compartido: las demás instancias del GLB (la Perrena jugable de la
## cinemática de NIVEL01) conservan todos sus clips intactos.
func _aislar_animaciones(anim_p: AnimationPlayer, permitidas: Array) -> bool:
	var lib_compartida := anim_p.get_animation_library("")
	if lib_compartida == null:
		return false
	anim_p.stop()
	# Copias duplicadas de los clips permitidos (con loop): los originales
	# del GLB quedan intactos y la librería nueva es solo del NPC.
	var lib_privada := AnimationLibrary.new()
	for anim_nombre in lib_compartida.get_animation_list():
		if not permitidas.has(StringName(anim_nombre)):
			continue
		var copia: Animation = (lib_compartida.get_animation(anim_nombre) as Animation).duplicate()
		copia.loop_mode = Animation.LOOP_LINEAR
		lib_privada.add_animation(anim_nombre, copia)
	if lib_privada.get_animation_list().is_empty():
		return false
	anim_p.remove_animation_library("")
	anim_p.add_animation_library("", lib_privada)
	return true


func _process(delta: float) -> void:
	_actualizar_proximidad()
	_actualizar_prompt_pantalla()
	if _anim_tree == null:
		return
	_t_fase += delta
	var duracion := DURACION_POSE if _en_pose else DURACION_IDLE
	if _t_fase >= duracion:
		_t_fase = 0.0
		_en_pose = not _en_pose
		_anim_tree.set("parameters/Alterna/transition_request", "idle" if not _en_pose else "pose")


## Construye el prompt "[E] Hablar" y el menú de 4 opciones como
## hermanos del NPC (en la raíz del nivel). La proximidad se mide por
## distancia en _process, sin nodos de física de por medio.
## El add_child es DIFERIDO: en _ready el padre aún está dando de alta
## a sus hijos y el add directo falla ("Parent node is busy...").
func _construir_interaccion() -> void:
	var raiz := get_parent()
	if raiz == null:
		push_warning("[PerrenaNPC] Sin padre para la interacción.")
		return
	_construir_prompt_hablar(raiz)
	_construir_menu_conversacion(raiz)


## Prompt 2D sobre su cabeza: un Label en CanvasLayer (la vía de UI,
## que sí renderiza) reposicionado cada frame con la proyección de la
## cámara en _actualizar_prompt_pantalla.
func _construir_prompt_hablar(raiz: Node) -> void:
	var capa := CanvasLayer.new()
	capa.name = "CapaPromptHablar"
	capa.layer = CAPA_PROMPT
	raiz.call_deferred("add_child", capa)
	_capa_prompt = capa
	var etiqueta := Label.new()
	etiqueta.name = "PromptHablar"
	etiqueta.text = "[E] " + tr(CLAVE_PROMPT_HABLAR)
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.add_theme_font_size_override("font_size", TAMANO_FUENTE_PROMPT)
	etiqueta.add_theme_color_override("font_color", Color.WHITE)
	etiqueta.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08))
	etiqueta.add_theme_constant_override("outline_size", 6)
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiqueta.visible = false
	capa.add_child(etiqueta)
	_prompt_hablar = etiqueta


## Coloca el prompt sobre la cabeza de Perrena en pantalla. Fuente única
## de verdad para su visibilidad: solo se muestra cerca, sin menú ni
## diálogo, con cámara válida y el ancla delante de ella.
func _actualizar_prompt_pantalla() -> void:
	if _prompt_hablar == null:
		return
	if not _jugador_cerca or _menu_abierto or _dialogo_activo:
		_prompt_hablar.visible = false
		return
	var vista := get_viewport()
	if vista == null:
		_prompt_hablar.visible = false
		return
	var camara := vista.get_camera_3d()
	if camara == null:
		_prompt_hablar.visible = false
		return
	var ancla_mundo := global_position + Vector3(0.0, ALTURA_PROMPT, 0.0)
	if camara.is_position_behind(ancla_mundo):
		_prompt_hablar.visible = false
		return
	var punto := camara.unproject_position(ancla_mundo)
	_prompt_hablar.size = _prompt_hablar.get_combined_minimum_size()
	_prompt_hablar.position = punto - _prompt_hablar.size * 0.5
	_prompt_hablar.visible = true


func _construir_menu_conversacion(raiz: Node) -> void:
	var capa := CanvasLayer.new()
	capa.name = "MenuConversacionPerrena"
	capa.layer = CAPA_MENU
	capa.visible = false
	raiz.call_deferred("add_child", capa)
	var centro := CenterContainer.new()
	centro.name = "CentroMenu"
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(centro)
	var panel := PanelContainer.new()
	panel.name = "PanelMenu"
	panel.custom_minimum_size = Vector2(340.0, 0.0)
	panel.add_theme_stylebox_override("panel", _estilo_panel_menu())
	centro.add_child(panel)
	var margen := MarginContainer.new()
	margen.add_theme_constant_override("margin_left", 25)
	margen.add_theme_constant_override("margin_top", 25)
	margen.add_theme_constant_override("margin_right", 25)
	margen.add_theme_constant_override("margin_bottom", 25)
	panel.add_child(margen)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 14)
	caja.alignment = BoxContainer.ALIGNMENT_CENTER
	margen.add_child(caja)
	var titulo := Label.new()
	titulo.name = "TituloMenu"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", TAMANO_FUENTE_TITULO)
	titulo.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	caja.add_child(titulo)
	_titulo_menu = titulo
	for i in OPCIONES_CLAVES.size():
		var boton := Button.new()
		boton.name = "Opcion%d" % i
		boton.custom_minimum_size = Vector2(0.0, ALTURA_BOTON_MENU)
		boton.add_theme_font_size_override("font_size", TAMANO_FUENTE_MENU)
		boton.add_theme_color_override("font_color", Color.WHITE)
		boton.add_theme_stylebox_override("normal", _estilo_boton(Color(0.0, 0.0, 0.0, 1.0)))
		boton.add_theme_stylebox_override("hover", _estilo_boton(Color(0.15, 0.15, 0.15, 1.0)))
		boton.add_theme_stylebox_override("pressed", _estilo_boton(Color(0.3, 0.3, 0.3, 1.0)))
		boton.add_theme_stylebox_override("focus", _estilo_boton(Color(0.12, 0.12, 0.12, 1.0)))
		boton.pressed.connect(_on_opcion_conversacion.bind(i))
		boton.focus_entered.connect(_on_foco_opcion.bind(i))
		caja.add_child(boton)
		_botones_opciones.append(boton)
	_menu_conversacion = capa
	_refrescar_textos_menu()


func _estilo_panel_menu() -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.0, 0.0, 0.0, 0.95)
	estilo.border_color = Color(1.0, 1.0, 1.0, 0.9)
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(10)
	return estilo


func _estilo_boton(color_fondo: Color) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = color_fondo
	estilo.border_color = Color(1.0, 1.0, 1.0, 0.8)
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(6)
	return estilo


func _refrescar_textos_menu() -> void:
	if _titulo_menu:
		_titulo_menu.text = tr(CLAVE_NOMBRE_PERRENA)
	for i in _botones_opciones.size():
		if i < OPCIONES_CLAVES.size():
			_botones_opciones[i].text = tr(OPCIONES_CLAVES[i])


## Proximidad por distancia (matemática pura, sin física): se evalúa en
## cada _process y conmuta prompt/menú solo al cruzar el umbral.
func _actualizar_proximidad() -> void:
	var jugador := _obtener_jugador()
	if jugador == null:
		return
	var cerca: bool = global_position.distance_to(jugador.global_position) <= RADIO_INTERACCION
	if cerca == _jugador_cerca:
		return
	_jugador_cerca = cerca
	if not cerca:
		_cerrar_menu_conversacion()
		_set_movimiento_jugador(true)


func _obtener_jugador() -> Node3D:
	if is_instance_valid(_jugador_nodo):
		return _jugador_nodo
	var arbol := get_tree()
	if arbol == null:
		return null
	_jugador_nodo = arbol.get_first_node_in_group("player_interior") as Node3D
	return _jugador_nodo


func _unhandled_input(evento: InputEvent) -> void:
	if _dialogo_activo:
		return
	if not (evento is InputEventKey):
		return
	var tecla_ev := evento as InputEventKey
	if not tecla_ev.pressed or tecla_ev.echo:
		return
	if _menu_abierto:
		## Navegación como el menú de defensoras: W/S mueve, E activa,
		## ESC sale. Enter/Espacio los gestiona el propio Button con foco.
		match tecla_ev.keycode:
			KEY_W, KEY_UP:
				_mover_foco(-1)
				get_viewport().set_input_as_handled()
			KEY_S, KEY_DOWN:
				_mover_foco(1)
				get_viewport().set_input_as_handled()
			KEY_E:
				_activar_foco()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				_cerrar_menu_conversacion()
				get_viewport().set_input_as_handled()
		return
	if not _jugador_cerca:
		return
	if _mesa_menu_abierto():
		return
	if tecla_ev.keycode == KEY_E or tecla_ev.keycode == KEY_ENTER:
		_abrir_menu_conversacion()
		get_viewport().set_input_as_handled()


## La zona de la mesa queda dentro del radio de Perrena: si su menú (o
## los submenús de defensoras/bestiario) está abierto, la mesa tiene
## prioridad y aquí no se abre nada (evita dos menús a la vez con E).
func _mesa_menu_abierto() -> bool:
	var raiz := get_parent()
	if raiz == null:
		return false
	var mesa := raiz.find_child("MesaConfiguracion", true, false)
	if mesa == null:
		return false
	for propiedad in ["menu_canvas", "menu_defensoras", "menu_bestiario"]:
		var submenu := mesa.get(propiedad) as Node
		if submenu != null and bool(submenu.get("visible")):
			return true
	return false


func _abrir_menu_conversacion() -> void:
	if _menu_abierto or _dialogo_activo or _menu_conversacion == null:
		return
	_menu_abierto = true
	_set_movimiento_jugador(false)
	_refrescar_textos_menu()
	_menu_conversacion.visible = true
	_opcion_foco = 0
	if not _botones_opciones.is_empty():
		_botones_opciones[0].grab_focus()


func _cerrar_menu_conversacion() -> void:
	if not _menu_abierto:
		return
	_menu_abierto = false
	if _menu_conversacion:
		_menu_conversacion.visible = false
	if _dialogo_activo:
		return
	_set_movimiento_jugador(true)


## Mueve la selección con W/S (o flechas del teclado), con vuelta al
## llegar al final de la lista.
func _mover_foco(direccion: int) -> void:
	if _botones_opciones.is_empty():
		return
	_opcion_foco = wrapi(_opcion_foco + direccion, 0, _botones_opciones.size())
	_botones_opciones[_opcion_foco].grab_focus()


## Activa con E la opción seleccionada (el ratón sigue funcionando igual).
func _activar_foco() -> void:
	_on_opcion_conversacion(_opcion_foco)


func _on_foco_opcion(indice: int) -> void:
	_opcion_foco = indice


func _on_opcion_conversacion(indice: int) -> void:
	if _dialogo_activo:
		return
	if indice < 0 or indice >= OPCIONES_CLAVES.size():
		push_warning("[PerrenaNPC] Opción de conversación inválida: %d." % indice)
		return
	match indice:
		0:
			_mostrar_dialogo_torre(DIALOGO_ASALTO_PAGINAS, DIALOGO_ASALTO_HABLANTES)
		1:
			_mostrar_dialogo_torre(DIALOGO_CIVILES_PAGINAS, DIALOGO_CIVILES_HABLANTES)
		2:
			_mostrar_consejo_perrena()
		3:
			_cerrar_menu_conversacion()


## Muestra un evento de conversación como el de la cinemática: reutiliza
## su escena (DialogoComic dual Eryn-Perrena) con páginas propias por
## clave. Al terminar vuelve al menú de opciones (no lo cierra), para
## poder pedir otro tema u otro consejo sin reabrir con E.
func _mostrar_dialogo_torre(paginas: Array[String], hablantes: Array[String]) -> void:
	if _dialogo_activo or paginas.is_empty():
		return
	if get_tree() == null:
		push_warning("[PerrenaNPC] Sin árbol para mostrar el diálogo.")
		return
	_dialogo_activo = true
	if _menu_conversacion:
		_menu_conversacion.visible = false
	_set_movimiento_jugador(false)
	var dialogo := ESCENA_DIALOGO_TORRE.instantiate() as DialogoComic
	if dialogo == null:
		push_warning("[PerrenaNPC] La escena de diálogo no usa DialogoComic.")
		_dialogo_activo = false
		_set_movimiento_jugador(true)
		return
	dialogo.paginas_texto = PackedStringArray(paginas)
	dialogo.paginas_hablante = PackedStringArray(hablantes)
	var ancla: Node = get_tree().current_scene
	if ancla == null:
		ancla = get_parent()
	dialogo.continuado.connect(_on_dialogo_torre_terminado.bind(dialogo))
	ancla.add_child(dialogo)


## Cierre del diálogo: libera la escena y vuelve al menú de opciones si
## sigue abierto (el jugador puede pedir otro tema); si no, devuelve el
## movimiento y el prompt según proximidad.
func _on_dialogo_torre_terminado(dialogo: DialogoComic) -> void:
	if is_instance_valid(dialogo):
		dialogo.queue_free()
	_dialogo_activo = false
	if _menu_abierto:
		if _menu_conversacion:
			_menu_conversacion.visible = true
		_opcion_foco = 0
		if not _botones_opciones.is_empty():
			_botones_opciones[0].grab_focus()
	else:
		_set_movimiento_jugador(true)


## Consejo sin repetición: cada llamada entrega una clave distinta hasta
## agotar la lista; al vaciarse la cola se rellena y mezcla de nuevo.
func obtener_siguiente_consejo() -> String:
	if _consejos_cola.is_empty():
		_rellenar_consejos()
	if _consejos_cola.is_empty():
		return ""
	return CONSEJOS_CLAVES[_consejos_cola.pop_front()]


func _rellenar_consejos() -> void:
	_consejos_cola.clear()
	for i in CONSEJOS_CLAVES.size():
		_consejos_cola.append(i)
	_consejos_cola.shuffle()


func _mostrar_consejo_perrena() -> void:
	var clave := obtener_siguiente_consejo()
	if clave.is_empty():
		return
	var paginas: Array[String] = [clave]
	var hablantes: Array[String] = [HABLANTE_PERRENA]
	_mostrar_dialogo_torre(paginas, hablantes)


func _set_movimiento_jugador(permitir: bool) -> void:
	var arbol := get_tree()
	if arbol == null:
		return
	var jugador := arbol.get_first_node_in_group("player_interior")
	if jugador and "puede_moverse" in jugador:
		jugador.puede_moverse = permitir
