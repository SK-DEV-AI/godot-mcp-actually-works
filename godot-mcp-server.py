#!/usr/bin/env python3
"""
Godot MCP Server - Node Control Tools

A Model Context Protocol server that provides tools for controlling Godot Engine nodes.
Uses FastMCP framework for MCP protocol handling and WebSocket communication with Godot addon.
"""

import asyncio
import json
import websockets
import logging
import os
from typing import Dict, List, Any, Optional
from fastmcp import FastMCP

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class Config:
    """Configuration management for the MCP server"""

    def __init__(self):
        self.godot_host = os.getenv("GODOT_HOST", "localhost")
        self.godot_port = int(os.getenv("GODOT_PORT", "9080"))
        self.godot_timeout = int(os.getenv("GODOT_TIMEOUT", "30"))
        self.max_retries = int(os.getenv("GODOT_MAX_RETRIES", "3"))
        self.retry_delay = float(os.getenv("GODOT_RETRY_DELAY", "2.0"))
        self.log_level = os.getenv("LOG_LEVEL", "INFO").upper()

        # Set logging level
        level_map = {
            "DEBUG": logging.DEBUG,
            "INFO": logging.INFO,
            "WARNING": logging.WARNING,
            "ERROR": logging.ERROR,
            "CRITICAL": logging.CRITICAL
        }
        logger.setLevel(level_map.get(self.log_level, logging.INFO))

class GodotConnection:
    """Handles WebSocket connection to Godot addon with retry logic"""

    def __init__(self, config: Config):
        self.config = config
        self.websocket: Optional[websockets.WebSocketServerProtocol] = None
        self.connected = False
        self.retry_count = 0

    async def connect(self) -> bool:
        """Connect to Godot WebSocket server with retry logic"""
        uri = f"ws://{self.config.godot_host}:{self.config.godot_port}"

        for attempt in range(self.config.max_retries + 1):
            try:
                logger.info(f"Connecting to Godot at {uri} (attempt {attempt + 1}/{self.config.max_retries + 1})")
                self.websocket = await asyncio.wait_for(
                    websockets.connect(uri),
                    timeout=self.config.godot_timeout
                )
                self.connected = True
                self.retry_count = 0
                logger.info("Connected to Godot successfully")
                return True
            except asyncio.TimeoutError:
                logger.warning(f"Connection timeout (attempt {attempt + 1})")
            except Exception as e:
                logger.error(f"Connection failed (attempt {attempt + 1}): {e}")

            if attempt < self.config.max_retries:
                logger.info(f"Retrying in {self.config.retry_delay} seconds...")
                await asyncio.sleep(self.config.retry_delay)

        logger.error(f"Failed to connect to Godot after {self.config.max_retries + 1} attempts")
        return False

    async def disconnect(self):
        """Disconnect from Godot"""
        if self.websocket:
            await self.websocket.close()
            self.connected = False
            logger.info("Disconnected from Godot")

    async def send_command(self, command: Dict[str, Any]) -> Dict[str, Any]:
        """Send command to Godot and wait for response"""
        if not self.connected or not self.websocket:
            raise ConnectionError("Not connected to Godot")

        try:
            # Drain any pending welcome messages before sending command
            await self._drain_welcome_messages()

            # Send command
            message = json.dumps(command)
            logger.debug(f"Sending command: {message}")
            await self.websocket.send(message)

            # Wait for response
            response = await self.websocket.recv()
            logger.debug(f"Received response: {response}")

            return json.loads(response)

        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse JSON response from Godot: {e}")
            logger.error(f"Raw response was: {response}")
            raise
        except Exception as e:
            logger.error(f"Error communicating with Godot: {e}")
            raise

    async def _drain_welcome_messages(self):
        """Drain any pending welcome messages from Godot"""
        try:
            # Check if there are pending messages without blocking
            while True:
                try:
                    # Try to receive with a very short timeout
                    response = await asyncio.wait_for(
                        self.websocket.recv(),
                        timeout=0.01
                    )
                    logger.debug(f"Drained pending message: {response}")

                    # Parse to see if it's a welcome message
                    try:
                        data = json.loads(response)
                        if data.get("type") == "welcome":
                            logger.info("Consumed welcome message from Godot")
                        else:
                            logger.warning(f"Unexpected pending message: {data}")
                    except json.JSONDecodeError:
                        logger.warning(f"Could not parse drained message: {response}")

                except asyncio.TimeoutError:
                    # No more pending messages
                    break
        except Exception as e:
            logger.debug(f"No pending messages to drain: {e}")

# Global configuration and connection
config = Config()
godot = GodotConnection(config)

# Initialize FastMCP server
app = FastMCP(
    name="GODOT-MCP",
    instructions="""Complete Godot Engine scene manipulation toolkit for AI assistants.

This MCP server provides comprehensive control over Godot 4.5 scenes and nodes, enabling AI assistants to:
• Create, modify, and organize scene hierarchies
• Set properties, transforms, and visual attributes
• Attach scripts and connect signals for interactive behavior
• Debug and inspect scene state in real-time
• Build complete game scenes through natural language commands

Perfect for game development workflows, prototyping, and automated scene construction.
All operations are undoable and include robust error handling with Godot-specific error messages."""
)

async def _execute_command(command_type: str, params: Dict[str, Any], success_formatter, error_prefix: str) -> str:
    """Helper to execute a command in Godot and handle response."""
    try:
        await ensure_godot_connection()
        command = {"type": command_type, "params": params}
        response = await godot.send_command(command)

        if response.get("status") == "success":
            data = success_formatter(response.get("data", {}))
            return json.dumps({"status": "success", "data": data}, indent=2)
        else:
            error_msg = response.get('error', 'Unknown error')
            if error_msg == "No scene is currently open":
                error_data = {"message": f"❌ {error_msg}. Please open a scene in Godot editor first, then try again."}
            else:
                error_data = {"message": f"❌ {error_prefix}: {error_msg}"}
            return json.dumps({"status": "error", "error": error_data}, indent=2)
    except Exception as e:
        error_data = {"message": f"❌ {error_prefix}: {str(e)}"}
        return json.dumps({"status": "error", "error": error_data}, indent=2)

@app.tool()
async def get_scene_tree() -> str:
    """Get the complete scene tree structure with all nodes, their types, and hierarchy.

    This tool provides a comprehensive view of your Godot scene, showing:
    - Root node and its properties
    - All child nodes with their types and paths
    - Node hierarchy and relationships
    - Current scene file path

    Useful for understanding scene structure before making changes, debugging layout issues,
    or getting an overview of available nodes for scripting.

    Returns: JSON object with scene tree data including node names, types, paths, and hierarchy.

    Example usage:
    - "Show me the current scene structure"
    - "What nodes are in my scene?"
    - "Get an overview of the scene hierarchy"
    """
    return await _execute_command(
        "get_scene_tree",
        {},
        lambda data: data,
        "Failed to get scene tree"
    )

@app.tool()
async def create_node(node_type: str, parent_path: str = ".", node_name: str = "", shape_type: str = "", shape_properties: Dict[str, Any] = None) -> str:
    """Create a new node in the Godot scene with full undo support.

    This tool creates any valid Godot node type and adds it to the scene hierarchy.
    The node will be properly owned by the scene and can be immediately manipulated.

    Args:
        node_type: Godot node class name (e.g., 'Node2D', 'Sprite2D', 'CharacterBody2D',
                   'Label', 'Button', 'Area2D', 'CollisionShape2D', etc.)
        parent_path: Path to parent node (default: "." for scene root)
                     Use paths like "Player", "UI/CanvasLayer", or "Enemies/Enemy1"
        node_name: Custom name for the node (optional - auto-generated if empty)
        shape_type: For CollisionShape2D/CollisionShape3D nodes, the shape type to create (optional)
                   2D Shapes:
                   - "RectangleShape2D": Rectangle collision shape (default for CollisionShape2D)
                   - "CircleShape2D": Circular collision shape
                   - "CapsuleShape2D": Capsule collision shape
                   - "ConvexPolygonShape2D": Convex polygon collision shape
                   - "ConcavePolygonShape2D": Concave polygon collision shape
                   - "WorldBoundaryShape2D": World boundary collision shape
                   - "SeparationRayShape2D": Separation ray collision shape
                   - "SegmentShape2D": Line segment collision shape
                   3D Shapes:
                   - "BoxShape3D": Box collision shape (default for CollisionShape3D)
                   - "SphereShape3D": Spherical collision shape
                   - "CapsuleShape3D": Capsule collision shape
                   - "CylinderShape3D": Cylinder collision shape
                   - "ConvexPolygonShape3D": Convex polygon collision shape
                   - "ConcavePolygonShape3D": Concave polygon collision shape
                   - "HeightMapShape3D": Height map collision shape
                   - "WorldBoundaryShape3D": World boundary collision shape
        shape_properties: Properties for the shape (optional)
                         2D Shapes:
                         - RectangleShape2D: {"size": [width, height]} (default: [32, 32])
                         - CircleShape2D: {"radius": radius} (default: 16)
                         - CapsuleShape2D: {"radius": radius, "height": height} (default: 16, 32)
                         - ConvexPolygonShape2D: {"points": [[x1,y1], [x2,y2], ...]}
                         - ConcavePolygonShape2D: {"segments": [[x1,y1], [x2,y2], ...]}
                         3D Shapes:
                         - BoxShape3D: {"size": [width, height, depth]} (default: [2, 2, 2])
                         - SphereShape3D: {"radius": radius} (default: 1)
                         - CapsuleShape3D: {"radius": radius, "height": height} (default: 1, 2)
                         - CylinderShape3D: {"radius": radius, "height": height} (default: 1, 2)
                         - ConvexPolygonShape3D: {"points": [[x1,y1,z1], [x2,y2,z2], ...]}
                         - HeightMapShape3D: {"map_width": width, "map_depth": depth, "map_data": [heights...]}

    Returns: Success message with the created node's path

    Examples:
    - "Create a Sprite2D node as a child of the Player node"
    - "Add a CollisionShape2D with RectangleShape2D size 64x64 to my Area2D node"
    - "Create a new Label node in the UI canvas"
    - "Add a CharacterBody2D for the player character"
    - "Create a CollisionShape2D with CircleShape2D radius 20"

    Note: All changes are undoable in Godot's editor.
    """
    params = {
        "node_type": node_type,
        "parent_path": parent_path,
        "node_name": node_name,
        "shape_type": shape_type,
        "shape_properties": shape_properties or {}
    }
    def success_formatter(data):
        node_path = data.get('node_path', 'Unknown')
        node_name_created = data.get('node_name', node_type)
        shape_info = ""
        if shape_type:
            shape_info = f" with {shape_type}"
        return {"message": f"✅ Created {node_type} node '{node_name_created}'{shape_info} at path: {node_path}"}

    return await _execute_command(
        "create_node",
        params,
        success_formatter,
        f"Failed to create {node_type} node"
    )

