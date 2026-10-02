extends "res://addons/gut/test.gd"

## Tests unitarios para el componente EfectoNube (estilo Castlevania: Symphony of the Night).
## Verifica la correcta inicialización, geometría 3D, actualización del shader UV,
## selector de velocidad y medidores de color (naranja atardecer, nocturno, etc.).

const SCENE_EFECTO_NUBE: PackedScene = preload("res://Levels/Nivel_Pueblo/EfectoNube.tscn")

func test_instanciar_efecto_nube_y_subnodos():
	# Arrange
	var efecto: EfectoNube = SCENE_EFECTO_NUBE.instantiate() as EfectoNube
	
	# Act
	add_child_autofree(efecto)
	
	# Assert
	assert_not_null(efecto, "La escena EfectoNube debe instanciarse correctamente")
	assert_not_null(efecto.malla_nubes, "MallaNubes (%MallaNubes) debe existir")


func test_valores_predeterminados():
	# Arrange & Act
	var efecto: EfectoNube = SCENE_EFECTO_NUBE.instantiate() as EfectoNube
	add_child_autofree(efecto)
	
	# Assert
	assert_almost_eq(efecto.get_velocidad(), 0.35, 0.001, "La velocidad inicial debe ser 0.35 u/s")
	assert_almost_eq(efecto.angulo_inclinacion_grados, -78.0, 0.1, "El ángulo de inclinación 3D debe ser -78°")
	assert_true(efecto.seguir_camara_x, "Debe seguir la cámara horizontalmente por defecto")
	assert_false(efecto.invertir_direccion, "La dirección por defecto debe viajar hacia la cámara")


func test_set_velocidad_emite_senal():
	# Arrange
	var efecto: EfectoNube = SCENE_EFECTO_NUBE.instantiate() as EfectoNube
	add_child_autofree(efecto)
	watch_signals(efecto)
	
	# Act
	efecto.set_velocidad(0.75)
	
	# Assert
	assert_almost_eq(efecto.get_velocidad(), 0.75, 0.001, "La velocidad debe haberse actualizado a 0.75")
	assert_signal_emitted_with_parameters(efecto, "velocidad_cambiada", [0.75])


func test_presets_velocidad_modifican_velocidad():
	# Arrange
	var efecto: EfectoNube = SCENE_EFECTO_NUBE.instantiate() as EfectoNube
	add_child_autofree(efecto)
	
	# Act & Assert — Preset Lento
	efecto.preset_velocidad = EfectoNube.PresetVelocidad.LENTO
	assert_almost_eq(efecto.get_velocidad(), EfectoNube.VELOCIDAD_PRESET_LENTO, 0.001, "Preset lento debe ser 0.15")
	
	# Act & Assert — Preset Rápido
	efecto.preset_velocidad = EfectoNube.PresetVelocidad.RAPIDO
	assert_almost_eq(efecto.get_velocidad(), EfectoNube.VELOCIDAD_PRESET_RAPIDO, 0.001, "Preset rápido debe ser 0.70")
	
	# Act & Assert — Preset Pausa
	efecto.preset_velocidad = EfectoNube.PresetVelocidad.PAUSA
	assert_almost_eq(efecto.get_velocidad(), 0.0, 0.001, "Preset pausa debe ser 0.0")
	
	# Act & Assert — Preset Normal
	efecto.preset_velocidad = EfectoNube.PresetVelocidad.NORMAL
	assert_almost_eq(efecto.get_velocidad(), EfectoNube.VELOCIDAD_PRESET_NORMAL, 0.001, "Preset normal debe ser 0.35")


func test_preset_color_naranja_tutorial():
	# Arrange
	var efecto: EfectoNube = SCENE_EFECTO_NUBE.instantiate() as EfectoNube
	add_child_autofree(efecto)
	
	# Act
	efecto.preset_color = EfectoNube.PresetColorNube.NARANJA_TUTORIAL
	
	# Assert
	assert_eq(efecto.tinte_luz, EfectoNube.COLOR_NARANJA_LUZ, "tinte_luz debe ser el naranja brillante de atardecer")
	assert_eq(efecto.tinte_sombra, EfectoNube.COLOR_NARANJA_SOMBRA, "tinte_sombra debe ser el terracota oscuro de atardecer")
	assert_almost_eq(efecto.intensidad_color, 1.15, 0.01, "La intensidad de color debe ser 1.15")
	assert_almost_eq(efecto.modo_recoloreo, 1.0, 0.01, "El modo recoloreo debe ser 1.0 (gradiente de dos tonos)")


