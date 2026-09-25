class_name MinaAcuatica
extends StaticBody3D

## Mina acuÃ¡tica del Jefe Submarino: cae del submarino al dispararse el
## ataque Lonko y deriva lentamente hacia la canoa como la vasija contenedora.
## Tiene 2 de vida; si contacta sin ser destruida explota (1 de daÃ±o),
## sacude la canoa con oleaje fuerte y Perrena simula el golpe sin morir.

signal explotada(mina: MinaAcuatica)
signal destruida(mina: MinaAcuatica)

const ESCENA_SPLASH: PackedScene = preload("res://TEST_/swimming-in-godot-from-scracth/SCENES/splash_vfx.tscn")
const ESCENA_VFX_SUELO: PackedScene = preload("res://assets/BinbunVFX_Vol2/ExplosionFX/effects/ground/vfx_ground_explosion_01.tscn")
const MAT_MINA: StandardMaterial3D = preload("res://Entities/Proyectil_Mina_Acuatica/MinaAcuatica_Mat.tres")
const SFX_IMPACTO_METAL: AudioStream = preload("res://TEST_/Impacto de metal.mp3")
const VOLUMEN_IMPACTO_METAL: float = 2.0
const UNIT_SIZE_SFX_MINA: float = 25.0
const SHADER_DISOLVER: Shader = preload("res://System/Shaders/dissolve.gdshader")
const SHADER_OUTLINE: Shader = preload("res://System/Shaders/outline_hueso.gdshader")
const DURACION_FLASH: float = 0.1
## Rojo puro + alta emisiÃ³n para mÃ¡xima visibilidad del parpadeo de daÃ±o.
const COLOR_FLASH_DANO: Color = Color(1.0, 0.0, 0.0)
const COLOR_OUTLINE_MINA: Color = Color(0.0, 0.0, 0.0, 1.0)
const GROSOR_OUTLINE_MINA: float = 12.0
const COLOR_MORADO_REAPARICION: Color = Color(0.7, 0.1, 1.0)


@export_category("Mina - Vida")
@export var vida_maxima: float = 2.0
@export var vida_mina: float = 2.0

@export_category("Mina - Deriva (como vasija)")
@export var deriva_activa: bool = true
@export var velocidad_deriva: float = 0.45
@export var flotacion_activa: bool = true
@export var amplitud_floteo: float = 0.06
@export var velocidad_floteo: float = 1.0
@export var amplitud_balanceo: float = 2.0

@export_category("Mina - ExplosiÃ³n")
@export var dano_explosion: float = 1.0
@export var radio_contacto: float = 1.2
@export var escala_vfx: Vector3 = Vector3(0.4, 0.4, 0.4)
@export var duracion_oleaje: float = 2.0
@export var fuerza_oleaje: float = 3.0

@export_category("Mina - Perrena en Canoa")
@export var velocidad_animacion_pararse: float = 1.35  ## Pararse un poco acelerado al levantarse tras la explosión

@export_category("Mina - FlotaciÃ³n")
@export var offset_agua_y: float = -0.30
@export var anillo_y: float = 0.4

@export_category("Mina - ApariciÃ³n")
@export var duracion_materializacion: float = 1.0

var es_escudo_enemigo: bool = true
var _destruida: bool = false
var _explotada: bool = false
var _tiempo: float = 0.0
var _pos_base_y: float = 0.0
var _canoa: Node3D = null
var _material_flash: StandardMaterial3D = null
## Material de outline (cull_front extrusion). Compartido entre flash y base.
var _outline_mat: ShaderMaterial = null
## Copia exclusiva del MAT_MINA con _outline_mat como next_pass.
## Garantiza que el outline solo afecte a esta instancia de mina.
var _mat_base_unico: StandardMaterial3D = null
var _app_z: bool = false
var _x_union_plano: float = 0.0
var _t_salpique: float = 0.0

