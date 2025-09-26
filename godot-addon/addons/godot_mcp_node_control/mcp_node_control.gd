@tool
extends EditorPlugin

# WebSocket server for MCP communication
var tcp_server := TCPServer.new()
var port := 9080
var debug_mode := true

# Error tracking and debug info
var error_log: Array[String] = []
var max_error_log_size := 100
var debug_info := {}

# Node operation handlers
var node_utils = null
var script_utils = null
var scene_utils = null
var resource_utils = null
var _command_handlers = {}

signal client_connected(id: int)
signal client_disconnected(id: int)
signal command_received(client_id: int, command: Dictionary)

class WebSocketClient:
	var tcp: StreamPeerTCP
	var id: int
	var ws: WebSocketPeer
	var state: int = -1  # -1: handshaking, 0: connected, 1: error/closed
	var handshake_time: int
	var last_poll_time: int

	func _init(p_tcp: StreamPeerTCP, p_id: int) -> void:
		tcp = p_tcp
		id = p_id
		handshake_time = Time.get_ticks_msec()

	func upgrade_to_websocket() -> bool:
		ws = WebSocketPeer.new()
		var err = ws.accept_stream(tcp)
		return err == OK

var clients := {}
var next_client_id := 1

func _enter_tree() -> void:
	# Store plugin instance for global access
	Engine.set_meta("GodotMCPNodeControl", self)

	print("=== MCP Node Control Server Starting ===")

	# Initialize utilities
	node_utils = preload("res://addons/godot_mcp_node_control/node_utils.gd").new()
	node_utils.name = "NodeUtils"
	add_child(node_utils)

	script_utils = preload("res://addons/godot_mcp_node_control/script_utils.gd").new()
	script_utils.name = "ScriptUtils"
	add_child(script_utils)

	scene_utils = preload("res://addons/godot_mcp_node_control/scene_utils.gd").new()
	scene_utils.name = "SceneUtils"
	add_child(scene_utils)

	resource_utils = preload("res://addons/godot_mcp_node_control/resource_utils.gd").new()
	resource_utils.name = "ResourceUtils"
	add_child(resource_utils)

	# Setup command handlers
	_command_handlers = {
		"get_scene_tree": _handle_get_scene_tree,
		"create_node": _handle_create_node,
		"delete_node": _handle_delete_node,
		"get_node_properties": _handle_get_node_properties,
		"set_node_property": _handle_set_node_property,
		"move_node": _handle_move_node,
		"duplicate_node": _handle_duplicate_node,
		"set_node_transform": _handle_set_node_transform,
		"set_node_visibility": _handle_set_node_visibility,
		"connect_signal": _handle_connect_signal,
		"disconnect_signal": _handle_disconnect_signal,
		"get_node_signals": _handle_get_node_signals,
		"get_node_methods": _handle_get_node_methods,
		"call_node_method": _handle_call_node_method,
		"find_nodes_by_type": _handle_find_nodes_by_type,
		"get_node_children": _handle_get_node_children,
		"add_script_to_node": _handle_add_script_to_node,
		"get_debug_info": _handle_get_debug_info,
		"run_scene": _handle_run_scene,
		"stop_scene": _handle_stop_scene,
		"get_script_content": _handle_get_script_content,
		"set_script_content": _handle_set_script_content,
		"validate_script": _handle_validate_script,
		"create_script_file": _handle_create_script_file,
		"load_script_file": _handle_load_script_file,
		"get_script_variables": _handle_get_script_variables,
		"set_script_variable": _handle_set_script_variable,
		"get_script_functions": _handle_get_script_functions,
		"attach_script_to_node": _handle_attach_script_to_node,
		"detach_script_from_node": _handle_detach_script_from_node,
		"create_resource": _handle_create_resource,
		"load_resource": _handle_load_resource,
		"save_resource": _handle_save_resource,
		"get_resource_dependencies": _handle_get_resource_dependencies,
		"list_directory": _handle_list_directory,
		"get_resource_metadata": _handle_get_resource_metadata,
		"get_current_scene_info": _handle_get_current_scene_info,
		"open_scene": _handle_open_scene,
		"save_scene": _handle_save_scene,
		"save_scene_as": _handle_save_scene_as,
		"create_new_scene": _handle_create_new_scene,
		"instantiate_scene": _handle_instantiate_scene,
		"pack_scene_from_node": _handle_pack_scene_from_node,
	}

	# Connect signals
	command_received.connect(_handle_command)

	# Start WebSocket server
	var err = tcp_server.listen(port)
	if err == OK:
		print("MCP Node Control server listening on port ", port)
		set_process(true)
	else:
		push_error("Failed to listen on port %d: %s" % [port, error_string(err)])
		_log_error("Server startup failed: %s" % error_string(err))

	print("=== MCP Node Control Server Initialized ===\n")

