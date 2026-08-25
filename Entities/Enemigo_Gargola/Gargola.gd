class_name Gargola
extends EnemyBase

## Gárgola voladora: aparece del spawn a altura fija (solo una de dos opciones),
## oscila arriba/abajo, usa FLY_IDLE para idle y desplazamiento. Ciclo de ataque:
##   CARGA_ATAQUE (solo animación) → ATACAR → 2 proyectiles rectos con dispersión.
const PROJECTILE_POOL_REF = preload("res://System/Core/ProjectilePool.gd")
const GARGOLA_PROJECTILE_COLOR: Color = Color(1.0, 0.1, 0.05)
const PROJECTILE_SCALE: Vector3 = Vector3.ONE
const SPAWN_OFFSET_LOCAL: Vector3 = Vector3(0.0, 0.1, 0.3)

# === CONFIGURACIÓN VUELO ===
@export_category("Vuelo - Gargola")
## Alturas fijas de spawn: la gárgola sale SIEMPRE en una u otra (nunca en medio).
@export var altura_spawn_baja: float = 3.3
@export var altura_spawn_alta: float = 5.2
@export var amplitud_oscilacion: float = 0.12
@export var velocidad_oscilacion: float = 1.8

# === CONFIGURACIÓN COMBATE ===
@export_category("Combate - Gargola")
@export var intervalo_disparo: float = 2.0
@export var velocidad_proyectil: float = 9.0
@export var dispersion_min_radianes: float = 0.07
@export var dispersion_max_radianes: float = 0.15
@export var num_proyectiles: int = 1
@export var tiempo_disparo_en_atacar: float = 0.4
@export_range(1.0, 3.0, 0.05) var multiplicador_velocidad_acelerada: float = 1.5  ## Velocidad de la variante acelerada (50% de las gárgolas entra acelerada)

# === CONFIGURACIÓN RAGDOLL (muerte como trapo) ===
@export_category("Ragdoll - Gargola")
## Empuje horizontal (hacia la derecha, +X) al morir para que tumbe de costado
## en vez de caer tiesa de frente y deformarse al golpear el suelo.
@export var impulso_horizontal_ragdoll: float = 0.8
## Tiempo que el trapo permanece en el suelo antes de disolverse.
@export var tiempo_espera_disolucion_trapo: float = 2.5

# === ESTADO INTERNO ===
enum FaseCombate { IDLE, CARGA, ATAQUE }

const COLOR_ANTICIPACION: Color = Color(1.491, 0.277, 0.55)

## Tope de la velocidad angular correctora del active-ragdoll (rad/s).
## Dividir diff_euler por delta sin límite produce picos enormes que azotan
## los miembros y estiran la piel del modelo durante la caída.
const MAX_VELOCIDAD_ANGULAR_CORRECCION: float = 10.0

var altura_base: float = 4.3
var oscilacion_fase: float = 0.0
var fase_combate: int = FaseCombate.IDLE
var timer_combate: float = 0.0
var ha_disparado_este_ciclo: bool = false
var ha_mostrado_anticipacion: bool = false
var omni_light_ataque: OmniLight3D = null

var tiempo_ragdoll_activo: float = 0.0
var ragdoll_listo_para_disolucion: bool = false

# === PUNTO DE SPAWN (sin visual en CARGA_ATAQUE) ===
var bone_attachment_spawn: BoneAttachment3D = null
var spawn_marker: Node3D = null
var ragdoll_simulator: PhysicalBoneSimulator3D = null
var huesos_fisicos_creados: Array[PhysicalBone3D] = []
var ragdoll_hueso_raiz: String = ""
## La simulacion se arranca un frame despues de crear los huesos, para que el
## esqueleto construya las articulaciones y no exploten por error inicial.
var ragdoll_inicio_pendiente: bool = false
var ragdoll_relajado: bool = false
## True cuando la física de huesos ya conduce al cadáver: el CharacterBody3D
## deja de caer por su cuenta y se ancla al trapo (evita doble movimiento).
var ragdoll_simulacion_activa: bool = false

