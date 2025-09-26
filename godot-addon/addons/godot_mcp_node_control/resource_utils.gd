@tool
extends Node

# Resource management utilities for MCP server
# Handles loading, saving, and managing Godot resources

func _ready():
	pass

# Load a resource from file path
func load_resource(resource_path: String) -> Dictionary:
	if not ResourceLoader.exists(resource_path):
		return {"error": "Resource does not exist: " + resource_path}

	var resource = ResourceLoader.load(resource_path)
	if resource == null:
		return {"error": "Failed to load resource: " + resource_path}

	return {"resource": resource, "type": resource.get_class()}

# Save a resource to file
func save_resource(resource: Resource, save_path: String, flags: int = 0) -> Dictionary:
	var error = ResourceSaver.save(resource, save_path, flags)
	if error != OK:
		return {"error": "Failed to save resource to " + save_path + ": " + error_string(error)}
	return {"success": true}

# Create a new resource of specified type
func create_resource(resource_type: String) -> Dictionary:
	var resource_class = ClassDB.instantiate(resource_type)
	if resource_class == null:
		return {"error": "Failed to create resource of type: " + resource_type}

	if not (resource_class is Resource):
		resource_class.free()
		return {"error": "Type " + resource_type + " is not a Resource"}

	return {"resource": resource_class}

# Get resource dependencies
func get_resource_dependencies(resource_path: String) -> Dictionary:
	if not ResourceLoader.exists(resource_path):
		return {"error": "Resource does not exist: " + resource_path}

	var dependencies = ResourceLoader.get_dependencies(resource_path)
	return {"dependencies": Array(dependencies)}

# List directory contents
func list_directory(dir_path: String) -> Dictionary:
	if not DirAccess.dir_exists_absolute(dir_path):
		return {"error": "Directory does not exist: " + dir_path}

	var contents = []
	var dir = DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not file_name.begins_with("."):  # Skip hidden files
				contents.append(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		return {"error": "Failed to open directory: " + dir_path}

	return {"contents": contents}


# Create and save a resource in one operation
func create_and_save_resource(resource_type: String, save_path: String, flags: int = 0) -> Dictionary:
	var resource_class = ClassDB.instantiate(resource_type)
	if resource_class == null:
		return {"error": "Failed to create resource of type: " + resource_type}

	if not (resource_class is Resource):
		resource_class.free()
		return {"error": "Type " + resource_type + " is not a Resource"}

	var error = ResourceSaver.save(resource_class, save_path, flags)
	if error != OK:
		resource_class.free()
		return {"error": "Failed to save resource to " + save_path + ": " + error_string(error)}

	resource_class.free()
	return {"success": true}

# Get resource metadata
func get_resource_metadata(resource_path: String) -> Dictionary:
	var metadata = {
		"path": resource_path,
		"exists": false,
		"type": "",
		"file_size": -1,
		"dependencies": []
	}

	if not ResourceLoader.exists(resource_path):
		return metadata

	metadata["exists"] = true

	# Get resource type
	var resource = ResourceLoader.load(resource_path)
	if resource == null:
		return metadata

	metadata["type"] = resource.get_class()
	# Note: Don't call resource.free() - ResourceLoader.load() returns cached resources
	# that are managed by Godot's reference counting system

	# Get file size
	var file = FileAccess.open(resource_path, FileAccess.READ)
	if file:
		metadata["file_size"] = file.get_length()
		file.close()

	# Get dependencies
	var dependencies = ResourceLoader.get_dependencies(resource_path)
	metadata["dependencies"] = Array(dependencies)

	return metadata