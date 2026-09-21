extends "res://addons/gut/test.gd"

## Tests unitarios para el volumen del sonido de movimiento del globo aerostático.

const GLOBO_SCENE := preload("res://Entities/Enemigo_GloboAerostatico/GloboAerostatico.tscn")
const GloboScript = preload("res://Entities/Enemigo_GloboAerostatico/GloboAerostatico.gd")

var _root_test: Node3D = null


func before_each() -> void:
	_root_test = Node3D.new()
	_root_test.name = "RootTestGloboSonido"
	get_tree().root.add_child(_root_test)
	get_tree().current_scene = _root_test


func after_each() -> void:
	if is_instance_valid(_root_test):
		_root_test.free()
	for n in get_tree().root.get_children():
		if n is GloboAerostatico:
			n.free()


func test_volumen_movimiento_globo_esta_disminuido() -> void:
	# Arrange & Act
	var globo := GloboScript.new()
	_root_test.add_child(globo)

	# Assert: El volumen debe ser menor o igual a 0.0 dB (antes era +9.0 dB)
	assert_lte(globo.volumen_movimiento_db, 0.0, "El volumen de movimiento debe ser sutil (<= 0.0 dB)")
	assert_eq(globo.volumen_movimiento_db, -3.0, "El volumen por defecto debe ser -3.0 dB")


func test_sfx_movimiento_instanciado_con_volumen_reducido() -> void:
	# Arrange
	var globo: GloboAerostatico = GLOBO_SCENE.instantiate() as GloboAerostatico
	_root_test.add_child(globo)

	# Act
	var sfx: AudioStreamPlayer = globo.find_child("SfxMovimiento", true, false) as AudioStreamPlayer

	# Assert
	assert_not_null(sfx, "El nodo SfxMovimiento debe existir como hijo del globo")
	assert_eq(sfx.volume_db, globo.volumen_movimiento_db, "El AudioStreamPlayer debe inicializarse con volumen_movimiento_db")
	assert_lte(sfx.volume_db, 0.0, "El volumen activo en el reproductor de audio debe ser atenuado (<= 0.0 dB)")


func test_modificar_volumen_movimiento_actualiza_reproductor() -> void:
	# Arrange
	var globo: GloboAerostatico = GLOBO_SCENE.instantiate() as GloboAerostatico
	_root_test.add_child(globo)
	var sfx: AudioStreamPlayer = globo.find_child("SfxMovimiento", true, false) as AudioStreamPlayer

	# Act: Modificar volumen vía export/setter
	globo.volumen_movimiento_db = -8.0

	# Assert
	assert_eq(sfx.volume_db, -8.0, "El setter debe actualizar de inmediato el volume_db del AudioStreamPlayer")
