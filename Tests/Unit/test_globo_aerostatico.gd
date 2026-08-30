extends "res://addons/gut/test.gd"

## Tests del Globo Aerostatico Goblin:
## - Vuelo por fases: avance lento, pausa de 18 s en el punto medio de la isla
##   enemiga y continuacion hasta el limite establecido para los enemigos.
## - La arquera dispara con GIRL_GOB_DISPARO mientras el globo avanza.
## - Misma fuerza y mismo proyectil que GoblinGirl.

var GloboScript = load("res://Entities/Enemigo_GloboAerostatico/GloboAerostatico.gd")
var BarreraLimiteScript = load("res://Entities/Ambiente_Barrera_Limite/BarreraLimite.gd")
var FlechaScript = load("res://Entities/Proyectil_Flecha_Goblin_Girl/GoblinGirlArrow.gd")


## Doble de prueba que cuenta los disparos sin instanciar proyectiles reales
## (evita depender del jugador, del pool de proyectiles y del AudioManager)
class GloboEspia extends "res://Entities/Enemigo_GloboAerostatico/GloboAerostatico.gd":
	var disparos: int = 0


	func _disparar_flecha() -> void:
		disparos += 1


func test_globo_aerostatico_initialization():
	# Arrange & Act
	var globo = GloboScript.new()
	add_child_autofree(globo)

	# Assert
	assert_not_null(globo, "GloboAerostatico debe instanciarse correctamente")
	assert_eq(globo.vida_maxima, 5, "Debe tener 5 puntos de vida maxima")
	assert_eq(globo.health, 5, "Debe iniciar con 5 puntos de vida")
	assert_false(globo.tiene_sangre, "No debe tener sangre")
	assert_gte(globo.altura_spawn_baja, 3.0, "La altura de spawn baja debe ser ~3.3")
	assert_gte(globo.altura_spawn_alta, 5.0, "La altura de spawn alta debe ser ~5.2")


func test_globo_aerostatico_damage_and_death():
	# Arrange
	var globo = GloboScript.new()
	add_child_autofree(globo)

	# Act: Aplicar 3 de dano (vida 5 -> 2)
	globo.take_damage(3)

	# Assert
	assert_eq(globo.health, 2, "La vida debe reducirse a 2")
	assert_eq(globo.current_state, globo.State.WALKING, "Debe seguir vivo en WALKING")

	# Act: Aplicar 2 de dano adicional (vida 2 -> 0)
	globo.take_damage(2)

	# Assert
	assert_eq(globo.health, 0, "La vida debe llegar a 0")
	assert_eq(globo.current_state, globo.State.DYING, "Debe transicionar a DYING al morir")


func test_configuracion_disparo_igual_a_goblingirl():
	# Arrange & Act
	var globo = GloboScript.new()
	add_child_autofree(globo)

	# Assert: misma fuerza que GoblinGirl (ver GoblinGirl.gd: 1.0 - 2.0)
	assert_eq(globo.potencia_disparo_min, 1.0, "La potencia minima debe ser la de GoblinGirl")
	assert_eq(globo.potencia_disparo_max, 2.0, "La potencia maxima debe ser la de GoblinGirl")
	# Assert: sin dispersion (GoblinGirl no aplica dispersión)
	assert_eq(globo.dispersion, 0.0, "No debe aplicar dispersion (igual que GoblinGirl)")
	# Assert: misma escala de flecha disparada que GoblinGirl (x1.10)
	assert_eq(globo.escala_flecha_disparo, Vector3(1.1, 1.1, 1.1), "La escala de flecha debe ser x1.10 como GoblinGirl")
	# Assert: pausa de 18 segundos en el medio de la isla enemiga
	assert_eq(globo.pausa_isla_segundos, 18.0, "La pausa en el medio de la isla debe durar 18 segundos")
	# Assert: mismo color de proyectil que la flecha de GoblinGirl
	assert_eq(GloboScript.COLOR_FLECHA, FlechaScript.GOBLIN_GIRL_ARROW_MAGENTA, "Debe usar el color magenta de GoblinGirl")
	# Assert: compensacion de arco identica a GoblinGirl
	assert_eq(GloboScript.ARC_COMPENSACION_DIST_MULT, 0.15, "Multiplicador de arco debe ser 0.15 como GoblinGirl")
	assert_eq(GloboScript.ARC_COMPENSACION_MIN, 0.1, "Arco minimo debe ser 0.1 como GoblinGirl")
	assert_eq(GloboScript.ARC_COMPENSACION_MAX, 0.5, "Arco maximo debe ser 0.5 como GoblinGirl")


func test_pausa_isla_en_punto_medio_del_recorrido():
	# Arrange
	var globo = GloboScript.new()
	add_child_autofree(globo)
	globo.global_position = Vector3(5.0, 4.3, 0.0)

	# Act
	globo._preparar_pausa_isla(-5.0)

	# Assert: el punto medio entre x=5 y limite x=-5 es x=0
	assert_eq(globo._x_pausa_isla, 0.0, "La pausa debe quedar en el punto medio del recorrido")
	assert_true(globo._pausa_isla_preparada, "Debe marcarse la pausa como preparada")

	# Boundary: recalcular con otro limite no debe cambiar el punto (solo se calcula una vez)
	globo._preparar_pausa_isla(-9.0)
	assert_eq(globo._x_pausa_isla, 0.0, "El punto medio debe calcularse una sola vez")