func _exit_tree() -> void:
	# Clean up
	if Engine.has_meta("GodotMCPNodeControl"):
		Engine.remove_meta("GodotMCPNodeControl")

	if tcp_server and tcp_server.is_listening():
		tcp_server.stop()

	clients.clear()
	print("=== MCP Node Control Server Shutdown ===")

func _log_error(message: String) -> void:
	var timestamp = Time.get_datetime_string_from_system()
	var error_entry = "[%s] ERROR: %s" % [timestamp, message]
	error_log.append(error_entry)

	# Keep log size manageable
	if error_log.size() > max_error_log_size:
		error_log.remove_at(0)

	# Use Godot's error logging
	push_error(message)

func _log_debug(message: String) -> void:
	if debug_mode:
		var timestamp = Time.get_datetime_string_from_system()
		print("[%s] DEBUG: %s" % [timestamp, message])

func _process(_delta: float) -> void:
	if not tcp_server.is_listening():
		return

	# Accept new connections
	if tcp_server.is_connection_available():
		var tcp = tcp_server.take_connection()
		var id = next_client_id
		next_client_id += 1

		var client = WebSocketClient.new(tcp, id)
		clients[id] = client

		print("[Client %d] New connection established" % id)

		# Try WebSocket upgrade
		if client.upgrade_to_websocket():
			print("[Client %d] WebSocket handshake initiated" % id)
		else:
			_log_error("Failed to initiate WebSocket handshake for client %d" % id)
			clients.erase(id)

	# Process existing clients
	var current_time = Time.get_ticks_msec()
	var ids_to_remove: Array[int] = []

	for id in clients:
		var client = clients[id]
		client.last_poll_time = current_time

		if client.state == -1:  # Handshaking
			if client.ws:
				client.ws.poll()
				var ws_state = client.ws.get_ready_state()

				if ws_state == WebSocketPeer.STATE_OPEN:
					print("[Client %d] WebSocket connected" % id)
					client.state = 0
					client_connected.emit(id)

					# Send welcome
					var welcome = {
						"type": "welcome",
						"message": "Godot MCP Node Control Server ready",
						"version": "1.0.0"
					}
					_send_to_client(id, welcome)

				elif ws_state != WebSocketPeer.STATE_CONNECTING:
					_log_error("WebSocket handshake failed for client %d, state: %d" % [id, ws_state])
					ids_to_remove.append(id)

			else:
				# Try upgrade if TCP connected
				if client.tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED:
					if client.upgrade_to_websocket():
						print("[Client %d] WebSocket handshake started" % id)
					else:
						_log_error("Failed to start WebSocket for client %d" % id)
						ids_to_remove.append(id)
				else:
					_log_error("TCP disconnected for client %d" % id)
					ids_to_remove.append(id)

		elif client.state == 0:  # Connected
			client.ws.poll()
			var ws_state = client.ws.get_ready_state()

			if ws_state != WebSocketPeer.STATE_OPEN:
				print("[Client %d] WebSocket disconnected, state: %d" % [id, ws_state])
				client_disconnected.emit(id)
				ids_to_remove.append(id)
				continue

			# Process messages
			var packet_count = client.ws.get_available_packet_count()
			for i in range(packet_count):
				var packet = client.ws.get_packet()
				var text = packet.get_string_from_utf8()

				_log_debug("[Client %d] Received: %s" % [id, text])

				# Parse JSON
				var json = JSON.new()
				var parse_result = json.parse(text)

				if parse_result == OK:
					var data = json.get_data()
					command_received.emit(id, data)
				else:
					_log_error("Failed to parse JSON from client %d: %s" % [id, json.get_error_message()])

	# Remove disconnected clients
	for id in ids_to_remove:
		clients.erase(id)

