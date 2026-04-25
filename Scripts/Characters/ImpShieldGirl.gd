extends CharacterBody3D
class_name ImpShieldGirl

## Imp femenino con escudo que protege a otros enemigos.
## Camina hasta posicionarse a la IZQUIERDA del enemigo más cercano
## (entre el jugador y el enemigo) y absorbe flechas con su escudo.
## Cuando el escudo se rompe (3 impactos), huye hacia la derecha.

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURACIÓN
# ═══════════════════════════════════════════════════════════════════════════════

@export_category("Movimiento")
@export var velocidad_caminar: float = 1.5  ## Velocidad al caminar hacia el enemigo
@export var distancia_proteccion: float = 0.5  ## Distancia a la izquierda del enemigo protegido

@export_category("Escudo")
@export var escudo_vida: int = 3  ## Impactos que aguanta el escudo antes de romperse

@export_category("Huida")
@export var velocidad_huida: float = 2.0  ## Velocidad al huir (sin escudo)
@export var distancia_fuera_pantalla: float = 15.0  ## Posición X para destruirse al huir

@export_category("Vida")
@export var vida_maxima: int = 1  ## HP del personaje (cuando no tiene escudo)

@export_category("Efecto de Muerte")
@export var duracion_disolucion: float = 1.0
@export var color_borde_disolucion: Color = Color(0.8, 0.2, 0.8)  ## Color púrpura del borde

@export_category("Modelo")
@export var rotacion_y_modelo: float = 0.0  ## Rotación Y en grados para corregir orientación del modelo

@export_category("Animaciones")
@export var anim_caminar: String = "CAMINAR_ESCUDO_IMP"  ## Animación de caminar
@export var anim_idle: String = "IMP_ESCUDO_IDLE"  ## Animación de defender (idle)
@export var anim_impacto: String = "IMP_ESCUDO_IMPACTO"  ## Animación al recibir impacto en el escudo
@export var anim_escape: String = "IMP_ESCUDO_ESCAPE"  ## Animación de escape (escudo roto)
@export var anim_huida: String = "IMP_ESCUDO_HUIDA"  ## Animación de huida
@export var anim_muertes: PackedStringArray = [
	"IMP_ESCUDO_MUERTE01", "IMP_ESCUDO_MUERTE02", "IMP_ESCUDO_MUERTE03"
]  ## Animaciones de muerte (aleatoria)

@export_category("Posición Libre")
@export var rango_posicion_libre: Vector2 = Vector2(1.0, 10.0)  ## Rango X aleatorio si no hay enemigo

# ═══════════════════════════════════════════════════════════════════════════════
# REFERENCIAS
# ═══════════════════════════════════════════════════════════════════════════════

var dissolve_shader = preload("res://Assets/Shaders/dissolve.gdshader")
var anim_player: AnimationPlayer
var escudo_node: Node3D  ## Nodo del modelo del escudo
var model_root: Node3D  ## Nodo raíz del modelo del personaje

# ═══════════════════════════════════════════════════════════════════════════════
# ESTADO
# ═══════════════════════════════════════════════════════════════════════════════

enum State { WALKING, DEFENDING, SHIELD_HIT, ESCAPING, FLEEING, DYING, DEAD }
var current_state: State = State.WALKING
var escudo_vida_actual: int = 3
var health: int = 1
var enemigo_protegido: Node3D = null  ## Referencia al enemigo que estamos protegiendo
var spawn_position: Vector3 = Vector3.ZERO  ## Posición de spawn original
var is_dissolving: bool = false
var dissolve_materials: Array = []
var hit_anim_timer: float = 0.0  ## Timer para volver de SHIELD_HIT a DEFENDING
var posicion_libre_destino: float = -1.0  ## Posición X destino cuando no hay enemigo

var _escudo_meshes: Array = []
var _flash_mat: StandardMaterial3D

static var _cached_wave_spawner: Node = null


func _get_cached_wave_spawner() -> Node:
	if is_instance_valid(_cached_wave_spawner):
		return _cached_wave_spawner

	if get_tree() == null:
		return null

	_cached_wave_spawner = get_tree().get_first_node_in_group("wave_spawners")
	if _cached_wave_spawner:
		return _cached_wave_spawner

	var scene_root = get_tree().current_scene
	if scene_root == null:
		scene_root = get_tree().root.get_child(get_tree().root.get_child_count() - 1)

	var wave_spawner = scene_root.find_child("WaveSpawner", true, false)
	if wave_spawner:
		_cached_wave_spawner = wave_spawner
	return _cached_wave_spawner


# === SEÑALES ===
signal died

