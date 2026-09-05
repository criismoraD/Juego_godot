class_name GargolaProjectile
extends "res://System/Core/EnemyProjectileBase.gd"

const VFX_FIREBALL_SCENE: PackedScene = preload("res://VFX/Scenes/VFX_Fire_ball_standar.tscn")
const VFX_HIT_FIRE_SCENE: PackedScene = preload("res://VFX/Scenes/VFX_Hit_fire_1.tscn")
## Claves registradas en AudioManager (no rutas de archivo).
const SFX_FUEGO: StringName = &"gargola_fire"
const SFX_IMPACTO: StringName = &"gargola_impacto"
## Escala local del VFX (el Area3D del proyectil se deja en 1 para no aplastar alphas/trails).
const VFX_LOCAL_SCALE: float = 0.375
## Volumen atenuado un 60% (-8.0 dB) respecto al boost original (+9.5 dB) por solicitud
const VOLUMEN_FUEGO_REDUCIDO_DB: float = 1.5

@export_category("Movimiento")
@export var speed: float = 9.0

@export_category("Audio")
@export var volumen_disparo_db: float = VOLUMEN_FUEGO_REDUCIDO_DB
@export var volumen_impacto_db: float = VOLUMEN_FUEGO_REDUCIDO_DB

static var suprimir_sonido_prewarm: bool = false  ## El precalentador de shaders lo activa para instanciar mudo

var _vfx_fireball: Node3D = null
var _vfx_nodos_preparados: bool = false


func _init() -> void:
	color_proyectil = Color(1.0, 0.1, 0.05)
	offscreen_margin_x = 400.0
	offscreen_margin_top = 2000.0
	offscreen_margin_bottom = 300.0


func initialize(shoot_direction: Vector3, power: float = 1.0) -> void:
	_inicializar_direccion(shoot_direction)
	speed = lerp(10.0, 30.0, clamp(power, 0.0, 1.0))


func _actualizar_movimiento(delta: float) -> void:
	_aplicar_movimiento_recto(delta, speed)


func _preparar_visuales() -> void:
	_remove_glb_model()
	_remove_placeholder_visuals()
	_create_fireball_vfx()


func _ready() -> void:
	super._ready()
	_excluir_meshes_vfx_del_cache()
	if not en_mano:
		_reactivar_vfx()


func _excluir_meshes_vfx_del_cache() -> void:
	# El VFX FireBall se instancia como hijo. Sus MeshInstance3D quedan dentro de
	# _cached_mesh_instances (por find_children recursivo en EnemyProjectileBase).
	# Los excluimos para que el material base (rojo toon + outline) nunca los toque.
	if not is_instance_valid(_vfx_fireball):
		return
	var meshes_vfx := {}
	for mesh_vfx in _vfx_fireball.find_children("*", "MeshInstance3D", true, false):
		meshes_vfx[mesh_vfx] = true
	var filtrado: Array[Node] = []
	for mesh in _cached_mesh_instances:
		if is_instance_valid(mesh) and not meshes_vfx.has(mesh):
			filtrado.append(mesh)
	_cached_mesh_instances = filtrado


func _remove_placeholder_visuals() -> void:
	for child_name in ["SphereVisual", "TrailContainer", "VFX_FireBall", "VFX_FireBall_TypeB", "ArrowModel"]:
		var node := find_child(child_name, false, false)
		if node:
			node.queue_free()


func _stick_to_surface() -> void:
	# Bola de fuego: explota en superficie en lugar de quedarse clavada.
	_spawn_hit_vfx()
	_safe_destroy()


func _stick_to_shield(_shield: Node3D) -> void:
	# El hit VFX ya se spawnea en _on_impacto_con_escudo antes de llegar aquí.
	_safe_destroy()


func _restaurar_visuales_desde_pool() -> void:
	# No aplicar materiales del proyectil base al VFX FireBall.
	if is_instance_valid(_vfx_fireball):
		_vfx_fireball.visible = true
		_reactivar_vfx()
	if trail_particles:
		trail_particles.emitting = true
	# Primer spawn y reuso del pool: el sonido de disparo va aquí (no en _preparar_visuales).
	if not en_mano:
		_reproducir_sonido_disparo()


