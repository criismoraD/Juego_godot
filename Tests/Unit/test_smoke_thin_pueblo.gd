extends "res://addons/gut/test.gd"

## Tests unitarios para SmokeThinVFX_07 en Nivel Pueblo.
## Verifica que la escena de humo exista y se instancie correctamente dentro del nivel.

const SCENE_PUEBLO: PackedScene = preload("res://Levels/Nivel_Pueblo/NivelPueblo.tscn")
const SCENE_SMOKE: PackedScene = preload("res://assets/BinbunVFX/smoke_effects/effects/smoke_thin/smoke_thin_vfx_07.tscn")

func test_smoke_thin_vfx_07_se_instancia_correctamente():
	# Arrange
	var humo: Node = SCENE_SMOKE.instantiate()
	
	# Act
	add_child_autofree(humo)
	
	# Assert
	assert_not_null(humo, "SmokeThinVFX_07 debe instanciarse sin errores")
	var particles: GPUParticles3D = humo.find_child("Smoke", true, false) as GPUParticles3D
	assert_not_null(particles, "SmokeThinVFX_07 debe contener el nodo GPUParticles3D 'Smoke'")


func test_smoke_thin_vfx_07_existe_en_nivel_pueblo():
	# Arrange & Act
	var nivel: Node = SCENE_PUEBLO.instantiate()
	add_child_autofree(nivel)
	
	# Assert
	var smoke_pueblo: Node = nivel.find_child("SmokeThinVFX_07", true, false)
	assert_not_null(smoke_pueblo, "Debe existir un nodo 'SmokeThinVFX_07' en NivelPueblo.tscn")
