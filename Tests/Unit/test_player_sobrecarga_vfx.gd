extends "res://addons/gut/test.gd"

var PlayerScript = load("res://Entities/Jugador_Arquera/Player.gd")


func _crear_player() -> Player:
	var player: Player = PlayerScript.new()
	var anim_player := AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	player.add_child(anim_player)

	var anim_tree := AnimationTree.new()
	anim_tree.name = "AnimationTree"
	anim_tree.anim_player = NodePath("../AnimationPlayer")
	player.add_child(anim_tree)
	return player


func test_creacion_particulas_sobrecarga_propiedades():
	# Arrange
	var player: Player = autofree(_crear_player())

	# Act
	var particles: GPUParticles3D = player._create_sobrecarga_particles()
	autofree(particles)

	# Assert: Nodo y configuración general
	assert_not_null(particles, "Debe instanciarse un GPUParticles3D para sobrecarga")
	assert_eq(particles.name, "SobrecargaArcoParticles", "El nombre debe ser SobrecargaArcoParticles")
	assert_true(particles.top_level, "Debe ser top_level para independizarse de escalas del personaje")
	assert_true(particles.local_coords, "Debe usar local_coords para seguir al arco en movimiento")
	assert_lte(particles.amount, 12, "La cantidad de partículas debe ser reducida (<= 12)")

	# Assert: Mesh de esfera estilo disolución
	assert_true(particles.draw_pass_1 is SphereMesh, "draw_pass_1 debe ser SphereMesh")
	var sphere: SphereMesh = particles.draw_pass_1 as SphereMesh
	assert_gt(sphere.radius, 0.0, "El radio de la esfera debe ser positivo")

	# Assert: Material brillante unshaded estilo disolución enemiga
	assert_true(sphere.material is StandardMaterial3D, "El material debe ser StandardMaterial3D")
	var mat: StandardMaterial3D = sphere.material as StandardMaterial3D
	assert_true(mat.emission_enabled, "La emisión debe estar habilitada")
	assert_eq(mat.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED, "Debe ser unshaded para brillar")
	assert_eq(mat.billboard_mode, BaseMaterial3D.BILLBOARD_PARTICLES, "Debe ser billboard de partículas")
	# Color celeste (azul y verde altos)
	assert_gt(mat.albedo_color.b, 0.7, "El color debe tener componente azul alta (celeste)")
	assert_gt(mat.albedo_color.g, 0.6, "El color debe tener componente verde alta (celeste)")

	# Assert: Process Material con atracción radial negativa (concentra energía en el centro)
	assert_true(particles.process_material is ParticleProcessMaterial, "El proceso debe ser ParticleProcessMaterial")
	var pmat: ParticleProcessMaterial = particles.process_material as ParticleProcessMaterial
	assert_lt(pmat.radial_accel_min, 0.0, "radial_accel_min debe ser negativo para atraer partículas al centro")
	assert_lt(pmat.radial_accel_max, 0.0, "radial_accel_max debe ser negativo para atraer partículas al centro")
	assert_eq(pmat.emission_shape, ParticleProcessMaterial.EMISSION_SHAPE_SPHERE, "Forma de emisión debe ser esfera")
	assert_not_null(pmat.color_ramp, "Debe tener rampa de color")
	assert_not_null(pmat.scale_curve, "Debe tener curva de escala")


func test_update_sobrecarga_vfx_activar_y_desactivar():
	# Arrange
	var player: Player = autofree(_crear_player())
	add_child_autofree(player)

	# Act: Activar
	player._update_sobrecarga_vfx(true)

	# Assert: Emisión iniciada
	var vfx: GPUParticles3D = player._sobrecarga_vfx
	assert_not_null(vfx, "Debe crearse el nodo _sobrecarga_vfx")
	assert_true(vfx.emitting, "El efecto debe estar emitiendo al activarse")

	# Act: Desactivar
	player._update_sobrecarga_vfx(false)

	# Assert: Emisión detenida
	assert_false(vfx.emitting, "El efecto debe dejar de emitir al desactivarse")


func test_disparo_y_cancelacion_apagan_particulas():
	# Arrange
	var player: Player = autofree(_crear_player())
	add_child_autofree(player)
	player._update_sobrecarga_vfx(true)
	assert_true(player._sobrecarga_vfx.emitting, "Debe estar emitiendo antes de disparar")

	# Act: Disparar
	player.start_shooting()

	# Assert: Debe apagarse la emisión al disparar
	assert_false(player._sobrecarga_vfx.emitting, "start_shooting() debe apagar las partículas de sobrecarga")

	# Act: Volver a activar y luego cancelar disparo
	player._update_sobrecarga_vfx(true)
	assert_true(player._sobrecarga_vfx.emitting, "Debe volver a emitir")
	player._cancel_current_shot()

	# Assert: Debe apagarse la emisión al cancelar
	assert_false(player._sobrecarga_vfx.emitting, "_cancel_current_shot() debe apagar las partículas de sobrecarga")


func test_ambos_efectos_coexisten_simultaneamente():
	# Arrange
	var player: Player = autofree(_crear_player())
	add_child_autofree(player)

	# Act
	player._update_charge_vfx(true)
	player._update_sobrecarga_vfx(true)

	# Assert: Ambos efectos deben estar instanciados y emitiendo
	assert_not_null(player._charge_vfx, "El efecto previo _charge_vfx debe existir")
	assert_not_null(player._sobrecarga_vfx, "El efecto nuevo _sobrecarga_vfx debe existir")
	assert_true(player._charge_vfx.emitting, "El efecto previo debe estar emitiendo")
	assert_true(player._sobrecarga_vfx.emitting, "El efecto nuevo debe estar emitiendo")
	player._update_charge_vfx(false)
	player._update_sobrecarga_vfx(false)


func test_get_bow_center_position_devuelve_posicion_valida():
	# Arrange
	var player: Player = autofree(_crear_player())
	add_child_autofree(player)
	player.global_position = Vector3(5.0, 10.0, 15.0)

	# Act
	var bow_pos: Vector3 = player._get_bow_center_position()

	# Assert: Debe devolver una posición finita cercana al jugador
	assert_false(is_nan(bow_pos.x) or is_nan(bow_pos.y) or is_nan(bow_pos.z), "La posición no debe contener NaNs")
	assert_gt(bow_pos.y, player.global_position.y, "La posición del arco debe estar a la altura del torso/brazo")
