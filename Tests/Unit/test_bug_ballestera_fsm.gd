extends "res://addons/gut/test.gd"
## Test FSM de largo plazo: ballesteras estáticas del nivel real disparando
## con la oleada ACTIVA hasta llegar a la fase agachada (5+ disparos).

var NivelScene = load("res://Levels/NIVEL01/NIVEL01.tscn")
var ImpScene = load("res://Entities/Enemigo_Imp/ImpEnemy.tscn")

var _nivel: Node = null


func before_each():
	GameUI.defensoras_config = {1: "ballestera", 2: "ballestera"}
	GameUI.modo_debug_solicitado = true
	_nivel = NivelScene.instantiate()
	get_tree().root.add_child(_nivel)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame


func after_each():
	GameUI.modo_debug_solicitado = false
	GameUI.defensoras_config = {}
	get_tree().current_scene = null
	if is_instance_valid(_nivel):
		_nivel.queue_free()
		await get_tree().process_frame
	for g in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(g):
			g.free()
	get_tree().paused = false


func _ballestera_estatica() -> AllyBallestera:
	for n in _nivel.get_children():
		if n is AllyBallestera and not n.es_movil and not n.es_mensajera:
			return n
	return null


func test_fsm_completa_fase_agachada_suena_y_metaliza():
	var b: AllyBallestera = _ballestera_estatica()
	assert_not_null(b, "Debe existir ballestera estática")
	if not b:
		return

	# Activar como hace el usuario: botón Aliadas ON
	_nivel._set_aliadas_activas(true)

	# Escudo vinculado
	var escudo = b._escudo_piso_ref
	assert_not_null(escudo, "Ballestera con escudo vinculado")
	if not escudo:
		return

	# Spawner con oleada activa y enemigo vivo para que dispare (contexto combate real).
	# El imp es invencible durante la observación: si muriera por los virotes, su
	# disolución/ragdoll generaría ruido de motor ajeno a lo que se prueba.
	var spawner = _nivel.get_node_or_null("WaveSpawner")
	var imp = ImpScene.instantiate()
	_nivel.add_child(imp)
	imp.global_position = Vector3(1.0, 0.5, 0.0)
	imp.health = 99999
	if "vida_maxima" in imp:
		imp.vida_maxima = 99999
	# Congelar al imp: sigue contando como hostil para _puede_atacar() (está vivo,
	# en WALKING y a la derecha), pero no ataca ni genera proyectiles que metan
	# ruido de motor en el test de 60s.
	imp.set_process(false)
	imp.set_physics_process(false)
	if spawner:
		spawner.active_goblins.append(imp)
		spawner.is_wave_active = true

	# Observar hasta 60s: 5 disparos de pie (~25s) → disparo 6 agachado (refuerzo)
	var refuerzo_visto: bool = false
	var informe: String = ""
	for i in range(600):  # 60s a 0.1s
		await get_tree().create_timer(0.1).timeout
		if not is_instance_valid(b) or not is_instance_valid(escudo):
			break
		if escudo.es_metalico:
			refuerzo_visto = true
			informe = "metalizado en t=%.1fs (disparos_en_fase=%d)" % [i * 0.1, b.disparos_en_fase]
			break
		if i % 100 == 0:
			print("[FSM-LP] t=", i * 0.1, "s state=", b.current_state,
				" disparos_en_fase=", b.disparos_en_fase,
				" fase_agachada=", b.fase_agachada,
				" escudo_metalico=", escudo.es_metalico)

	print("[FSM-LP] resultado: ", informe if informe != "" else "SIN REFUERZO en 60s",
		" | disparos_en_fase final=", b.disparos_en_fase if is_instance_valid(b) else -1)

	# Liberar el imp ANTES de los asserts para evitar el error espurio
	# "!is_inside_tree()" de colisiones tardías contra el árbol del test
	if is_instance_valid(imp):
		imp.queue_free()
		await get_tree().physics_frame
		await get_tree().physics_frame
		await get_tree().process_frame

	assert_true(refuerzo_visto, "La FSM debe llegar al refuerzo metálico (fase agachada)")
