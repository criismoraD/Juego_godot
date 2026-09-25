extends GutTest
## Tests para el sistema de outline 3D y parpadeo de daño de los proyectiles
## del Jefe Submarino: MinaAcuatica y MisilSubmarino.
##
## Cobertura:
##   - MinaAcuatica: creación de outline, aislamiento por instancia, flash rojo
##     puro, next_pass encadenado, restauración con outline tras el flash.
##   - MisilSubmarino: creación de outline, aislamiento por instancia.

const MINA_SCENE: PackedScene = preload("res://Entities/Proyectil_Mina_Acuatica/MinaAcuatica.tscn")
const MISIL_SCENE: PackedScene = preload("res://Entities/Proyectil_Misil_Submarino/MisilSubmarino.tscn")
const SHADER_OUTLINE: Shader = preload("res://System/Shaders/outline_hueso.gdshader")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _crear_mina() -> MinaAcuatica:
	var m: MinaAcuatica = MINA_SCENE.instantiate() as MinaAcuatica
	m.duracion_materializacion = 0.0
	add_child_autofree(m)
	return m



func _crear_misil() -> MisilSubmarino:
	var m: MisilSubmarino = MISIL_SCENE.instantiate() as MisilSubmarino
	add_child_autofree(m)
	return m


# ---------------------------------------------------------------------------
# MinaAcuatica — Outline
# ---------------------------------------------------------------------------

func test_mina_outline_mat_creado_en_ready() -> void:
	# Arrange & Act
	var mina: MinaAcuatica = _crear_mina()
	# Assert
	assert_not_null(mina._outline_mat,
		"_outline_mat debe crearse en _ready() via _crear_material_flash()")
	assert_is(mina._outline_mat, ShaderMaterial,
		"_outline_mat debe ser ShaderMaterial")


func test_mina_outline_usa_shader_correcto() -> void:
	# Arrange & Act
	var mina: MinaAcuatica = _crear_mina()
	# Assert
	assert_eq(mina._outline_mat.shader, SHADER_OUTLINE,
		"_outline_mat debe usar outline_hueso.gdshader")


func test_mina_mat_base_unico_creado_en_ready() -> void:
	# Arrange & Act
	var mina: MinaAcuatica = _crear_mina()
	# Assert
	assert_not_null(mina._mat_base_unico,
		"_mat_base_unico debe crearse en _ready()")
	assert_is(mina._mat_base_unico, StandardMaterial3D,
		"_mat_base_unico debe ser StandardMaterial3D (duplicado de MAT_MINA)")


func test_mina_mat_base_tiene_outline_como_next_pass() -> void:
	# Arrange & Act
	var mina: MinaAcuatica = _crear_mina()
	# Assert
	assert_eq(mina._mat_base_unico.next_pass, mina._outline_mat,
		"_mat_base_unico.next_pass debe apuntar al _outline_mat de la mina")


func test_mina_dos_instancias_tienen_mat_base_independiente() -> void:
	# Arrange & Act
	var mina_a: MinaAcuatica = _crear_mina()
	var mina_b: MinaAcuatica = _crear_mina()
	# Assert — cada instancia debe tener su propio duplicado
	assert_ne(mina_a._mat_base_unico, mina_b._mat_base_unico,
		"Dos instancias de MinaAcuatica deben tener _mat_base_unico diferentes (sin compartir)")
	assert_ne(mina_a._outline_mat, mina_b._outline_mat,
		"Dos instancias de MinaAcuatica deben tener _outline_mat diferentes")


# ---------------------------------------------------------------------------
# MinaAcuatica — Flash rojo
# ---------------------------------------------------------------------------

func test_mina_flash_mat_creado_en_ready() -> void:
	# Arrange & Act
	var mina: MinaAcuatica = _crear_mina()
	# Assert
	assert_not_null(mina._material_flash,
		"_material_flash debe crearse en _ready()")


func test_mina_flash_color_es_rojo_puro() -> void:
	# Arrange & Act
	var mina: MinaAcuatica = _crear_mina()
	var color: Color = mina._material_flash.albedo_color
	# Assert
	assert_almost_eq(color.r, 1.0, 0.01, "Canal R del flash debe ser 1.0 (rojo puro)")
	assert_almost_eq(color.g, 0.0, 0.01, "Canal G del flash debe ser 0.0")
	assert_almost_eq(color.b, 0.0, 0.01, "Canal B del flash debe ser 0.0")


func test_mina_flash_tiene_emision_activa_y_alta() -> void:
	# Arrange & Act
	var mina: MinaAcuatica = _crear_mina()
	# Assert
	assert_true(mina._material_flash.emission_enabled,
		"El flash debe tener emisión activada")
	assert_gt(mina._material_flash.emission_energy_multiplier, 3.0,
		"La energía de emisión del flash debe ser alta (>3.0) para máxima visibilidad")


func test_mina_flash_tiene_outline_como_next_pass() -> void:
	# Arrange & Act
	var mina: MinaAcuatica = _crear_mina()
	# Assert — el outline debe persistir DURANTE el flash
	assert_eq(mina._material_flash.next_pass, mina._outline_mat,
		"_material_flash.next_pass debe apuntar al _outline_mat para mantener el contorno durante el parpadeo")


