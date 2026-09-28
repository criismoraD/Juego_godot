extends "res://addons/gut/test.gd"

## Tests unitarios para la cámara de seguimiento estilo Mario Bros y parallax en Nivel Pueblo.
## Verifica que:
## 1. La cámara frontal inicia centrada en la protagonista.
## 2. La cámara avanza naturalmente junto a la protagonista sin dejar espacios desproporcionados.
## 3. El sprite 'FONDO estatico' permanece inmóvil respecto a la cámara de fondo (fondo 2D quieto en pantalla).
## 4. La cámara de fondo acompaña con un factor de parallax sutil (~15%).
## 5. La cámara frontal respeta los límites del pueblo pequeño (-9.5 a 8.5).

const SCENE_PUEBLO: PackedScene = preload("res://Levels/Nivel_Pueblo/NivelPueblo.tscn")

func test_camaras_y_fondo_estatico_existen_en_pueblo():
	# Arrange & Act
	var nivel: Node = SCENE_PUEBLO.instantiate()
	add_child_autofree(nivel)
	
	# Assert
	var cam_frente: Camera3D = nivel.find_child("CamaraFrente", true, false) as Camera3D
	var cam_fondo: Camera3D = nivel.find_child("CamaraFondoDOF", true, false) as Camera3D
	var fondo_estatico: Node3D = nivel.find_child("FONDO estatico", true, false) as Node3D
	
	assert_not_null(cam_frente, "Debe existir CamaraFrente")
	assert_not_null(cam_fondo, "Debe existir CamaraFondoDOF")
	assert_not_null(fondo_estatico, "Debe existir FONDO estatico")


func test_camara_inicia_centrada_en_la_protagonista():
	# Arrange
	var nivel: Node = SCENE_PUEBLO.instantiate()
	add_child_autofree(nivel)
	
	var cam_frente: Camera3D = nivel.find_child("CamaraFrente", true, false) as Camera3D
	var prota: Node3D = nivel.find_child("Player", true, false) as Node3D
	
	# Act — inicializar el encuadre
	nivel._process(0.016)
	
	# Assert — la cámara debe centrarse en la posición de la protagonista
	assert_almost_eq(cam_frente.global_position.x, prota.global_position.x, 0.5, "La camara debe iniciar centrada naturalmente en la protagonista")


func test_camara_avanza_naturalmente_con_el_personaje():
	# Arrange
	var nivel: Node = SCENE_PUEBLO.instantiate()
	add_child_autofree(nivel)
	
	var cam_frente: Camera3D = nivel.find_child("CamaraFrente", true, false) as Camera3D
	var prota: Node3D = nivel.find_child("Player", true, false) as Node3D
	nivel._process(0.016)
	
	# Act — el personaje avanza a x = 0.0
	prota.global_position.x = 0.0
	for i: int in range(60):
		nivel._process(0.016)
		
	# Assert — la cámara debe acompañar inmediatamente, manteniéndolo cerca del centro (estilo Mario Bros)
	var distancia_a_camara: float = absf(prota.global_position.x - cam_frente.global_position.x)
	assert_lt(distancia_a_camara, 0.5, "La camara debe seguir a la protagonista sin dejarla arrinconada en el borde")


func test_fondo_estatico_permanece_inmovil_respecto_a_camara_fondo():
	# Arrange
	var nivel: Node = SCENE_PUEBLO.instantiate()
	add_child_autofree(nivel)
	
	var cam_fondo: Camera3D = nivel.find_child("CamaraFondoDOF", true, false) as Camera3D
	var fondo_estatico: Node3D = nivel.find_child("FONDO estatico", true, false) as Node3D
	var prota: Node3D = nivel.find_child("Player", true, false) as Node3D
	
	nivel._process(0.016)
	var offset_inicial: float = fondo_estatico.global_position.x - cam_fondo.global_position.x
	
	# Act — desplazar a la protagonista y procesar varios frames
	prota.global_position.x = 3.0
	for i: int in range(60):
		nivel._process(0.016)
		
	# Assert — la distancia relativa entre FONDO estatico y CamaraFondoDOF debe ser idéntica
	var offset_actual: float = fondo_estatico.global_position.x - cam_fondo.global_position.x
	assert_almost_eq(offset_actual, offset_inicial, 0.001, "El fondo estatico debe permanecer perfectamente fijo con respecto a la camara de fondo")


func test_desplazamiento_parallax_sutil():
	# Arrange
	var nivel: Node = SCENE_PUEBLO.instantiate()
	add_child_autofree(nivel)
	
	var cam_frente: Camera3D = nivel.find_child("CamaraFrente", true, false) as Camera3D
	var cam_fondo: Camera3D = nivel.find_child("CamaraFondoDOF", true, false) as Camera3D
	var prota: Node3D = nivel.find_child("Player", true, false) as Node3D
	
	nivel._process(0.016)
	var x_inicial_frente: float = cam_frente.global_position.x
	var x_inicial_fondo: float = cam_fondo.global_position.x
	
	# Act — mover a la protagonista hacia la derecha y procesar frames
	prota.global_position.x = 2.0
	for i: int in range(60):
		nivel._process(0.016)
		
	var delta_frente: float = cam_frente.global_position.x - x_inicial_frente
	var delta_fondo: float = cam_fondo.global_position.x - x_inicial_fondo
	
	# Assert
	assert_gt(delta_frente, 1.0, "La camara de frente debe haberse desplazado siguiendo a la jugadora")
	assert_gt(delta_fondo, 0.1, "La camara de fondo debe haberse desplazado para dar parallax")
	assert_lt(delta_fondo, delta_frente, "La camara de fondo debe desplazarse mucho menos que el frente")
	
	var ratio: float = delta_fondo / delta_frente
	assert_almost_eq(ratio, 0.15, 0.02, "La proporcion de parallax debe coincidir con el factor sutil del 15%")


func test_limites_acotados_camara_pueblo_pequeno():
	# Arrange
	var nivel: Node = SCENE_PUEBLO.instantiate()
	add_child_autofree(nivel)
	
	var cam_frente: Camera3D = nivel.find_child("CamaraFrente", true, false) as Camera3D
	var prota: Node3D = nivel.find_child("Player", true, false) as Node3D
	
	nivel._process(0.016)
	
	# Act — mover a la protagonista muy lejos a la derecha (x = 50.0)
	prota.global_position.x = 50.0
	for i: int in range(120):
		nivel._process(0.016)
		
	# Assert — no debe exceder LIMITE_CAMARA_PUEBLO_MAX_X (8.5)
	assert_true(cam_frente.global_position.x <= 8.51, "La camara frontal no debe exceder el limite derecho del pueblo")
	
	# Act — mover a la protagonista muy lejos a la izquierda (x = -50.0)
	prota.global_position.x = -50.0
	for i: int in range(120):
		nivel._process(0.016)
		
	# Assert — no debe sobrepasar LIMITE_CAMARA_PUEBLO_MIN_X (-9.5)
	assert_true(cam_frente.global_position.x >= -9.51, "La camara frontal no debe exceder el limite izquierdo del pueblo")
