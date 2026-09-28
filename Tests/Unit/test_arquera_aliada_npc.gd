extends "res://addons/gut/test.gd"

## Tests unitarios para ArqueraAliadaNPC
## Verifica la lógica de desplazamiento y patrulla horizontal 2.5D (caminata con 'Caminar con arco casual'
## y giro suave de 180°), configuración de dirección inicial, posado en 360 grados,
## y el comportamiento en modo estático permitiendo seleccionar entre:
## 'Pose femenina 2', 'Idle animado' y 'Pose femenina estatica'.

const SCRIPT_ARQUERA: GDScript = preload("res://Entities/NPC_ArqueraAliada/ArqueraAliadaNPC.gd")
const SCENE_ARQUERA: PackedScene = preload("res://Entities/NPC_ArqueraAliada/ArqueraAliadaNPC.tscn")

func test_inicializacion_en_caminando() -> void:
	# Arrange & Act
	var arquera: Node3D = SCENE_ARQUERA.instantiate()
	add_child_autofree(arquera)

	# Assert
	assert_eq(arquera.call("obtener_estado"), SCRIPT_ARQUERA.Estado.CAMINANDO, "El estado inicial debe ser CAMINANDO")
	var ap: AnimationPlayer = arquera.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	assert_not_null(ap, "Debe tener un AnimationPlayer")
	assert_eq(ap.current_animation, "Caminar con arco casual", "La animacion inicial debe ser 'Caminar con arco casual'")
	var clip: Animation = ap.get_animation("Caminar con arco casual")
	assert_eq(clip.loop_mode, Animation.LOOP_LINEAR, "La animacion de caminata debe estar en loop lineal")


func test_material_asignado() -> void:
	# Arrange & Act
	var arquera: Node3D = SCENE_ARQUERA.instantiate()
	add_child_autofree(arquera)

	# Assert
	var meshes: Array[Node] = arquera.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0, "Debe existir al menos una malla para Arquera Aliada")
	var mesh_arquera: MeshInstance3D = meshes[0] as MeshInstance3D
	assert_not_null(mesh_arquera.material_override, "La malla debe tener material_override")


func test_configuracion_direccion_inicial_izquierda() -> void:
	# Arrange & Act
	var arquera: Node3D = SCENE_ARQUERA.instantiate()
	arquera.set("direccion_inicial", SCRIPT_ARQUERA.Direccion.IZQUIERDA)
	arquera.set("velocidad_caminar", 2.0)
	arquera.set("distancia_recorrido", 10.0)
	add_child_autofree(arquera)

	# Assert
	assert_eq(arquera.call("obtener_direccion"), -1.0, "La direccion inicial configurada como IZQUIERDA debe ser -1.0")
	var pivot: Node3D = arquera.get_node_or_null("Pivot")
	assert_not_null(pivot, "Debe existir el nodo Pivot")
	assert_almost_eq(pivot.rotation_degrees.y, -90.0, 1.0, "El Pivot debe orientarse a -90 grados (mirando a la izquierda)")

	# Act — avanzar 1s
	var x_inicial: float = arquera.position.x
	arquera._process(1.0)

	# Assert — debe caminar hacia la izquierda (X decrece)
	assert_almost_eq(arquera.position.x, x_inicial - 2.0, 0.05, "Debe avanzar en direccion negativa (-X) hacia la izquierda")


func test_desplazamiento_horizontal_al_caminar() -> void:
	# Arrange
	var arquera: Node3D = SCENE_ARQUERA.instantiate()
	arquera.set("velocidad_caminar", 2.0)
	arquera.set("distancia_recorrido", 10.0)
	add_child_autofree(arquera)
	var x_inicial: float = arquera.position.x

	# Act — avanzar 1 segundo a 2.0 m/s
	arquera._process(1.0)

	# Assert
	assert_almost_eq(arquera.position.x, x_inicial + 2.0, 0.05, "La posicion X debe avanzar segun velocidad * delta")
	assert_almost_eq(arquera.call("obtener_distancia_acumulada"), 2.0, 0.05, "La distancia acumulada debe registrar 2.0m")


func test_transicion_a_giro_al_alcanzar_distancia() -> void:
	# Arrange
	var arquera: Node3D = SCENE_ARQUERA.instantiate()
	arquera.call("configurar_patrulla", 2.0, 2.0)
	add_child_autofree(arquera)

	# Act — simular avance suficiente para alcanzar el limite
	arquera._process(1.2)

	# Assert
	assert_eq(arquera.call("obtener_estado"), SCRIPT_ARQUERA.Estado.GIRANDO, "Al alcanzar la distancia debe transicionar a GIRANDO")
	var ap: AnimationPlayer = arquera.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	assert_eq(ap.current_animation, "Caminar con arco casual", "La animacion debe mantenerse 'Caminar con arco casual' durante el giro")


