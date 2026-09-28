extends "res://addons/gut/test.gd"

## Tests unitarios para RatonaHerrera
## Verifica la lógica de desplazamiento y patrulla horizontal 2.5D (caminata y giro suave de 180°),
## configuración de dirección inicial, y el comportamiento por defecto de reproducir
## la animación 'Idle herrera' cuando está con las animaciones desactivadas (modo estático).

const SCRIPT_RATONA: GDScript = preload("res://Entities/NPC_RatonaHerrera/RatonaHerrera.gd")
const SCENE_RATONA: PackedScene = preload("res://Entities/NPC_RatonaHerrera/RatonaHerrera.tscn")

func test_inicializacion_en_caminando() -> void:
	# Arrange & Act
	var ratona: Node3D = SCENE_RATONA.instantiate()
	add_child_autofree(ratona)

	# Assert
	assert_eq(ratona.call("obtener_estado"), SCRIPT_RATONA.Estado.CAMINANDO, "El estado inicial debe ser CAMINANDO")
	var ap: AnimationPlayer = ratona.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	assert_not_null(ap, "Debe tener un AnimationPlayer")
	assert_eq(ap.current_animation, "caminar", "La animacion inicial debe ser 'caminar'")
	var clip: Animation = ap.get_animation("caminar")
	assert_eq(clip.loop_mode, Animation.LOOP_LINEAR, "La animacion de caminata debe estar en loop lineal")


func test_material_y_textura_ratona_asignados() -> void:
	# Arrange & Act
	var ratona: Node3D = SCENE_RATONA.instantiate()
	add_child_autofree(ratona)

	# Assert
	var meshes: Array[Node] = ratona.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0, "Debe existir al menos una malla para Ratona Herrera")
	var mesh_ratona: MeshInstance3D = meshes[0] as MeshInstance3D
	assert_not_null(mesh_ratona.material_override, "La malla debe tener material_override")
	var mat := mesh_ratona.material_override as StandardMaterial3D
	assert_not_null(mat.albedo_texture, "El material debe tener textura albedo")
	assert_true(mat.albedo_texture.resource_path.ends_with("ratona herrera_D.jpg"), "La textura debe ser ratona herrera_D.jpg")


func test_configuracion_direccion_inicial_izquierda() -> void:
	# Arrange & Act
	var ratona: Node3D = SCENE_RATONA.instantiate()
	ratona.set("direccion_inicial", SCRIPT_RATONA.Direccion.IZQUIERDA)
	ratona.set("velocidad_caminar", 2.0)
	ratona.set("distancia_recorrido", 10.0)
	add_child_autofree(ratona)

	# Assert
	assert_eq(ratona.call("obtener_direccion"), -1.0, "La direccion inicial configurada como IZQUIERDA debe ser -1.0")
	var pivot: Node3D = ratona.get_node_or_null("Pivot")
	assert_not_null(pivot, "Debe existir el nodo Pivot")
	assert_almost_eq(pivot.rotation_degrees.y, -90.0, 1.0, "El Pivot debe orientarse a -90 grados (mirando a la izquierda)")

	# Act — avanzar 1s
	var x_inicial: float = ratona.position.x
	ratona._process(1.0)

	# Assert — debe caminar hacia la izquierda (X decrece)
	assert_almost_eq(ratona.position.x, x_inicial - 2.0, 0.05, "Debe avanzar en direccion negativa (-X) hacia la izquierda")


func test_desplazamiento_horizontal_al_caminar() -> void:
	# Arrange
	var ratona: Node3D = SCENE_RATONA.instantiate()
	ratona.set("velocidad_caminar", 2.0)
	ratona.set("distancia_recorrido", 10.0)
	add_child_autofree(ratona)
	var x_inicial: float = ratona.position.x

	# Act — avanzar 1 segundo a 2.0 m/s
	ratona._process(1.0)

	# Assert
	assert_almost_eq(ratona.position.x, x_inicial + 2.0, 0.05, "La posicion X debe avanzar segun velocidad * delta")
	assert_almost_eq(ratona.call("obtener_distancia_acumulada"), 2.0, 0.05, "La distancia acumulada debe registrar 2.0m")


func test_transicion_a_giro_al_alcanzar_distancia() -> void:
	# Arrange
	var ratona: Node3D = SCENE_RATONA.instantiate()
	ratona.call("configurar_patrulla", 2.0, 2.0)
	add_child_autofree(ratona)

	# Act — simular avance suficiente para alcanzar el limite
	ratona._process(1.2)

	# Assert
	assert_eq(ratona.call("obtener_estado"), SCRIPT_RATONA.Estado.GIRANDO, "Al alcanzar la distancia debe transicionar a GIRANDO")
	var ap: AnimationPlayer = ratona.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	assert_eq(ap.current_animation, "caminar", "La animacion debe mantenerse 'caminar' durante el giro")


