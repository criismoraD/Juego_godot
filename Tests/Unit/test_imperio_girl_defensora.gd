extends "res://addons/gut/test.gd"

## Tests de la defensora Imperio Girl: misma función que la defensora
## arquera (hereda de AllyArcher) con el modelo de Imperio Girl.

const ESCENA_DEFENSORA: PackedScene = preload("res://Entities/Defensora_ImperioGirl/ImperioGirlDefensora.tscn")

const ANIMS_REQUERIDAS: Array[String] = [
	"Armature|IDLE",
	"Armature|TOMAR_FLECHA",
	"Armature|APUNTAR_IDLE",
	"Armature|DISPARAR",
	"Armature|MUERTE_01",
	"Armature|SUBIR_ESCALERA",
	"Armature|CORRER_ADELANTE",
]


func _crear_defensora() -> ImperioGirlDefensora:
	var defensora: ImperioGirlDefensora = ESCENA_DEFENSORA.instantiate() as ImperioGirlDefensora
	add_child_autofree(defensora)
	defensora.global_position = Vector3.ZERO
	return defensora


func _limpiar_cache(defensora: ImperioGirlDefensora) -> void:
	AllyArcher.active_allies_cache.erase(defensora)


func test_es_ally_archer_compatible_con_nivel() -> void:
	# Arrange & Act
	var defensora: ImperioGirlDefensora = _crear_defensora()

	# Assert: el nivel la trata como arquera (is AllyArcher, diálogos, estados)
	assert_true(defensora is AllyArcher, "Debe heredar de AllyArcher para no romper el nivel")
	assert_true(defensora.is_in_group("allies"), "Debe estar en el grupo allies")
	assert_true(AllyArcher.active_allies_cache.has(defensora), "Debe registrarse en active_allies_cache")
	assert_true(defensora.has_method("decir"), "Debe exponer decir() para los diálogos del tutorial")
	assert_true(defensora.es_aliada_inicial, "Defensora inicial como las arqueras del tutorial")
	_limpiar_cache(defensora)


func test_modelo_imperio_girl_con_arco_y_punto_disparo() -> void:
	# Arrange & Act
	var defensora: ImperioGirlDefensora = _crear_defensora()

	# Assert
	var modelo := defensora.find_child("ImperioGirlModel", false, false) as Node3D
	assert_not_null(modelo, "Modelo ImperioGirlModel como hijo directo")
	assert_eq(defensora.model_root, modelo, "La base debe resolver el modelooverrideado")
	assert_not_null(defensora.find_child("FLECHA", true, false), "Flecha visual en mano derecha")
	assert_not_null(defensora.find_child("PuntoDisparo", false, false), "Marker PuntoDisparo para el spawn")
	assert_not_null(defensora.find_child("HitboxBody", true, false), "HitboxBody de aliada")
	assert_not_null(defensora.find_child("Skeleton3D", true, false), "Esqueleto para apuntado y attachments")
	_limpiar_cache(defensora)


func test_alias_animaciones_disparo_y_muerte() -> void:
	# Arrange
	var defensora: ImperioGirlDefensora = _crear_defensora()
	await get_tree().process_frame

	# Act & Assert: cada alias del ciclo de arquera existe y tiene duración
	assert_not_null(defensora.anim_player, "AnimationPlayer corporal resuelto")
	for alias in ANIMS_REQUERIDAS:
		assert_true(defensora.anim_player.has_animation(alias), "Alias registrado: %s" % alias)
		assert_gt(defensora._get_anim_length(alias), 0.0, "Duración válida: %s" % alias)
	_limpiar_cache(defensora)


func test_dano_letal_entra_en_dying() -> void:
	# Arrange
	var defensora: ImperioGirlDefensora = _crear_defensora()
	await get_tree().process_frame

	# Act
	defensora.take_damage(99.0)

	# Assert
	assert_eq(defensora.current_state, AllyArcher.State.DYING, "Daño letal lleva a DYING como la arquera")
	_limpiar_cache(defensora)


func test_textura_imperio_girl_aplicada() -> void:
	# Arrange & Act
	var defensora: ImperioGirlDefensora = _crear_defensora()

	# Assert: ninguna malla del modelo queda sin material (en juego se veía blanca)
	var mallas: Array = defensora.find_child("ImperioGirlModel", true, false).find_children("*", "MeshInstance3D", true, false)
	assert_gt(mallas.size(), 0, "El modelo debe tener mallas")
	for m in mallas:
		var mi := m as MeshInstance3D
		assert_not_null(mi.material_override, "Cada malla lleva el material de Imperio Girl")
	_limpiar_cache(defensora)


func test_sin_enemigos_hace_idle_de_espera() -> void:
	# Arrange: sin enemigos en la escena (como el tutorial sin oleadas)
	var defensora: ImperioGirlDefensora = _crear_defensora()
	await get_tree().process_frame
	await get_tree().process_frame

	# Act: varios frames del ciclo IDLE sin enemigos
	for i in range(10):
		defensora._process(0.1)
		defensora._process_idle(0.1)

	# Assert: sigue en IDLE reproduciendo el clip "Idle espera"
	assert_eq(defensora.current_state, AllyArcher.State.IDLE, "Sin enemigos queda en IDLE")
	var actual: String = defensora.anim_player.current_animation
	assert_true("IDLE" in actual, "Reproduce un idle (actual: %s)" % actual)
	var nativa := _buscar_clip_nativo(defensora.anim_player, "idle espera")
	assert_not_null(nativa, "Existe el clip nativo Idle espera")
	assert_eq(defensora.anim_player.get_animation(actual), nativa, "El idle en curso ES el clip Idle espera")
	_limpiar_cache(defensora)


func _buscar_clip_nativo(anim_p: AnimationPlayer, buscar: String) -> Animation:
	for lib_nombre in anim_p.get_animation_library_list():
		var lib := anim_p.get_animation_library(lib_nombre)
		if lib == null:
			continue
		for anim_nombre in lib.get_animation_list():
			if String(anim_nombre).to_lower().ends_with(buscar):
				return lib.get_animation(anim_nombre)
	return null


func test_sonido_pasos_reducido() -> void:
	# Arrange & Act
	var defensora: ImperioGirlDefensora = _crear_defensora()

	# Assert: locomoción más suave que la arquera (0.5 dB) sin tocar la base
	assert_eq(defensora.volumen_pasos_db, -10.0, "Pasos de Imperio Girl reducidos")
	var arquera_base := AllyArcher.new()
	add_child_autofree(arquera_base)
	assert_eq(arquera_base.volumen_pasos_db, 0.5, "La arquera conserva su volumen")
	AllyArcher.active_allies_cache.erase(arquera_base)
	_limpiar_cache(defensora)
