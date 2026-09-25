class_name MisilSubmarino
extends Area3D

## Misil del Jefe Submarino (fase 2): sube desde el agua hasta salir de
## pantalla y luego cae girando rápido sobre una posición fija.
## Tiene 1 de vida y puede ser destruido por flechas de la jugadora.
## Al explotar se desintegra como los enemigos (borde naranja) y deja
## VFXAirExplosion_01 en aire o VFXGroundExplosion_01 en suelo/jugador.

signal caido(misil: MisilSubmarino)
signal destruido(misil: MisilSubmarino)

enum Fase { SUBIDA, ESPERA_ARRIBA, CAIDA, IMPACTADO }

const ALTURA_SALIDA_PANTALLA: float = 26.0
const DANO_AL_JUGADOR: float = 1.0
const DURACION_DESINTEGRACION: float = 0.5
const COLOR_BORDE_NARANJA: Color = Color(1.0, 0.55, 0.15)
const ESCENA_VFX_AIRE: PackedScene = preload("res://assets/BinbunVFX_Vol2/ExplosionFX/effects/air/vfx_air_explosion_01.tscn")
const ESCENA_VFX_SUELO: PackedScene = preload("res://assets/BinbunVFX_Vol2/ExplosionFX/effects/ground/vfx_ground_explosion_01.tscn")
const ESCENA_IMP: PackedScene = preload("res://Entities/Enemigo_Imp/ImpEnemy.tscn")
const SHADER_DISOLVER: Shader = preload("res://System/Shaders/dissolve.gdshader")
const SHADER_OUTLINE: Shader = preload("res://System/Shaders/outline_hueso.gdshader")
const MAT_MISIL: Material = preload("res://Entities/Proyectil_Misil_Submarino/MisilSubmarino_Mat.tres")
const COLOR_OUTLINE_MISIL: Color = Color(0.0, 0.0, 0.0, 1.0)
const GROSOR_OUTLINE_MISIL: float = 12.0
const ESCENA_SPLASH: PackedScene = preload("res://VFX/SplashAgua/SCENES/splash_vfx.tscn")
const ESCENA_WATER_SPLASH: PackedScene = preload("res://VFX/Scenes/WaterSplash3D.tscn")


@export_category("Misil - Vida")
@export var vida_maxima: int = 1
@export var health: int = 1

@export_category("Misil - Movimiento")
@export var velocidad_subida: float = 14.0
@export var velocidad_caida: float = 2.2
@export var velocidad_giro_caida: float = 4.0
@export var tiempo_vida: float = 30.0

@export_category("Misil - Colisión")
@export var escala_modelo: float = 0.65  ## Tamaño del misil (visual y colisión mejoran juntos)
@export var escala_explosion: float = 0.7  ## Tamaño global de la explosión (VFX y área de daño visual)

@export_category("Misil - Explosión")
@export var escala_vfx_aire: Vector3 = Vector3(0.18, 0.18, 0.18)
@export var escala_vfx_suelo: Vector3 = Vector3(0.2, 0.2, 0.2)
@export var cadaver_imp: bool = true

@export_category("Misil - Oleaje e Impacto Canoa")
@export var duracion_oleaje: float = 2.0
@export var fuerza_oleaje: float = 3.5

@export_category("Misil - Perrena en Canoa")
@export var velocidad_animacion_pararse: float = 1.35  ## Pararse un poco acelerado al levantarse tras la explosión

@export_category("Misil - Modo Cosmético")
@export var es_cosmetico: bool = false:
	set(v):
		es_cosmetico = v
		if is_node_ready() and es_cosmetico:
			_configurar_modo_cosmetico()
@export var altura_superficie_agua: float = -0.22  ## Nivel donde el misil rompe la superficie y genera splash
@export var escala_splash_agua: float = 0.40  ## Escala del splash estilo Azulina al salir del agua

var fase: Fase = Fase.SUBIDA
var _punto_caida: Vector3 = Vector3.ZERO
var _nodo_canoa: Node3D = null
var _offset_x_canoa: float = 0.0
var _caida_iniciada: bool = false
var _muerto: bool = false
var _dano_aplicado: bool = false
var _tiempo_vida: float = 0.0
var _materiales_disolver: Array = []
var _splash_agua_generado: bool = false
## ShaderMaterial de contorno (cull_front extrusion, negro).
var _outline_mat_misil: ShaderMaterial = null
## Copia exclusiva del MAT_MISIL por instancia, con el outline en next_pass.
var _mat_misil_unico: Material = null

