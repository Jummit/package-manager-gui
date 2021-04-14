tool
extends Control

signal file_system_changed

var addons_metadata : Dictionary
var installed : Array

var metadata_file := ProjectSettings.globalize_path("user://").get_base_dir()\
		.get_base_dir().get_base_dir().plus_file("addons.json")

const DEPENDENCIES := "res://godotmodules.txt"

const README_URL := "https://raw.githubusercontent.com/%s/%s/master/README.md"
const GITHUB_URL := "https://github.com/%s/%s"
const GIT_URL := "https://github.com/%s/%s.git"

onready var package_list : Tree = $HBoxContainer/AddonList/PackageList
onready var install_button : Button = $HBoxContainer/Details/HBoxContainer/HBoxContainer/InstallButton
onready var search_edit : LineEdit = $HBoxContainer/AddonList/SearchEdit
onready var package_discription : RichTextLabel = $HBoxContainer/Details/PackageDiscription
onready var uninstall_button : Button = $HBoxContainer/Details/HBoxContainer/HBoxContainer/UninstallButton
onready var link_edit : LineEdit = $HBoxContainer/AddonList/AddContainer/LinkEdit
onready var http_request : HTTPRequest = $HTTPRequest

func _ready() -> void:
	create_missing_files()
	load_metadata()
	var result = load_dependencies()
	if result is GDScriptFunctionState:
		yield(result, "completed")
	update_list()


func create_missing_files() -> void:
	var dir := Directory.new()
	if not dir.file_exists(metadata_file):
		var addons_file := File.new()
		addons_file.open(metadata_file, File.WRITE)
		addons_file.store_string("{}")
		addons_file.close()
	if not dir.file_exists(DEPENDENCIES):
		var file := File.new()
		file.open(DEPENDENCIES, File.WRITE)
		file.close()


func load_metadata() -> void:
	var addons_file := File.new()
	addons_file.open(metadata_file, File.READ)
	addons_metadata = parse_json(addons_file.get_as_text())
	addons_file.close()


func load_dependencies() -> void:
	var file := File.new()
	file.open(DEPENDENCIES, File.READ)
	for dependency in file.get_as_text().split("\n"):
		if not dependency:
			continue
		var url : String = dependency.split(" ")[0]
		installed.append(url)
		if not url in addons_metadata:
			yield(fetch_plugin_metadata(url.rstrip(".git")), "completed")
	file.close()


func get_addon_metadata(url : String) -> Dictionary:
	if not url.begins_with("https://github.com/"):
		url = "https://github.com/" + url
	var parts := Array(url.lstrip("https://github.com/").rstrip("/").split("/"))
	var user : String = parts.front()
	var repo_name : String = parts.back()
	var addon := {
		name = repo_name.replace("-", " ").replace("_", " ").capitalize(),
		author = user,
		git = GIT_URL % parts,
		readme = "",
	}
	http_request.request(README_URL % parts)
	var result : Array = yield(http_request, "request_completed")
	if result[0] == OK and result[1] == HTTPClient.RESPONSE_OK:
		addon.readme = result[3].get_string_from_utf8()
	return addon


func update_list() -> void:
	package_list.clear()
	package_list.create_item()
	for url in addons_metadata:
		var addon : Dictionary = addons_metadata[url]
		var addon_name : String = addon.name
		if url in installed:
			addon_name += " (Installed)" 
		if search_edit.text and not search_edit.text.to_lower() in\
				addon_name:
			continue
		var item := package_list.create_item()
		item.set_text(0, addon_name)
		item.set_metadata(0, addon)
	yield(get_tree(), "idle_frame")
	var first := package_list.get_root().get_next_visible()
	if first:
		first.select(0)
		show_addon_details(first.get_metadata(0))
	yield(get_tree(), "idle_frame")
	update_buttons()


func update_buttons():
	var one_to_install := false
	var one_to_uninstall := false
	var selected := package_list.get_next_selected(package_list.get_root())
	while selected:
		if selected.get_metadata(0).git in installed:
			one_to_uninstall = true
		else:
			one_to_install = true
		selected = package_list.get_next_selected(selected)
	install_button.visible = one_to_install
	uninstall_button.visible = one_to_uninstall


func call_package_manager(param : String) -> void:
	var out := []
	OS.execute("python3.9", [ProjectSettings.globalize_path(
			"res://package_manager/package_manager.py"), param, "-v"], true, out)

	
func update_file() -> void:
	var file := File.new()
	file.open(DEPENDENCIES, File.WRITE)
	for dependency in installed:
		file.store_string("%s master\n" % dependency)
	file.close()


func fetch_plugin_metadata(url : String) -> void:
	var metadata : Dictionary = yield(get_addon_metadata(url), "completed")
	addons_metadata[url] = metadata
	var file := File.new()
	file.open(metadata_file, File.WRITE)
	file.store_string(to_json(addons_metadata))
	file.close()


func show_addon_details(addon : Dictionary) -> void:
	package_discription.text = addon.readme


func _on_InstallButton_pressed() -> void:
	var selected := package_list.get_next_selected(package_list.get_root())
	while selected:
		installed.append(selected.get_metadata(0).git)
		selected = package_list.get_next_selected(selected)
	update_file()
	call_package_manager("update")
	emit_signal("file_system_changed")
	update_buttons()
	update_list()


func _on_UpdateButton_pressed() -> void:
	call_package_manager("update")
	emit_signal("file_system_changed")


func _on_UninstallButton_pressed() -> void:
	var selected := package_list.get_next_selected(package_list.get_root())
	while selected:
		installed.erase(selected.get_metadata(0).git)
		selected = package_list.get_next_selected(selected)
	update_file()
	call_package_manager("cleanall")
	call_package_manager("update")
	emit_signal("file_system_changed")
	update_buttons()
	update_list()


func _on_AddButton_pressed() -> void:
	for url in link_edit.text.split(" "):
		yield(fetch_plugin_metadata(url), "completed")
	update_list()


func _on_PackageList_multi_selected(_item : TreeItem, _column : int,
		_is_selected : bool) -> void:
	show_addon_details(package_list.get_selected().get_metadata(0))
	yield(get_tree(), "idle_frame")
	update_buttons()


func _on_SearchEdit_text_changed(_new_text : String) -> void:
	update_list()
