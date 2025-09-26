@tool
extends Node

# Animation utilities for Godot MCP Node Control
# Provides comprehensive animation and AnimationPlayer management

var editor_interface = null

func _ready() -> void:
	# Get editor interface when available
	if Engine.is_editor_hint():
		editor_interface = EditorInterface
		if not editor_interface:
			push_warning("EditorInterface not available in animation_utils")

# AnimationPlayer Node Management

func create_animation_player(parent_path: String = ".", node_name: String = "") -> Dictionary:
	"""Create an AnimationPlayer node in the scene"""
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

	# Create the AnimationPlayer node
	var animation_player = AnimationPlayer.new()
	if not animation_player:
		return {"error": "Failed to create AnimationPlayer node"}

	# Set name
	if node_name.is_empty():
		node_name = "AnimationPlayer_%d" % parent_node.get_child_count()
	animation_player.name = node_name

	# Make the change undoable
	var undo_redo = editor_interface.get_editor_undo_redo()
	undo_redo.create_action("Create AnimationPlayer: %s" % node_name)
	undo_redo.add_do_method(parent_node, "add_child", animation_player)
	undo_redo.add_do_property(animation_player, "owner", root)
	undo_redo.add_undo_method(parent_node, "remove_child", animation_player)
	undo_redo.commit_action()

	return {
		"node_path": str(animation_player.get_path()),
		"node_name": animation_player.name,
		"node_type": "AnimationPlayer"
	}

func get_animation_player_info(node_path: String) -> Dictionary:
	"""Get AnimationPlayer state and properties"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var animation_player = root.get_node_or_null(node_path)
	if not animation_player:
		return {"error": "AnimationPlayer not found: %s" % node_path}

	if not animation_player is AnimationPlayer:
		return {"error": "Node is not an AnimationPlayer: %s" % node_path}

	var info = {
		"node_path": node_path,
		"current_animation": animation_player.current_animation,
		"assigned_animation": animation_player.assigned_animation,
		"autoplay": animation_player.autoplay,
		"is_playing": animation_player.is_playing(),
		"current_animation_length": animation_player.current_animation_length if animation_player.current_animation else 0.0,
		"current_animation_position": animation_player.current_animation_position if animation_player.current_animation else 0.0,
		"speed_scale": animation_player.speed_scale,
		"playback_default_blend_time": animation_player.playback_default_blend_time,
		"has_section": animation_player.has_section(),
		"section_start_time": animation_player.get_section_start_time() if animation_player.has_section() else -1,
		"section_end_time": animation_player.get_section_end_time() if animation_player.has_section() else -1,
		"animation_list": animation_player.get_animation_list(),
		"queue": animation_player.get_queue()
	}

	return info

func set_animation_player_property(node_path: String, property_name: String, value) -> Dictionary:
	"""Set a property on an AnimationPlayer"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var animation_player = root.get_node_or_null(node_path)
	if not animation_player:
		return {"error": "AnimationPlayer not found: %s" % node_path}

	if not animation_player is AnimationPlayer:
		return {"error": "Node is not an AnimationPlayer: %s" % node_path}

	# Validate property exists
	var valid_properties = [
		"autoplay", "speed_scale", "playback_default_blend_time",
		"playback_auto_capture", "playback_auto_capture_duration",
		"playback_auto_capture_ease_type", "playback_auto_capture_transition_type",
		"movie_quit_on_finish"
	]

	if property_name not in valid_properties:
		return {"error": "Invalid AnimationPlayer property: %s" % property_name}

	# Get current value for undo
	var old_value = animation_player.get(property_name)

	# Set the new value
	animation_player.set(property_name, value)

	# Make undoable
	var undo_redo = editor_interface.get_editor_undo_redo()
	undo_redo.create_action("Set AnimationPlayer Property: %s.%s" % [node_path, property_name])
	undo_redo.add_do_property(animation_player, property_name, value)
	undo_redo.add_undo_property(animation_player, property_name, old_value)
	undo_redo.commit_action()

	return {"success": true}

