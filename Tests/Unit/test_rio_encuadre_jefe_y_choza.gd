extends "res://addons/gut/test.gd"

## Tests unitarios del encuadre del combate contra el jefe submarino y del bloque verde
## de posicionamiento en el nivel del río ('Rio en canoa con paralax').
##
## Valida que:
## 1. El bloque verde PosicionJefeSubmarino exista en la escena y sincronice la posición del jefe.
## 2. La ChozaMarinaGrande mantenga su posición original solicitada por el usuario (~141.25).
## 3. En Fase 1, la plataforma y el cañón del submarino sean siempre visibles en pantalla.
## 4. La cola del submarino quede proyectada fuera del borde derecho (> 1.0 norm).
## 5. La proa de la canoa y la proa del submarino mantengan su distancia física sin solaparse.

const ESCENA_RIO: PackedScene = preload("res://Levels/Rio en canoa con paralax.tscn")
const ANCHO_RESOLUCION_PX: float = 1920.0
const MARGEN_MAX_DERECHO_CANON: float = 0.95
const MARGEN_MAX_DERECHO_PLATAFORMA: float = 0.90
const LIMITE_BORDE_DERECHO: float = 1.0
const POS_X_ORIGINAL_CHOZA: float = 141.25


func test_bloque_verde_posicion_jefe_presente_y_sincroniza() -> void:
	# Arrange
	var scene: RioEnCanoaConParallax = ESCENA_RIO.instantiate() as RioEnCanoaConParallax
	add_child_autofree(scene)

	var bloque: PosicionJefeSubmarino = scene.find_child("PosicionJefeSubmarino", true, false) as PosicionJefeSubmarino
	var jefe: JefeSubmarinoRio = scene.find_child("JefeSubmarino", true, false) as JefeSubmarinoRio
	var choza: Node3D = scene.find_child("ChozaMarinaGrande", true, false) as Node3D

	# Assert de existencia e inicialización
	assert_not_null(bloque, "La escena debe contener el bloque PosicionJefeSubmarino")
	assert_not_null(jefe, "La escena debe contener JefeSubmarino")
	assert_not_null(choza, "La escena debe contener ChozaMarinaGrande")
	assert_true(bloque.is_in_group("posicion_jefe_submarino"), "El bloque debe estar en el grupo posicion_jefe_submarino")

	# Choza revertida a su posición original
	assert_almost_eq(choza.global_position.x, POS_X_ORIGINAL_CHOZA, 0.1, "La ChozaMarinaGrande debe estar en su posición original")

	# Sincronización inicial
	assert_almost_eq(jefe.global_position.x, bloque.global_position.x, 0.05, "El jefe debe sincronizar su X con el bloque")

	# Act: Mover el bloque verde a una nueva coordenada de prueba
	var nueva_x_prueba: float = 145.0
	bloque.global_position.x = nueva_x_prueba
	bloque.aplicar_posicion_al_jefe(jefe)

	# Assert: El jefe debe adoptar la nueva posición X del bloque
	assert_almost_eq(jefe.global_position.x, nueva_x_prueba, 0.05, "Mover el bloque verde debe reposicionar al jefe submarino")


func test_visibilidad_submarino_fase_uno_canon_y_plataforma() -> void:
	# Arrange
	var scene: RioEnCanoaConParallax = ESCENA_RIO.instantiate() as RioEnCanoaConParallax
	add_child_autofree(scene)

	var canoa: CanoaProtagonistaRio = scene.canoa_protagonista
	var cam: Camera3D = scene.camara_principal
	var jefe: JefeSubmarinoRio = scene.find_child("JefeSubmarino", true, false) as JefeSubmarinoRio

	# Act: Posicionar la canoa a la distancia de combate del jefe e igualar la cámara
	var canoa_x: float = jefe.global_position.x - RioEnCanoaConParallax.DISTANCIA_COMBATE_JEFE
	canoa.global_position.x = canoa_x
	cam.global_position.x = canoa_x + scene._offset_camara_x

	var screen_canon: Vector2 = cam.unproject_position(jefe.global_position + Vector3(2.35, 1.85, 0.0))
	var screen_plat: Vector2 = cam.unproject_position(jefe.global_position + Vector3(1.61, 1.75, 0.0))
	var screen_proa_sub: Vector2 = cam.unproject_position(jefe.global_position + Vector3(-3.8, 0.0, 0.0))
	var screen_cola_sub: Vector2 = cam.unproject_position(jefe.global_position + Vector3(4.5, 0.0, 0.0))
	var screen_proa_canoa: Vector2 = cam.unproject_position(canoa.global_position + Vector3(1.25, 0.0, 0.0))

	var norm_x_canon: float = screen_canon.x / ANCHO_RESOLUCION_PX
	var norm_x_plat: float = screen_plat.x / ANCHO_RESOLUCION_PX
	var norm_x_cola: float = screen_cola_sub.x / ANCHO_RESOLUCION_PX

	# Assert
	assert_lte(norm_x_canon, MARGEN_MAX_DERECHO_CANON, "El cañón del submarino debe ser visible en pantalla")
	assert_lte(norm_x_plat, MARGEN_MAX_DERECHO_PLATAFORMA, "La plataforma del submarino debe ser visible en pantalla")
	assert_gt(norm_x_cola, LIMITE_BORDE_DERECHO, "La cola del submarino queda fuera del borde derecho de la pantalla")
	assert_lt(screen_proa_canoa.x, screen_proa_sub.x, "La canoa y la proa del submarino mantienen separación sin solaparse")
