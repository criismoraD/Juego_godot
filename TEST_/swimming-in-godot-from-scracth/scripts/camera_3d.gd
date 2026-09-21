extends Camera3D

@export var move_speed: float = 10.0
@export var look_sensitivity: float = 0.002

var _rot_x: float = 0.0
var _rot_y: float = 0.0

func _ready():
	# Locks the mouse to the center of the screen
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	# Handle Mouse Movement
	if event is InputEventMouseMotion:
		_rot_x -= event.relative.x * look_sensitivity
		_rot_y -= event.relative.y * look_sensitivity
		_rot_y = clamp(_rot_y, -1.5, 1.5) # Prevent flipping upside down
		
		transform.basis = Basis.from_euler(Vector3(_rot_y, _rot_x, 0))

	# Toggle Mouse Lock (Press Escape to get your mouse back)
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(delta):
	var direction = Vector3.ZERO
	
	# WASD Movement relative to where the camera is looking
	if Input.is_key_pressed(KEY_W): direction -= transform.basis.z
	if Input.is_key_pressed(KEY_S): direction += transform.basis.z
	if Input.is_key_pressed(KEY_A): direction -= transform.basis.x
	if Input.is_key_pressed(KEY_D): direction += transform.basis.x
	if Input.is_key_pressed(KEY_E): direction += transform.basis.y # Fly Up
	if Input.is_key_pressed(KEY_Q): direction -= transform.basis.y # Fly Down

	if direction.length() > 0:
		global_position += direction.normalized() * move_speed * delta