@onready var _estela: GPUParticles3D = get_node_or_null("EstelaCaida") as GPUParticles3D


func _ready() -> void:
	health = vida_maxima
	if not es_cosmetico:
		add_to_group("enemies")
		add_to_group("enemy_projectiles")
	else:
		_configurar_modo_cosmetico()
	_aplicar_material()
	_inicializar_outline()
	_aplicar_escala_misil()
	if not es_cosmetico:
		if not body_entered.is_connected(_on_body_entered):
			body_entered.connect(_on_body_entered)
		if not area_entered.is_connected(_on_area_entered):
			area_entered.connect(_on_area_entered)


func _configurar_modo_cosmetico() -> void:
	if is_in_group("enemies"):
		remove_from_group("enemies")
	if is_in_group("enemy_projectiles"):
		remove_from_group("enemy_projectiles")
	monitoring = false
	monitorable = false
	collision_layer = 0
	collision_mask = 0
	_set_efecto_velocidad(true)


func _physics_process(delta: float) -> void:
	if _muerto:
		return
	_tiempo_vida += delta
	if _tiempo_vida >= tiempo_vida:
		_resolver_sin_dano()
		return
	match fase:
		Fase.SUBIDA:
			global_position.y += velocidad_subida * delta
			rotation.y += 1.5 * delta
			if es_cosmetico:
				if not _splash_agua_generado and global_position.y >= _obtener_altura_agua():
					_splash_agua_generado = true
					_generar_splash_salida_agua()
				if global_position.y >= ALTURA_SALIDA_PANTALLA:
					queue_free()
					return
			elif global_position.y >= ALTURA_SALIDA_PANTALLA:
				fase = Fase.ESPERA_ARRIBA
		Fase.ESPERA_ARRIBA:
			pass
		Fase.CAIDA:
			if is_instance_valid(_nodo_canoa):
				_punto_caida.x = _nodo_canoa.global_position.x + _offset_x_canoa
				_punto_caida.z = _nodo_canoa.global_position.z
			global_position.y = move_toward(global_position.y, _punto_caida.y, velocidad_caida * delta)
			global_position.x = _punto_caida.x
			global_position.z = _punto_caida.z
			rotation.y += velocidad_giro_caida * delta
			rotation.z += velocidad_giro_caida * 0.6 * delta
			if is_equal_approx(global_position.y, _punto_caida.y):
				_impactar_suelo()


## Fija dónde debe caer el misil (siempre el mismo patrón en el jefe).
func fijar_punto_caida(punto: Vector3) -> void:
	_punto_caida = punto
	_nodo_canoa = null


## Fija la canoa objetivo y el offset relativo sobre su cubierta (zona verde).
func fijar_objetivo_canoa(canoa: Node3D, offset_x: float, y_suelo: float) -> void:
	_nodo_canoa = canoa
	_offset_x_canoa = offset_x
	if is_instance_valid(canoa):
		_punto_caida = Vector3(canoa.global_position.x + offset_x, y_suelo, canoa.global_position.z)


## El jefe la llama cuando toca bajar (en tandas de 3 en 3).
func iniciar_caida() -> void:
	if _muerto or fase == Fase.CAIDA:
		return
	_caida_iniciada = true
	fase = Fase.CAIDA
	if is_instance_valid(_nodo_canoa):
		_punto_caida.x = _nodo_canoa.global_position.x + _offset_x_canoa
		_punto_caida.z = _nodo_canoa.global_position.z
	global_position.x = _punto_caida.x
	global_position.z = _punto_caida.z
	_set_efecto_velocidad(true)


func take_damage(amount: float) -> void:
	if _muerto or es_cosmetico:
		return
	health -= int(maxi(1, int(amount)))
	if health <= 0:
		_explotar(true)


func es_enemigo_activo() -> bool:
	return not _muerto and not es_cosmetico and fase == Fase.CAIDA


## Textura del modelo (igual que el submarino con su _Mat.tres): si el GLB
## viene sin material, se ve blanco; se cubre con su diffuse propio.
func _aplicar_material() -> void:
	if MAT_MISIL == null:
		return
	for m in find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi == null or not is_instance_valid(mi):
			continue
		mi.material_override = MAT_MISIL


