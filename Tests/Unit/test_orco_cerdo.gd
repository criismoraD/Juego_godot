extends "res://addons/gut/test.gd"

## Tests unitarios para OrcoCerdo
## Verifica la lógica de patrulla (caminata y giro suave de 180° del Pivot manteniendo 'Caminar con lanza'),
## configuración de distancia/velocidad, dirección inicial (DERECHA/IZQUIERDA),
## y el acople de la lanza orco en la mano derecha.

const SCRIPT_ORCO: GDScript = preload("res://Entities/NPC_OrcoCerdo/OrcoCerdo.gd")
const SCENE_ORCO: PackedScene = preload("res://Entities/NPC_OrcoCerdo/OrcoCerdo.tscn")

func test_inicializacion_en_caminando():
	# Arrange & Act
	var orco: Node3D = SCENE_ORCO.instantiate()
	add_child_autofree(orco)

	# Assert
	assert_eq(orco.call("obtener_estado"), SCRIPT_ORCO.Estado.CAMINANDO, "El estado inicial debe ser CAMINANDO")
	var ap: AnimationPlayer = orco.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	assert_not_null(ap, "Debe tener un AnimationPlayer")
	assert_eq(ap.current_animation, "Caminar con lanza", "La animacion inicial debe ser 'Caminar con lanza'")
	var clip: Animation = ap.get_animation("Caminar con lanza")
	assert_eq(clip.loop_mode, Animation.LOOP_LINEAR, "La animacion de caminata debe estar en loop lineal")


func test_lanza_orco_equipada_en_mano_derecha():
	# Arrange & Act
	var orco: Node3D = SCENE_ORCO.instantiate()
	add_child_autofree(orco)

	# Assert
	var lanza: Node3D = orco.call("obtener_lanza") as Node3D
	assert_not_null(lanza, "Debe existir la lanza acoplada")
	var parent_node: Node = lanza.get_parent()
	assert_true(parent_node is BoneAttachment3D, "El padre de la lanza debe ser un BoneAttachment3D")
	var ba := parent_node as BoneAttachment3D
	assert_eq(ba.bone_name, "mixamorig_RightHand", "La lanza debe estar acoplada en mixamorig_RightHand")

	# Verificar material y textura de la lanza
	var meshes_lanza: Array[Node] = lanza.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes_lanza.size(), 0, "La lanza debe tener mallas")
	for m in meshes_lanza:
		var mi := m as MeshInstance3D
		assert_not_null(mi.material_override, "La malla de la lanza debe tener material_override")
		var mat := mi.material_override as StandardMaterial3D
		assert_not_null(mat.albedo_texture, "La lanza debe tener textura")
		assert_true(mat.albedo_texture.resource_path.ends_with("lanza orco_D.jpg"), "La textura de la lanza debe ser lanza orco_D.jpg")


func test_material_y_textura_orco_asignados():
	# Arrange & Act
	var orco: Node3D = SCENE_ORCO.instantiate()
	add_child_autofree(orco)

	# Assert
	var skel: Skeleton3D = orco.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	assert_not_null(skel, "Debe existir el Skeleton3D")
	var mesh_orco: MeshInstance3D = null
	for c in skel.get_children():
		if c is MeshInstance3D:
			mesh_orco = c as MeshInstance3D
			break
	assert_not_null(mesh_orco, "Debe existir la malla del Orco Cerdo")
	assert_not_null(mesh_orco.material_override, "La malla del orco debe tener material_override")
	var mat := mesh_orco.material_override as StandardMaterial3D
	assert_not_null(mat.albedo_texture, "El orco debe tener textura")
	assert_true(mat.albedo_texture.resource_path.ends_with("Orco cerdo_D.jpg"), "La textura debe ser Orco cerdo_D.jpg")


