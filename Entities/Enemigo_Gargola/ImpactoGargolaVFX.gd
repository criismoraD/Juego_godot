class_name ImpactoGargolaVFX
extends AnimatedSprite3D

## Efecto de impacto y muerte animado para la Gárgola usando ExplosionSpritesheet.png (3 columnas x 4 filas).

func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shaded = false
	render_priority = 2
	no_depth_test = false
	scale = Vector3(0.38, 0.38, 0.38)  ## Reducido 3 veces para ajustarse al tamaño del cuerpo de la Gárgola

	var tex: Texture2D = preload("res://TEST_/ExplosionSpritesheet.png")
	if tex:
		var sf := SpriteFrames.new()
		sf.add_animation(&"default")
		sf.set_animation_loop(&"default", false)
		sf.set_animation_speed(&"default", 18.0)

		# 3 columnas x 4 filas
		var frame_w: float = tex.get_width() / 3.0
		var frame_h: float = tex.get_height() / 4.0

		for row in range(4):
			for col in range(3):
				var idx: int = row * 3 + col
				if idx >= 10:  # 10 frames de explosión en el spritesheet
					break
				var atlas := AtlasTexture.new()
				atlas.atlas = tex
				atlas.region = Rect2(col * frame_w, row * frame_h, frame_w, frame_h)
				sf.add_frame(&"default", atlas)

		sprite_frames = sf
		play(&"default")

	animation_finished.connect(queue_free)


static func spawn(tree_node: Node, pos: Vector3) -> void:
	var vfx := ImpactoGargolaVFX.new()
	var target_parent := tree_node.get_tree().current_scene
	if not target_parent:
		target_parent = tree_node.get_tree().root
	target_parent.add_child(vfx)
	vfx.global_position = pos
