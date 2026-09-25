@tool
class_name VasijaContenedor
extends StaticBody3D

## Vasija contenedora del nivel del rio: flota a la deriva, recibe 2 golpes,
## parpadea en rojo al ser impactada y al destruirse suelta un item al instante
## (como la mensajera), cambia al modelo destruido y eyecciona piedritas
## como las del pilar de la arquera lonko.
## Las flechas de la jugadora la dañan (es_escudo_enemigo); las enemigas la ignoran.

signal destruida

enum ItemSoltado { DISPARO_MULTIPLE, FLECHA_EXPLOSIVA, POCION_CURATIVA, FUEGO_RAPIDO }

# === CONSTANTES ===
const TEXTURA_PIEDRITAS: String = "res://Entities/Enemigo_Lonko/ROCAS.png"
const CANTIDAD_PIEDRITAS: int = 12
const DURACION_FLASH: float = 0.1
const COLOR_FLASH_DANO: Color = Color(1.0, 0.3, 0.3)
const SHADER_DISOLVER: Shader = preload("res://System/Shaders/dissolve.gdshader")
const SHADER_TOON_OUTLINE: Shader = preload("res://System/Shaders/TOON_LINEANEGRA.gdshader")
const RUTA_MAT_CONTENEDOR: String = "res://Levels/Rio_En_Canoa_Con_Parallax/BasijaContenedor_Mat.tres"
const RUTA_MAT_DESTRUIDO: String = "res://Levels/Rio_En_Canoa_Con_Parallax/BasijaDestruida_Mat.tres"
const ESCENA_DISPARO_MULTIPLE: PackedScene = preload("res://Entities/Item_Flecha_Multiple/PowerUpFlechaMultiple.tscn")
const ESCENA_FLECHA_EXPLOSIVA: PackedScene = preload("res://Entities/Item_Flecha_Explosiva/PowerUpFlechaExplosiva.tscn")
const ESCENA_POCION: PackedScene = preload("res://Entities/Item_Pocion/Posion.tscn")
const ESCENA_FUEGO_RAPIDO: PackedScene = preload("res://Entities/Item_Fuego_Rapido/PowerUpFuegoRapido.tscn")
const TIEMPO_VER_ITEM: float = 1.0  ## Segundos visible el item antes de auto-consumirse
const COLOR_DISOLVER_CELESTE: Color = Color(0.4, 0.85, 1.0, 1.0)  ## Tinte de disolución como los enemigos
const GROSOR_OUTLINE_TOON: float = 20.0

# === EXPORTS ===
@export_category("Contenedor")
@export var vida_maxima: float = 2.0  ## Golpes que aguanta antes de romperse
@export var item_soltado: ItemSoltado = ItemSoltado.DISPARO_MULTIPLE  ## Item que otorga al instante al destruirse
@export var cantidad_municion: int = 10  ## Flechas a otorgar (múltiple o explosiva)
@export var curacion_pocion: int = 1  ## Vida a restaurar si suelta poción
@export var duracion_fuego_rapido: float = 15.0  ## Segundos del buff si suelta fuego rápido

@export_category("Deriva")
@export_enum("Derecha", "Izquierda") var direccion_viaje: String = "Derecha"  ## Sentido del desplazamiento sobre el río
@export var deriva_activa: bool = true  ## Si false, no se desplaza
@export var velocidad_desplazamiento: float = 0.35  ## Metros por segundo del desplazamiento
@export var deriva_solo_en_pantalla: bool = true  ## No avanza hasta que la vasija aparece en el encuadre

@export_category("Flotación")
@export var flotacion_activa: bool = true  ## Si false, no bambolea
@export var amplitud_floteo: float = 0.06  ## Sube y baja en metros
@export var velocidad_floteo: float = 1.0  ## Oscilaciones por segundo
@export var amplitud_balanceo: float = 2.0  ## Vaivén lateral en grados

@export_category("Hundimiento")
@export var profundidad_hundimiento: float = 1.5  ## Metros que se hunde al destruirse
@export var duracion_hundimiento: float = 1.5  ## Segundos del hundimiento con disolución