func test_configuracion_direccion_inicial_izquierda():
	# Arrange & Act
	var orco: Node3D = SCENE_ORCO.instantiate()
	orco.set("direccion_inicial", SCRIPT_ORCO.Direccion.IZQUIERDA)
	orco.set("velocidad_caminar", 2.0)
	orco.set("distancia_recorrido", 10.0)
	add_child_autofree(orco)

	# Assert
	assert_eq(orco.call("obtener_direccion"), -1.0, "La direccion inicial configurada como IZQUIERDA debe ser -1.0")
	var pivot: Node3D = orco.get_node_or_null("Pivot")
	assert_not_null(pivot, "Debe existir el nodo Pivot")
	assert_almost_eq(pivot.rotation_degrees.y, -90.0, 1.0, "El Pivot debe orientarse a -90 grados (mirando a la izquierda)")

	# Act — avanzar 1s
	var x_inicial: float = orco.position.x
	orco._process(1.0)

	# Assert — debe caminar hacia la izquierda (X decrece)
	assert_almost_eq(orco.position.x, x_inicial - 2.0, 0.05, "Debe avanzar en direccion negativa (-X) hacia la izquierda")


func test_desplazamiento_horizontal_al_caminar():
	# Arrange
	var orco: Node3D = SCENE_ORCO.instantiate()
	orco.set("velocidad_caminar", 2.0)
	orco.set("distancia_recorrido", 10.0)
	add_child_autofree(orco)
	var x_inicial: float = orco.position.x

	# Act — avanzar 1 segundo a 2.0 m/s
	orco._process(1.0)

	# Assert
	assert_almost_eq(orco.position.x, x_inicial + 2.0, 0.05, "La posicion X debe avanzar segun velocidad * delta")
	assert_almost_eq(orco.call("obtener_distancia_acumulada"), 2.0, 0.05, "La distancia acumulada debe registrar 2.0m")


func test_transicion_a_giro_al_alcanzar_distancia():
	# Arrange
	var orco: Node3D = SCENE_ORCO.instantiate()
	orco.call("configurar_patrulla", 2.0, 2.0)
	add_child_autofree(orco)

	# Act — simular avance suficiente para alcanzar el limite
	orco._process(1.2)

	# Assert
	assert_eq(orco.call("obtener_estado"), SCRIPT_ORCO.Estado.GIRANDO, "Al alcanzar la distancia debe transicionar a GIRANDO")
	var ap: AnimationPlayer = orco.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	assert_eq(ap.current_animation, "Caminar con lanza", "La animacion debe mantenerse 'Caminar con lanza' sin animaciones de giro")


func test_inversion_de_sentido_al_terminar_giro():
	# Arrange
	var orco: Node3D = SCENE_ORCO.instantiate()
	orco.set("tiempo_giro", 0.5)
	add_child_autofree(orco)
	assert_eq(orco.call("obtener_direccion"), 1.0, "Direccion inicial debe ser +1.0")
	orco.call("iniciar_giro")
	assert_eq(orco.call("obtener_estado"), SCRIPT_ORCO.Estado.GIRANDO)

	# Act — simular finalizacion del tiempo de giro (0.5s)
	orco._process(0.6)

	# Assert
	assert_eq(orco.call("obtener_estado"), SCRIPT_ORCO.Estado.CAMINANDO, "Debe volver a CAMINANDO tras el giro")
	assert_eq(orco.call("obtener_direccion"), -1.0, "La direccion debe invertirse a -1.0")
	var ap: AnimationPlayer = orco.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	assert_eq(ap.current_animation, "Caminar con lanza", "La animacion debe mantenerse continua en 'Caminar con lanza'")


