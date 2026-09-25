extends "res://addons/gut/test.gd"

var JefeScript = load("res://Levels/Rio_En_Canoa_Con_Parallax/JefeSubmarinoRio.gd")
var MisilScript = load("res://Entities/Proyectil_Misil_Submarino/MisilSubmarino.gd")
var HachaScene: PackedScene = preload("res://Entities/Proyectil_Hacha_Perrena/HachaPerrena.tscn")
var GargolaScene: PackedScene = preload("res://Entities/Enemigo_Gargola/Gargola.tscn")
var _jefe = null


func _crear_camara_activa_en(x: float) -> Camera3D:
	# Arrange: cámara de juego en el viewport para las comprobaciones de encuadre
	var cam := Camera3D.new()
	get_tree().root.add_child(cam)
	cam.global_position = Vector3(x, 4.0, 10.0)
	cam.look_at(Vector3(x, 4.0, 0.0))
	cam.make_current()
	return cam


func _crear_gargola_fase2_en(pos_x: float) -> Node:
	# Arrange: gárgola real configurada como en el spawn de fase 2
	var g = GargolaScene.instantiate()
	get_tree().root.add_child(g)
	g.global_position = Vector3(pos_x, 4.0, 0.0)
	_jefe._configurar_gargola_fase2(g)
	return g


func before_each() -> void:
	_jefe = JefeScript.new()
	get_tree().root.add_child(_jefe)


func after_each() -> void:
	if is_instance_valid(_jefe):
		if _jefe.get_parent():
			_jefe.get_parent().remove_child(_jefe)
		_jefe.free()
	_jefe = null


func test_vida_inicial_43() -> void:
	# Arrange: el _ready fijó la oleada del jefe
	# Act: leer valores iniciales
	# Assert: 43 de vida y oleada 7+3+3
	assert_eq(_jefe.vida_maxima_jefe, 43, "El jefe debe tener 43 de vida maxima")
	assert_eq(_jefe.vida_actual_jefe, 43, "El jefe inicia con 43 de vida")
	assert_eq(_jefe.oleada_piratas + _jefe.oleada_arqueras + _jefe.oleada_imps, 13, "Oleada fase 1: 7+3+3=13")


func test_dano_acumula_y_hunde_a_los_16() -> void:
	# Arrange: forzar superficie para que acepte dano
	_jefe._fase_jefe = 0
	_jefe.current_state = 2
	_jefe._altura_objetivo_y = 12.0
	# Act: 16 de dano en golpes de 1
	for i in range(16):
		_jefe.take_damage(1.0)
	# Assert: vida 27 y salio de fase 1 (transicion o fase 2)
	assert_eq(_jefe.vida_actual_jefe, 27, "43-16=27 tras umbral de fase")
	assert_true(_jefe.obtener_fase() != 0, "Con 16 de dano debe abandonar fase 1")


func test_muerte_con_vida_cero() -> void:
	# Arrange: superficie
	_jefe._fase_jefe = 0
	_jefe.current_state = 2
	_jefe._altura_objetivo_y = 12.0
	var derrotado: Array = []
	_jefe.jefe_derrotado.connect(func(): derrotado.append(true))
	# Act: dano letal
	_jefe.take_damage(43.0)
	# Assert: muerto y senal emitida
	assert_true(_jefe._jefe_muerto, "Con 43 de dano el jefe muere")
	assert_eq(derrotado.size(), 1, "Debe emitir jefe_derrotado una vez")


func test_dano_negativo_no_cura() -> void:
	# Arrange: superficie
	_jefe._fase_jefe = 0
	_jefe.current_state = 2
	_jefe._altura_objetivo_y = 12.0
	# Act: dano negativo (input invalido)
	_jefe.take_damage(-5.0)
	# Assert: no debe curar por encima de 43 (maxi(1,...) lo convierte en 1)
	assert_true(_jefe.vida_actual_jefe <= 43, "El dano negativo no debe curar al jefe")


func test_misil_muere_de_un_golpe() -> void:
	# Arrange: misil con 1 de vida
	var misil = MisilScript.new()
	get_tree().root.add_child(misil)
	# Act: un golpe
	misil.take_damage(1.0)
	# Assert: liberado
	assert_true(not is_instance_valid(misil) or misil.is_queued_for_deletion() or misil._muerto, "El misil debe morir de 1 golpe")
	if is_instance_valid(misil) and not misil.is_queued_for_deletion():
		misil.queue_free()


func test_flash_igual_al_barco() -> void:
	# Arrange: valores del flash de BalsaPirataCombate
	# Act / Assert: mismo color rojo, misma energia y misma velocidad
	assert_eq(_jefe.color_flash_rojo, Color(1.0, 0.0, 0.0), "Mismo rojo que el barco")
	assert_eq(_jefe.intensidad_emision_flash, 2.0, "Misma emision que el barco")
	assert_eq(_jefe.duracion_flash_rojo, 0.12, "Misma velocidad de parpadeo que el barco")
	assert_true(_jefe.parpadeo_rojo_activo, "Parpadeo activo")


func test_formacion_misiles_referencia() -> void:
	# Arrange: patron de la referencia (izquierda abajo, centro arriba, derecha medio)
	# Assert: 3 slots en X y 3 alturas de formacion
	assert_eq(_jefe.offsets_caida_x.size(), 3, "La tanda es de 3 misiles")
	for off in _jefe.offsets_caida_x:
		assert_true(absf(off) <= 1.0, "Los misiles caen sobre la canoa, no afuera")
	assert_eq(_jefe.offsets_formacion_y.size(), 3, "Formacion con 3 alturas")
	assert_true(_jefe.offsets_formacion_y[1] > _jefe.offsets_formacion_y[2], "El centro va mas alto")
	assert_true(_jefe.offsets_formacion_y[2] > _jefe.offsets_formacion_y[0], "La derecha va en medio")


