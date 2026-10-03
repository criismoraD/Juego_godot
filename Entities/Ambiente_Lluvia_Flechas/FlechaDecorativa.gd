class_name FlechaDecorativa
extends Node3D

## Flecha individual decorativa de fondo.
## Emula el proyectil de la Goblin Morada (Goblin Girl):
## Trayectoria parabólica, rotación tangente a la velocidad, estilo toon brillante
## con contorno negro y estela de partículas, sin interacción de daño.

signal finalizada(flecha: Node3D)

const ESCENA_MODELO_FLECHA: PackedScene = preload("res://Recursos_Compartidos/FLECHA_ARQUERA_ENEMIGA.glb")
const MIN_LONGITUD_DIRECCION_SQ: float = 0.0001
const TRANSFORM_MODELO_BASE: Transform3D = Transform3D(
	Basis(
		Vector3(-8.742278e-08, 0.0, 0.6106571),
		Vector3(0.0, 1.7377698, 0.0),
		Vector3(-2.0, 0.0, -2.6692668e-08)
	),
	Vector3(0.297046, 0.0, 0.0)
)
const DURACION_DESVANECIMIENTO: float = 0.35

var direccion: Vector3 = Vector3.LEFT
var velocidad: float = 14.0
var gravedad: float = 0.85
var tiempo_vida_max: float = 4.5
var tiempo_vida_actual: float = 0.0
var y_suelo_impacto: float = -4.0
var usar_suelo_impacto: bool = true
var duracion_clavada: float = 1.2
var esta_clavada: bool = false
var esta_activa: bool = false
var profundidad_z_fija: float = 0.0

var _modelo_flecha: Node3D = null
var _mallas_cacheadas: Array[MeshInstance3D] = []
var _particulas_estela: GPUParticles3D = null
var _tiempo_clavada_actual: float = 0.0
var _desvaneciendo: bool = false
var _alpha_actual: float = 1.0


func _ready() -> void:
	_inicializar_estructura_visual()
	set_process(false)
	visible = false


func _process(delta: float) -> void:
	if not esta_activa:
		return

	if _desvaneciendo:
		_actualizar_desvanecimiento(delta)
		return

	if esta_clavada:
		_tiempo_clavada_actual += delta
		if _tiempo_clavada_actual >= duracion_clavada:
			_iniciar_desvanecimiento()
		return

	# 1. Movimiento balístico parabólico
	direccion.y -= gravedad * delta
	global_position += direccion * velocidad * delta
	global_position.z = profundidad_z_fija

	# 2. Rotación continua alineada a la trayectoria
	if direccion.length_squared() > MIN_LONGITUD_DIRECCION_SQ:
		rotation = Vector3(0.0, 0.0, atan2(direccion.y, direccion.x))

	# 3. Verificación de impacto en suelo de fondo
	if usar_suelo_impacto and global_position.y <= y_suelo_impacto:
		_clavar()
		return

	# 4. Verificación de tiempo de vida
	tiempo_vida_actual += delta
	if tiempo_vida_actual >= tiempo_vida_max:
		_iniciar_desvanecimiento()


