extends "res://addons/gut/test.gd"

## Tests unitarios para el comportamiento del Imp Embajador en el nivel Río:
## - Debe aparecer con su estandarte visible y el arco oculto.
## - No ataca con arco hasta que es atacado directamente (bloquea el estado SHOOTING).
## - Al recibir daño (ser atacado), suelta el estandarte físico, equipa el arco y comienza a atacar.
## - Auto-detección del nivel Río y configuración desde BarcoCombatePirata y SubmarinoRio.

const IMP_ESTANDARTE_SCENE: PackedScene = preload("res://Entities/Enemigo_Imp_Estandarte/ImpEnemyEstandarte.tscn")
const SCRIPT_IMP_ESTANDARTE: Script = preload("res://Entities/Enemigo_Imp_Estandarte/ImpEstandarte.gd")
const BARCO_SCENE: PackedScene = preload("res://Entities/Ambiente_Barco_Combate_Pirata/BarcoCombatePirata.tscn")
const SCRIPT_BARCO: Script = preload("res://Entities/Ambiente_Barco_Combate_Pirata/BarcoCombatePirata.gd")
const SUBMARINO_SCENE: PackedScene = preload("res://Levels/Rio_En_Canoa_Con_Parallax/SubmarinoRio.tscn")
const SCRIPT_SUBMARINO: Script = preload("res://Levels/Rio_En_Canoa_Con_Parallax/SubmarinoRio.gd")

var _root_test: Node3D = null


func before_each() -> void:
	_root_test = Node3D.new()
	_root_test.name = "RootTestImpRio"
	get_tree().root.add_child(_root_test)
	get_tree().current_scene = _root_test


func after_each() -> void:
	if is_instance_valid(_root_test):
		_root_test.free()
	for n: Node in get_tree().root.get_children():
		if n.get_script() == SCRIPT_IMP_ESTANDARTE or n.get_script() == SCRIPT_BARCO or n.get_script() == SCRIPT_SUBMARINO:
			n.free()


func _crear_imp(pasivo: bool = true) -> Node3D:
	var imp: Node3D = IMP_ESTANDARTE_SCENE.instantiate() as Node3D
	imp.set("pasivo_hasta_ser_atacado", pasivo)
	imp.set("usar_animacion_hit", false)  # Sin delay de hit timer para tests síncronos
	_root_test.add_child(imp)
	return imp


# ==============================================================================
# TESTS DE APARIENCIA Y ESTANDARTE
# ==============================================================================

func test_imp_embajador_aparece_con_estandarte_y_sin_arco() -> void:
	# Arrange & Act
	var imp := _crear_imp(true)

	# Assert
	var estandarte := imp.get("estandarte_visual") as Node3D
	var arco := imp.get("arco_visual") as Node3D
	var flecha_mano := imp.get("flecha_visual_mano") as Node3D

	assert_not_null(estandarte, "Debe tener estandarte_visual asignado")
	assert_not_null(arco, "Debe tener arco_visual asignado")
	assert_true(estandarte.visible, "El estandarte debe estar VISIBLE al aparecer")
	assert_false(arco.visible, "El arco debe estar OCULTO al aparecer")
	if is_instance_valid(flecha_mano):
		assert_false(flecha_mano.visible, "La flecha de mano debe estar OCULTA al aparecer")


func test_imp_embajador_bloquea_cambio_a_shooting_mientras_no_sea_atacado() -> void:
	# Arrange
	var imp := _crear_imp(true)
	var estandarte := imp.get("estandarte_visual") as Node3D
	var arco := imp.get("arco_visual") as Node3D

	# Act: Intentar forzar el estado SHOOTING (como hacen los barcos y submarinos con la tripulación normal)
	imp.call("_change_state", 1)  # State.SHOOTING = 1

	# Assert: Debe haberse bloqueado y mantenido en WALKING / Idle con su estandarte
	assert_eq(int(imp.get("current_state")), 0, "current_state debe mantenerse en WALKING (0), no SHOOTING")
	assert_true(estandarte.visible, "El estandarte debe seguir VISIBLE")
	assert_false(arco.visible, "El arco debe seguir OCULTO")
	assert_false(bool(imp.get("en_animacion_disparo")), "No debe estar en animación de disparo")