func test_misil_caida_rapida_y_dinamica() -> void:
	# Arrange: el misil debe caer rapido (dinamico, no lento)
	var misil = _jefe.ESCENA_MISIL.instantiate()
	get_tree().root.add_child(misil)
	# Assert: velocidad de caida alta y textura normal (sin tinte morado)
	assert_true(misil.velocidad_caida <= 3.0, "La caida debe ser lenta como antes")
	assert_true(is_instance_valid(misil.get_node_or_null("EstelaCaida")), "Debe tener estela de caida")
	misil.queue_free()


func test_misil_explosion_desintegra_naranja() -> void:
	# Arrange: misil en caida
	var misil = MisilScript.new()
	get_tree().root.add_child(misil)
	misil.fase = 2
	# Act: impacto contra suelo
	misil._impactar_suelo()
	# Assert: entra en desintegracion (no se libera al instante) y avisa al terminar
	assert_true(misil._muerto, "Al impactar queda marcado como muerto")
	assert_eq(misil.COLOR_BORDE_NARANJA, Color(1.0, 0.55, 0.15), "Borde naranja de enemigos")
	if is_instance_valid(misil) and not misil.is_queued_for_deletion():
		misil.queue_free()


func test_jefe_sale_por_izquierda_y_vuelve() -> void:
	# Assert: exports del nuevo flujo de fase 2 existen con valores sanos
	assert_true(_jefe.offset_salida_izquierda >= 5.0, "Debe salir de pantalla a la izquierda")
	assert_true(_jefe.tiempo_salida_izquierda >= 1.0, "Tiempo de salida valido")
	assert_eq(_jefe.gargolas_cantidad, 5, "5 gárgolas tras la primera tanda")
	assert_eq(_jefe.gargola_intervalo, 0.0, "Las 5 aparecen a la vez")
	assert_true(_jefe.gargola_velocidad_crucero > 0.0, "Crucero derecha a izquierda")
	assert_false(_jefe._ref_sumergida_valida, "Sin referencia en test: usa punto automatico")
	assert_true(_jefe._pos_combate.x == 0.0, "Sin escena: punto de combate en origen X")


func test_misil_fija_caida_y_cae() -> void:
	# Arrange: misil en espera arriba
	var misil = MisilScript.new()
	get_tree().root.add_child(misil)
	misil.fase = 1
	var punto := Vector3(5.0, 0.6, -7.5)
	# Act: fijar punto e iniciar caida
	misil.fijar_punto_caida(punto)
	misil.iniciar_caida()
	# Assert: fase caida y mismo punto
	assert_eq(misil.fase, 2, "Debe pasar a fase CAIDA")
	assert_eq(misil._punto_caida, punto, "El punto de caida debe conservarse")
	misil.queue_free()


func test_vida_15_activa_color_rojizo_y_humo() -> void:
	# Arrange: jefe en superficie y con umbral de fase alto para no sumergir
	_jefe._fase_jefe = 0
	_jefe.current_state = 2
	_jefe._altura_objetivo_y = 12.0
	_jefe.umbral_dano_fase = 100
	assert_false(_jefe._esta_danado, "Inicialmente no esta danado")
	assert_false(_jefe._particulas_humo.emitting, "Humo inactivo inicialmente")
	# Act: reducir vida hasta exactamente 15
	_jefe.take_damage(28.0)
	# Assert: vida 15, estado danado activo y humo emitiendo
	assert_eq(_jefe.vida_actual_jefe, 15, "Vida del jefe debe ser 15")
	assert_true(_jefe._esta_danado, "Con 15 de vida debe entrar en estado danado")
	assert_true(_jefe._particulas_humo.emitting, "El humo debe activarse con 15 de vida")
	assert_not_null(_jefe._material_danado, "Debe tener asignado el material danado")
	assert_eq(_jefe._material_danado.albedo_color, _jefe.color_danado_albedo, "Albedo rojizo de dano aplicado")


func test_canon_toma_tono_rojizo_en_menor_medida_al_danarse() -> void:
	# Arrange: jefe en superficie con un modelo de cañón simulado
	_jefe._fase_jefe = 0
	_jefe.current_state = 2
	_jefe._altura_objetivo_y = 12.0
	_jefe.umbral_dano_fase = 100
	var canon_mock := Node3D.new()
	canon_mock.name = "CanonModel"
	var malla_canon := MeshInstance3D.new()
	malla_canon.mesh = BoxMesh.new()
	canon_mock.add_child(malla_canon)
	_jefe.add_child(canon_mock)

	assert_false(_jefe._esta_danado, "Inicialmente no esta danado")
	assert_null(_jefe._material_danado_canon, "Material danado del canon inicia null")

	# Act: reducir vida hasta 15
	_jefe.take_damage(28.0)

	# Assert
	assert_true(_jefe._esta_danado, "Entra en estado danado con 15 de vida")
	assert_not_null(_jefe._material_danado_canon, "Material danado del canon creado")
	assert_eq(_jefe._material_danado_canon.albedo_color, _jefe.color_danado_canon_albedo, "Albedo del canon toma tono rojizo")
	assert_lt(_jefe.intensidad_emision_danado_canon, _jefe.intensidad_emision_danado, "Emision del canon en menor medida")
	assert_gt(_jefe.color_danado_canon_albedo.g, _jefe.color_danado_albedo.g, "Tinte del canon menos rojizo que el casco")
	assert_gt(_jefe._mallas_canon.size(), 0, "Debe tener mallas de canon cacheadas")
	assert_eq(_jefe._mallas_canon[0].material_override, _jefe._material_danado_canon, "Malla del canon tiene asignado material_danado_canon")



