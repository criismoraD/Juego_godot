class_name PirataGoblin
extends ImpEnemy

## Pirata Goblin: variante del Imp con modelo, texturas y animaciones propias.
## Reutiliza el comportamiento del Imp (caminar/correr, pausas IDLE, muerte
## normal y desmembramiento por explosiva) con proyectiles propios:
## LANZAR01 arroja la espada giratoria y LANZAR2 ("Disparo") es un pistoletazo
## que dispara una bala de cañón en línea recta.
## Las animaciones del GLB se registran con alias de los nombres del Imp,
## así el ciclo heredado (reproducción, duraciones y loops) funciona sin cambios.
## NOTA: el nodo del modelo se llama "ImpModel" a propósito para que el código
## heredado que lo oculta al morir lo encuentre (es el pirata, no un imp).

const MAT_PIRATA: Material = preload("res://Entities/Enemigo_Pirata_Goblin/MAT_PIRATA_GOBLIN.tres")
const MAT_PISTOLA: Material = preload("res://Entities/Enemigo_Pirata_Goblin/MAT_PISTOLA_PIRATA.tres")
const ESCENA_ESPADA_PIRATA: PackedScene = preload("res://Entities/Proyectil_Espada_Pirata/EspadaPirata.tscn")
const ESCENA_BALA_CANON: PackedScene = preload("res://Entities/Proyectil_Bala_Canon/BalaCanon.tscn")
const ESCENA_VFX_IMPACTO: PackedScene = preload("res://HitFXFree/assets/BinbunVFX_Vol2/StylizedHitFX/effects/hit/vfx_hit_01.tscn")
## Tope duro del fogonazo en código (ignora valores viejos/overrides grandes:
## el fogonazo de una pistola nunca debe tapar al personaje).
const ESCALA_MAX_FOGONAZO: float = 2.0

## Hueso que sostiene la pistola en Disparo (brazo izquierdo: 121° de recorrido
## contra 21° del derecho, medido en los tracks del clip).
const HUESO_PISTOLA: String = "mixamorig_LeftHand"

## Alias nombre-Imp -> nombre real en PirataGoblin.glb
const MAPA_ANIMACIONES: Dictionary = {
	"CAMINAR": "Strut Walking",
	"CORRER": "Correr",
	"IDLE": "Idle",
	"LANZAR01": "Ataque arrojar",
	"LANZAR2": "Disparo",
	"IMP_MUERTE01": "Muerte 1",
	"IMP_MUERTE02": "Muerte 2",
}
const ANIMACIONES_LOOP: Array[String] = ["CAMINAR", "CORRER", "IDLE"]

## Giro extra de yaw aplicado SOLO mientras se reproduce el disparo "Disparo"
## (alias LANZAR2). +90° deja el modelo de perfil a la izquierda (-X, hacia
## la jugadora); el seguimiento converge al mismo valor. Las demás
## animaciones quedan intactas.
@export var grados_extra_disparo: float = 90.0
## Velocidad con que el modelo gira para seguir al jugador durante el disparo.
@export var suavizado_aim_disparo: float = 10.0
## Segundo del Disparo en que la pistola sale de la funda (visible desde este frame).
## 0.2 = visible durante casi todo el Disparo para que siempre se vea en pantalla.
@export var tiempo_aparicion_pistola: float = 0.2
## Debug: si true, la pistola queda siempre visible (ignora el timing).
@export var forzar_pistola_visible: bool = false
## Punta del cañón en local de la pistola (ahí nace el fogonazo).
## Con la malla volteada, la boca quedó en -X.
@export var punta_pistola_local: Vector3 = Vector3(-0.55, 0.3, 0.0)
## Escala del fogonazo VFXHit_01 en la punta (grande y legible pero sin
## tapar al pirata ni la bala: ~45cm sobre un pirata de ~56cm).
@export var escala_vfx_impacto: float = 1.8
## Tamaño del humo Smoke VFX 2 que acompaña al pistoletazo.
@export var escala_humo_disparo: float = 0.7
## Si está activo o el pirata está sobre un submarino, siempre usará la animación de correr
@export var esta_en_submarino: bool = false

var _yaw_base_modelo: float = 0.0
var _yaw_base_guardado: bool = false


