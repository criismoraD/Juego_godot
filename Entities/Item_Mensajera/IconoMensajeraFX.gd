class_name IconoMensajeraFX
extends Area3D

## Icono de invocación de la mensajera (nivel 5): flota sobre una columna de
## luz (PillarAreaVFX_03), palpita y desaparece al ser activado por la jugadora.

signal activada

const SFX_REFUERZO_MENSAJERA: AudioStream = preload("res://TEST_/Sonido refuerzo mensajera.mp3")

@export_category("Flotación")
@export var altura_flotacion: float = 0.75  ## Altura del icono sobre la base del VFX
@export var amplitud_flotacion: float = 0.05  ## Sube/baja suave
@export var velocidad_flotacion: float = 2.2
@export_category("Palpitar")
@export var escala_base_icono: float = 1.0
@export var escala_palpito: float = 1.12  ## Pico del latido
@export var duracion_palpito: float = 0.55
@export var retardo_armado: float = 1.0  ## Segundos antes de poder activarse (evita auto-activación al aparecer)

var _icono: Sprite3D = null
var _vfx_luz: Node3D = null
var _activado: bool = false
var _armado: bool = false
var _tiempo: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_icono = get_node_or_null("Icono") as Sprite3D
	_vfx_luz = get_node_or_null("VFXLuz") as Node3D
	# Inactivo hasta pasar el retardo de armado
	set_deferred("monitoring", false)
	get_tree().create_timer(retardo_armado).timeout.connect(func():
		if is_instance_valid(self) and not _activado:
			_armado = true
			set_deferred("monitoring", true)
	)

	# Latido del icono: escala sube/baja rítmicamente
	if _icono:
		var base := escala_base_icono
		var pico := escala_base_icono * escala_palpito
		var tw := create_tween()
		tw.set_loops()
		tw.tween_property(_icono, "scale", Vector3.ONE * pico, duracion_palpito) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(_icono, "scale", Vector3.ONE * base, duracion_palpito) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _process(delta: float) -> void:
	if not _icono:
		return
	# Flotación suave sobre la columna de luz
	_tiempo += delta
	_icono.position.y = altura_flotacion + sin(_tiempo * velocidad_flotacion) * amplitud_flotacion


func _on_body_entered(body: Node3D) -> void:
	if _activado or not _armado:
		return
	if not body.is_in_group("player"):
		return
	_activado = true
	set_deferred("monitoring", false)
	_reproducir_sonido_refuerzo()
	activada.emit()
	_desaparecer()


func _reproducir_sonido_refuerzo() -> void:
	if not SFX_REFUERZO_MENSAJERA:
		return
	var sfx_player := AudioStreamPlayer.new()
	sfx_player.stream = SFX_REFUERZO_MENSAJERA
	sfx_player.volume_db = 2.0
	sfx_player.bus = "Master"
	var root := get_tree().current_scene
	if not root:
		root = get_tree().root
	if root:
		root.add_child(sfx_player)
		sfx_player.play()
		sfx_player.finished.connect(sfx_player.queue_free)
	else:
		sfx_player.queue_free()


## Desaparición: encoge rápido y se libera
func _desaparecer() -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	if _icono:
		tw.tween_property(_icono, "modulate:a", 0.0, 0.18)
	tw.chain().tween_callback(queue_free)
