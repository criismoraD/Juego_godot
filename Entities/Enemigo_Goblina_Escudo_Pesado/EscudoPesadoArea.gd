class_name EscudoPesadoArea
extends Area3D

var es_escudo_enemigo: bool = true
var es_pilar_enemigo: bool = true


func _ready() -> void:
	add_to_group("escudos")


func obtener_dueno_guardiana() -> Node:
	if owner and (owner.has_method("recibir_golpe_escudo") or owner.has_method("take_damage")):
		return owner
	var p: Node = get_parent()
	while p:
		if p.has_method("recibir_golpe_escudo") or p.has_method("take_damage"):
			return p
		p = p.get_parent()
	return null


func recibir_golpe(amount: float = 1.0) -> void:
	var p := obtener_dueno_guardiana()
	if not p:
		p = owner if owner else get_parent()
	if p and p.has_method("recibir_golpe_escudo"):
		p.recibir_golpe_escudo(amount)
	elif p and p.has_method("recibir_golpe"):
		p.recibir_golpe(amount)
	elif p and p.has_method("take_damage"):
		p.take_damage(amount, true)