func _on_enemy_ready() -> void:
	material_imp = MAT_PIRATA
	_aliasar_animaciones()
	super._on_enemy_ready()
	color_borde_disolucion = Color(0.44705883, 0.0, 0.06666667)
	# El pirata arroja su espada en vez del tridente del Imp (mismo daño/pool).
	if ESCENA_ESPADA_PIRATA:
		imp_arrow_scene = ESCENA_ESPADA_PIRATA
	sfx_lanzamiento = "lanzar_espada_pirata"
	# Voz de muerte propia: reemplaza imp_death + explosion_muerte del Imp
	# (la guarda evita duplicarlo en la muerte normal).
	sfx_muerte = "muerte_pirata_goblin"
	sfx_muerte_explosion = "muerte_pirata_goblin"
	# Cadencia más baja que el Imp (pausas más largas, sin pisar ajustes mayores del editor)
	pausa_idle_min = maxf(pausa_idle_min, 2.0)
	pausa_idle_max = maxf(pausa_idle_max, 3.5)
	_fijar_pistola_a_mano()
	_ocultar_pistola()


## Fija la pistola a la mano izquierda para que la siga durante Disparo.
## Colocacion local sana en el puno. Si el .tscn trae offset gigante, se repara.
## Todo ocurre en _ready antes del primer frame (sin parpadeo visible).
func _fijar_pistola_a_mano() -> void:
	var pistola := _buscar_pistola()
	if pistola == null:
		return
	_aplicar_material_pistola(pistola)
	var skel := find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		return
	var idx: int = _resolver_hueso_pistola(skel)
	if idx < 0:
		return
	var attach := _buscar_attachment_pistola(skel)
	if attach == null:
		attach = BoneAttachment3D.new()
		attach.name = "PistolaAttachment"
		skel.add_child(attach)
	if attach.bone_idx < 0 or attach.bone_idx >= skel.get_bone_count():
		attach.bone_idx = idx
	# El esqueleto viene en cm (Armature x0.01): offsets de decenas son normales.
	# Solo resetear si es un disparate (>2m en espacio del hueso o escala rota
	# por una version anterior que confundia attachment con pistola).
	var esc_attach: Vector3 = attach.transform.basis.get_scale()
	if attach.transform.origin.length() > 200.0 or esc_attach.x < 0.5 or esc_attach.x > 2.0:
		attach.transform = Transform3D.IDENTITY
	if pistola.get_parent() == attach:
		_reparar_transform_pistola(pistola)
		return
	var padre_previo := pistola.get_parent()
	if padre_previo:
		padre_previo.remove_child(pistola)
	attach.add_child(pistola)
	_reparar_transform_pistola(pistola)


## Attachment de la escena si existe (para posicionar en el editor).
func _buscar_attachment_pistola(skel: Skeleton3D) -> BoneAttachment3D:
	if not is_instance_valid(skel):
		return null
	var directo := skel.get_node_or_null("PistolaAttachment") as BoneAttachment3D
	if directo:
		return directo
	for n in skel.find_children("*", "BoneAttachment3D", true, false):
		return n as BoneAttachment3D
	return null


## Índice del hueso de la pistola (exacto + tolerante a : vs _).
func _resolver_hueso_pistola(skel: Skeleton3D) -> int:
	var idx: int = skel.find_bone(HUESO_PISTOLA)
	if idx >= 0:
		return idx
	for b in range(skel.get_bone_count()):
		if "lefthand" in skel.get_bone_name(b).to_lower().replace(":", "").replace("_", ""):
			return b
	var nombres := []
	for b in range(skel.get_bone_count()):
		nombres.append(skel.get_bone_name(b))
	push_warning("[PirataGoblin] Hueso de pistola no encontrado, la pistola queda estática. Huesos: " + str(nombres))
	return -1


## El pirata viene en cm (Armature x0.01) y la pistola mide ~1m en su GLB:
## la escala local sana es ~35 (=0.35m en mundo). Solo reparar disparates.
func _reparar_transform_pistola(pistola: Node3D) -> void:
	if not is_instance_valid(pistola):
		return
	var s: Vector3 = pistola.transform.basis.get_scale()
	var max_esc: float = maxf(s.x, maxf(s.y, s.z))
	var min_esc: float = minf(s.x, minf(s.y, s.z))
	var origen_lejos: bool = pistola.transform.origin.length() > 150.0
	if min_esc < 5.0 or max_esc > 150.0 or origen_lejos:
		pistola.transform = Transform3D(
			Basis.from_scale(Vector3(35.0, 35.0, 35.0)),
			Vector3(0.0, 2.0, 1.0)
		)
	# La boca miraba al revés: voltear la malla 180° en su eje local
	# (no toca tu colocación, solo invierte cañón/culata).
	for m in pistola.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).rotate_y(PI)


