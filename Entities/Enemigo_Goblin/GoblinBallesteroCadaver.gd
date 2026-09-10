class_name GoblinBallesteroCadaver
extends Node3D

## Cadáver decorativo del Goblin ballestero para la cinemática de fin de
## oleada 5 (NIVEL01): el modelo estático congelado en el ÚLTIMO frame de
## su animación de muerte, sobre el suelo de la isla enemiga. Sin lógica
## de enemigo: decoración pura. Invisible fuera de la cinemática
## (CinematicaOleada5 lo muestra al arrancar, como las nieblas de guerra).

## Animación de muerte cuya pose final se congela (una de las tres del GLB;
## la 1 es la caída de bruces clásica: mejor lectura de "cadáver").
const ANIM_MUERTE := "Armature|Armature|ENEMIGO_GOBLING_MUERTE_1"
## Frame exacto de congelado: el final del clip (todo el cuerpo en el suelo).
const MARGEN_FRAME: float = 0.01
## Mismo material que el goblin vivo (con su contorno TOON).
const MAT_GOBLIN: Material = preload("res://Entities/Enemigo_Goblin/GOBLING_MATERIAL.tres")

@onready var _anim_player: AnimationPlayer = find_child("AnimationPlayer", true, false) as AnimationPlayer


func _ready() -> void:
	visible = false
	_aplicar_material()
	if _anim_player == null:
		push_warning("[GoblinCadaver] Sin AnimationPlayer en el GLB.")
		return
	if not _anim_player.has_animation(ANIM_MUERTE):
		push_warning("[GoblinCadaver] Sin clip '%s'." % ANIM_MUERTE)
		return
	_congelar_ultimo_frame()


## Contorno y textura del goblin vivo (el GLB crudo trae material embebido
## sin la línea negra).
func _aplicar_material() -> void:
	for mesh in find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_override = MAT_GOBLIN


## Congela el modelo en el último frame de la muerte: seek al final del
## clip con la reproducción pausada (sin timers ni _process: queda fijo).
func _congelar_ultimo_frame() -> void:
	var clip := _anim_player.get_animation(ANIM_MUERTE)
	_anim_player.stop()
	_anim_player.play(ANIM_MUERTE)
	_anim_player.pause()
	_anim_player.seek(maxf(clip.length - MARGEN_FRAME, 0.0), true)
