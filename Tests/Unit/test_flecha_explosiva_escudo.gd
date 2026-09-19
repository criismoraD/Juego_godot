extends "res://addons/gut/test.gd"

## La explosiva contra el escudo de GuardianaMoradita debe explotar
## y aplicar el bono contra estructuras (3 + 6).

var EscenaGuardiana = load("res://Entities/Enemigo_Goblina_Escudo_Pesado/GuardianaMoradita.tscn")
var EscenaExplosiva = load("res://Entities/Flecha_Explosiva/FlechaExplosiva.tscn")

var _guardiana = null
var _flecha = null


func after_each():
	if is_instance_valid(_flecha):
		_flecha.free()
	if is_instance_valid(_guardiana):
		_guardiana.free()
	_flecha = null
	_guardiana = null


func test_explosiva_en_escudo_explota_con_bono() -> void:
	# Arrange
	_guardiana = EscenaGuardiana.instantiate()
	get_tree().root.add_child(_guardiana)
	_flecha = EscenaExplosiva.instantiate()
	get_tree().root.add_child(_flecha)
	assert_true(_flecha.es_explosiva, "La flecha es explosiva")
	var vida_antes: int = _guardiana.health

	# Act: impacto directo al cuerpo con escudo
	_flecha._on_body_entered(_guardiana)

	# Assert: explota y aplica base + bono
	var explosiones := get_tree().root.find_children("*", "ExplosionFlechaExplosiva", true, false)
	assert_false(explosiones.is_empty(), "Explota al impactar el escudo")
	assert_eq(vida_antes - _guardiana.health, 9, "Bono 3+6 contra estructuras")
	for e in explosiones:
		(e as Node).queue_free()
