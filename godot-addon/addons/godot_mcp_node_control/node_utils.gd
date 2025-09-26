extends Node

# Node utilities for Godot MCP Node Control
# Provides safe, robust node manipulation functions

var editor_interface = null

func _ready() -> void:
	# Get editor interface when available
	if Engine.is_editor_hint():
		editor_interface = EditorInterface
		if not editor_interface:
			push_warning("EditorInterface not available in node_utils")

func get_scene_tree() -> Dictionary:
	"""Get the current scene tree structure"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var tree_data = _build_node_tree(root)
	return {
		"root_node": root.name,
		"scene_path": root.scene_file_path if root.scene_file_path else "unsaved",
		"tree": tree_data
	}

func _build_node_tree(node: Node, depth: int = 0) -> Dictionary:
	"""Recursively build node tree structure"""
	var node_data = {
		"name": node.name,
		"type": node.get_class(),
		"path": str(node.get_path()),
		"children": []
	}

	# Add properties for common node types
	if node is Node2D or node is Node3D:
		node_data["position"] = node.position if node is Node2D else node.position
		if node is Node2D:
			node_data["rotation"] = node.rotation
			node_data["scale"] = node.scale
		else:
			node_data["rotation"] = node.rotation
			node_data["scale"] = node.scale

	# Add children (limit depth to prevent infinite recursion)
	if depth < 10:
		for child in node.get_children():
			node_data["children"].append(_build_node_tree(child, depth + 1))

	return node_data

func create_node(node_type: String, parent_path: String = ".", node_name: String = "") -> Dictionary:
	"""Create a new node in the scene"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	# Find parent node
	var parent_node = root.get_node_or_null(parent_path)
	if not parent_node and parent_path != ".":
		return {"error": "Parent node not found: %s" % parent_path}
	if not parent_node:
		parent_node = root

	# Validate node type
	if not ClassDB.class_exists(node_type):
		return {"error": "Invalid node type: %s" % node_type}

	# Create the node
	var new_node = ClassDB.instantiate(node_type)
	if not new_node:
		return {"error": "Failed to instantiate node of type: %s" % node_type}

	# Set name
	if node_name.is_empty():
		node_name = "%s_%d" % [node_type.to_lower(), parent_node.get_child_count()]
	new_node.name = node_name

	# Check if node is already in the scene tree (can happen with tool scripts)
	if new_node.is_inside_tree():
		# Remove from current parent first
		var current_parent = new_node.get_parent()
		if current_parent:
			current_parent.remove_child(new_node)

	# Make the change undoable
	var undo_redo = editor_interface.get_editor_undo_redo()
	undo_redo.create_action("Create Node: %s" % node_name)
	undo_redo.add_do_method(parent_node, "add_child", new_node)
	undo_redo.add_do_property(new_node, "owner", root)
	undo_redo.add_undo_method(parent_node, "remove_child", new_node)
	undo_redo.commit_action()

	return {
		"node_path": str(new_node.get_path()),
		"node_name": new_node.name,
		"node_type": node_type
	}

func delete_node(node_path: String) -> Dictionary:
	"""Delete a node from the scene"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var node = root.get_node_or_null(node_path)
	if not node:
		return {"error": "Node not found: %s" % node_path}

	if node == root:
		return {"error": "Cannot delete root node"}

	var parent = node.get_parent()
	if not parent:
		return {"error": "Node has no parent"}

	# Make the change undoable
	var undo_redo = editor_interface.get_editor_undo_redo()
	undo_redo.create_action("Delete Node: %s" % node.name)
	undo_redo.add_do_method(parent, "remove_child", node)
	undo_redo.add_undo_method(parent, "add_child", node)
	undo_redo.add_undo_property(node, "owner", root)
	undo_redo.commit_action()

	return {"deleted": true}

func get_node_properties(node_path: String) -> Dictionary:
	"""Get properties of a specific node"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var node = root.get_node_or_null(node_path)
	if not node:
		return {"error": "Node not found: %s" % node_path}

	var properties = {}

	# Get script properties if node has a script
	if node.script:
		properties["script"] = node.script.resource_path

	# Get built-in properties based on node type
	var property_list = node.get_property_list()
	for prop in property_list:
		var prop_name = prop.name
		# Skip internal properties
		if prop_name.begins_with("_") or prop_name in ["script", "owner"]:
			continue

		# Only include exported properties or common ones
		if prop.usage & PROPERTY_USAGE_EDITOR != 0:
			var value = node.get(prop_name)
			properties[prop_name] = _serialize_value(value)

	return {
		"node_path": node_path,
		"node_type": node.get_class(),
		"properties": properties
	}

