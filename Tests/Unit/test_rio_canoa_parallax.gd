extends "res://addons/gut/test.gd"

## Tests unitarios para el escenario 'Rio en canoa con paralax'.
## Validan la estructura del nivel, paridad de posiciones con NIVEL01,
## el funcionamiento del loop infinito de parallax y la navegación de la canoa.

const ESCENA_RIO_PATH: String = "res://Levels/Rio_En_Canoa_Con_Parallax/Rio_En_Canoa_Con_Parallax.tscn"
const SCRIPT_PARALLAX: Script = preload("res://Levels/Rio_En_Canoa_Con_Parallax/ParallaxFondoRio.gd")
const SCRIPT_CANOA_RIO: Script = preload("res://Levels/Rio_En_Canoa_Con_Parallax/CanoaProtagonistaRio.gd")
const MARGEN_FLOAT: float = 0.01


# === TESTS DE ESTRUCTURA E INSTANCIACIÓN ===
func test_instanciar_escena_rio_en_canoa_con_parallax() -> void:
	# Arrange & Act
	var packed := load(ESCENA_RIO_PATH) as PackedScene
	assert_not_null(packed, "La escena debe cargar correctamente")

	var nivel: Node3D = packed.instantiate() as Node3D
	assert_not_null(nivel, "La escena debe instanciarse")
	add_child_autofree(nivel)

	# Assert
	assert_not_null(nivel.find_child("Lighting", true, false), "Debe contener el nodo Lighting")
	assert_not_null(nivel.find_child("WaterPlane", true, false), "Debe contener WaterPlane")
	assert_not_null(nivel.find_child("ParallaxFondo", true, false), "Debe contener ParallaxFondo")
	assert_not_null(nivel.find_child("CanoaProtagonistaRio", true, false), "Debe contener CanoaProtagonistaRio")


# === TESTS DE PARIDAD CON NIVEL01 (CÁMARA, AGUA, PECES) ===
func test_camara_agua_y_peces_en_posiciones_nivel01() -> void:
	# Arrange
	var packed := load(ESCENA_RIO_PATH) as PackedScene
	var nivel: Node3D = packed.instantiate() as Node3D
	add_child_autofree(nivel)

	# Act & Assert Cámara: (-3.0599, 3.2650, 40.9710)
	var camara: Camera3D = nivel.find_child("CamaraPrincipal", true, false) as Camera3D
	assert_not_null(camara, "Debe existir la cámara principal")
	assert_almost_eq(camara.position.x, -3.0599065, MARGEN_FLOAT, "Posición X de cámara debe coincidir con Nivel 1")
	assert_almost_eq(camara.position.y, 3.265016, MARGEN_FLOAT, "Posición Y de cámara debe coincidir con Nivel 1")
	assert_almost_eq(camara.position.z, 40.971046, MARGEN_FLOAT, "Posición Z de cámara debe coincidir con Nivel 1")

	# Act & Assert WaterPlane: (-5.9324, -0.1729, -12.3044)
	var water: Node3D = nivel.find_child("WaterPlane", true, false) as Node3D
	assert_not_null(water, "Debe existir WaterPlane")
	assert_almost_eq(water.position.x, -5.9324427, MARGEN_FLOAT, "Posición X de agua debe coincidir con Nivel 1")
	assert_almost_eq(water.position.y, -0.17290789, MARGEN_FLOAT, "Posición Y de agua debe coincidir con Nivel 1")
	assert_almost_eq(water.position.z, -12.304441, MARGEN_FLOAT, "Posición Z de agua debe coincidir con Nivel 1")

	# Act & Assert Pez 1 y Pez 2
	var pez1: Node3D = nivel.find_child("Pez", true, false) as Node3D
	var pez2: Node3D = nivel.find_child("Pez2", true, false) as Node3D
	assert_not_null(pez1, "Debe existir Pez 1")
	assert_not_null(pez2, "Debe existir Pez 2")
	assert_almost_eq(pez1.position.x, 2.5, MARGEN_FLOAT, "Pez 1 X")
	assert_almost_eq(pez2.position.x, -2.6435776, MARGEN_FLOAT, "Pez 2 X")


