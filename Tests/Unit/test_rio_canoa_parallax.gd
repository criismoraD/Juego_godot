extends "res://addons/gut/test.gd"

## Tests unitarios para el escenario 'Rio en canoa con paralax'.
## Validan la estructura del nivel, paridad de posiciones con NIVEL01,
## el funcionamiento del loop infinito de parallax y la navegación de la canoa.

const ESCENA_RIO_PATH: String = "res://Levels/Rio en canoa con paralax.tscn"
const SCRIPT_PARALLAX: Script = preload("res://Levels/Rio_En_Canoa_Con_Parallax/ParallaxFondoRio.gd")
const SCRIPT_CANOA_RIO: Script = preload("res://Levels/Rio_En_Canoa_Con_Parallax/CanoaProtagonistaRio.gd")
const ESCENA_CANOA_PATH: String = "res://Levels/Rio_En_Canoa_Con_Parallax/CanoaProtagonistaRio.tscn"
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

	# Act & Assert WaterPlane: (-5.9324, -0.1729, -67.5795) en la escena del usuario
	var water: Node3D = nivel.find_child("WaterPlane", true, false) as Node3D
	assert_not_null(water, "Debe existir WaterPlane")
	assert_almost_eq(water.position.x, -5.9324427, MARGEN_FLOAT, "Posición X de agua debe coincidir con Nivel 1")
	assert_almost_eq(water.position.y, -0.17290789, MARGEN_FLOAT, "Posición Y de agua debe coincidir con Nivel 1")
	assert_almost_eq(water.position.z, -67.57953, MARGEN_FLOAT, "Posición Z de agua en la escena del usuario")

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
	assert_gt(pisos.size(), 0, "Debe detectar los nodos de piso en la escena")
	assert_eq(pisos.size(), 21, "Deben estar presentes los 21 segmentos de Piso nueva version (Piso parada excluida para no alterar el parallax)")


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


func test_piso_nueva_version_escena_usuario_deteccion_y_velocidad_cordillera() -> void:
	# Arrange & Act: Probar la escena principal con 'Piso nueva version'
	var path_usuario: String = "res://Levels/Rio en canoa con paralax.tscn"
	var packed := load(path_usuario) as PackedScene
	assert_not_null(packed, "La escena 'Rio en canoa con paralax.tscn' debe cargar correctamente")

	var nivel: Node3D = packed.instantiate() as Node3D
	assert_not_null(nivel)
	add_child_autofree(nivel)

	var parallax: ParallaxFondoRio = nivel.find_child("ParallaxFondo", true, false) as ParallaxFondoRio
	assert_not_null(parallax, "ParallaxFondo debe existir en la escena del usuario")

	var pisos: Array[Node3D] = parallax.obtener_segmentos_piso_aliado()
	assert_gt(pisos.size(), 0, "Debe detectar los nodos 'Piso nueva version'")
	assert_gte(pisos.size(), 20, "Deben estar presentes los segmentos de 'Piso nueva version'")

	# Assert de velocidad y desplazamiento sincronizado con la cordillera
	var cordillera: Array[Node3D] = parallax.obtener_segmentos_cordillera()
	assert_gt(cordillera.size(), 0, "Cordillera debe tener segmentos")

	var pos_inicial_cord: float = cordillera[0].position.x
	var pos_inicial_piso: float = pisos[0].position.x

	# Act: Simular un avance de 1.0 segundo
	parallax._actualizar_loop_cordillera(1.0)
	parallax._actualizar_loop_piso_aliado(1.0)

	# Assert: Desplazamiento idéntico
	var delta_cord: float = pos_inicial_cord - cordillera[0].position.x
	var delta_piso: float = pos_inicial_piso - pisos[0].position.x
	var desplazamiento_esperado: float = parallax.velocidad_base * parallax.factor_cordillera * 1.0

	assert_almost_eq(delta_cord, desplazamiento_esperado, MARGEN_FLOAT, "Desplazamiento cordillera")
	assert_almost_eq(delta_piso, desplazamiento_esperado, MARGEN_FLOAT, "Piso nueva version avanza al ritmo esperado")
	assert_almost_eq(delta_piso, delta_cord, MARGEN_FLOAT, "Piso nueva version debe moverse exactamente a la misma velocidad que la cordillera")


func test_textura_agua_fija_no_entra_al_loop() -> void:
	# Arrange & Act: la escena del usuario solo trae la sombra fija colocada a mano
	var packed := load(ESCENA_RIO_PATH) as PackedScene
	assert_not_null(packed, "La escena del usuario debe cargar correctamente")
	var nivel: Node3D = packed.instantiate() as Node3D
	add_child_autofree(nivel)

	var parallax: ParallaxFondoRio = nivel.find_child("ParallaxFondo", true, false) as ParallaxFondoRio
	assert_not_null(parallax, "ParallaxFondo debe existir")

	# Assert: no hay textura móvil y la fija queda fuera del loop
	var sprites: Array[Sprite3D] = parallax.obtener_sprites_agua_textura()
	assert_true(sprites.is_empty(), "Sin TexturaAgua móvil no hay sprites en el loop")
	assert_null(nivel.find_child("TexturaAgua", true, false), "La escena no trae TexturaAgua móvil")
	# Las marcadas (fijo) son sombras colocadas a mano y no entran al loop
	for fijo in nivel.find_children("TexturaAgua(fijo)", "", true, false):
		assert_false(sprites.has(fijo), "TexturaAgua(fijo) no debe moverse")


func test_textura_agua_misma_velocidad_cordillera() -> void:
	# Arrange: la escena no trae textura móvil; se registra una dinámica para cubrir el mecanismo
	var packed := load(ESCENA_RIO_PATH) as PackedScene
	var nivel: Node3D = packed.instantiate() as Node3D
	add_child_autofree(nivel)

	var parallax: ParallaxFondoRio = nivel.find_child("ParallaxFondo", true, false) as ParallaxFondoRio
	var agua := Sprite3D.new()
	agua.name = "TexturaAgua"
	agua.position = Vector3(10.0, -0.4, -60.0)
	nivel.add_child(agua)
	parallax.registrar_sprite_agua_textura(agua)
	var sprites: Array[Sprite3D] = parallax.obtener_sprites_agua_textura()
	assert_gt(sprites.size(), 0, "TexturaAgua debe existir")
	var cordillera: Array[Node3D] = parallax.obtener_segmentos_cordillera()
	assert_gt(cordillera.size(), 0, "Cordillera debe tener segmentos")

	var pos_inicial_cord: float = cordillera[0].position.x
	var pos_inicial_agua: float = sprites[0].position.x

	# Act: Simular un avance de 1.0 segundo
	parallax._actualizar_loop_cordillera(1.0)
	parallax._actualizar_loop_agua_textura(1.0)

	# Assert: Desplazamiento idéntico al de la cordillera
	var delta_cord: float = pos_inicial_cord - cordillera[0].position.x
	var delta_agua: float = pos_inicial_agua - sprites[0].position.x
	var desplazamiento_esperado: float = parallax.velocidad_base * parallax.factor_cordillera * 1.0

	assert_almost_eq(delta_cord, desplazamiento_esperado, MARGEN_FLOAT, "Desplazamiento cordillera")
	assert_almost_eq(delta_agua, desplazamiento_esperado, MARGEN_FLOAT, "TexturaAgua avanza al ritmo esperado")
	assert_almost_eq(delta_agua, delta_cord, MARGEN_FLOAT, "TexturaAgua debe moverse exactamente a la misma velocidad que la cordillera")