func test_inversion_de_sentido_al_terminar_giro() -> void:
	# Arrange
	var ratona: Node3D = SCENE_RATONA.instantiate()
	ratona.set("tiempo_giro", 0.5)
	add_child_autofree(ratona)
	assert_eq(ratona.call("obtener_direccion"), 1.0, "Direccion inicial debe ser +1.0")
	ratona.call("iniciar_giro")
	assert_eq(ratona.call("obtener_estado"), SCRIPT_RATONA.Estado.GIRANDO)

	# Act — simular finalizacion del tiempo de giro (0.5s)
	ratona._process(0.6)

	# Assert
	assert_eq(ratona.call("obtener_estado"), SCRIPT_RATONA.Estado.CAMINANDO, "Debe volver a CAMINANDO tras el giro")
	assert_eq(ratona.call("obtener_direccion"), -1.0, "La direccion debe invertirse a -1.0")
	var ap: AnimationPlayer = ratona.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	assert_eq(ap.current_animation, "caminar", "La animacion debe mantenerse continua en 'caminar'")


func test_rotacion_continua_pivot_durante_giro() -> void:
	# Arrange
	var ratona: Node3D = SCENE_RATONA.instantiate()
	ratona.set("tiempo_giro", 0.8)
	add_child_autofree(ratona)
	var pivot: Node3D = ratona.get_node("Pivot")
	assert_almost_eq(pivot.rotation_degrees.y, 90.0, 0.1, "Pivot inicial en 90 deg")

	# Act — iniciar giro y avanzar la mitad del tiempo de giro
	ratona.call("iniciar_giro")
	ratona._process(0.4)

	# Assert — el Pivot debe haber rotado suavemente a mitad de camino entre 90 y 270 grados
	var rot_media: float = pivot.rotation_degrees.y
	assert_gt(rot_media, 90.0, "El pivot debe rotar continuamente durante el giro")
	assert_lt(rot_media, 270.0, "El pivot a mitad del giro debe estar entre 90 y 270 deg")
	assert_almost_eq(rot_media, 180.0, 15.0, "A mitad del giro el angulo debe aproximarse a 180 deg")


func test_desaceleracion_suave_al_aproximarse_al_limite() -> void:
	# Arrange
	var ratona: Node3D = SCENE_RATONA.instantiate()
	ratona.set("distancia_recorrido", 4.0)
	ratona.set("distancia_desaceleracion", 1.0)
	ratona.set("velocidad_caminar", 2.0)
	add_child_autofree(ratona)

	# Act — avanzar primero a fase crucero
	for i in range(25):
		ratona._process(0.05)
	var vel_crucero: float = ratona.call("obtener_velocidad_actual")

	# Avanzamos hasta cerca del limite (3.7m)
	for i in range(25):
		ratona._process(0.05)
	var vel_frenado: float = ratona.call("obtener_velocidad_actual")

	# Assert
	assert_gt(vel_crucero, vel_frenado, "La velocidad debe desacelerar al acercarse al limite")
	assert_gt(vel_frenado, 0.0, "La velocidad de frenado debe mantenerse positiva antes del giro")


func test_modo_estatico_animaciones_desactivadas_ejecuta_idle_herrera() -> void:
	# Arrange
	var ratona: Node3D = SCENE_RATONA.instantiate()
	ratona.set("velocidad_caminar", 2.0)
	ratona.set("distancia_recorrido", 6.0)
	add_child_autofree(ratona)
	var x_inicial: float = ratona.position.x

	# Act
	ratona.call("desactivar_animaciones")

	# Assert
	assert_true(ratona.call("esta_estatico"), "Debe reportar que está estático / animaciones desactivadas")
	assert_eq(ratona.call("obtener_estado"), SCRIPT_RATONA.Estado.ESTATICO, "El estado debe ser ESTATICO")
	var ap: AnimationPlayer = ratona.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	assert_true(ap.is_playing(), "El AnimationPlayer debe estar reproduciendo la animacion")
	assert_eq(ap.current_animation, "Idle herrera", "Debe ejecutar 'Idle herrera' por defecto cuando las animaciones estan desactivadas")
	var clip: Animation = ap.get_animation("Idle herrera")
	assert_eq(clip.loop_mode, Animation.LOOP_LINEAR, "'Idle herrera' debe configurarse en loop lineal")

	# Act: Avanzar frames en modo estático
	for i in range(30):
		ratona._process(0.016)

	# Assert: La posición horizontal no debe haber cambiado
	assert_almost_eq(ratona.position.x, x_inicial, 0.001, "En modo estático la posición X no debe variar")
	assert_eq(ratona.call("obtener_estado"), SCRIPT_RATONA.Estado.ESTATICO, "Debe mantenerse en estado ESTATICO")
	assert_eq(ap.current_animation, "Idle herrera", "Debe seguir ejecutando 'Idle herrera'")


