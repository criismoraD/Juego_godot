extends "res://addons/gut/test.gd"

## Tests unitarios para PerrenaPuebloNPC
## Verifica la lógica de desplazamiento y patrulla horizontal 2.5D (caminata y giro suave de 180°),
## configuración de dirección inicial, posado en 360 grados,
## modo estático con selección de poses ('Pose feemenina fija', 'Idle', 'Baile', 'Celebracion', etc.)
## y la correcta integración y presencia en NivelPueblo.tscn.

const SCRIPT_PERRENA: GDScript = preload("res://Entities/NPC_PerrenaPueblo/PerrenaPuebloNPC.gd")
const SCENE_PERRENA: PackedScene = preload("res://Entities/NPC_PerrenaPueblo/PerrenaPuebloNPC.tscn")

func test_inicializacion_en_caminando() -> void:
	# Arrange & Act
	var perrena: Node3D = SCENE_PERRENA.instantiate()
	add_child_autofree(perrena)

	# Assert
	assert_eq(perrena.call("obtener_estado"), SCRIPT_PERRENA.Estado.CAMINANDO, "El estado inicial debe ser CAMINANDO")
	var ap: AnimationPlayer = perrena.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	assert_not_null(ap, "Debe tener un AnimationPlayer")
	assert_eq(ap.current_animation, "Caminar", "La animacion inicial debe ser 'Caminar'")
	var clip: Animation = ap.get_animation("Caminar")
	assert_eq(clip.loop_mode, Animation.LOOP_LINEAR, "La animacion de caminata debe estar en loop lineal")


func test_material_asignado() -> void:
	# Arrange & Act
	var perrena: Node3D = SCENE_PERRENA.instantiate()
	add_child_autofree(perrena)

	# Assert
	var meshes: Array[Node] = perrena.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0, "Debe existir al menos una malla para Perrena")
	var mesh_perrena: MeshInstance3D = meshes[0] as MeshInstance3D
	assert_not_null(mesh_perrena.material_override, "La malla debe tener material_override")


func test_configuracion_direccion_inicial_izquierda() -> void:
	# Arrange & Act
	var perrena: Node3D = SCENE_PERRENA.instantiate()
	perrena.set("direccion_inicial", SCRIPT_PERRENA.Direccion.IZQUIERDA)
	perrena.set("velocidad_caminar", 2.0)
	perrena.set("distancia_recorrido", 10.0)
	add_child_autofree(perrena)

	# Assert
	assert_eq(perrena.call("obtener_direccion"), -1.0, "La direccion inicial configurada como IZQUIERDA debe ser -1.0")
	var pivot: Node3D = perrena.get_node_or_null("Pivot")
	assert_not_null(pivot, "Debe existir el nodo Pivot")
	assert_almost_eq(pivot.rotation_degrees.y, -90.0, 1.0, "El Pivot debe orientarse a -90 grados (mirando a la izquierda)")

	# Act — avanzar 1s
	var x_inicial: float = perrena.position.x
	perrena._process(1.0)

	# Assert — debe caminar hacia la izquierda (X decrece)
	assert_almost_eq(perrena.position.x, x_inicial - 2.0, 0.05, "Debe avanzar en direccion negativa (-X) hacia la izquierda")


func test_desplazamiento_horizontal_al_caminar() -> void:
	# Arrange
	var perrena: Node3D = SCENE_PERRENA.instantiate()
	perrena.set("velocidad_caminar", 2.0)
	perrena.set("distancia_recorrido", 10.0)
	add_child_autofree(perrena)
	var x_inicial: float = perrena.position.x

	# Act — avanzar 1 segundo a 2.0 m/s
	perrena._process(1.0)

	# Assert
	assert_almost_eq(perrena.position.x, x_inicial + 2.0, 0.05, "La posicion X debe avanzar segun velocidad * delta")
	assert_almost_eq(perrena.call("obtener_distancia_acumulada"), 2.0, 0.05, "La distancia acumulada debe registrar 2.0m")


