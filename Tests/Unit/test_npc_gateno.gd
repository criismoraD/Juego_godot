extends "res://addons/gut/test.gd"

## Tests unitarios para Gateno
## Verifica la funcionalidad idéntica a OrcoCerdo:
## - Patrulla (caminata y giro suave de 180° del Pivot manteniendo 'Caminar')
## - Modo estático con animaciones, siendo 'Entrenamiento' la pose por defecto
## - Katana acoplada en la mano derecha (mixamorig_RightHand)
## - Materiales y texturas toon specular
## - Poses y posado 360°

const SCRIPT_GATENO: GDScript = preload("res://Entities/NPC_Gateno/Gateno.gd")
const SCENE_GATENO: PackedScene = preload("res://Entities/NPC_Gateno/Gateno.tscn")
const SCENE_KATANA: PackedScene = preload("res://Entities/NPC_Gateno/Katana.tscn")


func test_inicializacion_en_caminando():
	# Arrange & Act
	var gateno: Node3D = SCENE_GATENO.instantiate()
	add_child_autofree(gateno)

	# Assert
	assert_eq(gateno.call("obtener_estado"), SCRIPT_GATENO.Estado.CAMINANDO, "El estado inicial debe ser CAMINANDO cuando estatico=false")
	var ap: AnimationPlayer = gateno.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	assert_not_null(ap, "Debe tener un AnimationPlayer")
	assert_eq(ap.current_animation, "Caminar", "La animacion inicial de patrulla debe ser 'Caminar'")
	var clip: Animation = ap.get_animation("Caminar")
	assert_eq(clip.loop_mode, Animation.LOOP_LINEAR, "La animacion de caminata debe estar en loop lineal")


func test_modo_estatico_pose_por_defecto_es_entrenamiento():
	# Arrange
	var gateno: Node3D = SCENE_GATENO.instantiate()
	gateno.set("estatico", true)
	add_child_autofree(gateno)

	# Assert
	assert_eq(gateno.call("obtener_estado"), SCRIPT_GATENO.Estado.ESTATICO, "El estado debe ser ESTATICO")
	assert_true(gateno.call("esta_estatico"), "esta_estatico() debe retornar true")
	assert_eq(gateno.call("obtener_pose_estatica"), "Entrenamiento", "La pose estática por defecto debe ser 'Entrenamiento'")
	var ap: AnimationPlayer = gateno.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	assert_not_null(ap, "Debe tener un AnimationPlayer")
	assert_eq(ap.current_animation, "Entrenamiento", "La animación activa en estático debe ser 'Entrenamiento'")
	var clip: Animation = ap.get_animation("Entrenamiento")
	assert_eq(clip.loop_mode, Animation.LOOP_LINEAR, "La animacion de entrenamiento debe estar en loop lineal")


func test_cambio_de_poses_estaticas_desde_lista():
	# Arrange
	var gateno: Node3D = SCENE_GATENO.instantiate()
	gateno.set("estatico", true)
	add_child_autofree(gateno)
	var ap: AnimationPlayer = gateno.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer

	# Act & Assert - Probar cambio a Idle
	gateno.call("cambiar_pose_estatica", "Idle")
	assert_eq(gateno.call("obtener_pose_estatica"), "Idle")
	assert_eq(ap.current_animation, "Idle")

	# Act & Assert - Probar cambio a Victoria
	gateno.call("cambiar_pose_estatica", "Victoria")
	assert_eq(gateno.call("obtener_pose_estatica"), "Victoria")
	assert_eq(ap.current_animation, "Victoria")

	# Act & Assert - Volver a Entrenamiento
	gateno.call("cambiar_pose_estatica", "Entrenamiento")
	assert_eq(gateno.call("obtener_pose_estatica"), "Entrenamiento")
	assert_eq(ap.current_animation, "Entrenamiento")