func set_node_property(node_path: String, property_name: String, value) -> Dictionary:
	"""Set a property value on a node"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var node = root.get_node_or_null(node_path)
	if not node:
		return {"error": "Node not found: %s" % node_path}

	# Validate property exists
	if not node.get_property_list().any(func(p): return p.name == property_name):
		return {"error": "Property not found: %s" % property_name}

	# Get current value for undo
	var old_value = node.get(property_name)

	# Set the new value
	node.set(property_name, value)

	# Make undoable
	var undo_redo = editor_interface.get_editor_undo_redo()
	undo_redo.create_action("Set Property: %s.%s" % [node_path, property_name])
	undo_redo.add_do_property(node, property_name, value)
	undo_redo.add_undo_property(node, property_name, old_value)
	undo_redo.commit_action()

	return {"success": true}

func add_script_to_node(node_path: String, script_content: String) -> Dictionary:
	"""Add a GDScript to a node"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var node = root.get_node_or_null(node_path)
	if not node:
		return {"error": "Node not found: %s" % node_path}

	# Create a new script
	var script = GDScript.new()
	script.source_code = script_content

	# Validate the script
	var err = script.reload()
	if err != OK:
		return {"error": "Script compilation failed: %s" % error_string(err)}

	# Set the script on the node
	node.script = script

	# Make undoable
	var undo_redo = editor_interface.get_editor_undo_redo()
	undo_redo.create_action("Add Script to: %s" % node_path)
	undo_redo.add_do_property(node, "script", script)
	undo_redo.add_undo_property(node, "script", node.script)
	undo_redo.commit_action()

	return {"success": true}

func run_scene() -> Dictionary:
	"""Run the current scene"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	# Use EditorInterface to run the scene
	editor_interface.play_current_scene()
	return {"success": true}

func stop_scene() -> Dictionary:
	"""Stop the running scene"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	# Use EditorInterface to stop
	editor_interface.stop_playing_scene()
	return {"success": true}

func move_node(node_path: String, new_parent_path: String, new_name: String = "") -> Dictionary:
	"""Move a node to a new parent and optionally rename it"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var node = root.get_node_or_null(node_path)
	if not node:
		return {"error": "Node not found: %s" % node_path}

	var new_parent = root.get_node_or_null(new_parent_path)
	if not new_parent:
		return {"error": "New parent node not found: %s" % new_parent_path}

	if node == root:
		return {"error": "Cannot move root node"}

	var current_parent = node.get_parent()
	if not current_parent:
		return {"error": "Node has no parent"}

	# Handle renaming
	var final_name = node.name
	if not new_name.is_empty():
		final_name = new_name

	# Make the change undoable
	var undo_redo = editor_interface.get_editor_undo_redo()
	undo_redo.create_action("Move Node: %s" % node.name)

	# Remove from current parent
	undo_redo.add_do_method(current_parent, "remove_child", node)
	undo_redo.add_do_method(new_parent, "add_child", node)

	# Set new owner and name
	undo_redo.add_do_property(node, "owner", root)
	undo_redo.add_do_property(node, "name", final_name)

	# Undo operations
	undo_redo.add_undo_method(new_parent, "remove_child", node)
	undo_redo.add_undo_method(current_parent, "add_child", node)
	undo_redo.add_undo_property(node, "owner", root)
	undo_redo.add_undo_property(node, "name", node.name)

	undo_redo.commit_action()

	return {
		"new_path": str(node.get_path()),
		"new_name": final_name
	}

func duplicate_node(node_path: String, new_name: String = "") -> Dictionary:
	"""Duplicate a node"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var node = root.get_node_or_null(node_path)
	if not node:
		return {"error": "Node not found: %s" % node_path}

	var parent = node.get_parent()
	if not parent:
		return {"error": "Node has no parent"}

	# Create duplicate
	var duplicate = node.duplicate()
	if not duplicate:
		return {"error": "Failed to duplicate node"}

	# Set name
	if new_name.is_empty():
		new_name = "%s_duplicate" % node.name
	duplicate.name = new_name

	# Make undoable
	var undo_redo = editor_interface.get_editor_undo_redo()
	undo_redo.create_action("Duplicate Node: %s" % node.name)
	undo_redo.add_do_method(parent, "add_child", duplicate)
	undo_redo.add_do_property(duplicate, "owner", root)
	undo_redo.add_undo_method(parent, "remove_child", duplicate)
	undo_redo.commit_action()

	return {
		"duplicate_path": str(duplicate.get_path()),
		"duplicate_name": duplicate.name
	}