@app.tool()
async def delete_node(node_path: str) -> str:
    """Delete a node from the scene

    Args:
        node_path: Path to the node to delete
    """
    return await _execute_command(
        "delete_node",
        {"node_path": node_path},
        lambda data: {"message": f"🗑️ Successfully deleted node: {node_path}"},
        f"Failed to delete node {node_path}"
    )

@app.tool()
async def get_node_properties(node_path: str) -> str:
    """Get properties of a specific node

    Args:
        node_path: Path to the node
    """
    return await _execute_command(
        "get_node_properties",
        {"node_path": node_path},
        lambda data: data,
        "Failed to get node properties"
    )

@app.tool()
async def set_node_property(node_path: str, property_name: str, value: Any) -> str:
    """Set any property on a Godot node with type validation and undo support.

    This tool can modify any exposed property on Godot nodes including:
    - Transform properties (position, rotation, scale)
    - Visual properties (modulate, visible, z_index)
    - Physics properties (collision_layer, collision_mask)
    - Custom script properties
    - UI properties (text, size, anchors)

    Args:
        node_path: Path to the target node (e.g., "Player", "UI/HealthBar")
        property_name: Property name (e.g., "position", "text", "modulate", "visible")
        value: New value matching the property type:
               - Vector2: [x, y] for 2D positions/scales
               - Vector3: [x, y, z] for 3D transforms
               - Color: [r, g, b, a] (0-1 range)
               - bool: true/false
               - String: "text value"
               - int/float: numeric values

    Returns: Success confirmation with property details

    Examples:
    - "Set the Player's position to (100, 200)"
    - "Change the Label's text to 'Game Over'"
    - "Make the Sprite invisible by setting visible to false"
    - "Set the Button's modulate color to red [1, 0, 0, 1]"

    Note: Use get_node_properties first to see available properties and their current values.
    """
    params = {
        "node_path": node_path,
        "property_name": property_name,
        "value": value
    }
    return await _execute_command(
        "set_node_property",
        params,
        lambda data: {"message": f"✅ Set {property_name} on node {node_path}"},
        f"Failed to set {property_name} on {node_path}"
    )

@app.tool()
async def move_node(node_path: str, new_parent_path: str, new_name: str = "") -> str:
    """Move a node to a new parent and optionally rename it

    Args:
        node_path: Path to the node to move
        new_parent_path: Path to the new parent node
        new_name: New name for the node (optional)
    """
    params = {
        "node_path": node_path,
        "new_parent_path": new_parent_path,
        "new_name": new_name
    }
    return await _execute_command(
        "move_node",
        params,
        lambda data: {"message": f"📦 Successfully moved node to {data.get('new_path', 'new location')}"},
        f"Failed to move node {node_path}"
    )

@app.tool()
async def duplicate_node(node_path: str, new_name: str = "") -> str:
    """Duplicate a node

    Args:
        node_path: Path to the node to duplicate
        new_name: Name for the duplicated node (optional)
    """
    params = {"node_path": node_path, "new_name": new_name}
    return await _execute_command(
        "duplicate_node",
        params,
        lambda data: {"message": f"📋 Successfully duplicated node: {data.get('duplicate_path', 'duplicate')}"},
        f"Failed to duplicate node {node_path}"
    )

@app.tool()
async def set_node_transform(node_path: str, position: List[float] = None, rotation: List[float] = None, scale: List[float] = None) -> str:
    """Set position, rotation, and scale of a Godot node with precise control.

    This tool handles both 2D and 3D transforms automatically based on the node type.
    For 2D nodes (Node2D, Control, etc.): uses Vector2 [x, y]
    For 3D nodes (Node3D, etc.): uses Vector3 [x, y, z]

    Args:
        node_path: Path to the node to transform
        position: [x, y] or [x, y, z] coordinates (optional)
        rotation: [x, y, z] rotation in degrees (optional)
                 For 2D nodes, only rotation[0] (Z-axis) is used
        scale: [x, y] or [x, y, z] scale factors (optional)

    Returns: Success confirmation with transform details

    Examples:
    - "Move the Player to position (100, 200)"
    - "Rotate the Enemy by 45 degrees"
    - "Scale the Background to (2, 2) for zoom effect"
    - "Set the Camera3D position to (0, 5, 10)"

    Note: Only specify the transforms you want to change - others remain unchanged.
    """
    params = {
        "node_path": node_path,
        "position": position,
        "rotation": rotation,
        "scale": scale
    }
    def success_formatter(data):
        changes = []
        if position: changes.append(f"position={position}")
        if rotation: changes.append(f"rotation={rotation}")
        if scale: changes.append(f"scale={scale}")
        return {"message": f"✅ Set transform on {node_path}: {', '.join(changes)}"}

    return await _execute_command(
        "set_node_transform",
        params,
        success_formatter,
        f"Failed to set transform on {node_path}"
    )

@app.tool()
async def change_collision_shape(node_path: str, shape_type: str, shape_properties: Dict[str, Any] = None) -> str:
    """Change the collision shape of an existing CollisionShape2D or CollisionShape3D node.

    This tool allows you to modify the shape resource of existing collision shape nodes,
    changing from one shape type to another or modifying the properties of the current shape.

    Args:
        node_path: Path to the CollisionShape2D or CollisionShape3D node to modify
        shape_type: New shape type to assign:
                    2D Shapes: RectangleShape2D, CircleShape2D, CapsuleShape2D, ConvexPolygonShape2D,
                              ConcavePolygonShape2D, WorldBoundaryShape2D, SeparationRayShape2D, SegmentShape2D
                    3D Shapes: BoxShape3D, SphereShape3D, CapsuleShape3D, CylinderShape3D, ConvexPolygonShape3D,
                              ConcavePolygonShape3D, HeightMapShape3D, WorldBoundaryShape3D
        shape_properties: Properties for the new shape (same format as create_node)

    Returns: Success confirmation with shape change details

    Examples:
        - "Change DefaultRectShape to a circle with radius 25"
        - "Convert PlayerShape to a capsule with radius 8 and height 16"
        - "Update PlatformShape to a larger rectangle [300, 40]"

    Note: This completely replaces the existing shape resource with a new one.
    """
    params = {
        "node_path": node_path,
        "shape_type": shape_type,
        "shape_properties": shape_properties or {}
    }
    return await _execute_command(
        "change_collision_shape",
        params,
        lambda data: {"message": f"🔄 Changed {node_path} to {shape_type} shape"},
        f"Failed to change collision shape on {node_path}"
    )

@app.tool()
async def set_node_visibility(node_path: str, visible: bool) -> str:
    """Set the visibility of a node

    Args:
        node_path: Path to the node
        visible: Whether the node should be visible
    """
    params = {"node_path": node_path, "visible": visible}
    return await _execute_command(
        "set_node_visibility",
        params,
        lambda data: {"message": f"👁️ Successfully set visibility of {node_path} to {visible}"},
        f"Failed to set visibility of {node_path}"
    )

@app.tool()
async def connect_signal(from_node_path: str, signal_name: str, to_node_path: str, method_name: str) -> str:
    """Connect Godot signals between nodes for event-driven programming.

    This creates event connections between Godot nodes, enabling interactive behavior.
    Common signals include: pressed, button_down, body_entered, area_entered, timeout, etc.

    Args:
        from_node_path: Path to the node that emits the signal (e.g., "Button", "Area2D")
        signal_name: Signal name to connect (e.g., "pressed", "body_entered", "timeout")
        to_node_path: Path to the node that will handle the signal
        method_name: Method name to call when signal fires (must exist on target node)

    Returns: Success confirmation of the signal connection

    Examples:
    - "Connect the 'pressed' signal of StartButton to call 'start_game' on Main"
    - "Make Enemy detect Player by connecting 'body_entered' to 'on_player_collision'"
    - "Connect Timer's 'timeout' signal to 'spawn_enemy' method"
    - "Link Button's 'button_down' to 'play_sound' on AudioPlayer"

    Note: Use get_node_signals() first to see available signals on a node. The target method must exist.
    **Warning: This operation is not undoable in the Godot editor.**
    """
    params = {
        "from_node_path": from_node_path,
        "signal_name": signal_name,
        "to_node_path": to_node_path,
        "method_name": method_name
    }
    def success_formatter(data):
        return {"message": f"🔗 Connected signal '{signal_name}' from {from_node_path} → {method_name}() on {to_node_path}"}

    return await _execute_command(
        "connect_signal",
        params,
        success_formatter,
        f"Failed to connect signal '{signal_name}' from {from_node_path} to {to_node_path}"
    )

@app.tool()
async def disconnect_signal(from_node_path: str, signal_name: str, to_node_path: str, method_name: str) -> str:
    """Disconnect a signal connection

    Args:
        from_node_path: Path to the node that emits the signal
        signal_name: Name of the signal
        to_node_path: Path to the node that receives the signal
        method_name: Name of the method

    Note:
        **Warning: This operation is not undoable in the Godot editor.**
    """
    params = {
        "from_node_path": from_node_path,
        "signal_name": signal_name,
        "to_node_path": to_node_path,
        "method_name": method_name
    }
    def success_formatter(data):
        return {"message": f"🔌 Successfully disconnected signal {signal_name} from {from_node_path} to {method_name} on {to_node_path}"}

    return await _execute_command(
        "disconnect_signal",
        params,
        success_formatter,
        f"Failed to disconnect signal {signal_name}"
    )

@app.tool()
async def get_node_signals(node_path: str) -> str:
    """Get all signals available on a node

    Args:
        node_path: Path to the node
    """
    return await _execute_command(
        "get_node_signals",
        {"node_path": node_path},
        lambda data: data,
        "Error"
    )

@app.tool()
async def get_node_methods(node_path: str) -> str:
    """Get all methods available on a node

    Args:
        node_path: Path to the node
    """
    return await _execute_command(
        "get_node_methods",
        {"node_path": node_path},
        lambda data: data,
        "Error"
    )

@app.tool()
async def call_node_method(node_path: str, method_name: str, args: List[Any] = None) -> str:
    """Call a method on a node

    Args:
        node_path: Path to the node
        method_name: Name of the method to call
        args: Arguments to pass to the method (optional)
    """
    params = {
        "node_path": node_path,
        "method_name": method_name,
        "args": args or []
    }
    return await _execute_command(
        "call_node_method",
        params,
        lambda data: {"message": f"⚡ Method {method_name} called successfully. Result: {data.get('result')}"},
        f"Failed to call method {method_name} on {node_path}"
    )