func test_katana_equipada_en_mano_derecha():
	# Arrange & Act
	var gateno: Node3D = SCENE_GATENO.instantiate()
	add_child_autofree(gateno)

	# Assert
	var katana: Node3D = gateno.call("obtener_katana") as Node3D
	assert_not_null(katana, "Debe existir la katana acoplada")
	var parent_node: Node = katana.get_parent()
	assert_true(parent_node is BoneAttachment3D, "El padre de la katana debe ser un BoneAttachment3D")
	var ba := parent_node as BoneAttachment3D
	assert_eq(ba.bone_name, "mixamorig_RightHand", "La katana debe estar acoplada en mixamorig_RightHand")

	# Verificar material y textura de la katana
	var meshes_katana: Array[Node] = katana.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes_katana.size(), 0, "La katana debe tener mallas")
	for m in meshes_katana:
		var mi := m as MeshInstance3D
		assert_not_null(mi.material_override, "La malla de la katana debe tener material_override")
		var mat := mi.material_override as StandardMaterial3D
		assert_not_null(mat.albedo_texture, "La katana debe tener textura")
		assert_true(mat.albedo_texture.resource_path.ends_with("kataana_D.jpg"), "La textura de la katana debe ser kataana_D.jpg")
		assert_eq(mat.specular_mode, BaseMaterial3D.SPECULAR_TOON, "La katana debe tener specular_mode TOON")


func test_material_y_textura_gateno_asignados():
	# Arrange & Act
	var gateno: Node3D = SCENE_GATENO.instantiate()
	add_child_autofree(gateno)

	# Assert
	var skel: Skeleton3D = gateno.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	assert_not_null(skel, "Debe existir el Skeleton3D")
	var mesh_gateno: MeshInstance3D = null
	for c in skel.get_children():
		if c is MeshInstance3D:
			mesh_gateno = c as MeshInstance3D
			break
	assert_not_null(mesh_gateno, "Debe existir la malla de Gateno")
	assert_not_null(mesh_gateno.material_override, "La malla de Gateno debe tener material_override")
	var mat := mesh_gateno.material_override as StandardMaterial3D
	assert_not_null(mat.albedo_texture, "Gateno debe tener textura")
	assert_true(mat.albedo_texture.resource_path.ends_with("gateno_D.jpg"), "La textura debe ser gateno_D.jpg")
	assert_eq(mat.specular_mode, BaseMaterial3D.SPECULAR_TOON, "Gateno debe tener specular_mode TOON")


func test_desplazamiento_horizontal_y_giro_patrulla():
	# Arrange
	var gateno: Node3D = SCENE_GATENO.instantiate()
	gateno.set("velocidad_caminar", 2.0)
	gateno.set("distancia_recorrido", 1.0)
	gateno.set("tiempo_giro", 0.5)
	add_child_autofree(gateno)
	var x_inicial: float = gateno.position.x

	# Act — avanzar hasta alcanzar el límite
	gateno._process(0.6)
	assert_gt(gateno.position.x, x_inicial, "Debe haber avanzado hacia la derecha (+X)")

	# Act — forzar giro
	gateno.call("iniciar_giro")
	assert_eq(gateno.call("obtener_estado"), SCRIPT_GATENO.Estado.GIRANDO)
	gateno._process(0.6)
	assert_eq(gateno.call("obtener_estado"), SCRIPT_GATENO.Estado.CAMINANDO, "Tras finalizar el giro debe volver a CAMINANDO")
	assert_eq(gateno.call("obtener_direccion"), -1.0, "La dirección tras el giro debe ser hacia la izquierda (-1.0)")


func test_posado_360_grados():
	# Arrange
	var gateno: Node3D = SCENE_GATENO.instantiate()
	add_child_autofree(gateno)

	# Act
	gateno.call("posar", 135.0)

	# Assert
	assert_almost_eq(gateno.call("obtener_angulo_posado"), 135.0, 0.5, "El ángulo de posado debe ser 135 grados")


func test_gateno_en_nivel_rio():
	# Arrange & Act: Verificar que la escena del nivel río contiene la plataforma o nodo de Gateno
	var file := FileAccess.open("res://Levels/Rio en canoa con paralax.tscn", FileAccess.READ)
	assert_not_null(file, "El archivo del nivel río debe poder leerse")
	var content := file.get_as_text()
	file.close()

	# Assert
	assert_true(content.contains("Gateno"), "El nivel río debe tener referencia a Gateno o PlataformaMaderosInicioGateno")


