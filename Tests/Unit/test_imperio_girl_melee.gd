extends "res://addons/gut/test.gd"

## Tests unitarios de ImperioGirlMelee.
## Cubre: identidad/grupos, estadísticas, combate melee,
## sistema de daño, límite de vida=3 y muerte/disolución.

const ESCENA: PackedScene = preload(
		"res://Entities/Defensora_ImperioGirl_Melee/ImperioGirlMelee.tscn")


func _crear_melee() -> ImperioGirlMelee:
	var nodo: ImperioGirlMelee = ESCENA.instantiate() as ImperioGirlMelee
	add_child_autofree(nodo)
	nodo.global_position = Vector3.ZERO
	return nodo


# ─────────────────────────────────────────────────────────────────────────────
# IDENTIDAD Y GRUPOS
# ─────────────────────────────────────────────────────────────────────────────
func test_hereda_de_character_body_3d() -> void:
	# Arrange & Act
	var melee: ImperioGirlMelee = _crear_melee()

	# Assert
	assert_true(melee is CharacterBody3D,
			"ImperioGirlMelee debe heredar de CharacterBody3D")


func test_pertenece_a_grupo_allies_y_defensoras() -> void:
	# Arrange & Act
	var melee: ImperioGirlMelee = _crear_melee()

	# Assert
	assert_true(melee.is_in_group("allies"),
			"Debe estar en el grupo 'allies'")
	assert_true(melee.is_in_group("defensoras"),
			"Debe estar en el grupo 'defensoras'")


# ─────────────────────────────────────────────────────────────────────────────
# ESTADÍSTICAS
# ─────────────────────────────────────────────────────────────────────────────
func test_vida_maxima_igual_a_3() -> void:
	# Arrange & Act
	var melee: ImperioGirlMelee = _crear_melee()

	# Assert
	assert_eq(melee.vida_maxima, 3,
			"vida_maxima debe ser 3")
	assert_eq(melee.health, 3,
			"health inicial debe ser 3")


func test_constante_vida_maxima_default_es_3() -> void:
	# Arrange & Act & Assert
	assert_eq(ImperioGirlMelee.VIDA_MAXIMA_DEFAULT, 3,
			"VIDA_MAXIMA_DEFAULT debe ser 3")


func test_tiene_metodo_take_damage() -> void:
	# Arrange & Act
	var melee: ImperioGirlMelee = _crear_melee()

	# Assert
	assert_true(melee.has_method("take_damage"),
			"Debe exponer take_damage() para compatibilidad con proyectiles")


func test_tiene_metodo_recibir_golpe() -> void:
	# Arrange & Act
	var melee: ImperioGirlMelee = _crear_melee()

	# Assert
	assert_true(melee.has_method("recibir_golpe"),
			"Debe exponer recibir_golpe() como alias melee")


# ─────────────────────────────────────────────────────────────────────────────
# SISTEMA DE DAÑO – HAPPY PATH
# ─────────────────────────────────────────────────────────────────────────────
func test_daño_reduce_health() -> void:
	# Arrange
	var melee: ImperioGirlMelee = _crear_melee()
	var health_antes: int = melee.health

	# Act
	melee.take_damage(1.0)

	# Assert
	assert_eq(melee.health, health_antes - 1,
			"Un golpe de 1 debe reducir health en 1")


func test_recibir_golpe_reduce_health() -> void:
	# Arrange
	var melee: ImperioGirlMelee = _crear_melee()

	# Act
	melee.recibir_golpe(1.0)

	# Assert
	assert_eq(melee.health, 2,
			"recibir_golpe(1) debe dejar health en 2")


func test_tres_golpes_letales() -> void:
	# Arrange
	var melee: ImperioGirlMelee = _crear_melee()

	# Act
	melee.take_damage(1.0)
	melee.take_damage(1.0)
	melee.take_damage(1.0)

	# Assert: a los 3 golpes pasa a MURIENDO
	assert_eq(melee.estado, ImperioGirlMelee.Estado.MURIENDO,
			"Tres golpes de 1 deben llevar a estado MURIENDO (vida=3)")


func test_daño_letal_de_golpe_directo() -> void:
	# Arrange
	var melee: ImperioGirlMelee = _crear_melee()

	# Act
	melee.take_damage(99.0)

	# Assert
	assert_eq(melee.health, 0,
			"Daño muy alto debe llevar health a 0")
	assert_eq(melee.estado, ImperioGirlMelee.Estado.MURIENDO,
			"Daño letal debe cambiar estado a MURIENDO")


# ─────────────────────────────────────────────────────────────────────────────
# SISTEMA DE DAÑO – CASOS LÍMITE / INVÁLIDOS
# ─────────────────────────────────────────────────────────────────────────────
func test_daño_cero_no_reduce_health() -> void:
	# Arrange
	var melee: ImperioGirlMelee = _crear_melee()
	var health_antes: int = melee.health

	# Act
	melee.take_damage(0.0)

	# Assert
	assert_eq(melee.health, health_antes,
			"Daño 0 no debe modificar health")