var _anim_previa_nombre := ""
var _anim_previa_pos := 0.0
var _anim_previa_sonando := false


## Lleva el esqueleto al instante del disparo para capturar el offset exacto.
func _llevar_esqueleto_al_disparo() -> void:
	_anim_previa_nombre = ""
	_anim_previa_pos = 0.0
	_anim_previa_sonando = false
	if not anim_player:
		return
	if anim_player.is_playing():
		_anim_previa_nombre = anim_player.current_animation
		_anim_previa_pos = anim_player.current_animation_position
		_anim_previa_sonando = true
	var clip_nombre := ""
	if anim_player.has_animation("LANZAR2"):
		clip_nombre = "LANZAR2"
	elif anim_player.has_animation("Disparo"):
		clip_nombre = "Disparo"
	if clip_nombre == "":
		return
	anim_player.play(clip_nombre)
	var clip := anim_player.get_animation(clip_nombre)
	if clip:
		anim_player.seek(minf(tiempo_lanzamiento_lanzar2, clip.length), true)
	print("[PirataGoblin] Pistola fijada a hueso: ", HUESO_PISTOLA)


## Devuelve la animación que sonaba antes de capturar el offset.
func _restaurar_animacion_previa() -> void:
	if anim_player and _anim_previa_sonando and _anim_previa_nombre != "":
		anim_player.play(_anim_previa_nombre)
		anim_player.seek(_anim_previa_pos, true)


## Localiza la pistola colocada en el editor ("Pistola pirata2" o similar).
## OJO: no confundir con el PistolaAttachment (tambien contiene "pistola").
func _buscar_pistola() -> Node3D:
	for n in find_children("*", "Node3D", true, false):
		var nn := n as Node3D
		if nn == null or nn is BoneAttachment3D:
			continue
		if "pistola" in (nn as Node).name.to_lower():
			return nn
	var exacta := get_node_or_null("Pistola pirata2") as Node3D
	if exacta and not (exacta is BoneAttachment3D):
		return exacta
	return null


func _aplicar_material_pistola(pistola: Node3D) -> void:
	if not MAT_PISTOLA or not is_instance_valid(pistola):
		return
	for m in pistola.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_override = MAT_PISTOLA


func _mostrar_pistola() -> void:
	var pistola := _buscar_pistola()
	if pistola:
		pistola.visible = true


func _ocultar_pistola() -> void:
	var pistola := _buscar_pistola()
	if pistola:
		pistola.visible = false


## Reparto de ataques: LANZAR01 arroja la espada (ciclo heredado) y LANZAR2
## ("Disparo", la pistola pirata) dispara una bala de cañón en línea recta.
## La elección entre ambos es libre (azar del Imp, sin mínimo de espadas).
func _throw_projectile() -> void:
	if current_throw_anim == "LANZAR2" and ESCENA_BALA_CANON:
		_disparar_bala_canon()
	else:
		super._throw_projectile()


## Pistoletazo: bala de cañón tensa hacia la jugadora, sin parábola.
func _disparar_bala_canon() -> void:
	AudioManager.play_sfx("disparo_pistola_pirata_gob")
	if not player_ref:
		player_ref = get_tree().get_first_node_in_group("player")
		if not player_ref:
			return
	if player_ref.get("is_dead"):
		return
	var bala := PROJECTILE_POOL_REF.acquire(ESCENA_BALA_CANON) as BalaCanonProjectile
	if not bala:
		return
	bala.scale = Vector3.ONE
	var spawn_pos: Vector3 = global_position + Vector3(-0.3, altura_spawn_flecha, 0)
	var target_pos: Vector3 = player_ref.global_position + Vector3(0, 0.5, 0)
	var dir: Vector3 = (target_pos - spawn_pos).normalized()
	bala.initialize(dir, 1.0)
	PROJECTILE_POOL_REF.activate(bala, get_tree().root, spawn_pos)
	_generar_vfx_impacto()
	_generar_humo_disparo()