@onready var _detector: Area3D = get_node_or_null("DetectorImpacto") as Area3D


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("enemigos")
	add_to_group("mina_acuatica")
	collision_layer = 4
	collision_mask = 0
	vida_mina = vida_maxima
	_pos_base_y = position.y
	# Primero creamos los materiales (outline + flash) para que _aplicar_material()
	# ya pueda usar _mat_base_unico (con el contorno incorporado).
	_crear_material_flash()
	_aplicar_material()
	var anillo := get_node_or_null("AnilloFlotacion") as MeshInstance3D
	if is_instance_valid(anillo):
		anillo.position.y = anillo_y
	_efecto_aparicion()
	_canoa = _buscar_canoa()


## Coloca la mina en el agua: fija posiciÃ³n y base de flotaciÃ³n juntas.
func colocar_en(pos: Vector3) -> void:
	global_position = pos
	_pos_base_y = position.y


## Fija el carril de aproximaciÃ³n: mantiene su Z hasta rebasar el casco
## (origen_sub_x - 4) y luego converge al plano de la canoa/vasija.
func fijar_ruta(origen_sub_x: float) -> void:
	_x_union_plano = origen_sub_x - 4.0
	_app_z = true


## ApariciÃ³n con el efecto de reconstrucciÃ³n de escudos pero en morado:
## materializaciÃ³n con dissolve + crecimiento vertical desde la base.
func _efecto_aparicion() -> void:
	if duracion_materializacion <= 0.0:
		return
	var visual: Node3D = get_node_or_null("ModeloMina") as Node3D
	if not is_instance_valid(visual):
		visual = self
	var items: Array = []
	for m in find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi == null or not is_instance_valid(mi):
			continue
		# El anillo conserva su rojo traslÃºcido y marca la posiciÃ³n durante la apariciÃ³n.
		if _es_anillo_flotacion(mi):
			continue
		var mat := ShaderMaterial.new()
		mat.shader = SHADER_DISOLVER
		mat.next_pass = _outline_mat
		mat.set_shader_parameter("dissolve_amount", 1.0)
		mat.set_shader_parameter("glow_color", COLOR_MORADO_REAPARICION)
		mat.set_shader_parameter("glow_intensity", 8.0)
		mat.set_shader_parameter("edge_thickness", 0.08)
		mat.set_shader_parameter("noise_scale", 20.0)
		if MAT_MINA != null:
			if MAT_MINA.albedo_texture:
				mat.set_shader_parameter("albedo_texture", MAT_MINA.albedo_texture)
			var col: Color = MAT_MINA.albedo_color
			mat.set_shader_parameter("albedo_tint", Vector3(col.r, col.g, col.b))
		mi.material_override = mat
		items.append({"mesh": mi, "material": mat})
	if items.is_empty():
		return
	var escala_final: Vector3 = visual.scale
	if escala_final.is_zero_approx():
		escala_final = Vector3.ONE
	visual.scale = Vector3(escala_final.x, 0.05, escala_final.z)
	if is_instance_valid(_detector):
		_detector.set_deferred("monitoring", false)
	var tw := create_tween().set_parallel(true)
	tw.tween_method(_actualizar_materializacion.bind(items), 1.0, 0.0, maxf(duracion_materializacion, 0.2))
	tw.tween_property(visual, "scale", escala_final, maxf(duracion_materializacion, 0.2)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(_finalizar_materializacion.bind(items, visual, escala_final))


func _actualizar_materializacion(valor: float, items: Array) -> void:
	for item in items:
		if is_instance_valid(item["mesh"]):
			var mo: Material = (item["mesh"] as MeshInstance3D).material_override
			if mo is ShaderMaterial and mo == item["material"]:
				(mo as ShaderMaterial).set_shader_parameter("dissolve_amount", valor)


func _finalizar_materializacion(items: Array, visual: Node3D, escala_final: Vector3) -> void:
	for item in items:
		if is_instance_valid(item["mesh"]):
			var mi := item["mesh"] as MeshInstance3D
			if mi.material_override == item["material"]:
				mi.material_override = _mat_base_unico if _mat_base_unico != null else MAT_MINA

	if is_instance_valid(visual):
		visual.scale = escala_final
	if is_instance_valid(_detector) and not _destruida and not _explotada:
		_detector.set_deferred("monitoring", true)
	if is_instance_valid(_detector) and not _detector.body_entered.is_connected(_on_cuerpo_detector):
		_detector.body_entered.connect(_on_cuerpo_detector)


func _physics_process(delta: float) -> void:
	if _destruida or _explotada or delta <= 0.0:
		return
	if deriva_activa and is_instance_valid(_canoa):
		var dx: float = (_canoa as Node3D).global_position.x - global_position.x
		if absf(dx) > 0.1:
			var sentido: float = 1.0 if dx > 0.0 else -1.0
			position.x += sentido * velocidad_deriva * delta
		# Carril: converger al plano solo tras rebasar el casco (o si la
		# canoa quedÃ³ del otro lado, soltar el carril de inmediato).
		if _app_z:
			if dx > 0.0 or global_position.x < _x_union_plano:
				_app_z = false
			else:
				position.z = lerpf(position.z, (_canoa as Node3D).global_position.z, minf(1.0, delta * 0.5))
	if flotacion_activa:
		_tiempo += delta * velocidad_floteo
		position.y = _pos_base_y + sin(_tiempo * TAU) * amplitud_floteo
		rotation.z = sin(_tiempo * TAU * 0.6) * deg_to_rad(amplitud_balanceo)
		var anillo := get_node_or_null("AnilloFlotacion") as MeshInstance3D
		if is_instance_valid(anillo):
			var pulso: float = 1.0 + 0.1 * sin(_tiempo * TAU)
			anillo.scale = Vector3(pulso, 1.0, pulso)
	_comprobar_contacto_canoa()
	_actualizar_salpique(delta)


## Salpicadura periÃ³dica en la lÃ­nea de flotaciÃ³n para que se lea en el agua.
func _actualizar_salpique(delta: float) -> void:
	if not flotacion_activa:
		return
	_t_salpique += delta
	if _t_salpique < 1.4:
		return
	_t_salpique = 0.0
	if ESCENA_SPLASH == null or not is_inside_tree() or get_tree() == null:
		return
	var salpique = ESCENA_SPLASH.instantiate()
	if salpique == null:
		return
	var raiz: Node = get_tree().current_scene
	if raiz == null:
		raiz = get_tree().root
	raiz.add_child(salpique)
	salpique.global_position = global_position
	salpique.scale = Vector3.ONE * 0.15
	if salpique.has_method("play_splash"):
		salpique.call("play_splash")
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		if is_instance_valid(salpique):
			salpique.queue_free()
	)


