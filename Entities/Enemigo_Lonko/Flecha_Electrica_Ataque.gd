class_name FlechaElectricaAtaque
extends EnemyProjectileBase
## Flecha eléctrica de Lonko: la flecha normal + VFX Flecha_Electrica.tscn.
## Fase SUBIDA: sale en vertical desde la mano de Lonko hasta salir de pantalla.
## Fase ESPERA_MARCA: deja una marca (aros rojos expandiéndose) en la zona aliada durante N segundos.
## Fase CAIDA: cae del cielo en picada hasta el suelo en el punto marcado.

const MARCA_ZONA_CAIDA_REF = preload("res://Entities/Enemigo_Lonko/Marca_Zona_Caida.gd")
const VFX_ELECTRICO_REF = preload("res://Entities/Enemigo_Lonko/Flecha_Electrica.tscn")
const SFX_RAYO_ULT_STREAM = preload("res://Entities/Enemigo_Lonko/Sonido rayo ult.mp3")
const ALTURA_IMPACTO_SUELO: float = 0.2  ## Y a la que la flecha impacta el suelo y explota

enum Fase { SUBIDA, ESPERA_MARCA, CAIDA }

@export_category("Ataque Eléctrico - Trayectoria")
@export var altura_cielo: float = 45.0  ## Altura a la que la flecha "sale de pantalla" y espera
@export var velocidad_subida: float = 40.0  ## Velocidad vertical de ascenso
@export var velocidad_caida: float = 24.0  ## Velocidad vertical inicial de caída

@export_category("Ataque Eléctrico - Zona de Caída")
@export var zona_caida_x_min: float = -10.0  ## Límite izquierdo de la zona aliada
@export var zona_caida_x_max: float = -6.5  ## Límite derecho de la zona aliada
@export var zona_caida_z: float = 0.0  ## Plano Z fijo de la zona de caída

@export_category("Ataque Eléctrico - Marca")
@export var segundos_marca: float = 1.5  ## Tiempo de aviso con los aros rojos antes de caer
@export var radio_marca: float = 1.25  ## Radio de los aros de la marca

@export_category("Ataque Eléctrico - Daño")
@export var dano: float = 1.0  ## Solo quita 1 de vida al impactar

var fase: Fase = Fase.SUBIDA
var _punto_caida: Vector3 = Vector3.ZERO
var _marca: Node3D = null
var _gravedad: float = 0.0
var _fase_iniciada: bool = false
var _cuerpos_danados_caida: Dictionary = {}


func _ready() -> void:
	tiempo_vida = 20.0
	_gravedad = ProjectSettings.get_setting("physics/3d/default_gravity")
	super._ready()
	_excluir_meshes_vfx_del_cache()
	_preparar_nodos_vfx()


func _excluir_meshes_vfx_del_cache() -> void:
	# El VFX Flecha_Electrica se instancia como hijo. Sus MeshInstance3D quedan dentro de
	# _cached_mesh_instances (por find_children recursivo en EnemyProjectileBase).
	# Los excluimos para que el material base (verde toon + outline) nunca los toque.
	var vfx := find_child("FlechaElectricaVFX", true, false)
	if not is_instance_valid(vfx):
		return
	var meshes_vfx := {}
	for mesh_vfx in vfx.find_children("*", "MeshInstance3D", true, false):
		meshes_vfx[mesh_vfx] = true
	# El cubo DEBUG de la punta también conserva su material rojo
	var punta := find_child("DebugPunta", true, false)
	if punta:
		meshes_vfx[punta] = true
	var filtrado: Array[Node] = []
	for mesh in _cached_mesh_instances:
		if is_instance_valid(mesh) and not meshes_vfx.has(mesh):
			filtrado.append(mesh)
	_cached_mesh_instances = filtrado


func _preparar_nodos_vfx() -> void:
	var vfx := find_child("FlechaElectricaVFX", true, false)
	if not is_instance_valid(vfx):
		return

	# Plantilla fresca (fuera del árbol) para recuperar los material_override ORIGINALES
	# de la escena: EnemyProjectileBase los sobrescribe con el material toon base en _ready().
	var plantilla: Node3D = null
	if VFX_ELECTRICO_REF:
		plantilla = VFX_ELECTRICO_REF.instantiate() as Node3D

	for mesh in vfx.find_children("*", "MeshInstance3D", true, false):
		if not mesh is MeshInstance3D:
			continue
		# La escena VFX trae skeleton = "../../.." pensado para el showcase;
		# bajo el proyectil apunta a un nodo incorrecto y puede anular el render.
		mesh.skeleton = NodePath()
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if plantilla:
			var mesh_plantilla := plantilla.find_child(mesh.name, false, false)
			if mesh_plantilla is MeshInstance3D:
				mesh.material_override = mesh_plantilla.material_override

	if plantilla:
		plantilla.free()


## La flecha eléctrica nunca se destruye por salirse de pantalla:
## su ciclo (subir, esperar, caer) lo controlan las fases.
func _check_off_screen() -> void:
	pass