# === REFERENCIAS ===
var gargola_projectile_scene: PackedScene = preload("res://Entities/Proyectil_Gargola/GargolaProjectile.tscn")
var vfx_anticipacion_fire_scene: PackedScene = preload("res://VFX/Scenes/VFX_Anticipation_fire_3.tscn")
var vfx_hit_01_scene: PackedScene = preload("res://HitFXFree/assets/BinbunVFX_Vol2/StylizedHitFX/effects/hit/vfx_hit_01.tscn")

@export_category("Drops")
@export var posion_scene: PackedScene = preload("res://Entities/Item_Pocion/Posion.tscn")
@export_range(0.0, 1.0, 0.01) var posion_drop_chance: float = 0.30  ## 30% de probabilidad de dropear poción


# ═══════════════════════════════════════════════════════════════════════════════
# HOOKS DE ENEMYBASE
# ═══════════════════════════════════════════════════════════════════════════════


func _on_enemy_ready():
	# Desactivar colisiones de los huesos físicos en vida para que no choquen contra el escenario
	# y empujen la gárgola fuera del eje Z.
	if skeleton:
		for child in skeleton.get_children():
			if child is PhysicalBoneSimulator3D:
				for bone in child.get_children():
					if bone is PhysicalBone3D:
						bone.collision_layer = 0
						bone.collision_mask = 0
						# Forzar desactivación inmediata en el servidor de físicas
						PhysicsServer3D.body_set_collision_layer(bone.get_rid(), 0)
						PhysicsServer3D.body_set_collision_mask(bone.get_rid(), 0)

	# Spawn en una de dos alturas fijas (nunca en medio)
	if randf() < 0.5:
		altura_base = altura_spawn_baja
	else:
		altura_base = altura_spawn_alta
	oscilacion_fase = randf() * TAU

	# Dos velocidades de entrada: la mitad entran aceleradas
	if randf() < 0.5:
		velocidad_caminar *= multiplicador_velocidad_acelerada

	tiempo_ragdoll_activo = 0.0
	ragdoll_listo_para_disolucion = false
	ragdoll_relajado = false
	ragdoll_simulacion_activa = false

	# Apunta recto, no necesita tracking de torso (vuela)
	rastrear_jugador = false

	# Color místico para partículas de disolución
	color_borde_disolucion = Color(0.4, 0.2, 0.8)
	# Excluida de efectos de sangre
	tiene_sangre = false

	scale = Vector3(0.9, 0.9, 0.9)
	_crear_punto_spawn()
	_apagar_omni_light()
	_play_animation("FLY_IDLE")


func _on_state_walking():
	_play_animation("FLY_IDLE")
	fase_combate = FaseCombate.IDLE
	timer_combate = 0.0


func _on_state_shooting():
	fase_combate = FaseCombate.IDLE
	timer_combate = 0.0
	ha_disparado_este_ciclo = false
	_play_animation("FLY_IDLE")


func _detener_animacion() -> void:
	if anim_player:
		anim_player.stop(true)


func take_damage(amount: float) -> void:
	if current_state == State.DYING or current_state == State.DEAD:
		return
	# Ya no pausa la animación al recibir daño, puede ser dañado en cualquier momento
	fase_combate = FaseCombate.IDLE
	_apagar_omni_light()
	
	# Reproducir sonido de impacto/herida
	AudioManager.play_sfx("gargola_herida")

	# Destello de explosión SOLO en golpes no letales:
	# al golpe de muerte no le corresponde destello.
	if health - int(amount) > 0:
		# Spawnear animación de explosión en spritesheet 3x4 en lugar de sangre
		var spawn_pos: Vector3 = last_hit_position if not last_hit_position.is_zero_approx() else (global_position + Vector3(0, 0.4, 0))
		ImpactoGargolaVFX.spawn(self, spawn_pos)
	
	super.take_damage(amount)