func _send_to_client(client_id: int, data: Dictionary) -> int:
	_log_debug("[Client %d] Sending response: %s" % [client_id, JSON.stringify(data)])

	if not clients.has(client_id):
		_log_error("Client %d not found" % client_id)
		return ERR_DOES_NOT_EXIST

	var client = clients[client_id]
	if client.ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		_log_error("Client %d connection not open" % client_id)
		return ERR_UNAVAILABLE

	var json_text = JSON.stringify(data)
	_log_debug("[Client %d] JSON response: %s" % [client_id, json_text])

	var result = client.ws.send_text(json_text)
	_log_debug("[Client %d] Send result: %d" % [client_id, result])

	if result != OK:
		_log_error("Failed to send to client %d: %s" % [client_id, error_string(result)])

	return result

func _handle_command(client_id: int, command: Dictionary) -> void:
	var response = {}

	if command.has("type"):
		var cmd_type = command.get("type")
		var params = command.get("params", {})

		if _command_handlers.has(cmd_type):
			var handler = _command_handlers[cmd_type]
			if handler.get_argument_count() > 0:
				response = handler.call(params)
			else:
				response = handler.call()
		else:
			response = {
				"status": "error",
				"error": "Unknown command type: %s" % cmd_type
			}
	else:
		response = {
			"status": "error",
			"error": "Missing command type"
		}

	_send_to_client(client_id, response)

func _handle_get_scene_tree() -> Dictionary:
	var result = node_utils.get_scene_tree()
	if result.has("error"):
		_log_error("get_scene_tree failed: %s" % result.error)
		return result
	return {"status": "success", "data": result}

func _handle_create_node(params: Dictionary) -> Dictionary:
	var node_type = params.get("node_type", "")
	var parent_path = params.get("parent_path", ".")
	var node_name = params.get("node_name", "")

	if node_type.is_empty():
		return {"status": "error", "error": "node_type is required"}

	var result = node_utils.create_node(node_type, parent_path, node_name)
	if result.has("error"):
		_log_error("create_node failed: %s" % result.error)
		return result
	return {"status": "success", "data": result}

func _handle_delete_node(params: Dictionary) -> Dictionary:
	var node_path = params.get("node_path", "")
	if node_path.is_empty():
		return {"status": "error", "error": "node_path is required"}

	var result = node_utils.delete_node(node_path)
	if result.has("error"):
		_log_error("delete_node failed: %s" % result.error)
		return result
	return {"status": "success"}

func _handle_get_node_properties(params: Dictionary) -> Dictionary:
	var node_path = params.get("node_path", "")
	if node_path.is_empty():
		return {"status": "error", "error": "node_path is required"}

	var result = node_utils.get_node_properties(node_path)
	if result.has("error"):
		_log_error("get_node_properties failed: %s" % result.error)
		return result
	return {"status": "success", "data": result}

func _handle_set_node_property(params: Dictionary) -> Dictionary:
	var node_path = params.get("node_path", "")
	var property_name = params.get("property_name", "")
	var value = params.get("value")

	if node_path.is_empty() or property_name.is_empty():
		return {"status": "error", "error": "node_path and property_name are required"}

	var result = node_utils.set_node_property(node_path, property_name, value)
	if result.has("error"):
		_log_error("set_node_property failed: %s" % result.error)
		return result
	return {"status": "success"}