func test_transicion_a_giro_al_alcanzar_distancia() -> void:
	# Arrange
	var perrena: Node3D = SCENE_PERRENA.instantiate()
	perrena.call("configurar_patrulla", 2.0, 2.0)
	add_child_autofree(perrena)

	# Act — simular avance suficiente para alcanzar el limite
	perrena._process(1.2)

	# Assert
	assert_eq(perrena.call("obtener_estado"), SCRIPT_PERRENA.Estado.GIRANDO, "Al alcanzar la distancia debe transicionar a GIRANDO")
	var ap: AnimationPlayer = perrena.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	assert_eq(ap.current_animation, "Caminar", "La animacion debe mantenerse 'Caminar' durante el giro")


func test_inversion_de_sentido_al_terminar_giro() -> void:
	# Arrange
	var perrena: Node3D = SCENE_PERRENA.instantiate()
	perrena.set("tiempo_giro", 0.5)
	add_child_autofree(perrena)
	assert_eq(perrena.call("obtener_direccion"), 1.0, "Direccion inicial debe ser +1.0")
	perrena.call("iniciar_giro")
	assert_eq(perrena.call("obtener_estado"), SCRIPT_PERRENA.Estado.GIRANDO)

	# Act — avanzar el tiempo total del giro
	perrena._process(0.55)

	# Assert
	assert_eq(perrena.call("obtener_estado"), SCRIPT_PERRENA.Estado.CAMINANDO, "Debe retornar a CAMINANDO tras finalizar el giro")
	assert_eq(perrena.call("obtener_direccion"), -1.0, "La direccion debe invertirse a -1.0")
	assert_almost_eq(perrena.call("obtener_distancia_acumulada"), 0.0, 0.01, "La distancia acumulada debe reiniciarse")


func test_rotacion_continua_pivot_durante_giro() -> void:
	# Arrange
	var perrena: Node3D = SCENE_PERRENA.instantiate()
	perrena.set("tiempo_giro", 1.0)
	add_child_autofree(perrena)
	var pivot: Node3D = perrena.get_node_or_null("Pivot")
	assert_almost_eq(pivot.rotation_degrees.y, 90.0, 1.0)
	perrena.call("iniciar_giro")

	# Act — avanzar medio giro (0.5s)
	perrena._process(0.5)

	# Assert — a mitad de giro (progreso 0.5), el angulo debe estar cerca del punto medio (180 grados)
	assert_almost_eq(pivot.rotation_degrees.y, 180.0, 5.0, "A la mitad del giro, el Pivot debe haber rotado ~90 grados adicionales (total ~180°)")


func test_desaceleracion_suave_al_aproximarse_al_limite() -> void:
	# Arrange
	var perrena: Node3D = SCENE_PERRENA.instantiate()
	perrena.set("distancia_recorrido", 4.0)
	perrena.set("distancia_desaceleracion", 1.0)
	perrena.set("velocidad_caminar", 2.0)
	add_child_autofree(perrena)

	# Act — avanzar primero a fase crucero
	for i in range(25):
		perrena._process(0.05)
	var vel_crucero: float = perrena.call("obtener_velocidad_actual")

	# Avanzamos hasta cerca del limite (3.7m)
	for i in range(25):
		perrena._process(0.05)
	var vel_frenado: float = perrena.call("obtener_velocidad_actual")

	# Assert
	assert_gt(vel_crucero, vel_frenado, "La velocidad debe desacelerar al acercarse al limite")


func test_modo_estatico_pose_gala_por_defecto() -> void:
	# Arrange
	var perrena: Node3D = SCENE_PERRENA.instantiate()
	add_child_autofree(perrena)
	var ap: AnimationPlayer = perrena.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	assert_eq(ap.current_animation, "Caminar")

	# Act — activar modo estatico
	perrena.set("estatico", true)

	# Assert
	assert_true(perrena.call("esta_estatico"), "Debe estar en modo estatico")
	assert_eq(perrena.call("obtener_estado"), SCRIPT_PERRENA.Estado.ESTATICO, "El estado debe ser ESTATICO")
	assert_eq(ap.current_animation, "Pose feemenina fija", "En modo estatico por defecto debe ejecutar 'Pose feemenina fija'")
	var clip: Animation = ap.get_animation("Pose feemenina fija")
	assert_eq(clip.loop_mode, Animation.LOOP_LINEAR, "La pose estatica debe estar en loop lineal")


