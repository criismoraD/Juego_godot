extends "res://addons/gut/test.gd"
## Reproducción del bug: ballesteras no suenan "refuerzo_escudo" ni metalizan
## su escudo de piso al agacharse (fase_agachada) en el NIVEL01 real.

var NivelScene = load("res://Levels/NIVEL01/NIVEL01.tscn")
var EscudoScript = load("res://Entities/Ambiente_Escudo/Escudo.gd")
var EscudoScene = load("res://Entities/Ambiente_Escudo/Escudo.tscn")

var _nivel: Node = null
var _ballestera: Node = null
var _sonidos_refuerzo_escuchados: Array = []


func before_all():
	# Espiar AudioManager.play_sfx para capturar llamadas a "refuerzo_escudo"
	var AudioMgr = load("res://System/Core/AudioManager.gd")


func before_each():
	# Configurar defensoras tipo ballestera (flujo del menú de defensoras)
	GameUI.defensoras_config = {1: "ballestera", 2: "ballestera"}
	GameUI.modo_debug_solicitado = true

	_nivel = NivelScene.instantiate()
	get_tree().root.add_child(_nivel)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	# Localizar la ballestera de reemplazo (piso 1)
	_ballestera = _nivel.get_node_or_null("AllyArcher2")
	assert_not_null(_ballestera, "Debe existir la defensora AllyArcher2 (reemplazada por ballestera)")
	if _ballestera:
		assert_true(_ballestera is AllyBallestera, "La defensora del piso 1 debe ser AllyBallestera")


func after_each():
	GameUI.modo_debug_solicitado = false
	GameUI.oleada_inicial_solicitada = 0
	GameUI.defensoras_config = {}
	get_tree().current_scene = null
	if is_instance_valid(_nivel):
		_nivel.queue_free()
		await get_tree().process_frame
	for g in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(g):
			g.free()
	get_tree().paused = false


func test_ballestera_real_vincula_escudo_y_refuerza():
	if not _ballestera:
		return
	# Assert 1: la ballestera vinculó un escudo de piso
	assert_not_null(_ballestera._escudo_piso_ref, "La ballestera debe tener _escudo_piso_ref vinculada")
	assert_true(_ballestera._tiene_escudo_frente, "Debe reportar que tiene escudo frente a ella")
	var escudo: Node = _ballestera._escudo_piso_ref
	if escudo:
		assert_false(escudo.es_escudo_enemigo, "El escudo vinculado debe ser aliado")
		print("[DBG-BALL] escudo vinculado: ", escudo.name, " @ ", (escudo as Node3D).global_position,
			" | ballestera @ ", (_ballestera as Node3D).global_position)

	# Assert 2: el estado inicial no es metálico
	assert_false(escudo.es_metalico, "El escudo inicia sin modo metálico")

	# Act: disparar manualmente en fase agachada (la vía exacta del juego)
	_ballestera.fase_agachada = true
	_ballestera.disparos_en_fase = 0
	_ballestera._aplicar_efecto_escudo_piso()

	# Assert 3: tras la habilidad, el escudo ES metálico
	assert_true(escudo.es_metalico, "Tras _aplicar_efecto_escudo_piso el escudo debe ser metálico")
	assert_eq(escudo.aguante_metalico, 2, "Debe tener 2 de aguante metálico")


func test_ballestera_disparo_agachado_activa_habilidad():
	if not _ballestera:
		return
	# Arrange: ballestera con escudo vinculado y en fase agachada
	if not _ballestera._escudo_piso_ref:
		fail_test("Sin escudo vinculado no se puede probar el disparo agachado")
		return
	var escudo: Node = _ballestera._escudo_piso_ref
	escudo.desactivar_modo_metalico() if escudo.es_metalico else null

	# Act: disparar con fase_agachada=true (misma vía que la FSM: _process_aiming → _disparar)
	_ballestera.fase_agachada = true
	_ballestera._disparar()

	# Assert: el disparo agachado activó el modo metálico en el escudo
	assert_true(escudo.es_metalico, "El disparo en fase agachada debe metalizar el escudo")
	assert_eq(escudo.aguante_metalico, 2, "Aguante metálico = 2")