func remove_animation_player(node_path: String) -> Dictionary:
	"""Remove an AnimationPlayer node from the scene"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var animation_player = root.get_node_or_null(node_path)
	if not animation_player:
		return {"error": "AnimationPlayer not found: %s" % node_path}

	if not animation_player is AnimationPlayer:
		return {"error": "Node is not an AnimationPlayer: %s" % node_path}

	var parent = animation_player.get_parent()
	if not parent:
		return {"error": "AnimationPlayer has no parent"}

	# Make the change undoable
	var undo_redo = editor_interface.get_editor_undo_redo()
	undo_redo.create_action("Remove AnimationPlayer: %s" % animation_player.name)
	undo_redo.add_do_method(parent, "remove_child", animation_player)
	undo_redo.add_undo_method(parent, "add_child", animation_player)
	undo_redo.add_undo_property(animation_player, "owner", root)
	undo_redo.commit_action()

	return {"removed": true}

# Animation Playback Control

func play_animation(player_path: String, animation_name: String = "", custom_blend: float = -1, custom_speed: float = 1.0, from_end: bool = false) -> Dictionary:
	"""Play an animation on an AnimationPlayer"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var animation_player = root.get_node_or_null(player_path)
	if not animation_player:
		return {"error": "AnimationPlayer not found: %s" % player_path}

	if not animation_player is AnimationPlayer:
		return {"error": "Node is not an AnimationPlayer: %s" % player_path}

	# Validate animation exists if specified
	if not animation_name.is_empty() and not animation_player.has_animation(animation_name):
		return {"error": "Animation not found: %s" % animation_name}

	# Play the animation
	animation_player.play(animation_name, custom_blend, custom_speed, from_end)

	return {"success": true, "playing": animation_name if not animation_name.is_empty() else animation_player.current_animation}

func pause_animation(player_path: String) -> Dictionary:
	"""Pause the currently playing animation"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var animation_player = root.get_node_or_null(player_path)
	if not animation_player:
		return {"error": "AnimationPlayer not found: %s" % player_path}

	if not animation_player is AnimationPlayer:
		return {"error": "Node is not an AnimationPlayer: %s" % player_path}

	animation_player.pause()

	return {"success": true}

func stop_animation(player_path: String, keep_state: bool = false) -> Dictionary:
	"""Stop the currently playing animation"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var animation_player = root.get_node_or_null(player_path)
	if not animation_player:
		return {"error": "AnimationPlayer not found: %s" % player_path}

	if not animation_player is AnimationPlayer:
		return {"error": "Node is not an AnimationPlayer: %s" % player_path}

	animation_player.stop(keep_state)

	return {"success": true}

func seek_animation(player_path: String, seconds: float, update: bool = false, update_only: bool = false) -> Dictionary:
	"""Seek to a specific time in the current animation"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var animation_player = root.get_node_or_null(player_path)
	if not animation_player:
		return {"error": "AnimationPlayer not found: %s" % player_path}

	if not animation_player is AnimationPlayer:
		return {"error": "Node is not an AnimationPlayer: %s" % player_path}

	animation_player.seek(seconds, update, update_only)

	return {"success": true, "position": seconds}

func queue_animation(player_path: String, animation_name: String) -> Dictionary:
	"""Add an animation to the playback queue"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var animation_player = root.get_node_or_null(player_path)
	if not animation_player:
		return {"error": "AnimationPlayer not found: %s" % player_path}

	if not animation_player is AnimationPlayer:
		return {"error": "Node is not an AnimationPlayer: %s" % player_path}

	if not animation_player.has_animation(animation_name):
		return {"error": "Animation not found: %s" % animation_name}

	animation_player.queue(animation_name)

	return {"success": true, "queued": animation_name}