func test_textura_agua_loop_continuo() -> void:
	# Arrange: sprite registrado dinámicamente (la escena no trae textura móvil)
	var packed := load(ESCENA_RIO_PATH) as PackedScene
	var nivel: Node3D = packed.instantiate() as Node3D
	add_child_autofree(nivel)

	var parallax: ParallaxFondoRio = nivel.find_child("ParallaxFondo", true, false) as ParallaxFondoRio
	var agua := Sprite3D.new()
	agua.name = "TexturaAgua"
	agua.position = Vector3(10.0, -0.4, -60.0)
	nivel.add_child(agua)
	parallax.registrar_sprite_agua_textura(agua)
	var sprites: Array[Sprite3D] = parallax.obtener_sprites_agua_textura()
	assert_gt(sprites.size(), 0, "TexturaAgua debe existir")
	var camara: Camera3D = nivel.find_child("CamaraPrincipal", true, false) as Camera3D
	assert_not_null(camara, "Debe existir la cámara principal")

	# Act: Forzar que el primer sprite salga por la izquierda del límite visible
	sprites[0].position.x = -100.0
	parallax._actualizar_loop_agua_textura(0.0)

	# Assert: Debe reaparecer fuera de vista a la derecha (sin pop visible)
	assert_gt(sprites[0].position.x, camara.global_position.x + parallax.margen_reciclaje_adelante - MARGEN_FLOAT, "TexturaAgua debe reaparecer fuera de vista")


# === TESTS DE REFLEJO ESPEJADO DE LA CORDILLERA ===
func test_reflejo_cordillera_inicializacion_y_segmentos() -> void:
	# Arrange & Act
	var parallax: ParallaxFondoRio = SCRIPT_PARALLAX.new() as ParallaxFondoRio
	add_child_autofree(parallax)

	# Assert
	var capa_reflejo := parallax.get_node_or_null("CapaReflejoCordillera") as Node3D
	assert_not_null(capa_reflejo, "Debe instanciar automáticamente CapaReflejoCordillera")

	var segmentos: Array[Node3D] = parallax.obtener_segmentos_reflejo()
	assert_eq(segmentos.size(), 12, "El reflejo debe contener 12 segmentos como la cordillera")

	for i in range(segmentos.size()):
		var seg := segmentos[i] as Node3D
		assert_not_null(seg, "Cada segmento del reflejo debe ser un Node3D válido")
		assert_lt(seg.scale.y, 0.0, "Cada segmento del reflejo debe estar invertido en Y (mirror)")
		if i > 0:
			var seg_ant := segmentos[i - 1] as Node3D
			assert_gt(seg.position.x, seg_ant.position.x, "Los segmentos del reflejo deben estar alineados de izquierda a derecha")


func test_reflejo_misma_velocidad_cordillera() -> void:
	# Arrange
	var packed := load(ESCENA_RIO_PATH) as PackedScene
	var nivel: Node3D = packed.instantiate() as Node3D
	add_child_autofree(nivel)

	var parallax: ParallaxFondoRio = nivel.find_child("ParallaxFondo", true, false) as ParallaxFondoRio
	var cordillera: Array[Node3D] = parallax.obtener_segmentos_cordillera()
	var reflejo: Array[Node3D] = parallax.obtener_segmentos_reflejo()
	assert_gt(cordillera.size(), 0, "Cordillera debe tener segmentos")
	assert_gt(reflejo.size(), 0, "Reflejo debe tener segmentos")

	var pos_inicial_cord: float = cordillera[0].position.x
	var pos_inicial_refl: float = reflejo[0].position.x

	# Act: Simular un avance de 1.0 segundo
	parallax._actualizar_loop_cordillera(1.0)
	parallax._actualizar_loop_reflejo(1.0)

	# Assert: Desplazamiento idéntico
	var delta_cord: float = pos_inicial_cord - cordillera[0].position.x
	var delta_refl: float = pos_inicial_refl - reflejo[0].position.x
	var desplazamiento_esperado: float = parallax.velocidad_base * parallax.factor_cordillera * 1.0

	assert_almost_eq(delta_cord, desplazamiento_esperado, MARGEN_FLOAT, "Desplazamiento cordillera")
	assert_almost_eq(delta_refl, desplazamiento_esperado, MARGEN_FLOAT, "Reflejo avanza al ritmo esperado")
	assert_almost_eq(delta_refl, delta_cord, MARGEN_FLOAT, "El reflejo debe moverse exactamente a la misma velocidad que la cordillera")


func test_reflejo_loop_continuo() -> void:
	# Arrange
	var packed := load(ESCENA_RIO_PATH) as PackedScene
	var nivel: Node3D = packed.instantiate() as Node3D
	add_child_autofree(nivel)

	var parallax: ParallaxFondoRio = nivel.find_child("ParallaxFondo", true, false) as ParallaxFondoRio
	var reflejo: Array[Node3D] = parallax.obtener_segmentos_reflejo()
	assert_gt(reflejo.size(), 0, "Reflejo debe tener segmentos")

	var x_max_inicial: float = -INF
	for seg in reflejo:
		if seg.position.x > x_max_inicial:
			x_max_inicial = seg.position.x

	# Act: Forzar que el primer segmento salga por la izquierda del límite visible
	reflejo[0].position.x = -100.0
	parallax._actualizar_loop_reflejo(0.0)

	# Assert: Debe recolocarse a la derecha con el ancho de la cordillera
	assert_almost_eq(reflejo[0].position.x, x_max_inicial + parallax.ancho_segmento_cordillera, MARGEN_FLOAT, "El reflejo debe hacer wrap continuo a la derecha")