func test_refuerzo_se_aplica_una_sola_vez_por_fase_agachada():
	# La habilidad se aplica UNA vez cada 5 disparos (primer tiro agachado),
	# no en cada uno de los 5 tiros agachados.
	if not _ballestera:
		return
	if not _ballestera._escudo_piso_ref:
		fail_test("Sin escudo vinculado no se puede probar el ciclo")
		return
	var escudo: Node = _ballestera._escudo_piso_ref
	if escudo.es_metalico:
		escudo.desactivar_modo_metalico()

	# Arrange: inicio de fase agachada (como deja el ciclo tras 5 tiros de pie)
	_ballestera.fase_agachada = true
	_ballestera.disparos_en_fase = 0
	_ballestera.refuerzos_aplicados = 0

	# Act: los 5 disparos de la fase agachada
	for i in range(5):
		_ballestera._disparar()

	# Assert: UNA sola aplicación en toda la fase (no 5)
	assert_eq(_ballestera.refuerzos_aplicados, 1, "El refuerzo debe aplicarse 1 sola vez por fase agachada")
	assert_true(escudo.es_metalico, "El escudo debe quedar metálico")
	assert_eq(escudo.aguante_metalico, 2, "Aguante metálico = 2")


func test_refuerzo_no_acumulable_maximo_mas_2():
	# Si el escudo ya está al máximo (+2), el refuerzo no se re-aplica
	# (ni refresca, ni suma, ni suena de más).
	if not _ballestera:
		return
	if not _ballestera._escudo_piso_ref:
		fail_test("Sin escudo vinculado no se puede probar la no-acumulación")
		return
	var escudo: Node = _ballestera._escudo_piso_ref
	escudo.activar_modo_metalico(2)
	assert_eq(escudo.aguante_metalico, 2, "Precondición: escudo al máximo")

	_ballestera.fase_agachada = true
	_ballestera.disparos_en_fase = 0
	_ballestera.refuerzos_aplicados = 0

	# Act: ciclo completo de 5 disparos agachados con el escudo ya al máximo
	for i in range(5):
		_ballestera._disparar()

	# Assert: no se aplicó de nuevo y el aguante sigue en 2 (sin acumular)
	assert_eq(_ballestera.refuerzos_aplicados, 0, "Con el escudo al máximo no debe re-aplicarse")
	assert_eq(escudo.aguante_metalico, 2, "El aguante no debe superar +2")


func test_refuerzo_refresca_hasta_maximo_2_si_esta_gastado():
	# Si el escudo perdió parte del aguante (1/2), el refuerzo lo restaura a 2.
	if not _ballestera:
		return
	if not _ballestera._escudo_piso_ref:
		fail_test("Sin escudo vinculado no se puede probar el refresco")
		return
	var escudo: Node = _ballestera._escudo_piso_ref
	escudo.activar_modo_metalico(2)
	escudo.aguante_metalico = 1
	assert_true(escudo.es_metalico, "Precondición: escudo metálico con aguante parcial")

	_ballestera.fase_agachada = true
	_ballestera.disparos_en_fase = 0
	_ballestera.refuerzos_aplicados = 0

	# Act: primer disparo de la fase agachada
	_ballestera._disparar()

	# Assert: restaurado a 2, una sola aplicación
	assert_eq(escudo.aguante_metalico, 2, "El refuerzo restaura el aguante hasta 2")
	assert_eq(_ballestera.refuerzos_aplicados, 1, "Se aplicó una sola vez")


func test_refuerzo_reconstruye_escudo_destruido_con_1_vida_y_1_refuerzo():
	# Diseño: al destruirse el escudo de piso vinculado, la habilidad refuerzo lo
	# reconstruye con su animación de reaparecer, solo con 1 de vida y refuerzo a 1
	# (compensa que ya reparó el escudo por completo al reaparecerlo).
	if not _ballestera:
		return
	if not _ballestera._escudo_piso_ref:
		fail_test("Sin escudo vinculado no se puede probar la regeneración")
		return

	# Arrange: escudo vinculado sano y su vida original recordada
	var escudo: Node = _ballestera._escudo_piso_ref
	var vida_original: int = escudo.golpes_para_destruir
	var id_original: int = escudo.get_instance_id()
	assert_gt(vida_original, 1, "Precondición: el escudo del nivel nace con más de 1 de vida")
	assert_eq(_ballestera._escudo_piso_golpes, vida_original,
		"La ballestera debe recordar la vida del escudo vinculado al enlazarlo")

	# Aislar: alejar el resto de escudos aliados para forzar la vía de regeneración
	# (si quedara otro escudo del mismo piso al frente, el refuerzo se aplicaría sobre él)
	for esc in get_tree().get_nodes_in_group("escudos"):
		if not (esc is Node3D) or esc == escudo:
			continue
		if esc.get("es_escudo_enemigo") == true:
			continue
		(esc as Node3D).global_position += Vector3(1000.0, 1000.0, 0.0)

	# Act: destruir el escudo vinculado y usar la habilidad refuerzo
	escudo.queue_free()
	await get_tree().process_frame
	_ballestera.refuerzos_aplicados = 0
	_ballestera._aplicar_efecto_escudo_piso()

	# Assert: el escudo reaparece con 1 de vida y refuerzo a 1 (compensación de diseño)
	var nuevo: Node = _ballestera._escudo_piso_ref
	assert_not_null(nuevo, "La habilidad debe regenerar un escudo nuevo")
	if not nuevo or not is_instance_valid(nuevo):
		return
	assert_ne(nuevo.get_instance_id(), id_original, "Debe ser un escudo regenerado, no el destruido")
	assert_eq(nuevo.golpes_para_destruir, 1,
		"El escudo reconstruido debe tener 1 de vida, no la original del nivel (%d)" % vida_original)
	assert_true(nuevo.es_metalico, "El escudo reconstruido debe recibir el refuerzo metálico")
	assert_eq(nuevo.aguante_metalico, 1, "El escudo reconstruido queda con 1 de refuerzo, no 2")
	assert_eq(_ballestera.refuerzos_aplicados, 1, "El refuerzo se aplicó una sola vez")