func test_instanciacion_inicial_estatica_reproduce_idle_herrera() -> void:
	# Arrange: Configurado como estático desde el inicio (e.g. desde el editor de escenas)
	var ratona: Node3D = SCENE_RATONA.instantiate()
	ratona.set("estatico", true)

	# Act
	add_child_autofree(ratona)

	# Assert
	assert_true(ratona.call("esta_estatico"), "Debe iniciar en modo estático")
	assert_eq(ratona.call("obtener_estado"), SCRIPT_RATONA.Estado.ESTATICO, "Estado inicial debe ser ESTATICO")
	var ap: AnimationPlayer = ratona.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	assert_eq(ap.current_animation, "Idle herrera", "Al iniciar estatico debe reproducir 'Idle herrera' inmediatamente")


func test_reanudar_restaura_caminata() -> void:
	# Arrange
	var ratona: Node3D = SCENE_RATONA.instantiate()
	ratona.set("estatico", true)
	add_child_autofree(ratona)
	ratona._process(0.5)

	# Act
	ratona.call("activar_animaciones")

	# Assert
	assert_false(ratona.call("esta_estatico"), "Al reanudar no debe estar estático")
	assert_eq(ratona.call("obtener_estado"), SCRIPT_RATONA.Estado.CAMINANDO, "Debe volver al estado CAMINANDO")
	var ap: AnimationPlayer = ratona.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	assert_eq(ap.current_animation, "caminar", "Debe volver a la animacion de caminata")
	assert_true(ap.is_playing(), "El AnimationPlayer debe estar activo")


func test_configurar_patrulla_limites() -> void:
	# Arrange
	var ratona: Node3D = SCENE_RATONA.instantiate()
	add_child_autofree(ratona)

	# Act: Intentar pasar valores inválidos o bajo el límite
	ratona.call("configurar_patrulla", -5.0, -1.0)

	# Assert: Debe clampear a valores mínimos válidos
	assert_almost_eq(ratona.get("distancia_recorrido"), 0.5, 0.001, "La distancia minima debe ser 0.5m")
	assert_almost_eq(ratona.get("velocidad_caminar"), 0.1, 0.001, "La velocidad minima debe ser 0.1 m/s")


func test_ratona_herrera_en_nivel_pueblo() -> void:
	# Arrange
	var scene: PackedScene = load("res://Levels/Nivel_Pueblo/NivelPueblo.tscn")
	assert_not_null(scene, "La escena NivelPueblo debe cargar")

	# Act
	var nivel: Node = scene.instantiate()
	add_child_autofree(nivel)
	var ratona: Node = nivel.find_child("RatonaHerrera", true, false)

	# Assert
	assert_not_null(ratona, "RatonaHerrera debe existir en NivelPueblo.tscn")
	assert_true(ratona.get("estatico"), "RatonaHerrera en el pueblo debe estar configurada en modo estatico")
	assert_true(ratona.call("esta_estatico"), "Debe reportar que esta estatica")
	var ap: AnimationPlayer = ratona.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	assert_not_null(ap, "Debe tener AnimationPlayer")
	assert_eq(ap.current_animation, "Idle herrera", "En el pueblo debe ejecutar su animacion 'Idle herrera' por defecto")