func test_rotacion_continua_pivot_durante_giro():
	# Arrange
	var orco: Node3D = SCENE_ORCO.instantiate()
	orco.set("tiempo_giro", 0.8)
	add_child_autofree(orco)
	var pivot: Node3D = orco.get_node("Pivot")
	assert_almost_eq(pivot.rotation_degrees.y, 90.0, 0.1, "Pivot inicial en 90 deg")

	# Act — iniciar giro y avanzar la mitad del tiempo de giro
	orco.call("iniciar_giro")
	orco._process(0.4)

	# Assert — el Pivot debe haber rotado suavemente a mitad de camino entre 90 y 270 grados
	var rot_media: float = pivot.rotation_degrees.y
	assert_gt(rot_media, 90.0, "El pivot debe rotar continuamente durante el giro")
	assert_lt(rot_media, 270.0, "El pivot a mitad del giro debe estar entre 90 y 270 deg")
	assert_almost_eq(rot_media, 180.0, 15.0, "A mitad del giro el angulo debe aproximarse a 180 deg")


func test_caminata_continua_durante_todo_el_giro():
	# Arrange
	var orco: Node3D = SCENE_ORCO.instantiate()
	orco.set("tiempo_giro", 0.6)
	add_child_autofree(orco)
	var ap: AnimationPlayer = orco.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer

	# Act — iniciar giro
	orco.call("iniciar_giro")

	# Assert — durante el giro no cambia de animación
	assert_eq(ap.current_animation, "Caminar con lanza", "No debe cambiar a ninguna animación torcida")
	var clip: Animation = ap.get_animation("Caminar con lanza")
	assert_eq(clip.loop_mode, Animation.LOOP_LINEAR, "Debe continuar en LOOP_LINEAR")


func test_desaceleracion_suave_al_aproximarse_al_limite():
	# Arrange
	var orco: Node3D = SCENE_ORCO.instantiate()
	orco.set("distancia_recorrido", 4.0)
	orco.set("distancia_desaceleracion", 1.0)
	orco.set("velocidad_caminar", 2.0)
	add_child_autofree(orco)

	# Act — avanzar primero a fase crucero
	for i in range(25):
		orco._process(0.05)
	var vel_crucero: float = orco.call("obtener_velocidad_actual")

	# Avanzamos hasta cerca del limite (3.7m)
	for i in range(25):
		orco._process(0.05)
	var vel_frenado: float = orco.call("obtener_velocidad_actual")

	# Assert
	assert_gt(vel_crucero, vel_frenado, "La velocidad debe desacelerar al acercarse al limite")
	assert_gt(vel_frenado, 0.0, "La velocidad de frenado debe mantenerse positiva antes del giro")


func test_orco_cerdo_en_nivel_pueblo():
	# Arrange
	var scene: PackedScene = load("res://Levels/Nivel_Pueblo/NivelPueblo.tscn")
	assert_not_null(scene, "La escena NivelPueblo debe cargar")

	# Act
	var nivel: Node = scene.instantiate()
	add_child_autofree(nivel)
	var orco: Node = nivel.find_child("OrcoCerdo", true, false)

	# Assert
	assert_not_null(orco, "OrcoCerdo debe existir en NivelPueblo.tscn")
	var lanza: Node3D = orco.call("obtener_lanza") as Node3D
	assert_not_null(lanza, "El orco en NivelPueblo debe tener la lanza equipada")
	assert_gt(orco.get("distancia_recorrido"), 0.0, "Debe tener configurada distancia_recorrido")
	assert_gt(orco.get("velocidad_caminar"), 0.0, "Debe tener configurada velocidad_caminar")


func test_orco_cerdo_modo_estatico_pausa_patrulla_y_animacion():
	# Arrange
	var orco: Node3D = SCENE_ORCO.instantiate()
	orco.set("velocidad_caminar", 2.0)
	orco.set("distancia_recorrido", 6.0)
	add_child_autofree(orco)
	var x_inicial: float = orco.position.x

	# Act
	orco.call("pausar")

	# Assert
	assert_true(orco.call("esta_estatico"), "Debe reportar que está estático")
	assert_eq(orco.call("obtener_estado"), SCRIPT_ORCO.Estado.ESTATICO, "El estado debe ser ESTATICO")
	var ap: AnimationPlayer = orco.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	assert_false(ap.is_playing(), "El AnimationPlayer debe estar detenido/pausado")

	# Act: Avanzar frames en modo estático
	for i in range(30):
		orco._process(0.016)

	# Assert: La posición horizontal no debe haber cambiado
	assert_almost_eq(orco.position.x, x_inicial, 0.001, "En modo estático la posición X no debe variar")
	assert_eq(orco.call("obtener_estado"), SCRIPT_ORCO.Estado.ESTATICO, "Debe mantenerse en estado ESTATICO")