func test_preset_color_nocturno_violeta():
	# Arrange
	var efecto: EfectoNube = SCENE_EFECTO_NUBE.instantiate() as EfectoNube
	add_child_autofree(efecto)
	
	# Act
	efecto.preset_color = EfectoNube.PresetColorNube.NOCTURNO_VIOLETA
	
	# Assert
	assert_eq(efecto.tinte_luz, EfectoNube.COLOR_VIOLETA_LUZ, "tinte_luz debe ser violeta nocturno")
	assert_eq(efecto.tinte_sombra, EfectoNube.COLOR_VIOLETA_SOMBRA, "tinte_sombra debe ser sombra púrpura profunda")


func test_set_colores_nube_personalizado_emite_senal():
	# Arrange
	var efecto: EfectoNube = SCENE_EFECTO_NUBE.instantiate() as EfectoNube
	add_child_autofree(efecto)
	watch_signals(efecto)
	
	var luz_custom: Color = Color(1.0, 0.4, 0.1, 1.0)
	var sombra_custom: Color = Color(0.3, 0.1, 0.05, 1.0)
	
	# Act
	efecto.set_colores_nube(luz_custom, sombra_custom)
	
	# Assert
	assert_eq(efecto.tinte_luz, luz_custom, "tinte_luz debe ser actualizado")
	assert_eq(efecto.tinte_sombra, sombra_custom, "tinte_sombra debe ser actualizado")
	assert_signal_emitted_with_parameters(efecto, "color_cambiado", [luz_custom, sombra_custom])


func test_desplazamiento_en_process_actualiza_offset():
	# Arrange
	var efecto: EfectoNube = SCENE_EFECTO_NUBE.instantiate() as EfectoNube
	add_child_autofree(efecto)
	efecto.set_velocidad(1.0)
	
	# Act — Simular frames
	for i in range(10):
		efecto._process(0.016)
	
	# Assert
	assert_gt(efecto._acumulador_offset, 0.0, "El acumulador de offset debe avanzar con velocidad positiva")


func test_invertir_direccion_invierte_signo_desplazamiento():
	# Arrange
	var efecto: EfectoNube = SCENE_EFECTO_NUBE.instantiate() as EfectoNube
	add_child_autofree(efecto)
	efecto.set_velocidad(1.0)
	efecto.invertir_direccion = true
	
	# Act — Simular frames
	for i in range(10):
		efecto._process(0.016)
	
	# Assert
	assert_lt(efecto._acumulador_offset, 0.0, "Con invertir_direccion=true el offset debe avanzar en negativo")


func test_efecto_nube_existe_en_nivel_pueblo():
	# Arrange & Act
	var escena_pueblo: PackedScene = load("res://Levels/Nivel_Pueblo/NivelPueblo.tscn") as PackedScene
	assert_not_null(escena_pueblo, "La escena NivelPueblo debe cargarse sin errores")
	var nivel: Node = escena_pueblo.instantiate()
	add_child_autofree(nivel)
	
	# Assert
	var efecto_pueblo: Node = nivel.find_child("Efecto Nube", true, false)
	assert_not_null(efecto_pueblo, "Debe existir un nodo 'Efecto Nube' en NivelPueblo.tscn")
	assert_true(efecto_pueblo is EfectoNube, "El nodo 'Efecto Nube' debe ser de tipo EfectoNube")


func test_efecto_nube_existe_en_nivel_tutorial_con_nubes_naranjas():
	# Arrange & Act
	var escena_tuto: PackedScene = load("res://Levels/NIVEL_TUTORIAL/NIVEL_TUTORIAL.tscn") as PackedScene
	assert_not_null(escena_tuto, "La escena NIVEL_TUTORIAL debe cargarse sin errores")
	var nivel: Node = escena_tuto.instantiate()
	add_child_autofree(nivel)
	
	# Assert
	var efecto_tuto: Node = nivel.find_child("Efecto Nube", true, false)
	assert_not_null(efecto_tuto, "Debe existir un nodo 'Efecto Nube' en NIVEL_TUTORIAL.tscn")
	assert_true(efecto_tuto is EfectoNube, "El nodo 'Efecto Nube' debe ser de tipo EfectoNube")
	var efecto_cast: EfectoNube = efecto_tuto as EfectoNube
	assert_eq(efecto_cast.preset_color, EfectoNube.PresetColorNube.NARANJA_TUTORIAL, "El nivel tutorial debe tener preset NARANJA_TUTORIAL")
	assert_eq(efecto_cast.tinte_luz, EfectoNube.COLOR_NARANJA_LUZ, "Las nubes del tutorial deben ser naranjas")