func _handle_add_script_to_node(params: Dictionary) -> Dictionary:
	var node_path = params.get("node_path", "")
	var script_content = params.get("script_content", "")

	if node_path.is_empty() or script_content.is_empty():
		return {"status": "error", "error": "node_path and script_content are required"}

	var result = node_utils.add_script_to_node(node_path, script_content)
	if result.has("error"):
		_log_error("add_script_to_node failed: %s" % result.error)
		return result
	return {"status": "success"}

func _handle_get_debug_info() -> Dictionary:
	var debug_data = {
		"error_log": error_log.duplicate(),
		"debug_info": debug_info.duplicate(),
		"server_status": {
			"port": port,
			"active": tcp_server.is_listening(),
			"client_count": clients.size()
		},
		"godot_version": Engine.get_version_info(),
		"timestamp": Time.get_datetime_string_from_system()
	}
	return {"status": "success", "data": debug_data}

func _handle_run_scene() -> Dictionary:
	var result = node_utils.run_scene()
	if result.has("error"):
		_log_error("run_scene failed: %s" % result.error)
		return result
	return {"status": "success"}

func _handle_stop_scene() -> Dictionary:
	var result = node_utils.stop_scene()
	if result.has("error"):
		_log_error("stop_scene failed: %s" % result.error)
		return result
	return {"status": "success"}

func _handle_move_node(params: Dictionary) -> Dictionary:
	var node_path = params.get("node_path", "")
	var new_parent_path = params.get("new_parent_path", "")
	var new_name = params.get("new_name", "")

	if node_path.is_empty() or new_parent_path.is_empty():
		return {"status": "error", "error": "node_path and new_parent_path are required"}

	var result = node_utils.move_node(node_path, new_parent_path, new_name)
	if result.has("error"):
		_log_error("move_node failed: %s" % result.error)
		return result
	return {"status": "success", "data": result}

func _handle_duplicate_node(params: Dictionary) -> Dictionary:
	var node_path = params.get("node_path", "")
	var new_name = params.get("new_name", "")

	if node_path.is_empty():
		return {"status": "error", "error": "node_path is required"}

	var result = node_utils.duplicate_node(node_path, new_name)
	if result.has("error"):
		_log_error("duplicate_node failed: %s" % result.error)
		return result
	return {"status": "success", "data": result}

func _handle_set_node_transform(params: Dictionary) -> Dictionary:
	var node_path = params.get("node_path", "")
	var position = params.get("position")
	var rotation = params.get("rotation")
	var scale = params.get("scale")

	if node_path.is_empty():
		return {"status": "error", "error": "node_path is required"}

	var result = node_utils.set_node_transform(node_path, position, rotation, scale)
	if result.has("error"):
		_log_error("set_node_transform failed: %s" % result.error)
		return result
	return {"status": "success"}

func _handle_set_node_visibility(params: Dictionary) -> Dictionary:
	var node_path = params.get("node_path", "")
	var visible = params.get("visible", true)

	if node_path.is_empty():
		return {"status": "error", "error": "node_path is required"}

	var result = node_utils.set_node_visibility(node_path, visible)
	if result.has("error"):
		_log_error("set_node_visibility failed: %s" % result.error)
		return result
	return {"status": "success"}

func _handle_connect_signal(params: Dictionary) -> Dictionary:
	var from_node_path = params.get("from_node_path", "")
	var signal_name = params.get("signal_name", "")
	var to_node_path = params.get("to_node_path", "")
	var method_name = params.get("method_name", "")

	if from_node_path.is_empty() or signal_name.is_empty() or to_node_path.is_empty() or method_name.is_empty():
		return {"status": "error", "error": "from_node_path, signal_name, to_node_path, and method_name are required"}

	var result = node_utils.connect_signal(from_node_path, signal_name, to_node_path, method_name)
	if result.has("error"):
		_log_error("connect_signal failed: %s" % result.error)
		return result
	return {"status": "success"}