# === TESTS DE PROTAGONISTA EN CANOA ALIADA ===
func test_canoa_rio_contiene_protagonista_controlable() -> void:
	# Arrange
	var packed := load(ESCENA_RIO_PATH) as PackedScene
	var nivel: Node3D = packed.instantiate() as Node3D
	add_child_autofree(nivel)

	# Act
	var canoa: Node3D = nivel.obtener_canoa()
	assert_not_null(canoa, "El nivel debe exponer la canoa protagonista")
	var prota := canoa.find_child("Protagonista", true, false) as CharacterBody3D

	# Assert: protagonista real y controlable, no el marinero decorativo
	assert_not_null(prota, "La canoa debe contener el nodo Protagonista")
	assert_true(prota is Player, "Protagonista debe ser la arquera jugable (Player)")
	assert_not_null(canoa.find_child("SueloCanoa", true, false), "La canoa debe tener suelo físico para la protagonista")


func test_protagonista_misma_escala_nivel1() -> void:
	# Arrange
	var packed := load(ESCENA_RIO_PATH) as PackedScene
	var nivel: Node3D = packed.instantiate() as Node3D
	add_child_autofree(nivel)

	# Act
	var canoa: Node3D = nivel.obtener_canoa()
	var prota := canoa.find_child("Protagonista", true, false) as Node3D
	assert_not_null(prota, "La canoa debe contener a la protagonista")

	# Assert: escala de nodo 0.356 (local 0.178 x canoa x2).
	# Altura visual real: 0.178 x 2 x 2.37 (modelo) = 0.84 m, par con NIVEL01 (0.71 m x1.2).
	var escala_mundo: Vector3 = prota.global_transform.basis.get_scale()
	assert_almost_eq(escala_mundo.x, 0.356, MARGEN_FLOAT, "Escala mundo X de nodo 0.356")
	assert_almost_eq(escala_mundo.y, 0.356, MARGEN_FLOAT, "Escala mundo Y de nodo 0.356")
	assert_almost_eq(escala_mundo.z, 0.356, MARGEN_FLOAT, "Escala mundo Z de nodo 0.356")


func test_defensora_misma_escala_nivel1() -> void:
	# Arrange
	var packed := load(ESCENA_RIO_PATH) as PackedScene
	var nivel: Node3D = packed.instantiate() as Node3D
	add_child_autofree(nivel)

	# Act
	var canoa: Node3D = nivel.obtener_canoa()
	var defensora := canoa.find_child("Acompanante", true, false) as Node3D
	assert_not_null(defensora, "La canoa debe contener a la defensora acompañante")

	# Assert: escala de nodo 0.34 (local 0.17 x canoa x2).
	# Tripulación de fondo sentada: 0.17 x 2 x 0.598 (modelo) = 0.20 m, menor que la protagonista.
	var escala_mundo: Vector3 = defensora.global_transform.basis.get_scale()
	var escala_esperada: float = 0.17 * 2.0
	assert_almost_eq(escala_esperada, 0.34, MARGEN_FLOAT, "La fórmula local debe dar 0.34")
	assert_almost_eq(escala_mundo.x, 0.34, MARGEN_FLOAT, "Defensora escala mundo X de nodo 0.34")
	assert_almost_eq(escala_mundo.y, 0.34, MARGEN_FLOAT, "Defensora escala mundo Y de nodo 0.34")
	assert_almost_eq(escala_mundo.z, 0.34, MARGEN_FLOAT, "Defensora escala mundo Z de nodo 0.34")


func test_protagonista_apoyada_en_suelo_canoa() -> void:
	# Arrange
	var packed := load(ESCENA_RIO_PATH) as PackedScene
	var nivel: Node3D = packed.instantiate() as Node3D
	add_child_autofree(nivel)

	# Act
	var canoa: Node3D = nivel.obtener_canoa()
	var prota := canoa.find_child("Protagonista", true, false) as Node3D
	var suelo := canoa.find_child("SueloCanoa", true, false) as StaticBody3D
	assert_not_null(prota, "La canoa debe contener a la protagonista")
	assert_not_null(suelo, "La canoa debe contener el suelo")

	# Assert: los pies (origen) quedan sobre la cara superior del suelo y dentro de su planta
	var colision := suelo.find_child("CollisionShape3D", true, false) as CollisionShape3D
	assert_not_null(colision, "SueloCanoa debe tener forma de colisión")
	var caja := colision.shape as BoxShape3D
	var relativo: Vector3 = suelo.to_local(prota.global_position)
	var cara_superior_y: float = colision.position.y + (caja.size.y / 2.0)
	assert_almost_eq(relativo.y, cara_superior_y, 0.05, "Los pies deben apoyar sobre el suelo")
	assert_true(absf(relativo.x) <= (caja.size.x * colision.scale.x) / 2.0 + 0.5, "La protagonista debe estar dentro del largo del suelo")
	assert_true(absf(relativo.z) <= caja.size.z / 2.0 + 0.1, "La protagonista debe estar dentro del ancho del suelo")


# === TESTS DE PASAJERA SUJETA A LA CANOA ===
func test_pasajera_no_sale_de_la_canoa() -> void:
	# Arrange
	var packed := load("res://Levels/Rio_En_Canoa_Con_Parallax/CanoaProtagonistaRio.tscn") as PackedScene
	var canoa: CanoaProtagonistaRio = packed.instantiate() as CanoaProtagonistaRio
	add_child_autofree(canoa)
	var prota := canoa.find_child("Protagonista", true, false) as Node3D
	assert_not_null(prota, "La canoa debe contener a la protagonista")

	# Act: forzarla fuera de los límites
	prota.position = Vector3(5.0, 0.3, -5.0)
	canoa._sujetar_pasajera()

	# Assert: recortada a los límites configurados
	assert_almost_eq(prota.position.x, canoa.limite_pasajera_x.y, MARGEN_FLOAT, "X debe recortarse al máximo")
	assert_almost_eq(prota.position.z, canoa.limite_pasajera_z.x, MARGEN_FLOAT, "Z debe recortarse al mínimo")
	assert_almost_eq(prota.position.y, 0.3, MARGEN_FLOAT, "Y no debe alterarse al sujetar")


