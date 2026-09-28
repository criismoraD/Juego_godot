extends "res://addons/gut/test.gd"

## Test unitario y de integración para PirataGoblinNPC:
## Verifica la instanciación con el modelo PirataGoblin.glb, aplicación de material,
## uso exclusivo de la animación 'Strut Walking', ciclo de patrulla ida y vuelta con giro suave de 180°
## y presencia en la escena NivelPueblo.

const SCRIPT_PIRATA: GDScript = preload("res://Entities/NPC_PirataGoblin/PirataGoblinNPC.gd")
const SCENE_PIRATA: PackedScene = preload("res://Entities/NPC_PirataGoblin/PirataGoblinNPC.tscn")
const MATERIAL_PIRATA: Material = preload("res://Entities/Enemigo_Pirata_Goblin/MAT_PIRATA_GOBLIN.tres")

func test_pirata_goblin_npc_instancia_correctamente():
	# Arrange & Act
	var npc: Node3D = SCENE_PIRATA.instantiate() as Node3D
	add_child_autofree(npc)

	# Assert
	assert_not_null(npc, "PirataGoblinNPC debe instanciarse")
	assert_not_null(npc.get("material_npc"), "Debe tener asignado material_npc")
	assert_eq(npc.get("capa_visual"), 1, "La capa visual por defecto debe ser 1")

	var skel: Skeleton3D = npc.call("_obtener_skeleton") as Skeleton3D
	assert_not_null(skel, "Debe contener un Skeleton3D")

	var meshes: Array[Node] = npc.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0, "Debe contener al menos una MeshInstance3D")
	for m in meshes:
		var mi := m as MeshInstance3D
		assert_eq(mi.material_override, npc.get("material_npc"), "Las mallas deben tener aplicado el material del pirata goblin")


func test_pirata_goblin_solo_camina_con_strut_walking():
	# Arrange
	var npc: Node3D = SCENE_PIRATA.instantiate() as Node3D
	add_child_autofree(npc)

	var ap: AnimationPlayer = npc.call("_obtener_animation_player") as AnimationPlayer
	assert_not_null(ap, "Debe existir un AnimationPlayer en la jerarquía del modelo")
	assert_true(ap.has_animation("Strut Walking"), "El modelo debe contener la animación 'Strut Walking'")

	# Act
	npc.call("iniciar_caminata")

	# Assert
	assert_eq(npc.get("anim_caminar"), &"Strut Walking", "La animación de caminata configurada debe ser 'Strut Walking'")
	assert_eq(ap.current_animation, "Strut Walking", "El AnimationPlayer debe estar reproduciendo 'Strut Walking'")
	var clip: Animation = ap.get_animation("Strut Walking")
	assert_eq(clip.loop_mode, Animation.LOOP_LINEAR, "'Strut Walking' debe estar en modo LOOP_LINEAR")


func test_patrulla_caminata_y_giro_180_grados():
	# Arrange
	var npc: Node3D = SCENE_PIRATA.instantiate() as Node3D
	npc.set("direccion_inicial", SCRIPT_PIRATA.Direccion.DERECHA)
	npc.call("configurar_patrulla", 2.0, 1.0)
	npc.set("tiempo_giro", 0.5)
	npc.set("distancia_desaceleracion", 0.2)
	npc.set("tiempo_aceleracion", 0.2)
	add_child_autofree(npc)

	var x_inicial: float = npc.position.x
	assert_eq(npc.call("obtener_estado"), SCRIPT_PIRATA.Estado.CAMINANDO)
	assert_eq(npc.call("obtener_direccion"), 1.0)

	# Act - caminar 1 segundo (avance a la derecha)
	npc._process(1.0)
	assert_gt(npc.position.x, x_inicial, "Debe avanzar en dirección positiva X hacia la derecha")
	assert_gt(npc.call("obtener_distancia_acumulada"), 0.0)

	# Act - avanzar hasta alcanzar el límite del recorrido (2.0 metros)
	npc._process(1.5)
	assert_eq(npc.call("obtener_estado"), SCRIPT_PIRATA.Estado.GIRANDO, "Al alcanzar el límite debe entrar en estado GIRANDO")

	# Act - completar el tiempo de giro (0.5 segundos)
	npc._process(0.6)
	assert_eq(npc.call("obtener_estado"), SCRIPT_PIRATA.Estado.CAMINANDO, "Tras completar el tiempo de giro debe volver a CAMINANDO")
	assert_eq(npc.call("obtener_direccion"), -1.0, "La dirección debe haberse invertido a la izquierda (-1.0)")

	# Act - caminar hacia la izquierda
	var x_tras_giro: float = npc.position.x
	npc._process(1.0)
	assert_lt(npc.position.x, x_tras_giro, "Debe avanzar en dirección negativa X hacia la izquierda")


func test_pirata_goblin_presente_en_nivel_pueblo():
	# Arrange
	var scene: PackedScene = load("res://Levels/Nivel_Pueblo/NivelPueblo.tscn")
	assert_not_null(scene, "La escena NivelPueblo debe existir")

	# Act
	var nivel: Node = scene.instantiate()
	add_child_autofree(nivel)

	# Assert
	var pirata: Node = nivel.find_child("*PirataGoblin*", true, false)
	assert_not_null(pirata, "Debe existir un nodo 'PirataGoblin' en NivelPueblo")
	assert_gt(pirata.get("distancia_recorrido"), 0.0, "distancia_recorrido configurada debe ser mayor a 0")
	assert_eq(pirata.get("anim_caminar"), &"Strut Walking", "Debe usar 'Strut Walking'")