func _handle_disconnect_signal(params: Dictionary) -> Dictionary:
	var from_node_path = params.get("from_node_path", "")
	var signal_name = params.get("signal_name", "")
	var to_node_path = params.get("to_node_path", "")
	var method_name = params.get("method_name", "")

	if from_node_path.is_empty() or signal_name.is_empty() or to_node_path.is_empty() or method_name.is_empty():
		return {"status": "error", "error": "from_node_path, signal_name, to_node_path, and method_name are required"}

	var result = node_utils.disconnect_signal(from_node_path, signal_name, to_node_path, method_name)
	if result.has("error"):
		_log_error("disconnect_signal failed: %s" % result.error)
		return result
	return {"status": "success"}

func _handle_get_node_signals(params: Dictionary) -> Dictionary:
	var node_path = params.get("node_path", "")
	if node_path.is_empty():
		return {"status": "error", "error": "node_path is required"}

	var result = node_utils.get_node_signals(node_path)
	if result.has("error"):
		_log_error("get_node_signals failed: %s" % result.error)
		return result
	return {"status": "success", "data": result}

func _handle_get_node_methods(params: Dictionary) -> Dictionary:
	var node_path = params.get("node_path", "")
	if node_path.is_empty():
		return {"status": "error", "error": "node_path is required"}

	var result = node_utils.get_node_methods(node_path)
	if result.has("error"):
		_log_error("get_node_methods failed: %s" % result.error)
		return result
	return {"status": "success", "data": result}

func _handle_call_node_method(params: Dictionary) -> Dictionary:
	var node_path = params.get("node_path", "")
	var method_name = params.get("method_name", "")
	var args = params.get("args", [])

	if node_path.is_empty() or method_name.is_empty():
		return {"status": "error", "error": "node_path and method_name are required"}

	var result = node_utils.call_node_method(node_path, method_name, args)
	if result.has("error"):
		_log_error("call_node_method failed: %s" % result.error)
		return result
	return {"status": "success", "data": result}

func _handle_find_nodes_by_type(params: Dictionary) -> Dictionary:
	var node_type = params.get("node_type", "")
	var search_root = params.get("search_root", ".")

	if node_type.is_empty():
		return {"status": "error", "error": "node_type is required"}

	var result = node_utils.find_nodes_by_type(node_type, search_root)
	if result.has("error"):
		_log_error("find_nodes_by_type failed: %s" % result.error)
		return result
	return {"status": "success", "data": result}

func _handle_get_node_children(params: Dictionary) -> Dictionary:
	var node_path = params.get("node_path", "")
	var recursive = params.get("recursive", false)

	if node_path.is_empty():
		return {"status": "error", "error": "node_path is required"}

	var result = node_utils.get_node_children(node_path, recursive)
	if result.has("error"):
		_log_error("get_node_children failed: %s" % result.error)
		return result
	return {"status": "success", "data": result}

# Public API for other parts of the addon
func get_error_log() -> Array[String]:
	return error_log.duplicate()

func clear_error_log() -> void:
	error_log.clear()

func add_debug_info(key: String, value) -> void:
	debug_info[key] = value

func _handle_get_script_content(params: Dictionary) -> Dictionary:
	var node_path = params.get("node_path", "")
	if node_path.is_empty():
		return {"status": "error", "error": "node_path is required"}

	var result = script_utils.get_script_content(node_path)
	if result.has("error"):
		_log_error("get_script_content failed: %s" % result.error)
		return result
	return {"status": "success", "data": result}

func _handle_set_script_content(params: Dictionary) -> Dictionary:
	var node_path = params.get("node_path", "")
	var content = params.get("content", "")

	if node_path.is_empty() or content.is_empty():
		return {"status": "error", "error": "node_path and content are required"}

	var result = script_utils.set_script_content(node_path, content)
	if result.has("error"):
		_log_error("set_script_content failed: %s" % result.error)
		return result
	return {"status": "success"}

func _handle_validate_script(params: Dictionary) -> Dictionary:
	var content = params.get("content", "")
	if content.is_empty():
		return {"status": "error", "error": "content is required"}

	var result = script_utils.validate_script(content)
	if result.has("error"):
		_log_error("validate_script failed: %s" % result.error)
		return result
	return {"status": "success", "data": result}

