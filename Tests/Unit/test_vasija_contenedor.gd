extends "res://addons/gut/test.gd"

## Tests unitarios de la vasija contenedora del nivel del rio.
## Cubren valores por defecto, daño con parpadeo rojo, destrucción con
## cambio de modelo, deriva configurable y otorgamiento instantáneo de items.

const ESCENA_VASIJA: String = "res://Levels/Rio_En_Canoa_Con_Parallax/VasijaContenedor.tscn"
const ESCENA_JUGADORA: String = "res://Entities/Jugador_Arquera/Player.tscn"


func _crear_vasija() -> VasijaContenedor:
	var packed := load(ESCENA_VASIJA) as PackedScene
	assert_not_null(packed, "La escena de la vasija debe cargar correctamente")
	var vasija := packed.instantiate() as VasijaContenedor
	assert_not_null(vasija, "Debe instanciar una VasijaContenedor")
	add_child_autofree(vasija)
	return vasija


func _crear_jugadora() -> Node:
	var packed := load(ESCENA_JUGADORA) as PackedScene
	var jugadora: Node = packed.instantiate()
	add_child_autofree(jugadora)
	return jugadora


# === VALORES POR DEFECTO ===
func test_valores_por_defecto() -> void:
	# Arrange & Act
	var vasija := _crear_vasija()

	# Assert
	assert_eq(vasija.vida_maxima, 2.0, "2 puntos de vida por defecto")
	assert_eq(vasija.vida_contenedor, 2.0, "Vida llena al inicio")
	assert_eq(vasija.item_soltado, VasijaContenedor.ItemSoltado.DISPARO_MULTIPLE, "Item por defecto")
	assert_eq(vasija.direccion_viaje, "Derecha", "Viaja a la derecha por defecto")
	assert_gt(vasija.velocidad_desplazamiento, 0.0, "Velocidad positiva por defecto")
	assert_true(vasija.es_escudo_enemigo, "Las flechas de la jugadora deben dañarla")
	assert_false(vasija.esta_destruido(), "No destruida al inicio")
	assert_not_null(vasija.find_child("Model", true, false), "Debe tener modelo intacto")
	assert_not_null(vasija.find_child("ModeloDestruido", true, false), "Debe tener modelo destruido")
	assert_false((vasija.find_child("ModeloDestruido", true, false) as Node3D).visible, "El modelo destruido inicia oculto")


# === DAÑO Y PARPADEO ===
func test_primer_golpe_resta_vida_y_parpadea() -> void:
	# Arrange
	var vasija := _crear_vasija()
	var original = vasija._materiales_originales[0] if vasija._materiales_originales.size() > 0 else null

	# Act
	vasija.recibir_golpe(1.0)

	# Assert
	assert_almost_eq(vasija.vida_contenedor, 1.0, 0.001, "Un golpe resta 1 de vida")
	assert_false(vasija.esta_destruido(), "Con 1 de vida sigue intacta")
	assert_gt(vasija._mallas.size(), 0, "Debe tener mallas cacheadas")
	assert_ne(vasija._mallas[0].material_override, original, "Debe parpadear en rojo al ser impactada")


func test_segundo_golpe_destruye_y_cambia_modelo() -> void:
	# Arrange
	var vasija := _crear_vasija()
	watch_signals(vasija)

	# Act
	vasija.recibir_golpe(1.0)
	vasija.recibir_golpe(1.0)
	await get_tree().process_frame

	# Assert
	assert_true(vasija.esta_destruido(), "Con 0 de vida queda destruida")
	assert_false((vasija.find_child("Model", true, false) as Node3D).visible, "Oculta el modelo intacto")
	assert_true((vasija.find_child("ModeloDestruido", true, false) as Node3D).visible, "Muestra el contenedor destruido")
	assert_true((vasija.find_child("CollisionShape3D", true, false) as CollisionShape3D).disabled, "Desactiva su colisión")
	assert_signal_emitted(vasija, "destruida", "Debe emitir destruida")


func test_golpes_tras_destruir_no_hacen_nada() -> void:
	# Arrange
	var vasija := _crear_vasija()
	vasija.recibir_golpe(1.0)
	vasija.recibir_golpe(1.0)

	# Act
	vasija.recibir_golpe(1.0)

	# Assert
	assert_almost_eq(vasija.vida_contenedor, 0.0, 0.001, "La vida no baja de 0")