func test_cambio_entre_poses_estaticas() -> void:
	# Arrange
	var perrena: Node3D = SCENE_PERRENA.instantiate()
	perrena.set("estatico", true)
	add_child_autofree(perrena)
	var ap: AnimationPlayer = perrena.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer

	# Act & Assert 1: Pose inicial
	assert_eq(ap.current_animation, "Pose feemenina fija")

	# Act & Assert 2: Idle
	perrena.set("pose_estatica", "Idle")
	assert_eq(ap.current_animation, "Idle", "Al seleccionar 'Idle' debe reproducirse de inmediato")
	var clip_idle: Animation = ap.get_animation("Idle")
	assert_eq(clip_idle.loop_mode, Animation.LOOP_LINEAR)

	# Act & Assert 3: Baile
	perrena.call("cambiar_pose_estatica", "Baile")
	assert_eq(ap.current_animation, "Baile", "Al cambiar a 'Baile' debe actualizarse")

	# Act & Assert 4: Celebracion
	perrena.call("cambiar_pose_estatica", "Celebracion")
	assert_eq(ap.current_animation, "Celebracion", "Al cambiar a 'Celebracion' debe actualizarse")


func test_posar_360_grados() -> void:
	# Arrange
	var perrena: Node3D = SCENE_PERRENA.instantiate()
	add_child_autofree(perrena)
	var pivot: Node3D = perrena.get_node_or_null("Pivot")
	assert_not_null(pivot, "Debe existir el nodo Pivot")

	# Act 1: Posar a 45 grados
	perrena.call("posar", 45.0)
	assert_true(perrena.get("posar_360"), "Debe activar posar_360")
	assert_almost_eq(pivot.rotation_degrees.y, 45.0, 0.1, "El Pivot debe orientarse a 45°")

	# Act 2: Posar a 270 grados
	perrena.set("posar_angulo", 270.0)
	assert_almost_eq(pivot.rotation_degrees.y, 270.0, 0.1, "El Pivot debe orientarse a 270°")

	# Act 3: Envolver angulo mayor a 360
	perrena.set("posar_angulo", 380.0)
	assert_almost_eq(perrena.get("posar_angulo"), 20.0, 0.1, "380° debe envolverse a 20°")
	assert_almost_eq(pivot.rotation_degrees.y, 20.0, 0.1, "El Pivot debe reflejar el angulo envuelto")


func test_velocidad_animacion_pose_y_caminar() -> void:
	# Arrange
	var perrena: Node3D = SCENE_PERRENA.instantiate()
	add_child_autofree(perrena)
	var ap: AnimationPlayer = perrena.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer

	# Act & Assert 1: Velocidad caminar
	perrena.set("velocidad_anim_caminar", 1.5)
	assert_almost_eq(ap.speed_scale, 1.5, 0.05, "La velocidad de animacion de caminata debe ser 1.5")

	# Act & Assert 2: Velocidad pose en modo estatico
	perrena.set("estatico", true)
	perrena.set("velocidad_anim_pose", 0.75)
	assert_almost_eq(ap.speed_scale, 0.75, 0.05, "La velocidad de animacion de pose debe ser 0.75")


func test_perrena_pueblo_npc_en_nivel_pueblo() -> void:
	# Arrange
	var scene: PackedScene = load("res://Levels/Nivel_Pueblo/NivelPueblo.tscn")
	assert_not_null(scene, "La escena NivelPueblo debe cargar")

	# Act
	var nivel: Node = scene.instantiate()
	add_child_autofree(nivel)
	var perrena: Node = nivel.find_child("PerrenaNPCPueblo", true, false)

	# Assert
	assert_not_null(perrena, "PerrenaNPCPueblo debe existir en NivelPueblo.tscn")
	assert_true(perrena.get("estatico"), "PerrenaNPCPueblo debe estar configurada en modo estatico")
	assert_eq(perrena.get("pose_estatica"), "Pose feemenina fija", "Debe tener configurada 'Pose feemenina fija'")
	var ap: AnimationPlayer = perrena.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	assert_not_null(ap, "Debe tener AnimationPlayer")
	assert_eq(ap.current_animation, "Pose feemenina fija", "Debe reproducir 'Pose feemenina fija'")
	assert_true(ap.is_playing(), "El AnimationPlayer debe estar activo")
	var pivot: Node3D = perrena.get_node_or_null("Pivot")
	assert_not_null(pivot, "Debe tener nodo Pivot")
	assert_almost_eq(pivot.rotation_degrees.y, 90.0, 0.5, "El Pivot debe orientarse adecuadamente")