# ═══════════════════════════════════════════════════════════════════════════════
# INICIALIZACIÓN
# ═══════════════════════════════════════════════════════════════════════════════


func _ready():
	add_to_group("enemies")
	add_to_group("shield_imps")
	EnemyBase.active_shield_imps_cache.append(self)
	EnemyBase.active_enemies_cache.append(self)
	escudo_vida_actual = escudo_vida
	health = vida_maxima
	spawn_position = global_position

	_flash_mat = StandardMaterial3D.new()
	_flash_mat.albedo_color = Color(1, 1, 1)
	_flash_mat.emission_enabled = true
	_flash_mat.emission = Color(1, 1, 1)
	_flash_mat.emission_energy_multiplier = 3.0

	_setup_animation_player()
	_buscar_escudo()
	_aplicar_rotacion_modelo()

	# Iniciar caminando
	_play_animation(anim_caminar)

	# Buscar enemigo a proteger después de un frame (para que todos estén listos)
	call_deferred("_buscar_enemigo_a_proteger")


func _aplicar_rotacion_modelo():
	## Aplica rotación Y al modelo raíz para corregir orientación
	if rotacion_y_modelo == 0.0:
		return
	# Buscar el nodo del modelo GLB
	var model = find_child("GIRL_IMP_ESCUDO", true, false)
	if model:
		model.rotation_degrees.y = rotacion_y_modelo


func _setup_animation_player():
	# Desactivar AnimationTrees si existen
	var trees = find_children("*", "AnimationTree", true, false)
	for tree in trees:
		tree.active = false

	# Buscar AnimationPlayer con animaciones del personaje
	var all_players = find_children("*", "AnimationPlayer", true, false)
	for player in all_players:
		var anims = player.get_animation_list()
		for a in anims:
			if "IMP_ESCUDO" in a or "CAMINAR_ESCUDO" in a:
				anim_player = player
				break
		if anim_player:
			break

	if not anim_player:
		push_warning("[ImpShieldGirl] No se encontró AnimationPlayer!")
		return

	# === DEBUG: Listar todas las animaciones ===
	print("[ImpShieldGirl] ═══ ANIMACIONES ENCONTRADAS ═══")
	for anim_name in anim_player.get_animation_list():
		var anim = anim_player.get_animation(anim_name)
		var dur = anim.length if anim else 0.0
		var loop_txt = "LOOP" if anim and anim.loop_mode != Animation.LOOP_NONE else "ONCE"
		print("  → ", anim_name, " (", "%.2f" % dur, "s, ", loop_txt, ")")
	print("[ImpShieldGirl] ═══════════════════════════════")

	# Configurar loops en CAMINAR, IDLE, HUIDA
	for anim_name in anim_player.get_animation_list():
		if "CAMINAR" in anim_name or "IDLE" in anim_name or "HUIDA" in anim_name:
			var anim = anim_player.get_animation(anim_name)
			if anim:
				anim.loop_mode = Animation.LOOP_LINEAR


func _buscar_escudo():
	# Buscar el nodo del escudo (instancia de ESCUDO_IMP.glb)
	escudo_node = find_child("ESCUDO_IMP", true, false)
	if not escudo_node:
		# Buscar por nombre alternativo
		for child in get_children():
			if "ESCUDO" in child.name.to_upper() and child is Node3D:
				escudo_node = child
				break

	_escudo_meshes.clear()
	if escudo_node:
		if escudo_node is MeshInstance3D:
			_escudo_meshes.append(escudo_node)
		else:
			_escudo_meshes = escudo_node.find_children("*", "MeshInstance3D", true, false)


func _buscar_enemigo_a_proteger():
	var enemies = []
	var wave_spawner = _get_cached_wave_spawner()
	if wave_spawner and wave_spawner.has_method("get_active_enemies"):
		enemies = wave_spawner.get_active_enemies()
	else:
		enemies = EnemyBase.active_enemies_cache

	var mejor_enemigo: Node3D = null
	var menor_x: float = INF

	for enemy in enemies:
		if enemy == self:
			continue
		if not is_instance_valid(enemy) or not enemy.is_inside_tree():
			continue
		if enemy is ImpShieldGirl:
			continue  # No proteger a otras ImpShieldGirl

		# Solo proteger enemigos que estén en SHOOTING (parados/disparando)
		if enemy is EnemyBase:
			if enemy.current_state != EnemyBase.State.SHOOTING:
				continue
			if (
				enemy.current_state == EnemyBase.State.DYING
				or enemy.current_state == EnemyBase.State.DEAD
			):
				continue

		# Elegir el enemigo más a la izquierda (más cercano al jugador)
		if enemy.global_position.x < menor_x:
			menor_x = enemy.global_position.x
			mejor_enemigo = enemy

	if mejor_enemigo:
		enemigo_protegido = mejor_enemigo
		posicion_libre_destino = -1.0  # Reset posición libre
	else:
		enemigo_protegido = null