func _on_state_dying():
	_apagar_omni_light()

	# VFXHit_01 en el punto de muerte (antes del ragdoll para capturar posición exacta).
	_spawn_vfx_hit_01_muerte()

	# La Gárgola se convierte en ragdoll (trapo) al morir, sin textura de piedra.
	_activar_ragdoll()
	tiempo_ragdoll_activo = 0.0
	
	# Reproducir sonido de muerte
	AudioManager.play_sfx("gargola_death")
	_drop_pocion()


func _spawn_vfx_hit_01_muerte() -> void:
	if not vfx_hit_01_scene:
		return
	var vfx: Node3D = vfx_hit_01_scene.instantiate() as Node3D
	if not vfx:
		return
	var pos_muerte: Vector3 = _get_hips_global_position()
	if pos_muerte.is_zero_approx():
		pos_muerte = global_position + Vector3(0.0, 0.4, 0.0)
	# Más pequeño y naranjo (pedido)
	vfx.scale = Vector3(0.65, 0.65, 0.65)
	var parent_escena := get_tree().current_scene
	if parent_escena == null:
		parent_escena = get_tree().root
	parent_escena.add_child(vfx)
	vfx.global_position = pos_muerte
	# Color naranjo: primario vivo, secundario cálido
	if "primary_color" in vfx:
		vfx.set("primary_color", Color(1.0, 0.45, 0.0))
	if "secondary_color" in vfx:
		vfx.set("secondary_color", Color(1.0, 0.65, 0.15))
	# Asegurar reproducción única y limpieza automática (main dura 1.6s)
	if "one_shot" in vfx:
		vfx.set("one_shot", true)
	if vfx.has_method("play"):
		vfx.call("play")
	get_tree().create_timer(2.0).timeout.connect(func():
		if is_instance_valid(vfx):
			vfx.queue_free()
	)


func _drop_pocion() -> void:
	if not posion_scene:
		return
	if randf() > posion_drop_chance:
		return
	var posion := posion_scene.instantiate() as Node3D
	if not posion:
		return
	var target_parent := get_tree().current_scene
	if target_parent:
		target_parent.add_child(posion)
	elif get_parent():
		get_parent().add_child(posion)
	posion.global_position = global_position + Vector3(0.0, 0.5, 0.0)


func _activar_ragdoll() -> void:
	collision_layer = 0
	collision_mask = 1 # Colisionar contra el suelo para detener el CharacterBody3D en la superficie
	
	# Aplicar retroceso (knockback) horizontal y vertical al cuerpo al morir
	var fuerza_retroceso_x := 5.0 # Empuje hacia la derecha (+X)
	var fuerza_retroceso_y := 2.5 # Pequeña elevación inicial para dibujar una parábola
	if not last_hit_direction.is_zero_approx():
		# Proyectar el empuje en X basado en la dirección del impacto
		velocity.x = sign(last_hit_direction.x) * fuerza_retroceso_x
	else:
		velocity.x = fuerza_retroceso_x
	velocity.y = fuerza_retroceso_y
	velocity.z = 0.0
	
	# Buscar el simulador de huesos físicos preconfigurado en el Skeleton3D
	if ragdoll_simulator == null and skeleton:
		for child in skeleton.get_children():
			if child is PhysicalBoneSimulator3D:
				ragdoll_simulator = child
				break
				
	if ragdoll_simulator != null:
		# Recolectamos los huesos físicos para aplicarles impulsos y disolución
		huesos_fisicos_creados.clear()
		for child in ragdoll_simulator.get_children():
			if child is PhysicalBone3D:
				child.collision_layer = 4
				child.collision_mask = 1
				# Forzar activación inmediata en el servidor de físicas para colisionar contra el suelo
				PhysicsServer3D.body_set_collision_layer(child.get_rid(), 4)
				PhysicsServer3D.body_set_collision_mask(child.get_rid(), 1)
				huesos_fisicos_creados.append(child)
				# Hueso raíz: el primero sin joint, o por defecto el primer hueso físico
				if child.joint_type == PhysicalBone3D.JOINT_TYPE_NONE and ragdoll_hueso_raiz == "":
					ragdoll_hueso_raiz = child.bone_name
		if ragdoll_hueso_raiz == "" and not huesos_fisicos_creados.is_empty():
			ragdoll_hueso_raiz = huesos_fisicos_creados[0].bone_name
	else:
		push_warning("Ragdoll Gárgola: No se encontró PhysicalBoneSimulator3D en el esqueleto. Asegúrate de crearlo en la interfaz de Godot.")

	# Arrancar la simulacion un frame mas tarde (ver _procesar_muerte)
	ragdoll_inicio_pendiente = true


