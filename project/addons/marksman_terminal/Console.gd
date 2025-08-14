class_name Console
extends Control

const UI = preload("uid://ben5ih8gcc5qu")
const HELPER = preload("uid://4a572geex7c1")
var Helper = null
var Ui : Control = null
var canvas_layer : CanvasLayer = null
var text_label : RichTextLabel = null

var enabled = false
var dir : Node = null

var command_list = {
	"dir" = {"fun": show_dir, "arg" : []},
	"ls" = {"fun": show_dir, "arg" : []},
	"help" = {"fun": list_commands, "arg" : []},
	"clear" = {"fun": clear_terminal, "arg" : []},
	"path" = {"fun": print_path, "arg" : []},
	"cd" = {"fun": cd, "arg" : [TYPE_STRING]},
	"pvar" = {"fun" : print_var, "arg" : [TYPE_STRING, TYPE_STRING]},
	"svar" = {"fun" : set_var, "arg" : [TYPE_STRING, TYPE_STRING, TYPE_STRING]},
}

var command : String = ""
var prev_command : Array = []
var prev_idx = -1

func _ready() -> void:
	Helper = HELPER.new()
	Helper.set_specific_keybind("Toggle_Console","\\")
	dir = get_tree().root
	# Canvaslayer
	canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 1280
	add_child(canvas_layer)
	
	# UI init
	Ui = UI.instantiate()
	canvas_layer.add_child(Ui)
	canvas_layer.hide()
	Ui.process_mode = Node.PROCESS_MODE_DISABLED
	Ui.modulate.a = 0.8
	
	# Text label
	text_label = Ui.find_child("RichTextLabel")
	
	reset_text()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Toggle_Console"):
		enabled = !enabled
		
		if enabled: 
			canvas_layer.show()
			Ui.process_mode = Node.PROCESS_MODE_ALWAYS
			get_tree().current_scene.process_mode = Node.PROCESS_MODE_DISABLED
		else: 
			canvas_layer.hide()
			get_tree().current_scene.process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(event: InputEvent) -> void:
	if (enabled and event is InputEventKey and event.is_pressed()) and !event.is_action_pressed("Toggle_Console"):
		var key_event := event as InputEventKey
		if event.keycode == KEY_BACKSPACE: command = command.left(command.length()-1); accept_event()
		elif event.keycode == KEY_UP and prev_command.size() > 0: 
			prev_idx = clamp(prev_idx+1,-1,prev_command.size()-1)
			if prev_idx == -1: command = ''
			else: command = prev_command[clamp(prev_idx,0,9)]
		elif event.keycode == KEY_DOWN and prev_command.size() > 0: 
			prev_idx = clamp(prev_idx-1,-1,prev_command.size()-1)
			if prev_idx == -1: command = ''
			else: command = prev_command[clamp(prev_idx,0,9)]
		elif event.keycode == KEY_ENTER: prev_idx = -1 ; command_enter()
		elif !(key_event.keycode & KEY_SPECIAL):
			var letter := String.chr(key_event.unicode)
			command = command + letter
			accept_event()
		if !(event.keycode == KEY_ENTER): reset_text()

func new_text() -> void:
	text_label.text = text_label.text + ("[%s] %s|" % [dir.get_name(),command])

func reset_text() -> void:
	text_label.text = Helper.remove_line(text_label.text,1)
	text_label.text = text_label.text + ("[%s] %s|" % [dir.get_name(),command])

func command_enter() -> void:
	var error = ""
	var error_state = 1
	var command_split = command.split(' ')
	prev_command.push_front(command)
	if prev_command.size() > 10: prev_command.erase(-1)
	for i in command_list:
		if i == command_split[0]:
			error_state = 0
			if command_list[i]["arg"].size() <= command_split.size()-1:
				if command_list[i]["arg"].size() == 0: command_list[i]["fun"].call()
				else:
					var args = []
					for k in range(command_list[i]["arg"].size()):
						args.append(type_convert(command_split[k+1],command_list[i]["arg"][k]))
					command_list[i]["fun"].callv(args)
			else:
				error_state = 2
			break
	match error_state:
		1: terminal_print("Command not found")
		2: terminal_print("Not enough arguments provided")
	command = ""
	reset_text()

func terminal_print(value:String) -> void:
	text_label.text = text_label.text + ("\n%s\n" % [value])

func clear_terminal() -> void:
	text_label.text = ""

func cd(path:String) -> void:
	path = path.replace('"','').replace("'",'')
	if path == '..' and dir != get_tree().root: dir = dir.get_parent()
	else: 
		if dir.get_node(path) == null: 
			path = path.replace('_',' ')
			if dir.get_node(path) == null:
				terminal_print("Path not found")
			else: dir = dir.get_node(path)
		else: dir = dir.get_node(path)

func list_commands() -> void:
	var out = ""
	for i in command_list:
		var args = ""
		if command_list[i]["arg"].size() != 0: 
			var count = 0
			for k in command_list[i]["arg"]:
				args = args + "arg%s " % [count]
				count+=1
		out = "%s %s %s \n" % [out,i,args]
	terminal_print(out)

func show_dir() -> void:
	var dirs  = ""
	for i in dir.get_children(): dirs += "%s|" % [i.name]
	terminal_print(dirs)

func print_path() -> void:
	var path = dir.get_path()
	terminal_print("%s" % [path])

func print_var(path:String,variable:String) -> void:
	var node_path = null
	path = path.replace('"','').replace("'",'')
	variable = variable.replace('"','').replace("'",'')
	if path.to_lower() == "s": node_path = dir
	else: 
		node_path = dir.get_node(path)
		if dir.get_node(path) == null: 
				path = path.replace('_',' ')
				if dir.get_node(path) == null:
					terminal_print("Path not found"); return
	var var_get = node_path.get(variable)
	if var_get == null: terminal_print("Variable not found")
	else: terminal_print("%s: %s" % [type_string(typeof(var_get)), str(var_get)])
	
func set_var(path:String,variable:String,value:String) -> void:
	var node_path = null
	path = path.replace('"','').replace("'",'')
	variable = variable.replace('"','').replace("'",'')
	if path.to_lower() == "s": node_path = dir
	else: 
		node_path = dir.get_node(path)
		if dir.get_node(path) == null: 
				path = path.replace('_',' ')
				if dir.get_node(path) == null:
					terminal_print("Path not found"); return
	var var_get = node_path.get(variable)
	if var_get == null: terminal_print("Variable not found"); return
	var true_value = type_convert(str_to_var(value.replace('_',' ')),typeof(var_get))
	node_path.set(variable,true_value)
	var_get = node_path.get(variable)
	terminal_print("%s: %s" % [type_string(typeof(var_get)), str(var_get)])

func add_command(name:String,function:Callable,args:Array) -> void:
	if command_list.has(name): push_error("Command %s already a thing" % [name])
	else: command_list[name] = {"fun": function, "arg" : args}
