@tool
class_name HombrePez
extends Node3D

## Wrapper posicionable para el hombre pez en el nivel pueblo.
## Aplica el material con textura a todas las mallas importadas del GLB,
## gestiona su capa visual (capa 1 para primer plano nítido, capa 2 para fondo DOF),
## e implementa una animación procedural de respiración sutil mediante estiramiento
## vertical y expansión del torso.

# ─────────────────────────────────────────────────────────────────────────────
# CONSTANTES
# ─────────────────────────────────────────────────────────────────────────────
const INDICE_SUPERFICIE_PRINCIPAL: int = 0
const EXPONENTE_CURVA_RESPIRACION: float = 1.3

# ─────────────────────────────────────────────────────────────────────────────
# EXPORTS
# ─────────────────────────────────────────────────────────────────────────────
@export_category("Configuración Visual")
@export var material_hombre_pez: StandardMaterial3D:
	set(nuevo_material):
		material_hombre_pez = nuevo_material
		if is_node_ready():
			_aplicar_material()

@export_flags_3d_render var capa_visual: int = 1:
	set(nueva_capa):
		capa_visual = nueva_capa
		if is_node_ready():
			_aplicar_capa_visual(self)

@export_group("Animación Respiración")
@export var habilitar_respiracion: bool = true:
	set(valor):
		habilitar_respiracion = valor
		if not habilitar_respiracion and is_instance_valid(modelo):
			modelo.scale = Vector3.ONE

@export var velocidad_respiracion: float = 2.0  ## Ciclo de respiración en radianes/segundo (~3.1s por ciclo)
@export var amplitud_estiramiento_y: float = 0.035  ## Estiramiento sutil vertical de la parte superior (3.5%)
@export var amplitud_expansion_xz: float = 0.015  ## Expansión sutil del torso/pecho (1.5%)
@export var previsualizar_en_editor: bool = true  ## Si es true, la respiración se visualiza también en el editor

# ─────────────────────────────────────────────────────────────────────────────
# VARIABLES PRIVADAS
# ─────────────────────────────────────────────────────────────────────────────
var _tiempo_respiracion: float = 0.0

# ─────────────────────────────────────────────────────────────────────────────
# ONREADY
# ─────────────────────────────────────────────────────────────────────────────
@onready var modelo: Node3D = $Model


# ─────────────────────────────────────────────────────────────────────────────
# FUNCIONES BUILT-IN
# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	if "fondo" in name.to_lower():
		capa_visual = 2
	_aplicar_material()
	_aplicar_capa_visual(self)


func _process(delta: float) -> void:
	if not habilitar_respiracion:
		return
	if Engine.is_editor_hint() and not previsualizar_en_editor:
		return
	if not is_instance_valid(modelo):
		return
	_actualizar_respiracion(delta)


# ─────────────────────────────────────────────────────────────────────────────
# FUNCIONES PÚBLICAS
# ─────────────────────────────────────────────────────────────────────────────
## Aplica el material configurado a la instancia del modelo.
func aplicar_material() -> void:
	_aplicar_material()


## Resetea la escala del modelo al valor neutro.
func reiniciar_respiracion() -> void:
	_tiempo_respiracion = 0.0
	if is_instance_valid(modelo):
		modelo.scale = Vector3.ONE


# ─────────────────────────────────────────────────────────────────────────────
# FUNCIONES PRIVADAS
# ─────────────────────────────────────────────────────────────────────────────
func _actualizar_respiracion(delta: float) -> void:
	_tiempo_respiracion += delta
	# Curva orgánica de respiración: inhalación suave con expansión y exhalación progresiva
	var onda_seno: float = sin(_tiempo_respiracion * velocidad_respiracion)
	var curva: float = pow(0.5 + 0.5 * onda_seno, EXPONENTE_CURVA_RESPIRACION)
	
	var escala_y: float = 1.0 + curva * amplitud_estiramiento_y
	var escala_xz: float = 1.0 + curva * amplitud_expansion_xz
	modelo.scale = Vector3(escala_xz, escala_y, escala_xz)


func _aplicar_material() -> void:
	if material_hombre_pez == null:
		return
	var raiz_modelo: Node = modelo
	if not is_instance_valid(raiz_modelo):
		raiz_modelo = find_child("Model", true, false)
		if raiz_modelo == null:
			return
	_aplicar_a_instancias(raiz_modelo)


func _aplicar_a_instancias(nodo: Node) -> void:
	if nodo is MeshInstance3D:
		var malla_instancia: MeshInstance3D = nodo as MeshInstance3D
		malla_instancia.material_override = material_hombre_pez
		if malla_instancia.mesh != null and malla_instancia.mesh.get_surface_count() > INDICE_SUPERFICIE_PRINCIPAL:
			malla_instancia.set_surface_override_material(INDICE_SUPERFICIE_PRINCIPAL, material_hombre_pez)
	for hijo in nodo.get_children():
		_aplicar_a_instancias(hijo)


func _aplicar_capa_visual(nodo: Node) -> void:
	if nodo is VisualInstance3D:
		(nodo as VisualInstance3D).layers = capa_visual
	for hijo in nodo.get_children():
		_aplicar_capa_visual(hijo)
