extends CharacterBody3D

@export var speed = 200.0
@export var turn_speed = 3.0
@export var jump_force = 20.0 # The massive get-unstuck jump!
@export var gravity = 1
# We multiply gravity by 3 so the car feels heavy and sticks to your giant slides!
var default_gravity = ProjectSettings.get_setting("physics/3d/default_gravity") * gravity


func _physics_process(delta):
	# 1. APPLY GRAVITY
	if not is_on_floor():
		velocity.y -= default_gravity * delta

	# 2. THE HIGH JUMP (Spacebar)
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_force

	# 3. STEERING (Left / Right Arrows)
	# ui_left and ui_right are built into Godot automatically
	var turn = Input.get_axis("ui_right", "ui_left") 
	rotation.y += turn * turn_speed * delta

	# 4. GAS AND BRAKE (Up / Down Arrows)
	var gas = Input.get_axis("ui_down", "ui_up") 
	
	# Find out which way the front of the car is currently pointing
	var forward_direction = -transform.basis.z 
	
	if gas != 0:
		# Drive in that direction!
		velocity.x = forward_direction.x * gas * speed
		velocity.z = forward_direction.z * gas * speed
	else:
		# If we let go of the gas, slam on the brakes (friction)
		velocity.x = move_toward(velocity.x, 0, 2.0)
		velocity.z = move_toward(velocity.z, 0, 2.0)

	# Apply everything to the physics engine
	move_and_slide()