func _iniciar_simulacion_ragdoll() -> void:
	if not ragdoll_simulator or not is_instance_valid(ragdoll_simulator):
		return
	ragdoll_inicio_pendiente = false
	
	# La simulación física arranca con el AnimationPlayer todavía activo,
	# para poder realizar una mezcla gradual (Active Ragdoll) por velocidad.
	ragdoll_simulator.physical_bones_start_simulation()
	
	# Transferir la velocidad lineal de knockback del cuerpo principal (CharacterBody3D)
	# a todos los huesos físicos para que arranquen su simulación con esa velocidad parabólica inicial.
	for pb in huesos_fisicos_creados:
		if is_instance_valid(pb):
			pb.linear_velocity = velocity
	
	_aplicar_impulso_de_impacto()

	# A partir de aquí la física de huesos conduce al cadáver
	ragdoll_simulacion_activa = true


func _aplicar_impulso_de_impacto() -> void:
	if last_hit_direction.is_zero_approx():
		# Fallback: todos los huesos ya tienen asignada la velocidad de knockback en 'pb.linear_velocity = velocity'
		return
		
	# Usar un RayCast3D mediante DirectSpaceState para buscar el hueso físico golpeado
	var space_state := get_world_3d().direct_space_state
	if not space_state:
		return
		
	# Lanzar el rayo desde un poco antes de la posición del impacto
	var origen_rayo := last_hit_position - last_hit_direction * 0.5
	var destino_rayo := last_hit_position + last_hit_direction * 1.5
	
	var query := PhysicsRayQueryParameters3D.create(origen_rayo, destino_rayo)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = 4 # Capa 4 de los PhysicalBones
	
	var result := space_state.intersect_ray(query)
	var hueso_golpeado: PhysicalBone3D = null
	
	if not result.is_empty() and result.collider is PhysicalBone3D:
		hueso_golpeado = result.collider
		
	# Fallback si el rayo no pegó directamente: buscar el hueso físico más cercano
	if not hueso_golpeado:
		var dist_min := 99999.0
		for pb in huesos_fisicos_creados:
			if is_instance_valid(pb):
				var dist := pb.global_position.distance_to(last_hit_position)
				if dist < dist_min:
					dist_min = dist
					hueso_golpeado = pb
					
	# Aplicar el impulso al hueso golpeado
	if hueso_golpeado and is_instance_valid(hueso_golpeado):
		var fuerza_impulso := 3.0 # Fuerza de empuje del impacto (moderada para evitar estiramientos elásticos)
		hueso_golpeado.apply_central_impulse(last_hit_direction * fuerza_impulso)
	else:
		# Fallback general: aplicar el impulso horizontal solo al hueso raíz del ragdoll,
		# dejando que Jolt propague de forma natural el movimiento al resto del esqueleto.
		var raiz: PhysicalBone3D = null
		if ragdoll_hueso_raiz != "" and skeleton:
			var node_raiz = skeleton.find_child(ragdoll_hueso_raiz, true, false)
			if node_raiz is PhysicalBone3D:
				raiz = node_raiz
		if not raiz and not huesos_fisicos_creados.is_empty():
			raiz = huesos_fisicos_creados[0]
			
		if raiz and is_instance_valid(raiz):
			raiz.linear_velocity = Vector3(impulso_horizontal_ragdoll, 0.0, 0.0)