## Flechas de la jugadora (vÃ­a escudo enemigo, como la vasija) y hachas.
func recibir_golpe(dano: float = 1.0) -> void:
	take_damage(dano)


func take_damage(amount: float) -> void:
	if _destruida or _explotada:
		return
	vida_mina -= maxf(amount, 0.0)
	_flash_dano()
	_reproducir_sfx_impacto_metal()
	if vida_mina <= 0.0:
		_destruir_sin_explosion()


## Estampido metÃ¡lico del casco al recibir un golpe (flechas/hachas).
func _reproducir_sfx_impacto_metal() -> void:
	if SFX_IMPACTO_METAL == null:
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var player := AudioStreamPlayer3D.new()
	player.name = "SfxImpactoMetal"
	player.stream = SFX_IMPACTO_METAL
	player.unit_size = UNIT_SIZE_SFX_MINA
	player.volume_db = VOLUMEN_IMPACTO_METAL
	player.bus = "Master"
	var root: Node = tree.current_scene
	if root == null:
		root = tree.root
	root.add_child(player)
	player.global_position = global_position
	player.play()
	player.finished.connect(player.queue_free)


func _comprobar_contacto_canoa() -> void:
	if not is_instance_valid(_canoa):
		_canoa = _buscar_canoa()
		if not is_instance_valid(_canoa):
			return
	if absf((_canoa as Node3D).global_position.x - global_position.x) <= radio_contacto:
		_explotar()


