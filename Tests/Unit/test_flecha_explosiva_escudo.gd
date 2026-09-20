extends "res://addons/gut/test.gd"

## Tests unitarios para la interacción de Flecha Explosiva contra el escudo
## de GuardianaMoradita (daño 3 base + 5 bono estructuras = 8 total; 10 HP).

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
	var explosiones := get_tree().root.find_children("*", "ExplosionFlechaExplosiva", true, false)
	for e in explosiones:
		(e as Node).queue_free()


func test_explosiva_en_escudo_explota_con_bono_y_sobrevive() -> void:
	# Arrange
	_guardiana = EscenaGuardiana.instantiate()
	get_tree().root.add_child(_guardiana)
	_flecha = EscenaExplosiva.instantiate()
	get_tree().root.add_child(_flecha)
	assert_true(_flecha.es_explosiva, "La flecha es explosiva")
	var vida_antes: int = _guardiana.health
	assert_eq(vida_antes, 10, "La vida inicial del escudo debe ser 10")

	# Act: impacto al escudo/cuerpo
	_flecha._on_body_entered(_guardiana)

	# Assert: explota y aplica base + bono (3 + 5 = 8), no daño doble
	var explosiones := get_tree().root.find_children("*", "ExplosionFlechaExplosiva", true, false)
	assert_false(explosiones.is_empty(), "Explota al impactar el escudo")
	assert_eq(vida_antes - _guardiana.health, 8, "Bono 3+5 contra estructuras = 8 de daño")
	assert_eq(_guardiana.health, 2, "La guardiana sobrevive el primer tiro con 2 HP")
	assert_true(_guardiana.health > 0, "No debe morir de un solo impacto no crítico")


func test_dos_flechas_explosivas_destruyen_guardiana() -> void:
	# Arrange
	_guardiana = EscenaGuardiana.instantiate()
	get_tree().root.add_child(_guardiana)

	# Act 1: Primer tiro
	var flecha1: Node = EscenaExplosiva.instantiate()
	get_tree().root.add_child(flecha1)
	flecha1._on_body_entered(_guardiana)
	flecha1.queue_free()

	assert_eq(_guardiana.health, 2, "Tras el 1er tiro debe quedar con 2 HP")

	# Act 2: Segundo tiro
	var flecha2: Node = EscenaExplosiva.instantiate()
	get_tree().root.add_child(flecha2)
	flecha2._on_body_entered(_guardiana)
	flecha2.queue_free()

	# Assert: Cae destruida con el segundo tiro
	assert_eq(_guardiana.health, 0, "Tras el 2do tiro la vida debe ser 0")


func test_flecha_explosiva_en_ataque_es_impacto_critico_letal() -> void:
	# Arrange: Poner a la guardiana en estado de ataque (momento vulnerable)
	_guardiana = EscenaGuardiana.instantiate()
	get_tree().root.add_child(_guardiana)
	_guardiana.current_state = _guardiana.State.ATTACKING

	# Act: Flecha explosiva impacta mientras está atacando
	_flecha = EscenaExplosiva.instantiate()
	get_tree().root.add_child(_flecha)
	_flecha._on_body_entered(_guardiana)

	# Assert: 8 de daño + 5 de crítico = 13 (supera los 10 HP y muere de 1 solo tiro)
	assert_eq(_guardiana.health, 0, "Impacto crítico en momento vulnerable debe eliminarla de 1 tiro")