## Crea el contorno 3D (cull_front extrusion) para este misil y lo aplica
## como next_pass en un duplicado por-instancia del MAT_MISIL.
## Llamar en _ready() después de _aplicar_material().
func _inicializar_outline() -> void:
	_outline_mat_misil = ShaderMaterial.new()
	_outline_mat_misil.shader = SHADER_OUTLINE
	_outline_mat_misil.set_shader_parameter("outline_color", COLOR_OUTLINE_MISIL)
	_outline_mat_misil.set_shader_parameter("outline_width", GROSOR_OUTLINE_MISIL)

	# Clonar MAT_MISIL por instancia para que el next_pass no afecte
	# a los demás misiles simultáneos en escena.
	if MAT_MISIL != null:
		_mat_misil_unico = MAT_MISIL.duplicate()
	else:
		var base := StandardMaterial3D.new()
		_mat_misil_unico = base
	_mat_misil_unico.next_pass = _outline_mat_misil

	# Aplicar el material con outline a todos los meshes del modelo.
	for m in find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi == null or not is_instance_valid(mi):
			continue
		mi.material_override = _mat_misil_unico
		if not mi.is_in_group("outline_meshes"):
			mi.add_to_group("outline_meshes")



func _set_efecto_velocidad(activo: bool) -> void:
	if is_instance_valid(_estela):
		_estela.emitting = activo


## Tamaño del misil: modelo visual, colisión de impacto y estela juntos.
## "escala_modelo" controla el tamaño general (más chico = más discreto).
func _aplicar_escala_misil() -> void:
	var s: float = clampf(escala_modelo, 0.25, 2.0)
	# Modelo visual
	var modelo: Node3D = find_child("ModeloMisil", true, false) as Node3D
	if is_instance_valid(modelo):
		modelo.scale = Vector3.ONE * s
	# Colisión de impacto (esfera)
	var colision: CollisionShape3D = find_child("CollisionShape3D", true, false) as CollisionShape3D
	if is_instance_valid(colision) and colision.shape is SphereShape3D:
		(colision.shape as SphereShape3D).radius = 0.35 * s
	# Estela en proporción
	if is_instance_valid(_estela):
		_estela.scale = Vector3.ONE * s


func _on_body_entered(body: Node) -> void:
	if _muerto or fase != Fase.CAIDA:
		return
	if body.is_in_group("player") or body.is_in_group("allies"):
		var objetivo: Node = body
		var padre: Node = body.get_parent()
		if is_instance_valid(padre) and padre.has_method("take_damage"):
			objetivo = padre
		_aplicar_dano_jugador(objetivo)
		_explotar(false)
		return
	if body is StaticBody3D or body is AnimatableBody3D:
		_explotar(false)


func _on_area_entered(area: Area3D) -> void:
	if _muerto:
		return
	if area == self:
		return
	# Flecha de la jugadora: la detectamos por clase o por grupo/tipo.
	var es_flecha_jugadora: bool = false
	if area is ArrowProjectile:
		if (area as ArrowProjectile).tipo_dueño == ArrowProjectile.TipoFlecha.JUGADOR:
			es_flecha_jugadora = true
	elif area.is_in_group("player_projectiles"):
		es_flecha_jugadora = true
	elif "tipo_dueño" in area and int(area.get("tipo_dueño")) == 0:
		es_flecha_jugadora = true
	if not es_flecha_jugadora:
		return
	if area.has_method("_safe_destroy"):
		area.call("_safe_destroy")
	elif is_instance_valid(area):
		area.queue_free()
	take_damage(1.0)


## Explosión con desintegración naranja de enemigos + VFX según dónde explote.
## en_aire true: destruido por flecha -> VFXAirExplosion_01 + señal destruido.
## en_aire false: suelo/jugador -> VFXGroundExplosion_01 + señal caido.
func _explotar(en_aire: bool) -> void:
	if _muerto:
		return
	_muerto = true
	fase = Fase.IMPACTADO
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	_set_efecto_velocidad(false)
	_spawn_vfx_explosion(en_aire)
	if not en_aire:
		_danar_jugador_en_radio()
		_sacudir_canoa()
		_simular_golpe_perrena()
	_iniciar_desintegracion(en_aire)


func _impactar_suelo() -> void:
	_explotar(false)


func _resolver_sin_dano() -> void:
	if _muerto:
		return
	_muerto = true
	caido.emit(self)
	queue_free()