@app.tool()
async def find_nodes_by_type(node_type: str, search_root: str = ".") -> str:
    """Find all nodes of a specific type in the scene

    Args:
        node_type: The type of nodes to find (e.g., 'Node2D', 'Sprite2D')
        search_root: Root path to start searching from (default: scene root)
    """
    params = {"node_type": node_type, "search_root": search_root}
    def success_formatter(data):
        nodes = data.get("nodes", [])
        return {"nodes": nodes, "message": f"🔍 Found {len(nodes)} nodes of type {node_type}."}

    return await _execute_command(
        "find_nodes_by_type",
        params,
        success_formatter,
        f"Failed to find nodes of type {node_type}"
    )

@app.tool()
async def get_node_children(node_path: str, recursive: bool = False) -> str:
    """Get children of a node

    Args:
        node_path: Path to the parent node
        recursive: Whether to get all descendants recursively
    """
    params = {"node_path": node_path, "recursive": recursive}
    def success_formatter(data):
        children = data.get("children", [])
        mode = "recursive" if recursive else "direct"
        return {"children": children, "message": f"👶 Found {len(children)} {mode} children of {node_path}."}

    return await _execute_command(
        "get_node_children",
        params,
        success_formatter,
        f"Failed to get children of {node_path}"
    )

@app.tool()
async def add_script_to_node(node_path: str, script_content: str) -> str:
    """Attach GDScript code to a Godot node to add custom behavior and logic.

    This tool creates a new GDScript file and attaches it to the specified node,
    enabling custom game logic, event handling, and interactive behavior.

    Args:
        node_path: Path to the node to attach the script to
        script_content: Complete GDScript code as a string, including:
                        - extends Node2D/Node3D/etc. (optional, inferred from node type)
                        - func _ready(): initialization code
                        - func _process(delta): frame updates
                        - Custom methods and variables
                        - Signal handlers

    Returns: Success confirmation with script attachment details

    Examples:
    - "Add a movement script to the Player node with WASD controls"
    - "Create a script for Enemy AI with pathfinding logic"
    - "Attach a health system script to the Player character"
    - "Add collision detection script to handle player-enemy interactions"

    Script Example:
    ```gdscript
        extends CharacterBody2D

        @export var speed = 300.0
        @export var jump_velocity = -400.0

        func _physics_process(delta):
            # Movement logic here
            var direction = Input.get_axis("ui_left", "ui_right")
            velocity.x = direction * speed
            move_and_slide()
    ```

    Note: The script is validated for syntax errors before attachment.
    Use get_node_properties() to verify the script was attached successfully.
    """
    params = {"node_path": node_path, "script_content": script_content}
    return await _execute_command(
        "add_script_to_node",
        params,
        lambda data: {"message": f"📝 Successfully attached GDScript to {node_path} ({len(script_content)} characters)"},
        f"Failed to add script to {node_path}"
    )

@app.tool()
async def get_debug_info() -> str:
    """Get current debug information and errors from Godot"""
    return await _execute_command(
        "get_debug_info",
        {},
        lambda data: data,
        "Failed to get debug info"
    )

@app.tool()
async def check_connection() -> str:
    """Check the connection status to Godot and server health.

    This tool verifies that the MCP server can communicate with the Godot addon,
    providing connection status, server information, and any potential issues.

    Returns: Connection status and health information
    """
    try:
        await ensure_godot_connection()
        command = {"type": "get_debug_info", "params": {}}
        response = await godot.send_command(command)

        if response.get("status") == "success":
            debug_data = response.get("data", {})
            server_info = debug_data.get("server_status", {})

            status_report = {
                "status": "Healthy",
                "websocket_host": config.godot_host,
                "websocket_port": config.godot_port,
                "godot_version": debug_data.get('godot_version', {}).get('string', 'Unknown'),
                "active_clients": server_info.get('client_count', 0),
                "server_uptime": debug_data.get('timestamp', 'Unknown'),
                "error_log_size": len(debug_data.get('error_log', []))
            }
            return json.dumps({"status": "success", "data": status_report}, indent=2)
        else:
            return json.dumps({"status": "error", "error": {"message": f"⚠️ Connected but communication failed: {response.get('error', 'Unknown error')}"}}, indent=2)

    except Exception as e:
        return json.dumps({"status": "error", "error": {"message": f"❌ Connection check failed: {str(e)}"}}, indent=2)

@app.tool()
async def run_scene() -> str:
    """Play/run the current scene in Godot (starts the game simulation)

    This tool starts the Godot game player to run the current scene.
    Note: This plays the scene in game mode, not opens it in the editor.
    For editor operations, you need to have a scene open in Godot's editor first.
    """
    return await _execute_command(
        "run_scene",
        {},
        lambda data: {"message": "▶️ Scene started successfully"},
        "Failed to start scene"
    )

@app.tool()
async def stop_scene() -> str:
    """Stop the running scene in Godot"""
    return await _execute_command(
        "stop_scene",
        {},
        lambda data: {"message": "⏹️ Scene stopped successfully"},
        "Failed to stop scene"
    )

@app.tool()
async def get_script_content(node_path: str) -> str:
    """Retrieve the complete GDScript source code attached to a specific node.

    This tool extracts the full script content from any Godot node that has a GDScript attached,
    allowing you to inspect existing game logic, understand node behavior, or prepare for modifications.

    Args:
        node_path: Path to the node containing the script (e.g., "Player", "Enemy", "UI/ScoreLabel")

    Returns: Complete script content with character count and resource path information

    Examples:
        - "Show me the movement script on the Player node"
        - "Get the AI logic from the Enemy node"
        - "Check what script is attached to the Main scene node"

    Note: Use this tool before modifying scripts to understand the current implementation.
    The returned content includes the full GDScript source code for analysis or backup.
    """
    return await _execute_command(
        "get_script_content",
        {"node_path": node_path},
        lambda data: data,
        f"Failed to get script content from {node_path}"
    )

@app.tool()
async def set_script_content(node_path: str, content: str) -> str:
    """Replace the entire GDScript content on a node with new code.

    This tool completely overwrites the existing script attached to a node with new GDScript code.
    Use this for major script modifications, refactoring, or implementing new functionality.
    The script is validated for syntax errors before being applied.

    Args:
        node_path: Path to the node whose script should be updated (e.g., "Player", "Enemy")
        content: Complete new GDScript code as a string, including class declaration and all methods

    Returns: Success confirmation with character count

    Examples:
        - "Update the Player script with new movement controls"
        - "Replace the Enemy AI with pathfinding logic"
        - "Add collision detection to the Player script"

    Note: This completely replaces the existing script. Use get_script_content() first to preserve existing code.
    The new script is validated for syntax errors before attachment. Changes are undoable in Godot.
    """
    params = {"node_path": node_path, "content": content}
    return await _execute_command(
        "set_script_content",
        params,
        lambda data: {"message": f"📝 Successfully updated script content on {node_path} ({len(content)} characters)"},
        f"Failed to update script content on {node_path}"
    )

@app.tool()
async def validate_script(content: str) -> str:
    """Check GDScript code for syntax errors and compilation issues without attaching it to any node.

    This tool validates GDScript syntax and catches common programming errors before you attach
    scripts to nodes. Use this to verify code correctness and get specific error messages with line numbers.

    Args:
        content: Complete GDScript code to validate (must include proper class declaration)

    Returns: Validation result with detailed error information if any

    Examples:
        - "Check if this movement script has any syntax errors"
        - "Validate the AI logic before attaching it to enemies"
        - "Test the collision detection code for errors"

    Note: This only checks syntax and basic compilation errors, not runtime logic issues.
    Use this tool before set_script_content() or add_script_to_node() to catch errors early.
    """
    def success_formatter(data):
        if data.get("valid", False):
            return {"valid": True, "message": f"✅ Script validation successful ({len(content)} characters)"}
        else:
            return {"valid": False, "error": data.get("error", "Unknown validation error")}

    return await _execute_command(
        "validate_script",
        {"content": content},
        success_formatter,
        "Failed to validate script"
    )

@app.tool()
async def create_script_file(filename: str, content: str) -> str:
    """Create a new standalone GDScript file in the project's script directory.

    This tool creates reusable script files that can be attached to multiple nodes or used as templates.
    The file is saved in the project's scripts directory and can be referenced by other scripts.

    Args:
        filename: Name for the new script file (without .gd extension, e.g., "PlayerController", "EnemyAI")
        content: Complete GDScript code including class declaration and all functionality

    Returns: Success confirmation with the created file path

    Examples:
        - "Create a reusable PlayerController script with movement logic"
        - "Make a new EnemyAI script for different enemy types"
        - "Create a utility script for game management functions"

    Note: Files are created in the project's scripts directory. Use attach_script_to_node() to attach these files to nodes.
    The script content is validated before file creation.
    **Warning: This is a file system operation and cannot be undone.**
    """
    params = {"filename": filename, "content": content}
    return await _execute_command(
        "create_script_file",
        params,
        lambda data: {"file_path": data.get("file_path", "unknown"), "message": f"📄 Successfully created script file: {data.get('file_path', 'unknown')}"},
        f"Failed to create script file {filename}"
    )

@app.tool()
async def load_script_file(file_path: str) -> str:
    """Load and display the content of an existing GDScript file from the project.

    This tool reads script files from the project's file system, allowing you to examine
    existing scripts, use them as templates, or prepare them for modification.

    Args:
        file_path: Path to the GDScript file (e.g., "res://scripts/Player.gd", "res://EnemyAI.gd")

    Returns: Complete script content with character count

    Examples:
        - "Load the PlayerController script to see its current implementation"
        - "Check what's in the UtilityFunctions script"
        - "Read the base Enemy script to understand the inheritance structure"

    Note: Use Godot's res:// paths for project files. This tool only reads existing files.
    """
    return await _execute_command(
        "load_script_file",
        {"file_path": file_path},
        lambda data: data,
        f"Failed to load script file {file_path}"
    )

@app.tool()
async def get_script_variables(node_path: str) -> str:
    """Get exported variables from a node's script

    Args:
        node_path: Path to the node with the script
    """
    return await _execute_command(
        "get_script_variables",
        {"node_path": node_path},
        lambda data: data,
        f"Failed to get script variables from {node_path}"
    )

@app.tool()
async def set_script_variable(node_path: str, var_name: str, value: Any) -> str:
    """Set the value of an exported script variable

    Args:
        node_path: Path to the node with the script
        var_name: Name of the exported variable
        value: New value for the variable
    """
    params = {"node_path": node_path, "var_name": var_name, "value": value}
    return await _execute_command(
        "set_script_variable",
        params,
        lambda data: {"message": f"🔧 Successfully set {var_name} = {value} on {node_path}"},
        f"Failed to set script variable {var_name} on {node_path}"
    )