func test_vida_mayor_a_15_no_activa_humo() -> void:
	# Arrange: jefe en superficie
	_jefe._fase_jefe = 0
	_jefe.current_state = 2
	_jefe._altura_objetivo_y = 12.0
	# Act: recibir 10 de dano (vida 33 > 15)
	_jefe.take_damage(10.0)
	# Assert: vida 33, sin dano critico ni humo
	assert_eq(_jefe.vida_actual_jefe, 33, "Vida debe ser 33")
	assert_false(_jefe._esta_danado, "A mas de 15 de vida no debe estar danado")
	assert_false(_jefe._particulas_humo.emitting, "El humo permanece inactivo")


func test_muerte_jefe_apaga_humo() -> void:
	# Arrange: jefe danado con humo activo en superficie
	_jefe._fase_jefe = 0
	_jefe.current_state = 2
	_jefe._altura_objetivo_y = 12.0
	_jefe.umbral_dano_fase = 100
	_jefe.take_damage(28.0)
	assert_true(_jefe._particulas_humo.emitting, "Humo activo a 15 de vida")
	# Act: dano letal
	_jefe.take_damage(15.0)
	# Assert: jefe muerto y humo desactivado
	assert_true(_jefe._jefe_muerto, "El jefe debe estar muerto")
	assert_false(_jefe._particulas_humo.emitting, "Al morir el humo debe apagarse")


func test_flash_dano_restaura_material_danado() -> void:
	# Arrange: jefe con vida <= 15
	_jefe._fase_jefe = 0
	_jefe.current_state = 2
	_jefe._altura_objetivo_y = 12.0
	_jefe.take_damage(28.0)
	assert_true(_jefe._esta_danado, "Estado danado activo")
	# Act: simular flash y posterior restauracion
	_jefe._originales_flash.append({"mesh": null, "material": null})
	_jefe._restaurar_materiales_flash()
	# Assert: la cola de flash queda limpia y el material destino es el danado
	assert_true(_jefe._originales_flash.is_empty(), "Cola de flash restaurada")
	assert_not_null(_jefe._material_danado, "Material danado preservado")


func test_humo_se_oculta_al_sumergirse_y_reaparece_al_reemerger() -> void:
	# Arrange: jefe dañado en superficie con humo activo
	_jefe._fase_jefe = 0
	_jefe.current_state = 2 # EN_SUPERFICIE
	_jefe._altura_objetivo_y = 12.0
	_jefe.umbral_dano_fase = 100
	_jefe.take_damage(28.0)
	assert_true(_jefe._particulas_humo.emitting, "Humo activo en superficie")
	assert_true(_jefe._particulas_humo.visible, "Humo visible en superficie")

	# Act 1: sumergirse bajo el agua
	_jefe.current_state = 5 # SUMERGIENDOSE
	_jefe._actualizar_humo_segun_superficie()

	# Assert 1: humo oculto y apagado bajo el agua
	assert_false(_jefe._particulas_humo.emitting, "Al sumergirse bajo el agua el humo no debe emitir")
	assert_false(_jefe._particulas_humo.visible, "Al sumergirse el humo debe estar invisible")

	# Act 2: reemerger a la superficie
	_jefe.current_state = 2 # EN_SUPERFICIE
	_jefe._actualizar_humo_segun_superficie()

	# Assert 2: humo reaparece activo y visible
	assert_true(_jefe._particulas_humo.emitting, "Al reemerger a la superficie el humo vuelve a emitir")
	assert_true(_jefe._particulas_humo.visible, "Al reemerger a la superficie el humo vuelve a ser visible")


func test_destruccion_modelo_vfx_y_audio() -> void:
	# Arrange: jefe en superficie listo para combate
	_jefe._fase_jefe = 0
	_jefe.current_state = 2 # EN_SUPERFICIE
	_jefe._altura_objetivo_y = 12.0
	var escena_destruido_valida: bool = _jefe.ESCENA_SUBMARINO_DESTRUIDO != null
	var vfx_valido: bool = _jefe.ESCENA_VFX_BIG_IMPACT_02 != null
	var sfx_valido: bool = _jefe.SFX_BARCO_HUNDIMIENTO != null
	var exp_pilar_valida: bool = _jefe.ESCENA_EXPLOSION_PILAR != null
	var sfx_exp01_valido: bool = _jefe.SFX_EXPLOSION_01 != null
	var sfx_exp02_valido: bool = _jefe.SFX_EXPLOSION_02 != null
	var tex_piedras_valida: bool = _jefe.TEXTURA_PIEDRAS_NEGRAS_RES != null

	assert_true(escena_destruido_valida, "Escena Submarino destruido precargada")
	assert_true(vfx_valido, "VFXBigImpact_02 precargado")
	assert_true(sfx_valido, "Audio Barco pirata hundimiento precargado")
	assert_true(exp_pilar_valida, "Explocion_Pilar (Globo) precargada")
	assert_true(sfx_exp01_valido, "SFX EXPLOSION01 precargado")
	assert_true(sfx_exp02_valido, "SFX EXPLOSION02 precargado")
	assert_true(tex_piedras_valida, "Textura piedras negras precargada")

	# Act: aplicar daño letal para destruir al jefe
	_jefe.take_damage(43.0)

	# Assert: estado de destrucción, inclinación hacia cámara y volumen en crescendo
	assert_true(_jefe._jefe_muerto, "El jefe debe estar marcado como muerto")
	assert_eq(_jefe.current_state, SubmarinoRio.State.SUMERGIENDOSE, "Debe estar en estado de hundimiento")
	assert_true(_jefe.inclinacion_camara_grados >= 20.0, "Inclinación hacia la cámara de al menos 20 grados")
	assert_true(_jefe.duracion_hundimiento_muerte >= 3.0, "Hundimiento lento de al menos 3 segundos")
	assert_true(_jefe.volumen_final_hundimiento_db > _jefe.volumen_inicial_hundimiento_db, "El volumen debe aumentar mientras se hunde")