func set_node_transform(node_path: String, position = null, rotation = null, scale = null) -> Dictionary:
	"""Set transform properties of a node"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var node = root.get_node_or_null(node_path)
	if not node:
		return {"error": "Node not found: %s" % node_path}

	var undo_redo = editor_interface.get_editor_undo_redo()
	undo_redo.create_action("Set Transform: %s" % node_path)

	# Handle position
	if position != null:
		var old_pos = node.position if node is Node2D else node.position
		var new_pos = Vector2(position[0], position[1]) if node is Node2D else Vector3(position[0], position[1], position[2])
		undo_redo.add_do_property(node, "position", new_pos)
		undo_redo.add_undo_property(node, "position", old_pos)

	# Handle rotation
	if rotation != null:
		var old_rot = node.rotation if node is Node2D else node.rotation
		var new_rot = deg_to_rad(rotation[0]) if node is Node2D else Vector3(deg_to_rad(rotation[0]), deg_to_rad(rotation[1]), deg_to_rad(rotation[2]))
		undo_redo.add_do_property(node, "rotation", new_rot)
		undo_redo.add_undo_property(node, "rotation", old_rot)

	# Handle scale
	if scale != null:
		var old_scale = node.scale if node is Node2D else node.scale
		var new_scale = Vector2(scale[0], scale[1]) if node is Node2D else Vector3(scale[0], scale[1], scale[2])
		undo_redo.add_do_property(node, "scale", new_scale)
		undo_redo.add_undo_property(node, "scale", old_scale)

	undo_redo.commit_action()
	return {"success": true}

func set_node_visibility(node_path: String, visible: bool) -> Dictionary:
	"""Set the visibility of a node"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var node = root.get_node_or_null(node_path)
	if not node:
		return {"error": "Node not found: %s" % node_path}

	if not node.has_method("set_visible"):
		return {"error": "Node does not support visibility control"}

	var old_visible = node.visible

	var undo_redo = editor_interface.get_editor_undo_redo()
	undo_redo.create_action("Set Visibility: %s" % node_path)
	undo_redo.add_do_method(node, "set_visible", visible)
	undo_redo.add_undo_method(node, "set_visible", old_visible)
	undo_redo.commit_action()

	return {"success": true}

func connect_signal(from_node_path: String, signal_name: String, to_node_path: String, method_name: String) -> Dictionary:
	"""Connect a signal from one node to a method on another node"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var from_node = root.get_node_or_null(from_node_path)
	if not from_node:
		return {"error": "Source node not found: %s" % from_node_path}

	var to_node = root.get_node_or_null(to_node_path)
	if not to_node:
		return {"error": "Target node not found: %s" % to_node_path}

	# Check if signal exists
	if not from_node.has_signal(signal_name):
		return {"error": "Signal '%s' not found on node %s" % [signal_name, from_node_path]}

	# Check if method exists
	if not to_node.has_method(method_name):
		return {"error": "Method '%s' not found on node %s" % [method_name, to_node_path]}

	# Connect the signal
	var err = from_node.connect(signal_name, Callable(to_node, method_name))
	if err != OK:
		return {"error": "Failed to connect signal: %s" % error_string(err)}

	# Note: Signal connections are not easily undoable in Godot's undo system
	# This is a limitation of the current implementation

	return {"success": true}

func disconnect_signal(from_node_path: String, signal_name: String, to_node_path: String, method_name: String) -> Dictionary:
	"""Disconnect a signal connection"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var from_node = root.get_node_or_null(from_node_path)
	if not from_node:
		return {"error": "Source node not found: %s" % from_node_path}

	var to_node = root.get_node_or_null(to_node_path)
	if not to_node:
		return {"error": "Target node not found: %s" % to_node_path}

	# Disconnect the signal
	from_node.disconnect(signal_name, Callable(to_node, method_name))

	return {"success": true}