func test_posar_360_grados() -> void:
	# Arrange
	var ratona: Node3D = SCENE_RATONA.instantiate()
	add_child_autofree(ratona)
	var pivot: Node3D = ratona.get_node("Pivot")
	assert_not_null(pivot, "Debe existir el nodo Pivot")

	# Act: Posar a 45 grados (diagonal frente-derecha)
	ratona.call("posar", 45.0)

	# Assert
	assert_true(ratona.get("posar_360"), "posar_360 debe estar activo")
	assert_almost_eq(ratona.call("obtener_angulo_posado"), 45.0, 0.1, "El angulo posado debe ser 45 grados")
	assert_almost_eq(pivot.rotation_degrees.y, 45.0, 0.1, "El Pivot debe orientarse a 45 grados")

	# Act: Cambiar angulo directamente desde propiedad posar_angulo a 180 grados (espalda)
	ratona.set("posar_angulo", 180.0)

	# Assert
	assert_almost_eq(pivot.rotation_degrees.y, 180.0, 0.1, "El Pivot debe orientarse a 180 grados")

	# Act: Probar wrap de angulo mayor a 360 (ej. 390 -> 30)
	ratona.set("posar_angulo", 390.0)
	assert_almost_eq(pivot.rotation_degrees.y, 30.0, 0.1, "El Pivot debe normalizar 390° a 30°")

	# Act: Desactivar posado 360 debe restaurar orientacion normal
	ratona.set("posar_360", false)
	assert_almost_eq(pivot.rotation_degrees.y, 90.0, 0.1, "Al desactivar posado 360 debe volver al angulo estandar 90°")


func test_velocidad_anim_idle_ralentizada() -> void:
	# Arrange & Act
	var ratona: Node3D = SCENE_RATONA.instantiate()
	ratona.set("estatico", true)
	add_child_autofree(ratona)

	var ap: AnimationPlayer = ratona.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	assert_not_null(ap, "Debe tener AnimationPlayer")

	# Assert: La velocidad por defecto de Idle debe ser 0.6 (ralentizada)
	assert_almost_eq(ratona.get("velocidad_anim_idle"), 0.6, 0.01, "La velocidad_anim_idle por defecto debe ser 0.6")
	assert_almost_eq(ap.speed_scale, 0.6, 0.01, "El speed_scale del AnimationPlayer en Idle debe ser 0.6")

	# Act: Modificar velocidad de idle
	ratona.set("velocidad_anim_idle", 0.4)

	# Assert
	assert_almost_eq(ap.speed_scale, 0.4, 0.01, "El speed_scale debe actualizarse a 0.4")


func test_linea_2d_activa_por_defecto() -> void:
	# Arrange & Act
	var ratona: Node3D = SCENE_RATONA.instantiate()
	add_child_autofree(ratona)

	# Assert
	assert_false(ratona.get("sin_linea_negra"), "sin_linea_negra debe ser false por defecto")
	assert_true(ratona.call("tiene_linea_2d"), "La linea 2D debe estar activa por defecto")
	var meshes: Array[Node] = ratona.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0, "Debe tener mallas")
	var mi := meshes[0] as MeshInstance3D
	assert_true(mi.is_in_group("outline_meshes"), "La malla debe pertenecer al grupo outline_meshes")
	assert_not_null(mi.material_override, "La malla debe tener material asignado")
	var mat := mi.material_override as StandardMaterial3D
	assert_not_null(mat.next_pass, "El material debe tener next_pass para el contorno linea 2D")
	var sm := mat.next_pass as ShaderMaterial
	assert_not_null(sm.shader, "El next_pass debe tener asignado el shader de linea 2d")
	assert_true(sm.shader.resource_path.ends_with("TOON_LINEANEGRA.gdshader"), "El shader debe ser TOON_LINEANEGRA.gdshader")


func test_desactivar_y_reactivar_linea_2d() -> void:
	# Arrange
	var ratona: Node3D = SCENE_RATONA.instantiate()
	add_child_autofree(ratona)

	# Act: Desactivar linea 2D
	ratona.call("configurar_linea_2d", false)

	# Assert
	assert_true(ratona.get("sin_linea_negra"), "sin_linea_negra debe ser true tras desactivarla")
	assert_false(ratona.call("tiene_linea_2d"), "tiene_linea_2d debe retornar false")
	var meshes: Array[Node] = ratona.find_children("*", "MeshInstance3D", true, false)
	var mi := meshes[0] as MeshInstance3D
	assert_false(mi.is_in_group("outline_meshes"), "La malla no debe estar en outline_meshes al quitar la linea 2D")
	var mat_sin := mi.material_override as StandardMaterial3D
	assert_null(mat_sin.next_pass, "El material no debe tener next_pass de contorno")

	# Act: Reactivar linea 2D
	ratona.call("configurar_linea_2d", true)

	# Assert
	assert_false(ratona.get("sin_linea_negra"), "sin_linea_negra debe ser false al reactivarla")
	assert_true(ratona.call("tiene_linea_2d"), "tiene_linea_2d debe retornar true")
	assert_true(mi.is_in_group("outline_meshes"), "La malla debe volver al grupo outline_meshes")
	var mat_con := mi.material_override as StandardMaterial3D
	assert_not_null(mat_con.next_pass, "El material debe recuperar el next_pass de linea 2D")



