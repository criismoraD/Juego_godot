class_name HealthComponent
extends Node
## Componente reutilizable para gestión de vida, daño y muerte
## Se puede añadir a cualquier entidad (jugador, enemigos, jefes)

signal health_changed(current: int, max_health: int)
signal damaged(amount: int, damage_type: String)
signal healed(amount: int)
signal died()
signal revived()

@export var max_health: int = 100
@export var current_health: int = 100
@export var invulnerable_time: float = 1.0
@export var damage_flash_material: Material
@export var death_sound: AudioStream

var _invulnerable: bool = false
var _invulnerable_timer: float = 0.0
var _is_dead: bool = false
var _sprite: Sprite2D
var _original_material: Material

func _ready() -> void:
	current_health = max_health
	_sprite = get_parent().get_node_or_null("Sprite2D") if get_parent() else null
	if _sprite and _sprite.material:
		_original_material = _sprite.material


func _physics_process(delta: float) -> void:
	if _invulnerable:
		_invulnerable_timer -= delta
		if _invulnerable_timer <= 0:
			_set_invulnerable(false)


func take_damage(amount: int, damage_type: String = "normal", knockback: Vector2 = Vector2.ZERO) -> void:
	if _is_dead or _invulnerable:
		return
	
	current_health = max(0, current_health - amount)
	health_changed.emit(current_health, max_health)
	damaged.emit(amount, damage_type)
	
	_flash_damage()
	_apply_knockback(knockback)
	
	if current_health <= 0:
		die()


func heal(amount: int) -> void:
	if _is_dead:
		return
	
	var old_health: int = current_health
	current_health = min(max_health, current_health + amount)
	var actual_heal: int = current_health - old_health
	
	if actual_heal > 0:
		health_changed.emit(current_health, max_health)
		healed.emit(actual_heal)


func die() -> void:
	if _is_dead:
		return
	
	_is_dead = true
	_set_invulnerable(true)
	
	if death_sound:
		var audio_player: AudioStreamPlayer = AudioStreamPlayer.new()
		audio_player.stream = death_sound
		get_parent().add_child(audio_player)
		audio_player.play()
		await audio_player.finished
		audio_player.queue_free()
	
	died.emit()


func revive(reset_health: bool = true) -> void:
	if not _is_dead:
		return
	
	_is_dead = false
	if reset_health:
		current_health = max_health
	else:
		current_health = 1
	
	_set_invulnerable(true)
	revived.emit()
	health_changed.emit(current_health, max_health)


func is_dead() -> bool:
	return _is_dead


func is_invulnerable() -> bool:
	return _invulnerable


func set_max_health(new_max: int) -> void:
	max_health = new_max
	current_health = min(current_health, max_health)
	health_changed.emit(current_health, max_health)


func percentage() -> float:
	if max_health == 0:
		return 0.0
	return float(current_health) / float(max_health)


func _set_invulnerable(state: bool) -> void:
	_invulnerable = state
	if state:
		_invulnerable_timer = invulnerable_time
	else:
		_invulnerable_timer = 0.0


func _flash_damage() -> void:
	if not _sprite or not damage_flash_material:
		return
	
	_sprite.material = damage_flash_material
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(_sprite):
		_sprite.material = _original_material


func _apply_knockback(knockback: Vector2) -> void:
	if knockback.length() > 0:
		var rigid_body: RigidBody2D = get_parent() as RigidBody2D
		if rigid_body:
			rigid_body.apply_impulse(knockback)
