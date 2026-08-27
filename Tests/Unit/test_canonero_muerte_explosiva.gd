extends res://addons/gut/test.gd

var CanoneroScene: PackedScene = preload(res://Entities/Enemigo_Canonero/Canonero.tscn)
var canonero: Canonero = null


func before_each():
	canonero = CanoneroScene.instantiate() as Canonero
	add_child_autofree(canonero)


func after_each():
	if is_instance_valid(canonero) and not canonero.is_queued_for_deletion():
		canonero.queue_free()


func test_canonero_initial_state() -> void:
	assert_not_null(canonero, El nodo canonero debe instanciarse correctamente)
	assert_false(canonero.murio_por_explosion, murio_por_explosion debe ser falso por defecto)


func test_canonero_muerte_por_explosion_oculta_modelo_y_genera_vfx() -> void:
	# Arrange
	canonero.murio_por_explosion = true

	# Act
	canonero._on_state_dying()
	await get_tree().process_frame
	await get_tree().process_frame

	# Assert
	var model = canonero.get_node_or_null(Model)
	if is_instance_valid(model):
		assert_false(model.visible, El modelo intacto debe ocultarse al morir por explosion)

	var sprites := get_tree().root.find_children(*, Sprite3D, true, false)
	var canonero_sprite: Sprite3D = null
	for s in sprites:
		var sp := s as Sprite3D
		if sp and sp.vframes == 12:
			canonero_sprite = sp
			break

	assert_not_null(canonero_sprite, Debe instanciarse el Sprite3D con los 12 frames de muerte explosiva)

	var mancha := get_tree().root.find_child(ManchaSangreSuelo, true, false) as MeshInstance3D
	assert_not_null(mancha, Debe generar la mancha de sangre en el suelo tras la explosion)
	if mancha:
		mancha.queue_free()
	if canonero_sprite:
		canonero_sprite.queue_free()