func clear_animation_queue(player_path: String) -> Dictionary:
	"""Clear all animations from the queue"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var animation_player = root.get_node_or_null(player_path)
	if not animation_player:
		return {"error": "AnimationPlayer not found: %s" % player_path}

	if not animation_player is AnimationPlayer:
		return {"error": "Node is not an AnimationPlayer: %s" % player_path}

	animation_player.clear_queue()

	return {"success": true}

func get_animation_state(player_path: String) -> Dictionary:
	"""Get the current playback state of an AnimationPlayer"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var animation_player = root.get_node_or_null(player_path)
	if not animation_player:
		return {"error": "AnimationPlayer not found: %s" % player_path}

	if not animation_player is AnimationPlayer:
		return {"error": "Node is not an AnimationPlayer: %s" % player_path}

	var state = {
		"is_playing": animation_player.is_playing(),
		"current_animation": animation_player.current_animation,
		"current_position": animation_player.current_animation_position if animation_player.current_animation else 0.0,
		"current_length": animation_player.current_animation_length if animation_player.current_animation else 0.0,
		"playing_speed": animation_player.get_playing_speed(),
		"queue": animation_player.get_queue(),
		"has_section": animation_player.has_section()
	}

	if animation_player.has_section():
		state["section_start"] = animation_player.get_section_start_time()
		state["section_end"] = animation_player.get_section_end_time()

	return state

func set_animation_speed(player_path: String, speed: float) -> Dictionary:
	"""Set the playback speed of an AnimationPlayer"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var animation_player = root.get_node_or_null(player_path)
	if not animation_player:
		return {"error": "AnimationPlayer not found: %s" % player_path}

	if not animation_player is AnimationPlayer:
		return {"error": "Node is not an AnimationPlayer: %s" % player_path}

	var old_speed = animation_player.speed_scale
	animation_player.speed_scale = speed

	# Make undoable
	var undo_redo = editor_interface.get_editor_undo_redo()
	undo_redo.create_action("Set Animation Speed: %s" % player_path)
	undo_redo.add_do_property(animation_player, "speed_scale", speed)
	undo_redo.add_undo_property(animation_player, "speed_scale", old_speed)
	undo_redo.commit_action()

	return {"success": true, "speed": speed}

# Animation Library Management

func create_animation_library(player_path: String, library_name: String) -> Dictionary:
	"""Create a new AnimationLibrary for an AnimationPlayer"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var animation_player = root.get_node_or_null(player_path)
	if not animation_player:
		return {"error": "AnimationPlayer not found: %s" % player_path}

	if not animation_player is AnimationPlayer:
		return {"error": "Node is not an AnimationPlayer: %s" % player_path}

	# Create new AnimationLibrary
	var library = AnimationLibrary.new()
	if not library:
		return {"error": "Failed to create AnimationLibrary"}

	# Add to AnimationPlayer
	var result = animation_player.add_animation_library(library_name, library)
	if result != OK:
		library.free()
		return {"error": "Failed to add AnimationLibrary: %s" % error_string(result)}

	return {"success": true, "library_name": library_name}

func load_animation_library(player_path: String, library_path: String, library_name: String = "") -> Dictionary:
	"""Load an AnimationLibrary from file"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var animation_player = root.get_node_or_null(player_path)
	if not animation_player:
		return {"error": "AnimationPlayer not found: %s" % player_path}

	if not animation_player is AnimationPlayer:
		return {"error": "Node is not an AnimationPlayer: %s" % player_path}

	# Load the library
	var library = ResourceLoader.load(library_path)
	if not library:
		return {"error": "Failed to load AnimationLibrary: %s" % library_path}

	if not library is AnimationLibrary:
		return {"error": "Resource is not an AnimationLibrary: %s" % library_path}

	# Set library name if not provided
	if library_name.is_empty():
		library_name = library_path.get_file().get_basename()

	# Add to AnimationPlayer
	var result = animation_player.add_animation_library(library_name, library)
	if result != OK:
		return {"error": "Failed to add AnimationLibrary: %s" % error_string(result)}

	return {"success": true, "library_name": library_name}

func add_animation_to_library(player_path: String, library_name: String, animation_name: String, animation_data: Dictionary) -> Dictionary:
	"""Add an Animation to an AnimationLibrary"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var animation_player = root.get_node_or_null(player_path)
	if not animation_player:
		return {"error": "AnimationPlayer not found: %s" % player_path}

	if not animation_player is AnimationPlayer:
		return {"error": "Node is not an AnimationPlayer: %s" % player_path}

	# Get the library
	var library = animation_player.get_animation_library(library_name)
	if not library:
		return {"error": "AnimationLibrary not found: %s" % library_name}

	# Create Animation object from data
	var animation = Animation.new()
	if animation_data.has("length"):
		animation.length = animation_data["length"]
	if animation_data.has("loop_mode"):
		animation.loop_mode = animation_data["loop_mode"]
	if animation_data.has("step"):
		animation.step = animation_data["step"]

	# Add tracks if provided
	if animation_data.has("tracks"):
		for track_data in animation_data["tracks"]:
			var track_type = track_data.get("type", 4)  # Default to PROPERTY
			var track_path = track_data.get("path", "")
			var track_idx = animation.add_track(track_type)
			if track_idx != -1:
				animation.track_set_path(track_idx, track_path)
				# Add keyframes if provided
				if track_data.has("keyframes"):
					for kf in track_data["keyframes"]:
						var time = kf.get("time", 0.0)
						var value = kf.get("value", null)
						if value != null:
							animation.track_insert_key(track_idx, time, value)

	# Add animation to library
	var result = library.add_animation(animation_name, animation)
	if result != OK:
		animation.free()
		return {"error": "Failed to add animation to library: %s" % error_string(result)}

	return {"success": true, "animation_name": animation_name}