func test_pausa_isla_omitida_con_recorrido_degenerado():
	# Arrange
	var globo = GloboScript.new()
	add_child_autofree(globo)
	globo.global_position = Vector3(5.0, 4.3, 0.0)

	# Act: limite a la derecha del spawn (recorrido invalido)
	globo._preparar_pausa_isla(6.0)

	# Assert: sin pausa, el punto medio queda inalcanzable
	assert_eq(globo._x_pausa_isla, -INF, "Con recorrido degenerado no debe haber pausa")

	# Boundary: globo ya pasado el punto medio (posicion defensiva)
	globo.global_position.x = -6.0
	globo._pausa_isla_preparada = false
	globo._preparar_pausa_isla(-5.0)
	assert_eq(globo._x_pausa_isla, -INF, "Si ya esta pasado el punto medio no debe pausar")


## Integra un frame de vuelo manualmente (move_and_slide no corre en el test)
func _simular_frame_vuelo(globo, delta: float) -> void:
	globo._procesar_vuelo(delta)
	globo.global_position.x += globo.velocity.x * delta


func test_vuelo_avanza_pausa_en_medio_y_continua_hasta_el_limite():
	# Arrange
	var barrera = BarreraLimiteScript.new()
	barrera.tamano = Vector3(1.0, 5.0, 1.0)
	add_child_autofree(barrera)
	barrera.global_position = Vector3(-5.0, 0.0, 0.0)

	var globo = GloboScript.new()
	add_child_autofree(globo)
	globo.global_position = Vector3(5.0, 4.3, 0.0)
	var delta: float = 1.0 / 30.0

	# Act: primer frame de avance
	_simular_frame_vuelo(globo, delta)

	# Assert: avanza lentamente mientras esta en WALKING
	assert_eq(globo.current_state, globo.State.WALKING, "Debe seguir en WALKING mientras avanza")
	assert_eq(globo._fase_vuelo, globo.FaseVuelo.AVANZANDO, "Debe estar en fase AVANZANDO")
	assert_lt(globo.velocity.x, 0.0, "Debe avanzar hacia la izquierda")

	# Act: avanzar hasta el punto medio de la isla (x=0)
	var pasos: int = 0
	while globo._fase_vuelo != globo.FaseVuelo.PAUSA_ISLA and pasos < 600:
		_simular_frame_vuelo(globo, delta)
		pasos += 1

	# Assert: se detiene en el medio de la isla enemiga
	assert_eq(globo._fase_vuelo, globo.FaseVuelo.PAUSA_ISLA, "Debe pausar en el punto medio de la isla")
	assert_eq(globo.velocity.x, 0.0, "Debe estar detenido durante la pausa")
	assert_eq(globo.current_state, globo.State.WALKING, "La pausa no debe cambiar el estado")
	assert_true(globo.global_position.x <= 0.2, "La pausa debe quedar cerca del punto medio")

	# Act: esperar 1 s menos que la pausa configurada (boundary inferior)
	var segundos_pausa: int = int(globo.pausa_isla_segundos)
	for i in range(segundos_pausa - 1):
		globo._procesar_vuelo(1.0)

	# Assert: a 1 s de completar la pausa sigue en pausa
	assert_eq(globo._fase_vuelo, globo.FaseVuelo.PAUSA_ISLA, "A 1 s de completar la pausa debe seguir en pausa")

	# Act: completar el ultimo segundo de pausa
	globo._procesar_vuelo(1.0)

	# Assert: reanuda el avance
	assert_eq(globo._fase_vuelo, globo.FaseVuelo.AVANZANDO, "Al completar la pausa debe reanudar el avance")

	# Act: continuar hasta el limite establecido para los enemigos
	pasos = 0
	while globo.current_state != globo.State.SHOOTING and pasos < 600:
		_simular_frame_vuelo(globo, delta)
		pasos += 1

	# Assert: se detiene definitivamente en el limite
	assert_eq(globo.current_state, globo.State.SHOOTING, "Debe detenerse en el limite de la isla")
	assert_eq(globo._fase_vuelo, globo.FaseVuelo.DETENIDO, "Fase de vuelo DETENIDO en el limite")
	assert_eq(globo.velocity.x, 0.0, "Detenido en el limite")
	assert_gte(globo.global_position.x, -5.0, "No debe sobrepasar el limite de la isla")


