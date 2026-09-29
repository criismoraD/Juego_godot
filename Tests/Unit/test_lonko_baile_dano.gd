extends GutTest

## Tests para el baile de invocación del pilar de Lonko:
## - Sin sacudida de cámara al invocar (el shake total volvía el juego injugable).
## - Lonko recibe daño mientras baila, pero los impactos no interrumpen su animación.
## Estructura AAA (Arrange, Act, Assert) siguiendo las directrices de AGENTS.md.

const LONKO_SCENE: PackedScene = preload("res://Entities/Enemigo_Lonko/Lonko.tscn")

var scene_root: Node3D


func before_each() -> void:
	scene_root = Node3D.new()
	add_child(scene_root)


func after_each() -> void:
	if is_instance_valid(scene_root):
		scene_root.queue_free()
	await get_tree().process_frame


func _lonko_en_baile() -> Lonko:
	# Arrange: Lonko a mitad del baile de subida (pilar invocado, aún no desplegado)
	var lonko := LONKO_SCENE.instantiate() as Lonko
	scene_root.add_child(lonko)
	await get_tree().process_frame
	lonko._pilar_invocado = true
	lonko._pilar_desplegado = false
	lonko._is_invulnerable = false
	lonko.health = 6
	return lonko


func test_baile_no_es_invulnerable() -> void:
	# Arrange
	var lonko := await _lonko_en_baile()

	# Assert
	assert_false(lonko._is_invulnerable, "Durante el baile Lonko no debe ser invulnerable")
	assert_true(lonko._en_baile_pilar(), "El helper debe detectar el baile de subida")

	lonko.queue_free()
	await get_tree().process_frame


func test_baile_recibe_dano_sin_interrumpir() -> void:
	# Arrange
	var lonko := await _lonko_en_baile()
	var estado_previo: int = lonko.current_state

	# Act: impacto no letal durante el baile
	lonko.take_damage(1.0)

	# Assert: la vida baja pero no hay reacción de impacto ni cambio de estado
	assert_eq(lonko.health, 5, "El daño durante el baile debe restar vida")
	assert_false(lonko._is_taking_damage, "El tiro no debe marcar taking_damage durante el baile")
	assert_eq(lonko.current_state, estado_previo, "El tiro no debe cambiar el estado durante el baile")

	lonko.queue_free()
	await get_tree().process_frame


func test_baile_dano_letal_mata() -> void:
	# Arrange
	var lonko := await _lonko_en_baile()

	# Act: daño letal durante el baile
	lonko.take_damage(999.0)

	# Assert
	assert_eq(lonko.current_state, Lonko.State.DYING, "El daño letal durante el baile debe matar")

	lonko.queue_free()
	await get_tree().process_frame


func test_baile_no_rastrea_jugador() -> void:
	# Arrange
	var lonko := await _lonko_en_baile()
	lonko.current_state = Lonko.State.SHOOTING
	lonko.rastrear_jugador = true

	# Assert: no debe rastrear para no romper la orientación al fondo del baile
	assert_false(lonko._debe_rastrear_jugador(), "Durante el baile no debe rastrear al jugador")

	lonko.queue_free()
	await get_tree().process_frame


func test_invocacion_pilar_sin_shake_camara() -> void:
	# Arrange
	var lonko := LONKO_SCENE.instantiate() as Lonko
	scene_root.add_child(lonko)
	await get_tree().process_frame

	# Act: iniciar la secuencia del pilar (corre hasta el primer await)
	lonko._iniciar_secuencia_pilar()

	# Assert: no debe registrar cámaras para sacudir
	assert_true(lonko._shake_camaras.is_empty(), "Invocar el pilar no debe sacudir cámaras")
	assert_true(lonko._shake_posiciones_orig.is_empty(), "Sin shake no debe guardar posiciones de cámara")

	lonko.queue_free()
	await get_tree().process_frame
