extends Node

func delete_specific_keybind(action):
	InputMap.action_erase_events(action)

func set_specific_keybind(action, keybind):
	if not InputMap.get_actions().has(action):
		InputMap.add_action(action)
	delete_specific_keybind(action)
	var key = InputEventKey.new()
	key.physical_keycode = keybind.unicode_at(0)
	InputMap.action_add_event(action, key)

func recursive_visible(node,state : bool) -> void:
	node.visible = state
	if node.get_child_count() > 0:
		for i in node.get_children():
			recursive_visible(i,state)

func remove_line(value:String,lines:int = 1) -> String:
	var strings = value.split('\n')
	if strings.size() > lines:
		strings.remove_at(strings.size()-lines)
		return '\n'.join(strings) + '\n'
	else:
		return ''
		
func swap(i : int, j : int, a : Array) -> Array:
	var t = a[i]
	a[i] = a[j]
	a[j] = t
	return a
