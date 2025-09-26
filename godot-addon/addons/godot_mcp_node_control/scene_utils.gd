extends Node

var editor_interface = null

func _ready() -> void:
	if Engine.is_editor_hint():
		editor_interface = EditorInterface

func _validate_editor_access() -> String:
	"""Validate that we have access to editor functionality"""
	if not Engine.is_editor_hint():
		return "Scene operations are only available in editor mode"

	if not editor_interface:
		return "EditorInterface not available"

	return ""

func get_current_scene_info() -> Dictionary:
	"""Get information about the currently edited scene"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	var scene_path = root.scene_file_path
	if scene_path.is_empty():
		return {"error": "Current scene has not been saved yet"}

	return {
		"scene_path": scene_path,
		"scene_name": scene_path.get_file().get_basename(),
		"root_node_type": root.get_class(),
		"root_node_name": root.name,
		"child_count": root.get_child_count()
	}

func open_scene(scene_path: String) -> Dictionary:
	"""Open a scene file in the editor"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	if not FileAccess.file_exists(scene_path):
		return {"error": "Scene file does not exist: %s" % scene_path}

	if not scene_path.ends_with(".tscn"):
		return {"error": "Invalid scene file extension. Must be .tscn"}

	editor_interface.open_scene_from_path(scene_path)

	return {"success": true, "scene_path": scene_path}

func save_scene() -> Dictionary:
	"""Save the currently edited scene"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	if root.scene_file_path.is_empty():
		return {"error": "Scene has not been saved yet. Use 'Save Scene As' first"}

	var packed_scene = PackedScene.new()
	var result = packed_scene.pack(root)
	if result != OK:
		return {"error": "Failed to pack scene: %s" % error_string(result)}

	result = ResourceSaver.save(packed_scene, root.scene_file_path)
	if result != OK:
		return {"error": "Failed to save scene: %s" % error_string(result)}

	return {"success": true, "scene_path": root.scene_file_path}

func save_scene_as(scene_path: String) -> Dictionary:
	"""Save the currently edited scene to a new file"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	if not scene_path.ends_with(".tscn"):
		return {"error": "Invalid scene file extension. Must be .tscn"}

	var packed_scene = PackedScene.new()
	var result = packed_scene.pack(root)
	if result != OK:
		return {"error": "Failed to pack scene: %s" % error_string(result)}

	result = ResourceSaver.save(packed_scene, scene_path)
	if result != OK:
		return {"error": "Failed to save scene: %s" % error_string(result)}

	# Update the scene file path
	root.scene_file_path = scene_path

	return {"success": true, "scene_path": scene_path}

func create_new_scene(root_node_type: String = "Node2D") -> Dictionary:
	"""Create a new empty scene with a specified root node type and open it in the editor."""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	if not ClassDB.class_exists(root_node_type):
		return {"error": "Invalid node type: %s" % root_node_type}

	# 1. Create the root node in memory
	var root_node = ClassDB.instantiate(root_node_type)
	if not root_node:
		return {"error": "Failed to instantiate root node of type: %s" % root_node_type}
	root_node.name = root_node_type

	# 2. Pack the node into a PackedScene
	var packed_scene = PackedScene.new()
	packed_scene.pack(root_node)

	# 3. Save to a temporary file
	var temp_scene_path = "res://.mcp_temp_scene.tscn"
	var save_err = ResourceSaver.save(packed_scene, temp_scene_path)
	if save_err != OK:
		root_node.free() # Clean up the node
		return {"error": "Failed to save temporary scene: %s" % error_string(save_err)}

	# 4. Open the temporary scene in the editor
	editor_interface.open_scene_from_path(temp_scene_path)

	# 5. Clean up the temporary file
	var dir_access = DirAccess.open("res://")
	if dir_access:
		dir_access.remove(temp_scene_path)

	# After opening, the editor's scene root is the new node.
	# We need to clear its scene_file_path to make it an "unsaved" scene.
	var new_root = editor_interface.get_edited_scene_root()
	if new_root:
		new_root.scene_file_path = ""

	return {
		"success": true,
		"root_node_type": root_node_type,
		"root_node_name": root_node.name,
		"message": "Successfully created a new unsaved scene. Use save_scene_as() to save it to a file."
	}

func instantiate_scene(scene_path: String, parent_path: String = ".") -> Dictionary:
	"""Instantiate a scene and add it as a child to the specified parent"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	if not FileAccess.file_exists(scene_path):
		return {"error": "Scene file does not exist: %s" % scene_path}

	# Load the packed scene
	var packed_scene = load(scene_path)
	if not packed_scene or not packed_scene is PackedScene:
		return {"error": "Failed to load scene: %s" % scene_path}

	# Instantiate the scene
	var instance = packed_scene.instantiate()
	if not instance:
		return {"error": "Failed to instantiate scene"}

	# Find parent node
	var parent = _get_node_by_path(parent_path)
	if not parent:
		return {"error": "Parent node not found: %s" % parent_path}

	# Add as child
	parent.add_child(instance)
	instance.owner = editor_interface.get_edited_scene_root()

	return {
		"success": true,
		"instance_path": str(instance.get_path()),
		"instance_name": instance.name,
		"scene_path": scene_path
	}

func pack_scene_from_node(node_path: String, save_path: String) -> Dictionary:
	"""Create a packed scene from an existing node and save it"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var node = _get_node_by_path(node_path)
	if not node:
		return {"error": "Node not found: %s" % node_path}

	if not save_path.ends_with(".tscn"):
		return {"error": "Invalid scene file extension. Must be .tscn"}

	var packed_scene = PackedScene.new()
	var result = packed_scene.pack(node)
	if result != OK:
		return {"error": "Failed to pack scene: %s" % error_string(result)}

	result = ResourceSaver.save(packed_scene, save_path)
	if result != OK:
		return {"error": "Failed to save packed scene: %s" % error_string(result)}

	return {"success": true, "save_path": save_path, "node_path": node_path}

func _get_node_by_path(node_path: String) -> Node:
	"""Helper function to get node by path"""
	var root = editor_interface.get_edited_scene_root()
	if not root:
		return null

	if node_path == ".":
		return root

	return root.get_node_or_null(node_path)