@app.tool()
async def get_script_functions(node_path: str) -> str:
    """Get functions defined in a node's script for signal connection and method inspection.

    This tool discovers all callable methods in a GDScript, including their signatures,
    parameter counts, and return types. Useful for connecting signals or understanding
    available functionality.

    Args:
        node_path: Path to the node with the script (e.g., "Player", "UI/Button")

    Returns: Formatted list of functions with signatures and virtual method indicators

    Examples:
        - "See what methods are available on the Player node"
        - "Check the Enemy's AI functions for signal connections"
        - "List all callable methods on this UI component"

    Note: Includes both custom methods and Godot virtual methods (_ready, _process, etc.).
    Virtual methods are marked with (virtual) and are commonly overridden.
    """
    return await _execute_command(
        "get_script_functions",
        {"node_path": node_path},
        lambda data: data,
        f"Failed to get script functions from {node_path}"
    )

@app.tool()
async def attach_script_to_node(node_path: str, script_path: str) -> str:
    """Attach an existing script file to a node for reusable code sharing.

    This tool links a standalone GDScript file (created with create_script_file) to a node,
    enabling code reuse across multiple nodes and cleaner project organization.

    Args:
        node_path: Path to the node to attach the script to (e.g., "Player", "Enemies/Enemy1")
        script_path: Path to the existing script file (e.g., "res://scripts/PlayerController.gd")

    Returns: Success confirmation of script attachment

    Examples:
        - "Attach the PlayerController script to the Player node"
        - "Use the EnemyAI script for all enemy instances"
        - "Link the shared UI logic to this button"

    Note: The script file must exist and be a valid GDScript. Use create_script_file() to create reusable scripts.
    Attaching replaces any existing script on the node. Use detach_script_from_node() to remove first if needed.
    """
    params = {"node_path": node_path, "script_path": script_path}
    return await _execute_command(
        "attach_script_to_node",
        params,
        lambda data: {"message": f"📎 Successfully attached script {script_path} to {node_path}"},
        f"Failed to attach script {script_path} to {node_path}"
    )

@app.tool()
async def detach_script_from_node(node_path: str) -> str:
    """Remove the script from a node to disable its custom behavior.

    This tool detaches any attached GDScript from a node, returning it to its default
    Godot behavior. Useful for temporarily disabling custom logic or switching scripts.

    Args:
        node_path: Path to the node to detach the script from (e.g., "Player", "UI/Button")

    Returns: Success confirmation of script removal

    Examples:
        - "Remove the custom script from the Player node"
        - "Detach the AI script from this enemy"
        - "Clear the script from this UI element"

    Note: The node will revert to default Godot behavior after script removal.
    Any @export variables and custom methods will no longer be available.
    The script file itself is not deleted, only the attachment to the node.
    """
    return await _execute_command(
        "detach_script_from_node",
        {"node_path": node_path},
        lambda data: {"message": f"📤 Successfully detached script from {node_path}"},
        f"Failed to detach script from {node_path}"
    )

@app.tool()
async def create_resource(resource_type: str) -> str:
    """Create a new Godot resource instance for use in your game project.

    This tool creates various types of Godot resources including Texture, AudioStream,
    PackedScene, and custom resources. Resources are the building blocks of Godot games,
    containing data like images, sounds, scenes, and configuration.

    Args:
        resource_type: Godot resource class name (e.g., "Texture2D", "AudioStream", "PackedScene", "Resource")

    Returns: Success confirmation with resource details

    Examples:
        - "Create a new Texture2D resource for sprites"
        - "Make an AudioStream resource for sound effects"
        - "Create a PackedScene resource for level templates"
        - "Generate a custom Resource for game configuration"

    Note: The resource is created in memory and can be saved to disk using save_resource().
    Use this when you need to programmatically create resources for your game.
    """
    return await _execute_command(
        "create_resource",
        {"resource_type": resource_type},
        lambda data: {"message": f"📄 Successfully created {resource_type} resource"},
        f"Failed to create {resource_type} resource"
    )

@app.tool()
async def load_resource(resource_path: str) -> str:
    """Load an existing resource from the Godot project filesystem.

    This tool loads resources from your project's res:// directory, including textures,
    audio files, scenes, scripts, and custom resources. Godot caches loaded resources
    for performance, so loading the same resource multiple times returns the same instance.

    Args:
        resource_path: Path to the resource file (e.g., "res://textures/player.png", "res://scenes/level.tscn")

    Returns: Success confirmation with resource type information

    Examples:
        - "Load the player texture from res://textures/player.png"
        - "Load the main menu scene from res://scenes/menu.tscn"
        - "Load the background music from res://audio/bgm.ogg"
        - "Load the game configuration from res://config/settings.tres"

    Note: Resources must exist in the project filesystem. Use list_directory() to explore available files.
    Loaded resources are cached by Godot for performance.
    """
    return await _execute_command(
        "load_resource",
        {"resource_path": resource_path},
        lambda data: {"type": data.get("type", "Unknown"), "message": f"📂 Successfully loaded {data.get('type', 'Unknown')} resource from {resource_path}"},
        f"Failed to load resource from {resource_path}"
    )

@app.tool()
async def save_resource(resource_type: str, save_path: str, flags: int = 0) -> str:
    """Create and save a resource to disk in Godot's native format.

    This tool creates a new resource of the specified type and immediately saves it to disk.
    Use this to create and persist resources in one operation.

    Args:
        resource_type: Godot resource class name (e.g., "Texture2D", "AudioStream", "PackedScene", "Resource")
        save_path: Path where to save the resource (e.g., "res://my_resource.tres")
        flags: Save flags (0 = default, 1 = compress) (optional)

    Returns: Success confirmation of resource creation and save

    Examples:
        - "Create and save a new Texture2D resource to res://textures/new_texture.tres"
        - "Create and save an AudioStream resource to res://audio/new_sound.ogg"
        - "Create and save a PackedScene resource to res://scenes/template.tscn"
        - "Create and save a custom Resource to res://config/settings.tres"

    Note: Use compression flag (1) for smaller file sizes, especially for large resources.
    Resources are saved in Godot's native format and can be loaded with load_resource().
    **Warning: This is a file system operation and cannot be undone.**
    """
    params = {"resource_type": resource_type, "save_path": save_path, "flags": flags}
    def success_formatter(data):
        compression_note = " with compression" if flags & 1 else ""
        return {"message": f"💾 Successfully created and saved {resource_type} resource to {save_path}{compression_note}"}

    return await _execute_command(
        "create_and_save_resource",
        params,
        success_formatter,
        f"Failed to create and save {resource_type} resource to {save_path}"
    )

@app.tool()
async def get_resource_dependencies(resource_path: str) -> str:
    """Analyze and list all resources that a given resource depends on.

    This tool examines resource dependencies to understand the relationship graph
    between assets in your project. Useful for optimization, bundling, and understanding
    which resources need to be included when distributing parts of your game.

    Args:
        resource_path: Path to the resource to analyze (e.g., "res://scenes/level.tscn")

    Returns: Formatted list of all dependent resources

    Examples:
        - "Check what resources the main scene depends on"
        - "Analyze dependencies of the player character scene"
        - "See what textures and sounds are used in this level"
        - "Find all resources needed for the UI system"

    Note: Dependencies include textures, audio, scripts, and other scenes referenced by the resource.
    This helps with asset management and optimization decisions.
    """
    return await _execute_command(
        "get_resource_dependencies",
        {"resource_path": resource_path},
        lambda data: data,
        f"Failed to get dependencies for {resource_path}"
    )

@app.tool()
async def list_directory(dir_path: str) -> str:
    """List all files and subdirectories in a Godot project directory.

    This tool explores your project's file structure, showing available resources,
    scenes, scripts, and assets. Essential for discovering what files are available
    for loading and understanding your project's organization.

    Args:
        dir_path: Directory path to list (e.g., "res://", "res://scenes", "res://textures")

    Returns: Formatted list of directory contents

    Examples:
        - "Show me all files in the project root"
        - "List available scenes in res://scenes/"
        - "See what textures are in res://textures/"
        - "Explore the audio directory contents"

    Note: Hidden files (starting with .) are excluded. Directories end with /.
    Use this to discover available resources before loading them.
    """
    return await _execute_command(
        "list_directory",
        {"dir_path": dir_path},
        lambda data: data,
        f"Failed to list directory {dir_path}"
    )

@app.tool()
async def get_current_scene_info() -> str:
    """Get information about the currently edited scene in Godot.

    This tool provides details about the currently open scene in the Godot editor,
    including the scene path, root node type, and basic statistics.

    Returns: Scene information including path, root node details, and child count

    Examples:
        - "What scene is currently open?"
        - "Get information about the current scene"
        - "Show me the scene details"

    Note: Requires a scene to be open in Godot editor.
    """
    return await _execute_command(
        "get_current_scene_info",
        {},
        lambda data: data,
        "Failed to get scene info"
    )

@app.tool()
async def open_scene(scene_path: str) -> str:
    """Open a scene file in the Godot editor.

    This tool opens an existing scene file (.tscn) in the Godot editor,
    making it the currently edited scene.

    Args:
        scene_path: Path to the scene file to open (e.g., "res://scenes/level1.tscn")

    Returns: Success confirmation with scene path

    Examples:
        - "Open the main menu scene at res://scenes/menu.tscn"
        - "Load level 1 from res://levels/level1.tscn"
        - "Switch to the player scene"

    Note: The scene file must exist and be a valid .tscn file.
    """
    return await _execute_command(
        "open_scene",
        {"scene_path": scene_path},
        lambda data: {"message": f"📂 Successfully opened scene: {scene_path}"},
        f"Failed to open scene {scene_path}"
    )

@app.tool()
async def save_scene() -> str:
    """Save the currently edited scene in Godot.

    This tool saves the currently open scene to its existing file path.
    If the scene hasn't been saved before, use save_scene_as() instead.

    Returns: Success confirmation with saved scene path

    Examples:
        - "Save the current scene"
        - "Save my changes"
        - "Commit the scene changes"

    Note: Requires a scene to be open and previously saved.
    **Warning: This is a file system operation and cannot be undone.**
    """
    return await _execute_command(
        "save_scene",
        {},
        lambda data: {"message": f"💾 Successfully saved scene: {data.get('scene_path', 'unknown')}"},
        "Failed to save scene"
    )

@app.tool()
async def save_scene_as(scene_path: str) -> str:
    """Save the currently edited scene to a new file path.

    This tool saves the currently open scene to a specified file path,
    allowing you to save as a new file or change the location.

    Args:
        scene_path: New path where to save the scene (must end with .tscn)

    Returns: Success confirmation with new scene path

    Examples:
        - "Save scene as res://scenes/new_level.tscn"
        - "Save current scene to res://backups/scene_backup.tscn"
        - "Export scene to res://exports/level1.tscn"

    Note: The path must end with .tscn extension.
    **Warning: This is a file system operation and cannot be undone.**
    """
    return await _execute_command(
        "save_scene_as",
        {"scene_path": scene_path},
        lambda data: {"message": f"💾 Successfully saved scene as: {scene_path}"},
        f"Failed to save scene as {scene_path}"
    )