func _cleanup_materials() -> void:
	# Preservar el VFX FireBall al devolver al pool (solo ocultarlo).
	if is_instance_valid(_vfx_fireball):
		_vfx_fireball.visible = false
		_detener_particulas_vfx()


func _create_fireball_vfx() -> void:
	if not VFX_FIREBALL_SCENE:
		return
	_vfx_fireball = VFX_FIREBALL_SCENE.instantiate() as Node3D
	if not is_instance_valid(_vfx_fireball):
		return

	# Escala del Area3D = 1; el tamaño lo controla solo el VFX para no romper
	# alphas, trails y billboards del shader.
	_vfx_fireball.scale = Vector3.ONE * VFX_LOCAL_SCALE
	# El VFX avanza sobre +Z; el proyectil orienta +X hacia la dirección de disparo.
	_vfx_fireball.rotation = Vector3(0.0, -PI / 2.0, 0.0)
	add_child(_vfx_fireball)
	_preparar_nodos_vfx()


func _preparar_nodos_vfx() -> void:
	if not is_instance_valid(_vfx_fireball) or _vfx_nodos_preparados:
		return
	_vfx_nodos_preparados = true

	for child in _vfx_fireball.get_children():
		if child is MeshInstance3D:
			var mesh_instance := child as MeshInstance3D
			# La escena VFX trae skeleton = "../.." pensado para el showcase;
			# bajo el proyectil apunta a un nodo incorrecto y puede anular el render.
			mesh_instance.skeleton = NodePath()
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mesh_instance.visible = true
			_asegurar_material_transparente(mesh_instance)

		if child is GPUParticles3D:
			var particles := child as GPUParticles3D
			particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			particles.emitting = true
			particles.visible = true

		if child.name == "Trail2_dynamic":
			child.visible = true
			if child is MeshInstance3D:
				(child as MeshInstance3D).skeleton = NodePath()


func _asegurar_material_transparente(mesh_instance: MeshInstance3D) -> void:
	var mat := mesh_instance.material_override
	if mat == null:
		return

	# Duplicar una sola vez para no mutar el recurso embebido de la escena VFX.
	var mat_unico: Material = mat.duplicate(true)
	mesh_instance.material_override = mat_unico

	if mat_unico is ShaderMaterial:
		var shader_mat := mat_unico as ShaderMaterial
		shader_mat.render_priority = maxi(shader_mat.render_priority, 1)
	elif mat_unico is StandardMaterial3D:
		var std_mat := mat_unico as StandardMaterial3D
		std_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		std_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		std_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED


func _reactivar_vfx() -> void:
	if not is_instance_valid(_vfx_fireball):
		return

	_vfx_fireball.visible = true
	_preparar_nodos_vfx()

	for child in _vfx_fireball.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = true
		if child is GPUParticles3D:
			var particles := child as GPUParticles3D
			particles.restart()
			particles.emitting = true
		# Reinicia el trail dinámico (Trail3D).
		if child.get("trailEnabled") != null:
			child.set("trailEnabled", true)
			child.set("points", [])
			child.set("widths", [])
			child.set("lifePoints", [])
			if child.get("oldPos") != null:
				child.set("oldPos", child.global_transform.origin)


func _detener_particulas_vfx() -> void:
	if not is_instance_valid(_vfx_fireball):
		return
	for child in _vfx_fireball.get_children():
		if child is GPUParticles3D:
			(child as GPUParticles3D).emitting = false
		if child.get("trailEnabled") != null:
			child.set("trailEnabled", false)


func _reproducir_sonido_disparo() -> void:
	if suprimir_sonido_prewarm:
		return
	AudioManager.play_sfx(String(SFX_FUEGO), volumen_disparo_db)