# ═══════════════════════════════════════════════════════════════════════════════
# PROCESO PRINCIPAL
# ═══════════════════════════════════════════════════════════════════════════════


func _physics_process(delta):
	# Gravedad
	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta

	match current_state:
		State.WALKING:
			_process_walking(delta)
		State.DEFENDING:
			_process_defending(delta)
		State.SHIELD_HIT:
			_process_shield_hit(delta)
		State.ESCAPING:
			_process_escaping(delta)
		State.FLEEING:
			_process_fleeing(delta)
		State.DYING:
			velocity.x = 0
		State.DEAD:
			pass

	move_and_slide()


# ═══════════════════════════════════════════════════════════════════════════════
# ESTADOS
# ═══════════════════════════════════════════════════════════════════════════════


func _process_walking(delta):
	# Si no hay enemigo a proteger, buscar uno
	if not enemigo_protegido or not is_instance_valid(enemigo_protegido):
		_buscar_enemigo_a_proteger()
		if not enemigo_protegido:
			# Sin enemigos: ir a posición libre aleatoria
			if posicion_libre_destino < 0:
				posicion_libre_destino = randf_range(rango_posicion_libre.x, rango_posicion_libre.y)
				print(
					"[ImpShieldGirl] Sin enemigo → posición libre X=",
					"%.1f" % posicion_libre_destino
				)

			var dist_to_free = global_position.x - posicion_libre_destino
			if dist_to_free > 0.1:
				velocity.x = -velocidad_caminar
			else:
				velocity.x = 0
				_cambiar_estado(State.DEFENDING)
			return
		else:
			posicion_libre_destino = -1.0  # Encontramos enemigo, reset

	# Verificar que el enemigo siga en SHOOTING (no haya muerto o se haya movido)
	if (
		enemigo_protegido is EnemyBase
		and enemigo_protegido.current_state != EnemyBase.State.SHOOTING
	):
		# Enemigo murió o cambió, nos plantamos aquí
		velocity.x = 0
		_cambiar_estado(State.DEFENDING)
		return

	# Calcular posición objetivo: a la izquierda del enemigo protegido
	var target_x = enemigo_protegido.global_position.x - distancia_proteccion
	var dist_to_target = global_position.x - target_x

	if dist_to_target > 0.1:
		# Todavía no llegamos, seguir caminando
		velocity.x = -velocidad_caminar
	else:
		# Llegamos, empezar a defender
		velocity.x = 0
		_cambiar_estado(State.DEFENDING)


func _process_defending(_delta):
	velocity.x = 0
	# Mantener posición estática, ya no persigue a otro enemigo si muere.


func _process_shield_hit(delta):
	velocity.x = 0
	hit_anim_timer -= delta
	if hit_anim_timer <= 0:
		_cambiar_estado(State.DEFENDING)


func _process_escaping(_delta):
	velocity.x = 0


func _process_fleeing(_delta):
	velocity.x = velocidad_huida  # Huir hacia la derecha (X positivo)

	# Destruirse si sale de pantalla
	if global_position.x > spawn_position.x + distancia_fuera_pantalla:
		_limpiar_y_destruir()


# ═══════════════════════════════════════════════════════════════════════════════
# CAMBIO DE ESTADO
# ═══════════════════════════════════════════════════════════════════════════════


func _cambiar_estado(nuevo: State):
	current_state = nuevo
	match nuevo:
		State.WALKING:
			_play_animation(anim_caminar)
		State.DEFENDING:
			_play_animation(anim_idle)
		State.SHIELD_HIT:
			_play_animation(anim_impacto)
			AudioManager.play_sfx("shield_imp_impact")
			hit_anim_timer = _get_animation_duration(anim_impacto)
		State.ESCAPING:
			pass
		State.FLEEING:
			_play_animation(anim_huida)
		State.DYING:
			_on_dying()
		State.DEAD:
			pass


# ═══════════════════════════════════════════════════════════════════════════════
# DAÑO
# ═══════════════════════════════════════════════════════════════════════════════


func take_damage(amount: float):
	if current_state == State.DYING or current_state == State.DEAD:
		return

	if escudo_vida_actual > 0:
		# El escudo absorbe el daño
		escudo_vida_actual -= 1
		_flash_escudo()

		if escudo_vida_actual > 0:
			_cambiar_estado(State.SHIELD_HIT)
		else:
			# Escudo roto -> Muere instantáneamente junto con el escudo
			if escudo_node and is_instance_valid(escudo_node):
				escudo_node.visible = false
			health = 0
			_cambiar_estado(State.DYING)