func test_orco_cerdo_deformacion_sutil_respiracion():
	# Arrange
	var orco: Node3D = SCENE_ORCO.instantiate()
	orco.set("estatico", true)
	orco.set("respiracion_velocidad", 2.0)
	orco.set("respiracion_intensidad", 0.03)
	add_child_autofree(orco)

	var model: Node3D = orco.find_child("Model", true, false) as Node3D
	assert_not_null(model, "Debe existir el nodo Model dentro de Pivot")

	var escalas_y: Array[float] = []

	# Act: Simular un ciclo completo de respiración (período ~3.14s con velocidad 2.0)
	for i in range(80):
		orco._process(0.05)
		escalas_y.append(model.scale.y)

	# Assert: Debe haber variación continua (inhalación y exhalación)
	var max_y: float = -INF
	var min_y: float = INF
	for sy in escalas_y:
		max_y = maxf(max_y, sy)
		min_y = minf(min_y, sy)

	assert_gt(max_y, 1.0, "La escala Y debe expandirse por encima de 1.0 durante la inhalación")
	assert_lt(min_y, 1.0, "La escala Y debe comprimirse por debajo de 1.0 durante la exhalación")
	assert_almost_eq(max_y, 1.03, 0.01, "La expansión máxima debe coincidir con la intensidad (1.03)")
	assert_almost_eq(min_y, 0.97, 0.01, "La compresión mínima debe coincidir con la intensidad (0.97)")


func test_orco_cerdo_reanudar_restaura_caminata():
	# Arrange
	var orco: Node3D = SCENE_ORCO.instantiate()
	orco.set("estatico", true)
	add_child_autofree(orco)
	var model: Node3D = orco.find_child("Model", true, false) as Node3D
	orco._process(0.5)

	# Act
	orco.call("reanudar")

	# Assert
	assert_false(orco.call("esta_estatico"), "Al reanudar no debe estar estático")
	assert_eq(orco.call("obtener_estado"), SCRIPT_ORCO.Estado.CAMINANDO, "Debe volver al estado CAMINANDO")
	assert_almost_eq(model.scale.y, 1.0, 0.001, "La escala Y del modelo debe restaurarse a 1.0")
	assert_almost_eq(model.scale.x, 1.0, 0.001, "La escala X del modelo debe restaurarse a 1.0")
	assert_almost_eq(model.scale.z, 1.0, 0.001, "La escala Z del modelo debe restaurarse a 1.0")
	var ap: AnimationPlayer = orco.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	assert_true(ap.is_playing(), "El AnimationPlayer debe reanudar la animación de caminata")


func test_orco_cerdo5_en_nivel_pueblo_es_estatico():
	# Arrange
	var scene: PackedScene = load("res://Levels/Nivel_Pueblo/NivelPueblo.tscn")
	assert_not_null(scene, "La escena NivelPueblo debe cargar")

	# Act
	var nivel: Node = scene.instantiate()
	add_child_autofree(nivel)
	var orco5: Node = nivel.find_child("OrcoCerdo5", true, false)

	# Assert
	assert_not_null(orco5, "OrcoCerdo5 debe existir en NivelPueblo.tscn")
	assert_true(orco5.get("estatico"), "OrcoCerdo5 debe tener estatico = true")