func test_mina_meshes_del_modelo_usan_mat_base_unico() -> void:
	# Arrange & Act
	var mina: MinaAcuatica = _crear_mina()
	# Assert — todos los meshes del modelo (excluyendo AnilloFlotacion)
	# deben tener _mat_base_unico como material_override
	var meshes_verificados: int = 0
	for m: Node in mina.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m as MeshInstance3D
		if mi == null or mi.name == "AnilloFlotacion":
			continue
		assert_eq(mi.material_override, mina._mat_base_unico,
			"El MeshInstance3D '%s' debe usar _mat_base_unico como override" % mi.name)
		meshes_verificados += 1
	assert_gt(meshes_verificados, 0,
		"Debe haber al menos 1 MeshInstance3D con el material de outline aplicado")


# ---------------------------------------------------------------------------
# MisilSubmarino — Outline
# ---------------------------------------------------------------------------

func test_misil_outline_mat_creado_en_ready() -> void:
	# Arrange & Act
	var misil: MisilSubmarino = _crear_misil()
	# Assert
	assert_not_null(misil._outline_mat_misil,
		"_outline_mat_misil debe crearse en _ready() via _inicializar_outline()")
	assert_is(misil._outline_mat_misil, ShaderMaterial,
		"_outline_mat_misil debe ser ShaderMaterial")


func test_misil_outline_usa_shader_correcto() -> void:
	# Arrange & Act
	var misil: MisilSubmarino = _crear_misil()
	# Assert
	assert_eq(misil._outline_mat_misil.shader, SHADER_OUTLINE,
		"_outline_mat_misil debe usar outline_hueso.gdshader")


func test_misil_mat_unico_creado_en_ready() -> void:
	# Arrange & Act
	var misil: MisilSubmarino = _crear_misil()
	# Assert
	assert_not_null(misil._mat_misil_unico,
		"_mat_misil_unico debe crearse en _ready()")


func test_misil_mat_unico_tiene_outline_como_next_pass() -> void:
	# Arrange & Act
	var misil: MisilSubmarino = _crear_misil()
	# Assert
	assert_eq(misil._mat_misil_unico.next_pass, misil._outline_mat_misil,
		"_mat_misil_unico.next_pass debe apuntar al _outline_mat_misil")


func test_misil_dos_instancias_tienen_mat_unico_independiente() -> void:
	# Arrange & Act
	var misil_a: MisilSubmarino = _crear_misil()
	var misil_b: MisilSubmarino = _crear_misil()
	# Assert — materiales duplicados son instancias distintas
	assert_ne(misil_a._mat_misil_unico, misil_b._mat_misil_unico,
		"Dos misiles simultáneos no deben compartir _mat_misil_unico")
	assert_ne(misil_a._outline_mat_misil, misil_b._outline_mat_misil,
		"Dos misiles simultáneos no deben compartir _outline_mat_misil")


func test_misil_meshes_del_modelo_usan_mat_unico() -> void:
	# Arrange & Act
	var misil: MisilSubmarino = _crear_misil()
	# Assert
	var meshes_verificados: int = 0
	for m: Node in misil.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m as MeshInstance3D
		if mi == null:
			continue
		assert_eq(mi.material_override, misil._mat_misil_unico,
			"El MeshInstance3D '%s' del misil debe usar _mat_misil_unico" % mi.name)
		meshes_verificados += 1
	assert_gt(meshes_verificados, 0,
		"Debe haber al menos 1 MeshInstance3D del misil con el material de outline aplicado")


# === Tamaño del misil y de su explosión ===
func test_misil_mas_chico_modelo_y_colision_juntos() -> void:
	# Arrange / Act: misil instanciado aplica su escala
	var misil: MisilSubmarino = _crear_misil()

	# Assert: escala general inferior a 1, modelo reducido y colisión acorde
	assert_lt(misil.escala_modelo, 1.0, "El misil debe ser mas chico")
	var modelo: Node3D = misil.find_child("ModeloMisil", true, false) as Node3D
	assert_not_null(modelo, "Debe existir el modelo")
	assert_almost_eq(modelo.scale.x, misil.escala_modelo, 0.001, "Modelo escalado igual a escala_modelo")
	var colision: CollisionShape3D = misil.find_child("CollisionShape3D", true, false) as CollisionShape3D
	assert_not_null(colision, "Debe existir la colision")
	assert_almost_eq((colision.shape as SphereShape3D).radius, 0.35 * misil.escala_modelo, 0.001, "Colision reducida en proporcion")


func test_misil_explosion_mas_chica() -> void:
	# Arrange / Act: escalas relativas de VFX y global
	var misil: MisilSubmarino = _crear_misil()

	# Assert: tanto la explosion en aire como en suelo son menores que antes
	assert_almost_eq(misil.escala_vfx_aire.x, 0.18, 0.001, "Explosion en aire mas chica")
	assert_almost_eq(misil.escala_vfx_suelo.x, 0.2, 0.001, "Explosion en suelo mas chica")
	assert_lt(misil.escala_explosion, 1.0, "Multiplicador global de explosion reducido")
	assert_almost_eq(misil.escala_explosion * misil.escala_vfx_suelo.x, 0.14, 0.001, "Escala efectiva suelo = 0.7 x 0.2")

