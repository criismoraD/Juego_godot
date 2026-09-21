@tool
extends Node3D

@export_group("Animation Settings")
@export var animation_name: String = "ripple"
@export var play_on_start: bool = true

@export_group("Dynamic VFX Layers")
## Drag any node from the Scene Tree into this array to control its visibility
@export var vfx_layers: Array[Node3D] = []

## Toggles visibility for ALL layers in the array at once
@export var layers_enabled: bool = true:
	set(value):
		layers_enabled = value
		_update_all_layers()

@export var anim_player: AnimationPlayer 

func _ready() -> void:
	_update_all_layers()
	
	if play_on_start:
		play_splash()

## Syncs the visibility of all nodes in the array to the 'layers_enabled' toggle
func _update_all_layers() -> void:
	for layer in vfx_layers:
		if is_instance_valid(layer):
			layer.visible = layers_enabled

## trigger
func play_splash() -> void:
	if anim_player:
		# Restart  the animation 
		anim_player.stop() 
		if anim_player.has_animation(animation_name):
			anim_player.play(animation_name)
			print("animation played")
			
		else:
			push_error("VFX Controller: Animation '" + animation_name + "' not found!")

## Use this to toggle a specific layer by its index in the array
func toggle_layer_index(index: int, is_visible: bool) -> void:
	if index >= 0 and index < vfx_layers.size():
		var layer = vfx_layers[index]
		if is_instance_valid(layer):
			layer.visible = is_visible