func test_gateno_en_nivel_pueblo():
	# Arrange & Act: Verificar que la escena del nivel pueblo contiene a Gateno configurado
	var file := FileAccess.open("res://Levels/Nivel_Pueblo/NivelPueblo.tscn", FileAccess.READ)
	assert_not_null(file, "El archivo del nivel pueblo debe poder leerse")
	var content := file.get_as_text()
	file.close()

	# Assert
	assert_true(content.contains("Entities/NPC_Gateno/GatenoNPC.tscn") or content.contains("Entities/NPC_Gateno/Gateno.tscn"), "El nivel pueblo debe tener el ExtResource de Gateno")
	assert_true(content.contains('[node name="GatenoNPC') or content.contains('[node name="Gateno'), "El nivel pueblo debe tener el nodo GatenoNPC instanciado")
	assert_true(content.contains("estatico = true"), "Gateno en el pueblo debe estar en modo estático")


func test_gateno_dialogo_lineas_configuradas():
	# Arrange & Act
	var gateno: Node3D = SCENE_GATENO.instantiate()
	add_child_autofree(gateno)

	# Assert
	assert_eq(gateno.get("lineas_dialogo").size(), 2, "Gateno debe tener 2 líneas de diálogo por defecto")
	assert_eq(gateno.get("lineas_dialogo")[0], "GATENO_PUEBLO_1", "Línea 1 debe ser clave de traducción")
	assert_eq(gateno.get("lineas_dialogo")[1], "GATENO_PUEBLO_2", "Línea 2 debe ser clave de traducción")
	assert_ne(tr("GATENO_PUEBLO_1"), "GATENO_PUEBLO_1", "GATENO_PUEBLO_1 debe resolverse en el locale activo")
	assert_ne(tr("GATENO_PUEBLO_2"), "GATENO_PUEBLO_2", "GATENO_PUEBLO_2 debe resolverse en el locale activo")


func test_gateno_deteccion_proximidad_y_tinte_morado():
	# Arrange
	var gateno: Node3D = SCENE_GATENO.instantiate()
	add_child_autofree(gateno)
	watch_signals(gateno)

	# Act: Simular entrada del jugador
	gateno.call("fijar_jugador_cerca", true)

	# Assert
	assert_signal_emitted_with_parameters(gateno, "proximidad_jugador_cambiada", [true])
	assert_true(gateno.call("esta_jugador_cerca"), "Debe registrar que el jugador está cerca")
	var prompt: Label3D = gateno.call("obtener_prompt_hablar") as Label3D
	assert_not_null(prompt, "Debe existir PromptHablar")
	assert_eq(prompt.text, "[E] " + tr("PERRENA_PROMPT_HABLAR"), "El prompt debe usar la clave traducida")

	var tinte: StandardMaterial3D = gateno.call("obtener_material_tinte") as StandardMaterial3D
	assert_not_null(tinte, "Debe haber configurado el material de tinte")
	assert_almost_eq(tinte.albedo_color.r, 0.78, 0.01, "El color de tinte debe ser morado")

	# Act 2: Salida del jugador
	gateno.call("fijar_jugador_cerca", false)
	assert_signal_emitted_with_parameters(gateno, "proximidad_jugador_cambiada", [false])
	assert_false(gateno.call("esta_jugador_cerca"), "Debe registrar que el jugador se alejó")


func test_gateno_flujo_dialogo_completo_dos_vinetas():
	# Arrange
	var gateno: Node3D = SCENE_GATENO.instantiate()
	add_child_autofree(gateno)
	watch_signals(gateno)
	gateno.call("fijar_jugador_cerca", true)

	# Act 1: Primer pulsado de E / interactuar
	gateno.call("interactuar")

	# Assert 1
	assert_true(gateno.call("esta_hablando_dialogo"), "Debe estar en modo diálogo activo")
	assert_eq(gateno.call("obtener_indice_dialogo"), 1, "Debe estar en la viñeta 1")
	assert_signal_emitted_with_parameters(gateno, "dialogo_iniciado", ["GATENO_PUEBLO_1"])

	# Act 2: Avanzar a viñeta 2
	gateno.call("interactuar")

	# Assert 2
	assert_true(gateno.call("esta_hablando_dialogo"), "Debe seguir en diálogo activo")
	assert_eq(gateno.call("obtener_indice_dialogo"), 2, "Debe estar en la viñeta 2")
	assert_signal_emitted_with_parameters(gateno, "dialogo_avanzado", [2, "GATENO_PUEBLO_2"])

	# Act 3: Cerrar diálogo
	gateno.call("interactuar")

	# Assert 3
	assert_false(gateno.call("esta_hablando_dialogo"), "El diálogo debe cerrarse")
	assert_eq(gateno.call("obtener_indice_dialogo"), 0, "El índice debe reiniciarse a 0")
	assert_signal_emitted(gateno, "dialogo_terminado")