func test_daño_negativo_no_reduce_health() -> void:
	# Arrange
	var melee: ImperioGirlMelee = _crear_melee()
	var health_antes: int = melee.health

	# Act
	melee.take_damage(-5.0)

	# Assert
	assert_eq(melee.health, health_antes,
			"Daño negativo no debe modificar health")


func test_daño_ignorado_si_ya_esta_muriendo() -> void:
	# Arrange
	var melee: ImperioGirlMelee = _crear_melee()
	melee.take_damage(99.0)  # llevar a MURIENDO
	var health_post_muerte: int = melee.health

	# Act: intentar dañar de nuevo
	melee.take_damage(1.0)

	# Assert: health no baja más de 0
	assert_eq(melee.health, health_post_muerte,
			"Daño adicional en estado MURIENDO debe ignorarse")


# ─────────────────────────────────────────────────────────────────────────────
# MODELO Y VISUAL
# ─────────────────────────────────────────────────────────────────────────────
func test_modelo_imperio_girl_presente() -> void:
	# Arrange & Act
	var melee: ImperioGirlMelee = _crear_melee()

	# Assert
	var modelo := melee.find_child("ImperioGirlModel", true, false) as Node3D
	assert_not_null(modelo,
			"El modelo ImperioGirlModel debe existir como hijo")


func test_textura_imperio_girl_aplicada() -> void:
	# Arrange & Act
	var melee: ImperioGirlMelee = _crear_melee()

	# Assert: ninguna malla queda sin material
	var modelo := melee.find_child("ImperioGirlModel", true, false)
	assert_not_null(modelo, "ImperioGirlModel debe existir")
	var mallas: Array = (modelo as Node).find_children(
			"*", "MeshInstance3D", true, false)
	assert_gt(mallas.size(), 0, "El modelo debe tener mallas")
	for m in mallas:
		var mi := m as MeshInstance3D
		assert_not_null(mi.material_override,
				"Cada malla del modelo debe tener material de Imperio Girl")


func test_esqueleto_presente() -> void:
	# Arrange & Act
	var melee: ImperioGirlMelee = _crear_melee()

	# Assert
	var skel := melee.find_child("Skeleton3D", true, false) as Skeleton3D
	assert_not_null(skel,
			"Debe haber Skeleton3D para enlazar la espada")


# ─────────────────────────────────────────────────────────────────────────────
# ESPADA IMPERIAL
# ─────────────────────────────────────────────────────────────────────────────
func test_espada_imperial_equipada() -> void:
	# Arrange & Act
	var melee: ImperioGirlMelee = _crear_melee()
	await get_tree().process_frame  # esperar _ready()

	# Assert
	var espada := melee.find_child("EspadaImperial", true, false) as Node3D
	assert_not_null(espada,
			"La espada imperial debe estar instanciada en la mano derecha")


func test_espada_tiene_material() -> void:
	# Arrange & Act
	var melee: ImperioGirlMelee = _crear_melee()
	await get_tree().process_frame

	# Assert
	var espada := melee.find_child("EspadaImperial", true, false)
	if not is_instance_valid(espada):
		pending("Espada no encontrada – revisar escena")
		return
	var mallas: Array = (espada as Node).find_children(
			"*", "MeshInstance3D", true, false)
	assert_gt(mallas.size(), 0, "La espada debe tener mallas")
	for m in mallas:
		var mi := m as MeshInstance3D
		assert_not_null(mi.material_override,
				"La espada debe tener el material EspadaImperial_Mat")


# ─────────────────────────────────────────────────────────────────────────────
# ESTADO INICIAL Y COMBATE
# ─────────────────────────────────────────────────────────────────────────────
func test_estado_inicial_es_corriendo() -> void:
	# Arrange & Act
	var melee: ImperioGirlMelee = _crear_melee()
	await get_tree().process_frame

	# Assert
	assert_eq(melee.estado, ImperioGirlMelee.Estado.CORRIENDO,
			"Al instanciar debe comenzar en estado CORRIENDO")


func test_sin_enemigos_no_cambia_a_atacando() -> void:
	# Arrange: sin enemigos en la escena
	var melee: ImperioGirlMelee = _crear_melee()
	await get_tree().process_frame

	# Act: simular varios frames
	for _i in range(10):
		melee._physics_process(0.1)

	# Assert
	assert_eq(melee.estado, ImperioGirlMelee.Estado.CORRIENDO,
			"Sin enemigos debe mantenerse en CORRIENDO")


func test_señal_died_se_emite_al_morir() -> void:
	# Arrange
	var melee: ImperioGirlMelee = _crear_melee()
	watch_signals(melee)

	# Act
	melee.take_damage(99.0)  # → MURIENDO → disolución (async)
	# La señal died se emite al terminar el tween de disolución;
	# en tests verificamos que _finish_dissolve la emite correctamente
	# llamando directamente al callback.
	melee._finish_dissolve()

	# Assert
	assert_signal_emitted(melee, "died",
			"La señal 'died' debe emitirse al terminar la disolución")
