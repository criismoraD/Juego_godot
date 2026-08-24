extends "res://addons/gut/test.gd"

var PlayerScript = load("res://Entities/Jugador_Arquera/Player.gd")


func test_flag_bloqueo_ui_desactivado_por_defecto():
	var player := autofree(PlayerScript.new()) as CharacterBody3D
	assert_false(
		player.get("disparo_bloqueado_por_ui"),
		"El bloqueo de disparo por UI debe estar apagado por defecto (niveles normales)"
	)


func test_activar_bandera_en_mapa_debug():
	var player := autofree(PlayerScript.new()) as CharacterBody3D
	player.set("disparo_bloqueado_por_ui", true)
	assert_true(
		player.get("disparo_bloqueado_por_ui"),
		"El mapa debug debe poder activar el bloqueo de disparo por UI"
	)


func test_sin_hover_no_se_considera_clic_sobre_ui():
	var player := autofree(PlayerScript.new()) as CharacterBody3D
	add_child_autofree(player)
	await get_tree().process_frame
	assert_false(
		player._mouse_sobre_control_ui(),
		"Sin control bajo el cursor no debe considerarse clic sobre la UI"
	)