func remove_animation_from_library(player_path: String, library_name: String, animation_name: String) -> Dictionary:
	"""Remove an Animation from an AnimationLibrary"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var animation_player = root.get_node_or_null(player_path)
	if not animation_player:
		return {"error": "AnimationPlayer not found: %s" % player_path}

	if not animation_player is AnimationPlayer:
		return {"error": "Node is not an AnimationPlayer: %s" % player_path}

	# Get the library
	var library = animation_player.get_animation_library(library_name)
	if not library:
		return {"error": "AnimationLibrary not found: %s" % library_name}

	# Remove animation from library
	library.remove_animation(animation_name)

	return {"success": true, "removed": animation_name}

func get_animation_library_list(player_path: String) -> Dictionary:
	"""Get list of animations in all libraries"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var animation_player = root.get_node_or_null(player_path)
	if not animation_player:
		return {"error": "AnimationPlayer not found: %s" % player_path}

	if not animation_player is AnimationPlayer:
		return {"error": "Node is not an AnimationPlayer: %s" % player_path}

	var libraries = {}
	var library_list = animation_player.get_animation_library_list()

	for lib_name in library_list:
		var library = animation_player.get_animation_library(lib_name)
		if library:
			libraries[lib_name] = library.get_animation_list()

	return {"libraries": libraries}

func rename_animation(player_path: String, old_name: String, new_name: String) -> Dictionary:
	"""Rename an animation in an AnimationPlayer"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var animation_player = root.get_node_or_null(player_path)
	if not animation_player:
		return {"error": "AnimationPlayer not found: %s" % player_path}

	if not animation_player is AnimationPlayer:
		return {"error": "Node is not an AnimationPlayer: %s" % player_path}

	if not animation_player.has_animation(old_name):
		return {"error": "Animation not found: %s" % old_name}

	if animation_player.has_animation(new_name):
		return {"error": "Animation already exists: %s" % new_name}

	# Get the animation resource
	var animation = animation_player.get_animation(old_name)
	if not animation:
		return {"error": "Failed to get animation: %s" % old_name}

	# Get the default animation library (where animations are stored)
	var library = animation_player.get_animation_library("")
	if not library:
		return {"error": "Failed to get default animation library"}

	# Remove from library and re-add with new name
	library.remove_animation(old_name)
	var result = library.add_animation(new_name, animation)
	if result != OK:
		# Try to restore the old animation if rename failed
		library.add_animation(old_name, animation)
		return {"error": "Failed to rename animation: %s" % error_string(result)}

	return {"success": true, "old_name": old_name, "new_name": new_name}

# Animation Data Manipulation

func create_animation(player_path: String, animation_name: String, length: float = 1.0) -> Dictionary:
	"""Create a new Animation resource"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var animation_player = root.get_node_or_null(player_path)
	if not animation_player:
		return {"error": "AnimationPlayer not found: %s" % player_path}

	if not animation_player is AnimationPlayer:
		return {"error": "Node is not an AnimationPlayer: %s" % player_path}

	if animation_player.has_animation(animation_name):
		return {"error": "Animation already exists: %s" % animation_name}

	# Create new animation
	var animation = Animation.new()
	animation.length = length

	# Create or get default AnimationLibrary
	var library = animation_player.get_animation_library("")
	if not library:
		library = AnimationLibrary.new()
		var lib_result = animation_player.add_animation_library("", library)
		if lib_result != OK:
			animation.free()
			return {"error": "Failed to create AnimationLibrary: %s" % error_string(lib_result)}

	# Add animation to library
	var result = library.add_animation(animation_name, animation)
	if result != OK:
		animation.free()
		return {"error": "Failed to add animation to library: %s" % error_string(result)}

	return {"success": true, "animation_name": animation_name, "length": length}