# ═══════════════════════════════════════════════════════════════════════════════
# FÍSICA (Override: vuelo sin gravedad, oscilación vertical)
# ═══════════════════════════════════════════════════════════════════════════════


func _physics_process(delta):
	if current_state == State.DEAD:
		return

	if current_state == State.DYING:
		_procesar_muerte(delta)
		return

	oscilacion_fase += delta * velocidad_oscilacion
	velocity.y = 0.0
	velocity.z = 0.0
	global_position.y = altura_base + sin(oscilacion_fase) * amplitud_oscilacion

	match current_state:
		State.WALKING:
			_procesar_vuelo(delta)
		State.SHOOTING:
			_procesar_combate(delta)
		State.DEAD:
			pass

	_empujar_si_en_barrera()
	move_and_slide()


func _procesar_muerte(delta: float) -> void:
	# Arrancar la simulacion un frame despues de crear los huesos (ver _activar_ragdoll).
	if ragdoll_inicio_pendiente:
		_iniciar_simulacion_ragdoll()

	if ragdoll_simulacion_activa:
		# El cadáver lo lleva la física de los huesos: anclar el CharacterBody3D
		# al centro del trapo. Caer por cuenta propia EN PARALELO diverge del
		# ragdoll y estira la piel entre huesos animados y huesos simulados.
		global_position = _get_hips_global_position()
	else:
		# Caída cinemática breve hasta que arranque la simulación
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
		# Desaceleración suave del impulso de impacto en X
		velocity.x = move_toward(velocity.x, 0.0, delta * 3.0)
		velocity.z = 0.0
		move_and_slide()

	tiempo_ragdoll_activo += delta
	
	# Transición gradual de Animación a Ragdoll (Active Ragdoll Blend de 100% a 0%)
	# Usamos una curva de atenuación cúbica a lo largo de 1.5 segundos.
	# Esto causa que la influencia de la animación baje de 1.0 a 0.0 de forma desacelerada
	# (la pérdida de rigidez se va deteniendo suavemente a medida que se acerca a cero).
	var t_blend := clampf(tiempo_ragdoll_activo / 1.5, 0.0, 1.0)
	var blend := pow(1.0 - t_blend, 3.0)
	
	if skeleton:
		for pb in huesos_fisicos_creados:
			if is_instance_valid(pb):
				var bone_idx = skeleton.find_bone(pb.bone_name)
				if bone_idx != -1:
					# Calcular la posición animada global del hueso en el esqueleto
					var pose_animada_global = skeleton.global_transform * skeleton.get_bone_global_pose(bone_idx)
					
					# Alinear rotación aplicando una velocidad angular correctora basada en los ángulos de Euler.
					# Con tope: sin él, diff/delta genera picos que azotan los brazos y estiran el modelo.
					var diff_rot = pose_animada_global.basis * pb.global_transform.basis.inverse()
					var correccion_angular = (diff_rot.get_euler() / delta).limit_length(MAX_VELOCIDAD_ANGULAR_CORRECCION)
					pb.angular_velocity = correccion_angular * blend + pb.angular_velocity * (1.0 - blend)
						
	# Al finalizar el blend (1.5 segundos), congelamos definitivamente el AnimationPlayer
	# y relajamos los joints para que colapsen completamente sobre el suelo.
	if tiempo_ragdoll_activo >= 1.5 and not ragdoll_relajado:
		ragdoll_relajado = true
		if anim_player:
			anim_player.process_mode = Node.PROCESS_MODE_DISABLED
		for pb in huesos_fisicos_creados:
			if is_instance_valid(pb):
				pb.angular_damp = 2.0 # Damping de caída libre relajado
				pb.set("joint_constraints/cone_angle", 40.0) # Límite relajado para amoldarse al suelo
				
	if not ragdoll_listo_para_disolucion and tiempo_ragdoll_activo >= tiempo_espera_disolucion_trapo:
		ragdoll_listo_para_disolucion = true
		_iniciar_disolucion_final()


func _iniciar_disolucion_final() -> void:
	if current_state == State.DEAD or is_dissolving:
		return
	super._die()