func test_pasajera_dentro_de_limites_no_se_mueve() -> void:
	# Arrange
	var packed := load("res://Levels/Rio_En_Canoa_Con_Parallax/CanoaProtagonistaRio.tscn") as PackedScene
	var canoa: CanoaProtagonistaRio = packed.instantiate() as CanoaProtagonistaRio
	add_child_autofree(canoa)
	var prota := canoa.find_child("Protagonista", true, false) as Node3D
	assert_not_null(prota, "La canoa debe contener a la protagonista")

	# Act
	prota.position = Vector3(0.0, 0.3, 0.0)
	canoa._sujetar_pasajera()

	# Assert
	assert_almost_eq(prota.position.x, 0.0, MARGEN_FLOAT, "X dentro de límites no cambia")
	assert_almost_eq(prota.position.z, 0.0, MARGEN_FLOAT, "Z dentro de límites no cambia")


func test_pasajera_visible_sobre_borda() -> void:
	# Arrange
	var packed := load("res://Levels/Rio_En_Canoa_Con_Parallax/CanoaProtagonistaRio.tscn") as PackedScene
	var canoa: CanoaProtagonistaRio = packed.instantiate() as CanoaProtagonistaRio
	add_child_autofree(canoa)

	# Act
	var prota := canoa.find_child("Protagonista", true, false) as Node3D
	assert_not_null(prota, "La canoa debe contener a la protagonista")

	# Assert: la cabeza (2.0 de alto a escala local) supera la borda media (0.17)
	var altura_cabeza: float = prota.position.y + 2.0 * prota.scale.y
	assert_gt(altura_cabeza, 0.17, "La cabeza debe asomar por encima de la borda")


# === TESTS DE CASA BONETA ACOPLADA A LA CORDILLERA ===
func test_casa_boneta_deteccion_en_escena_rio() -> void:
	# Arrange & Act: escena del usuario
	var packed := load(ESCENA_RIO_PATH) as PackedScene
	assert_not_null(packed, "La escena del río debe cargar correctamente")
	var nivel: Node3D = packed.instantiate() as Node3D
	add_child_autofree(nivel)

	var parallax: ParallaxFondoRio = nivel.find_child("ParallaxFondo", true, false) as ParallaxFondoRio
	assert_not_null(parallax, "ParallaxFondo debe existir")

	# Assert: CasaBoneta posicionable detectada y registrada
	var casa: Node3D = nivel.find_child("CasaBoneta", true, false) as Node3D
	assert_not_null(casa, "CasaBoneta debe existir")
	var segmentos: Array[Node3D] = parallax.obtener_segmentos_casa_boneta()
	assert_true(segmentos.has(casa), "Parallax debe registrar CasaBoneta")


func test_casa_boneta_misma_velocidad_cordillera() -> void:
	# Arrange
	var packed := load(ESCENA_RIO_PATH) as PackedScene
	var nivel: Node3D = packed.instantiate() as Node3D
	add_child_autofree(nivel)

	var parallax: ParallaxFondoRio = nivel.find_child("ParallaxFondo", true, false) as ParallaxFondoRio
	var casas: Array[Node3D] = parallax.obtener_segmentos_casa_boneta()
	assert_gt(casas.size(), 0, "CasaBoneta debe existir")
	var cordillera: Array[Node3D] = parallax.obtener_segmentos_cordillera()
	assert_gt(cordillera.size(), 0, "Cordillera debe tener segmentos")

	var pos_inicial_cord: float = cordillera[0].position.x
	var pos_inicial_casa: float = casas[0].position.x

	# Act: Simular un avance de 1.0 segundo
	parallax._actualizar_loop_cordillera(1.0)
	parallax._actualizar_loop_casa_boneta(1.0)

	# Assert: Desplazamiento idéntico al de la cordillera
	var delta_cord: float = pos_inicial_cord - cordillera[0].position.x
	var delta_casa: float = pos_inicial_casa - casas[0].position.x
	var desplazamiento_esperado: float = parallax.velocidad_base * parallax.factor_cordillera * 1.0

	assert_almost_eq(delta_cord, desplazamiento_esperado, MARGEN_FLOAT, "Desplazamiento cordillera")
	assert_almost_eq(delta_casa, desplazamiento_esperado, MARGEN_FLOAT, "CasaBoneta avanza al ritmo esperado")
	assert_almost_eq(delta_casa, delta_cord, MARGEN_FLOAT, "CasaBoneta debe moverse exactamente a la misma velocidad que la cordillera")


func test_casa_boneta_reciclaje_fuera_de_vista() -> void:
	# Arrange
	var packed := load(ESCENA_RIO_PATH) as PackedScene
	var nivel: Node3D = packed.instantiate() as Node3D
	add_child_autofree(nivel)

	var parallax: ParallaxFondoRio = nivel.find_child("ParallaxFondo", true, false) as ParallaxFondoRio
	var camara: Camera3D = nivel.find_child("CamaraPrincipal", true, false) as Camera3D
	assert_not_null(camara, "Debe existir la cámara principal")
	var casas: Array[Node3D] = parallax.obtener_segmentos_casa_boneta()
	assert_gt(casas.size(), 0, "CasaBoneta debe existir")
	var pisos: Array[Node3D] = parallax.obtener_segmentos_piso_aliado()
	assert_gt(pisos.size(), 0, "Debe haber piso para anclar")

	# Act: forzar que la primera casa salga por la izquierda del límite visible
	casas[0].position.x = camara.global_position.x - parallax.margen_reciclaje_atras - 10.0
	parallax._actualizar_loop_casa_boneta(0.0)

	# Assert: reaparece sobre una baldosa (nunca flotando) y fuera de atrás
	var xs_piso: Array = []
	for piso in pisos:
		xs_piso.append((piso as Node3D).global_position.x)
	assert_true(xs_piso.has(casas[0].global_position.x), "La casa debe caer sobre una baldosa")
	assert_gt(casas[0].global_position.x, camara.global_position.x - 5.0, "No debe quedar atrás")


func test_casa_boneta_conserva_grupo_delante() -> void:
	# Arrange
	var packed := load(ESCENA_RIO_PATH) as PackedScene
	var nivel: Node3D = packed.instantiate() as Node3D
	add_child_autofree(nivel)

	var parallax: ParallaxFondoRio = nivel.find_child("ParallaxFondo", true, false) as ParallaxFondoRio
	var camara: Camera3D = nivel.find_child("CamaraPrincipal", true, false) as Camera3D
	var casas: Array[Node3D] = parallax.obtener_segmentos_casa_boneta()
	assert_gt(casas.size(), 0, "CasaBoneta debe existir")
	var pisos: Array[Node3D] = parallax.obtener_segmentos_piso_aliado()
	assert_gt(pisos.size(), 0, "Debe haber piso para anclar")

	# Act: todas las casas quedan atrás y se reciclan
	for casa in casas:
		(casa as Node3D).position.x = camara.global_position.x - parallax.margen_reciclaje_atras - 1.0
	parallax._actualizar_loop_casa_boneta(0.0)

	# Assert: todas sobre baldosas y fuera de atrás
	var xs_piso: Array = []
	for piso in pisos:
		xs_piso.append((piso as Node3D).global_position.x)
	for casa in casas:
		assert_true(xs_piso.has((casa as Node3D).global_position.x), "Cada casa debe caer sobre una baldosa")
		assert_gt((casa as Node3D).global_position.x, camara.global_position.x - 5.0, "Ninguna queda atrás")