## Fogonazo VFXHit_01 en la punta de la pistola al pistoletazo.
## Grande y legible pero sin tapar al pirata ni la bala.
func _generar_vfx_impacto() -> void:
	var pistola := _buscar_pistola()
	if pistola == null or not is_inside_tree() or get_tree() == null:
		return
	if not ESCENA_VFX_IMPACTO:
		return
	var vfx := ESCENA_VFX_IMPACTO.instantiate() as Node3D
	if vfx == null:
		return
	vfx.scale = Vector3.ONE * ESCALA_MAX_FOGONAZO
	if "light_energy" in vfx:
		vfx.set("light_energy", 0.8)
	if "emission" in vfx:
		vfx.set("emission", 1.0)
	# El VFXHit_01 ya es contenido por diseño; se fuerzan coordenadas
	# locales para que la escala del padre lo gobierne.
	_reducir_particulas_impacto(vfx, ESCALA_MAX_FOGONAZO)
	print("[PirataGoblin] fogonazo VFXHit_01 x", ESCALA_MAX_FOGONAZO)
	var root: Node = get_tree().current_scene
	if root == null:
		root = get_tree().root
	root.add_child(vfx)
	vfx.global_position = pistola.to_global(punta_pistola_local)
	if vfx.has_method("play"):
		vfx.call("play")
	if vfx.has_signal("finished"):
		vfx.connect("finished", func(): if is_instance_valid(vfx): vfx.queue_free())


## Humo Smoke VFX 2 en la punta de la pistola al pistoletazo.
func _generar_humo_disparo() -> void:
	var pistola := _buscar_pistola()
	if pistola == null or not is_inside_tree() or get_tree() == null:
		return
	var humo := HumoDisparoPirata.new()
	humo.escala_humo = escala_humo_disparo
	var root: Node = get_tree().current_scene
	if root == null:
		root = get_tree().root
	root.add_child(humo)
	humo.global_position = pistola.to_global(punta_pistola_local)


## Reduce un VFXHit_01 instanciado sin tocar el asset compartido (mismo
## patrón que la gárgola): fuerza coordenadas locales para que la escala
## del padre gobierne, duplica cada ParticleProcessMaterial, baja cantidad
## y vida, y encoge el rango de la luz.
func _reducir_particulas_impacto(vfx: Node3D, factor: float) -> void:
	for n in vfx.find_children("*", "GPUParticles3D", true, false):
		var gpu := n as GPUParticles3D
		if gpu == null:
			continue
		gpu.local_coords = true
		gpu.amount = maxi(1, gpu.amount / 2)
		gpu.lifetime = maxf(0.15, gpu.lifetime * 0.7)
		var pm := gpu.process_material as ParticleProcessMaterial
		if pm == null:
			continue
		var dup := pm.duplicate() as ParticleProcessMaterial
		dup.initial_velocity_min *= factor
		dup.initial_velocity_max *= factor
		dup.radial_velocity_min *= factor
		dup.radial_velocity_max *= factor
		dup.directional_velocity_min *= factor
		dup.directional_velocity_max *= factor
		dup.gravity = pm.gravity * factor
		dup.emission_sphere_radius = maxf(0.01, pm.emission_sphere_radius * factor)
		gpu.process_material = dup
	for n in vfx.find_children("*", "OmniLight3D", true, false):
		var luz := n as OmniLight3D
		if luz:
			luz.omni_range = minf(luz.omni_range, 0.3)


## Registra cada animación del pirata también bajo el nombre que espera el Imp.
## Comparte el recurso (sin duplicar datos) y fuerza loop en las de movimiento.
func _aliasar_animaciones() -> void:
	if anim_player == null:
		return
	for lib_name in anim_player.get_animation_library_list():
		var lib := anim_player.get_animation_library(lib_name)
		if lib == null:
			continue
		for alias in MAPA_ANIMACIONES:
			var real: String = MAPA_ANIMACIONES[alias]
			if not lib.has_animation(alias) and lib.has_animation(real):
				lib.add_animation(alias, lib.get_animation(real))
	for alias in ANIMACIONES_LOOP:
		if anim_player.has_animation(alias):
			var a := anim_player.get_animation(alias)
			if a:
				a.loop_mode = Animation.LOOP_LINEAR


