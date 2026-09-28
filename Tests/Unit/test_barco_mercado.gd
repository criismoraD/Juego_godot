extends "res://addons/gut/test.gd"

## Tests unitarios para BarcoMercado.gd
## Verifica la lógica de flotación sinusoidal y la correcta asignación de material y textura.

const TOLERANCE: float = 0.001
const SCRIPT_BARCO: GDScript = preload("res://Entities/Ambiente_BarcoMercado/BarcoMercado.gd")
const SCENE_BARCO: PackedScene = preload("res://Entities/Ambiente_BarcoMercado/BarcoMercado.tscn")

# ─────────────────────────────────────────────
# Helper
# ─────────────────────────────────────────────
func _crear_barco() -> Node3D:
	var barco: Node3D = SCRIPT_BARCO.new()
	# Fases fijas para resultados deterministas
	barco.fase_flotacion = 0.0
	barco.fase_balanceo  = 0.0
	barco.fase_cabeceo   = 0.0
	# Valores de referencia explícitos
	barco.amplitud_flotacion   = 0.03
	barco.frecuencia_flotacion = 0.28
	barco.amplitud_balanceo    = 1.2
	barco.frecuencia_balanceo  = 0.22
	barco.amplitud_cabeceo     = 0.7
	barco.frecuencia_cabeceo   = 0.35
	return barco


# ─────────────────────────────────────────────
# Test: desplazamiento Y en t = 0
# ─────────────────────────────────────────────
func test_flotacion_y_en_t0():
	# Arrange
	var barco := _crear_barco()

	# Act — sin(0) = 0 → sin desplazamiento al inicio
	var y: float = barco.calcular_desplazamiento_y(0.0)

	# Assert
	assert_almost_eq(y, 0.0, TOLERANCE, "En t=0 la flotacion debe ser 0 con fase=0")
	barco.free()


# ─────────────────────────────────────────────
# Test: amplitud máxima de flotación vertical
# ─────────────────────────────────────────────
func test_flotacion_y_amplitud_maxima():
	# Arrange
	var barco := _crear_barco()
	# t que hace sin(TAU * freq * t) = 1  → t = 1 / (4 * freq)
	var t_pico: float = 1.0 / (4.0 * barco.frecuencia_flotacion)

	# Act
	var y: float = barco.calcular_desplazamiento_y(t_pico)

	# Assert
	assert_almost_eq(y, barco.amplitud_flotacion, TOLERANCE, "La amplitud maxima de flotacion debe coincidir con el export")
	barco.free()


# ─────────────────────────────────────────────
# Test: amplitud máxima de balanceo lateral
# ─────────────────────────────────────────────
func test_balanceo_amplitud_maxima():
	# Arrange
	var barco := _crear_barco()
	var t_pico: float = 1.0 / (4.0 * barco.frecuencia_balanceo)

	# Act
	var roll: float = barco.calcular_roll_grados(t_pico)

	# Assert
	assert_almost_eq(roll, barco.amplitud_balanceo, TOLERANCE, "La amplitud maxima de balanceo debe coincidir con el export")
	barco.free()


# ─────────────────────────────────────────────
# Test: amplitud máxima de cabeceo
# ─────────────────────────────────────────────
func test_cabeceo_amplitud_maxima():
	# Arrange
	var barco := _crear_barco()
	var t_pico: float = 1.0 / (4.0 * barco.frecuencia_cabeceo)

	# Act
	var pitch: float = barco.calcular_pitch_grados(t_pico)

	# Assert
	assert_almost_eq(pitch, barco.amplitud_cabeceo, TOLERANCE, "La amplitud maxima de cabeceo debe coincidir con el export")
	barco.free()


# ─────────────────────────────────────────────
# Test: barco pesado de mercado — amplitudes menores que la canoa ligera
# ─────────────────────────────────────────────
func test_amplitudes_sutiles_vs_canoa():
	# Arrange — valores de referencia de CanoaAliada
	var canoa_flotacion: float = 0.05
	var canoa_balanceo: float  = 2.5
	var canoa_cabeceo: float   = 1.5
	var barco := _crear_barco()

	# Assert — el barco mercado (pesado) debe oscilar menos
	assert_lt(barco.amplitud_flotacion, canoa_flotacion, "Barco mercado: flotacion mas sutil que canoa ligera")
	assert_lt(barco.amplitud_balanceo,  canoa_balanceo,  "Barco mercado: balanceo mas sutil que canoa ligera")
	assert_lt(barco.amplitud_cabeceo,   canoa_cabeceo,   "Barco mercado: cabeceo mas sutil que canoa ligera")
	barco.free()


# ─────────────────────────────────────────────
# Test: capa_visual del barco es 2 por defecto
# ─────────────────────────────────────────────
func test_capa_visual_fondo_por_defecto():
	# Arrange
	var barco := SCRIPT_BARCO.new() as Node3D

	# Assert
	assert_eq(barco.capa_visual, 2, "La capa visual por defecto debe ser 2 (fondo DOF)")
	barco.free()


# ─────────────────────────────────────────────
# Test: la escena BarcoMercado aplica el material y textura a sus mallas
# ─────────────────────────────────────────────
func test_escena_barco_mercado_aplica_material_y_textura():
	# Arrange
	var barco := SCENE_BARCO.instantiate() as Node3D
	add_child_autofree(barco)

	# Act
	var meshes: Array[Node] = barco.find_children("*", "MeshInstance3D", true, false)

	# Assert
	assert_gt(meshes.size(), 0, "El BarcoMercado debe contener al menos una MeshInstance3D")
	for m in meshes:
		var mi := m as MeshInstance3D
		assert_not_null(mi.material_override, "Cada malla debe tener material_override asignado")
		var mat := mi.material_override as StandardMaterial3D
		if mat:
			assert_not_null(mat.albedo_texture, "El material debe tener albedo_texture asignada")
			assert_true(mat.albedo_texture.resource_path.ends_with("Barco mercado_D.jpg"), "La textura debe ser Barco mercado_D.jpg")