func _actualizar_movimiento(delta: float) -> void:
	match fase:
		Fase.SUBIDA:
			global_position += Vector3.UP * velocidad_subida * delta
			_rotar_hacia(Vector3.UP)
			if global_position.y >= altura_cielo:
				_iniciar_fase_espera()
		Fase.ESPERA_MARCA:
			pass
		Fase.CAIDA:
			if not _fase_iniciada:
				_iniciar_fase_caida()
			global_position.y -= velocidad_caida * delta
			velocidad_caida += _gravedad * delta
			_rotar_hacia(Vector3.DOWN)
			# Atraviesa todo (plataformas, decorados) hasta el suelo: impacta y
			# explota al llegar a la altura ALTURA_IMPACTO_SUELO (0.2 en Y).
			if global_position.y <= ALTURA_IMPACTO_SUELO:
				_explotar_en_impacto()
				_safe_destroy()


func _rotar_hacia(dir: Vector3) -> void:
	if dir.y > 0.1:
		rotation_degrees = Vector3(0.0, 0.0, 90.0)
	elif dir.y < -0.1:
		rotation_degrees = Vector3(0.0, 0.0, -90.0)
	elif dir.length_squared() > 0.01:
		rotation = Vector3(0.0, 0.0, atan2(dir.y, dir.x))


func _iniciar_fase_espera() -> void:
	fase = Fase.ESPERA_MARCA
	visible = false
	monitoring = false
	monitorable = false
	_traila_particles_off()

	# Punto de caída aleatorio dentro de la zona aliada
	_punto_caida = Vector3(randf_range(zona_caida_x_min, zona_caida_x_max), 0.0, zona_caida_z)

	# Crear la marca con aros expandiéndose (RayCast al suelo, como las sombras).
	var marca := MARCA_ZONA_CAIDA_REF.new()
	marca.radio_marca = radio_marca
	marca.duracion_marca = segundos_marca
	_marca = marca
	var root := get_tree().current_scene
	var subviewport_fondo: Node = null
	if root:
		subviewport_fondo = root.find_child("SubViewportFondo3D", true, false)
	if subviewport_fondo:
		subviewport_fondo.add_child(marca)
	elif root:
		root.add_child(marca)
	else:
		get_tree().root.add_child(marca)
	marca.iniciar(_punto_caida)

	await get_tree().create_timer(segundos_marca, false).timeout
	if not is_instance_valid(self) or not is_inside_tree():
		return

	# Posicionarse en el cielo justo encima del punto marcado y caer
	global_position = Vector3(_punto_caida.x, altura_cielo, _punto_caida.z)
	fase = Fase.CAIDA
	visible = true
	monitoring = true
	monitorable = true
	_rotar_hacia(Vector3.DOWN)


func _iniciar_fase_caida() -> void:
	_fase_iniciada = true
	_restaurar_trail()


func _traila_particles_off() -> void:
	if trail_particles:
		trail_particles.emitting = false


func _restaurar_trail() -> void:
	if trail_particles:
		trail_particles.emitting = true


func _on_body_entered(body: Node) -> void:
	if fase != Fase.CAIDA or is_stuck:
		return

	if body.is_in_group("allies") or body.is_in_group("player"):
		if not _cuerpos_danados_caida.has(body):
			_cuerpos_danados_caida[body] = true
			if body.has_method("take_damage"):
				body.take_damage(dano)
			elif body.has_method("recibir_dano"):
				body.recibir_dano(dano)
			_reproducir_sonido_rayo()
		# Continúa su caída libremente hacia el target sin destruirse a mitad de trayectoria


func _explotar_en_impacto() -> void:
	_reproducir_sonido_rayo()

	# Destruir la marca del target al impactar en el suelo
	if _marca and is_instance_valid(_marca):
		if _marca.has_method("explotar_y_destruir"):
			_marca.call("explotar_y_destruir")
		else:
			_marca.queue_free()
		_marca = null

	# Destello y área de daño eléctrico en el punto de impacto
	var vfx := VFX_ELECTRICO_REF.instantiate() as Node3D
	if vfx:
		if "dano" in vfx:
			vfx.dano = dano
		var root := get_tree().current_scene
		if root:
			root.add_child(vfx)
		else:
			get_tree().root.add_child(vfx)
		vfx.global_position = global_position
		vfx.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		vfx.scale = Vector3.ONE * 0.5
		var sparks := vfx.find_child("sparks", true, false)
		if sparks is GPUParticles3D:
			sparks.visible = true
			sparks.emitting = true
		get_tree().create_timer(1.0, false).timeout.connect(func():
			if is_instance_valid(vfx):
				vfx.queue_free()
		)


func _reproducir_sonido_rayo() -> void:
	if not SFX_RAYO_ULT_STREAM:
		return
	var player := AudioStreamPlayer.new()
	player.add_to_group("pausable_audio")
	player.stream = SFX_RAYO_ULT_STREAM
	player.volume_db = -2.5  # -25% (~-2.5 dB)
	player.bus = "Master"
	var root := get_tree().current_scene
	if root:
		root.add_child(player)
		player.play()
		player.finished.connect(player.queue_free)
	else:
		player.queue_free()
	AudioManager.play_sfx("shield_hit_arrow")