func _on_cuerpo_detector(body: Node) -> void:
	if _destruida or _explotada:
		return
	if body == self or body == _detector:
		return
	var p: Node = body
	while is_instance_valid(p):
		if p.is_in_group("player") or p.is_in_group("allies") or p.is_in_group("canoas_aliadas"):
			_explotar()
			return
		p = p.get_parent()


func _explotar() -> void:
	if _destruida or _explotada:
		return
	_explotada = true
	deriva_activa = false
	set_physics_process(false)
	_desactivar_colisiones_mina()
	_danar_jugador()
	_sacudir_canoa()
	_simular_golpe_perrena()
	_spawn_vfx()
	remove_from_group("enemies")
	remove_from_group("enemigos")
	explotada.emit(self)
	visible = false
	var tree: SceneTree = get_tree()
	if tree != null:
		tree.create_timer(1.5).timeout.connect(func() -> void:
			if is_instance_valid(self):
				queue_free()
		)


func _destruir_sin_explosion() -> void:
	if _destruida or _explotada:
		return
	_destruida = true
	deriva_activa = false
	set_physics_process(false)
	_desactivar_colisiones_mina()
	remove_from_group("enemies")
	remove_from_group("enemigos")
	destruida.emit(self)
	_spawn_splash()
	_reproducir_sfx_explosion_acuatica()
	var tw := create_tween()
	tw.tween_property(self, "position:y", position.y - 1.5, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


func _desactivar_colisiones_mina() -> void:
	collision_layer = 0
	collision_mask = 0
	for col in find_children("*", "CollisionShape3D", true, false):
		if col is CollisionShape3D:
			(col as CollisionShape3D).disabled = true
			(col as CollisionShape3D).set_deferred("disabled", true)
	if is_instance_valid(_detector):
		_detector.monitoring = false
		_detector.monitorable = false
		_detector.set_deferred("monitoring", false)
		_detector.set_deferred("monitorable", false)


func _danar_jugador() -> void:
	if get_tree() == null:
		return
	var jugador := get_tree().get_first_node_in_group("player") as Node
	if not is_instance_valid(jugador):
		return
	if jugador.has_method("take_damage"):
		if "last_hit_position" in jugador:
			jugador.set("last_hit_position", global_position)
		jugador.call("take_damage", dano_explosion)


func _sacudir_canoa() -> void:
	if not is_instance_valid(_canoa):
		_canoa = _buscar_canoa()
	if is_instance_valid(_canoa):
		if (_canoa as Node).has_method("expulsar_escombros_maderos"):
			(_canoa as Node).call("expulsar_escombros_maderos", global_position)
		if (_canoa as Node).has_method("sacudida_oleaje"):
			(_canoa as Node).call("sacudida_oleaje", duracion_oleaje, fuerza_oleaje)


## Perrena hace su animación de muerte 2 sin morir y al segundo se para
## con la animación de pararse (acelerada), volviendo luego al reposo.
func _simular_golpe_perrena() -> void:
	var perrena := _buscar_perrena()
	if not is_instance_valid(perrena):
		return
	if "health" in perrena and int(perrena.get("health")) <= 0:
		return
	if perrena.has_method("_play_anim"):
		perrena.call("_play_anim", ["Muerte 2", "Muerte 1", "impacto"], 0.1, 1.0)
	else:
		_reproducir_anim(perrena, ["Muerte 2", "Muerte 1", "impacto"])
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	tree.create_timer(1.0).timeout.connect(func() -> void:
		if not is_instance_valid(perrena):
			return
		if "health" in perrena and int(perrena.get("health")) <= 0:
			return
		_reproducir_pararse(perrena)
	)


## Levanta a Perrena con la animación de pararse (acelerada) y la devuelve
## al reposo de canoa al terminar, para no dejarla congelada. No pisa
## combate, muerte ni una nueva caída en curso.
func _reproducir_pararse(perrena: Node) -> void:
	if not is_instance_valid(perrena):
		return
	var dur: float = _duracion_clip(perrena, ["Pararse", "pararse"], 0.9)
	if perrena.has_method("_play_anim"):
		perrena.call("_play_anim", ["Pararse", "pararse"], 0.2, velocidad_animacion_pararse)
	else:
		_reproducir_anim(perrena, ["Pararse", "pararse"])
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	tree.create_timer(dur / maxf(velocidad_animacion_pararse, 0.1) + 0.25).timeout.connect(func() -> void:
		if not is_instance_valid(perrena):
			return
		if "health" in perrena and int(perrena.get("health")) <= 0:
			return
		var player_anim := _resolver_player_anim(perrena)
		if player_anim:
			var actual := String(player_anim.current_animation).to_lower()
			if not ("pararse" in actual or "idle" in actual or actual == ""):
				return
		if perrena.has_method("_play_anim"):
			perrena.call("_play_anim", ["Idle Canoa", "Idle agachada", "Idle"], 0.25, 1.0)
		else:
			_reproducir_anim(perrena, ["Idle Canoa", "Idle agachada", "Idle"])
	)


## Duración del primer clip existente (para temporizar el reposo).
func _duracion_clip(perrena: Node, candidatos: Array, defecto: float) -> float:
	var player_anim := _resolver_player_anim(perrena)
	if player_anim:
		for nombre in candidatos:
			var n := str(nombre)
			if player_anim.has_animation(n):
				var a := player_anim.get_animation(n)
				if a:
					return maxf(0.2, a.length)
	return defecto


func _resolver_player_anim(perrena: Node) -> AnimationPlayer:
	var player_anim: AnimationPlayer = null
	if "anim_player" in perrena:
		player_anim = perrena.get("anim_player") as AnimationPlayer
	if player_anim == null and perrena is Node:
		player_anim = (perrena as Node).find_child("AnimationPlayer", true, false) as AnimationPlayer
		if player_anim == null:
			player_anim = (perrena as Node).find_child("VistaPrevia", true, false) as AnimationPlayer
	return player_anim


func _reproducir_anim(perrena: Node, candidatos: Array) -> void:
	var player_anim: AnimationPlayer = null
	if "anim_player" in perrena:
		player_anim = perrena.get("anim_player") as AnimationPlayer
	if player_anim == null and perrena is Node:
		player_anim = (perrena as Node).find_child("AnimationPlayer", true, false) as AnimationPlayer
		if player_anim == null:
			player_anim = (perrena as Node).find_child("VistaPrevia", true, false) as AnimationPlayer
	if player_anim == null:
		return
	for nombre in candidatos:
		if player_anim.has_animation(str(nombre)):
			player_anim.play(str(nombre), 0.15, 1.0)
			return


func _buscar_canoa() -> Node3D:
	if get_tree() == null:
		return null
	var canoa := get_tree().get_first_node_in_group("canoas_aliadas") as Node3D
	if is_instance_valid(canoa):
		return canoa
	var escena := get_tree().current_scene
	if is_instance_valid(escena):
		return escena.find_child("CanoaProtagonistaRio", true, false) as Node3D
	return null


func _buscar_perrena() -> Node:
	if is_instance_valid(_canoa):
		var directa := (_canoa as Node).find_child("DefensoraPerrena", true, false)
		if is_instance_valid(directa):
			return directa
	if get_tree() == null:
		return null
	return get_tree().get_first_node_in_group("defensora_perrena")


func _spawn_vfx() -> void:
	_spawn_splash()
	if ESCENA_VFX_SUELO == null or not is_inside_tree():
		return
	var vfx := ESCENA_VFX_SUELO.instantiate() as Node3D
	if vfx == null:
		return
	var raiz: Node = get_tree().current_scene if get_tree() else get_parent()
	if raiz == null:
		raiz = get_tree().root
	raiz.add_child(vfx)
	vfx.global_position = global_position
	vfx.scale = escala_vfx
	for hijo in vfx.find_children("*", "GPUParticles3D", true, false):
		if hijo is GPUParticles3D:
			(hijo as GPUParticles3D).restart()
			(hijo as GPUParticles3D).emitting = true
	if vfx.has_method("play"):
		vfx.call("play")
	_reproducir_sfx_explosion_acuatica()
	var tree: SceneTree = get_tree()
	if tree != null:
		tree.create_timer(2.5).timeout.connect(func() -> void:
			if is_instance_valid(vfx):
				vfx.queue_free()
		)


func _spawn_splash() -> void:
	if ESCENA_SPLASH == null or not is_inside_tree() or get_tree() == null:
		return
	var splash = ESCENA_SPLASH.instantiate()
	if splash == null:
		return
	var raiz: Node = get_tree().current_scene
	if raiz == null:
		raiz = get_tree().root
	raiz.add_child(splash)
	splash.global_position = global_position
	if splash.has_method("play_splash"):
		splash.call("play_splash")


## Estampido acuÃ¡tico potente: suena tanto al explotar por contacto como al
## ser destruida por el jugador (mismo SFX en ambos finales).
func _reproducir_sfx_explosion_acuatica() -> void:
	AudioManager.play_sfx("explosion_acuatica_potente")


func _aplicar_material() -> void:
	# Usa el material por-instancia (con outline) si ya estÃ¡ creado; si no, el compartido.
	var mat_a_usar: Material = _mat_base_unico if _mat_base_unico != null else MAT_MINA
	if mat_a_usar == null:
		return
	for m in find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi == null or not is_instance_valid(mi):
			continue
		# El anillo de flotaciÃ³n conserva su propio material rojo traslÃºcido.
		if _es_anillo_flotacion(mi):
			continue
		mi.material_override = mat_a_usar
		if not mi.is_in_group("outline_meshes"):
			mi.add_to_group("outline_meshes")



## True si el nodo es el flotador superficial (conserva su material propio).
func _es_anillo_flotacion(nodo: Node) -> bool:
	return is_instance_valid(nodo) and nodo.name == "AnilloFlotacion"


func _crear_material_flash() -> void:
	# --- Outline (contorno 3D cull_front) ---
	_outline_mat = ShaderMaterial.new()
	_outline_mat.shader = SHADER_OUTLINE
	_outline_mat.set_shader_parameter("outline_color", COLOR_OUTLINE_MINA)
	_outline_mat.set_shader_parameter("outline_width", GROSOR_OUTLINE_MINA)

	# --- Material base exclusivo para esta instancia ---
	# Duplicamos el recurso compartido para que el next_pass (outline) solo
	# afecte a esta mina y no a las demÃ¡s instancias presentes en escena.
	if MAT_MINA != null:
		_mat_base_unico = MAT_MINA.duplicate() as StandardMaterial3D
		_mat_base_unico.next_pass = _outline_mat

	# --- Flash rojo de daÃ±o (con outline para que el contorno persista) ---
	_material_flash = StandardMaterial3D.new()
	_material_flash.albedo_color = COLOR_FLASH_DANO
	_material_flash.emission_enabled = true
	_material_flash.emission = COLOR_FLASH_DANO
	_material_flash.emission_energy_multiplier = 3.5
	_material_flash.next_pass = _outline_mat


func _flash_dano() -> void:
	if _destruida or _explotada or not is_inside_tree() or get_tree() == null:
		return
	var mallas: Array = []
	for m in find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi != null and is_instance_valid(mi) and not _es_anillo_flotacion(mi):
			mallas.append(mi)
			mi.material_override = _material_flash
	if mallas.is_empty():
		return
	get_tree().create_timer(DURACION_FLASH).timeout.connect(func() -> void:
		if _destruida or _explotada:
			return
		for mi: Node in mallas:
			if is_instance_valid(mi):
				# Restaurar el material base con outline (no el compartido sin contorno).
				(mi as MeshInstance3D).material_override = _mat_base_unico if _mat_base_unico != null else MAT_MINA
	)