# === TESTS DE MÚSICA DEL NIVEL ===
func test_musica_viaje_rio_registrada() -> void:
	# Arrange & Act
	var total: int = AudioManager.bgm_streams.size()

	# Assert: índice 7 con la canción cargada
	assert_gte(total, 8, "Debe existir el índice 7 de música")
	assert_not_null(AudioManager.bgm_streams[7], "Viaje por el rio debe estar cargado en el índice 7")


func test_nivel_rio_pide_musica_viaje() -> void:
	# Arrange
	var packed := load(ESCENA_RIO_PATH) as PackedScene
	var nivel: RioEnCanoaConParallax = packed.instantiate() as RioEnCanoaConParallax
	add_child_autofree(nivel)

	# Assert
	assert_eq(nivel.MUSICA_VIAJE_RIO, 7, "El nivel debe apuntar al índice 7")
	assert_true(nivel.musica_viaje_rio, "La música debe estar activada por defecto")


# === TESTS DE BOSQUE ROJO CON PARALLAX PROPIO ===
func test_bosque_rojo_deteccion_en_escena_rio() -> void:
	# Arrange & Act: escena del usuario
	var packed := load(ESCENA_RIO_PATH) as PackedScene
	assert_not_null(packed, "La escena del río debe cargar correctamente")
	var nivel: Node3D = packed.instantiate() as Node3D
	add_child_autofree(nivel)

	var parallax: ParallaxFondoRio = nivel.find_child("ParallaxFondo", true, false) as ParallaxFondoRio
	assert_not_null(parallax, "ParallaxFondo debe existir")

	# Assert: BosqueRojo posicionable detectado y registrado
	var bosque: Sprite3D = nivel.find_child("BosqueRojo", true, false) as Sprite3D
	assert_not_null(bosque, "BosqueRojo debe existir")
	var sprites: Array[Sprite3D] = parallax.obtener_sprites_bosque_rojo()
	assert_true(sprites.has(bosque), "Parallax debe registrar BosqueRojo")


func test_bosque_rojo_mas_lento_que_cordillera() -> void:
	# Arrange
	var packed := load(ESCENA_RIO_PATH) as PackedScene
	var nivel: Node3D = packed.instantiate() as Node3D
	add_child_autofree(nivel)

	var parallax: ParallaxFondoRio = nivel.find_child("ParallaxFondo", true, false) as ParallaxFondoRio
	var sprites: Array[Sprite3D] = parallax.obtener_sprites_bosque_rojo()
	assert_gt(sprites.size(), 0, "BosqueRojo debe existir")
	var cordillera: Array[Node3D] = parallax.obtener_segmentos_cordillera()
	assert_gt(cordillera.size(), 0, "Cordillera debe tener segmentos")

	# Assert: el factor propio es menor (más lejos = más lento)
	assert_lt(parallax.factor_bosque_rojo, parallax.factor_cordillera, "El bosque debe moverse más lento que la cordillera")

	var pos_inicial_cord: float = cordillera[0].position.x
	var pos_inicial_bosque: float = sprites[0].position.x

	# Act: Simular un avance de 1.0 segundo
	parallax._actualizar_loop_cordillera(1.0)
	parallax._actualizar_loop_bosque_rojo(1.0)

	# Assert: cada uno avanza a su ritmo
	var delta_cord: float = pos_inicial_cord - cordillera[0].position.x
	var delta_bosque: float = pos_inicial_bosque - sprites[0].position.x

	assert_almost_eq(delta_cord, parallax.velocidad_base * parallax.factor_cordillera, MARGEN_FLOAT, "Desplazamiento cordillera")
	assert_almost_eq(delta_bosque, parallax.velocidad_base * parallax.factor_bosque_rojo, MARGEN_FLOAT, "Bosque avanza a su ritmo propio")
	assert_lt(delta_bosque, delta_cord, "El bosque debe avanzar menos que la cordillera")


func test_bosque_rojo_loop_continuo() -> void:
	# Arrange
	var packed := load(ESCENA_RIO_PATH) as PackedScene
	var nivel: Node3D = packed.instantiate() as Node3D
	add_child_autofree(nivel)

	var parallax: ParallaxFondoRio = nivel.find_child("ParallaxFondo", true, false) as ParallaxFondoRio
	var sprites: Array[Sprite3D] = parallax.obtener_sprites_bosque_rojo()
	assert_gt(sprites.size(), 0, "BosqueRojo debe existir")
	var camara: Camera3D = nivel.find_child("CamaraPrincipal", true, false) as Camera3D
	assert_not_null(camara, "Debe existir la cámara principal")

	# Act: Forzar que el primer sprite salga por la izquierda del límite visible
	sprites[0].position.x = -100.0
	parallax._actualizar_loop_bosque_rojo(0.0)

	# Assert: Debe reaparecer fuera de vista a la derecha (sin pop visible)
	assert_gt(sprites[0].position.x, camara.global_position.x + parallax.margen_reciclaje_adelante - MARGEN_FLOAT, "BosqueRojo debe reaparecer fuera de vista")


# === TESTS DE ACELERACIÓN DEBUG CON TECLA Z ===
func test_aceleracion_debug_configuracion_por_defecto() -> void:
	# Arrange & Act
	var packed := load(ESCENA_RIO_PATH) as PackedScene
	var nivel: RioEnCanoaConParallax = packed.instantiate() as RioEnCanoaConParallax
	add_child_autofree(nivel)

	# Assert
	assert_true(nivel.permitir_aceleracion_debug, "La aceleración debug debe estar habilitada por defecto")
	assert_almost_eq(nivel.multiplicador_aceleracion, 6.0, MARGEN_FLOAT, "El multiplicador por defecto debe ser 6.0")
	assert_false(nivel.modo_toggle_z, "El modo toggle debe estar deshabilitado por defecto (mantener presionado)")
	assert_false(nivel.esta_acelerando_debug(), "No debe estar acelerando al iniciar")


