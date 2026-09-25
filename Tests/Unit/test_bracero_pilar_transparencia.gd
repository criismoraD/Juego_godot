extends GutTest
## Tests unitarios para el sistema de transparencia dinámica de BraceroPilar.
## Cubre: activación, detección por grupo, fade de alpha, aislamiento por instancia.

const BRACERO_SCRIPT: Script = preload("res://Levels/Rio_En_Canoa_Con_Parallax/BraceroPilar.gd")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Crea un BraceroPilar básico sin GLB (no instancia la escena completa
## para evitar dependencias del modelo 3D en entorno headless).
func _crear_bracero(activo: bool = false) -> BraceroPilar:
	var b: BraceroPilar = BraceroPilar.new()
	b.transparencia_activa = activo
	add_child_autofree(b)
	return b


## Crea un Node3D de prueba y lo añade a un grupo determinado.
func _crear_nodo_en_grupo(grupo: StringName, pos_x: float = 0.0) -> Node3D:
	var n: Node3D = Node3D.new()
	n.position.x = pos_x
	add_child_autofree(n)
	n.add_to_group(grupo)
	return n


# ---------------------------------------------------------------------------
# Tests — Estado inicial
# ---------------------------------------------------------------------------

func test_transparencia_inactiva_por_defecto() -> void:
	# Arrange & Act
	var bracero: BraceroPilar = _crear_bracero(false)
	# Assert
	assert_false(bracero.transparencia_activa,
		"transparencia_activa debe ser false por defecto")
	assert_false(bracero.is_processing(),
		"El proceso debe estar desactivado cuando transparencia_activa=false")


func test_transparencia_activa_activa_proceso() -> void:
	# Arrange & Act
	var bracero: BraceroPilar = _crear_bracero(true)
	# Assert
	assert_true(bracero.transparencia_activa,
		"transparencia_activa debe reflejar el valor asignado")
	assert_true(bracero.is_processing(),
		"El proceso debe estar activo cuando transparencia_activa=true")


func test_alpha_inicial_es_opaco() -> void:
	# Arrange & Act
	var bracero: BraceroPilar = _crear_bracero(true)
	# Assert — antes de cualquier frame, el alpha objetivo es 1.0
	assert_almost_eq(bracero._alpha_actual, 1.0, 0.001,
		"El alpha inicial debe ser 1.0 (opaco)")
	assert_almost_eq(bracero._alpha_objetivo, 1.0, 0.001,
		"El alpha objetivo inicial debe ser 1.0")


# ---------------------------------------------------------------------------
# Tests — Detección de personajes
# ---------------------------------------------------------------------------

func test_calcula_alpha_transparente_con_player_en_rango() -> void:
	# Arrange
	var bracero: BraceroPilar = _crear_bracero(true)
	bracero.global_position.x = 100.0
	bracero.radio_deteccion_x = 4.0
	bracero.alpha_transparente = 0.25
	var jugador: Node3D = _crear_nodo_en_grupo(&"player", 102.0)  # a 2 u. en X

	# Act
	var resultado: float = bracero._calcular_alpha_objetivo()

	# Assert
	assert_almost_eq(resultado, 0.25, 0.001,
		"Debe devolver alpha_transparente cuando 'player' está en rango X")

	jugador.queue_free()


func test_calcula_alpha_opaco_con_player_fuera_de_rango() -> void:
	# Arrange
	var bracero: BraceroPilar = _crear_bracero(true)
	bracero.global_position.x = 100.0
	bracero.radio_deteccion_x = 4.0
	var jugador: Node3D = _crear_nodo_en_grupo(&"player", 110.0)  # a 10 u. en X

	# Act
	var resultado: float = bracero._calcular_alpha_objetivo()

	# Assert
	assert_almost_eq(resultado, 1.0, 0.001,
		"Debe devolver 1.0 cuando 'player' está fuera del radio X")

	jugador.queue_free()


func test_detecta_grupo_allies() -> void:
	# Arrange
	var bracero: BraceroPilar = _crear_bracero(true)
	bracero.global_position.x = 50.0
	bracero.radio_deteccion_x = 3.0
	bracero.alpha_transparente = 0.3
	var aliado: Node3D = _crear_nodo_en_grupo(&"allies", 52.0)

	# Act
	var resultado: float = bracero._calcular_alpha_objetivo()

	# Assert
	assert_almost_eq(resultado, 0.3, 0.001,
		"Debe detectar nodos en el grupo 'allies'")

	aliado.queue_free()


func test_detecta_grupo_enemies() -> void:
	# Arrange
	var bracero: BraceroPilar = _crear_bracero(true)
	bracero.global_position.x = 160.0
	bracero.radio_deteccion_x = 5.0
	bracero.alpha_transparente = 0.2
	var enemigo: Node3D = _crear_nodo_en_grupo(&"enemies", 163.0)

	# Act
	var resultado: float = bracero._calcular_alpha_objetivo()

	# Assert
	assert_almost_eq(resultado, 0.2, 0.001,
		"Debe detectar nodos en el grupo 'enemies'")

	enemigo.queue_free()


func test_sin_personajes_cerca_retorna_opaco() -> void:
	# Arrange
	var bracero: BraceroPilar = _crear_bracero(true)
	bracero.global_position.x = 200.0
	bracero.radio_deteccion_x = 3.0
	# No añadimos ningún nodo cercano

	# Act
	var resultado: float = bracero._calcular_alpha_objetivo()

	# Assert
	assert_almost_eq(resultado, 1.0, 0.001,
		"Debe devolver 1.0 cuando no hay personajes en el rango")


func test_deteccion_en_borde_exacto_del_radio() -> void:
	# Arrange — nodo exactamente en el límite del radio
	var bracero: BraceroPilar = _crear_bracero(true)
	bracero.global_position.x = 0.0
	bracero.radio_deteccion_x = 4.0
	bracero.alpha_transparente = 0.25
	var jugador: Node3D = _crear_nodo_en_grupo(&"player", 4.0)  # exactamente en el límite

	# Act
	var resultado: float = bracero._calcular_alpha_objetivo()

	# Assert
	assert_almost_eq(resultado, 0.25, 0.001,
		"Un nodo en el límite exacto del radio debe activar la transparencia (<=)")

	jugador.queue_free()


func test_nodo_no_node3d_en_grupo_no_causa_error() -> void:
	# Arrange — añadir un Node (no Node3D) al grupo "player"
	var nodo_plano: Node = Node.new()
	add_child_autofree(nodo_plano)
	nodo_plano.add_to_group(&"player")
	var bracero: BraceroPilar = _crear_bracero(true)
	bracero.global_position.x = 0.0

	# Act — no debe lanzar error
	var resultado: float = bracero._calcular_alpha_objetivo()

	# Assert
	assert_almost_eq(resultado, 1.0, 0.001,
		"Nodos que no son Node3D en el grupo deben ignorarse sin errores")

	nodo_plano.queue_free()


# ---------------------------------------------------------------------------
# Tests — Aislamiento entre instancias
# ---------------------------------------------------------------------------

func test_dos_braceros_tienen_materiales_independientes() -> void:
	# Arrange
	var b1: BraceroPilar = _crear_bracero(true)
	var b2: BraceroPilar = _crear_bracero(false)

	# Solo b1 tiene transparencia activa; b2 no debe ser afectado
	assert_true(b1.transparencia_activa, "b1 debe tener transparencia activa")
	assert_false(b2.transparencia_activa, "b2 NO debe tener transparencia activa")
	assert_false(b2.is_processing(), "b2 no debe procesar frames de transparencia")


# ---------------------------------------------------------------------------
# Tests — Fade por tiempo (simulando delta)
# ---------------------------------------------------------------------------

func test_alpha_actual_converge_hacia_objetivo() -> void:
	# Arrange
	var bracero: BraceroPilar = _crear_bracero(true)
	bracero._alpha_actual = 1.0
	bracero._alpha_objetivo = 0.25
	bracero.velocidad_fade = 5.0

	# Act — simular 1 segundo de delta
	bracero._alpha_actual = move_toward(bracero._alpha_actual, bracero._alpha_objetivo, bracero.velocidad_fade * 1.0)

	# Assert
	assert_almost_eq(bracero._alpha_actual, 0.25, 0.001,
		"Tras 1s de fade a velocidad 5, debe alcanzar el objetivo de 0.25")


func test_alpha_actual_converge_de_vuelta_a_opaco() -> void:
	# Arrange
	var bracero: BraceroPilar = _crear_bracero(true)
	bracero._alpha_actual = 0.25
	bracero._alpha_objetivo = 1.0
	bracero.velocidad_fade = 10.0

	# Act — simular 1 segundo
	bracero._alpha_actual = move_toward(bracero._alpha_actual, bracero._alpha_objetivo, bracero.velocidad_fade * 1.0)

	# Assert
	assert_almost_eq(bracero._alpha_actual, 1.0, 0.001,
		"Tras 1s de fade a velocidad 10, debe volver a ser totalmente opaco")