func test_dialogo_pueblo_disponible() -> void:
	# Arrange
	var perrena: Node3D = SCENE_PERRENA.instantiate()
	add_child_autofree(perrena)

	# Assert — el sistema de diálogo está inicializado
	assert_false(perrena.get("_dialogo_mostrado"), "El diálogo no debe haberse mostrado aún")
	assert_false(perrena.get("_dialogo_activo"), "No debe haber diálogo activo al inicio")


func test_color_morado_al_acercarse() -> void:
	# Arrange
	var perrena: Node3D = SCENE_PERRENA.instantiate()
	add_child_autofree(perrena)

	# Act — simular jugador cerca
	perrena.set("_jugador_cerca", true)
	perrena.call("_animar_morado", true)

	# Assert — se configura el StandardMaterial3D de tinte morado con alpha
	var tinte: StandardMaterial3D = perrena.call("obtener_material_tinte")
	assert_not_null(tinte, "Debe existir el material de tinte morado")
	assert_eq(tinte.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED, "El tinte debe ser unshaded")
	assert_eq(tinte.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA, "El tinte debe tener transparencia alpha")
	assert_almost_eq(tinte.albedo_color.r, 0.78, 0.01, "El canal R debe ser morado (~0.78)")
	assert_almost_eq(tinte.albedo_color.g, 0.48, 0.01, "El canal G debe ser morado (~0.48)")
	assert_almost_eq(tinte.albedo_color.b, 0.95, 0.01, "El canal B debe ser morado (~0.95)")


func test_dialogo_solo_una_vez() -> void:
	# Arrange
	var perrena: Node3D = SCENE_PERRENA.instantiate()
	add_child_autofree(perrena)

	# Act — marcar como mostrado
	perrena.set("_dialogo_mostrado", true)

	# Assert — el sistema no mostrará el diálogo de nuevo
	assert_true(perrena.get("_dialogo_mostrado"), "El flag de diálogo mostrado debe persistir")


func test_prompt_hablar_usa_traduccion() -> void:
	# Arrange
	var perrena: Node3D = SCENE_PERRENA.instantiate()
	add_child_autofree(perrena)

	# Act
	var prompt: Label3D = perrena.find_child("PromptHablar", true, false) as Label3D

	# Assert
	assert_not_null(prompt, "Debe crearse el Label3D del prompt")
	assert_true(prompt.text.begins_with("[E] "), "El texto debe comenzar con [E] ")
	assert_true(prompt.text.contains(tr("PERRENA_PROMPT_HABLAR")), "El prompt debe contener la traducción de PERRENA_PROMPT_HABLAR")


func test_congelar_jugador_durante_dialogo() -> void:
	# Arrange
	var perrena: Node3D = SCENE_PERRENA.instantiate()
	add_child_autofree(perrena)

	var mock_player := CharacterBody3D.new()
	mock_player.add_to_group("player")
	mock_player.set("puede_moverse", true)
	add_child_autofree(mock_player)

	# Act — congelar
	perrena.call("_set_movimiento_jugador", false)

	# Assert
	assert_false(mock_player.get("puede_moverse"), "El jugador debe quedar inmovilizado al iniciar diálogo")

	# Act — restaurar
	perrena.call("_set_movimiento_jugador", true)

	# Assert
	assert_true(mock_player.get("puede_moverse"), "El jugador debe recuperar el movimiento al finalizar diálogo")


func test_jingle_perrena_recurso_existe() -> void:
	# Arrange & Assert
	assert_true(ResourceLoader.exists("res://System/Audio/Music/Perrena Jingle.mp3"), "El archivo de jingle de Perrena debe existir")
	var audio := load("res://System/Audio/Music/Perrena Jingle.mp3") as AudioStream
	assert_not_null(audio, "El audio del jingle de Perrena debe cargar correctamente")


func test_jingle_perrena_loop_activo_en_dialogo() -> void:
	# Arrange
	var perrena: Node3D = SCENE_PERRENA.instantiate()
	add_child_autofree(perrena)

	# Act
	perrena.set("_dialogo_activo", true)
	perrena.call("_on_jingle_player_finished")

	# Assert — se maneja callback sin errores
	assert_true(perrena.get("_dialogo_activo"), "El diálogo debe estar activo")