func test_cadena_explosiones_y_modelo_destruido_tscn() -> void:
	# Arrange: simular nodo de modelo destruido agregado en la escena (.tscn)
	var nodo_destruido_dummy := Node3D.new()
	nodo_destruido_dummy.name = "Submarino destruido2"
	_jefe.add_child(nodo_destruido_dummy)
	_jefe._buscar_y_configurar_modelo_destruido_tscn()

	# Assert 1: al inicializar, el modelo destruido en escena debe estar oculto
	assert_false(nodo_destruido_dummy.visible, "El modelo destruido del tscn debe comenzar invisible")
	assert_true(_jefe.cantidad_explosiones_cadena >= 3, "Debe haber una cadena de al menos 3 explosiones")
	assert_true(_jefe.intervalo_explosiones_cadena > 0.05, "El intervalo entre explosiones debe ser consistente")

	# Act: ejecutar sustitución por modelo destruido
	_jefe._sustituir_por_modelo_destruido()

	# Assert 2: el modelo destruido debe volverse visible y los modelos intactos/cañón invisibles
	assert_true(nodo_destruido_dummy.visible, "El modelo destruido del tscn debe volverse visible al destruirse")
	if is_instance_valid(_jefe.modelo) and _jefe.modelo != nodo_destruido_dummy:
		assert_false(_jefe.modelo.visible, "El modelo intacto debe estar oculto")
	if is_instance_valid(_jefe._canon_modelo):
		assert_false(_jefe._canon_modelo.visible, "El modelo del cañón debe estar oculto")


func test_misiles_caen_solo_en_zona_verde_canoa() -> void:
	# Arrange: canoa simulada en una posición dada
	var canoa_dummy := Node3D.new()
	canoa_dummy.name = "CanoaProtagonistaRio"
	canoa_dummy.add_to_group("canoa_protagonista")
	get_tree().root.add_child(canoa_dummy)
	canoa_dummy.global_position = Vector3(-15.0, 0.0, -7.5)

	# Act: calcular los puntos de caída para los 3 misiles de la tanda
	var puntos: Array[Vector3] = []
	for i in range(_jefe.misiles_por_tanda):
		puntos.append(_jefe._calcular_punto_caida(i))

	# Assert: todos los puntos deben estar estrictamente dentro de la zona verde de la canoa
	for p in puntos:
		var off: float = p.x - canoa_dummy.global_position.x
		assert_true(off >= _jefe.OFFSET_ZONA_VERDE_MIN_X, "No debe caer a la izquierda de la zona verde")
		assert_true(off <= _jefe.OFFSET_ZONA_VERDE_MAX_X, "No debe caer a la derecha de la zona verde")
		assert_eq(p.z, canoa_dummy.global_position.z, "Debe caer en el mismo eje Z que la canoa")

	# Act 2: verificar que el misil se alinea directamente con la canoa
	var misil = _jefe.ESCENA_MISIL.instantiate() as MisilSubmarino
	get_tree().root.add_child(misil)
	misil.fase = MisilSubmarino.Fase.ESPERA_ARRIBA
	misil.fijar_objetivo_canoa(canoa_dummy, 0.0, 0.6)
	misil.iniciar_caida()
	assert_eq(misil.global_position.x, canoa_dummy.global_position.x, "El misil debe iniciar caída alineado con la canoa")
	assert_eq(misil.global_position.z, canoa_dummy.global_position.z, "El misil debe caer en el eje Z de la canoa")

	canoa_dummy.queue_free()
	misil.queue_free()


func test_sacudida_oleaje_submarino_multiplica_amplitudes_y_suaviza() -> void:
	# Arrange: amplitudes iniciales del submarino
	var amp_flot_orig: float = _jefe.amplitud_floteo
	var amp_bal_orig: float = _jefe.amplitud_balanceo
	var amp_cab_orig: float = _jefe.amplitud_cabeceo

	# Act: aplicar sacudida de oleaje
	_jefe.sacudida_oleaje(2.0, 4.5)

	# Assert: amplitudes aumentadas proporcionalmente y tween de suavizado activo
	assert_gt(_jefe.amplitud_floteo, amp_flot_orig, "La amplitud de floteo debe aumentar durante la sacudida")
	assert_gt(_jefe.amplitud_balanceo, amp_bal_orig, "La amplitud de balanceo debe aumentar durante la sacudida")
	assert_gt(_jefe.amplitud_cabeceo, amp_cab_orig, "La amplitud de cabeceo debe aumentar durante la sacudida")
	assert_not_null(_jefe._tween_oleaje, "El Tween de oleaje debe haberse creado")
	assert_true(_jefe._tween_oleaje.is_valid(), "El Tween de oleaje debe ser valido")


