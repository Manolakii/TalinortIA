class_name StateMachine
extends Node
## Máquina de estados simple: cada hijo es un State. Se cambia con transition_to(&"Nombre").

signal state_changed(previous: StringName, current: StringName)

@export var initial_state: State

var current: State
var _states: Dictionary[StringName, State] = {}


## Se llama desde el dueño cuando ya está listo (así los estados pueden usarlo en enter()).
func start(owner_body: Node) -> void:
	for child: Node in get_children():
		var state := child as State
		if state == null:
			continue
		state.owner_body = owner_body
		state.machine = self
		_states[StringName(state.name)] = state
	current = initial_state if initial_state != null else _states.values()[0]
	current.enter(&"")


func physics_update(delta: float) -> void:
	if current != null:
		current.physics_update(delta)


func transition_to(state_name: StringName) -> void:
	if not _states.has(state_name):
		push_error("StateMachine: no existe el estado '%s'" % state_name)
		return
	var previous: StringName = StringName(current.name)
	if previous == state_name:
		return
	current.exit()
	current = _states[state_name]
	current.enter(previous)
	state_changed.emit(previous, state_name)


func current_name() -> StringName:
	return StringName(current.name) if current != null else &""