func get_node_signals(node_path: String) -> Dictionary:
	"""Get all signals available on a node"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var node = root.get_node_or_null(node_path)
	if not node:
		return {"error": "Node not found: %s" % node_path}

	var signals = []
	var signal_list = node.get_signal_list()

	for signal_info in signal_list:
		signals.append(signal_info.name)

	return {"signals": signals}

func get_node_methods(node_path: String) -> Dictionary:
	"""Get all methods available on a node"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var node = root.get_node_or_null(node_path)
	if not node:
		return {"error": "Node not found: %s" % node_path}

	var methods = []
	var method_list = node.get_method_list()

	for method in method_list:
		if not method.name.begins_with("_"):  # Skip private methods
			methods.append({
				"name": method.name,
				"args": method.args.size(),
				"return_type": method.return.type if method.return else "void"
			})

	return {"methods": methods}

func call_node_method(node_path: String, method_name: String, args: Array = []) -> Dictionary:
	"""Call a method on a node"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var node = root.get_node_or_null(node_path)
	if not node:
		return {"error": "Node not found: %s" % node_path}

	if not node.has_method(method_name):
		return {"error": "Method '%s' not found on node %s" % [method_name, node_path]}

	# Call the method
	var result = node.callv(method_name, args)

	return {"result": _serialize_value(result)}

func find_nodes_by_type(node_type: String, search_root: String = ".") -> Dictionary:
	"""Find all nodes of a specific type in the scene"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var search_node = root.get_node_or_null(search_root)
	if not search_node:
		return {"error": "Search root not found: %s" % search_root}

	var found_nodes = []
	_find_nodes_recursive(search_node, node_type, found_nodes)

	var node_paths = []
	for node in found_nodes:
		node_paths.append(str(node.get_path()))

	return {"nodes": node_paths}

func _find_nodes_recursive(node: Node, node_type: String, result: Array) -> void:
	"""Recursively find nodes of a specific type"""
	if node.get_class() == node_type:
		result.append(node)

	for child in node.get_children():
		_find_nodes_recursive(child, node_type, result)

func get_node_children(node_path: String, recursive: bool = false) -> Dictionary:
	"""Get children of a node"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var node = root.get_node_or_null(node_path)
	if not node:
		return {"error": "Node not found: %s" % node_path}

	var children = []
	if recursive:
		_get_children_recursive(node, children)
	else:
		for child in node.get_children():
			children.append(str(child.get_path()))

	return {"children": children}

func _get_children_recursive(node: Node, result: Array) -> void:
	"""Recursively get all children"""
	for child in node.get_children():
		result.append(str(child.get_path()))
		_get_children_recursive(child, result)

func _validate_editor_access() -> String:
	"""Validate that we have proper editor access, returns error message or empty string"""
	if not Engine.is_editor_hint():
		return "Not running in editor mode"

	if not editor_interface:
		editor_interface = EditorInterface
		if not editor_interface:
			return "EditorInterface not available"

	return ""

func _serialize_value(value) -> Variant:
	"""Serialize a value for JSON transmission"""
	if value is Vector2 or value is Vector3 or value is Color:
		return str(value)
	elif value is Array:
		var serialized = []
		for item in value:
			serialized.append(_serialize_value(item))
		return serialized
	elif value is Dictionary:
		var serialized = {}
		for key in value:
			serialized[key] = _serialize_value(value[key])
		return serialized
	else:
		return value