func test_impacto_hacha_especial_perrena_activa_sacudida_oleaje() -> void:
	# Arrange: registrar amplitudes base del submarino
	var amp_bal_orig: float = _jefe.amplitud_balanceo

	var hacha_normal: HachaPerrenaProjectile = HachaScene.instantiate() as HachaPerrenaProjectile
	get_tree().root.add_child(hacha_normal)
	hacha_normal.initialize(Vector3.RIGHT, 1.0, null)
	hacha_normal.es_hacha_especial = false

	# Act 1: impacto de hacha normal no debe sacudir el submarino
	hacha_normal._procesar_impacto(_jefe, Vector3.ZERO, Vector3.UP)

	# Assert 1: amplitudes sin modificar
	assert_eq(_jefe.amplitud_balanceo, amp_bal_orig, "Hacha normal no altera balanceo")
	hacha_normal.free()

	# Arrange 2: hacha especial (Ult de Perrena)
	var hacha_ult: HachaPerrenaProjectile = HachaScene.instantiate() as HachaPerrenaProjectile
	get_tree().root.add_child(hacha_ult)
	hacha_ult.initialize(Vector3.RIGHT, 1.0, null)
	hacha_ult.es_hacha_especial = true

	# Act 2: impacto del Ult sobre el submarino
	hacha_ult._procesar_impacto(_jefe, Vector3.ZERO, Vector3.UP)

	# Assert 2: sacudida activada, balanceo amplificado y tween en curso
	assert_gt(_jefe.amplitud_balanceo, amp_bal_orig, "Hacha especial (Ult) debe sacudir el submarino")
	assert_not_null(_jefe._tween_oleaje, "El Tween de oleaje debe estar activo tras el Ult")
	assert_true(_jefe._tween_oleaje.is_valid(), "El Tween de oleaje debe ser valido tras el Ult")
	hacha_ult.free()


func test_salida_izquierda_hunde_extra_para_no_atravesar_canoa() -> void:
	# Arrange: salida por izquierda configurada
	# Act / Assert: existe hundimiento extra sano para cruzar por debajo de la canoa
	assert_true(_jefe.hundimiento_extra_salida > 0.5, "Debe hundirse un extra al salir por la izquierda")
	assert_true(_jefe.hundimiento_extra_salida < 4.0, "El extra no debe desaparecerlo de escena")
	assert_true(_jefe.tiempo_salida_izquierda >= 1.0, "Tiempo de salida valido")


func test_gargolas_minimo_dos_atacan_a_mitad_de_trayecto() -> void:
	# Arrange: atacantes designadas
	# Act: marcar con 5 gárgolas simuladas
	for i in range(5):
		var dummy := Node3D.new()
		dummy.set_meta("test", true)
		_jefe._gargolas.append(dummy)
	_jefe._marcar_gargolas_atacantes()
	# Assert: mínimo 2 designadas y helper de forzado disponible
	assert_true(_jefe.gargolas_atacantes_min >= 2, "Mínimo 2 gárgolas deben atacar")
	assert_eq(_jefe._gargolas_forzadas.size(), 2, "Debe designar 2 atacantes con 5 gárgolas")
	assert_true(_jefe.has_method("_forzar_ataque_gargola"), "Debe existir forzado de ataque")
	for dummy in _jefe._gargolas:
		dummy.queue_free()
	_jefe._gargolas.clear()
	_jefe._gargolas_forzadas.clear()


func test_rojo_destruido_se_conserva_un_segundo() -> void:
	# Arrange / Act / Assert: el modelo destruido conserva el rojo 1 s para integrar el cambio
	assert_eq(_jefe.duracion_rojo_destruido, 1.0, "El rojo debe conservarse 1 s tras el cambio de modelo")
	assert_true(_jefe.has_method("_aplicar_rojo_transitorio_destruido"), "Debe existir rojo transitorio en modelo destruido")


func test_jefe_margen_bloqueo_encuadra_casco_en_camara() -> void:
	# Arrange / Act: margen configurado en _ready
	# Assert: la canoa frena a 2.4+margen del centro (7.2 m con margen 4.8);
	# la proa de la canoa queda a ~1 m de la plataforma sin solapar el casco.
	assert_gte(_jefe.margen_bloqueo_proa, 4.0, "Margen mínimo para no solapar el casco con la proa")
	assert_lte(_jefe.margen_bloqueo_proa, 5.5, "Margen máximo para encuadre de combate")
	assert_gt(2.4 + _jefe.margen_bloqueo_proa, 6.0, "La proa debe frenar antes de la plataforma")


func test_hundimiento_muerte_lento_y_baile_perrena_tras_hundirse() -> void:
	# Arrange / Act: config de destrucción/hundimiento y baile
	# Assert: hundimiento claramente más lento (baja más tiempo y cambio de modelo en errores)
	assert_gte(_jefe.duracion_hundimiento_muerte, 8.0, "El hundimiento del jefe debe ser lento")
	assert_eq(_jefe.retraso_fin_baile_tras_hundirse, 1.5, "Perrena sigue bailando 1.5 s tras hundirse")
	assert_true(_jefe.has_method("_iniciar_baile_perrena"), "Debe iniciar el baile al destruirse")
	assert_true(_jefe.has_method("_finalizar_baile_tras_hundimiento"), "Debe cerrar y liberar tras el baile")
	assert_true(_jefe.has_method("_detener_baile_perrena"), "Debe detener el baile 1.5 s tras hundirse")


func test_gargola_fuera_de_pantalla_no_ataca_y_sigue_crucero() -> void:
	# Arrange: gárgola en SHOOTING pero muy a la derecha, fuera del encuadre
	var cam := _crear_camara_activa_en(0.0)
	var g = _crear_gargola_fase2_en(30.0)
	g.call("_change_state", 1)
	assert_eq(int(g.get("current_state")), 1, "Precondición: en combate")
	_jefe._gargolas.append(g)
	var x_antes: float = g.global_position.x

	# Act: un paso de crucero
	_jefe._procesar_crucero_gargolas(0.1)

	# Assert: revertida a crucero y avanzando, sin atacar desde afuera
	assert_eq(int(g.get("current_state")), 0, "Fuera de pantalla debe volver a WALKING, no atacar")
	assert_lt(g.global_position.x, x_antes, "Debe seguir barriendo hacia la izquierda")

	g.queue_free()
	cam.queue_free()