# === DERIVA ===
func test_deriva_derecha_e_izquierda() -> void:
	# Arrange
	var vasija := _crear_vasija()
	vasija.deriva_activa = true
	vasija.flotacion_activa = false
	vasija.velocidad_desplazamiento = 0.5
	var x0: float = vasija.position.x

	# Act derecha
	vasija.direccion_viaje = "Derecha"
	vasija._process(1.0)

	# Assert
	assert_almost_eq(vasija.position.x, x0 + 0.5, 0.001, "A la derecha avanza +X")

	# Act izquierda
	vasija.direccion_viaje = "Izquierda"
	vasija._process(1.0)

	# Assert
	assert_almost_eq(vasija.position.x, x0, 0.001, "A la izquierda retrocede")


# === ITEM VISIBLE 1 SEGUNDO ===
func test_suelta_item_visible_un_segundo() -> void:
	# Arrange
	var vasija := _crear_vasija()
	vasija.item_soltado = VasijaContenedor.ItemSoltado.DISPARO_MULTIPLE
	vasija.cantidad_municion = 10

	# Act
	vasija.recibir_golpe(1.0)
	vasija.recibir_golpe(1.0)

	# Assert: aparece el pickup real con 1s en pantalla antes de auto-consumirse
	var item: Node = null
	for hijo in vasija.get_parent().get_children():
		if hijo is Area3D and "tiempo_en_pantalla" in hijo:
			item = hijo
			break
	assert_not_null(item, "Debe soltar el item visible al destruirse")
	assert_almost_eq(float(item.get("tiempo_en_pantalla")), 1.0, 0.001, "El item queda 1s visible")
	assert_eq(int(item.get("municion_a_otorgar_jugador")), 10, "Con la cantidad configurada")


func test_suelta_pocion_con_curacion_configurada() -> void:
	# Arrange
	var vasija := _crear_vasija()
	vasija.item_soltado = VasijaContenedor.ItemSoltado.POCION_CURATIVA
	vasija.curacion_pocion = 2

	# Act
	vasija.recibir_golpe(1.0)
	vasija.recibir_golpe(1.0)

	# Assert
	var item: Node = null
	for hijo in vasija.get_parent().get_children():
		if hijo is Area3D and "vida_a_restaurar" in hijo:
			item = hijo
			break
	assert_not_null(item, "Debe soltar la poción visible")
	assert_eq(int(item.get("vida_a_restaurar")), 2, "Con la curación configurada")


func test_destruir_sin_jugadora_no_rompe() -> void:
	# Arrange
	var vasija := _crear_vasija()

	# Act (sin nadie en el grupo "player")
	vasija.recibir_golpe(1.0)
	vasija.recibir_golpe(1.0)

	# Assert
	assert_true(vasija.esta_destruido(), "Se destruye igual sin jugadora")


# === HUNDIMIENTO Y DISOLUCIÓN CELESTE ===
func test_hundimiento_tras_destruir() -> void:
	# Arrange
	var vasija := _crear_vasija()
	var y_inicial: float = vasija.position.y

	# Act
	vasija.recibir_golpe(1.0)
	vasija.recibir_golpe(1.0)
	await get_tree().create_timer(0.5).timeout

	# Assert: se hunde en lugar de quedarse flotando
	if is_instance_valid(vasija):
		assert_lt(vasija.position.y, y_inicial, "Debe hundirse tras destruirse")


func test_disolucion_celeste_enemiga() -> void:
	# Arrange
	var vasija := _crear_vasija()

	# Act
	vasija.recibir_golpe(1.0)
	vasija.recibir_golpe(1.0)

	# Assert: disolución como los enemigos con brillo celeste
	assert_gt(vasija._materiales_disolver.size(), 0, "Debe preparar materiales de disolución")
	var mat := vasija._materiales_disolver[0] as ShaderMaterial
	assert_not_null(mat, "El material debe ser ShaderMaterial")
	assert_almost_eq(float(mat.get_shader_parameter("glow_color").b), 1.0, 0.01, "Brillo celeste como los enemigos")


# === SONIDO DE ROTURA ===
func test_sonido_vasija_quebrada_registrado() -> void:
	# Arrange & Act
	var tiene_clave: bool = AudioManager.sfx_streams.has("vasija_quebrada")

	# Assert: la clave existe y apunta a un stream válido (si no, play_sfx avisa y calla)
	assert_true(tiene_clave, "vasija_quebrada debe estar registrado en AudioManager")
	var sonidos: Array = AudioManager.sfx_streams["vasija_quebrada"]
	assert_gt(sonidos.size(), 0, "Debe tener al menos un stream")
	assert_not_null(sonidos[0], "El stream debe cargar correctamente")