func _spawn_vfx_explosion(en_aire: bool) -> void:
	var escena: PackedScene = ESCENA_VFX_AIRE if en_aire else ESCENA_VFX_SUELO
	if escena == null:
		return
	var vfx := escena.instantiate() as Node3D
	if vfx == null:
		return
	var raiz: Node = get_tree().current_scene if get_tree() else get_parent()
	if raiz == null:
		raiz = get_tree().root
	raiz.add_child(vfx)
	vfx.global_position = global_position
	vfx.scale = (escala_vfx_aire if en_aire else escala_vfx_suelo) * maxf(escala_explosion, 0.25)
	for hijo in vfx.find_children("*", "GPUParticles3D", true, false):
		if hijo is GPUParticles3D:
			(hijo as GPUParticles3D).restart()
			(hijo as GPUParticles3D).emitting = true
	if vfx.has_method("play"):
		vfx.call("play")
	var tree: SceneTree = get_tree()
	if tree != null:
		tree.create_timer(2.5).timeout.connect(func() -> void:
			if is_instance_valid(vfx):
				vfx.queue_free()
		)


## Desintegración con el dissolve de enemigos en naranja, luego libera y avisa.
func _iniciar_desintegracion(en_aire: bool) -> void:
	_materiales_disolver.clear()
	for m in find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi == null or not is_instance_valid(mi):
			continue
		var material := ShaderMaterial.new()
		material.shader = SHADER_DISOLVER
		material.set_shader_parameter("dissolve_amount", 0.0)
		material.set_shader_parameter("glow_color", COLOR_BORDE_NARANJA)
		material.set_shader_parameter("glow_intensity", 8.0)
		material.set_shader_parameter("edge_thickness", 0.05)
		material.set_shader_parameter("noise_scale", 20.0)
		var original: Material = mi.get_surface_override_material(0)
		if original == null:
			original = mi.material_override
		if original == null and mi.mesh != null and mi.mesh.get_surface_count() > 0:
			original = mi.mesh.surface_get_material(0)
		if original is StandardMaterial3D:
			var tex: Texture2D = (original as StandardMaterial3D).albedo_texture
			if tex != null:
				material.set_shader_parameter("albedo_texture", tex)
			var col: Color = (original as StandardMaterial3D).albedo_color
			material.set_shader_parameter("albedo_tint", Vector3(col.r, col.g, col.b))
		mi.material_override = material
		_materiales_disolver.append(material)
	if _materiales_disolver.is_empty():
		_finalizar_explosion(en_aire)
		return
	var tw := create_tween()
	tw.tween_method(_actualizar_disolucion, 0.0, 1.0, DURACION_DESINTEGRACION)
	tw.tween_callback(_finalizar_explosion.bind(en_aire))


func _actualizar_disolucion(valor: float) -> void:
	for material in _materiales_disolver:
		if is_instance_valid(material):
			(material as ShaderMaterial).set_shader_parameter("dissolve_amount", valor)


func _finalizar_explosion(en_aire: bool) -> void:
	_soltar_cadaver_imp()
	if en_aire:
		destruido.emit(self)
	else:
		caido.emit(self)
	queue_free()


## Al explotar sale volando el cadáver de un Imp con muerte por explosión
## (ragdoll + desmembramiento) y su sonido de muerte.
func _soltar_cadaver_imp() -> void:
	if not cadaver_imp or ESCENA_IMP == null:
		return
	if not is_inside_tree() or get_tree() == null:
		return
	var imp := ESCENA_IMP.instantiate() as Node3D
	if imp == null:
		return
	var raiz: Node = get_tree().current_scene
	if raiz == null:
		raiz = get_tree().root
	raiz.add_child(imp)
	imp.global_position = global_position + Vector3(0.0, 0.5, 0.0)
	# No es un enemigo de la oleada: no bloquea ni cuenta como objetivo.
	if imp.is_in_group("enemies"):
		imp.remove_from_group("enemies")
	if imp.is_in_group("enemigos"):
		imp.remove_from_group("enemigos")
	imp.set("murio_por_explosion", true)
	var lado: float = -0.5 if randi() % 2 == 0 else 0.5
	imp.set("last_hit_position", global_position + Vector3(lado, 0.0, 0.0))
	if has_node("/root/AudioManager"):
		AudioManager.play_sfx("imp_death")
	if imp.has_method("take_damage"):
		imp.call("take_damage", 999.0)