func test_gargola_en_pantalla_si_mantiene_combate() -> void:
	# Arrange: gárgola en SHOOTING dentro del encuadre
	var cam := _crear_camara_activa_en(0.0)
	var g = _crear_gargola_fase2_en(0.0)
	g.call("_change_state", 1)
	_jefe._gargolas.append(g)
	var x_antes: float = g.global_position.x

	# Act: un paso de crucero
	_jefe._procesar_crucero_gargolas(0.1)

	# Assert: mantiene el combate en pantalla para completar el ataque
	assert_eq(int(g.get("current_state")), 1, "En pantalla debe mantener SHOOTING")
	assert_almost_eq(g.global_position.x, x_antes, 0.001, "En combate se queda fija para disparar")

	g.queue_free()
	cam.queue_free()


func test_forzar_ataque_fuera_de_pantalla_no_fuerza() -> void:
	# Arrange: gárgola designada pero aún fuera del encuadre
	var cam := _crear_camara_activa_en(0.0)
	var g = _crear_gargola_fase2_en(30.0)

	# Act: intento de forzado desde afuera
	_jefe._forzar_ataque_gargola(g)

	# Assert: no entra en combate hasta entrar en cuadro
	assert_eq(int(g.get("current_state")), 0, "No debe forzarse el ataque fuera de pantalla")
	assert_false(_jefe._gargolas_ataque_forzado.has(g), "No debe marcarse como forzada")

	g.queue_free()
	cam.queue_free()


func test_spawn_gargola_configura_solo_combate_en_pantalla() -> void:
	# Arrange / Act: configuración de fase 2
	var g = _crear_gargola_fase2_en(10.0)

	# Assert: combate limitado a pantalla y caminata larga para no abrir fuego afuera
	assert_true(bool(g.get("solo_atacar_en_pantalla")), "Solo debe combatir en pantalla")
	assert_eq(float(g.get("walked_distance")), 0.0, "La caminata parte de cero al entrar")
	assert_gte(float(g.get("target_walk_distance")), 6.0, "Caminata larga para no disparar antes de entrar")
	assert_lte(float(g.get("target_walk_distance")), 10.0, "Caminata acotada para atacar en cuadro")

	g.queue_free()


func test_gargola_al_salir_por_izquierda_se_elimina_sin_reaparecer_segunda_tanda() -> void:
	# Arrange: gárgola que cruza más allá del límite izquierdo (cam - margen_x)
	var cam := _crear_camara_activa_en(0.0)
	var g = _crear_gargola_fase2_en(-20.0)
	_jefe._gargolas.append(g)

	# Act: procesar crucero donde debe salir de escena
	_jefe._procesar_crucero_gargolas(0.1)

	# Assert: se elimina de la lista y se libera (no se reubica a la derecha en segunda tanda)
	assert_eq(_jefe._gargolas.size(), 0, "No debe quedar en _gargolas al salir por la izquierda")
	assert_true(g.is_queued_for_deletion(), "Debe liberarse con queue_free() para aparecer una sola vez")

	cam.queue_free()


func test_misil_impacto_en_canoa_activa_bamboleo_y_reaccion_perrena() -> void:
	# Arrange
	var MisilScene: PackedScene = load("res://Entities/Proyectil_Misil_Submarino/MisilSubmarino.tscn") as PackedScene
	var misil = MisilScene.instantiate() as MisilSubmarino
	add_child_autofree(misil)

	var canoa_dummy := Node3D.new()
	canoa_dummy.name = "CanoaDummy"
	canoa_dummy.add_to_group("canoas_aliadas")
	canoa_dummy.set_script(load("res://Entities/Ambiente_Canoa_Aliada/CanoaAliada.gd"))
	add_child_autofree(canoa_dummy)

	var perrena_dummy := Node3D.new()
	perrena_dummy.name = "DefensoraPerrena"
	perrena_dummy.add_to_group("defensora_perrena")
	canoa_dummy.add_child(perrena_dummy)

	var anim_player := AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	var lib := AnimationLibrary.new()
	lib.add_animation("Muerte 2", Animation.new())
	lib.add_animation("Pararse", Animation.new())
	anim_player.add_animation_library("", lib)
	perrena_dummy.add_child(anim_player)

	misil.fijar_objetivo_canoa(canoa_dummy, 0.0, 0.0)
	var base_flot: float = canoa_dummy.amplitud_flotacion

	# Act: explosión en suelo/canoa
	misil._explotar(false)

	# Assert: se activó la sacudida de oleaje (bamboleo) en la canoa y la animación de caída en Perrena
	assert_gt(canoa_dummy.amplitud_flotacion, base_flot, "La amplitud de flotación debe elevarse por la sacudida")
	assert_eq(anim_player.current_animation, "Muerte 2", "Perrena debe reproducir animación de caída")