@export_category("Texturas")
@export var material_contenedor: StandardMaterial3D:
	set(nuevo_material):
		material_contenedor = nuevo_material
		if is_node_ready():
			_aplicar_materiales()
@export var material_destruido: StandardMaterial3D:
	set(nuevo_material):
		material_destruido = nuevo_material
		if is_node_ready():
			_aplicar_materiales()

# === VARIABLES PÚBLICAS ===
var es_escudo_enemigo: bool = true  ## Las flechas de la jugadora la dañan; las enemigas la ignoran
var vida_contenedor: float = 2.0  ## Vida actual

# === VARIABLES PRIVADAS ===
var _destruido: bool = false
var _tiempo: float = 0.0
var _pos_base_y: float = 0.0
var _mallas: Array[MeshInstance3D] = []
var _materiales_originales: Array = []
var _materiales_disolver: Array = []
var _textura_piedritas: Texture2D = null
var _en_pantalla: bool = false  ## True cuando la vasija ya apareció en el encuadre (habilita la deriva)
var _notificador_pantalla: VisibleOnScreenNotifier3D = null

# === ONREADY ===
@onready var modelo: Node3D = $Model
@onready var modelo_destruido: Node3D = $ModeloDestruido
@onready var forma_colision: CollisionShape3D = $CollisionShape3D


# === FUNCIONES BUILT-IN ===
func _ready() -> void:
	vida_contenedor = vida_maxima
	_pos_base_y = position.y
	_aplicar_materiales()
	_cachear_mallas()
	asegurar_contorno_toon()
	_configurar_notificador_pantalla()
	_textura_piedritas = load(TEXTURA_PIEDRITAS) as Texture2D
	if is_instance_valid(modelo_destruido):
		modelo_destruido.visible = false


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if delta <= 0.0:
		return
	if deriva_activa and not _destruido and _puede_derivar():
		var sentido: float = 1.0 if direccion_viaje == "Derecha" else -1.0
		position.x += sentido * velocidad_desplazamiento * delta
	if flotacion_activa and not _destruido:
		_tiempo += delta * velocidad_floteo
		position.y = _pos_base_y + sin(_tiempo * TAU) * amplitud_floteo
		rotation.z = sin(_tiempo * TAU * 0.6) * deg_to_rad(amplitud_balanceo)


# === FUNCIONES PÚBLICAS ===
## Recibe impacto de flecha (1.0 de daño normal; la sobrecarga puede romper de un golpe).
func recibir_golpe(dano: float = 1.0) -> void:
	if _destruido or vida_contenedor <= 0.0:
		return
	vida_contenedor -= dano
	AudioManager.play_sfx("arrow_impact")
	_flash_dano()
	if vida_contenedor <= 0.0:
		_destruir()


## Retorna si la vasija ya fue destruida.
func esta_destruido() -> bool:
	return _destruido


# === FUNCIONES PRIVADAS ===
func _destruir() -> void:
	_destruido = true
	if is_instance_valid(forma_colision):
		forma_colision.set_deferred("disabled", true)
	if is_instance_valid(modelo):
		modelo.visible = false
	if is_instance_valid(modelo_destruido):
		modelo_destruido.visible = true
	AudioManager.play_sfx("vasija_quebrada")
	_soltar_piedritas()
	_soltar_item_visible()
	_hundir_y_disolver()
	destruida.emit()


func _flash_dano() -> void:
	for mi in _mallas:
		if not is_instance_valid(mi):
			continue
		var flash_mat := StandardMaterial3D.new()
		flash_mat.emission_enabled = true
		flash_mat.emission = COLOR_FLASH_DANO
		flash_mat.emission_energy_multiplier = 3.0
		if material_contenedor != null and material_contenedor.next_pass != null:
			flash_mat.next_pass = material_contenedor.next_pass
		mi.material_override = flash_mat
	get_tree().create_timer(DURACION_FLASH).timeout.connect(_restaurar_materiales)


