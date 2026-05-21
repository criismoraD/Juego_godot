class_name PlayerStateMachine
extends Node
## Máquina de Estados para el Jugador - Gestiona transiciones de estado de forma clara
##
## Estados disponibles:
##   - IDLE: Jugador quieto en suelo
##   - WALKING: Movimiento horizontal
##   - RUNNING: Corriendo
##   - JUMPING: En el aire subiendo
##   - FALLING: Cayendo
##   - LANDING: Aterrizando (animación)
##   - CLIMBING: Escalando escalera
##   - AIMING: Apuntando con arco
##   - SHOOTING: Disparando
##   - HURT: Recibiendo daño
##   - DEAD: Muerto
##
## Uso desde Player.gd:
##   state_machine.transition_to("JUMPING")
##   if state_machine.is_in_state("CLIMBING"): ...

enum State {
	IDLE,
	WALKING,
	RUNNING,
	JUMPING,
	FALLING,
	LANDING,
	CLIMBING,
	AIMING,
	SHOOTING,
	HURT,
	DEAD
}

var current_state: State = State.IDLE
var previous_state: State = State.IDLE
var state_changed: Signal

var _state_names: Dictionary = {
	State.IDLE: "IDLE",
	State.WALKING: "WALKING",
	State.RUNNING: "RUNNING",
	State.JUMPING: "JUMPING",
	State.FALLING: "FALLING",
	State.LANDING: "LANDING",
	State.CLIMBING: "CLIMBING",
	State.AIMING: "AIMING",
	State.SHOOTING: "SHOOTING",
	State.HURT: "HURT",
	State.DEAD: "DEAD"
}

# Configuración de transiciones permitidas
var _allowed_transitions: Dictionary = {
	State.IDLE: [State.WALKING, State.RUNNING, State.JUMPING, State.AIMING, State.HURT, State.DEAD],
	State.WALKING: [State.IDLE, State.RUNNING, State.JUMPING, State.AIMING, State.HURT, State.DEAD],
	State.RUNNING: [State.IDLE, State.WALKING, State.JUMPING, State.AIMING, State.HURT, State.DEAD],
	State.JUMPING: [State.FALLING, State.HURT, State.DEAD],
	State.FALLING: [State.LANDING, State.CLIMBING, State.HURT, State.DEAD],
	State.LANDING: [State.IDLE, State.WALKING, State.RUNNING, State.JUMPING, State.HURT, State.DEAD],
	State.CLIMBING: [State.IDLE, State.FALLING, State.LANDING, State.HURT, State.DEAD],
	State.AIMING: [State.IDLE, State.WALKING, State.RUNNING, State.SHOOTING, State.HURT, State.DEAD],
	State.SHOOTING: [State.IDLE, State.WALKING, State.RUNNING, State.AIMING, State.HURT, State.DEAD],
	State.HURT: [State.IDLE, State.FALLING, State.DEAD],
	State.DEAD: []  # Estado terminal, no hay salida
}

func _ready():
	pass

## Intenta transicionar a un nuevo estado
func transition_to(new_state: State) -> bool:
	if not _can_transition_to(new_state):
		push_warning("[PlayerStateMachine] Transición inválida: %s -> %s" % [_state_names[current_state], _state_names[new_state]])
		return false
	
	previous_state = current_state
	current_state = new_state
	
	state_changed.emit(current_state, previous_state)
	return true

## Verifica si una transición es válida
func _can_transition_to(new_state: State) -> bool:
	if new_state == current_state:
		return true  # Ya está en ese estado
	
	if not _allowed_transitions.has(current_state):
		return false
	
	var allowed = _allowed_transitions[current_state]
	return new_state in allowed

## Obtiene el nombre del estado actual como string
func get_state_name() -> String:
	return _state_names.get(current_state, "UNKNOWN")

## Obtiene el nombre de un estado específico
func get_state_name_from_enum(state: State) -> String:
	return _state_names.get(state, "UNKNOWN")

## Verifica si está en un estado específico
func is_in_state(state: State) -> bool:
	return current_state == state

## Verifica si está en alguno de varios estados
func is_in_any_state(states: Array) -> bool:
	for state in states:
		if current_state == state:
			return true
	return false

## Fuerza una transición (ignora validaciones, usar solo en casos especiales)
func force_transition_to(new_state: State) -> void:
	previous_state = current_state
	current_state = new_state
	state_changed.emit(current_state, previous_state)

## Reinicia la máquina de estados al estado inicial
func reset() -> void:
	previous_state = current_state
	current_state = State.IDLE
	state_changed.emit(current_state, previous_state)

## Obtiene estadísticas de la máquina de estados (para debug)
func get_stats() -> Dictionary:
	return {
		"current": _state_names[current_state],
		"previous": _state_names[previous_state],
		"is_terminal": current_state == State.DEAD
	}

## Convierte un string a enum de estado
func string_to_state(state_str: String) -> State:
	for key in _state_names.keys():
		if _state_names[key] == state_str:
			return key
	return State.IDLE
