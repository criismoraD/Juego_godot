extends "res://addons/gut/test.gd"

## Tests unitarios para GatetaMercader
## Verifica la lógica de estados de animación, temporizador de transición,
## crossfade suave (blend times) y asignación de texturas.

const SCRIPT_GATETA: GDScript = preload("res://Entities/NPC_GatetaMercader/GatetaMercader.gd")
const SCENE_GATETA: PackedScene = preload("res://Entities/NPC_GatetaMercader/GatetaMercader.tscn")

func test_inicializacion_en_idle():
	# Arrange & Act
	var npc: Node3D = SCENE_GATETA.instantiate()
	add_child_autofree(npc)
	
	# Assert
	assert_eq(npc.obtener_estado(), SCRIPT_GATETA.Estado.IDLE, "El estado inicial debe ser IDLE")
	var ap: AnimationPlayer = npc.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	assert_not_null(ap, "Debe tener un AnimationPlayer")
	assert_eq(ap.current_animation, "Idle", "La animacion inicial debe ser 'Idle'")
	var clip: Animation = ap.get_animation("Idle")
	assert_eq(clip.loop_mode, Animation.LOOP_LINEAR, "La animacion Idle debe estar configurada en loop lineal")


func test_material_y_textura_asignados():
	# Arrange & Act
	var npc: Node3D = SCENE_GATETA.instantiate()
	add_child_autofree(npc)
	
	# Assert
	var meshes: Array[Node] = npc.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0, "Debe tener al menos una MeshInstance3D")
	for m in meshes:
		var mi := m as MeshInstance3D
		assert_not_null(mi.material_override, "Debe tener material_override")
		var mat := mi.material_override as StandardMaterial3D
		assert_not_null(mat, "El material debe ser StandardMaterial3D")
		assert_not_null(mat.albedo_texture, "Debe tener albedo_texture")
		assert_true(mat.albedo_texture.resource_path.ends_with("gateta mercader_D.jpg"), "La textura debe ser gateta mercader_D.jpg")


func test_tiempo_programado_entre_20_y_25_segundos():
	# Arrange & Act
	var npc: Node3D = SCENE_GATETA.instantiate()
	add_child_autofree(npc)
	
	# Assert
	var t: float = npc.obtener_tiempo_para_cambio()
	assert_gte(t, 20.0, "El tiempo de cambio debe ser >= 20 segundos")
	assert_lte(t, 25.0, "El tiempo de cambio debe ser <= 25 segundos")


func test_transicion_suave_configurada():
	# Arrange & Act
	var npc: Node3D = SCENE_GATETA.instantiate()
	add_child_autofree(npc)
	
	# Assert
	var blend: float = npc.obtener_tiempo_transicion()
	assert_gt(blend, 0.2, "El tiempo de transicion suave debe ser significativo (> 0.2s) para no verse brusco")
	var ap: AnimationPlayer = npc.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	assert_almost_eq(ap.get_blend_time(&"Idle", &"Dwarf Idle"), blend, 0.01, "Blend de Idle a Dwarf Idle debe coincidir")
	assert_almost_eq(ap.get_blend_time(&"Dwarf Idle", &"Idle"), blend, 0.01, "Blend de Dwarf Idle a Idle debe coincidir")


func test_transicion_a_dwarf_al_cumplir_tiempo():
	# Arrange
	var npc: Node3D = SCENE_GATETA.instantiate()
	npc.configurar_intervalo(0.1, 0.2)
	add_child_autofree(npc)
	
	# Act
	npc._process(0.25)
	
	# Assert
	assert_eq(npc.obtener_estado(), SCRIPT_GATETA.Estado.DWARF, "Debe transicionar a DWARF tras cumplirse el tiempo")
	var ap: AnimationPlayer = npc.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	assert_eq(ap.current_animation, "Dwarf Idle", "La animacion activa debe ser 'Dwarf Idle'")


func test_retorno_suave_a_idle_antes_del_corte_de_dwarf():
	# Arrange
	var npc: Node3D = SCENE_GATETA.instantiate()
	add_child_autofree(npc)
	npc.reproducir_dwarf()
	assert_eq(npc.obtener_estado(), SCRIPT_GATETA.Estado.DWARF)
	
	# Act — avanzar tiempo hasta la ventana de anticipación del crossfade
	# duración ~7.03s, transición ~0.75s -> retorno se dispara a ~6.28s
	npc._process(6.35)
	
	# Assert
	assert_eq(npc.obtener_estado(), SCRIPT_GATETA.Estado.IDLE, "Debe iniciar el retorno suave a IDLE antes de que corte el clip")
	var ap: AnimationPlayer = npc.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	assert_eq(ap.current_animation, "Idle", "La animacion debe volver a 'Idle'")


func test_gateta_mercader_en_nivel_pueblo():
	# Arrange
	var scene: PackedScene = load("res://Levels/Nivel_Pueblo/NivelPueblo.tscn")
	assert_not_null(scene, "La escena NivelPueblo debe cargar")
	
	# Act
	var nivel: Node = scene.instantiate()
	add_child_autofree(nivel)
	var npc: Node = nivel.find_child("GatetaMercader", true, false)
	
	# Assert
	assert_not_null(npc, "GatetaMercader debe existir en NivelPueblo.tscn")
	var meshes: Array[Node] = npc.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0, "GatetaMercader en NivelPueblo debe tener mallas")
	for m in meshes:
		var mi := m as MeshInstance3D
		assert_not_null(mi.material_override, "Las mallas deben tener material_override con textura")