func recibir_dano(amount: int):
	take_damage(float(amount))


func _flash_escudo():
	## Flash blanco rápido en el escudo al recibir impacto
	if not escudo_node or not is_instance_valid(escudo_node):
		return

	var originals: Array = []
	for mesh in _escudo_meshes:
		if is_instance_valid(mesh):
			originals.append({"mesh": mesh, "mat": mesh.material_override})
			mesh.material_override = _flash_mat

	get_tree().create_timer(0.08).timeout.connect(
		func():
			for item in originals:
				if is_instance_valid(item["mesh"]):
					item["mesh"].material_override = item["mat"]
	)


# ═══════════════════════════════════════════════════════════════════════════════
# MUERTE Y DISOLUCIÓN
# ═══════════════════════════════════════════════════════════════════════════════


func _on_dying():
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)

	AudioManager.play_sfx("shield_imp_death")

	# Elegir muerte aleatoria de los exports
	var chosen = anim_muertes[randi() % anim_muertes.size()]
	_play_animation(chosen)

	var dur = _get_animation_duration(chosen)
	get_tree().create_timer(dur + 0.5).timeout.connect(
		func():
			if is_instance_valid(self) and is_inside_tree():
				_start_dissolve()
	)


func _start_dissolve():
	if is_dissolving:
		return
	is_dissolving = true

	var meshes = find_children("*", "MeshInstance3D", true, false)
	for mesh in meshes:
		if not is_instance_valid(mesh):
			continue
		var mat = ShaderMaterial.new()
		mat.shader = dissolve_shader
		mat.set_shader_parameter("dissolve_amount", 0.0)
		mat.set_shader_parameter("glow_color", color_borde_disolucion)
		mat.set_shader_parameter("glow_intensity", 3.0)
		mat.set_shader_parameter("edge_thickness", 0.05)
		mat.set_shader_parameter("noise_scale", 20.0)

		var orig = mesh.material_override
		if orig == null and mesh.mesh:
			orig = mesh.mesh.surface_get_material(0)
		if orig and orig is StandardMaterial3D:
			var tex = orig.albedo_texture
			if tex:
				mat.set_shader_parameter("albedo_texture", tex)
			var col = orig.albedo_color
			mat.set_shader_parameter("albedo_tint", Vector3(col.r, col.g, col.b))

		mesh.material_override = mat
		dissolve_materials.append({"mesh": mesh, "material": mat})

	var tween = create_tween()
	tween.tween_method(_update_dissolve, 0.0, 1.0, duracion_disolucion)
	tween.tween_callback(_finish_dissolve)


func _update_dissolve(value: float):
	for item in dissolve_materials:
		if is_instance_valid(item["mesh"]):
			item["material"].set_shader_parameter("dissolve_amount", value)


func _finish_dissolve():
	for mesh in find_children("*", "MeshInstance3D", true, false):
		if is_instance_valid(mesh):
			mesh.material_override = null
			mesh.visible = false
	dissolve_materials.clear()
	current_state = State.DEAD
	died.emit()
	queue_free()


func _exit_tree():
	EnemyBase.active_shield_imps_cache.erase(self)
	EnemyBase.active_enemies_cache.erase(self)


func _limpiar_y_destruir():
	current_state = State.DEAD
	died.emit()
	queue_free()


# ═══════════════════════════════════════════════════════════════════════════════
# ANIMACIÓN
# ═══════════════════════════════════════════════════════════════════════════════


func _play_animation(anim_name: String, custom_blend: float = -1.0, speed: float = 1.0):
	if not anim_player:
		return

	# Intentar con diferentes prefijos (por compatibilidad con distintos formatos de .glb)
	var possible_names = [anim_name, "Armature|" + anim_name, "Armature|Armature|" + anim_name]
	for possible_anim in possible_names:
		if anim_player.has_animation(possible_anim):
			anim_player.play(possible_anim, custom_blend, speed)
			return

	push_warning("[ImpShieldGirl] Animación no encontrada: " + anim_name)


func _get_animation_duration(anim_name: String) -> float:
	if not anim_player:
		return 2.0

	var possible_names = [anim_name, "Armature|" + anim_name, "Armature|Armature|" + anim_name]
	for possible_anim in possible_names:
		if anim_player.has_animation(possible_anim):
			return anim_player.get_animation(possible_anim).length

	return 2.0