func _procesar_vuelo(delta):
	velocity.x = -velocidad_caminar
	walked_distance += velocidad_caminar * delta

	if modo_pacifico:
		if global_position.x <= limite_pacifico_x:
			velocity.x = 0
			if not pacifico_detenido:
				pacifico_detenido = true
				_on_pacifico_detenido()
		return

	if walked_distance >= target_walk_distance:
		if _check_spacing():
			_change_state(State.SHOOTING)
		else:
			target_walk_distance += 0.3


func _procesar_combate(delta):
	velocity.x = 0
	timer_combate += delta

	match fase_combate:
		FaseCombate.IDLE:
			if timer_combate >= intervalo_disparo:
				fase_combate = FaseCombate.CARGA
				timer_combate = 0.0
				ha_disparado_este_ciclo = false
				ha_mostrado_anticipacion = false
				_play_animation("CARGA_ATAQUE", -1.0, 1.0)

		FaseCombate.CARGA:
			var duracion_carga: float = _get_animation_duration("CARGA_ATAQUE")
			if duracion_carga <= 0.0:
				duracion_carga = 1.0
			# La anticipación aparece al final de la animación de carga (75% del tiempo de carga)
			if not ha_mostrado_anticipacion and timer_combate >= duracion_carga * 0.75:
				ha_mostrado_anticipacion = true
				_spawn_anticipation_vfx()

			if timer_combate >= duracion_carga:
				fase_combate = FaseCombate.ATAQUE
				timer_combate = 0.0
				_play_animation("ATACAR")

		FaseCombate.ATAQUE:
			var duracion_atacar: float = _get_animation_duration("ATACAR")
			if not ha_disparado_este_ciclo and timer_combate >= tiempo_disparo_en_atacar:
				_disparar_proyectiles()
				ha_disparado_este_ciclo = true
				_apagar_omni_light()
			if timer_combate >= duracion_atacar:
				fase_combate = FaseCombate.IDLE
				timer_combate = 0.0
				_apagar_omni_light()
				_play_animation("FLY_IDLE")


func _empujar_si_en_barrera():
	if current_state == State.DYING or current_state == State.DEAD:
		return
	var barreras: Array[Node] = []
	barreras.assign(get_tree().get_nodes_in_group("barrera_destruye_flechas"))
	if barreras.is_empty():
		return
	for barrera_untyped in barreras:
		if not is_instance_valid(barrera_untyped):
			continue
		var barrera := barrera_untyped as Node3D
		if not barrera:
			continue
		var tam_x: float = 1.0
		if "tamano" in barrera:
			tam_x = barrera.tamano.x
		var limite_izquierdo: float = barrera.global_position.x - (tam_x * 0.5)
		if global_position.x >= limite_izquierdo - 0.5:
			if current_state != State.WALKING:
				_change_state(State.WALKING)
			velocity.x = -velocidad_caminar
			return


# ═══════════════════════════════════════════════════════════════════════════════
# PUNTO DE SPAWN (marker invisible en la mano; sin proyectil en CARGA_ATAQUE)
# ═══════════════════════════════════════════════════════════════════════════════


func _crear_punto_spawn() -> void:
	spawn_marker = Node3D.new()
	spawn_marker.name = "SpawnProyectil"

	var skeleton := find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton:
		var bone_idx := _buscar_hueso_mano(skeleton)
		if bone_idx != -1:
			bone_attachment_spawn = BoneAttachment3D.new()
			bone_attachment_spawn.name = "AttachmentSpawn"
			bone_attachment_spawn.bone_name = skeleton.get_bone_name(bone_idx)
			skeleton.add_child(bone_attachment_spawn)
			bone_attachment_spawn.add_child(spawn_marker)
			spawn_marker.position = SPAWN_OFFSET_LOCAL
			_crear_omni_light_ataque()
			return

	# Fallback: raíz del enemigo
	add_child(spawn_marker)
	spawn_marker.position = Vector3(0.0, 0.3, 0.3)
	_crear_omni_light_ataque()