func _on_impacto_con_dano(_body: Node) -> void:
	_spawn_hit_vfx()


func _on_impacto_con_escudo(_body: Node) -> void:
	_spawn_hit_vfx()
	if _body is Node3D:
		_crear_quemadura_escudo(_body as Node3D, global_position)


func _spawn_hit_vfx() -> void:
	if not VFX_HIT_FIRE_SCENE:
		return
	var hit := VFX_HIT_FIRE_SCENE.instantiate() as Node3D
	if not hit:
		return
	get_tree().root.add_child(hit)
	hit.scale = Vector3(0.3, 0.3, 0.3)
	hit.global_position = global_position
	_reproducir_sonido_impacto()


func _crear_quemadura_escudo(escudo: Node3D, pos_global: Vector3) -> void:
	# Limitar a 3 quemaduras por escudo para no saturar - ahora en zona de impacto
	var existentes: Array[Node] = escudo.find_children("QuemaduraGargola*", "MeshInstance3D", false, false)
	if existentes.size() >= 6:
		return
	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	mesh_inst.name = "QuemaduraGargola%d" % existentes.size()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.38, 0.38)
	mesh_inst.mesh = quad

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	mat.render_priority = 2

	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var center: Vector2 = Vector2(31.5, 31.5)
	for y: int in range(64):
		for x: int in range(64):
			var uv: Vector2 = (Vector2(x, y) - center) / 31.0
			# Forma irregular que sigue contorno vertical del escudo (alargado y con muescas)
			var aniso: Vector2 = Vector2(uv.x * 1.35, uv.y * 0.88)
			var warp: float = sin(aniso.x * 5.5) * 0.09 + cos(aniso.y * 6.2) * 0.09 + sin((aniso.x + aniso.y) * 4.0) * 0.06
			var d: float = aniso.length() + warp * 0.35
			# Borde quemado irregular con ruido de alta frecuencia
			var n1: float = sin(float(x) * 1.9) * cos(float(y) * 1.9) * 0.14
			var n2: float = sin(float(x) * 3.7 + float(y) * 2.1) * 0.07
			var alpha: float = 1.0 - smoothstep(0.32, 0.88, d)
			alpha = clamp(alpha + n1 + n2, 0.0, 1.0) * 0.92
			# Centro carbonizado, borde ahumado siguiendo veta vertical
			var col: Color = Color(0.14, 0.06, 0.03, alpha)
			if d > 0.55:
				var t: float = clamp((d - 0.55) / 0.33, 0.0, 1.0)
				# Degradado quemado con vetas
				var edge_noise: float = sin(float(x) * 2.3) * 0.08 + cos(float(y) * 3.1) * 0.08
				col = col.lerp(Color(0.04, 0.02, 0.015, alpha * (0.9 + edge_noise)), t)
			img.set_pixel(x, y, col)
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mesh_inst.material_override = mat

	var local_hit: Vector3 = escudo.to_local(pos_global)
	# Cara frontal del escudo (BoxShape fino en X) - clavar quemadura a superficie
	local_hit.x = 0.02
	local_hit.y = clamp(local_hit.y, -0.55, 0.65)
	local_hit.z = clamp(local_hit.z, -0.45, 0.45)
	local_hit += Vector3(randf_range(-0.015, 0.015), randf_range(-0.03, 0.03), randf_range(-0.03, 0.03))
	escudo.add_child(mesh_inst)
	mesh_inst.position = local_hit
	mesh_inst.rotation_degrees = Vector3(0, 90, randf_range(0.0, 360.0))

	var tween: Tween = mesh_inst.create_tween()
	tween.tween_interval(2.5)
	tween.tween_property(mat, "albedo_color:a", 0.0, 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(func() -> void:
		if is_instance_valid(mesh_inst):
			mesh_inst.queue_free()
	)


func _reproducir_sonido_impacto() -> void:
	if suprimir_sonido_prewarm:
		return
	AudioManager.play_sfx(String(SFX_IMPACTO), volumen_impacto_db)