func test_orco_cerdo_modo_estatico_pose_secreto():
	# Arrange
	var orco: Node3D = SCENE_ORCO.instantiate()
	orco.set("estatico", true)
	orco.set("pose_estatica", "Secreto")
	add_child_autofree(orco)

	# Assert
	assert_true(orco.call("esta_estatico"), "Debe estar en modo estático")
	assert_eq(orco.call("obtener_estado"), SCRIPT_ORCO.Estado.ESTATICO, "El estado debe ser ESTATICO")
	var ap: AnimationPlayer = orco.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	assert_not_null(ap, "Debe tener AnimationPlayer")
	assert_eq(ap.current_animation, "Secreto", "En modo estático con pose 'Secreto' debe reproducir la animación 'Secreto'")
	assert_true(ap.is_playing(), "El AnimationPlayer debe estar reproduciendo la animación Secreto")
	var clip: Animation = ap.get_animation("Secreto")
	assert_not_null(clip, "El clip 'Secreto' debe existir")
	assert_eq(clip.loop_mode, Animation.LOOP_LINEAR, "La animación 'Secreto' debe configurarse en loop lineal")


func test_orco_cerdo_cambio_dinamico_pose_secreto_y_respiracion():
	# Arrange
	var orco: Node3D = SCENE_ORCO.instantiate()
	orco.set("estatico", true)
	add_child_autofree(orco)
	var ap: AnimationPlayer = orco.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	assert_false(ap.is_playing(), "Por defecto en 'Respiracion' el AnimationPlayer debe estar detenido")

	# Act 1: Cambiar dinámicamente a pose Secreto (incluso con minúsculas)
	orco.call("cambiar_pose_estatica", "secreto")

	# Assert 1
	assert_eq(ap.current_animation, "Secreto", "Debe reproducir 'Secreto'")
	assert_true(ap.is_playing(), "Debe estar en reproducción")

	# Act 2: Regresar a Respiracion
	orco.call("cambiar_pose_estatica", "Respiracion")

	# Assert 2
	assert_false(ap.is_playing(), "Al volver a 'Respiracion' el AnimationPlayer debe detenerse")


func test_orco_cerdo_velocidad_animacion_pose():
	# Arrange
	var orco: Node3D = SCENE_ORCO.instantiate()
	orco.set("estatico", true)
	orco.set("pose_estatica", "Secreto")
	orco.set("velocidad_anim_pose", 0.5)
	add_child_autofree(orco)

	# Assert
	var ap: AnimationPlayer = orco.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	assert_almost_eq(ap.speed_scale, 0.5, 0.05, "La velocidad de animación de la pose debe ser 0.5")


func test_orco_cerdo8secreto_en_nivel_pueblo():
	# Arrange
	var scene: PackedScene = load("res://Levels/Nivel_Pueblo/NivelPueblo.tscn")
	assert_not_null(scene, "La escena NivelPueblo debe cargar")

	# Act
	var nivel: Node = scene.instantiate()
	add_child_autofree(nivel)
	var orco8: Node = nivel.find_child("OrcoCerdo8secreto", true, false)

	# Assert
	assert_not_null(orco8, "OrcoCerdo8secreto debe existir en NivelPueblo.tscn")
	assert_true(orco8.get("estatico"), "Debe estar en modo estático")
	assert_eq(orco8.get("pose_estatica"), "Secreto", "Debe tener configurada la pose 'Secreto'")
	var ap: AnimationPlayer = orco8.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	assert_not_null(ap, "Debe tener AnimationPlayer")
	assert_eq(ap.current_animation, "Secreto", "Debe estar reproduciendo 'Secreto'")
	assert_true(ap.is_playing(), "El AnimationPlayer debe estar activo reproduciendo 'Secreto'")
	var pivot: Node3D = orco8.get_node_or_null("Pivot")
	assert_not_null(pivot, "Debe tener nodo Pivot")
	assert_almost_eq(pivot.rotation_degrees.y, 90.0, 0.5, "El Pivot debe orientarse a 90° para mirar en la dirección deseada hacia el pozo")