func get_animation_info(player_path: String, animation_name: String) -> Dictionary:
	"""Get information about an animation"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var animation_player = root.get_node_or_null(player_path)
	if not animation_player:
		return {"error": "AnimationPlayer not found: %s" % player_path}

	if not animation_player is AnimationPlayer:
		return {"error": "Node is not an AnimationPlayer: %s" % player_path}

	if not animation_player.has_animation(animation_name):
		return {"error": "Animation not found: %s" % animation_name}

	var animation = animation_player.get_animation(animation_name)
	if not animation:
		return {"error": "Failed to get animation: %s" % animation_name}

	var info = {
		"name": animation_name,
		"length": animation.length,
		"loop_mode": animation.loop_mode,
		"step": animation.step,
		"track_count": animation.get_track_count()
	}

	return info

func set_animation_property(player_path: String, animation_name: String, property_name: String, value) -> Dictionary:
	"""Set a property on an Animation"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var animation_player = root.get_node_or_null(player_path)
	if not animation_player:
		return {"error": "AnimationPlayer not found: %s" % player_path}

	if not animation_player is AnimationPlayer:
		return {"error": "Node is not an AnimationPlayer: %s" % player_path}

	if not animation_player.has_animation(animation_name):
		return {"error": "Animation not found: %s" % animation_name}

	var animation = animation_player.get_animation(animation_name)
	if not animation:
		return {"error": "Failed to get animation: %s" % animation_name}

	# Validate property
	var valid_properties = ["length", "loop_mode", "step"]
	if property_name not in valid_properties:
		return {"error": "Invalid animation property: %s" % property_name}

	var old_value = animation.get(property_name)
	animation.set(property_name, value)

	return {"success": true, "property": property_name, "value": value}

func add_animation_track(player_path: String, animation_name: String, track_type: int, track_path: String) -> Dictionary:
	"""Add a track to an animation"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var animation_player = root.get_node_or_null(player_path)
	if not animation_player:
		return {"error": "AnimationPlayer not found: %s" % player_path}

	if not animation_player is AnimationPlayer:
		return {"error": "Node is not an AnimationPlayer: %s" % player_path}

	if not animation_player.has_animation(animation_name):
		return {"error": "Animation not found: %s" % animation_name}

	var animation = animation_player.get_animation(animation_name)
	if not animation:
		return {"error": "Failed to get animation: %s" % animation_name}

	# Validate track type (valid types: 0-8)
	if track_type < 0 or track_type > 8:
		return {"error": "Invalid track type: %d (must be 0-8)" % track_type}

	# Add track
	var track_idx = animation.add_track(track_type)
	if track_idx == -1:
		return {"error": "Failed to add track"}

	# Set track path
	animation.track_set_path(track_idx, track_path)

	return {"success": true, "track_index": track_idx, "track_path": track_path}

func remove_animation_track(player_path: String, animation_name: String, track_idx: int) -> Dictionary:
	"""Remove a track from an animation"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var animation_player = root.get_node_or_null(player_path)
	if not animation_player:
		return {"error": "AnimationPlayer not found: %s" % player_path}

	if not animation_player is AnimationPlayer:
		return {"error": "Node is not an AnimationPlayer: %s" % player_path}

	if not animation_player.has_animation(animation_name):
		return {"error": "Animation not found: %s" % animation_name}

	var animation = animation_player.get_animation(animation_name)
	if not animation:
		return {"error": "Failed to get animation: %s" % animation_name}

	if track_idx < 0 or track_idx >= animation.get_track_count():
		return {"error": "Invalid track index: %d" % track_idx}

	animation.remove_track(track_idx)

	return {"success": true, "removed_track": track_idx}

