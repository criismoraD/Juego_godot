class_name CaidaPiedrasTorre
extends Node3D

## Sistema de desprendimiento periódico de piedras de la torre dañada.
## Cada intervalo_segundos suelta micro-piedras cuya opacidad disminuye progresivamente a medida que caen.

const TEXTURA_ROCAS: String = "res://Entities/Enemigo_Lonko/ROCAS.png"

@export var intervalo_segundos: float = 60.0
@export var cantidad_piedras: int = 14
@export var gravedad: float = 8.0
@export var velocidad_inicial_min: float = 0.2
@export var velocidad_inicial_max: float = 0.9
@export var escala_min: float = 0.006
@export var escala_max: float = 0.015
@export var y_suelo: float = 0.08  ## Altura del suelo donde rebotan las piedras
@export var elasticidad_min: float = 0.28
@export var elasticidad_max: float = 0.45
@export var max_rebotes: int = 2
@export var opacidad_inicial: float = 0.55  ## Opacidad al desprenderse en la cornisa
@export var opacidad_suelo: float = 0.08    ## Opacidad reducida al llegar al suelo

var _timer: float = 0.0
var _textura_cargada: Texture2D = null
var _piedras_activas: Array[Dictionary] = []

func _ready() -> void:
	_textura_cargada = load(TEXTURA_ROCAS) as Texture2D
	_soltar_piedras()

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= intervalo_segundos:
		_timer = 0.0
		_soltar_piedras()

	_actualizar_piedras(delta)

func _soltar_piedras() -> void:
	if not _textura_cargada:
		return

	for i in range(cantidad_piedras):
		var delay_piedra: float = randf_range(0.0, 0.85)
		get_tree().create_timer(delay_piedra).timeout.connect(_crear_piedra_individual)

func _crear_piedra_individual() -> void:
	if not is_inside_tree():
		return

	var sprite := Sprite3D.new()
	sprite.texture = _textura_cargada
	sprite.hframes = 4
	sprite.vframes = 1
	sprite.frame = randi() % 4
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.render_priority = 2
	sprite.layers = 7
	sprite.modulate = Color(0.95, 0.90, 0.82, 0.0)

	var esc: float = randf_range(escala_min, escala_max)
	sprite.scale = Vector3(esc, esc, esc)
	sprite.rotation.z = randf_range(0.0, TAU)

	# Nacer en la cornisa baja
	var offset_x: float = randf_range(-0.08, 0.08)
	var offset_z: float = randf_range(-0.03, 0.03)
	sprite.position = Vector3(offset_x, 0.0, offset_z)

	add_child(sprite)

	var vy: float = -randf_range(velocidad_inicial_min, velocidad_inicial_max)
	var vx: float = randf_range(-0.03, 0.03)
	var v_rot: float = randf_range(-3.5, 3.5)
	var elast: float = randf_range(elasticidad_min, elasticidad_max)

	_piedras_activas.append({
		"nodo": sprite,
		"vx": vx,
		"vy": vy,
		"v_rot": v_rot,
		"rebotes": max_rebotes,
		"elasticidad": elast,
		"en_suelo": false,
		"y_origen": sprite.global_position.y,
		"tiempo_vida": 0.0,
		"tiempo_desvanecer": 0.4
	})

func _actualizar_piedras(delta: float) -> void:
	for i in range(_piedras_activas.size() - 1, -1, -1):
		var p: Dictionary = _piedras_activas[i]
		var nodo: Sprite3D = p["nodo"]
		if not is_instance_valid(nodo):
			_piedras_activas.remove_at(i)
			continue

		p["tiempo_vida"] += delta

		if p["en_suelo"]:
			# Desvanecer los restos tenues al posarse
			p["tiempo_desvanecer"] -= delta
			var alpha_suelo: float = clamp(p["tiempo_desvanecer"] / 0.4, 0.0, 1.0) * opacidad_suelo
			nodo.modulate.a = alpha_suelo
			if p["tiempo_desvanecer"] <= 0.0:
				nodo.queue_free()
				_piedras_activas.remove_at(i)
			continue

		# Opacidad que disminuye progresivamente con la altura de la caída
		var y_orig: float = p["y_origen"]
		var factor_altura: float = clamp((nodo.global_position.y - y_suelo) / max(0.1, y_orig - y_suelo), 0.0, 1.0)
		var opacidad_gradual: float = lerp(opacidad_suelo, opacidad_inicial, factor_altura)
		var fade_in: float = clamp(p["tiempo_vida"] * 10.0, 0.0, 1.0)
		nodo.modulate.a = opacidad_gradual * fade_in

		# Físicas de caída
		p["vy"] -= gravedad * delta
		nodo.position.y += p["vy"] * delta
		nodo.position.x += p["vx"] * delta
		nodo.rotation.z += p["v_rot"] * delta

		# Comprobar rebote con el suelo
		if nodo.global_position.y <= y_suelo:
			nodo.global_position.y = y_suelo
			if p["rebotes"] > 0 and abs(p["vy"]) > 0.6:
				p["rebotes"] -= 1
				p["vy"] = -p["vy"] * p["elasticidad"]
				p["vx"] = randf_range(-0.20, 0.20)
				p["v_rot"] = randf_range(-5.0, 5.0)
			else:
				p["en_suelo"] = true
				p["vy"] = 0.0
				p["vx"] = 0.0
