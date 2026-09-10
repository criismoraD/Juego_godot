class_name PerrenaNPCInterior
extends Node3D

## Perrena NPC en el interior de la torre (Levels/Player_Interior.tscn).
## Solo exhibición: sin física ni input. Alterna suave entre la pose de
## gala ("Pose feemenina fija", 10 s, nombre tal cual trae el GLB) e "Idle"
## con crossfade del AnimationTree, para que el cambio sea natural.
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

var _anim_tree: AnimationTree
var _en_pose: bool = true
var _t_fase: float = 0.0


func _ready() -> void:
	_aplicar_material()
	_ajustar_linea_negra()
	_construir_arbol()
	_construir_colision()


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
	if _anim_tree == null:
		return
	_t_fase += delta
	var duracion := DURACION_POSE if _en_pose else DURACION_IDLE
	if _t_fase >= duracion:
		_t_fase = 0.0
		_en_pose = not _en_pose
		_anim_tree.set("parameters/Alterna/transition_request", "idle" if not _en_pose else "pose")