func _buscar_luz_ataque() -> OmniLight3D:
	if is_instance_valid(omni_light_ataque):
		return omni_light_ataque
	var luz := find_child("LUZ_Ataque", true, false) as OmniLight3D
	if luz:
		omni_light_ataque = luz
		return omni_light_ataque
	luz = find_child("OmniLight3D", true, false) as OmniLight3D
	if luz:
		omni_light_ataque = luz
		return omni_light_ataque
	return null


func _crear_omni_light_ataque() -> void:
	if not _buscar_luz_ataque():
		omni_light_ataque = OmniLight3D.new()
		omni_light_ataque.name = "LUZ_Ataque"
		omni_light_ataque.light_color = COLOR_ANTICIPACION
		omni_light_ataque.light_energy = 0.0
		omni_light_ataque.omni_range = 3.5
		omni_light_ataque.visible = false
		if is_instance_valid(spawn_marker):
			spawn_marker.add_child(omni_light_ataque)
		else:
			add_child(omni_light_ataque)


func _encender_omni_light(intensidad: float = 3.0) -> void:
	var luz := _buscar_luz_ataque()
	if luz:
		luz.light_color = COLOR_ANTICIPACION
		luz.light_energy = intensidad
		luz.visible = true


func _apagar_omni_light() -> void:
	var luz := _buscar_luz_ataque()
	if luz:
		luz.light_energy = 0.0
		luz.visible = false


func _buscar_hueso_mano(skeleton: Skeleton3D) -> int:
	# Rig de la Gárgola usa nombres Blender (hand.r/hand.l)
	for nombre in ["hand.r", "hand.l", "Hand_R", "Hand_L", "mixamorig_RightHand", "mixamorig_LeftHand"]:
		var idx := skeleton.find_bone(nombre)
		if idx != -1:
			return idx
	# Fallback: hueso upper spine (entre las manos)
	for nombre in ["spine_02.x", "spine_01.x", "neck.x", "Spine2", "mixamorig_Spine2"]:
		var idx := skeleton.find_bone(nombre)
		if idx != -1:
			return idx
	return -1


func _obtener_posicion_spawn() -> Vector3:
	if is_instance_valid(spawn_marker):
		return spawn_marker.global_position
	return global_position + Vector3(0.0, 0.3, 0.0)


# ═══════════════════════════════════════════════════════════════════════════════
# RAGDOLL (trapo al morir)
# ═══════════════════════════════════════════════════════════════════════════════


## Override: vincula el nacimiento de las partículas de muerte directamente al hueso de la cadera (hips),
## siguiendo la simulación física (ragdoll) si está activa y eliminando desplazamientos horizontales.
func _get_hips_global_position() -> Vector3:
	if skeleton and is_instance_valid(skeleton):
		var nombres_cadera: Array[String] = [
			"hips",
			"Hips",
			"hip",
			"Hip",
			"cadera",
			"Cadera",
			"pelvis",
			"Pelvis",
			"root_ref.x",
			"spine_01_ref.x",
			"root",
			"Root"
		]

		var cadera_idx: int = -1
		var nombre_encontrado: String = ""

		if ragdoll_hueso_raiz != "":
			cadera_idx = skeleton.find_bone(ragdoll_hueso_raiz)
			if cadera_idx != -1:
				nombre_encontrado = ragdoll_hueso_raiz

		if cadera_idx == -1:
			for nombre in nombres_cadera:
				var idx = skeleton.find_bone(nombre)
				if idx != -1:
					cadera_idx = idx
					nombre_encontrado = nombre
					break

		# Si hay un PhysicalBone3D asociado al hueso de la cadera durante el ragdoll, usar su posición global
		if nombre_encontrado != "":
			for pbone in huesos_fisicos_creados:
				if is_instance_valid(pbone) and pbone.bone_name == nombre_encontrado:
					return pbone.global_position

		if cadera_idx != -1:
			var bone_pose := skeleton.get_bone_global_pose(cadera_idx)
			return skeleton.global_transform * bone_pose.origin

	return global_position