func insert_keyframe(player_path: String, animation_name: String, track_idx: int, time: float, value) -> Dictionary:
	"""Insert a keyframe into an animation track"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var animation_player = root.get_node_or_null(player_path)
	if not animation_player:
		return {"error": "AnimationPlayer not found: %s" % player_path}

	if not animation_player is AnimationPlayer:
		return {"error": "Node is not an AnimationPlayer: %s" % player_path}

	if not animation_player.has_animation(animation_name):
		return {"error": "Animation not found: %s" % animation_name}

	var animation = animation_player.get_animation(animation_name)
	if not animation:
		return {"error": "Failed to get animation: %s" % animation_name}

	if track_idx < 0 or track_idx >= animation.get_track_count():
		return {"error": "Invalid track index: %d" % track_idx}

	# Convert value to proper Godot type based on track type
	var track_type = animation.track_get_type(track_idx)
	var converted_value = _convert_keyframe_value(value, track_type)

	# For METHOD tracks, we need to handle the dictionary format
	if track_type == Animation.TYPE_METHOD:
		# METHOD tracks expect a dictionary with "method" and "args"
		if not converted_value is Dictionary or not converted_value.has("method"):
			return {"error": "METHOD track requires a dictionary with 'method' and 'args' keys"}

	# Insert keyframe
	var key_idx = animation.track_insert_key(track_idx, time, converted_value)
	if key_idx == -1:
		return {"error": "Failed to insert keyframe"}

	return {"success": true, "key_index": key_idx, "time": time}

func remove_keyframe(player_path: String, animation_name: String, track_idx: int, key_idx: int) -> Dictionary:
	"""Remove a keyframe from an animation track"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var animation_player = root.get_node_or_null(player_path)
	if not animation_player:
		return {"error": "AnimationPlayer not found: %s" % player_path}

	if not animation_player is AnimationPlayer:
		return {"error": "Node is not an AnimationPlayer: %s" % player_path}

	if not animation_player.has_animation(animation_name):
		return {"error": "Animation not found: %s" % animation_name}

	var animation = animation_player.get_animation(animation_name)
	if not animation:
		return {"error": "Failed to get animation: %s" % animation_name}

	if track_idx < 0 or track_idx >= animation.get_track_count():
		return {"error": "Invalid track index: %d" % track_idx}

	var key_count = animation.track_get_key_count(track_idx)
	if key_idx < 0 or key_idx >= key_count:
		return {"error": "Invalid key index: %d" % key_idx}

	animation.track_remove_key(track_idx, key_idx)

	return {"success": true, "removed_key": key_idx}

