extends GutTest

## Test unitario para verificar la iluminación continua y uniforme del agua en Nivel Pueblo.
## Comprueba la presencia de LuzAguaPueblo, sus parámetros ópticos (capa 1, energía, rango)
## y que acompaña fielmente a la cámara frente a lo largo de todo el recorrido del pueblo,
## eliminando apagones y saltos de luz al desplazarse la protagonista.

const ESCENA_NIVEL_PUEBLO_PATH: String = "res://Levels/Nivel_Pueblo/NivelPueblo.tscn"

var _nivel: Node3D = null


func before_each() -> void:
	var packed := load(ESCENA_NIVEL_PUEBLO_PATH) as PackedScene
	assert_not_null(packed, "La escena NivelPueblo.tscn debe cargarse correctamente")
	_nivel = packed.instantiate() as Node3D
	add_child_autofree(_nivel)


func test_luz_agua_pueblo_existe_y_propiedades_basicas() -> void:
	# Arrange & Act
	var luz: OmniLight3D = _nivel.find_child("LuzAguaPueblo", true, false) as OmniLight3D

	# Assert
	assert_not_null(luz, "Debe existir el nodo LuzAguaPueblo en la escena")
	assert_eq(luz.layers, 1, "LuzAguaPueblo debe estar asignada exclusivamente a la capa visual 1 (agua frontal)")
	assert_gt(luz.light_energy, 2.0, "LuzAguaPueblo debe tener energía suficiente para el agua (> 2.0)")
	assert_gte(luz.omni_range, 14.0, "LuzAguaPueblo debe tener un radio amplio (>= 14.0) para cubrir el marco visual")


func test_luz_agua_pueblo_inicia_sincronizada_con_camara() -> void:
	# Arrange
	var camara: Camera3D = _nivel.find_child("CamaraFrente", true, false) as Camera3D
	var luz: OmniLight3D = _nivel.find_child("LuzAguaPueblo", true, false) as OmniLight3D
	assert_not_null(camara, "Debe existir CamaraFrente en Nivel Pueblo")
	assert_not_null(luz, "Debe existir LuzAguaPueblo")

	# Act: Simular un frame de _process
	_nivel._process(0.016)

	# Assert: La luz debe coincidir exactamente en X con la cámara frontal
	assert_almost_eq(luz.global_position.x, camara.global_position.x, 0.05,
		"LuzAguaPueblo debe iniciar en la misma coordenada X que CamaraFrente")


func test_luz_agua_pueblo_sigue_a_camara_al_moverse_la_protagonista() -> void:
	# Arrange
	var prota: Node3D = _nivel.find_child("Player", true, false) as Node3D
	var camara: Camera3D = _nivel.find_child("CamaraFrente", true, false) as Camera3D
	var luz: OmniLight3D = _nivel.find_child("LuzAguaPueblo", true, false) as OmniLight3D
	assert_not_null(prota, "Debe existir Player")
	assert_not_null(camara, "Debe existir CamaraFrente")
	assert_not_null(luz, "Debe existir LuzAguaPueblo")

	# Iniciar cámara
	_nivel._process(0.016)

	# Act: Mover la protagonista hacia la derecha (hacia el centro del pueblo, X = -3.0)
	prota.global_position.x = -3.0
	for i in range(30):
		_nivel._process(0.016)

	# Assert: La luz debe acompañar a la cámara sin rezagarse ni apagarse
	assert_almost_eq(luz.global_position.x, camara.global_position.x, 0.05,
		"LuzAguaPueblo debe seguir continuamente la posición X de CamaraFrente al moverse a X = -3.0")
	assert_true(luz.visible, "LuzAguaPueblo debe permanecer visible")

	# Act: Mover la protagonista más a la derecha (hacia el mercado, X = 4.0)
	prota.global_position.x = 4.0
	for i in range(30):
		_nivel._process(0.016)

	# Assert
	assert_almost_eq(luz.global_position.x, camara.global_position.x, 0.05,
		"LuzAguaPueblo debe seguir continuamente la posición X de CamaraFrente al moverse a X = 4.0")


func test_luz_agua_pueblo_reseta_limites_extremos() -> void:
	# Arrange
	var prota: Node3D = _nivel.find_child("Player", true, false) as Node3D
	var camara: Camera3D = _nivel.find_child("CamaraFrente", true, false) as Camera3D
	var luz: OmniLight3D = _nivel.find_child("LuzAguaPueblo", true, false) as OmniLight3D

	# Act: Desplazar más allá del límite izquierdo (-15.0)
	prota.global_position.x = -15.0
	for i in range(30):
		_nivel._process(0.016)

	# Assert: Tanto cámara como luz se acotan al límite mínimo (-9.5)
	assert_almost_eq(camara.global_position.x, -9.5, 0.1, "CamaraFrente respeta el límite izquierdo")
	assert_almost_eq(luz.global_position.x, camara.global_position.x, 0.05, "LuzAguaPueblo respeta el límite izquierdo junto a la cámara")

	# Act: Desplazar más allá del límite derecho (+15.0)
	prota.global_position.x = 15.0
	for i in range(60):
		_nivel._process(0.016)

	# Assert: Tanto cámara como luz se acotan al límite derecho (+8.5)
	assert_almost_eq(camara.global_position.x, 8.5, 0.1, "CamaraFrente respeta el límite derecho")
	assert_almost_eq(luz.global_position.x, camara.global_position.x, 0.05, "LuzAguaPueblo respeta el límite derecho junto a la cámara")