@app.tool()
async def create_new_scene(root_node_type: str = "Node2D") -> str:
    """Creates and opens a new, unsaved scene in the Godot editor.

    This tool creates a new scene with the specified root node, making it the active scene
    in the editor. This new scene is unsaved and has no file path. Use the 'save_scene_as'
    tool to save it to a .tscn file.

    Args:
        root_node_type: The class name of the root node for the new scene.
                        Common options: "Node2D", "Node3D", "Control", "Node".
                        Defaults to "Node2D".

    Returns: A JSON object confirming the creation of the new scene.

    Examples:
        - "Create a new 2D scene"
        - "Start a new 3D scene with Node3D root"
        - "Create a new UI scene with Control root, then save it as main_menu.tscn"

    Note: This action leaves the editor with an unsaved scene. Subsequent operations
    can be performed on this scene, but it must be saved with 'save_scene_as' to persist.
    """
    def success_formatter(data):
        root_type = data.get("root_node_type", root_node_type)
        root_name = data.get("root_node_name", "SceneRoot")
        return {"message": f"🆕 Successfully created a new unsaved scene with '{root_name}' ({root_type}) as the root. Use save_scene_as() to save it."}

    return await _execute_command(
        "create_new_scene",
        {"root_node_type": root_node_type},
        success_formatter,
        "Failed to create new scene"
    )

@app.tool()
async def instantiate_scene(scene_path: str, parent_path: str = ".") -> str:
    """Instantiate a scene and add it as a child to the specified parent.

    This tool loads a scene file and creates an instance of it, adding it
    as a child to the specified parent node in the current scene.

    Args:
        scene_path: Path to the scene file to instantiate (e.g., "res://scenes/enemy.tscn")
        parent_path: Path to the parent node where to add the instance (default: "." for scene root)

    Returns: Success confirmation with instance details

    Examples:
        - "Add enemy instance to the Enemies node"
        - "Instantiate player prefab at res://prefabs/player.tscn"
        - "Spawn collectible at the Items container"

    Note: The scene file must exist and the parent node must exist in the current scene.
    """
    params = {"scene_path": scene_path, "parent_path": parent_path}
    def success_formatter(data):
        instance_path = data.get("instance_path", "unknown")
        instance_name = data.get("instance_name", "unknown")
        return {"message": f"📦 Successfully instantiated {scene_path} as '{instance_name}' at {instance_path}"}

    return await _execute_command(
        "instantiate_scene",
        params,
        success_formatter,
        f"Failed to instantiate scene {scene_path}"
    )

@app.tool()
async def pack_scene_from_node(node_path: str, save_path: str) -> str:
    """Create a packed scene from an existing node and save it.

    This tool takes an existing node from the current scene and creates
    a reusable packed scene file from it, which can then be instantiated elsewhere.

    Args:
        node_path: Path to the node to pack into a scene
        save_path: Path where to save the packed scene file (must end with .tscn)

    Returns: Success confirmation with save details

    Examples:
        - "Pack the Player node into res://prefabs/player.tscn"
        - "Create enemy prefab from the Enemy node"
        - "Save UI panel as reusable component"

    Note: The node must exist in the current scene and save path must end with .tscn.
    """
    params = {"node_path": node_path, "save_path": save_path}
    return await _execute_command(
        "pack_scene_from_node",
        params,
        lambda data: {"message": f"📦 Successfully packed scene from {node_path} and saved to {save_path}"},
        f"Failed to pack scene from {node_path}"
    )

@app.tool()
async def get_resource_metadata(resource_path: str) -> str:
    """Get comprehensive metadata about a resource including type, size, and dependencies.

    This tool provides detailed information about any resource in your project,
    helping you understand its properties, file size, and relationships to other assets.

    Args:
        resource_path: Path to the resource to analyze (e.g., "res://scenes/level.tscn")

    Returns: Detailed resource metadata including type, size, existence, and dependencies

    Examples:
        - "Get metadata for the player texture"
        - "Check information about the main scene file"
        - "Analyze the properties of this audio file"
        - "See details about the configuration resource"

    Note: Includes file size, resource type, existence status, and dependency information.
    Useful for asset management, optimization, and debugging resource issues.
    """
    return await _execute_command(
        "get_resource_metadata",
        {"resource_path": resource_path},
        lambda data: data,
        f"Failed to get metadata for {resource_path}"
    )

# Animation System Tools

@app.tool()
async def create_animation_player(parent_path: str = ".", node_name: str = "") -> str:
    """Create an AnimationPlayer node in the Godot scene with full undo support.

    This tool creates an AnimationPlayer node that can control animations for the entire scene
    or specific node hierarchies. AnimationPlayers are essential for creating complex animated
    sequences, character animations, UI transitions, and procedural animations.

    Args:
        parent_path: Path to parent node (default: "." for scene root)
                     Use paths like "Player", "UI/CanvasLayer", or "Enemies/Enemy1"
        node_name: Custom name for the AnimationPlayer (optional - auto-generated if empty)

    Returns: Success message with the created node's path

    Examples:
        - "Create an AnimationPlayer for the Player character"
        - "Add an AnimationPlayer to the UI canvas for menu transitions"
        - "Create an AnimationPlayer for enemy attack animations"

    Note: All changes are undoable in Godot's editor.
    """
    params = {
        "parent_path": parent_path,
        "node_name": node_name
    }
    def success_formatter(data):
        node_path = data.get('node_path', 'Unknown')
        node_name_created = data.get('node_name', 'AnimationPlayer')
        return {"message": f"🎬 Created AnimationPlayer '{node_name_created}' at path: {node_path}"}

    return await _execute_command(
        "create_animation_player",
        params,
        success_formatter,
        f"Failed to create AnimationPlayer"
    )

@app.tool()
async def get_animation_player_info(node_path: str) -> str:
    """Get AnimationPlayer state and properties for debugging and inspection.

    This tool provides comprehensive information about an AnimationPlayer's current state,
    including playback status, current animation, speed settings, and queue information.
    Essential for debugging animation issues and understanding player configuration.

    Args:
        node_path: Path to the AnimationPlayer node (e.g., "AnimationPlayer", "Player/Animator")

    Returns: Detailed AnimationPlayer state information

    Examples:
        - "Check the AnimationPlayer's current state"
        - "See what animation is currently playing"
        - "Get AnimationPlayer configuration details"

    Note: Provides real-time playback information and configuration settings.
    """
    return await _execute_command(
        "get_animation_player_info",
        {"node_path": node_path},
        lambda data: data,
        f"Failed to get AnimationPlayer info for {node_path}"
    )

@app.tool()
async def set_animation_player_property(node_path: str, property_name: str, value: Any) -> str:
    """Set AnimationPlayer properties like autoplay, speed, and blend settings.

    This tool allows configuration of AnimationPlayer behavior including playback speed,
    autoplay settings, blend times, and other core properties that affect how animations
    are played and transitioned.

    Args:
        node_path: Path to the AnimationPlayer node
        property_name: Property to modify:
                      - "autoplay": Animation to play on scene start (string)
                      - "speed_scale": Playback speed multiplier (float)
                      - "playback_default_blend_time": Default blend duration (float)
                      - "playback_auto_capture": Auto-capture mode (bool)
                      - "playback_auto_capture_duration": Auto-capture duration (float)
                      - "movie_quit_on_finish": Quit on movie finish (bool)
        value: New value for the property

    Returns: Success confirmation

    Examples:
        - "Set AnimationPlayer autoplay to 'idle'"
        - "Change playback speed to 2.0 for fast-forward"
        - "Enable auto-capture for procedural animations"

    Note: Changes are undoable in Godot's editor.
    """
    params = {
        "node_path": node_path,
        "property_name": property_name,
        "value": value
    }
    return await _execute_command(
        "set_animation_player_property",
        params,
        lambda data: {"message": f"⚙️ Set {property_name} = {value} on AnimationPlayer {node_path}"},
        f"Failed to set {property_name} on {node_path}"
    )

@app.tool()
async def remove_animation_player(node_path: str) -> str:
    """Remove an AnimationPlayer node from the scene.

    This tool safely removes AnimationPlayer nodes and all their associated animations.
    Use this when cleaning up unused animation controllers or restructuring scene hierarchy.

    Args:
        node_path: Path to the AnimationPlayer to remove

    Returns: Success confirmation

    Examples:
        - "Remove the unused AnimationPlayer from the Player node"
        - "Clean up the old animation controller"

    Note: This operation is undoable in Godot's editor.
    """
    return await _execute_command(
        "remove_animation_player",
        {"node_path": node_path},
        lambda data: {"message": f"🗑️ Successfully removed AnimationPlayer: {node_path}"},
        f"Failed to remove AnimationPlayer {node_path}"
    )

@app.tool()
async def play_animation(player_path: str, animation_name: str = "", custom_blend: float = -1, custom_speed: float = 1.0, from_end: bool = False) -> str:
    """Play animations with advanced playback controls.

    This tool provides full control over animation playback including custom blend times,
    speed modifications, and playback direction. Essential for creating dynamic animation
    sequences and interactive responses.

    Args:
        player_path: Path to the AnimationPlayer node
        animation_name: Name of animation to play (empty for current/default)
        custom_blend: Custom blend time in seconds (-1 for default)
        custom_speed: Playback speed multiplier (1.0 = normal speed)
        from_end: Start playback from the end (reverse playback)

    Returns: Success confirmation with playing animation info

    Examples:
        - "Play the 'walk' animation on the Player"
        - "Play 'jump' with 0.5 second blend time"
        - "Play 'death' animation in reverse from the end"
        - "Play current animation at double speed"

    Note: Playback controls are applied immediately and affect real-time animation.
    """
    params = {
        "player_path": player_path,
        "animation_name": animation_name,
        "custom_blend": custom_blend,
        "custom_speed": custom_speed,
        "from_end": from_end
    }
    def success_formatter(data):
        playing = data.get("playing", animation_name if animation_name else "current")
        blend_note = f" with {custom_blend}s blend" if custom_blend >= 0 else ""
        speed_note = f" at {custom_speed}x speed" if custom_speed != 1.0 else ""
        reverse_note = " in reverse" if from_end else ""
        return {"message": f"▶️ Playing animation '{playing}'{blend_note}{speed_note}{reverse_note}"}

    return await _execute_command(
        "play_animation",
        params,
        success_formatter,
        f"Failed to play animation on {player_path}"
    )