# ═══════════════════════════════════════════════════════════════════════════════
# DISPARO (2 proyectiles rectos con dispersión) — solo en fase ATAQUE
# ═══════════════════════════════════════════════════════════════════════════════


func _disparar_proyectiles() -> void:
	if not player_ref:
		player_ref = get_tree().get_first_node_in_group("player")
		if not player_ref:
			return
	if player_ref.get("is_dead"):
		return
	if not gargola_projectile_scene:
		return

	var spawn_pos: Vector3 = _obtener_posicion_spawn()
	var target_pos := player_ref.global_position + Vector3(0, 0.5, 0)
	var direccion_base := (target_pos - spawn_pos).normalized()

	var power := (velocidad_proyectil - 10.0) / 20.0
	var dispersion_radianes: float = randf_range(dispersion_min_radianes, dispersion_max_radianes)
	
	# Calcular un desvío aleatorio dentro del rango de dispersión
	var offset_angulo := randf_range(-dispersion_radianes, dispersion_radianes)
	var direccion_rotada := _rotar_direccion_xy(direccion_base, offset_angulo)
	
	var proyectil := PROJECTILE_POOL_REF.acquire(gargola_projectile_scene) as GargolaProjectile
	if proyectil:
		proyectil.scale = PROJECTILE_SCALE
		proyectil.initialize(direccion_rotada, power)
		proyectil.speed = velocidad_proyectil
		PROJECTILE_POOL_REF.activate(proyectil, get_tree().root, spawn_pos)


func _rotar_direccion_xy(dir: Vector3, angulo: float) -> Vector3:
	var cos_a := cos(angulo)
	var sin_a := sin(angulo)
	return Vector3(
		dir.x * cos_a - dir.y * sin_a,
		dir.x * sin_a + dir.y * cos_a,
		0.0
	).normalized()


## Instancia el VFX de anticipación de fuego en el punto de disparo reducido un 70% (escala 0.3) y color personalizado
func _spawn_anticipation_vfx() -> void:
	if not vfx_anticipacion_fire_scene:
		return
	var vfx := vfx_anticipacion_fire_scene.instantiate() as Node3D
	if not vfx:
		return

	# Reducción de un 70% (escala a 0.3)
	vfx.scale = Vector3(0.3, 0.3, 0.3)

	if is_instance_valid(spawn_marker):
		spawn_marker.add_child(vfx)
		vfx.position = Vector3.ZERO
	else:
		add_child(vfx)
		vfx.position = Vector3(0.0, 0.3, 0.3)

	# Encender la LUZ_Ataque con intensidad 3.0 al atacar
	_encender_omni_light(3.0)

	# Aplicar el color Color(1.491, 0.277, 0.55) a las partículas y materiales del VFX
	for child in vfx.find_children("*", "GPUParticles3D", true, false):
		if child is GPUParticles3D:
			var particles := child as GPUParticles3D
			if particles.process_material is ParticleProcessMaterial:
				var pmat := (particles.process_material as ParticleProcessMaterial).duplicate()
				pmat.color = COLOR_ANTICIPACION
				particles.process_material = pmat

			if particles.material_override:
				var mat := particles.material_override.duplicate()
				if mat is StandardMaterial3D:
					(mat as StandardMaterial3D).albedo_color = COLOR_ANTICIPACION
					(mat as StandardMaterial3D).emission = COLOR_ANTICIPACION
				elif mat is ShaderMaterial:
					(mat as ShaderMaterial).set_shader_parameter("color", COLOR_ANTICIPACION)
					(mat as ShaderMaterial).set_shader_parameter("Color", COLOR_ANTICIPACION)
				particles.material_override = mat

			particles.restart()
			particles.emitting = true

	# Auto-eliminar el VFX tras 0.8 segundos (duración de la anticipación al final de la carga)
	get_tree().create_timer(0.8).timeout.connect(func():
		if is_instance_valid(vfx):
			vfx.queue_free()
		_apagar_omni_light()
	)