# === TESTS DE CAPAS DE PARALLAX ===
func test_parallax_capas_atardecer_y_terroso() -> void:
	# Arrange & Act
	var parallax: Node3D = SCRIPT_PARALLAX.new() as Node3D
	add_child_autofree(parallax)

	# Assert
	var capa_atardecer := parallax.get_node_or_null("CapaAtardecer") as Node3D
	var capa_terroso := parallax.get_node_or_null("CapaTerroso") as Node3D

	assert_not_null(capa_atardecer, "Debe existir CapaAtardecer")
	assert_not_null(capa_terroso, "Debe existir CapaTerroso")

	# Profundidad: Atardecer más alejado que Terroso (Z más negativa)
	assert_lt(capa_atardecer.position.z, capa_terroso.position.z, "El atardecer debe estar más al fondo que el terreno")

	# Segmentos
	var sprites_terroso: Array = parallax.call("obtener_sprites_terroso")
	assert_eq(sprites_terroso.size(), 3, "Deben existir 3 segmentos modulares de rocas terrosas")

	for s in sprites_terroso:
		var sprite := s as Sprite3D
		assert_eq(sprite.texture, SCRIPT_PARALLAX.TEX_TERROSO, "La textura del terreno debe ser Fondo terroso nivel 6")


# === TESTS DE LOOP INFINITO EN PARALLAX ===
func test_parallax_loop_continuo_terroso() -> void:
	# Arrange
	var parallax: Node3D = SCRIPT_PARALLAX.new() as Node3D
	add_child_autofree(parallax)
	parallax.set("velocidad_terroso", 2.0)

	var sprites: Array = parallax.call("obtener_sprites_terroso")
	var sprite_0 := sprites[0] as Sprite3D
	var x_inicial_0: float = sprite_0.position.x

	# Act: Simular desplazamiento de 1 segundo hacia la izquierda
	parallax._process(1.0)

	# Assert: Debe haberse desplazado hacia la izquierda (X menor)
	assert_almost_eq(sprite_0.position.x, x_inicial_0 - 2.0, MARGEN_FLOAT, "El terreno debe desplazarse a la izquierda")

	# Simular salida del encuadre para probar el wrap-around
	var ancho_seg: float = float(parallax.get("ancho_segmento_terroso"))
	sprite_0.position.x = -ancho_seg * 2.0
	parallax.call("_actualizar_loop_terroso", 0.016)

	# Assert: El sprite debe haberse reposicionado al extremo derecho
	assert_gt(sprite_0.position.x, 0.0, "El segmento debe recolocarse a la derecha al hacer loop")


# === TESTS DE CANOA Y PROTAGONISTA ===
func test_canoa_navegacion_hacia_la_derecha() -> void:
	# Arrange
	var canoa: Node3D = SCRIPT_CANOA_RIO.new() as Node3D
	add_child_autofree(canoa)
	canoa.call("fijar_posicion_base", Vector3(-5.0, -0.28, -7.5))
	canoa.set("velocidad_avance", 1.0)

	# Act: Iniciar viaje y avanzar 2 segundos
	canoa.call("iniciar_travesia", 1.0)
	canoa.call("_actualizar_navegacion", 2.0)

	# Assert: La posición X debe haber avanzado hacia la derecha (de -5.0 a -3.0)
	var pos_base: Vector3 = canoa.call("obtener_posicion_base")
	assert_almost_eq(pos_base.x, -3.0, MARGEN_FLOAT, "La canoa debe avanzar hacia la derecha (+X)")
	assert_true(bool(canoa.call("esta_flotando")), "La canoa debe mantener su estado de flotación")