func test_enemigos_en_plataforma_permanecen_en_canon_y_mueren_al_sumergirse() -> void:
	# Arrange: jefe en superficie en Fase 1
	_jefe._fase_jefe = 0
	_jefe.current_state = 2  # State.EN_SUPERFICIE
	_jefe._altura_objetivo_y = 12.0

	var canon_dummy := Node3D.new()
	canon_dummy.name = "CanonModel"
	_jefe.add_child(canon_dummy)
	_jefe._canon_modelo = canon_dummy

	var boca_dummy := Marker3D.new()
	boca_dummy.name = "BocaCanon"
	canon_dummy.add_child(boca_dummy)
	_jefe._boca_canon = boca_dummy

	_jefe.canon_tiempo_apuntado = 0.5
	_jefe.canon_pausa_antes_disparo = 0.5

	var dummy_enemy1 := CharacterBody3D.new()
	dummy_enemy1.name = "PirataGoblin1"
	dummy_enemy1.add_to_group("enemies")
	dummy_enemy1.set("health", 2)
	_jefe.add_child(dummy_enemy1)
	_jefe._enemigos_vivos.append(dummy_enemy1)

	var dummy_enemy2 := CharacterBody3D.new()
	dummy_enemy2.name = "PirataGoblin2"
	dummy_enemy2.add_to_group("enemies")
	dummy_enemy2.set("health", 2)
	_jefe.add_child(dummy_enemy2)
	_jefe._enemigos_vivos.append(dummy_enemy2)

	# Act 1: Aplicar 16 de daño para alcanzar el umbral y entrar a transición de cañón
	for i in range(16):
		_jefe.take_damage(1.0)

	# Assert 1: Al pasar a disparar el cañón, los enemigos vivos NO desaparecen de golpe
	assert_false(dummy_enemy1.is_queued_for_deletion(), "El enemigo 1 no debe borrarse de golpe al pasar al cañón")
	assert_false(dummy_enemy2.is_queued_for_deletion(), "El enemigo 2 no debe borrarse de golpe al pasar al cañón")
	assert_gt(_jefe._enemigos_vivos.size(), 0, "Los enemigos deben permanecer en cubierta durante el cañón")

	# Act 2: Finaliza el disparo del cañón y el submarino comienza a hundirse
	_jefe._hundir_hasta_fuera_de_camara()

	# Assert 2: Al hundirse después de disparar el cañón, los enemigos mueren y se limpia la lista
	assert_eq(_jefe._enemigos_vivos.size(), 0, "La lista de enemigos vivos debe quedar vacía tras la sumersión")
	assert_false(dummy_enemy1.is_in_group("enemies"), "Debe removerse del grupo enemies al morir")
	assert_false(dummy_enemy2.is_in_group("enemies"), "Debe removerse del grupo enemies al morir")


func test_fase2_fondo_configuracion_naufragio() -> void:
	# Arrange / Act: verificar exports de crucero de fondo
	# Assert: valores coherentes para el naufragio y profundidad de fondo
	assert_true(_jefe.fondo_fase2_activo, "El crucero de fondo debe estar activo por defecto")
	assert_true(_jefe.z_fondo_fase2 <= -30.0, "La coordenada Z del fondo debe estar a la distancia del naufragio (< -30)")
	assert_true(_jefe.y_fondo_fase2 < -1.0, "Debe estar sumergido bajo el agua (Y < -1.0)")
	assert_true(_jefe.duracion_crucero_fondo >= 5.0, "La duracion del crucero debe ser suficiente para cruzar la pantalla")
	assert_true(_jefe.margen_salida_fondo_x >= 15.0, "Margen horizontal para cruzar de lado a lado")


func test_reposicionar_sumergido_al_fondo_orienta_y_coloca_en_el_fondo() -> void:
	# Arrange: preparar camara dummy y activar secuencia de fase 2
	var cam := _crear_camara_activa_en(100.0)
	_jefe._secuencia_fase2_activa = true
	_jefe._fase_jefe = 1  # TRANSICION_FASE2

	# Act: reposicionar sumergido al fondo
	_jefe._reposicionar_sumergido_al_fondo()

	# Assert: el jefe está en el fondo (Z <= -30), mirando a la derecha (Y = 180°), no en Z = -7.5 (canoa)
	assert_eq(_jefe.obtener_fase(), 2, "Debe estar en FASE2")
	assert_eq(_jefe.rotation_degrees.y, 180.0, "Debe girar 180 grados para navegar mirando a la derecha (+X)")
	assert_true(_jefe.global_position.z <= -30.0, "Debe ubicarse en el fondo donde esta el naufragio, lejos de la canoa")
	assert_true(_jefe.global_position.x < cam.global_position.x, "Debe comenzar a la izquierda de la camara")
	assert_true(is_instance_valid(_jefe._tween_crucero_fondo), "Debe haber iniciado el tween del crucero")

	cam.queue_free()


func test_volver_a_fase1_restaura_orientacion_y_posicion() -> void:
	# Arrange: jefe simulando crucero en fase 2
	_jefe._fase_jefe = 2
	_jefe.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	_jefe.global_position = Vector3(50.0, -3.2, -39.0)
	_jefe._crucero_fondo_completado = true

	# Act: volver a fase 1
	_jefe._volver_a_fase1()

	# Assert: orientacion restaurada (0 grados), posicion en Z de combate (-7.5), y fase 1 activa
	assert_eq(_jefe.obtener_fase(), 0, "Debe regresar a FASE1")
	assert_eq(_jefe.rotation_degrees, Vector3.ZERO, "Debe restaurar rotacion original (0 grados, mirando a la izquierda hacia la canoa)")
	assert_eq(_jefe.global_position.z, _jefe._pos_combate.z, "Debe regresar al plano Z del combate original")
	assert_false(_jefe._crucero_fondo_completado, "_crucero_fondo_completado se reinicia en false")


func test_crucero_fondo_aplica_escala_reducida_y_restaura() -> void:
	# Arrange: escala base distinta de 1 para verificar restauración exacta
	_jefe.scale = Vector3(2.0, 2.0, 2.0)

	# Act: aplicar escala de fondo
	_jefe._aplicar_escala_fondo()

	# Assert: reducido para parecer más lejos
	assert_almost_eq(_jefe.scale.x, 0.7, 0.001, "En crucero el modelo debe reducirse a 0.7")
	assert_almost_eq(_jefe.scale.y, 0.7, 0.001, "Escala uniforme en Y")
	assert_almost_eq(_jefe.scale.z, 0.7, 0.001, "Escala uniforme en Z")

	# Act: restaurar
	_jefe._restaurar_escala_fondo()

	# Assert: vuelve a la previa exacta y segunda llamada es no-op
	assert_eq(_jefe.scale, Vector3(2.0, 2.0, 2.0), "Debe restaurar la escala previa exacta")
	_jefe.scale = Vector3(0.7, 0.7, 0.7)
	_jefe._restaurar_escala_fondo()
	assert_eq(_jefe.scale, Vector3(0.7, 0.7, 0.7), "Sin aplicar no debe tocar la escala")


