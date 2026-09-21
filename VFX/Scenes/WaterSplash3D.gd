@tool
class_name WaterSplash3D
extends GPUParticles3D

## Salpicadura de agua 3D (2.5D): adaptación del water_splash de GODOT-VFX-LIBRARY
## (addons/vfx_library, CPUParticles2D) a GPUParticles3D con sus mismos parámetros:
## 24 gotas, 0.8 s, explosividad total, esfera r=0.12, cono 60° hacia arriba,
## gravedad y degradado azul->transparente.
## One-shot autodestructivo: instanciar, posicionar y emitir (o usar spawn()).
## En el editor previsualiza en bucle sola; en juego es one-shot.

## Genera una salpicadura en un punto y la libera sola al terminar.
static func spawn(pos: Vector3, escala: float = 1.0, padre: Node = null) -> WaterSplash3D:
	# load() en vez de preload(): evita inclusión cíclica con la propia escena.
	var escena: PackedScene = load("res://VFX/Scenes/WaterSplash3D.tscn") as PackedScene
	if escena == null:
		return null
	var fx := escena.instantiate() as WaterSplash3D
	if fx == null:
		return null
	var raiz: Node = padre
	if raiz == null:
		var arbol := Engine.get_main_loop() as SceneTree
		raiz = arbol.current_scene if arbol and arbol.current_scene else (arbol.root if arbol else null)
	if raiz == null:
		fx.queue_free()
		return null
	raiz.add_child(fx)
	fx.global_position = pos
	fx.scale = Vector3(escala, escala, escala)
	fx.emitting = true
	return fx


func _ready() -> void:
	if Engine.is_editor_hint():
		# Solo previsualización: en bucle para verla en el editor
		one_shot = false
		emitting = true
		return
	emitting = false
	finished.connect(_al_terminar)
	# Red de seguridad por si finished no dispara (headless/tests)
	if is_inside_tree() and get_tree():
		get_tree().create_timer(lifetime + 1.5).timeout.connect(_al_terminar)


func _al_terminar() -> void:
	if is_instance_valid(self) and not is_queued_for_deletion():
		queue_free()