# === TESTS DE VISUALIZACIÓN EN EDITOR ===
func test_parallax_visualizacion_en_editor_y_escena() -> void:
	# Arrange & Act: Cargar la escena tal como se abre en el editor de Godot
	var packed := load(ESCENA_RIO_PATH) as PackedScene
	var nivel: Node3D = packed.instantiate() as Node3D
	add_child_autofree(nivel)

	var parallax: Node3D = nivel.find_child("ParallaxFondo", true, false) as Node3D
	assert_not_null(parallax, "ParallaxFondo debe existir en la escena")

	# Assert: Capas presentes como nodos hijos para manipulación con gizmos en el editor
	var capa_atardecer := parallax.get_node_or_null("CapaAtardecer") as Node3D
	var capa_terroso := parallax.get_node_or_null("CapaTerroso") as Node3D
	assert_not_null(capa_atardecer, "CapaAtardecer debe ser un nodo hijo en la escena para el editor")
	assert_not_null(capa_terroso, "CapaTerroso debe ser un nodo hijo en la escena para el editor")

	# Assert: Sprites con sus texturas en el árbol del editor
	var sprites_arboles: Array = parallax.call("obtener_sprites_arboles")
	var sprites_atardecer: Array = parallax.call("obtener_sprites_atardecer")
	assert_eq(sprites_arboles.size(), 8, "Debe tener 8 sprites de árboles en la escena")
	assert_eq(sprites_atardecer.size(), 1, "Debe tener 1 sprite de atardecer panorámico con un único sol")

	for s in sprites_arboles:
		var sprite := s as Sprite3D
		assert_not_null(sprite.texture, "El sprite del terreno debe tener textura asignada en la escena")
		assert_true(bool(sprite.layers & 1), "El sprite debe ser visible en la capa 1 para el editor")

	for s in sprites_atardecer:
		var sprite := s as Sprite3D
		assert_not_null(sprite.texture, "El sprite de atardecer debe tener textura asignada en la escena")
		assert_true(bool(sprite.layers & 1), "El sprite debe ser visible en la capa 1 para el editor")

	# Assert: CapaCordillera presente con 12 modelos de piedras
	var capa_cordillera := parallax.get_node_or_null("CapaCordillera") as Node3D
	assert_not_null(capa_cordillera, "CapaCordillera debe ser un nodo hijo en la escena para el editor")
	var segmentos_cord: Array = parallax.call("obtener_segmentos_cordillera")
	assert_eq(segmentos_cord.size(), 12, "Debe tener 12 segmentos de cordillera en la escena")


# === TESTS DE CORDILLERA 3D (PIEDRA FONDO NIVEL 6) ===
func test_parallax_capa_cordillera_inicializacion_y_segmentos() -> void:
	# Arrange & Act
	var parallax: Node3D = SCRIPT_PARALLAX.new() as Node3D
	add_child_autofree(parallax)

	# Assert
	var capa_cordillera := parallax.get_node_or_null("CapaCordillera") as Node3D
	assert_not_null(capa_cordillera, "Debe instanciar automáticamente CapaCordillera")
	assert_almost_eq(capa_cordillera.position.z, -28.0, MARGEN_FLOAT, "Profundidad de cordillera debe ser -28.0 (intermedio entre agua y atardecer)")

	var segmentos: Array = parallax.call("obtener_segmentos_cordillera")
	assert_eq(segmentos.size(), 12, "La cordillera debe contener 12 segmentos consecutivos tipo cinta")

	for i in range(segmentos.size()):
		var seg := segmentos[i] as Node3D
		assert_not_null(seg, "Cada segmento de la cordillera debe ser un Node3D válido")
		if i > 0:
			var seg_ant := segmentos[i - 1] as Node3D
			assert_gt(seg.position.x, seg_ant.position.x, "Los segmentos de la cordillera deben estar alineados sucesivamente de izquierda a derecha")