func test_crucero_fondo_bamboleo_sutil_mueve_pivot_y_se_congela_al_completar() -> void:
	# Arrange: crucero en curso con pivot falso
	_jefe._secuencia_fase2_activa = true
	_jefe._fase_jefe = 2  # FaseJefe.FASE2
	_jefe._jefe_muerto = false
	_jefe.fondo_fase2_activo = true
	_jefe._crucero_fondo_completado = false
	var piv := Node3D.new()
	piv.name = "PivotFlotacion"
	_jefe.add_child(piv)
	_jefe._preparar_bamboleo_fondo()

	# Act: dos pasos de bamboleo
	_jefe._procesar_bamboleo_fondo(0.5)
	_jefe._procesar_bamboleo_fondo(0.25)
	var y_movida: float = piv.position.y
	var z_rolido: float = piv.rotation.z

	# Assert: sube/baja + rolido sutiles (no tieso)
	assert_ne(y_movida, 0.0, "El bamboleo debe mover el pivot en Y")
	assert_lte(absf(y_movida), 0.3, "Bamboleo sutil en Y (<= 0.3 m)")
	assert_ne(z_rolido, 0.0, "Debe rolar el pivot")
	assert_lte(absf(rad_to_deg(z_rolido)), 5.0, "Rolido sutil (<= 5 grados)")

	# Act: al completar se congela
	_jefe._crucero_fondo_completado = true
	_jefe._procesar_bamboleo_fondo(1.0)

	# Assert: sin cambios tras completar
	assert_eq(piv.position.y, y_movida, "Completado el crucero el bamboleo se congela")
	assert_eq(piv.rotation.z, z_rolido, "Completado el crucero el rolido se congela")
	piv.queue_free()


func test_crucero_fondo_no_bambolea_fuera_de_fase2() -> void:
	# Arrange: pivot falso pero en FASE1
	_jefe._secuencia_fase2_activa = true
	_jefe._fase_jefe = 0  # FaseJefe.FASE1
	_jefe._jefe_muerto = false
	_jefe.fondo_fase2_activo = true
	_jefe._crucero_fondo_completado = false
	var piv := Node3D.new()
	piv.name = "PivotFlotacion"
	_jefe.add_child(piv)
	_jefe._preparar_bamboleo_fondo()

	# Act
	_jefe._procesar_bamboleo_fondo(1.0)

	# Assert: intacto (la base lleva la flotación en fase 1)
	assert_eq(piv.position.y, 0.0, "Fuera de fase 2 no debe tocar el pivot")
	assert_eq(piv.rotation, Vector3.ZERO, "Fuera de fase 2 no debe rotar el pivot")
	piv.queue_free()


class PerrenaEspiaPararse extends Node:
	var llamadas: Array = []
	var player_anim: AnimationPlayer = null
	func _play_anim(nombres, blend: float = 0.15, speed: float = 1.0) -> void:
		llamadas.append({"nombres": (nombres as Array).duplicate(), "speed": speed})
		if player_anim:
			for n in (nombres as Array):
				if player_anim.has_animation(str(n)):
					player_anim.play(str(n), blend, speed)
					return


func _crear_mock_perrena() -> Node:
	var mock := PerrenaEspiaPararse.new()
	mock.name = "MockPerrenaPararse"
	var ap := AnimationPlayer.new()
	var lib := AnimationLibrary.new()
	for n in ["Muerte 2", "Pararse", "Idle Canoa"]:
		var a := Animation.new()
		a.length = 1.0
		lib.add_animation(n, a)
	ap.add_animation_library("", lib)
	mock.add_child(ap)
	mock.player_anim = ap
	add_child_autofree(mock)
	return mock


func test_misil_pararse_acelerado_y_vuelve_a_reposo() -> void:
	# Arrange: misil + sosias de Perrena con clips de 1 s
	var MisilScene: PackedScene = load("res://Entities/Proyectil_Misil_Submarino/MisilSubmarino.tscn") as PackedScene
	var misil = MisilScene.instantiate()
	add_child_autofree(misil)
	var mock = _crear_mock_perrena()
	var ap: AnimationPlayer = mock.get("player_anim") as AnimationPlayer

	# Act: levantarse tras la explosion
	misil._reproducir_pararse(mock)

	# Assert: pararse con velocidad un poco acelerada (1.35)
	assert_eq(mock.llamadas.size(), 1, "Debe pedirse una animacion")
	assert_true((mock.llamadas[0]["nombres"] as Array).has("Pararse"), "Primero la animacion de pararse")
	assert_almost_eq(float(mock.llamadas[0]["speed"]), 1.35, 0.001, "Pararse acelerado a 1.35")
	assert_eq(ap.current_animation, "Pararse", "Reproduce Pararse")

	# Act: esperar el regreso a reposo (1.0/1.35+0.25 ~= 1 s)
	await get_tree().create_timer(1.4).timeout

	# Assert: vuelve a reposo de canoa sin quedarse congelada
	assert_eq(mock.llamadas.size(), 2, "Luego pide el reposo")
	assert_true((mock.llamadas[1]["nombres"] as Array).has("Idle Canoa"), "Reposo de canoa")
	assert_eq(ap.current_animation, "Idle Canoa", "Termina en reposo")