func test_inversion_de_sentido_al_terminar_giro() -> void:
	# Arrange
	var arquera: Node3D = SCENE_ARQUERA.instantiate()
	arquera.set("tiempo_giro", 0.5)
	add_child_autofree(arquera)
	assert_eq(arquera.call("obtener_direccion"), 1.0, "Direccion inicial debe ser +1.0")
	arquera.call("iniciar_giro")
	assert_eq(arquera.call("obtener_estado"), SCRIPT_ARQUERA.Estado.GIRANDO)

	# Act — avanzar el tiempo total del giro
	arquera._process(0.55)

	# Assert
	assert_eq(arquera.call("obtener_estado"), SCRIPT_ARQUERA.Estado.CAMINANDO, "Debe retornar a CAMINANDO tras finalizar el giro")
	assert_eq(arquera.call("obtener_direccion"), -1.0, "La direccion debe invertirse a -1.0")
	assert_almost_eq(arquera.call("obtener_distancia_acumulada"), 0.0, 0.01, "La distancia acumulada debe reiniciarse")


func test_rotacion_continua_pivot_durante_giro() -> void:
	# Arrange
	var arquera: Node3D = SCENE_ARQUERA.instantiate()
	arquera.set("tiempo_giro", 1.0)
	add_child_autofree(arquera)
	var pivot: Node3D = arquera.get_node_or_null("Pivot")
	assert_almost_eq(pivot.rotation_degrees.y, 90.0, 1.0)
	arquera.call("iniciar_giro")

	# Act — avanzar medio giro (0.5s)
	arquera._process(0.5)

	# Assert — a mitad de giro (progreso 0.5), el angulo debe estar cerca del punto medio (180 grados)
	assert_almost_eq(pivot.rotation_degrees.y, 180.0, 5.0, "A la mitad del giro, el Pivot debe haber rotado ~90 grados adicionales (total ~180°)")


func test_desaceleracion_suave_al_aproximarse_al_limite() -> void:
	# Arrange
	var arquera: Node3D = SCENE_ARQUERA.instantiate()
	arquera.set("distancia_recorrido", 4.0)
	arquera.set("distancia_desaceleracion", 1.0)
	arquera.set("velocidad_caminar", 2.0)
	add_child_autofree(arquera)

	# Act — avanzar primero a fase crucero
	for i in range(25):
		arquera._process(0.05)
	var vel_crucero: float = arquera.call("obtener_velocidad_actual")

	# Avanzamos hasta cerca del limite (3.7m)
	for i in range(25):
		arquera._process(0.05)
	var vel_frenado: float = arquera.call("obtener_velocidad_actual")

	# Assert
	assert_gt(vel_crucero, vel_frenado, "La velocidad debe desacelerar al acercarse al limite")


func test_modo_estatico_por_defecto_pose_femenina_2() -> void:
	# Arrange
	var arquera: Node3D = SCENE_ARQUERA.instantiate()
	add_child_autofree(arquera)
	var ap: AnimationPlayer = arquera.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	assert_eq(ap.current_animation, "Caminar con arco casual")

	# Act — activar modo estatico
	arquera.set("estatico", true)

	# Assert
	assert_true(arquera.call("esta_estatico"), "Debe estar en modo estatico")
	assert_eq(arquera.call("obtener_estado"), SCRIPT_ARQUERA.Estado.ESTATICO, "El estado debe ser ESTATICO")
	assert_eq(ap.current_animation, "Pose femenina 2", "En modo estatico por defecto debe ejecutar 'Pose femenina 2'")
	var clip: Animation = ap.get_animation("Pose femenina 2")
	assert_eq(clip.loop_mode, Animation.LOOP_LINEAR, "La pose estatica debe estar en loop lineal")


func test_cambio_entre_poses_estaticas() -> void:
	# Arrange
	var arquera: Node3D = SCENE_ARQUERA.instantiate()
	arquera.set("estatico", true)
	add_child_autofree(arquera)
	var ap: AnimationPlayer = arquera.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer

	# Act & Assert 1: Pose femenina 2
	assert_eq(ap.current_animation, "Pose femenina 2")

	# Act & Assert 2: Idle animado
	arquera.set("pose_estatica", "Idle animado")
	assert_eq(ap.current_animation, "Idle animado", "Al seleccionar 'Idle animado' debe reproducirse de inmediato")
	var clip_idle: Animation = ap.get_animation("Idle animado")
	assert_eq(clip_idle.loop_mode, Animation.LOOP_LINEAR, "Idle animado debe estar en loop lineal")

	# Act & Assert 3: Pose femenina estatica
	arquera.call("cambiar_pose_estatica", "Pose femenina estatica")
	assert_eq(ap.current_animation, "Pose femenina estatica", "Al cambiar a 'Pose femenina estatica' debe actualizarse")
	var clip_femenina: Animation = ap.get_animation("Pose femenina estatica")
	assert_eq(clip_femenina.loop_mode, Animation.LOOP_LINEAR, "Pose femenina estatica debe estar en loop lineal")

	# Act & Assert 4: Retorno a Pose femenina 2
	arquera.set("pose_estatica", "Pose femenina 2")
	assert_eq(ap.current_animation, "Pose femenina 2", "Debe volver a 'Pose femenina 2' correctamente")