func test_parallax_loop_continuo_cordillera() -> void:
	# Arrange
	var parallax: Node3D = SCRIPT_PARALLAX.new() as Node3D
	add_child_autofree(parallax)
	parallax.set("velocidad_terroso", 2.0)
	parallax.set("factor_cordillera", 0.5)

	var segmentos: Array = parallax.call("obtener_segmentos_cordillera")
	assert_eq(segmentos.size(), 12, "Deben existir 12 segmentos")
	var seg_0 := segmentos[0] as Node3D
	var x_inicial_0: float = seg_0.position.x

	# Act: Simular desplazamiento de 1 segundo hacia la izquierda
	parallax.call("_actualizar_loop_cordillera", 1.0)

	# Assert: Debe haberse desplazado hacia la izquierda (paso = 2.0 * 0.5 * 1.0 = 1.0)
	assert_almost_eq(seg_0.position.x, x_inicial_0 - 1.0, MARGEN_FLOAT, "La cordillera debe avanzar en paralaje hacia la izquierda")

	# Act: Simular que el segmento queda muy atrás a la izquierda de la cámara/origen
	var ancho_seg: float = float(parallax.get("ancho_segmento_cordillera"))
	seg_0.position.x = -ancho_seg * 5.0
	parallax.call("_actualizar_loop_cordillera", 0.016)

	# Assert: El segmento debe reubicarse al extremo derecho como una cinta transportadora
	assert_gt(seg_0.position.x, 0.0, "El segmento de la cordillera debe teletransportarse al frente derecho de la cinta")


# === TESTS DE CÁMARA SIGUE CANOA ===
func test_camara_sigue_canoa_aliada() -> void:
	# Arrange
	var packed := load(ESCENA_RIO_PATH) as PackedScene
	var nivel: Node3D = packed.instantiate() as Node3D
	add_child_autofree(nivel)

	var canoa: Node3D = nivel.call("obtener_canoa")
	var camara: Camera3D = nivel.call("obtener_camara")
	var water: Node3D = nivel.call("obtener_water_plane")

	assert_not_null(canoa, "Debe existir la canoa de la protagonista")
	assert_not_null(camara, "Debe existir la cámara principal")
	assert_not_null(water, "Debe existir el plano de agua")

	var offset_inicial_camara: float = camara.global_position.x - canoa.global_position.x

	# Act: Desplazar la canoa 15 metros hacia la derecha
	canoa.global_position.x += 15.0
	nivel._process(0.016)

	# Assert: La cámara debe acompañar a la canoa manteniendo el offset
	assert_almost_eq(camara.global_position.x, canoa.global_position.x + offset_inicial_camara, MARGEN_FLOAT, "La cámara debe seguir fielmente la coordenada X de la canoa")


# === TESTS DE AGUA CONTINUA SIN CORTES Y PECES DINÁMICOS ===
func test_cinta_transportadora_agua_infinita() -> void:
	# Arrange
	var packed := load(ESCENA_RIO_PATH) as PackedScene
	var nivel: Node3D = packed.instantiate() as Node3D
	add_child_autofree(nivel)

	var water: Node3D = nivel.call("obtener_water_plane")
	assert_not_null(water, "Debe existir el plano de agua")
	assert_gte(water.scale.x, 3.5, "El plano de agua debe tener escala horizontal >= 3.5x para cubrir el río sin costuras")

	var canoa: Node3D = nivel.call("obtener_canoa")
	var x_agua_inicial: float = water.global_position.x

	# Act: Avanzar la canoa 30 metros a la derecha
	canoa.global_position.x += 30.0
	nivel._process(0.016)

	# Assert: El plano de agua acompaña a la canoa garantizando cobertura infinita sin cortes
	assert_almost_eq(water.global_position.x, x_agua_inicial + 30.0, MARGEN_FLOAT, "El plano de agua acompaña el movimiento de la canoa")


func test_peces_limites_dinamicos_relativos_a_camara() -> void:
	# Arrange
	var packed := load(ESCENA_RIO_PATH) as PackedScene
	var nivel: Node3D = packed.instantiate() as Node3D
	add_child_autofree(nivel)

	var pez: Pez = nivel.find_child("Pez", true, false) as Pez
	assert_not_null(pez, "Debe existir el pez")

	var camara: Camera3D = nivel.call("obtener_camara")
	camara.global_position.x = 100.0

	# Act: Obtener límites dinámicos
	var limites: Vector2 = pez.call("_obtener_limites_x")

	# Assert: Límites deben estar centrados alrededor de la cámara (100.0) y no en coordenadas fijas (-11, 5)
	assert_almost_eq(limites.x, 100.0 - pez.margen_pantalla_peces, MARGEN_FLOAT, "Límite izquierdo relativo a la cámara")
	assert_almost_eq(limites.y, 100.0 + pez.margen_pantalla_peces, MARGEN_FLOAT, "Límite derecho relativo a la cámara")