func test_set_aceleracion_debug_multiplica_canoa_y_parallax() -> void:
	# Arrange
	var packed := load(ESCENA_RIO_PATH) as PackedScene
	var nivel: RioEnCanoaConParallax = packed.instantiate() as RioEnCanoaConParallax
	add_child_autofree(nivel)

	var canoa: CanoaAliada = nivel.obtener_canoa()
	var parallax: ParallaxFondoRio = nivel.obtener_parallax() as ParallaxFondoRio
	assert_not_null(canoa, "La canoa debe existir")
	assert_not_null(parallax, "El parallax debe existir")

	var vel_c_base: float = nivel.obtener_velocidad_canoa_base()
	var vel_p_base: float = nivel.obtener_velocidad_parallax_base()
	var factor: float = nivel.multiplicador_aceleracion

	# Act: Activar aceleración
	nivel.set_aceleracion_debug(true)

	# Assert
	assert_true(nivel.esta_acelerando_debug(), "El estado debe indicar que está acelerando")
	assert_almost_eq(nivel.velocidad_canoa, vel_c_base * factor, MARGEN_FLOAT, "Velocidad canoa nivel acelerada")
	assert_almost_eq(nivel.velocidad_parallax, vel_p_base * factor, MARGEN_FLOAT, "Velocidad parallax nivel acelerada")
	assert_almost_eq(float(canoa.get("velocidad_avance")), vel_c_base * factor, MARGEN_FLOAT, "Canoa velocidad de avance acelerada")
	assert_almost_eq(parallax.velocidad_base, vel_p_base * factor, MARGEN_FLOAT, "Parallax velocidad base acelerada")

	# Act: Desactivar aceleración
	nivel.set_aceleracion_debug(false)

	# Assert
	assert_false(nivel.esta_acelerando_debug(), "El estado debe indicar que ya no acelera")
	assert_almost_eq(nivel.velocidad_canoa, vel_c_base, MARGEN_FLOAT, "Velocidad canoa restaurada a base")
	assert_almost_eq(nivel.velocidad_parallax, vel_p_base, MARGEN_FLOAT, "Velocidad parallax restaurada a base")
	assert_almost_eq(float(canoa.get("velocidad_avance")), vel_c_base, MARGEN_FLOAT, "Canoa velocidad restaurada a base")
	assert_almost_eq(parallax.velocidad_base, vel_p_base, MARGEN_FLOAT, "Parallax velocidad restaurada a base")


func test_input_tecla_z_activa_y_desactiva_aceleracion() -> void:
	# Arrange
	var packed := load(ESCENA_RIO_PATH) as PackedScene
	var nivel: RioEnCanoaConParallax = packed.instantiate() as RioEnCanoaConParallax
	add_child_autofree(nivel)

	var ev_press := InputEventKey.new()
	ev_press.keycode = KEY_Z
	ev_press.pressed = true
	ev_press.echo = false

	var ev_release := InputEventKey.new()
	ev_release.keycode = KEY_Z
	ev_release.pressed = false
	ev_release.echo = false

	# Act: Presionar tecla Z
	nivel._input(ev_press)

	# Assert: Debe estar acelerando
	assert_true(nivel.esta_acelerando_debug(), "Al presionar tecla Z debe acelerar")

	# Act: Soltar tecla Z
	nivel._input(ev_release)

	# Assert: Debe volver a velocidad normal
	assert_false(nivel.esta_acelerando_debug(), "Al soltar tecla Z debe regresar a normal")


func test_modo_toggle_z_conmuta_estado() -> void:
	# Arrange
	var packed := load(ESCENA_RIO_PATH) as PackedScene
	var nivel: RioEnCanoaConParallax = packed.instantiate() as RioEnCanoaConParallax
	add_child_autofree(nivel)
	nivel.modo_toggle_z = true

	var ev_press := InputEventKey.new()
	ev_press.keycode = KEY_Z
	ev_press.pressed = true
	ev_press.echo = false

	var ev_release := InputEventKey.new()
	ev_release.keycode = KEY_Z
	ev_release.pressed = false
	ev_release.echo = false

	# Act: Primer toque (press y release)
	nivel._input(ev_press)
	nivel._input(ev_release)

	# Assert: Permanece acelerado tras soltar Z
	assert_true(nivel.esta_acelerando_debug(), "En modo toggle, debe mantenerse acelerado tras soltar Z")

	# Act: Segundo toque (press y release)
	nivel._input(ev_press)
	nivel._input(ev_release)

	# Assert: Vuelve a velocidad normal
	assert_false(nivel.esta_acelerando_debug(), "En modo toggle, el segundo toque debe desactivar la aceleración")


func test_desactivar_travesia_cancela_aceleracion() -> void:
	# Arrange
	var packed := load(ESCENA_RIO_PATH) as PackedScene
	var nivel: RioEnCanoaConParallax = packed.instantiate() as RioEnCanoaConParallax
	add_child_autofree(nivel)

	nivel.set_aceleracion_debug(true)
	assert_true(nivel.esta_acelerando_debug(), "Debe iniciar acelerado")

	# Act: Pausar travesía
	nivel.set_travesia_activa(false)

	# Assert: Aceleración cancelada
	assert_false(nivel.esta_acelerando_debug(), "Pausar la travesía debe cancelar la aceleración debug")


# === TESTS DE ÁRBOLES ACOPLADOS A LA CORDILLERA ===
func test_arbol_cordillera_deteccion_solo_etiquetados() -> void:
	# Arrange
	var parallax: ParallaxFondoRio = SCRIPT_PARALLAX.new() as ParallaxFondoRio
	add_child_autofree(parallax)
	var bueno := Node3D.new()
	bueno.name = "ArbolLow(cordillera)"
	var malo := Node3D.new()
	malo.name = "ArbolLowPoly"
	parallax.add_child(bueno)
	parallax.add_child(malo)

	# Act
	parallax._inicializar_capa_arbol_cordillera()

	# Assert: solo los que dicen (cordillera) entran al parallax
	var segs: Array[Node3D] = parallax.obtener_segmentos_arbol_cordillera()
	assert_true(segs.has(bueno), "Debe registrar ArbolLow(cordillera)")
	assert_false(segs.has(malo), "No debe registrar árboles sin etiqueta")