func _handle_create_script_file(params: Dictionary) -> Dictionary:
	var filename = params.get("filename", "")
	var content = params.get("content", "")

	if filename.is_empty() or content.is_empty():
		return {"status": "error", "error": "filename and content are required"}

	var result = script_utils.create_script_file(filename, content)
	if result.has("error"):
		_log_error("create_script_file failed: %s" % result.error)
		return result
	return {"status": "success", "data": result}

func _handle_load_script_file(params: Dictionary) -> Dictionary:
	var file_path = params.get("file_path", "")
	if file_path.is_empty():
		return {"status": "error", "error": "file_path is required"}

	var result = script_utils.load_script_file(file_path)
	if result.has("error"):
		_log_error("load_script_file failed: %s" % result.error)
		return result
	return {"status": "success", "data": result}

func _handle_get_script_variables(params: Dictionary) -> Dictionary:
	var node_path = params.get("node_path", "")
	if node_path.is_empty():
		return {"status": "error", "error": "node_path is required"}

	var result = script_utils.get_script_variables(node_path)
	if result.has("error"):
		_log_error("get_script_variables failed: %s" % result.error)
		return result
	return {"status": "success", "data": result}

func _handle_set_script_variable(params: Dictionary) -> Dictionary:
	var node_path = params.get("node_path", "")
	var var_name = params.get("var_name", "")
	var value = params.get("value")

	if node_path.is_empty() or var_name.is_empty():
		return {"status": "error", "error": "node_path and var_name are required"}

	var result = script_utils.set_script_variable(node_path, var_name, value)
	if result.has("error"):
		_log_error("set_script_variable failed: %s" % result.error)
		return result
	return {"status": "success"}

func _handle_get_script_functions(params: Dictionary) -> Dictionary:
	var node_path = params.get("node_path", "")
	if node_path.is_empty():
		return {"status": "error", "error": "node_path is required"}

	var result = script_utils.get_script_functions(node_path)
	if result.has("error"):
		_log_error("get_script_functions failed: %s" % result.error)
		return result
	return {"status": "success", "data": result}

func _handle_attach_script_to_node(params: Dictionary) -> Dictionary:
	var node_path = params.get("node_path", "")
	var script_path = params.get("script_path", "")

	if node_path.is_empty() or script_path.is_empty():
		return {"status": "error", "error": "node_path and script_path are required"}

	var result = script_utils.attach_script_to_node(node_path, script_path)
	if result.has("error"):
		_log_error("attach_script_to_node failed: %s" % result.error)
		return result
	return {"status": "success"}

func _handle_detach_script_from_node(params: Dictionary) -> Dictionary:
	var node_path = params.get("node_path", "")
	if node_path.is_empty():
		return {"status": "error", "error": "node_path is required"}

	var result = script_utils.detach_script_from_node(node_path)
	if result.has("error"):
		_log_error("detach_script_from_node failed: %s" % result.error)
		return result
	return {"status": "success"}

func _handle_create_resource(params: Dictionary) -> Dictionary:
	var resource_type = params.get("resource_type", "")
	if resource_type.is_empty():
		return {"status": "error", "error": "resource_type is required"}

	var result = resource_utils.create_resource(resource_type)
	if result.has("error"):
		return {"status": "error", "error": result.error}
	return {"status": "success", "data": result}

func _handle_load_resource(params: Dictionary) -> Dictionary:
	var resource_path = params.get("resource_path", "")
	if resource_path.is_empty():
		return {"status": "error", "error": "resource_path is required"}

	var result = resource_utils.load_resource(resource_path)
	if result.has("error"):
		return {"status": "error", "error": result.error}
	return {"status": "success", "data": result}