@app.tool()
async def pause_animation(player_path: str) -> str:
    """Pause the currently playing animation.

    This tool freezes animation playback at the current frame, allowing for
    precise control over animation timing and synchronization with game events.

    Args:
        player_path: Path to the AnimationPlayer node

    Returns: Success confirmation

    Examples:
        - "Pause the Player's walking animation"
        - "Freeze the current animation for debugging"

    Note: Use play_animation() to resume playback from the paused position.
    """
    return await _execute_command(
        "pause_animation",
        {"player_path": player_path},
        lambda data: {"message": f"⏸️ Paused animation on {player_path}"},
        f"Failed to pause animation on {player_path}"
    )

@app.tool()
async def stop_animation(player_path: str, keep_state: bool = False) -> str:
    """Stop animation playback with state preservation option.

    This tool stops the current animation and optionally preserves the animated
    properties at their current values, useful for creating pose-to-pose animations
    or maintaining specific states.

    Args:
        player_path: Path to the AnimationPlayer node
        keep_state: If true, animated properties remain at current values

    Returns: Success confirmation

    Examples:
        - "Stop the Player's animation"
        - "Stop animation but keep the current pose"
        - "Reset animation state completely"

    Note: Use keep_state=true for seamless transitions between animations.
    """
    params = {"player_path": player_path, "keep_state": keep_state}
    state_note = " (keeping current state)" if keep_state else ""
    return await _execute_command(
        "stop_animation",
        params,
        lambda data: {"message": f"⏹️ Stopped animation on {player_path}{state_note}"},
        f"Failed to stop animation on {player_path}"
    )

@app.tool()
async def seek_animation(player_path: str, seconds: float, update: bool = False, update_only: bool = False) -> str:
    """Seek to a specific time in the current animation.

    This tool allows precise positioning within an animation timeline, essential for
    creating cutscenes, synchronization points, and interactive animation control.

    Args:
        player_path: Path to the AnimationPlayer node
        seconds: Time position in seconds to seek to
        update: If true, update animated properties immediately
        update_only: If true, only update properties without changing playback position

    Returns: Success confirmation with seek position

    Examples:
        - "Seek to 2.5 seconds in the animation"
        - "Jump to the middle of the current animation"
        - "Update animation properties without changing position"

    Note: Useful for creating precise animation synchronization and debugging.
    """
    params = {
        "player_path": player_path,
        "seconds": seconds,
        "update": update,
        "update_only": update_only
    }
    update_note = " (updating properties)" if update else ""
    return await _execute_command(
        "seek_animation",
        params,
        lambda data: {"message": f"🎯 Seeked to {seconds}s in animation on {player_path}{update_note}"},
        f"Failed to seek animation on {player_path}"
    )

@app.tool()
async def queue_animation(player_path: str, animation_name: str) -> str:
    """Add an animation to the playback queue for sequential playing.

    This tool enables creating animation sequences where animations play one after another
    automatically. Perfect for creating complex animation chains like attack combos,
    character state transitions, or cinematic sequences.

    Args:
        player_path: Path to the AnimationPlayer node
        animation_name: Name of animation to add to queue

    Returns: Success confirmation

    Examples:
        - "Queue the 'attack2' animation after 'attack1'"
        - "Add 'land' animation to play after 'jump'"
        - "Create an animation sequence for character actions"

    Note: Animations play in queue order after the current animation finishes.
    """
    params = {"player_path": player_path, "animation_name": animation_name}
    return await _execute_command(
        "queue_animation",
        params,
        lambda data: {"message": f"📋 Queued animation '{animation_name}' on {player_path}"},
        f"Failed to queue animation '{animation_name}' on {player_path}"
    )

@app.tool()
async def clear_animation_queue(player_path: str) -> str:
    """Clear all animations from the playback queue.

    This tool removes all queued animations, stopping the automatic sequence playback.
    Useful for interrupting animation chains or resetting animation state.

    Args:
        player_path: Path to the AnimationPlayer node

    Returns: Success confirmation

    Examples:
        - "Clear the animation queue to stop the sequence"
        - "Cancel pending animations"
        - "Reset animation playback state"

    Note: Current playing animation continues unaffected.
    """
    return await _execute_command(
        "clear_animation_queue",
        {"player_path": player_path},
        lambda data: {"message": f"🧹 Cleared animation queue on {player_path}"},
        f"Failed to clear animation queue on {player_path}"
    )

@app.tool()
async def get_animation_state(player_path: str) -> str:
    """Get comprehensive animation playback state information.

    This tool provides real-time information about animation playback including
    current position, playback speed, queue status, and section information.
    Essential for debugging animation timing and synchronization issues.

    Args:
        player_path: Path to the AnimationPlayer node

    Returns: Detailed animation state information

    Examples:
        - "Check current animation position and speed"
        - "See what's in the animation queue"
        - "Get playback state for debugging"

    Note: Returns live playback information for real-time monitoring.
    """
    return await _execute_command(
        "get_animation_state",
        {"player_path": player_path},
        lambda data: data,
        f"Failed to get animation state for {player_path}"
    )

@app.tool()
async def set_animation_speed(player_path: str, speed: float) -> str:
    """Set the playback speed multiplier for animations.

    This tool allows dynamic speed control for creating slow-motion effects,
    fast-forward sequences, or synchronized timing adjustments.

    Args:
        player_path: Path to the AnimationPlayer node
        speed: Speed multiplier (1.0 = normal, 2.0 = double speed, 0.5 = half speed)

    Returns: Success confirmation with speed setting

    Examples:
        - "Slow down animation to half speed for dramatic effect"
        - "Speed up animation to 3x for fast-forward"
        - "Reset animation speed to normal"

    Note: Speed changes are applied immediately to current and future animations.
    """
    params = {"player_path": player_path, "speed": speed}
    return await _execute_command(
        "set_animation_speed",
        params,
        lambda data: {"message": f"⚡ Set animation speed to {speed}x on {player_path}"},
        f"Failed to set animation speed on {player_path}"
    )

@app.tool()
async def create_animation_library(player_path: str, library_name: str) -> str:
    """Create a new AnimationLibrary for organizing animations.

    This tool creates animation libraries for better organization of complex animation
    sets. Libraries allow grouping related animations and managing large animation
    collections efficiently.

    Args:
        player_path: Path to the AnimationPlayer node
        library_name: Name for the new animation library

    Returns: Success confirmation

    Examples:
        - "Create a 'Combat' animation library for battle animations"
        - "Add a 'Movement' library for locomotion animations"
        - "Create a 'UI' library for interface animations"

    Note: Libraries help organize animations in complex projects.
    """
    params = {"player_path": player_path, "library_name": library_name}
    return await _execute_command(
        "create_animation_library",
        params,
        lambda data: {"message": f"📚 Created animation library '{library_name}' on {player_path}"},
        f"Failed to create animation library '{library_name}' on {player_path}"
    )

@app.tool()
async def load_animation_library(player_path: str, library_path: str, library_name: str = "") -> str:
    """Load an AnimationLibrary from a file.

    This tool loads pre-created animation libraries from disk, allowing reuse
    of animation assets across different scenes and projects.

    Args:
        player_path: Path to the AnimationPlayer node
        library_path: Path to the animation library file (.res)
        library_name: Name to assign to the loaded library (optional)

    Returns: Success confirmation

    Examples:
        - "Load character animations from res://animations/character_animations.res"
        - "Import shared animation library for UI elements"
        - "Load animation library with custom name"

    Note: Libraries must be saved AnimationLibrary resources.
    """
    params = {
        "player_path": player_path,
        "library_path": library_path,
        "library_name": library_name
    }
    return await _execute_command(
        "load_animation_library",
        params,
        lambda data: {"message": f"📂 Loaded animation library from {library_path} on {player_path}"},
        f"Failed to load animation library from {library_path}"
    )

@app.tool()
async def add_animation_to_library(player_path: str, library_name: str, animation_name: str, animation_data: Dict[str, Any]) -> str:
    """Add an animation to an existing library.

    This tool allows building up animation libraries programmatically by adding
    individual animations to organized collections.

    Args:
        player_path: Path to the AnimationPlayer node
        library_name: Name of the target animation library
        animation_name: Name for the animation in the library
        animation_data: Dictionary containing animation properties:
            - length: Animation duration in seconds (optional, default 1.0)
            - loop_mode: Looping behavior (optional, 0=Linear, 1=Clamp, 2=PingPong)
            - step: Keyframe step size (optional)
            - tracks: Array of track data (optional), each containing:
                - type: Track type (0-8, see add_animation_track for details)
                - path: Node path for the track
                - keyframes: Array of keyframe data with 'time' and 'value' fields

    Returns: Success confirmation

    Examples:
        - "Add the 'walk' animation to the Movement library"
        - "Import animation into the Combat library"
        - "Add custom animation to existing library"

    Note: Animation data is converted to a proper Animation resource.
    """
    params = {
        "player_path": player_path,
        "library_name": library_name,
        "animation_name": animation_name,
        "animation_data": animation_data
    }
    return await _execute_command(
        "add_animation_to_library",
        params,
        lambda data: {"message": f"➕ Added animation '{animation_name}' to library '{library_name}'"},
        f"Failed to add animation to library '{library_name}'"
    )

@app.tool()
async def remove_animation_from_library(player_path: str, library_name: str, animation_name: str) -> str:
    """Remove an animation from an animation library.

    This tool allows cleaning up animation libraries by removing unused or
    outdated animations from organized collections.

    Args:
        player_path: Path to the AnimationPlayer node
        library_name: Name of the animation library
        animation_name: Name of animation to remove

    Returns: Success confirmation

    Examples:
        - "Remove the old 'walk' animation from Movement library"
        - "Clean up unused animations from library"
        - "Remove animation from Combat library"

    Note: Only removes the animation from the library, not from disk.
    """
    params = {
        "player_path": player_path,
        "library_name": library_name,
        "animation_name": animation_name
    }
    return await _execute_command(
        "remove_animation_from_library",
        params,
        lambda data: {"message": f"➖ Removed animation '{animation_name}' from library '{library_name}'"},
        f"Failed to remove animation from library '{library_name}'"
    )

@app.tool()
async def get_animation_library_list(player_path: str) -> str:
    """Get a list of all animations in all libraries.

    This tool provides an overview of all available animations organized by library,
    helping with animation management and debugging.

    Args:
        player_path: Path to the AnimationPlayer node

    Returns: Dictionary of libraries with their animations

    Examples:
        - "List all available animations"
        - "See what's in each animation library"
        - "Get overview of animation organization"

    Note: Shows both built-in animations and library-organized animations.
    """
    return await _execute_command(
        "get_animation_library_list",
        {"player_path": player_path},
        lambda data: data,
        f"Failed to get animation library list for {player_path}"
    )

