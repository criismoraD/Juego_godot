class_name FlechaElectricaVFX
extends Node3D
## VFX y Área de daño de impacto del ataque eléctrico de Lonko.

@export var dano: float = 1.0

@onready var area_danio: Area3D = find_child("AreaDanio", true, false) as Area3D
var _cuerpos_danados: Dictionary = {}


func _ready() -> void:
	if area_danio:
		area_danio.body_entered.connect(_on_body_entered)
		call_deferred("_verificar_superposicion")


func _verificar_superposicion() -> void:
	if not area_danio:
		return
	for body in area_danio.get_overlapping_bodies():
		_aplicar_dano(body)


func _on_body_entered(body: Node) -> void:
	_aplicar_dano(body)


func _aplicar_dano(body: Node) -> void:
	if not is_instance_valid(body) or _cuerpos_danados.has(body):
		return

	if body.is_in_group("allies") or body.is_in_group("player"):
		_cuerpos_danados[body] = true
		# Posición del impacto para el efecto de sangre no letal
		if "last_hit_position" in body:
			body.last_hit_position = global_position
		if "last_hit_direction" in body:
			body.last_hit_direction = Vector3.DOWN
		if body.has_method("take_damage"):
			body.take_damage(dano)
		elif body.has_method("recibir_dano"):
			body.recibir_dano(dano)