func test_arbol_cordillera_misma_velocidad() -> void:
	# Arrange
	var parallax: ParallaxFondoRio = SCRIPT_PARALLAX.new() as ParallaxFondoRio
	add_child_autofree(parallax)
	var arbol := Node3D.new()
	arbol.name = "ArbolLow(cordillera)"
	arbol.position = Vector3(10.0, 0.0, -50.0)
	parallax.add_child(arbol)
	parallax._inicializar_capa_arbol_cordillera()
	var cordillera: Array[Node3D] = parallax.obtener_segmentos_cordillera()
	assert_gt(cordillera.size(), 0, "Cordillera debe tener segmentos")

	var pos_inicial_cord: float = cordillera[0].position.x
	var pos_inicial_arbol: float = arbol.position.x

	# Act: Simular un avance de 1.0 segundo
	parallax._actualizar_loop_cordillera(1.0)
	parallax._actualizar_loop_arbol_cordillera(1.0)

	# Assert: Desplazamiento idéntico al de la cordillera
	var delta_cord: float = pos_inicial_cord - cordillera[0].position.x
	var delta_arbol: float = pos_inicial_arbol - arbol.position.x
	var desplazamiento_esperado: float = parallax.velocidad_base * parallax.factor_cordillera * 1.0

	assert_almost_eq(delta_cord, desplazamiento_esperado, MARGEN_FLOAT, "Desplazamiento cordillera")
	assert_almost_eq(delta_arbol, desplazamiento_esperado, MARGEN_FLOAT, "Árbol avanza al ritmo esperado")
	assert_almost_eq(delta_arbol, delta_cord, MARGEN_FLOAT, "El árbol debe moverse exactamente a la misma velocidad que la cordillera")


func test_arbol_cordillera_reciclaje_fuera_de_vista() -> void:
	# Arrange
	var parallax: ParallaxFondoRio = SCRIPT_PARALLAX.new() as ParallaxFondoRio
	add_child_autofree(parallax)
	var arbol := Node3D.new()
	arbol.name = "ArbolLow(cordillera)"
	parallax.add_child(arbol)
	parallax._inicializar_capa_arbol_cordillera()

	# Act: forzar que salga por la izquierda (sin cámara: referencia x = 0)
	arbol.position.x = -100.0
	parallax._actualizar_loop_arbol_cordillera(0.0)

	# Assert: reaparece delante fuera de vista, no junto al grupo visible
	assert_almost_eq(arbol.position.x, parallax.margen_reciclaje_adelante, MARGEN_FLOAT, "Debe reaparecer fuera de vista a la derecha")


func test_sonido_canoa_stream_asignado_y_volumen_audible() -> void:
	# Arrange & Act
	var packed_canoa := load(ESCENA_CANOA_PATH) as PackedScene
	var canoa: CanoaProtagonistaRio = packed_canoa.instantiate() as CanoaProtagonistaRio
	add_child_autofree(canoa)

	var audio: AudioStreamPlayer = canoa.obtener_audio_navegacion()
	assert_not_null(audio, "La canoa debe poseer un AudioStreamPlayer para el sonido de navegación")
	assert_not_null(audio.stream, "El AudioStreamPlayer debe tener cargado el stream de sonido_canoa_por_el_rio")
	assert_eq(audio.stream.resource_path, "res://TEST_/sonido_canoa_por_el_rio.mp3", "Ruta de sonido_canoa_por_el_rio.mp3 correcta")
	assert_between(audio.volume_db, -20.0, 0.0, "El volumen debe ser sutil y natural (<= 0 dB) para no sobrecargar la mezcla")
	assert_eq(audio.bus, &"Master", "Debe reproducirse en el bus Master")


func test_sonido_canoa_reproduccion_en_travesia() -> void:
	# Arrange
	var packed_canoa := load(ESCENA_CANOA_PATH) as PackedScene
	var canoa: CanoaProtagonistaRio = packed_canoa.instantiate() as CanoaProtagonistaRio
	add_child_autofree(canoa)

	# Act: Iniciar travesía
	canoa.iniciar_travesia()
	var audio: AudioStreamPlayer = canoa.obtener_audio_navegacion()

	# Assert: Navegando y reproduciendo
	assert_true(canoa.esta_navegando(), "La canoa debe estar en estado de navegación")
	assert_true(audio.playing, "El sonido de navegación debe estar activo mientras avanza")

	# Act: Detener canoa
	canoa.detener()

	# Assert: Audio detenido
	assert_false(canoa.esta_navegando(), "La canoa debe detenerse")
	assert_false(audio.playing, "El sonido de navegación debe silenciarse al detener la canoa")


func test_sonido_canoa_loop_continuo() -> void:
	# Arrange
	var stream: AudioStreamMP3 = load("res://TEST_/sonido_canoa_por_el_rio.mp3") as AudioStreamMP3
	assert_not_null(stream, "El recurso de audio debe existir")

	# Assert
	assert_true(stream.loop, "El stream MP3 de la canoa debe estar configurado con loop = true")


# === TESTS DE ÁRBOLES ASENTADOS SOBRE PISO ===
func test_arbol_reciclado_cae_sobre_piso() -> void:	# Arrange
	var parallax: ParallaxFondoRio = SCRIPT_PARALLAX.new() as ParallaxFondoRio
	add_child_autofree(parallax)
	var piso := Node3D.new()
	piso.name = "PisoTest"
	piso.position = Vector3(50.0, -1.0, -80.0)
	piso.scale = Vector3(5.75, 7.06, 3.57)
	parallax.add_child(piso)
	parallax._segmentos_piso_aliado.append(piso)
	var arbol := Node3D.new()
	arbol.name = "ArbolLow(cordillera)"
	arbol.position = Vector3(-100.0, 5.0, -39.0)
	parallax.add_child(arbol)
	parallax._segmentos_arbol_cordillera.append(arbol)

	# Act: sale por la izquierda y se recicla
	parallax._actualizar_loop_arbol_cordillera(0.0)

	# Assert: sobre la baldosa (nunca flotando)
	assert_almost_eq(arbol.global_position.x, 50.0, MARGEN_FLOAT, "X sobre la baldosa")
	assert_almost_eq(arbol.global_position.z, -80.0, MARGEN_FLOAT, "Z sobre la baldosa")
	assert_almost_eq(arbol.global_position.y, -0.3505, 0.01, "Base sobre la cara superior")