func test_instanciacion_inicial_estatica_con_pose_personalizada() -> void:
	# Arrange & Act
	var arquera: Node3D = SCENE_ARQUERA.instantiate()
	arquera.set("estatico", true)
	arquera.set("pose_estatica", "Idle animado")
	add_child_autofree(arquera)

	# Assert
	assert_true(arquera.call("esta_estatico"))
	assert_eq(arquera.call("obtener_estado"), SCRIPT_ARQUERA.Estado.ESTATICO)
	var ap: AnimationPlayer = arquera.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	assert_eq(ap.current_animation, "Idle animado", "Debe inicializar directamente con la pose configurada 'Idle animado'")


func test_reanudar_restaura_caminata() -> void:
	# Arrange
	var arquera: Node3D = SCENE_ARQUERA.instantiate()
	add_child_autofree(arquera)
	arquera.call("pausar")
	assert_true(arquera.call("esta_estatico"))

	# Act — reanudar patrulla
	arquera.call("reanudar")

	# Assert
	assert_false(arquera.call("esta_estatico"), "Ya no debe estar estatico")
	assert_eq(arquera.call("obtener_estado"), SCRIPT_ARQUERA.Estado.CAMINANDO, "Debe volver al estado CAMINANDO")
	var ap: AnimationPlayer = arquera.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	assert_eq(ap.current_animation, "Caminar con arco casual", "Debe reanudar 'Caminar con arco casual'")


func test_posar_360_grados() -> void:
	# Arrange
	var arquera: Node3D = SCENE_ARQUERA.instantiate()
	add_child_autofree(arquera)
	var pivot: Node3D = arquera.get_node_or_null("Pivot")
	assert_not_null(pivot, "Debe existir el nodo Pivot")

	# Act 1: Posar a 45 grados
	arquera.call("posar", 45.0)
	assert_true(arquera.get("posar_360"), "Debe activar posar_360")
	assert_almost_eq(pivot.rotation_degrees.y, 45.0, 0.1, "El Pivot debe orientarse a 45°")

	# Act 2: Posar a 270 grados
	arquera.set("posar_angulo", 270.0)
	assert_almost_eq(pivot.rotation_degrees.y, 270.0, 0.1, "El Pivot debe orientarse a 270°")

	# Act 3: Envolver angulo mayor a 360
	arquera.set("posar_angulo", 380.0)
	assert_almost_eq(arquera.get("posar_angulo"), 20.0, 0.1, "380° debe envolverse a 20°")
	assert_almost_eq(pivot.rotation_degrees.y, 20.0, 0.1, "El Pivot debe reflejar el angulo envuelto")


func test_velocidad_animacion_pose_y_caminar() -> void:
	# Arrange
	var arquera: Node3D = SCENE_ARQUERA.instantiate()
	add_child_autofree(arquera)
	var ap: AnimationPlayer = arquera.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer

	# Act & Assert 1: Velocidad caminar
	arquera.set("velocidad_anim_caminar", 1.5)
	assert_almost_eq(ap.speed_scale, 1.5, 0.05, "La velocidad de animacion de caminata debe ser 1.5")

	# Act & Assert 2: Velocidad pose en modo estatico
	arquera.set("estatico", true)
	arquera.set("velocidad_anim_pose", 0.75)
	assert_almost_eq(ap.speed_scale, 0.75, 0.05, "La velocidad de animacion de pose debe ser 0.75")


func test_arquera_aliada_npc_en_nivel_pueblo() -> void:
	# Arrange
	var scene: PackedScene = load("res://Levels/Nivel_Pueblo/NivelPueblo.tscn")
	assert_not_null(scene, "La escena NivelPueblo debe cargar")

	# Act
	var nivel: Node = scene.instantiate()
	add_child_autofree(nivel)
	var arquera: Node = nivel.find_child("ArqueraAliadaNPC", true, false)

	# Assert
	assert_not_null(arquera, "ArqueraAliadaNPC debe existir en NivelPueblo.tscn")
	var ap: AnimationPlayer = arquera.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	assert_not_null(ap, "Debe tener AnimationPlayer")
	assert_eq(ap.current_animation, "Caminar con arco casual", "En el pueblo debe reproducir 'Caminar con arco casual' al patrullar")