func test_escena_usuario_rio_en_canoa_con_paralax_integridad() -> void:
	# Arrange & Act: Probar la escena raíz que el usuario abre en Godot
	var path_usuario: String = "res://Levels/Rio en canoa con paralax.tscn"
	var packed := load(path_usuario) as PackedScene
	assert_not_null(packed, "La escena 'Rio en canoa con paralax.tscn' debe cargar correctamente")

	var nivel: Node3D = packed.instantiate() as Node3D
	assert_not_null(nivel, "La escena del usuario debe instanciarse")
	add_child_autofree(nivel)

	# Assert Parallax y Atardecer
	var parallax: Node3D = nivel.find_child("ParallaxFondo", true, false) as Node3D
	assert_not_null(parallax, "ParallaxFondo debe existir")
	assert_gte(float(parallax.get("ancho_segmento_atardecer")), 150.0, "El atardecer debe tener al menos 150m de ancho panorámico para un único sol")

	var sprites_atardecer: Array = parallax.call("obtener_sprites_atardecer")
	assert_gte(sprites_atardecer.size(), 1, "Debe haber al menos 1 panel de atardecer panorámico con sol único")

	# Assert Cordillera
	var segs_cord: Array = parallax.call("obtener_segmentos_cordillera")
	assert_eq(segs_cord.size(), 12, "La cordillera debe contar con 12 segmentos")

	# Assert Agua
	var water_usuario: Node3D = nivel.find_child("WaterPlane", true, false) as Node3D
	assert_not_null(water_usuario, "WaterPlane debe existir en la escena del usuario")
	assert_gte(water_usuario.scale.x, 3.5, "El agua debe tener al menos 3.5x de escala para garantizar río sin costuras")


# === TESTS DE NUBES ROSA (LIMPIAS SIN SHADER DE NIEBLA) ===
func test_nubes_rosa_sin_shader_de_niebla() -> void:
	# Arrange & Act
	var packed := load(ESCENA_RIO_PATH) as PackedScene
	var nivel: Node3D = packed.instantiate() as Node3D
	add_child_autofree(nivel)

	var parallax: ParallaxFondoRio = nivel.find_child("ParallaxFondo", true, false) as ParallaxFondoRio
	assert_not_null(parallax, "ParallaxFondo debe existir en la escena")

	var nubes: Array[Sprite3D] = parallax.obtener_sprites_nubes()
	assert_eq(nubes.size(), 5, "Deben existir 5 paneles de nubes rosa")

	for i in range(nubes.size()):
		var nube: Sprite3D = nubes[i]
		assert_not_null(nube, "El nodo NubeRosa_%d debe existir" % i)
		assert_null(nube.material_override, "NubeRosa_%d no debe tener ShaderMaterial de niebla para evitar movimientos extraños" % i)
		assert_not_null(nube.texture, "NubeRosa_%d debe conservar su textura original" % i)


func test_nubes_rosa_inicializacion_dinamica_limpia() -> void:
	# Arrange & Act
	var parallax: ParallaxFondoRio = SCRIPT_PARALLAX.new() as ParallaxFondoRio
	add_child_autofree(parallax)

	# Assert
	var nubes: Array[Sprite3D] = parallax.obtener_sprites_nubes()
	assert_eq(nubes.size(), 5, "Deben crearse 5 segmentos de nubes rosa dinámicamente")

	for nube in nubes:
		assert_null(nube.material_override, "Cada nube debe ser limpia sin shader que altere el parallax")