func test_arboles_se_asientan_solos_aunque_falle_init() -> void:
	# Arrange: parallax sin pasar por el init de asentado, con piso disponible
	var parallax: ParallaxFondoRio = SCRIPT_PARALLAX.new() as ParallaxFondoRio
	add_child_autofree(parallax)
	var piso := Node3D.new()
	piso.name = "PisoTest"
	piso.position = Vector3(50.0, -1.0, -80.0)
	piso.scale = Vector3(5.75, 7.06, 3.57)
	parallax.add_child(piso)
	parallax._segmentos_piso_aliado.append(piso)
	var arbol := Node3D.new()
	arbol.name = "ArbolLow(cordillera)"
	arbol.position = Vector3(0.0, 5.0, -39.0)
	parallax.add_child(arbol)
	parallax._segmentos_arbol_cordillera.append(arbol)
	assert_false(parallax._arboles_asentados, "Precondición: aún no asentados")

	# Act: un frame del loop (sin init previo de asentado)
	parallax._actualizar_loop_arbol_cordillera(0.016)

	# Assert: se asientan solos sobre el piso
	assert_true(parallax._arboles_asentados, "Debe marcarse como asentado")
	assert_almost_eq(arbol.global_position.x, 50.0, MARGEN_FLOAT, "X sobre la baldosa")
	assert_almost_eq(arbol.global_position.z, -80.0, MARGEN_FLOAT, "Z sobre la baldosa")


# === TESTS DE BANDERA MORADA ===
func test_bandera_morada_textura_y_shader_asignados() -> void:
	# Arrange
	var packed := load("res://Levels/Rio_En_Canoa_Con_Parallax/BanderaMorada.tscn") as PackedScene
	assert_not_null(packed, "La escena BanderaMorada.tscn debe cargar correctamente")
	var bandera := packed.instantiate() as Sprite3D
	add_child_autofree(bandera)

	# Assert
	assert_not_null(bandera.texture, "BanderaMorada debe tener textura asignada")
	assert_eq(bandera.texture.resource_path, "res://TEST_/bandera morada.png", "La textura debe ser bandera morada.png")
	assert_not_null(bandera.material_override, "BanderaMorada debe tener material_override")
	assert_true(bandera.material_override is ShaderMaterial, "material_override debe ser ShaderMaterial")
	var mat := bandera.material_override as ShaderMaterial
	assert_not_null(mat.get_shader_parameter("albedo_texture"), "albedo_texture del shader NO debe ser null para evitar que se vea blanca")
	assert_eq(mat.get_shader_parameter("albedo_texture").resource_path, "res://TEST_/bandera morada.png")


func test_bandera_morada_escena_instanciable() -> void:
	# Arrange
	var packed := load("res://Levels/Rio_En_Canoa_Con_Parallax/BanderaMorada.tscn") as PackedScene
	assert_not_null(packed, "La escena empaquetada BanderaMorada.tscn debe existir")

	# Act
	var bandera := packed.instantiate() as Sprite3D
	add_child_autofree(bandera)

	# Assert
	assert_not_null(bandera.texture, "Debe poseer la textura de bandera morada por defecto")
	assert_not_null(bandera.material_override, "Debe tener configurado su material de ondeado")
	var mat := bandera.material_override as ShaderMaterial
	assert_not_null(mat.get_shader_parameter("albedo_texture"), "albedo_texture debe estar preconfigurada")


# === TESTS DE PREVENCIÓN DE ÁRBOLES FLOTANTES EN EL FONDO ===
func test_bosque_rojo_base_enterrada_y_sin_huecos() -> void:
	# Arrange
	var packed := load(ESCENA_RIO_PATH) as PackedScene
	assert_not_null(packed, "La escena del río debe cargar correctamente")
	var nivel: Node3D = packed.instantiate() as Node3D
	add_child_autofree(nivel)

	var parallax: ParallaxFondoRio = nivel.find_child("ParallaxFondo", true, false) as ParallaxFondoRio
	assert_not_null(parallax, "ParallaxFondo debe existir")

	# Assert 1: Ancho de segmento continuo (<= 45m para cubrir con solape sprites de 42m)
	assert_lte(parallax.ancho_segmento_bosque_rojo, 45.0, "El ancho de segmento de BosqueRojo debe ser <= 45m para evitar huecos en el fondo")

	# Assert 2: Cada sprite de BosqueRojo tiene su base enterrada por debajo de Y = -2.5
	var sprites: Array[Sprite3D] = parallax.obtener_sprites_bosque_rojo()
	assert_gt(sprites.size(), 0, "Deben existir sprites de BosqueRojo")
	for s in sprites:
		var tex_h: float = float(s.texture.get_height()) if s.texture else 1200.0
		# Row 1199 es el fondo de los árboles (599 px bajo el centro)
		var base_y: float = s.global_position.y - (tex_h * 0.5) * s.pixel_size * s.scale.y
		assert_lte(base_y, -2.5, "La base de %s debe estar enterrada bajo -2.5m (base_y=%.2f) para no flotar en valles" % [s.name, base_y])


func test_arboles_capa_terroso_base_enterrada() -> void:
	# Arrange
	var packed := load(ESCENA_RIO_PATH) as PackedScene
	var nivel: Node3D = packed.instantiate() as Node3D
	add_child_autofree(nivel)

	var parallax: ParallaxFondoRio = nivel.find_child("ParallaxFondo", true, false) as ParallaxFondoRio
	var capa_terroso := parallax.get_node_or_null("CapaTerroso") as Node3D
	assert_not_null(capa_terroso, "CapaTerroso debe existir")

	# Assert: Los sprites Arboles_* deben tener su base por debajo de -2.5 en coordenadas de mundo
	for c in capa_terroso.get_children():
		if c is Sprite3D and c.name.begins_with("Arbol"):
			var s := c as Sprite3D
			var tex_h: float = float(s.texture.get_height()) if s.texture else 240.0
			var world_y: float = s.global_position.y
			var base_y: float = world_y - (tex_h * 0.5) * s.pixel_size * s.scale.y
			assert_lte(base_y, -2.5, "La base de %s debe estar bajo -2.5m (base_y=%.2f) para no verse flotando" % [s.name, base_y])


func test_piso_parada_excluido_de_pisos_aliados() -> void:
	# Arrange
	var packed := load(ESCENA_RIO_PATH) as PackedScene
	var nivel: Node3D = packed.instantiate() as Node3D
	add_child_autofree(nivel)

	var parallax: ParallaxFondoRio = nivel.find_child("ParallaxFondo", true, false) as ParallaxFondoRio
	var pisos: Array[Node3D] = parallax.obtener_segmentos_piso_aliado()

	# Assert: Piso parada 1 y 2 no deben estar incluidos
	for p in pisos:
		assert_false(p.name.to_lower().contains("parada"), "Piso parada '%s' NO debe estar en los pisos móviles del parallax" % p.name)
