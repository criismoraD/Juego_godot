extends "res://addons/gut/test.gd"

## Tests unitarios para el diálogo de la arquera superior al aparecer la primera goblin rosada en pantalla en oleada 3.
## Sigue la estructura AAA (Arrange, Act, Assert) y las normas de AGENTS.md.

const CLAVE_DIALOGO: String = "DIALOGO_ARQUERA_ARRIBA_GOBLIN_LEGENDARIA"
const NIVEL01_SCRIPT = preload("res://Levels/NIVEL01/NIVEL01.gd")

class MockArcher extends Node:
	var ultimo_dialogo: String = ""
	var ultima_duracion: float = 0.0

	func decir(clave: String, duracion: float = -1.0) -> void:
		ultimo_dialogo = clave
		ultima_duracion = duracion
		if GameUI.es_dialogo_defensora_unico(clave):
			GameUI.marcar_dialogo_defensora_dicho(clave)


class MockGoblinRosa extends Node3D:
	signal aparicion_en_pantalla(goblin: Node)
	var en_pantalla: bool = false

	func esta_en_pantalla(_margen: float = 60.0) -> bool:
		return en_pantalla

	func aparecer_en_pantalla() -> void:
		en_pantalla = true
		aparicion_en_pantalla.emit(self)


func before_each():
	GameUI.limpiar_dialogos_defensoras()


func after_each():
	GameUI.limpiar_dialogos_defensoras()


func test_dialogo_goblin_legendaria_traduccion():
	# Arrange & Act
	var traduccion: String = tr(CLAVE_DIALOGO)

	# Assert
	assert_ne(traduccion, CLAVE_DIALOGO, "La clave de diálogo debe estar registrada en el sistema de traducción")
	assert_true(
		traduccion == "¿ACASO ES LA GOBLIN LEGENDARIA?" or traduccion == "COULD IT BE THE LEGENDARY GOBLIN?",
		"La traducción debe devolver el texto en español o inglés según el locale"
	)


func test_clave_en_dialogos_defensoras_unicos():
	# Arrange & Act & Assert
	assert_true(
		GameUI.es_dialogo_defensora_unico(CLAVE_DIALOGO),
		"La clave debe estar registrada como diálogo único de defensora"
	)
	assert_has(
		GameUI.DIALOGOS_DEFENSORAS_UNICOS,
		CLAVE_DIALOGO,
		"DIALOGOS_DEFENSORAS_UNICOS debe contener la clave del diálogo legendario"
	)


func test_spawn_fuera_de_pantalla_no_dispara_dialogo():
	# Arrange: Spawnea fuera de pantalla (en_pantalla = false)
	var nivel = NIVEL01_SCRIPT.new()
	autofree(nivel)
	nivel.oleada_combate_actual = 3

	var archer = MockArcher.new()
	archer.name = "AllyArcher"
	nivel.add_child(archer)

	var rosa = MockGoblinRosa.new()
	rosa.name = "ArqueraRosa"
	rosa.en_pantalla = false
	nivel.add_child(rosa)

	# Act: Solo spawnea, aún no entra en pantalla
	nivel._on_goblin_spawneado_nivel(rosa)

	# Assert
	assert_false(nivel._dialogo_arriba_goblin_legendaria_mostrado, "No debe mostrarse mientras siga fuera de pantalla")
	assert_eq(archer.ultimo_dialogo, "", "La arquera no debe hablar si no ha aparecido en pantalla")
	assert_false(GameUI.dialogo_defensora_ya_dicho(CLAVE_DIALOGO), "GameUI no debe marcarlo como dicho")


func test_aparicion_en_pantalla_dispara_dialogo_oleada_3():
	# Arrange
	var nivel = NIVEL01_SCRIPT.new()
	autofree(nivel)
	nivel.oleada_combate_actual = 3

	var archer = MockArcher.new()
	archer.name = "AllyArcher"
	nivel.add_child(archer)

	var rosa = MockGoblinRosa.new()
	rosa.name = "ArqueraRosa"
	rosa.en_pantalla = false
	nivel.add_child(rosa)

	nivel._on_goblin_spawneado_nivel(rosa)
	assert_false(nivel._dialogo_arriba_goblin_legendaria_mostrado, "Aún no debe dispararse")

	# Act: Aparece en pantalla
	rosa.aparecer_en_pantalla()

	# Assert
	assert_true(nivel._dialogo_arriba_goblin_legendaria_mostrado, "Debe mostrarse al aparecer en pantalla")
	assert_eq(archer.ultimo_dialogo, CLAVE_DIALOGO, "La arquera superior debe decir la clave del diálogo legendario")
	assert_eq(archer.ultima_duracion, 7.0, "La duración del diálogo debe ser de 7.0 segundos")
	assert_true(GameUI.dialogo_defensora_ya_dicho(CLAVE_DIALOGO), "GameUI debe registrar el diálogo como ya dicho")