# === TESTS DE POSICIONAMIENTO LIBRE DEL FONDO DE VIDEO ===
func test_fondo_video_posicionamiento_libre_en_editor_y_juego() -> void:
	# Arrange
	var packed := load(ESCENA_RIO_PATH) as PackedScene
	var nivel: Node3D = packed.instantiate() as Node3D
	add_child_autofree(nivel)

	var parallax: ParallaxFondoRio = nivel.find_child("ParallaxFondo", true, false) as ParallaxFondoRio
	assert_not_null(parallax, "ParallaxFondo debe existir")

	var sprite_video: Sprite3D = parallax.obtener_sprite_fondo_video()
	assert_not_null(sprite_video, "El sprite de video debe existir")

	# Act: Simular que el usuario mueve el video libremente a una nueva posición y escala en el editor
	var nueva_pos := Vector3(12.5, 8.0, -85.0)
	var nueva_escala := Vector3(9.0, 6.0, 1.0)
	sprite_video.position = nueva_pos
	sprite_video.scale = nueva_escala

	# Ejecutar _ready de inicialización (como hace el editor o al recargar la escena)
	parallax._inicializar_capa_fondo_video()

	# Assert: La posición y escala personalizadas NO deben ser sobreescritas por el script
	assert_almost_eq(sprite_video.position.y, 8.0, MARGEN_FLOAT, "La cota Y del video debe mantenerse según el usuario")
	assert_almost_eq(sprite_video.position.z, -85.0, MARGEN_FLOAT, "La profundidad Z del video debe mantenerse según el usuario")
	assert_almost_eq(sprite_video.scale.x, 9.0, MARGEN_FLOAT, "La escala X debe mantenerse según el usuario")
	assert_almost_eq(sprite_video.scale.y, 6.0, MARGEN_FLOAT, "La escala Y debe mantenerse según el usuario")


func test_fondo_video_ajuste_offset_manual_en_inspector() -> void:
	# Arrange
	var packed := load(ESCENA_RIO_PATH) as PackedScene
	var nivel: Node3D = packed.instantiate() as Node3D
	add_child_autofree(nivel)

	var parallax: ParallaxFondoRio = nivel.find_child("ParallaxFondo", true, false) as ParallaxFondoRio
	var sprite_video: Sprite3D = parallax.obtener_sprite_fondo_video()
	var pos_inicial := sprite_video.position

	# Act: Modificar offset_posicion_video en el inspector
	parallax.offset_posicion_video = Vector3(4.0, -2.0, 5.0)

	# Assert: Debe haberse desplazado la posición del sprite por el delta del offset
	assert_almost_eq(sprite_video.position.x, pos_inicial.x + 4.0, MARGEN_FLOAT, "Offset X manual")
	assert_almost_eq(sprite_video.position.y, pos_inicial.y - 2.0, MARGEN_FLOAT, "Offset Y manual")
	assert_almost_eq(sprite_video.position.z, pos_inicial.z + 5.0, MARGEN_FLOAT, "Offset Z manual")


# === TEST DE FONDO NITIDO Y SIN NIEBLA ===
func test_fondo_video_nitido_sin_niebla() -> void:
	# Arrange
	var packed := load(ESCENA_RIO_PATH) as PackedScene
	var nivel: RioEnCanoaConParallax = packed.instantiate() as RioEnCanoaConParallax
	add_child_autofree(nivel)

	var parallax: ParallaxFondoRio = nivel.obtener_parallax() as ParallaxFondoRio
	assert_not_null(parallax, "Debe existir ParallaxFondo")

	# Act
	var sprite_video: Sprite3D = parallax.obtener_sprite_fondo_video()
	assert_not_null(sprite_video, "El sprite de video debe existir")

	# Assert: Debe usar StandardMaterial3D sin shader de desenfoque y con disable_fog para máxima nitidez
	var mat := sprite_video.material_override as StandardMaterial3D
	assert_not_null(mat, "El sprite de video debe usar StandardMaterial3D nítido")
	assert_true(mat.disable_fog, "El video de fondo debe tener disable_fog para no verse tapado por la niebla")
	assert_eq(mat.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED, "El video debe ser unshaded para mantener colores directos")


