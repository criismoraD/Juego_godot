class_name EscudoPesadoArea
extends Area3D

var es_escudo_enemigo: bool = true
var es_pilar_enemigo: bool = true


func _ready() -> void:
	add_to_group("escudos")


func recibir_golpe(amount: float = 1.0) -> void:
	var p = owner
	if not p:
		p = get_parent()
	if p and p.has_method("recibir_golpe_escudo"):
		p.recibir_golpe_escudo(amount)
	elif p and p.has_method("recibir_golpe"):
		p.recibir_golpe(amount)
	elif p and p.has_method("take_damage"):
		p.take_damage(amount, true)
