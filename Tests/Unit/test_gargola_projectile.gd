extends GutTest

const GARGOLA_PROJECTILE_SCENE: PackedScene = preload("res://Entities/Projectiles/GargolaProjectile.tscn")

var scene_root: Node3D


func before_each() -> void:
	scene_root = Node3D.new()
	add_child(scene_root)


func after_each() -> void:
	if is_instance_valid(scene_root):
		scene_root.queue_free()
	await get_tree().process_frame


func test_preparar_visuales_crea_vfx_sin_material_rojo() -> void:
	# Arrange
	var projectile := GARGOLA_PROJECTILE_SCENE.instantiate()

	# Act
	projectile._preparar_visuales()

	# Assert: el VFX FireBall existe como hijo del proyectil
	var vfx: Node = projectile._vfx_fireball
	assert_not_null(vfx, "Debe instanciar el VFX_Fire_ball_standar.tscn")
	assert_true(vfx is Node3D, "El VFX debe ser un Node3D")
	assert_eq(vfx.name, "VFX_FireBall", "El nodo raiz del VFX debe llamarse VFX_FireBall")

	# El proyectil NO usa el material rojo toon compartido del base
	assert_null(projectile.projectile_material, "GargolaProjectile no debe crear material rojo toon")

	# Skeleton paths del showcase no deben romper el render bajo el proyectil
	for mesh_node in vfx.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		if not is_instance_valid(mesh_instance):
			continue
		assert_eq(
			mesh_instance.skeleton,
			NodePath(),
			"Los meshes del VFX no deben apuntar a skeleton del showcase"
		)

	projectile.queue_free()
	await get_tree().process_frame


func test_impacto_superficie_no_se_pega() -> void:
	# Arrange
	var projectile := GARGOLA_PROJECTILE_SCENE.instantiate() as GargolaProjectile
	scene_root.add_child(projectile)
	await get_tree().process_frame
	projectile.is_stuck = false
	projectile.monitoring = true
	projectile.set_physics_process(true)

	var muro := StaticBody3D.new()
	muro.name = "MuroTest"
	scene_root.add_child(muro)

	# Act
	projectile._on_body_entered(muro)
	await get_tree().process_frame

	# Assert
	assert_false(projectile.is_stuck, "La bola de fuego no debe quedarse pegada a superficies")
	assert_true(
		projectile._destroying or not projectile.visible,
		"Debe destruirse o ocultarse al impactar en superficie"
	)

	if is_instance_valid(projectile):
		projectile.queue_free()
	muro.queue_free()
	await get_tree().process_frame


func test_impacto_escudo_no_se_pega() -> void:
	# Arrange
	var projectile := GARGOLA_PROJECTILE_SCENE.instantiate() as GargolaProjectile
	scene_root.add_child(projectile)
	await get_tree().process_frame
	projectile.is_stuck = false

	var escudo := StaticBody3D.new()
	escudo.name = "EscudoTest"
	scene_root.add_child(escudo)

	# Act
	projectile._on_impacto_con_escudo(escudo)
	projectile._stick_to_shield(escudo)
	await get_tree().process_frame

	# Assert
	assert_false(projectile.is_stuck, "La bola de fuego no debe pegarse al escudo")
	assert_true(
		projectile._destroying or not projectile.visible,
		"Debe destruirse al impactar en escudo"
	)

	if is_instance_valid(projectile):
		projectile.queue_free()
	if is_instance_valid(escudo):
		escudo.queue_free()
	await get_tree().process_frame


func test_sonidos_y_escala_configurados() -> void:
	assert_eq(String(GargolaProjectile.SFX_FUEGO), "gargola_fire")
	assert_eq(String(GargolaProjectile.SFX_IMPACTO), "gargola_impacto")
	assert_eq(GargolaProjectile.VFX_LOCAL_SCALE, 0.375)
	assert_almost_eq(GargolaProjectile.BOOST_VOLUMEN_X3_DB, 9.5, 0.01)


func test_cache_meshes_excluye_vfx_tras_ready() -> void:
	# Arrange: simula prop en BoneAttachment (defensa en profundidad del cache)
	var attachment := BoneAttachment3D.new()
	attachment.name = "AttachmentCarga"
	scene_root.add_child(attachment)
	await get_tree().process_frame

	# Act
	var projectile := GARGOLA_PROJECTILE_SCENE.instantiate()
	attachment.add_child(projectile)
	await get_tree().process_frame

	# Assert: comportamiento de "en la mano"
	assert_false(projectile.monitoring, "En la mano no debe detectar colisiones")
	assert_false(projectile.is_physics_processing(), "En la mano no debe procesar física")
	assert_false(projectile.visible, "En la mano inicia oculto")

	var vfx: Node = projectile._vfx_fireball
	assert_not_null(vfx, "El VFX debe haberse creado")
	var meshes_vfx := {}
	for mesh_vfx in vfx.find_children("*", "MeshInstance3D", true, false):
		meshes_vfx[mesh_vfx] = true

	for mesh_cacheado in projectile._cached_mesh_instances:
		assert_false(
			meshes_vfx.has(mesh_cacheado),
			"Ningun mesh del VFX debe quedar en _cached_mesh_instances"
		)

	projectile.queue_free()
	await get_tree().process_frame