func _aplicar_dano_jugador(objetivo: Node) -> void:
	if _dano_aplicado:
		return
	_dano_aplicado = true
	if objetivo.has_method("take_damage"):
		if "last_hit_position" in objetivo:
			objetivo.set("last_hit_position", global_position)
		objetivo.call("take_damage", DANO_AL_JUGADOR)


func _danar_jugador_en_radio() -> void:
	if _dano_aplicado or get_tree() == null:
		return
	var jugador := get_tree().get_first_node_in_group("player") as Node3D
	if not is_instance_valid(jugador):
		return
	if global_position.distance_to(jugador.global_position) <= 2.5:
		_aplicar_dano_jugador(jugador)


func _sacudir_canoa() -> void:
	var canoa := _buscar_canoa()
	if is_instance_valid(canoa):
		if canoa.has_method("expulsar_escombros_maderos"):
			canoa.call("expulsar_escombros_maderos", global_position)
		if canoa.has_method("sacudida_oleaje"):
			canoa.call("sacudida_oleaje", duracion_oleaje, fuerza_oleaje)


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
		if player_anim.has_animation(nombre):
			player_anim.play(nombre)
			return


func _buscar_canoa() -> Node3D:
	if is_instance_valid(_nodo_canoa):
		return _nodo_canoa
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
	var canoa := _buscar_canoa()
	if is_instance_valid(canoa):
		var directa := (canoa as Node).find_child("DefensoraPerrena", true, false)
		if is_instance_valid(directa):
			return directa
	if get_tree() == null:
		return null
	return get_tree().get_first_node_in_group("defensora_perrena")


func _obtener_altura_agua() -> float:
	if is_inside_tree() and get_tree() != null:
		var escena: Node = get_tree().current_scene
		if is_instance_valid(escena):
			var wp: Node3D = escena.find_child("WaterPlane*", true, false) as Node3D
			if is_instance_valid(wp):
				return wp.global_position.y + 0.01
	return altura_superficie_agua


## Genera el efecto de salpicadura estilo Azulina al romper la superficie del agua en Fase.SUBIDA.
func _generar_splash_salida_agua() -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	var y_agua: float = _obtener_altura_agua()
	var pos_splash: Vector3 = Vector3(global_position.x, y_agua, global_position.z)
	var raiz: Node = get_tree().current_scene
	if raiz == null:
		raiz = get_parent()
	if raiz == null:
		raiz = get_tree().root

	# 1. Salpicadura de onda/pilar de Azulina (splash_vfx)
	if ESCENA_SPLASH != null:
		var sal := ESCENA_SPLASH.instantiate() as Node3D
		if is_instance_valid(sal):
			raiz.add_child(sal)
			sal.global_position = pos_splash
			sal.scale = Vector3.ONE * maxf(escala_splash_agua, 0.1)
			if sal.has_method("play_splash"):
				sal.call("play_splash")
			var timer := get_tree().create_timer(1.2)
			if timer != null:
				timer.timeout.connect(func():
					if is_instance_valid(sal):
						sal.queue_free()
				)

	# 2. Gotas de agua 3D (WaterSplash3D)
	if ESCENA_WATER_SPLASH != null:
		var gotas := ESCENA_WATER_SPLASH.instantiate() as Node3D
		if is_instance_valid(gotas):
			raiz.add_child(gotas)
			gotas.global_position = pos_splash
			gotas.scale = Vector3.ONE * (maxf(escala_splash_agua, 0.1) * 0.8)
			if gotas.has_method("restart"):
				gotas.call("restart")
			elif gotas is GPUParticles3D:
				(gotas as GPUParticles3D).restart()
			var timer_gotas := get_tree().create_timer(1.5)
			if timer_gotas != null:
				timer_gotas.timeout.connect(func():
					if is_instance_valid(gotas):
						gotas.queue_free()
				)

	# 3. Sonido acuático si AudioManager está presente
	if Engine.has_singleton("AudioManager"):
		var am: Node = Engine.get_singleton("AudioManager")
		if am and am.has_method("play_sfx"):
			am.call("play_sfx", "splash_agua")
	elif is_instance_valid(get_tree().root.find_child("AudioManager", true, false)):
		var am: Node = get_tree().root.find_child("AudioManager", true, false)
		if am.has_method("play_sfx"):
			am.call("play_sfx", "splash_agua")