@app.tool()
async def rename_animation(player_path: str, old_name: str, new_name: str) -> str:
    """Rename an animation in an AnimationPlayer.

    This tool allows reorganizing animation names for better clarity and consistency
    in animation management.

    Args:
        player_path: Path to the AnimationPlayer node
        old_name: Current name of the animation
        new_name: New name for the animation

    Returns: Success confirmation

    Examples:
        - "Rename 'walk_cycle' to 'walking'"
        - "Change animation name for consistency"
        - "Update animation naming scheme"

    Note: Renaming affects all references to this animation.
    """
    params = {
        "player_path": player_path,
        "old_name": old_name,
        "new_name": new_name
    }
    return await _execute_command(
        "rename_animation",
        params,
        lambda data: {"message": f"📝 Renamed animation '{old_name}' to '{new_name}' on {player_path}"},
        f"Failed to rename animation '{old_name}' on {player_path}"
    )

@app.tool()
async def create_animation(player_path: str, animation_name: str, length: float = 1.0) -> str:
    """Create a new empty animation resource.

    This tool creates blank animation resources that can then be populated with
    keyframes and tracks. Essential for building custom animations programmatically.

    Args:
        player_path: Path to the AnimationPlayer node
        animation_name: Name for the new animation
        length: Duration of the animation in seconds

    Returns: Success confirmation with animation details

    Examples:
        - "Create a 2-second 'jump' animation"
        - "Make a new 'attack' animation with 1.5 second duration"
        - "Create empty animation for procedural keyframe insertion"

    Note: Animation is created empty - use other tools to add tracks and keyframes.
    """
    params = {
        "player_path": player_path,
        "animation_name": animation_name,
        "length": length
    }
    return await _execute_command(
        "create_animation",
        params,
        lambda data: {"message": f"🎬 Created animation '{animation_name}' ({length}s) on {player_path}"},
        f"Failed to create animation '{animation_name}' on {player_path}"
    )

@app.tool()
async def get_animation_info(player_path: str, animation_name: str) -> str:
    """Get detailed information about a specific animation.

    This tool provides comprehensive metadata about animations including duration,
    loop mode, track count, and configuration settings.

    Args:
        player_path: Path to the AnimationPlayer node
        animation_name: Name of the animation to inspect

    Returns: Animation metadata and configuration

    Examples:
        - "Check the duration and loop mode of 'walk' animation"
        - "Get track count for 'complex_animation'"
        - "Inspect animation properties for debugging"

    Note: Provides static animation properties, not playback state.
    """
    params = {"player_path": player_path, "animation_name": animation_name}
    return await _execute_command(
        "get_animation_info",
        params,
        lambda data: data,
        f"Failed to get animation info for '{animation_name}' on {player_path}"
    )

@app.tool()
async def set_animation_property(player_path: str, animation_name: str, property_name: str, value: Any) -> str:
    """Set properties of an animation like length, loop mode, and step size.

    This tool allows configuration of animation behavior including timing,
    looping, and interpolation settings.

    Args:
        player_path: Path to the AnimationPlayer node
        animation_name: Name of the animation to modify
        property_name: Property to change:
                      - "length": Animation duration in seconds (float)
                      - "loop_mode": Looping behavior (0=Linear, 1=Clamp, 2=PingPong)
                      - "step": Keyframe step size for snapping (float)
        value: New value for the property

    Returns: Success confirmation

    Examples:
        - "Set animation length to 3.0 seconds"
        - "Enable looping for the walk cycle"
        - "Set step size to 0.1 for precise keyframing"

    Note: Property changes affect animation playback behavior.
    """
    params = {
        "player_path": player_path,
        "animation_name": animation_name,
        "property_name": property_name,
        "value": value
    }
    return await _execute_command(
        "set_animation_property",
        params,
        lambda data: {"message": f"⚙️ Set {property_name} = {value} on animation '{animation_name}'"},
        f"Failed to set {property_name} on animation '{animation_name}'"
    )

@app.tool()
async def add_property_track(player_path: str, animation_name: str, property_path: str, initial_value: Any) -> str:
    """Add a property track to an animation with automatic track type selection.

    This tool automatically chooses the correct track type (VALUE or METHOD) based on the property value type.
    For numeric properties that can be interpolated, it uses VALUE tracks. For complex types like bool,
    Vector2, Color, etc., it uses METHOD tracks to call setter methods.

    Args:
        player_path: Path to the AnimationPlayer node
        animation_name: Name of the animation to modify
        property_path: Property path in format "NodePath:PropertyName" (e.g., "Sprite:position", ".:visible")
        initial_value: Initial value for the property to determine track type:
                      - float/int: Uses VALUE track for interpolation
                      - bool: Uses METHOD track with set_visible() etc.
                      - Vector2: Uses METHOD track with set_position() etc.
                      - Color: Uses METHOD track with set_modulate() etc.

    Returns: Success confirmation with track details

    Examples:
        - "Add track for Sprite position with initial value [100, 200]"
        - "Add track for node visibility with initial value true"
        - "Add track for modulate color with initial value [1, 0, 0, 1]"

    Note: The track type is automatically chosen based on the value type for optimal animation support.
    """
    # Determine track type and path based on value type and property name
    if ":" in property_path:
        node_path, prop_name = property_path.split(":", 1)
    else:
        node_path = property_path
        prop_name = ""

    # Check for boolean properties by name or value type
    boolean_properties = ["visible", "enabled", "active", "disabled", "hidden"]
    is_boolean_prop = prop_name in boolean_properties or isinstance(initial_value, bool)

    if isinstance(initial_value, (int, float)) and not is_boolean_prop:
        # Numeric values use VALUE tracks
        track_type = 4  # TYPE_VALUE
        track_path = property_path
        method_data = None
    elif is_boolean_prop or isinstance(initial_value, bool):
        # Boolean values use METHOD tracks
        track_type = 5  # TYPE_METHOD
        track_path = node_path
        # Create setter method name
        setter_name = f"set_{prop_name}" if prop_name else "set_visible"
        method_data = {"method": setter_name, "args": [initial_value]}
    elif isinstance(initial_value, list):
        # Array values (Vector2, Color, etc.) use METHOD tracks
        track_type = 5  # TYPE_METHOD
        track_path = node_path
        # Create setter method name
        setter_name = f"set_{prop_name}" if prop_name else "set_position"
        method_data = {"method": setter_name, "args": [initial_value]}
    else:
        # Fallback to VALUE track for other types
        track_type = 4  # TYPE_VALUE
        track_path = property_path
        method_data = None

    params = {
        "player_path": player_path,
        "animation_name": animation_name,
        "track_type": track_type,
        "track_path": track_path
    }

    def success_formatter(data):
        track_type_name = "VALUE" if track_type == 4 else "METHOD"
        return {"message": f"➕ Added {track_type_name} track for '{property_path}' to animation '{animation_name}' (index {data.get('track_index', 'unknown')})"}

    result = await _execute_command(
        "add_animation_track",
        params,
        success_formatter,
        f"Failed to add track to animation '{animation_name}'"
    )

    # If this is a METHOD track, we need to store the method data for later use
    if track_type == 5 and method_data:
        # Store method data in a way that insert_keyframe can access it
        # For now, we'll handle this in the insert_keyframe function
        pass

    return result

@app.tool()
async def add_animation_track(player_path: str, animation_name: str, track_type: int, track_path: str) -> str:
    """Add a new track to an animation for keyframe data.

    This tool creates animation tracks that define which properties are animated
    and how they change over time. Different track types support different data types.

    Args:
        player_path: Path to the AnimationPlayer node
        animation_name: Name of the animation to modify
        track_type: Type of track to create:
                    - 0: POSITION_3D (Vector3 position)
                    - 1: ROTATION_3D (Quaternion rotation)
                    - 2: SCALE_3D (Vector3 scale)
                    - 3: BLEND_SHAPE (float blend shape weight)
                    - 4: VALUE (generic property animation - use for 2D transforms)
                    - Note: Godot 4.5 has no dedicated 2D transform tracks. Use VALUE tracks for 2D position/rotation/scale with paths like "Sprite:position", "Sprite:rotation", "Sprite:scale"
        track_path: Node path for the track (e.g., "Sprite:position" for 2D, "Node3D" for 3D transforms, ".:rotation" for self)

    Returns: Success confirmation with track index

    Examples:
        - "Add position track for Sprite movement"
        - "Create rotation track for character turning"
        - "Add property track for modulate color changes"

    Note: Track path format: "NodePath:PropertyName"
    """
    params = {
        "player_path": player_path,
        "animation_name": animation_name,
        "track_type": track_type,
        "track_path": track_path
    }
    return await _execute_command(
        "add_animation_track",
        params,
        lambda data: {"message": f"➕ Added {track_type} track '{track_path}' to animation '{animation_name}' (index {data.get('track_index', 'unknown')})"},
        f"Failed to add track to animation '{animation_name}'"
    )

@app.tool()
async def remove_animation_track(player_path: str, animation_name: str, track_idx: int) -> str:
    """Remove a track from an animation.

    This tool allows cleaning up animation tracks that are no longer needed,
    helping maintain clean and efficient animations.

    Args:
        player_path: Path to the AnimationPlayer node
        animation_name: Name of the animation to modify
        track_idx: Index of the track to remove

    Returns: Success confirmation

    Examples:
        - "Remove unused track from animation"
        - "Clean up animation by removing track at index 2"
        - "Delete track that was added by mistake"

    Note: Removing tracks also removes all their keyframes.
    """
    params = {
        "player_path": player_path,
        "animation_name": animation_name,
        "track_idx": track_idx
    }
    return await _execute_command(
        "remove_animation_track",
        params,
        lambda data: {"message": f"➖ Removed track {track_idx} from animation '{animation_name}'"},
        f"Failed to remove track {track_idx} from animation '{animation_name}'"
    )

@app.tool()
async def insert_keyframe(player_path: str, animation_name: str, track_idx: int, time: float, value: Any) -> str:
    """Insert a keyframe at a specific time in an animation track.

    This tool creates keyframes that define how properties change over time.
    Keyframes are the building blocks of animations, specifying values at specific moments.

    Args:
        player_path: Path to the AnimationPlayer node
        animation_name: Name of the animation to modify
        track_idx: Index of the track to add keyframe to
        time: Time position in seconds for the keyframe
        value: Value for the keyframe (type depends on track type):
               - For VALUE tracks: numeric values (float/int), Vector2 [x,y], Color [r,g,b,a], etc.
               - For METHOD tracks: the raw value (bool, Vector2, Color, etc.) - method format is handled automatically

    Returns: Success confirmation with keyframe index

    Examples:
        - "Add position keyframe at 1.0s for Sprite movement"
        - "Insert rotation keyframe at 0.5s for character turn"
        - "Create color keyframe at 2.0s for modulate change"
        - "Add visibility keyframe at 1.0s with value true"

    Note: The Godot addon automatically handles value formatting based on track type.
    """
    params = {
        "player_path": player_path,
        "animation_name": animation_name,
        "track_idx": track_idx,
        "time": time,
        "value": value
    }
    return await _execute_command(
        "insert_keyframe",
        params,
        lambda data: {"message": f"🔑 Inserted keyframe at {time}s in track {track_idx} of '{animation_name}' (index {data.get('key_index', 'unknown')})"},
        f"Failed to insert keyframe in animation '{animation_name}'"
    )