func test_gateno_gira_de_frente_hacia_jugador_y_reproduce_idle():
	# Arrange: Gateno en modo estático con pose Entrenamiento y posar_angulo = 90° (mirando a la derecha)
	var gateno: Node3D = SCENE_GATENO.instantiate()
	gateno.set("estatico", true)
	gateno.set("pose_estatica", "Entrenamiento")
	gateno.call("posar", 90.0)
	add_child_autofree(gateno)

	var ap: AnimationPlayer = gateno.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	assert_eq(ap.current_animation, "Entrenamiento", "Antes de hablar debe estar en 'Entrenamiento'")
	assert_almost_eq(gateno.call("obtener_angulo_pivot"), 90.0, 0.1, "Antes de hablar debe estar en 90°")

	# Jugador ubicado exactamente al frente (+Z) de Gateno
	var dummy_jugador := Node3D.new()
	dummy_jugador.name = "Player"
	dummy_jugador.add_to_group("player")
	add_child_autofree(dummy_jugador)
	dummy_jugador.global_position = gateno.global_position + Vector3(0.0, 0.0, 2.0)

	gateno.call("fijar_jugador_cerca", true)

	# Act: Iniciar diálogo
	gateno.call("interactuar")

	# Assert: Debe girarse de frente hacia el jugador (0° en espacio local cuando el jugador está en +Z)
	gateno.call("orientar_hacia_jugador", false)
	assert_almost_eq(gateno.call("obtener_angulo_pivot"), 0.0, 0.5, "Al hablar debe girarse de frente hacia el jugador (0° hacia +Z)")
	assert_eq(ap.current_animation, "Idle", "Al hablar debe reproducir su animación de 'Idle'")

	# Act 2: Cerrar diálogo
	gateno.call("interactuar")  # viñeta 2
	assert_eq(ap.current_animation, "Idle", "Durante la viñeta 2 debe mantenerse en 'Idle'")
	gateno.call("interactuar")  # cerrar diálogo
	gateno.call("_restaurar_orientacion_estatica", false)

	# Assert 2: Al terminar, debe restaurar su pose estática 'Entrenamiento' y su ángulo original (90°)
	assert_eq(ap.current_animation, "Entrenamiento", "Al terminar diálogo debe restaurar su pose estática 'Entrenamiento'")
	assert_almost_eq(gateno.call("obtener_angulo_pivot"), 90.0, 0.5, "Al terminar diálogo debe restaurar su orientación previa (90°)")


func test_gateno_detiene_y_reanuda_dummy_boya_al_dialogar():
	# Arrange
	var gateno: Node3D = SCENE_GATENO.instantiate()
	add_child_autofree(gateno)

	var dummy_boya_escena: PackedScene = load("res://Entities/Ambiente_Dummy/Dummy.tscn")
	var dummy: DummyBoya = dummy_boya_escena.instantiate() as DummyBoya
	add_child_autofree(dummy)
	dummy.global_position = gateno.global_position + Vector3(1.0, 0.0, 0.0)

	assert_false(dummy.esta_detenido(), "El dummy no debe estar detenido antes de hablar")

	# Jugador cerca de Gateno
	gateno.call("fijar_jugador_cerca", true)

	# Act 1: Gateno inicia diálogo
	gateno.call("interactuar")

	# Assert 1: Dummy debe detenerse
	assert_true(gateno.call("esta_hablando_dialogo"), "Gateno debe estar en diálogo")
	assert_true(dummy.esta_detenido(), "El DummyBoya debe detenerse cuando Gateno comienza a hablar")

	# Act 2: Avanzar diálogo hasta terminar (viñeta 2 -> cerrar)
	gateno.call("interactuar")
	gateno.call("interactuar")

	# Assert 2: Al terminar de hablar, el DummyBoya debe reanudar su movimiento
	assert_false(gateno.call("esta_hablando_dialogo"), "El diálogo debe haberse cerrado")
	assert_false(dummy.esta_detenido(), "El DummyBoya debe reanudar su movimiento al terminar el diálogo")



