@tool
extends EditorPlugin
const Atlas = preload("atlas_panel.gd")
var panel

func _enter_tree() -> void:
	panel = Atlas.new()
	get_editor_interface().get_editor_main_screen().add_child(panel)
	_make_visible(false)

func _exit_tree() -> void:
	if is_instance_valid(panel):
		panel.write_recovery()
		panel.queue_free()

func _has_main_screen() -> bool:
	return true

func _get_plugin_name() -> String:
	return "Hughes Atlas"

func _get_plugin_icon() -> Texture2D:
	return get_editor_interface().get_base_control().get_theme_icon("GraphEdit", "EditorIcons")

func _make_visible(value: bool) -> void:
	if is_instance_valid(panel):
		panel.visible = value

func _save_external_data() -> void:
	if is_instance_valid(panel) and panel.dirty:
		panel.save_document()

func _get_unsaved_status(for_scene: String) -> String:
	if for_scene.is_empty() and is_instance_valid(panel) and panel.dirty:
		return "Hughes Atlas contains unsaved authoring changes. Save in its workspace; a recovery copy is kept on disable."
	return ""
