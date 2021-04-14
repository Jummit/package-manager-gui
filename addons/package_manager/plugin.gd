tool
extends EditorPlugin

var package_manager_panel := preload("res://addons/package_manager/package_manager_panel.tscn").instance()

func _enter_tree() -> void:
	get_editor_interface().get_editor_viewport().add_child(package_manager_panel)
	package_manager_panel.connect("file_system_changed", self,
			"_on_PackageManagerPanel_file_system_changed")
	make_visible(false)


func _exit_tree() -> void:
	package_manager_panel.queue_free()


func has_main_screen():
	return true


func make_visible(visible):
	package_manager_panel.visible = visible


func get_plugin_name():
	return "Packages"


func get_plugin_icon():
	return get_editor_interface().get_base_control().get_icon("AssetLib", "EditorIcons")


func _on_PackageManagerPanel_file_system_changed():
	get_editor_interface().get_resource_filesystem().scan()