func test_imp_embajador_no_camina_ni_dispara_en_process_walking() -> void:
	# Arrange
	var imp := _crear_imp(true)

	# Act: Ejecutar ciclo de física de caminata
	imp.call("_process_walking", 0.5)

	# Assert: Velocidad debe ser cero (inmóvil con el estandarte) y no cambiar a SHOOTING
	var vel := imp.get("velocity") as Vector3
	assert_almost_eq(vel.x, 0.0, 0.001, "La velocidad horizontal debe ser 0.0 (quieto)")
	assert_eq(int(imp.get("current_state")), 0, "No debe transicionar a SHOOTING")


# ==============================================================================
# TESTS DE REACCIÓN AL SER ATACADO
# ==============================================================================

func test_imp_embajador_al_ser_atacado_suelta_estandarte_y_empieza_a_atacar() -> void:
	# Arrange
	var imp := _crear_imp(true)
	var estandarte := imp.get("estandarte_visual") as Node3D
	var arco := imp.get("arco_visual") as Node3D

	assert_false(bool(imp.get("_ha_sido_atacado")), "Inicialmente no ha sido atacado")
	assert_true(estandarte.visible, "Estandarte visible antes del ataque")

	# Act: Atacarlo haciéndole 1 punto de daño (como flecha o hacha)
	imp.call("take_damage", 1.0)

	# Assert: Debe registrar el ataque, soltar el estandarte y pasar a SHOOTING con arco
	assert_true(bool(imp.get("_ha_sido_atacado")), "Debe marcarse como atacado tras take_damage")
	assert_true(bool(imp.get("estandarte_ya_soltado")), "Debe haber soltado el estandarte")
	assert_eq(int(imp.get("current_state")), 1, "Debe pasar al estado SHOOTING (1)")
	assert_true(arco.visible, "El arco debe pasar a estar VISIBLE para contraatacar")
	assert_false(estandarte.visible, "El estandarte original debe estar OCULTO tras soltarlo")


func test_imp_embajador_con_hit_timer_transiciona_a_shooting_al_terminar_hit() -> void:
	# Arrange
	var imp := _crear_imp(true)
	imp.set("usar_animacion_hit", true)
	imp.set("velocidad_animacion_hit", 10.0)  # Animación ultra rápida para el test

	# Act: Atacar
	imp.call("take_damage", 1.0)
	assert_true(bool(imp.get("_ha_sido_atacado")), "Marcado como atacado")

	# Simular timeout del hit
	imp.call("_on_hit_timer_timeout")

	# Assert: Al terminar la animación de impacto, debe entrar a SHOOTING
	assert_eq(int(imp.get("current_state")), 1, "Debe entrar a SHOOTING tras recuperarse del golpe")
	var arco := imp.get("arco_visual") as Node3D
	assert_true(arco.visible, "El arco debe estar visible tras recuperarse del golpe")


# ==============================================================================
# TESTS DE AUTO-DETECCIÓN Y CONFIGURACIÓN EN RÍO
# ==============================================================================

func test_imp_embajador_auto_detecta_nivel_rio_por_nombre_escena() -> void:
	# Arrange: Escena con nombre que contiene "Rio"
	_root_test.name = "Rio_En_Canoa_Con_Parallax"
	var imp: Node3D = IMP_ESTANDARTE_SCENE.instantiate() as Node3D
	_root_test.add_child(imp)

	# Assert: Debe haber detectado el nivel del río y activado pasivo_hasta_ser_atacado
	assert_true(bool(imp.get("pasivo_hasta_ser_atacado")), "Debe auto-activar pasivo_hasta_ser_atacado en nivel Río")


func test_barco_combate_preconfigura_imp_embajador_como_pasivo() -> void:
	# Arrange
	var barco: Node3D = BARCO_SCENE.instantiate() as Node3D
	_root_test.add_child(barco)
	var imp: Node3D = IMP_ESTANDARTE_SCENE.instantiate() as Node3D

	# Act: Ejecutar preconfiguración del barco
	barco.call("_preconfigurar_tripulante", imp)

	# Assert
	assert_true(bool(imp.get("pasivo_hasta_ser_atacado")), "El barco de combate debe preconfigurar al imp como pasivo")
	imp.free()
	barco.free()


func test_submarino_preconfigura_imp_embajador_como_pasivo() -> void:
	# Arrange
	var submarino: Node3D = SUBMARINO_SCENE.instantiate() as Node3D
	_root_test.add_child(submarino)
	var imp: Node3D = IMP_ESTANDARTE_SCENE.instantiate() as Node3D

	# Act: Ejecutar preconfiguración del submarino
	submarino.call("_configurar_enemigo_para_rio", imp)

	# Assert
	assert_true(bool(imp.get("pasivo_hasta_ser_atacado")), "El submarino debe configurar al imp como pasivo")
	imp.free()
	submarino.free()