# === TESTS DE PISOS ALIADOS SINCRONIZADOS CON LA CORDILLERA ===
func test_pisos_aliados_deteccion_en_escena() -> void:
	# Arrange & Act
	var packed := load(ESCENA_RIO_PATH) as PackedScene
	var nivel: RioEnCanoaConParallax = packed.instantiate() as RioEnCanoaConParallax
	add_child_autofree(nivel)

	# Assert
	var pisos: Array[Node3D] = nivel.obtener_segmentos_piso_aliado()
	assert_gt(pisos.size(), 0, "Debe detectar los nodos PISO ALIADO en la escena")
	assert_eq(pisos.size(), 20, "Deben estar presentes los 20 segmentos de piso aliado")


func test_pisos_aliados_sincronizados_misma_velocidad_cordillera() -> void:
	# Arrange
	var packed := load(ESCENA_RIO_PATH) as PackedScene
	var nivel: RioEnCanoaConParallax = packed.instantiate() as RioEnCanoaConParallax
	add_child_autofree(nivel)

	var parallax: ParallaxFondoRio = nivel.obtener_parallax() as ParallaxFondoRio
	assert_not_null(parallax, "ParallaxFondo debe existir")

	var cordillera: Array[Node3D] = parallax.obtener_segmentos_cordillera()
	var pisos: Array[Node3D] = parallax.obtener_segmentos_piso_aliado()
	assert_gt(cordillera.size(), 0, "Cordillera debe tener segmentos")
	assert_gt(pisos.size(), 0, "Pisos aliados deben tener segmentos")

	var pos_inicial_cordillera: float = cordillera[0].position.x
	var pos_inicial_piso: float = pisos[0].position.x

	# Act: Simular un avance de 1.0 segundo
	parallax._actualizar_loop_cordillera(1.0)
	parallax._actualizar_loop_piso_aliado(1.0)

	# Assert: El desplazamiento debe ser IDÉNTICO para ambos
	var delta_cordillera: float = pos_inicial_cordillera - cordillera[0].position.x
	var delta_piso: float = pos_inicial_piso - pisos[0].position.x

	var desplazamiento_esperado: float = parallax.velocidad_base * parallax.factor_cordillera * 1.0
	assert_almost_eq(delta_cordillera, desplazamiento_esperado, MARGEN_FLOAT, "Desplazamiento de cordillera")
	assert_almost_eq(delta_piso, desplazamiento_esperado, MARGEN_FLOAT, "Desplazamiento de piso aliado")
	assert_almost_eq(delta_piso, delta_cordillera, MARGEN_FLOAT, "Piso aliado y cordillera deben moverse a la misma velocidad exacta como si fueran uno solo")


func test_pisos_aliados_loop_continuo() -> void:
	# Arrange
	var packed := load(ESCENA_RIO_PATH) as PackedScene
	var nivel: RioEnCanoaConParallax = packed.instantiate() as RioEnCanoaConParallax
	add_child_autofree(nivel)

	var parallax: ParallaxFondoRio = nivel.obtener_parallax() as ParallaxFondoRio
	var pisos: Array[Node3D] = parallax.obtener_segmentos_piso_aliado()
	assert_gt(pisos.size(), 0, "Pisos aliados deben existir")

	var piso_0: Node3D = pisos[0]
	var x_max_inicial: float = -INF
	for p in pisos:
		if p.position.x > x_max_inicial:
			x_max_inicial = p.position.x

	# Act: Forzar que piso_0 salga por la izquierda del límite visible
	piso_0.position.x = -100.0
	parallax._actualizar_loop_piso_aliado(0.0)

	# Assert: Debe recolocarse a la derecha de x_maxima
	assert_almost_eq(piso_0.position.x, x_max_inicial + parallax.ancho_segmento_piso, MARGEN_FLOAT, "El piso aliado debe hacer wrap continuo a la derecha")