func _restaurar_materiales() -> void:
	for i in range(_mallas.size()):
		if is_instance_valid(_mallas[i]):
			_mallas[i].material_override = _materiales_originales[i] if i < _materiales_originales.size() else null


func _cachear_mallas() -> void:
	_mallas.clear()
	_materiales_originales.clear()
	if not is_instance_valid(modelo):
		return
	for m in modelo.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi:
			_mallas.append(mi)
			_materiales_originales.append(mi.material_override if mi.material_override != null else material_contenedor)


func _aplicar_materiales() -> void:
	if material_contenedor == null and ResourceLoader.exists(RUTA_MAT_CONTENEDOR):
		material_contenedor = load(RUTA_MAT_CONTENEDOR) as StandardMaterial3D
	if material_destruido == null and ResourceLoader.exists(RUTA_MAT_DESTRUIDO):
		material_destruido = load(RUTA_MAT_DESTRUIDO) as StandardMaterial3D
	if is_instance_valid(modelo) and material_contenedor != null:
		_aplicar_a_instancias(modelo, material_contenedor)
	if is_instance_valid(modelo_destruido) and material_destruido != null:
		_aplicar_a_instancias(modelo_destruido, material_destruido)


func _aplicar_a_instancias(nodo: Node, material: StandardMaterial3D) -> void:
	if nodo is MeshInstance3D:
		var malla := nodo as MeshInstance3D
		malla.material_override = material
		if malla.mesh != null and malla.mesh.get_surface_count() > 0:
			malla.set_surface_override_material(0, material)
	for hijo in nodo.get_children():
		_aplicar_a_instancias(hijo, material)


