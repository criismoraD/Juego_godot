class_name BalaCanonProjectile
extends "res://System/Core/EnemyProjectileBase.gd"

## Bala de cañón de la pistola pirata: vuela en línea recta, sin gravedad.
## Hereda la base enemiga (daño a jugadora/aliadas, clavado en superficies y
## escudos, pool). Visual: sprite redondo de Bala cañon.png siempre de frente.

const VELOCIDAD_BASE: float = 14.0  ## Rápida y tensa, como disparo de pistola

@export_category("Bala Cañon")
@export var velocidad: float = VELOCIDAD_BASE  ## Velocidad en línea recta (m/s)

var _sprite: Sprite3D = null


func _init() -> void:
	color_proyectil = Color(0.2, 0.2, 0.22)
	offscreen_margin_x = 400.0
	offscreen_margin_top = 2000.0
	offscreen_margin_bottom = 300.0


func _ready() -> void:
	_sprite = find_child("BalaSprite", true, false) as Sprite3D
	super._ready()


func initialize(shoot_direction: Vector3, potencia: float = 1.0) -> void:
	_inicializar_direccion(shoot_direction)
	velocidad = VELOCIDAD_BASE * maxf(0.5, potencia)


func _actualizar_movimiento(delta: float) -> void:
	_aplicar_movimiento_recto(delta, velocidad)


func _preparar_visuales() -> void:
	pass  ## El sprite del .tscn ya trae su textura


func _aplicar_visuales_cacheados() -> void:
	if is_instance_valid(_sprite):
		_sprite.visible = true


func _restaurar_visuales_desde_pool() -> void:
	if is_instance_valid(_sprite):
		_sprite.visible = true