func test_refuerzo_solo_acepta_escudo_frente_mismo_piso():
	# REGLA: la fija solo refuerza escudos propios al frente (+X) y de su piso.
	# Ni escudos detrás ni de otro piso ni enemigos son objetivos válidos.
	if not _ballestera:
		return
	var centro: Vector3 = (_ballestera as Node3D).global_position

	# Arrange: sondas de posición (mismo tratamiento que un escudo real)
	var al_frente := Node3D.new()
	al_frente.name = "SondaFrente"
	_nivel.add_child(al_frente)
	al_frente.global_position = centro + Vector3(0.55, 0.0, 0.0)

	var detras := Node3D.new()
	detras.name = "SondaDetras"
	_nivel.add_child(detras)
	detras.global_position = centro + Vector3(-0.55, 0.0, 0.0)

	var otro_piso := Node3D.new()
	otro_piso.name = "SondaOtroPiso"
	_nivel.add_child(otro_piso)
	otro_piso.global_position = centro + Vector3(0.55, 2.0, 0.0)

	var esc_enemigo = EscudoScene.instantiate() as Node3D
	_nivel.add_child(esc_enemigo)
	esc_enemigo.global_position = centro + Vector3(0.55, 0.0, 0.0)
	esc_enemigo.set("es_escudo_enemigo", true)

	# Assert: solo el escudo propio al frente y del mismo piso es válido
	assert_true(_ballestera._es_escudo_de_mi_piso_frente(al_frente),
		"El escudo propio al frente del mismo piso SÍ es objetivo de refuerzo")
	assert_false(_ballestera._es_escudo_de_mi_piso_frente(detras),
		"El escudo detrás NO es objetivo de refuerzo")
	assert_false(_ballestera._es_escudo_de_mi_piso_frente(otro_piso),
		"El escudo de otro piso NO es objetivo de refuerzo")
	assert_false(_ballestera._es_escudo_de_mi_piso_frente(esc_enemigo),
		"El escudo enemigo al frente NO es objetivo de refuerzo")


func test_refuerzo_no_toca_escudo_que_quedo_en_otro_piso():
	# Si el escudo vinculado deja de estar en el piso propio (p. ej. fue movido
	# o la referencia apuntó a otro piso), la habilidad lo descarta y NO lo
	# metaliza: regenera el propio en su marco real en vez de reforzarlo.
	if not _ballestera:
		return
	if not _ballestera._escudo_piso_ref:
		fail_test("Sin escudo vinculado no se puede probar la regla de piso")
		return

	# Aislar el resto de escudos aliados para que no haya otro objetivo válido
	var escudo: Node = _ballestera._escudo_piso_ref
	for esc in get_tree().get_nodes_in_group("escudos"):
		if not (esc is Node3D) or esc == escudo:
			continue
		if esc.get("es_escudo_enemigo") == true:
			continue
		(esc as Node3D).global_position += Vector3(1000.0, 1000.0, 0.0)

	# Arrange: el vinculado queda al frente pero en OTRO piso y sin metalizar
	if escudo.get("es_metalico") == true:
		escudo.desactivar_modo_metalico()
	(escudo as Node3D).global_position = (_ballestera as Node3D).global_position + Vector3(0.55, 2.0, 0.0)
	_ballestera.refuerzos_aplicados = 0

	# Act: la habilidad debe descartar esa referencia fuera de su piso
	_ballestera._aplicar_efecto_escudo_piso()

	# Assert: el escudo de otro piso NO fue reforzado; se regeneró el propio
	assert_false(escudo.es_metalico,
		"El refuerzo no debe metalizar un escudo que está en otro piso")
	assert_not_null(_ballestera._escudo_piso_ref,
		"Debe regenerar el escudo propio de su piso en su marco real")
	assert_ne(_ballestera._escudo_piso_ref, escudo,
		"La referencia fuera del piso propio debe descartarse, no reutilizarse")
