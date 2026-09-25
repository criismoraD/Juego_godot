class_name HumoDisparoPirata
extends AnimatedSprite3D

## Humo del pistoletazo pirata (Smoke VFX 2): tira de 13 cuadros de 64x64
## con fondo transparente. Misma técnica que Fuego2D (AnimatedSprite3D con
## billboard, sin sombreado y SIN material_override para que el alfa
## funcione y no salga ningún cuadrado). Un solo disparo: se reproduce
## una vez y se libera solo.

const TEXTURA_HUMO: Texture2D = preload("res://VFX/Textures/Smoke VFX 2.png")
const ANIM_HUMO: StringName = &"humo"
const COLUMNAS: int = 13
const FILAS: int = 1
const CUADRO: Vector2i = Vector2i(64, 64)
const TOTAL_CUADROS: int = 13

@export var velocidad_fps: float = 24.0 ## ~0.54s por disparo (13 cuadros)
@export var escala_humo: float = 0.7 ## Penacho visible junto al fogonazo
@export var pixel_base: float = 0.0055 ## Igual que Fuego2D para mismo tamaño mundo


func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shaded = false
	render_priority = 2
	offset = Vector2.ZERO
	pixel_size = pixel_base
	scale = Vector3(escala_humo, escala_humo, escala_humo)
	material_override = null
	_construir_frames()
	animation_finished.connect(_on_fin_animacion)
	play(ANIM_HUMO)


func _construir_frames() -> void:
	var sf := SpriteFrames.new()
	sf.add_animation(ANIM_HUMO)
	sf.set_animation_loop(ANIM_HUMO, false)
	sf.set_animation_speed(ANIM_HUMO, velocidad_fps)
	for i in range(TOTAL_CUADROS):
		var col: int = i % COLUMNAS
		var row: int = i / COLUMNAS
		var atlas := AtlasTexture.new()
		atlas.atlas = TEXTURA_HUMO
		atlas.region = Rect2(col * CUADRO.x, row * CUADRO.y, CUADRO.x, CUADRO.y)
		sf.add_frame(ANIM_HUMO, atlas)
	sprite_frames = sf


func _on_fin_animacion() -> void:
	if is_instance_valid(self) and not is_queued_for_deletion():
		queue_free()