func test_dispara_mientras_avanza():
	# Arrange: espia que cuenta disparos
	var globo = GloboEspia.new()
	add_child_autofree(globo)
	globo.current_state = globo.State.WALKING

	# Act: ciclo completo de combate mientras el globo AVANZA
	globo._fase_combate = globo.FaseCombate.IDLE
	globo._timer_combate = globo.intervalo_disparo_globo
	globo._procesar_combate(1.0 / 60.0)
	assert_eq(globo._fase_combate, globo.FaseCombate.TENSANDO, "Debe tensar el arco mientras avanza")

	globo._timer_combate = globo.tiempo_tensado_arco
	globo._procesar_combate(1.0 / 60.0)
	assert_eq(globo._fase_combate, globo.FaseCombate.DISPARANDO, "Debe pasar a DISPARANDO mientras avanza")

	globo._procesar_combate(1.0 / 60.0)

	# Assert
	assert_eq(globo.disparos, 1, "La arquera debe disparar mientras el globo avanza")

	# Boundary: no dispara dos veces en el mismo ciclo
	globo._procesar_combate(1.0 / 60.0)
	assert_eq(globo.disparos, 1, "No debe disparar dos veces en el mismo ciclo")

func test_sombra_ampliada_para_vehiculo():
	# Arrange: instanciar la ESCENA (los overrides del tscn solo aplican asi)
	var escena_globo = load("res://Entities/Enemigo_GloboAerostatico/GloboAerostatico.tscn")
	var globo = escena_globo.instantiate()
	add_child_autofree(globo)

	# Assert: sombra mas grande que la de un personaje (0.6 x 0.6 por defecto)
	assert_gt(globo.sombra_tamano.x, 0.6, "La sombra debe ser mas ancha que la de un personaje")
	assert_gt(globo.sombra_tamano.y, 0.6, "La sombra debe ser mas profunda que la de un personaje")
	# Assert: techo de desvanecimiento por encima de la altura maxima de vuelo
	# (5.2 m) para que la sombra nunca desaparezca bajo el vehiculo
	assert_gt(globo.sombra_altura_max, globo.altura_spawn_alta, "La sombra debe seguir visible a la altura maxima de vuelo")
	# Boundary: a la altura maxima de vuelo conserva mas de la mitad de su opacidad
	var factor_max: float = clampf(1.0 - (globo.altura_spawn_alta / globo.sombra_altura_max), 0.0, 1.0)
	assert_gt(factor_max, 0.5, "A la altura maxima la sombra conserva mas de la mitad de su opacidad")

## Doble de prueba que cuenta las explosiones sin instanciar VFX reales
class GloboEspiaExplosiones extends "res://Entities/Enemigo_GloboAerostatico/GloboAerostatico.gd":
	var explosiones_lanzadas: int = 0


	func _spawn_explosion(_indice: int) -> void:
		explosiones_lanzadas += 1


func test_config_explosion_cadena():
	# Arrange & Act
	var globo = GloboScript.new()
	add_child_autofree(globo)

	# Assert: 3 explosiones rapidas como el pilar de Lonko al destruirse
	assert_eq(globo.cantidad_explosiones, 3, "Deben ser 3 explosiones al morir")
	assert_eq(globo.intervalo_explosiones, 0.7, "La cadencia debe ser la del pilar de Lonko (0.7 s)")
	assert_eq(globo.escala_explosion, 0.75, "La escala debe ser la del pilar de Lonko (0.75)")


func test_cadena_3_explosiones_en_sucesion():
	# Arrange: espia que cuenta explosiones sin VFX
	var espia = GloboEspiaExplosiones.new()
	add_child_autofree(espia)

	# Act & Assert: la primera estalla de inmediato al morir
	espia._explotar_en_cadena()
	assert_eq(espia.explosiones_lanzadas, 1, "La primera explosion debe estallar al instante")

	# Segunda tras el intervalo (0.7 s)
	await get_tree().create_timer(0.85).timeout
	assert_eq(espia.explosiones_lanzadas, 2, "La segunda explosion debe estallar tras el intervalo")

	# Tercera tras otro intervalo
	await get_tree().create_timer(0.7).timeout
	assert_eq(espia.explosiones_lanzadas, 3, "La tercera explosion debe estallar tras el segundo intervalo")

	# Boundary: no existe una cuarta explosion
	await get_tree().create_timer(0.8).timeout
	assert_eq(espia.explosiones_lanzadas, 3, "No debe haber mas de 3 explosiones")


func test_explosion_individual_genera_vfx_y_rocas():
	# Arrange: escena completa del globo en arbol
	var escena_globo = load("res://Entities/Enemigo_GloboAerostatico/GloboAerostatico.tscn")
	var globo = escena_globo.instantiate()
	add_child_autofree(globo)
	await get_tree().process_frame

	# Act: una explosion individual de la cadena
	globo._spawn_explosion(0)
	await get_tree().process_frame

	# Assert: VFX del pilar + rafaga de rocas negras presentes en el arbol
	var ruta_vfx := "res://Entities/Enemigo_Lonko/Explocion_Pilar.tscn"
	var vfx: int = 0
	var rocas: int = 0
	for nodo in get_tree().root.find_children("*", "Node", true, false):
		if nodo.get("scene_file_path") == ruta_vfx:
			vfx += 1
		if nodo.name == "ParticulasRocasDestruccion":
			rocas += 1
	assert_gt(vfx, 0, "Debe instanciarse el VFX de explosion del pilar de Lonko")
	assert_gt(rocas, 0, "Debe instanciarse la rafaga de rocas negras")