func _soltar_piedritas() -> void:
	if _textura_piedritas == null or get_parent() == null:
		return
	for i in range(CANTIDAD_PIEDRITAS):
		var piedra := Sprite3D.new()
		piedra.texture = _textura_piedritas
		piedra.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		piedra.shaded = false
		piedra.double_sided = false
		var esc: float = randf_range(0.02, 0.05)
		piedra.scale = Vector3(esc, esc, esc)
		piedra.rotation.z = randf_range(0.0, TAU)
		piedra.modulate = Color(0.95, 0.9, 0.82, 1.0)
		get_parent().add_child(piedra)
		piedra.global_position = global_position + Vector3(randf_range(-0.3, 0.3), 0.5, randf_range(-0.2, 0.2))
		var destino := piedra.position + Vector3(randf_range(-1.2, 1.2), randf_range(-1.6, -0.8), 0.0)
		var tw := piedra.create_tween()
		tw.set_parallel(true)
		tw.tween_property(piedra, "position", destino, randf_range(0.5, 0.8)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(piedra, "modulate:a", 0.0, 0.8)
		tw.chain().tween_callback(piedra.queue_free)


func _soltar_item_visible() -> void:
	if get_parent() == null:
		return
	var escena_item: PackedScene = null
	match item_soltado:
		ItemSoltado.DISPARO_MULTIPLE:
			escena_item = ESCENA_DISPARO_MULTIPLE
		ItemSoltado.FLECHA_EXPLOSIVA:
			escena_item = ESCENA_FLECHA_EXPLOSIVA
		ItemSoltado.POCION_CURATIVA:
			escena_item = ESCENA_POCION
		ItemSoltado.FUEGO_RAPIDO:
			escena_item = ESCENA_FUEGO_RAPIDO
	if escena_item == null:
		return
	var item := escena_item.instantiate() as Node3D
	if item == null:
		return
	# Un segundo visible para ver qué salió antes de auto-consumirse al contacto o por tiempo
	item.set("tiempo_en_pantalla", TIEMPO_VER_ITEM)
	if "municion_a_otorgar_jugador" in item:
		item.set("municion_a_otorgar_jugador", cantidad_municion)
	if "vida_a_restaurar" in item:
		var cura: int = curacion_pocion if curacion_pocion > 0 else 1
		item.set("vida_a_restaurar", cura)
	if "duracion_buff" in item:
		item.set("duracion_buff", duracion_fuego_rapido)
	get_parent().add_child(item)
	item.global_position = global_position + Vector3(0.0, 0.6, 0.0)


func _hundir_y_disolver() -> void:
	_materiales_disolver.clear()
	if is_instance_valid(modelo_destruido):
		for m in modelo_destruido.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if mi == null:
				continue
			var mat := ShaderMaterial.new()
			mat.shader = SHADER_DISOLVER
			mat.set_shader_parameter("dissolve_amount", 0.0)
			if material_destruido != null and material_destruido.albedo_texture != null:
				mat.set_shader_parameter("albedo_texture", material_destruido.albedo_texture)
			mat.set_shader_parameter("glow_color", COLOR_DISOLVER_CELESTE)
			if material_destruido != null and material_destruido.next_pass != null:
				mat.next_pass = material_destruido.next_pass
			mi.material_override = mat
			_materiales_disolver.append(mat)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:y", position.y - profundidad_hundimiento, maxf(duracion_hundimiento, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_method(_actualizar_disolucion, 0.0, 1.0, maxf(duracion_hundimiento, 0.01))
	tw.chain().tween_callback(queue_free)


func _actualizar_disolucion(valor: float) -> void:
	for mat in _materiales_disolver:
		if mat is ShaderMaterial:
			(mat as ShaderMaterial).set_shader_parameter("dissolve_amount", valor)


## Asegura que los meshes de la vasija (intacta y destruida) posean contorno toon negro.
func asegurar_contorno_toon() -> void:
	if not SHADER_TOON_OUTLINE:
		return
	var modelos: Array[Node3D] = []
	if is_instance_valid(modelo):
		modelos.append(modelo)
	if is_instance_valid(modelo_destruido):
		modelos.append(modelo_destruido)

	for nodo_modelo: Node3D in modelos:
		for child in nodo_modelo.find_children("*", "MeshInstance3D", true, false):
			var mi := child as MeshInstance3D
			if not mi:
				continue
			if not mi.is_in_group("outline_meshes"):
				mi.add_to_group("outline_meshes")
			if not mi.mesh:
				continue
			for i in range(mi.mesh.get_surface_count()):
				var mat: Material = mi.get_active_material(i)
				if mat is StandardMaterial3D:
					var std_mat := mat as StandardMaterial3D
					if std_mat.next_pass == null or not (std_mat.next_pass is ShaderMaterial):
						var outline_mat := ShaderMaterial.new()
						outline_mat.shader = SHADER_TOON_OUTLINE
						outline_mat.set_shader_parameter("outline_color", Color(0.0, 0.0, 0.0, 1.0))
						outline_mat.set_shader_parameter("outline_width", GROSOR_OUTLINE_TOON)
						std_mat.next_pass = outline_mat
					elif std_mat.next_pass is ShaderMaterial:
						var outline_mat := std_mat.next_pass as ShaderMaterial
						if outline_mat.shader == null:
							outline_mat.shader = SHADER_TOON_OUTLINE
						outline_mat.set_shader_parameter("outline_color", Color(0.0, 0.0, 0.0, 1.0))
						outline_mat.set_shader_parameter("outline_width", GROSOR_OUTLINE_TOON)


func _configurar_notificador_pantalla() -> void:
	if Engine.is_editor_hint():
		return
	_notificador_pantalla = VisibleOnScreenNotifier3D.new()
	_notificador_pantalla.name = "NotificadorPantalla"
	_notificador_pantalla.aabb = AABB(Vector3(-0.4, -0.2, -0.4), Vector3(0.8, 1.2, 0.8))
	add_child(_notificador_pantalla)
	_notificador_pantalla.screen_entered.connect(_on_pantalla_cambiada.bind(true))
	_notificador_pantalla.screen_exited.connect(_on_pantalla_cambiada.bind(false))


func _on_pantalla_cambiada(v: bool) -> void:
	_en_pantalla = v


func _puede_derivar() -> bool:
	return not deriva_solo_en_pantalla or _en_pantalla

