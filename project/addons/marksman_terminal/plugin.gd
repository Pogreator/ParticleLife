@tool
extends EditorPlugin

func _enable_plugin() -> void:
	add_autoload_singleton("Marksman_Terminal","res://addons/marksman_terminal/Console.gd")
	
func _disable_plugin() -> void:
	remove_autoload_singleton("Marksman_Terminal")