## Lanza la flecha decorativa desde el pool con todos sus parámetros configurados.
func lanzar(
	pos_inicial: Vector3,
	dir_inicial: Vector3,
	vel: float,
	grav: float,
	t_vida: float,
	suelo_y: float,
	con_suelo: bool,
	t_clavada: float,
	mat_flecha: Material,
	mat_proceso_estela: Material,
	malla_estela: Mesh,
	capa_render: int,
	con_estela: bool
) -> void:
	_inicializar_estructura_visual()

	global_position = pos_inicial
	profundidad_z_fija = pos_inicial.z
	direccion = dir_inicial.normalized()
	velocidad = max(0.1, vel)
	gravedad = max(0.0, grav)
	tiempo_vida_max = max(0.5, t_vida)
	tiempo_vida_actual = 0.0
	y_suelo_impacto = suelo_y
	usar_suelo_impacto = con_suelo
	duracion_clavada = max(0.1, t_clavada)
	_tiempo_clavada_actual = 0.0
	esta_clavada = false
	_desvaneciendo = false
	_alpha_actual = 1.0

	# Aplicar rotación inicial
	if direccion.length_squared() > MIN_LONGITUD_DIRECCION_SQ:
		rotation = Vector3(0.0, 0.0, atan2(direccion.y, direccion.x))

	# Aplicar capa y material a mallas
	for mesh in _mallas_cacheadas:
		if is_instance_valid(mesh):
			mesh.material_override = mat_flecha
			mesh.layers = capa_render
			mesh.visible = true

	# Configurar partículas de estela
	if is_instance_valid(_particulas_estela):
		_particulas_estela.layers = capa_render
		_particulas_estela.process_material = mat_proceso_estela
		_particulas_estela.draw_pass_1 = malla_estela
		_particulas_estela.restart()
		_particulas_estela.emitting = con_estela
		_particulas_estela.visible = con_estela

	scale = Vector3.ONE
	visible = true
	esta_activa = true
	set_process(true)


## Detiene la flecha de inmediato y la desactiva regresándola al pool.
func desactivar() -> void:
	esta_activa = false
	esta_clavada = false
	_desvaneciendo = false
	visible = false
	set_process(false)
	if is_instance_valid(_particulas_estela):
		_particulas_estela.emitting = false


func _inicializar_estructura_visual() -> void:
	if is_instance_valid(_modelo_flecha):
		return

	# 1. Instanciar el modelo de la flecha original de la Goblin
	if ESCENA_MODELO_FLECHA:
		_modelo_flecha = ESCENA_MODELO_FLECHA.instantiate() as Node3D
		if _modelo_flecha:
			_modelo_flecha.name = "ModeloFlecha"
			_modelo_flecha.transform = TRANSFORM_MODELO_BASE
			add_child(_modelo_flecha)
			_mallas_cacheadas = []
			var encontradas := _modelo_flecha.find_children("*", "MeshInstance3D", true, false)
			for m in encontradas:
				if m is MeshInstance3D:
					_mallas_cacheadas.append(m)

	# 2. Si por algún motivo no hubiese malla en el GLB, crear fallback de cilindro
	if _mallas_cacheadas.is_empty():
		var mesh_inst := MeshInstance3D.new()
		mesh_inst.name = "MeshFallback"
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.025
		cyl.bottom_radius = 0.025
		cyl.height = 0.6
		cyl.radial_segments = 8
		mesh_inst.mesh = cyl
		mesh_inst.rotation = Vector3(0.0, 0.0, -PI / 2.0)
		add_child(mesh_inst)
		_mallas_cacheadas.append(mesh_inst)

	# 3. Crear nodo de partículas para la estela
	if not is_instance_valid(_particulas_estela):
		_particulas_estela = GPUParticles3D.new()
		_particulas_estela.name = "EstelaParticulas"
		_particulas_estela.amount = 14
		_particulas_estela.lifetime = 0.35
		_particulas_estela.explosiveness = 0.0
		_particulas_estela.local_coords = false
		_particulas_estela.position = Vector3(-0.35, 0.0, 0.0)
		add_child(_particulas_estela)


func _clavar() -> void:
	esta_clavada = true
	_tiempo_clavada_actual = 0.0
	if is_instance_valid(_particulas_estela):
		_particulas_estela.emitting = false


func _iniciar_desvanecimiento() -> void:
	_desvaneciendo = true
	_alpha_actual = 1.0
	if is_instance_valid(_particulas_estela):
		_particulas_estela.emitting = false


func _actualizar_desvanecimiento(delta: float) -> void:
	_alpha_actual -= delta / DURACION_DESVANECIMIENTO
	if _alpha_actual <= 0.0:
		_alpha_actual = 0.0
		desactivar()
		finalizada.emit(self)
		return

	# Reducción de escala suave al desvanecer
	scale = Vector3.ONE * clamp(_alpha_actual, 0.05, 1.0)
