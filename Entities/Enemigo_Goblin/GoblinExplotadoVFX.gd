class_name GoblinExplotadoVFX
extends Node3D

## Controlador del efecto de desmembramiento/explosión del Goblin de Ballesta.
## Spawnea las 4 partes 3D dispersas con impulsos físicos y reproduce el sprite animado Sangre_explosion.png (14 frames verticales) y el SFX Sangre_splash.mp3.

const SANGRE_TEX := preload("res://Entities/Enemigo_Goblin/Muerte_Explotado/Sangre_explosion.png")
const SFX_SPLASH := preload("res://Entities/Enemigo_Goblin/Muerte_Explotado/Sangre_splash.mp3")

const BRAZO_1_SCENE := preload("res://Entities/Enemigo_Goblin/Muerte_Explotado/Brazo_01_GOBLING_MUERTE.glb")
const BRAZO_2_SCENE := preload("res://Entities/Enemigo_Goblin/Muerte_Explotado/Brazo_02_GOBLING_MUERTE.glb")
const CABEZA_SCENE := preload("res://Entities/Enemigo_Goblin/Muerte_Explotado/Cabeza_GOBLING_MUERTE.glb")
const PIERNAS_SCENE := preload("res://Entities/Enemigo_Goblin/Muerte_Explotado/Piernas_GOBLING_MUERTE.glb")


func _ready() -> void:
	# 1. Reproducir sonido de splash de sangre
	_reproducir_audio()

	# 2. Reproducir animación 2D de sangre en espacio 3D (14 cuadros verticales)
	_spawn_sangre_animada()

	# 3. Mancha de sangre en el suelo (se desvanece de forma idéntica a las quemaduras)
	VFXFactory.spawn_ground_blood_splatter(self, global_position)

	# 4. Spawnear partes físicas 3D dispersas
	_spawn_partes_cuerpo()

	# 4. Auto-limpieza tras 4.5 segundos
	get_tree().create_timer(4.5).timeout.connect(func():
		if is_instance_valid(self):
			queue_free()
	)


func _reproducir_audio() -> void:
	if SFX_SPLASH:
		var player := AudioStreamPlayer3D.new()
		player.stream = SFX_SPLASH
		player.volume_db = 2.0
		player.bus = "Master"
		add_child(player)
		player.play()
		player.finished.connect(player.queue_free)


func _spawn_sangre_animada() -> void:
	if not SANGRE_TEX:
		return

	var sprite := AnimatedSprite3D.new()
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.render_priority = 2
	sprite.no_depth_test = false
	sprite.scale = Vector3(2.2, 2.2, 2.2)  # Duplicado de 1.1 para mayor impacto visual

	var sf := SpriteFrames.new()
	if not sf.has_animation(&"default"):
		sf.add_animation(&"default")
	sf.set_animation_loop(&"default", false)
	sf.set_animation_speed(&"default", 20.0)

	# 1 columna x 14 filas verticales
	var frame_w: float = float(SANGRE_TEX.get_width())
	var frame_h: float = float(SANGRE_TEX.get_height()) / 14.0

	for i in range(14):
		var atlas := AtlasTexture.new()
		atlas.atlas = SANGRE_TEX
		atlas.region = Rect2(0.0, float(i) * frame_h, frame_w, frame_h)
		sf.add_frame(&"default", atlas)

	sprite.sprite_frames = sf
	add_child(sprite)
	sprite.position = Vector3(0.0, 0.4, 0.0)
	sprite.play(&"default")
	sprite.animation_finished.connect(sprite.queue_free)


func _spawn_partes_cuerpo() -> void:
	var partes: Array[Dictionary] = [
		{"scene": CABEZA_SCENE, "vel": Vector3(randf_range(-1.2, 1.2), randf_range(4.5, 6.5), randf_range(-0.4, 0.4)), "offset": Vector3(0.0, 0.8, 0.0)},
		{"scene": BRAZO_1_SCENE, "vel": Vector3(randf_range(-3.5, -1.5), randf_range(3.5, 5.5), randf_range(-0.4, 0.4)), "offset": Vector3(-0.2, 0.5, 0.0)},
		{"scene": BRAZO_2_SCENE, "vel": Vector3(randf_range(1.5, 3.5), randf_range(3.5, 5.5), randf_range(-0.4, 0.4)), "offset": Vector3(0.2, 0.5, 0.0)},
		{"scene": PIERNAS_SCENE, "vel": Vector3(randf_range(-1.0, 1.0), randf_range(2.5, 4.0), randf_range(-0.4, 0.4)), "offset": Vector3(0.0, 0.2, 0.0)},
	]

	for info in partes:
		var scene: PackedScene = info["scene"]
		if not scene:
			continue

		var rb := RigidBody3D.new()
		rb.collision_layer = 0
		rb.collision_mask = 1  # Solo colisiona con el suelo

		var col := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.12
		col.shape = sphere
		rb.add_child(col)

		var mesh_instance := scene.instantiate() as Node3D
		if mesh_instance:
			rb.add_child(mesh_instance)

		add_child(rb)
		rb.position = info["offset"]
		rb.linear_velocity = info["vel"]
		rb.angular_velocity = Vector3(
			randf_range(-10.0, 10.0),
			randf_range(-10.0, 10.0),
			randf_range(-10.0, 10.0)
		)

		# Desvanecimiento progresivo después de 2.5s
		var tween := rb.create_tween()
		tween.tween_interval(2.5)
		tween.tween_property(rb, "scale", Vector3.ZERO, 1.0) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.finished.connect(func():
			if is_instance_valid(rb):
				rb.queue_free()
		)


static func spawn(tree_node: Node, pos: Vector3) -> void:
	var vfx := GoblinExplotadoVFX.new()
	var target_parent := tree_node.get_tree().current_scene
	if not target_parent:
		target_parent = tree_node.get_tree().root
	target_parent.add_child(vfx)
	vfx.global_position = pos