func get_animation_tracks(player_path: String, animation_name: String) -> Dictionary:
	"""Get information about all tracks in an animation"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var animation_player = root.get_node_or_null(player_path)
	if not animation_player:
		return {"error": "AnimationPlayer not found: %s" % player_path}

	if not animation_player is AnimationPlayer:
		return {"error": "Node is not an AnimationPlayer: %s" % player_path}

	if not animation_player.has_animation(animation_name):
		return {"error": "Animation not found: %s" % animation_name}

	var animation = animation_player.get_animation(animation_name)
	if not animation:
		return {"error": "Failed to get animation: %s" % animation_name}

	var tracks = []
	var track_count = animation.get_track_count()

	for i in range(track_count):
		var track_info = {
			"index": i,
			"type": animation.track_get_type(i),
			"path": animation.track_get_path(i),
			"key_count": animation.track_get_key_count(i)
		}
		tracks.append(track_info)

	return {"tracks": tracks}

# Animation Transition Management

func set_blend_time(player_path: String, animation_from: String, animation_to: String, blend_time: float) -> Dictionary:
	"""Set blend time between two animations"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var animation_player = root.get_node_or_null(player_path)
	if not animation_player:
		return {"error": "AnimationPlayer not found: %s" % player_path}

	if not animation_player is AnimationPlayer:
		return {"error": "Node is not an AnimationPlayer: %s" % player_path}

	if not animation_player.has_animation(animation_from):
		return {"error": "Source animation not found: %s" % animation_from}

	if not animation_player.has_animation(animation_to):
		return {"error": "Target animation not found: %s" % animation_to}

	animation_player.set_blend_time(animation_from, animation_to, blend_time)

	return {"success": true, "blend_time": blend_time}

func get_blend_time(player_path: String, animation_from: String, animation_to: String) -> Dictionary:
	"""Get blend time between two animations"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var animation_player = root.get_node_or_null(player_path)
	if not animation_player:
		return {"error": "AnimationPlayer not found: %s" % player_path}

	if not animation_player is AnimationPlayer:
		return {"error": "Node is not an AnimationPlayer: %s" % player_path}

	var blend_time = animation_player.get_blend_time(animation_from, animation_to)

	return {"blend_time": blend_time}

func set_animation_next(player_path: String, animation_from: String, animation_to: String) -> Dictionary:
	"""Set the next animation to play after another"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var animation_player = root.get_node_or_null(player_path)
	if not animation_player:
		return {"error": "AnimationPlayer not found: %s" % player_path}

	if not animation_player is AnimationPlayer:
		return {"error": "Node is not an AnimationPlayer: %s" % player_path}

	if not animation_player.has_animation(animation_from):
		return {"error": "Source animation not found: %s" % animation_from}

	if not animation_player.has_animation(animation_to):
		return {"error": "Target animation not found: %s" % animation_to}

	animation_player.animation_set_next(animation_from, animation_to)

	return {"success": true, "next_animation": animation_to}

func get_animation_next(player_path: String, animation_from: String) -> Dictionary:
	"""Get the next animation queued after another"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var animation_player = root.get_node_or_null(player_path)
	if not animation_player:
		return {"error": "AnimationPlayer not found: %s" % player_path}

	if not animation_player is AnimationPlayer:
		return {"error": "Node is not an AnimationPlayer: %s" % player_path}

	var next_animation = animation_player.animation_get_next(animation_from)

	return {"next_animation": next_animation}

# Animation Section and Marker Control

func set_animation_section(player_path: String, start_time: float = -1, end_time: float = -1) -> Dictionary:
	"""Set the playback section for the current animation"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var animation_player = root.get_node_or_null(player_path)
	if not animation_player:
		return {"error": "AnimationPlayer not found: %s" % player_path}

	if not animation_player is AnimationPlayer:
		return {"error": "Node is not an AnimationPlayer: %s" % player_path}

	animation_player.set_section(start_time, end_time)

	return {"success": true, "start_time": start_time, "end_time": end_time}

func set_animation_section_with_markers(player_path: String, start_marker: String = "", end_marker: String = "") -> Dictionary:
	"""Set the playback section using markers"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var animation_player = root.get_node_or_null(player_path)
	if not animation_player:
		return {"error": "AnimationPlayer not found: %s" % player_path}

	if not animation_player is AnimationPlayer:
		return {"error": "Node is not an AnimationPlayer: %s" % player_path}

	animation_player.set_section_with_markers(start_marker, end_marker)

	return {"success": true, "start_marker": start_marker, "end_marker": end_marker}

func add_animation_marker(player_path: String, animation_name: String, marker_name: String, time: float) -> Dictionary:
	"""Add a marker to an animation"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var animation_player = root.get_node_or_null(player_path)
	if not animation_player:
		return {"error": "AnimationPlayer not found: %s" % player_path}

	if not animation_player is AnimationPlayer:
		return {"error": "Node is not an AnimationPlayer: %s" % player_path}

	if not animation_player.has_animation(animation_name):
		return {"error": "Animation not found: %s" % animation_name}

	var animation = animation_player.get_animation(animation_name)
	if not animation:
		return {"error": "Failed to get animation: %s" % animation_name}

	animation.add_marker(marker_name, time)

	return {"success": true, "marker": marker_name, "time": time}

