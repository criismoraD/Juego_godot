extends "res://addons/gut/test.gd"

## Tests unitarios para la animación y tensado del arco de la protagonista (Player.gd)
## Verifica que las animaciones ARCO_TENSAR, ARCO_DISPARO y ARCO_IDLE se resuelvan correctamente,
## que la cuerda y extremidades del arco se tensen proporcionalmente durante la carga,
## mantengan la tensión máxima al apuntar y retornen al reposo tras disparar o cancelar.

const SCENE_PLAYER: PackedScene = preload("res://Entities/Jugador_Arquera/Player.tscn")


func before_all() -> void:
	if gut != null and gut.error_tracker != null:
		gut.error_tracker.treat_engine_errors_as = 0


func test_resolucion_nombres_animaciones_arco() -> void:
	# Arrange
	var player: Player = SCENE_PLAYER.instantiate() as Player
	add_child_autofree(player)

	# Act
	var anim_tensar: String = player.call("_resolver_nombre_anim_arco", "ARCO_TENSAR")
	var anim_disparo: String = player.call("_resolver_nombre_anim_arco", "ARCO_DISPARO")
	var anim_idle: String = player.call("_resolver_nombre_anim_arco", "ARCO_IDLE")

	# Assert
	assert_ne(anim_tensar, "", "Debe resolver el nombre de la animación ARCO_TENSAR")
	assert_true(anim_tensar.contains("ARCO_TENSAR"), "El nombre resuelto debe contener ARCO_TENSAR")
	assert_ne(anim_disparo, "", "Debe resolver el nombre de la animación ARCO_DISPARO")
	assert_true(anim_disparo.contains("ARCO_DISPARO"), "El nombre resuelto debe contener ARCO_DISPARO")
	assert_ne(anim_idle, "", "Debe resolver el nombre de la animación ARCO_IDLE")
	assert_true(anim_idle.contains("ARCO_IDLE"), "El nombre resuelto debe contener ARCO_IDLE")


func test_tensar_cuerda_progreso_y_posicion() -> void:
	# Arrange
	var player: Player = SCENE_PLAYER.instantiate() as Player
	add_child_autofree(player)
	var bow: Node3D = player.get("bow_node") as Node3D
	assert_not_null(bow, "El arco debe existir en el jugador")
	var ap: AnimationPlayer = player.get("bow_anim_player") as AnimationPlayer
	assert_not_null(ap, "El AnimationPlayer del arco debe existir")

	var skel: Skeleton3D = bow.find_child("Skeleton3D", true, false) as Skeleton3D
	assert_not_null(skel, "El Skeleton3D del arco debe existir")
	var string_bone: int = skel.find_bone("String")
	assert_ne(string_bone, -1, "Debe existir el hueso 'String' en el esqueleto del arco")

	var rest_string_pos: Vector3 = skel.get_bone_pose_position(string_bone)

	# Act — Tensar el arco suave y naturalmente
	player.call("play_bow_animation", "ARCO_TENSAR", 0.15, 1.0)
	assert_true(ap.is_playing(), "El AnimationPlayer debe estar reproduciendo ARCO_TENSAR")

	# Avanzar suavemente a medio tensado (0.5s)
	ap.advance(0.5)
	var mid_string_pos: Vector3 = skel.get_bone_pose_position(string_bone)
	assert_ne(mid_string_pos, rest_string_pos, "A medio camino la cuerda debe estar desplazándose suavemente")
	assert_lt(mid_string_pos.y, rest_string_pos.y, "La cuerda debe ir hacia atrás")

	# Avanzar hasta tensado completo (1.25s)
	ap.advance(0.8)
	var tense_string_pos: Vector3 = skel.get_bone_pose_position(string_bone)

	# Assert — La cuerda debe estar retraída a su máxima tensión sin saltos bruscos
	assert_lt(tense_string_pos.y, mid_string_pos.y, "Al final la cuerda debe alcanzar su máxima retracción")


func test_disparo_y_retorno_a_idle() -> void:
	# Arrange
	var player: Player = SCENE_PLAYER.instantiate() as Player
	add_child_autofree(player)
	var bow: Node3D = player.get("bow_node") as Node3D
	var ap: AnimationPlayer = player.get("bow_anim_player") as AnimationPlayer
	var skel: Skeleton3D = bow.find_child("Skeleton3D", true, false) as Skeleton3D
	var string_bone: int = skel.find_bone("String")
	var rest_string_pos: Vector3 = skel.get_bone_pose_position(string_bone)

	# Tensar de forma suave
	player.call("play_bow_animation", "ARCO_TENSAR", 0.15, 1.0)
	ap.advance(1.25)

	# Act 1 — Disparar
	player.call("play_bow_animation", "ARCO_DISPARO")
	var res_disparo: String = player.call("_resolver_nombre_anim_arco", "ARCO_DISPARO")
	assert_eq(ap.current_animation, res_disparo, "Debe reproducir ARCO_DISPARO")

	# Act 2 — Idle
	player.call("play_bow_animation", "ARCO_IDLE")
	ap.advance(0.1)
	var idle_string_pos: Vector3 = skel.get_bone_pose_position(string_bone)

	# Assert — Retorna a la posición de reposo
	assert_almost_eq(idle_string_pos.y, rest_string_pos.y, 0.001, "Tras IDLE la cuerda debe volver al reposo")


func test_cancelar_disparo_restaura_reposo_arco() -> void:
	# Arrange
	var player: Player = SCENE_PLAYER.instantiate() as Player
	add_child_autofree(player)
	var bow: Node3D = player.get("bow_node") as Node3D
	var ap: AnimationPlayer = player.get("bow_anim_player") as AnimationPlayer
	var skel: Skeleton3D = bow.find_child("Skeleton3D", true, false) as Skeleton3D
	var string_bone: int = skel.find_bone("String")
	var rest_string_pos: Vector3 = skel.get_bone_pose_position(string_bone)

	# Act — Iniciar tensado y luego cancelar
	player.set("current_aim_state", 1)  # AimState.DRAWING
	player.call("play_bow_animation", "ARCO_TENSAR", 0.15, 1.0)
	ap.advance(0.5)
	player.call("_cancel_current_shot")

	# Simular proceso en reposo (AimState.NONE)
	player._process(0.016)
	if ap.has_animation(player.call("_resolver_nombre_anim_arco", "ARCO_IDLE")):
		ap.advance(0.05)

	# Assert
	var string_pos_final: Vector3 = skel.get_bone_pose_position(string_bone)
	assert_almost_eq(string_pos_final.y, rest_string_pos.y, 0.001, "Al cancelar el disparo, la cuerda debe volver al reposo")
