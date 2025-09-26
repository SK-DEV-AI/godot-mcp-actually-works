extends Node

# Script utilities for Godot MCP Node Control
# Provides safe, robust script manipulation functions

var editor_interface = null

func _ready() -> void:
	# Get editor interface when available
	if Engine.is_editor_hint():
		editor_interface = EditorInterface
		if not editor_interface:
			push_warning("EditorInterface not available in script_utils")

func get_script_content(node_path: String) -> Dictionary:
	"""Get the script content from a node"""
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

	if not node.script:
		return {"error": "Node has no script attached"}

	if not node.script is GDScript:
		return {"error": "Script is not a GDScript"}

	return {
		"content": node.script.source_code,
		"resource_path": node.script.resource_path if node.script.resource_path else ""
	}

func set_script_content(node_path: String, content: String) -> Dictionary:
	"""Update the script content on a node"""
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

	if not node.script:
		return {"error": "Node has no script attached"}

	if not node.script is GDScript:
		return {"error": "Script is not a GDScript"}

	# Validate the new content first
	var test_script = GDScript.new()
	test_script.source_code = content
	var err = test_script.reload()
	if err != OK:
		return {"error": "Script compilation failed: %s" % error_string(err)}

	# Store old content for undo
	var old_content = node.script.source_code

	# Update the script content
	node.script.source_code = content
	err = node.script.reload()
	if err != OK:
		# Restore old content on failure
		node.script.source_code = old_content
		node.script.reload()
		return {"error": "Failed to reload script: %s" % error_string(err)}

	# Make undoable
	var undo_redo = editor_interface.get_editor_undo_redo()
	undo_redo.create_action("Update Script Content: %s" % node_path)
	undo_redo.add_do_property(node.script, "source_code", content)
	undo_redo.add_undo_property(node.script, "source_code", old_content)
	undo_redo.commit_action()

	return {"success": true}

func validate_script(content: String) -> Dictionary:
	"""Validate GDScript syntax without attaching to a node"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	# Create a test script to validate
	var test_script = GDScript.new()
	test_script.source_code = content

	var err = test_script.reload()
	if err != OK:
		return {
			"valid": false,
			"error": error_string(err),
			"line": -1  # Godot doesn't provide line numbers in basic validation
		}

	return {"valid": true}

func create_script_file(filename: String, content: String) -> Dictionary:
	"""Create a new GDScript file"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	# Validate filename
	if not filename.ends_with(".gd"):
		filename += ".gd"

	# Validate content first
	var validation = validate_script(content)
	if not validation.get("valid", false):
		return validation

	# Create the script file
	var script = GDScript.new()
	script.source_code = content

	# Save to file system
	var file_path = "res://scripts/" + filename
	var err = ResourceSaver.save(script, file_path)
	if err != OK:
		return {"error": "Failed to save script file: %s" % error_string(err)}

	return {
		"success": true,
		"file_path": file_path
	}

func load_script_file(file_path: String) -> Dictionary:
	"""Load script content from a file"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	# Load the script resource
	var script = load(file_path)
	if not script:
		return {"error": "Failed to load script file: %s" % file_path}

	if not script is GDScript:
		return {"error": "File is not a GDScript: %s" % file_path}

	return {
		"content": script.source_code,
		"file_path": file_path
	}

func get_script_variables(node_path: String) -> Dictionary:
	"""Get exported variables from a node's script"""
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

	if not node.script:
		return {"error": "Node has no script attached"}

	var variables = []
	var property_list = node.get_property_list()

	for prop in property_list:
		# Check if it's an exported property from the script
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE != 0:
			var value = node.get(prop.name)
			variables.append({
				"name": prop.name,
				"type": _get_type_name(prop.type),
				"value": _serialize_value(value)
			})

	return {"variables": variables}

func set_script_variable(node_path: String, var_name: String, value) -> Dictionary:
	"""Set the value of an exported script variable"""
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

	if not node.script:
		return {"error": "Node has no script attached"}

	# Check if variable exists and is exported
	var property_list = node.get_property_list()
	var found = false
	for prop in property_list:
		if prop.name == var_name and prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE != 0:
			found = true
			break

	if not found:
		return {"error": "Exported variable not found: %s" % var_name}

	# Get old value for undo
	var old_value = node.get(var_name)

	# Set new value
	node.set(var_name, value)

	# Make undoable
	var undo_redo = editor_interface.get_editor_undo_redo()
	undo_redo.create_action("Set Script Variable: %s.%s" % [node_path, var_name])
	undo_redo.add_do_property(node, var_name, value)
	undo_redo.add_undo_property(node, var_name, old_value)
	undo_redo.commit_action()

	return {"success": true}

func get_script_functions(node_path: String) -> Dictionary:
	"""Get functions defined in a node's script"""
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

	if not node.script:
		return {"error": "Node has no script attached"}

	var functions = []
	var method_list = node.get_method_list()

	for method in method_list:
		# Only include methods defined in the script (not inherited)
		if method.name in ["_ready", "_process", "_physics_process", "_input", "_unhandled_input"] or not method.name.begins_with("_"):
			functions.append({
				"name": method.name,
				"args_count": method.args.size() if method.args else 0,
				"return_type": _get_type_name(method.return.type) if method.return else "void",
				"is_virtual": method.name.begins_with("_")
			})

	return {"functions": functions}

func attach_script_to_node(node_path: String, script_path: String) -> Dictionary:
	"""Attach an existing script file to a node"""
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

	# Load the script
	var script = load(script_path)
	if not script:
		return {"error": "Failed to load script: %s" % script_path}

	if not script is GDScript:
		return {"error": "Script is not a GDScript: %s" % script_path}

	# Store old script for undo
	var old_script = node.script

	# Attach the script
	node.script = script

	# Make undoable
	var undo_redo = editor_interface.get_editor_undo_redo()
	undo_redo.create_action("Attach Script to: %s" % node_path)
	undo_redo.add_do_property(node, "script", script)
	undo_redo.add_undo_property(node, "script", old_script)
	undo_redo.commit_action()

	return {"success": true}

func detach_script_from_node(node_path: String) -> Dictionary:
	"""Remove the script from a node"""
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

	if not node.script:
		return {"error": "Node has no script attached"}

	# Store old script for undo
	var old_script = node.script

	# Remove the script
	node.script = null

	# Make undoable
	var undo_redo = editor_interface.get_editor_undo_redo()
	undo_redo.create_action("Detach Script from: %s" % node_path)
	undo_redo.add_do_property(node, "script", null)
	undo_redo.add_undo_property(node, "script", old_script)
	undo_redo.commit_action()

	return {"success": true}

func _validate_editor_access() -> String:
	"""Validate that we have proper editor access, returns error message or empty string"""
	if not Engine.is_editor_hint():
		return "Not running in editor mode"

	if not editor_interface:
		editor_interface = EditorInterface
		if not editor_interface:
			return "EditorInterface not available"

	return ""

func _get_type_name(type: int) -> String:
	"""Convert Variant.Type enum to string"""
	match type:
		TYPE_BOOL: return "bool"
		TYPE_INT: return "int"
		TYPE_FLOAT: return "float"
		TYPE_STRING: return "String"
		TYPE_VECTOR2: return "Vector2"
		TYPE_VECTOR3: return "Vector3"
		TYPE_COLOR: return "Color"
		TYPE_OBJECT: return "Object"
		TYPE_ARRAY: return "Array"
		TYPE_DICTIONARY: return "Dictionary"
		_: return "Variant"

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