func remove_animation_marker(player_path: String, animation_name: String, marker_name: String) -> Dictionary:
	"""Remove a marker from an animation"""
	var error_msg = _validate_editor_access()
	if error_msg:
		return {"error": error_msg}

	var root = editor_interface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open"}

	# Check if this is an editor UI scene (not a user scene)
	if root.name.begins_with("@") or root.name.contains("Editor"):
		return {"error": "No user scene is currently open. Please open a scene in the Godot editor."}

	var animation_player = root.get_node_or_null(player_path)
	if not animation_player:
		return {"error": "AnimationPlayer not found: %s" % player_path}

	if not animation_player is AnimationPlayer:
		return {"error": "Node is not an AnimationPlayer: %s" % player_path}

	if not animation_player.has_animation(animation_name):
		return {"error": "Animation not found: %s" % animation_name}

	var animation = animation_player.get_animation(animation_name)
	if not animation:
		return {"error": "Failed to get animation: %s" % animation_name}

	animation.remove_marker(marker_name)

	return {"success": true, "removed_marker": marker_name}

func _validate_editor_access() -> String:
	"""Validate that we have proper editor access, returns error message or empty string"""
	if not Engine.is_editor_hint():
		return "Not running in editor mode"

	if not editor_interface:
		editor_interface = EditorInterface
		if not editor_interface:
			return "EditorInterface not available"

	return ""

func _convert_keyframe_value(value, track_type: int):
	"""Convert keyframe value to proper Godot type based on track type"""
	match track_type:
		5:  # POSITION_2D - Vector2
			if value is Array and value.size() >= 2:
				return Vector2(value[0], value[1])
			elif value is Vector2:
				return value
			else:
				return value
		0:  # POSITION_3D - Vector3
			if value is Array and value.size() >= 3:
				return Vector3(value[0], value[1], value[2])
			elif value is Vector3:
				return value
			else:
				return value
		6:  # ROTATION_2D - float (radians)
			if value is float or value is int:
				return float(value)
			return value
		1:  # ROTATION_3D - Quaternion
			if value is Array and value.size() >= 4:
				return Quaternion(value[0], value[1], value[2], value[3])
			elif value is Quaternion:
				return value
			else:
				return value
		7:  # SCALE_2D - Vector2
			if value is Array and value.size() >= 2:
				return Vector2(value[0], value[1])
			elif value is Vector2:
				return value
			else:
				return value
		2:  # SCALE_3D - Vector3
			if value is Array and value.size() >= 3:
				return Vector3(value[0], value[1], value[2])
			elif value is Vector3:
				return value
			else:
				return value
		3:  # BLEND_SHAPE - float
			if value is float or value is int:
				return float(value)
			return value
		4:  # VALUE (generic property) - direct value
			# For generic value tracks, handle all common Godot types
			if value is Array:
				if value.size() == 2:
					return Vector2(value[0], value[1])
				elif value.size() == 3:
					return Vector3(value[0], value[1], value[2])
				elif value.size() == 4:
					# Could be Color or Quaternion - try Color first
					if value[0] is float or value[0] is int:
						return Color(value[0], value[1], value[2], value[3])
					else:
						return Quaternion(value[0], value[1], value[2], value[3])
			# Handle primitive types directly
			elif value is bool or value is int or value is float or value is String:
				return value
			# Handle Godot objects
			elif value is Vector2 or value is Vector3 or value is Color or value is Quaternion:
				return value
			else:
				# For any other type, return as-is and let Godot handle it
				return value
		8:  # METHOD - Dictionary with "method" and "args"
			# Method calls expect a dictionary with "method" and "args"
			if value is Dictionary:
				return value
			return value
		_:
			return value

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

