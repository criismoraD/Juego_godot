class_name HumoEstilizadoJefe
extends GPUParticles3D

## Efecto de humo estilizado para el Jefe Submarino dañado.
## Controla la emisión de partículas con shader de ruido Voronoi y gradiente térmico.

@export var activo: bool = false:
	set(valor):
		activo = valor
		emitting = valor


func _ready() -> void:
	emitting = activo


func encender() -> void:
	activo = true
	emitting = true


func apagar() -> void:
	activo = false
	emitting = false