func _on_state_walking() -> void:
	if va_a_correr or es_en_submarino():
		_play_animation("CORRER")
	else:
		_play_animation("CAMINAR")


## Determina si el pirata está ubicado sobre un submarino
func es_en_submarino() -> bool:
	if esta_en_submarino or is_in_group("piratas_submarino") or has_meta("en_submarino"):
		return true
	var p: Node = get_parent()
	while p:
		if p is SubmarinoRio or p.name.to_lower().contains("submarino"):
			return true
		p = p.get_parent()
	return false


## Todo el playback del Imp pasa por _play_animation: aquí se gira el modelo
## solo durante LANZAR2 ("Disparo") y se restaura la base en cualquier otra
## animación (caminar, correr, idle, arrojar, muerte). El giro se aplica al
## nodo ImpModel, así el facing del cuerpo (CharacterBody3D) no se altera.
func _play_animation(anim_name: String, custom_blend: float = -1.0, speed: float = 1.0):
	var anim_final: String = anim_name
	# Si está sobre un submarino, siempre debe usar la animación de correr en lugar de caminar
	if (anim_final == "CAMINAR" or anim_final == "Strut Walking") and es_en_submarino():
		anim_final = "CORRER"
	_aplicar_yaw_disparo(anim_final)
	# La pistola sale de la funda a su frame (lo decide _process); cualquier
	# otra animación la oculta de inmediato.
	_ocultar_pistola()
	super._play_animation(anim_final, custom_blend, speed)


## Al morir se oculta la pistola también en la vía explosiva (que no reproduce animación).
func _on_state_dying() -> void:
	_ocultar_pistola()
	super._on_state_dying()


func _aplicar_yaw_disparo(anim_name: String) -> void:
	var modelo := get_node_or_null("ImpModel") as Node3D
	if modelo == null:
		return
	if not _yaw_base_guardado:
		_yaw_base_modelo = modelo.rotation.y
		_yaw_base_guardado = true
	if anim_name == "LANZAR2":
		modelo.rotation.y = _yaw_base_modelo + deg_to_rad(grados_extra_disparo)
	else:
		modelo.rotation.y = _yaw_base_modelo


func _process(delta: float) -> void:
	super._process(delta)
	_actualizar_aim_disparo(delta)
	_actualizar_visibilidad_pistola()


## La pistola aparece desde su frame del Disparo (sale de la funda) y se oculta
## al terminar. Se limita a la duración real para garantizar que siempre se vea
## antes del pistoletazo.
func _actualizar_visibilidad_pistola() -> void:
	if forzar_pistola_visible:
		_mostrar_pistola()
		return
	if not is_throwing or current_throw_anim != "LANZAR2":
		return
	var t_mostrar: float = tiempo_aparicion_pistola
	if throw_anim_duration > 0.0:
		t_mostrar = minf(t_mostrar, maxf(throw_anim_duration - 0.1, 0.0))
	if throw_anim_timer >= t_mostrar:
		_mostrar_pistola()
	else:
		_ocultar_pistola()


## Mientras dura el disparo (LANZAR2), el modelo gira para apuntar al jugador.
## Es la ÚNICA animación que se orienta: al terminar, _play_animation restaura
## la base con IDLE/caminar/muerte. El cuerpo (CharacterBody3D) no se toca.
func _actualizar_aim_disparo(delta: float) -> void:
	if not is_throwing or current_throw_anim != "LANZAR2":
		return
	if current_state == State.DYING or current_state == State.DEAD:
		return
	var modelo := get_node_or_null("ImpModel") as Node3D
	if modelo == null or not modelo.is_inside_tree():
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null or not is_instance_valid(player):
		return
	if player.get("is_dead"):
		return
	var dir: Vector3 = player.global_position - modelo.global_position
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	# Yaw de mundo hacia el jugador (forward -Z) + compensación del clip.
	var yaw_deseado_mundo: float = atan2(-dir.x, -dir.z) + deg_to_rad(grados_extra_disparo)
	# Pasar a yaw local por si el cuerpo alguna vez rota.
	var padre := modelo.get_parent() as Node3D
	var yaw_padre_mundo: float = padre.global_rotation.y if padre else 0.0
	var peso: float = minf(1.0, suavizado_aim_disparo * delta)
	modelo.rotation.y = lerp_angle(modelo.rotation.y, yaw_deseado_mundo - yaw_padre_mundo, peso)