func test_monitoreo_process_detecta_entrada_pantalla():
	# Arrange
	var nivel = NIVEL01_SCRIPT.new()
	autofree(nivel)
	nivel.oleada_combate_actual = 3

	var archer = MockArcher.new()
	archer.name = "AllyArcher"
	nivel.add_child(archer)

	var rosa = MockGoblinRosa.new()
	rosa.name = "ArqueraRosa"
	rosa.en_pantalla = false
	nivel.add_child(rosa)

	nivel._on_goblin_spawneado_nivel(rosa)
	assert_eq(nivel._goblin_rosa_pendiente_pantalla, rosa, "Debe quedar como pendiente de monitoreo")

	# Act: Cambia de posición entrando a pantalla y el proceso monitorea
	rosa.en_pantalla = true
	nivel._monitorear_goblin_rosa_pantalla()

	# Assert
	assert_true(nivel._dialogo_arriba_goblin_legendaria_mostrado, "El monitoreo en proceso debe activar el diálogo")
	assert_eq(archer.ultimo_dialogo, CLAVE_DIALOGO)
	assert_null(nivel._goblin_rosa_pendiente_pantalla, "El pendiente debe limpiarse tras el disparo")


func test_no_disparo_en_otras_oleadas_aunque_aparezca_en_pantalla():
	# Arrange
	var nivel = NIVEL01_SCRIPT.new()
	autofree(nivel)
	nivel.oleada_combate_actual = 2  # Oleada 2 en lugar de 3

	var archer = MockArcher.new()
	archer.name = "AllyArcher"
	nivel.add_child(archer)

	var rosa = MockGoblinRosa.new()
	rosa.name = "ArqueraRosa"
	rosa.en_pantalla = false
	nivel.add_child(rosa)

	nivel._on_goblin_spawneado_nivel(rosa)

	# Act
	rosa.aparecer_en_pantalla()

	# Assert
	assert_false(nivel._dialogo_arriba_goblin_legendaria_mostrado, "No debe mostrarse en oleadas distintas a la 3")
	assert_eq(archer.ultimo_dialogo, "", "La arquera no debe decir nada en oleada != 3")
	assert_false(GameUI.dialogo_defensora_ya_dicho(CLAVE_DIALOGO), "No debe registrarse como dicho si la oleada no es 3")


func test_no_duplicacion_segunda_goblin_rosada():
	# Arrange
	var nivel = NIVEL01_SCRIPT.new()
	autofree(nivel)
	nivel.oleada_combate_actual = 3

	var archer = MockArcher.new()
	archer.name = "AllyArcher"
	nivel.add_child(archer)

	var rosa1 = MockGoblinRosa.new()
	rosa1.name = "ArqueraRosa1"
	nivel.add_child(rosa1)

	var rosa2 = MockGoblinRosa.new()
	rosa2.name = "ArqueraRosa2"
	nivel.add_child(rosa2)

	# Act: Primera goblin entra en pantalla
	nivel._on_goblin_spawneado_nivel(rosa1)
	rosa1.aparecer_en_pantalla()
	assert_true(nivel._dialogo_arriba_goblin_legendaria_mostrado, "Debe mostrarse en la primera goblin")
	assert_eq(archer.ultimo_dialogo, CLAVE_DIALOGO)

	archer.ultimo_dialogo = ""

	# Act: Segunda goblin entra en pantalla
	nivel._on_goblin_spawneado_nivel(rosa2)
	rosa2.aparecer_en_pantalla()

	# Assert
	assert_eq(archer.ultimo_dialogo, "", "No debe volver a reproducirse en goblins rosadas posteriores")
	assert_true(nivel._dialogo_arriba_goblin_legendaria_mostrado, "Debe mantenerse en true")


func test_memoria_sesion_torre_evita_repeticion():
	# Arrange: simular que ya se dijo antes de entrar/salir de la torre
	GameUI.marcar_dialogo_defensora_dicho(CLAVE_DIALOGO)

	var nivel = NIVEL01_SCRIPT.new()
	autofree(nivel)
	nivel.oleada_combate_actual = 3
	nivel._dialogo_arriba_goblin_legendaria_mostrado = false  # nivel recién cargado

	var archer = MockArcher.new()
	archer.name = "AllyArcher"
	nivel.add_child(archer)

	var rosa = MockGoblinRosa.new()
	rosa.name = "ArqueraRosa"
	nivel.add_child(rosa)

	# Act
	nivel._on_goblin_spawneado_nivel(rosa)
	rosa.aparecer_en_pantalla()

	# Assert
	assert_eq(archer.ultimo_dialogo, "", "No debe reproducirse si GameUI ya lo tiene registrado en sesión")


func test_nodo_fuera_de_pantalla_por_coordenada_x():
	# Arrange
	var nivel = NIVEL01_SCRIPT.new()
	autofree(nivel)

	var nodo_spawn = Node3D.new()
	nodo_spawn.position = Vector3(4.746, 0.6, 0.0)
	nivel.add_child(nodo_spawn)

	# Assert: En coordenada del spawner (X=4.746) debe ser false
	assert_false(nivel._esta_nodo_en_pantalla(nodo_spawn), "En X=4.746 debe considerarse fuera de pantalla")

	# Assert: En X=4.30 sigue fuera de pantalla
	nodo_spawn.position = Vector3(4.3, 0.6, 0.0)
	assert_false(nivel._esta_nodo_en_pantalla(nodo_spawn), "En X=4.30 debe considerarse fuera de pantalla")

	# Assert: En origen (0,0,0) sin posicionar debe ser false
	nodo_spawn.position = Vector3.ZERO
	assert_false(nivel._esta_nodo_en_pantalla(nodo_spawn), "En Vector3.ZERO debe considerarse fuera de pantalla")