func _handle_save_resource(params: Dictionary) -> Dictionary:
	var resource = params.get("resource")
	var save_path = params.get("save_path", "")
	var flags = params.get("flags", 0)

	if resource == null or save_path.is_empty():
		return {"status": "error", "error": "resource and save_path are required"}

	var result = resource_utils.save_resource(resource, save_path, flags)
	if result.has("error"):
		return {"status": "error", "error": result.error}
	return {"status": "success"}

func _handle_get_resource_dependencies(params: Dictionary) -> Dictionary:
	var resource_path = params.get("resource_path", "")
	if resource_path.is_empty():
		return {"status": "error", "error": "resource_path is required"}

	var result = resource_utils.get_resource_dependencies(resource_path)
	if result.has("error"):
		return {"status": "error", "error": result.error}
	return {"status": "success", "data": result}

func _handle_list_directory(params: Dictionary) -> Dictionary:
	var dir_path = params.get("dir_path", "")
	if dir_path.is_empty():
		return {"status": "error", "error": "dir_path is required"}

	var result = resource_utils.list_directory(dir_path)
	if result.has("error"):
		return {"status": "error", "error": result.error}
	return {"status": "success", "data": result}

func _handle_get_resource_metadata(params: Dictionary) -> Dictionary:
	var resource_path = params.get("resource_path", "")
	if resource_path.is_empty():
		return {"status": "error", "error": "resource_path is required"}

	var result = resource_utils.get_resource_metadata(resource_path)
	return {"status": "success", "data": result}

func _handle_get_current_scene_info() -> Dictionary:
	var result = scene_utils.get_current_scene_info()
	if result.has("error"):
		_log_error("get_current_scene_info failed: %s" % result.error)
		return result
	return {"status": "success", "data": result}

func _handle_open_scene(params: Dictionary) -> Dictionary:
	var scene_path = params.get("scene_path", "")
	if scene_path.is_empty():
		return {"status": "error", "error": "scene_path is required"}

	var result = scene_utils.open_scene(scene_path)
	if result.has("error"):
		_log_error("open_scene failed: %s" % result.error)
		return result
	return {"status": "success", "data": result}

func _handle_save_scene() -> Dictionary:
	var result = scene_utils.save_scene()
	if result.has("error"):
		_log_error("save_scene failed: %s" % result.error)
		return result
	return {"status": "success", "data": result}

func _handle_save_scene_as(params: Dictionary) -> Dictionary:
	var scene_path = params.get("scene_path", "")
	if scene_path.is_empty():
		return {"status": "error", "error": "scene_path is required"}

	var result = scene_utils.save_scene_as(scene_path)
	if result.has("error"):
		_log_error("save_scene_as failed: %s" % result.error)
		return result
	return {"status": "success", "data": result}

func _handle_create_new_scene(params: Dictionary) -> Dictionary:
	var root_node_type = params.get("root_node_type", "Node2D")

	var result = scene_utils.create_new_scene(root_node_type)
	if result.has("error"):
		_log_error("create_new_scene failed: %s" % result.error)
		return result
	return {"status": "success", "data": result}

func _handle_instantiate_scene(params: Dictionary) -> Dictionary:
	var scene_path = params.get("scene_path", "")
	var parent_path = params.get("parent_path", ".")

	if scene_path.is_empty():
		return {"status": "error", "error": "scene_path is required"}

	var result = scene_utils.instantiate_scene(scene_path, parent_path)
	if result.has("error"):
		_log_error("instantiate_scene failed: %s" % result.error)
		return result
	return {"status": "success", "data": result}

func _handle_pack_scene_from_node(params: Dictionary) -> Dictionary:
	var node_path = params.get("node_path", "")
	var save_path = params.get("save_path", "")

	if node_path.is_empty() or save_path.is_empty():
		return {"status": "error", "error": "node_path and save_path are required"}

	var result = scene_utils.pack_scene_from_node(node_path, save_path)
	if result.has("error"):
		_log_error("pack_scene_from_node failed: %s" % result.error)
		return result
	return {"status": "success", "data": result}

func get_server_status() -> Dictionary:
	return {
		"listening": tcp_server.is_listening(),
		"port": port,
		"clients": clients.size()
	}