@app.tool()
async def remove_keyframe(player_path: str, animation_name: str, track_idx: int, key_idx: int) -> str:
    """Remove a keyframe from an animation track.

    This tool allows precise editing of animation curves by removing specific
    keyframes that are no longer needed.

    Args:
        player_path: Path to the AnimationPlayer node
        animation_name: Name of the animation to modify
        track_idx: Index of the track containing the keyframe
        key_idx: Index of the keyframe to remove

    Returns: Success confirmation

    Examples:
        - "Remove unwanted keyframe from position track"
        - "Delete keyframe at index 3 in rotation track"
        - "Clean up animation curve by removing keyframe"

    Note: Removing keyframes changes the animation curve interpolation.
    """
    params = {
        "player_path": player_path,
        "animation_name": animation_name,
        "track_idx": track_idx,
        "key_idx": key_idx
    }
    return await _execute_command(
        "remove_keyframe",
        params,
        lambda data: {"message": f"🗑️ Removed keyframe {key_idx} from track {track_idx} in '{animation_name}'"},
        f"Failed to remove keyframe {key_idx} from animation '{animation_name}'"
    )

@app.tool()
async def get_animation_tracks(player_path: str, animation_name: str) -> str:
    """Get detailed information about all tracks in an animation.

    This tool provides comprehensive track information including types, paths,
    and keyframe counts for debugging and inspection.

    Args:
        player_path: Path to the AnimationPlayer node
        animation_name: Name of the animation to inspect

    Returns: Array of track information objects

    Examples:
        - "List all tracks in the 'complex_animation'"
        - "Check track types and paths for debugging"
        - "Get track overview for animation analysis"

    Note: Useful for understanding animation structure and debugging.
    """
    params = {"player_path": player_path, "animation_name": animation_name}
    return await _execute_command(
        "get_animation_tracks",
        params,
        lambda data: data,
        f"Failed to get tracks for animation '{animation_name}' on {player_path}"
    )

@app.tool()
async def set_blend_time(player_path: str, animation_from: str, animation_to: str, blend_time: float) -> str:
    """Set blend time between two animations for smooth transitions.

    This tool controls how smoothly animations transition between each other,
    essential for creating professional-looking animation sequences.

    Args:
        player_path: Path to the AnimationPlayer node
        animation_from: Name of the source animation
        animation_to: Name of the target animation
        blend_time: Blend duration in seconds

    Returns: Success confirmation

    Examples:
        - "Set 0.5s blend time between 'walk' and 'run'"
        - "Create smooth transition from 'idle' to 'jump'"
        - "Adjust blend time for better animation flow"

    Note: Blend times improve animation quality by preventing jarring transitions.
    """
    params = {
        "player_path": player_path,
        "animation_from": animation_from,
        "animation_to": animation_to,
        "blend_time": blend_time
    }
    return await _execute_command(
        "set_blend_time",
        params,
        lambda data: {"message": f"🔄 Set blend time {blend_time}s between '{animation_from}' → '{animation_to}'"},
        f"Failed to set blend time between '{animation_from}' and '{animation_to}'"
    )

@app.tool()
async def get_blend_time(player_path: str, animation_from: str, animation_to: str) -> str:
    """Get the blend time between two animations.

    This tool retrieves the current blend duration setting for inspecting
    transition smoothness between animations.

    Args:
        player_path: Path to the AnimationPlayer node
        animation_from: Name of the source animation
        animation_to: Name of the target animation

    Returns: Blend time in seconds

    Examples:
        - "Check blend time between walk and run animations"
        - "Get transition duration for debugging"
        - "Verify blend settings for animation sequence"

    Note: Returns the configured blend time, not actual transition time.
    """
    params = {
        "player_path": player_path,
        "animation_from": animation_from,
        "animation_to": animation_to
    }
    return await _execute_command(
        "get_blend_time",
        params,
        lambda data: {"blend_time": data.get("blend_time", 0.0), "message": f"Blend time: {data.get('blend_time', 0.0)}s"},
        f"Failed to get blend time between '{animation_from}' and '{animation_to}'"
    )

@app.tool()
async def set_animation_next(player_path: str, animation_from: str, animation_to: str) -> str:
    """Set the next animation to play automatically after another.

    This tool creates automatic animation sequences where one animation
    triggers the next, perfect for creating complex animation chains.

    Args:
        player_path: Path to the AnimationPlayer node
        animation_from: Name of the animation that triggers the next
        animation_to: Name of the animation to play next

    Returns: Success confirmation

    Examples:
        - "Set 'run' to play after 'walk'"
        - "Chain 'attack1' to 'attack2' for combo system"
        - "Create automatic animation sequence"

    Note: The next animation plays automatically when the first finishes.
    """
    params = {
        "player_path": player_path,
        "animation_from": animation_from,
        "animation_to": animation_to
    }
    return await _execute_command(
        "set_animation_next",
        params,
        lambda data: {"message": f"➡️ Set '{animation_to}' to play after '{animation_from}'"},
        f"Failed to set next animation for '{animation_from}'"
    )

@app.tool()
async def get_animation_next(player_path: str, animation_from: str) -> str:
    """Get the next animation queued to play after another.

    This tool reveals animation sequence chains for debugging and inspection
    of automatic animation transitions.

    Args:
        player_path: Path to the AnimationPlayer node
        animation_from: Name of the animation to check

    Returns: Name of the next animation or empty string

    Examples:
        - "Check what plays after the 'walk' animation"
        - "See the animation sequence chain"
        - "Debug automatic animation transitions"

    Note: Returns the configured next animation, not what's currently queued.
    """
    params = {"player_path": player_path, "animation_from": animation_from}
    return await _execute_command(
        "get_animation_next",
        params,
        lambda data: {"next_animation": data.get("next_animation", ""), "message": f"Next animation: '{data.get('next_animation', 'none')}'"},
        f"Failed to get next animation for '{animation_from}'"
    )

@app.tool()
async def set_animation_section(player_path: str, start_time: float = -1, end_time: float = -1) -> str:
    """Set the playback section for the current animation.

    This tool allows playing only a portion of an animation, useful for creating
    variations or focusing on specific parts of longer animations.

    Args:
        player_path: Path to the AnimationPlayer node
        start_time: Start time in seconds (-1 for animation start)
        end_time: End time in seconds (-1 for animation end)

    Returns: Success confirmation

    Examples:
        - "Play only the first second of the animation"
        - "Set section from 1.0s to 3.0s"
        - "Create animation variation by playing subsection"

    Note: Section affects all subsequent playback until changed.
    """
    params = {
        "player_path": player_path,
        "start_time": start_time,
        "end_time": end_time
    }
    section_desc = f"{start_time}s to {end_time}s" if start_time >= 0 and end_time >= 0 else "full animation"
    return await _execute_command(
        "set_animation_section",
        params,
        lambda data: {"message": f"🎬 Set playback section to {section_desc} on {player_path}"},
        f"Failed to set animation section on {player_path}"
    )

@app.tool()
async def set_animation_section_with_markers(player_path: str, start_marker: str = "", end_marker: str = "") -> str:
    """Set playback section using named markers in the animation.

    This tool uses animation markers for precise section control, allowing
    semantic naming of important animation points.

    Args:
        player_path: Path to the AnimationPlayer node
        start_marker: Name of the start marker (empty for animation start)
        end_marker: Name of the end marker (empty for animation end)

    Returns: Success confirmation

    Examples:
        - "Play from 'anticipation' to 'action' markers"
        - "Set section between 'start' and 'end' markers"
        - "Use named markers for precise animation control"

    Note: Markers must exist in the animation for this to work.
    """
    params = {
        "player_path": player_path,
        "start_marker": start_marker,
        "end_marker": end_marker
    }
    marker_desc = f"'{start_marker}' to '{end_marker}'" if start_marker and end_marker else "full animation"
    return await _execute_command(
        "set_animation_section_with_markers",
        params,
        lambda data: {"message": f"🏷️ Set playback section to {marker_desc} on {player_path}"},
        f"Failed to set animation section with markers on {player_path}"
    )

@app.tool()
async def add_animation_marker(player_path: str, animation_name: str, marker_name: str, time: float) -> str:
    """Add a named marker to an animation at a specific time.

    This tool creates semantic markers for important animation points,
    enabling precise control and better animation organization.

    Args:
        player_path: Path to the AnimationPlayer node
        animation_name: Name of the animation to modify
        marker_name: Name for the marker
        time: Time position in seconds for the marker

    Returns: Success confirmation

    Examples:
        - "Add 'anticipation' marker at 0.5 seconds"
        - "Mark the 'impact' point at 1.2 seconds"
        - "Create 'recovery' marker at animation end"

    Note: Markers enable semantic animation control and sectioning.
    """
    params = {
        "player_path": player_path,
        "animation_name": animation_name,
        "marker_name": marker_name,
        "time": time
    }
    return await _execute_command(
        "add_animation_marker",
        params,
        lambda data: {"message": f"🏷️ Added marker '{marker_name}' at {time}s to '{animation_name}'"},
        f"Failed to add marker '{marker_name}' to animation '{animation_name}'"
    )

@app.tool()
async def remove_animation_marker(player_path: str, animation_name: str, marker_name: str) -> str:
    """Remove a named marker from an animation.

    This tool cleans up animation markers that are no longer needed,
    maintaining clean and organized animation definitions.

    Args:
        player_path: Path to the AnimationPlayer node
        animation_name: Name of the animation to modify
        marker_name: Name of the marker to remove

    Returns: Success confirmation

    Examples:
        - "Remove the unused 'temp' marker"
        - "Clean up old animation markers"
        - "Delete marker that was added by mistake"

    Note: Removing markers may affect sections that reference them.
    """
    params = {
        "player_path": player_path,
        "animation_name": animation_name,
        "marker_name": marker_name
    }
    return await _execute_command(
        "remove_animation_marker",
        params,
        lambda data: {"message": f"🗑️ Removed marker '{marker_name}' from '{animation_name}'"},
        f"Failed to remove marker '{marker_name}' from animation '{animation_name}'"
    )


async def ensure_godot_connection():
    """Ensure we have a connection to Godot, connecting if necessary"""
    if not godot.connected:
        logger.info("Connecting to Godot...")
        if not await godot.connect():
            raise ConnectionError("Failed to connect to Godot. Make sure Godot is running with the MCP addon enabled.")
        logger.info("Connected to Godot successfully")
    return True

if __name__ == "__main__":
    # Let FastMCP handle everything
    app.run()