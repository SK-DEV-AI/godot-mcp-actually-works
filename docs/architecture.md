# Architecture & Design

## System Architecture

### High-Level Overview

```
┌─────────────────┐    WebSocket    ┌─────────────────┐
│   AI Assistant  │◄──────────────►│  MCP Server     │
│  (Claude/Copilot│   JSON-RPC     │ (Python/FastMCP)│
└─────────────────┘                └─────────────────┘
                                         │
                                         │ HTTP WebSocket
                                         ▼
┌─────────────────┐    Internal API    ┌─────────────────┐
│   Godot Addon   │◄─────────────────►│ Godot Engine    │
│ (GDScript Plugin│   Godot Signals    │   4.5 Editor    │
└─────────────────┘                    └─────────────────┘
```

### Component Breakdown

## 1. MCP Server Component (`godot-mcp-server.py`)

### Purpose
The MCP server acts as the bridge between AI assistants and the Godot engine, translating natural language commands into structured operations.

### Key Classes

#### `GodotConnection`
```python
class GodotConnection:
    """Handles WebSocket connection to Godot addon"""

    def __init__(self, host: str = "localhost", port: int = 9080):
        self.host = host
        self.port = port
        self.websocket: Optional[websockets.WebSocketServerProtocol] = None
        self.connected = False

    async def connect(self) -> bool:
        """Establish WebSocket connection to Godot"""

    async def send_command(self, command: Dict[str, Any]) -> Dict[str, Any]:
        """Send command and await response"""
```

#### FastMCP Integration
```python
app = FastMCP(
    name="Godot Node Control MCP Server",
    description="Complete Godot Engine scene manipulation toolkit"
)

@app.tool()
async def create_node(node_type: str, parent_path: str = ".", node_name: str = "") -> str:
    """Create a new node in the Godot scene"""
```

### Tool Categories (80 Total Tools)

#### Scene Management Tools (9 tools)
- `get_scene_tree()` - Complete scene hierarchy inspection
- `run_scene()` / `stop_scene()` - Scene execution control
- `get_current_scene_info()` - Scene metadata and information
- `open_scene()` / `save_scene()` / `save_scene_as()` - Scene file operations
- `create_new_scene()` - Create new scenes with root node types
- `instantiate_scene()` - Load and instantiate scene files
- `pack_scene_from_node()` - Create reusable scene files from nodes

#### Node Lifecycle Tools (6 tools)
- `create_node()` - Node creation with type validation
- `delete_node()` - Safe node removal
- `move_node()` - Reparenting and renaming
- `duplicate_node()` - Node cloning
- `find_nodes_by_type()` - Type-based node searching
- `get_node_children()` - Hierarchy traversal

#### Property & Transform Tools (4 tools)
- `get_node_properties()` - Property inspection
- `set_node_property()` - Property modification
- `set_node_transform()` - Position/rotation/scale control
- `set_node_visibility()` - Visibility toggling

#### Signal & Method Tools (4 tools)
- `connect_signal()` - Event connection setup
- `disconnect_signal()` - Event disconnection
- `get_node_signals()` - Signal introspection
- `get_node_methods()` - Method discovery
- `call_node_method()` - Dynamic method execution

#### Script Management Tools (11 tools)
- `add_script_to_node()` - GDScript attachment
- `get_script_content()` / `set_script_content()` - Script source manipulation
- `validate_script()` - GDScript syntax validation
- `create_script_file()` / `load_script_file()` - Script file management
- `get_script_variables()` / `set_script_variable()` - Exported variable control
- `get_script_functions()` - Function introspection
- `attach_script_to_node()` / `detach_script_from_node()` - Script file linking

#### Resource Management Tools (6 tools)
- `create_resource()` / `load_resource()` / `save_resource()` - Resource lifecycle
- `get_resource_dependencies()` - Dependency analysis
- `list_directory()` - File system exploration
- `get_resource_metadata()` - Resource information

#### Animation System Tools (32 tools)
- Complete animation player management and control
- Keyframe and track manipulation
- Animation library organization
- Playback control and sequencing

#### Advanced Tools (8 tools)
- `change_collision_shape()` - Collision shape modification
- `get_debug_info()` - System diagnostics
- `check_connection()` - Connection health monitoring

## 2. Godot Addon Component (`godot-addon/`)

### Plugin Structure
```
godot-addon/
├── project.godot              # Demo project file
├── demo_scene.tscn           # Example scene
├── demo_script.gd            # Example script
└── addons/
    └── godot_mcp_node_control/
        ├── plugin.cfg         # Plugin configuration
        ├── mcp_node_control.gd # Main plugin script
        └── node_utils.gd      # Node operation utilities
```

### Main Plugin Class (`mcp_node_control.gd`)

```gdscript
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
```

#### Key Methods

##### Connection Management
```gdscript
func _enter_tree() -> void:
    # Initialize WebSocket server
    var err = tcp_server.listen(port)
    if err == OK:
        print("MCP Node Control server listening on port ", port)
        set_process(true)

func _process(_delta: float) -> void:
    # Handle new connections and process messages
    if tcp_server.is_connection_available():
        var tcp = tcp_server.take_connection()
        # ... WebSocket upgrade and client setup
```

##### Command Processing
```gdscript
func _handle_command(client_id: int, command: Dictionary) -> void:
    var response = {}

    if command.has("type"):
        var cmd_type = command.get("type")
        var params = command.get("params", {})

        match cmd_type:
            "get_scene_tree": response = _handle_get_scene_tree()
            "create_node": response = _handle_create_node(params)
            # ... other command handlers

    _send_to_client(client_id, response)
```

### Node Utilities Class (`node_utils.gd`)

#### Core Operations

##### Scene Inspection
```gdscript
func get_scene_tree() -> Dictionary:
    """Get complete scene hierarchy"""
    var root = editor_interface.get_edited_scene_root()
    if not root:
        return {"error": "No scene is currently open"}

    var tree_data = _build_tree_recursive(root)
    return tree_data
```

##### Node Creation
```gdscript
func create_node(node_type: String, parent_path: String, node_name: String) -> Dictionary:
    """Create node with validation and undo support"""
    var error_msg = _validate_editor_access()
    if error_msg:
        return {"error": error_msg}

    # Type validation
    if not ClassDB.class_exists(node_type):
        return {"error": "Invalid node type: %s" % node_type}

    # Create and configure node
    var node = ClassDB.instantiate(node_type)
    if node_name.is_empty():
        node_name = _generate_unique_name(node_type)
    node.name = node_name

    # Add to scene with undo support
    var parent = _get_node_by_path(parent_path)
    if not parent:
        return {"error": "Parent node not found: %s" % parent_path}

    parent.add_child(node)
    node.owner = root

    return {"node_path": str(node.get_path()), "node_name": node.name}
```

##### Property Management
```gdscript
func set_node_property(node_path: String, property_name: String, value) -> Dictionary:
    """Set node property with validation"""
    var error_msg = _validate_editor_access()
    if error_msg:
        return {"error": error_msg}

    var node = _get_node_by_path(node_path)
    if not node:
        return {"error": "Node not found: %s" % node_path}

    # Validate property exists
    if not node.get_property_list().any(func(p): return p.name == property_name):
        return {"error": "Property '%s' not found on node" % property_name}

    # Set with undo support
    var undo_redo = editor_interface.get_editor_undo_redo()
    undo_redo.create_action("Set Property: %s.%s" % [node_path, property_name])

    var old_value = node.get(property_name)
    undo_redo.add_do_property(node, property_name, value)
    undo_redo.add_undo_property(node, property_name, old_value)
    undo_redo.commit_action()

    return {"success": true}
```

## 3. Communication Protocol

### WebSocket + JSON-RPC 2.0

#### Message Format
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "create_node",
    "arguments": {
      "node_type": "Sprite2D",
      "parent_path": ".",
      "node_name": "PlayerSprite"
    }
  }
}
```

#### Response Format
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "status": "success",
    "data": {
      "node_path": "/root/PlayerSprite",
      "node_name": "PlayerSprite"
    }
  }
}
```

### Error Handling

#### Error Response Format
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "error": {
    "code": -32602,
    "message": "Invalid params",
    "data": {
      "details": "node_type is required and must be a valid Godot node class"
    }
  }
}
```

#### Error Codes
- `-32700`: Parse error
- `-32600`: Invalid request
- `-32601`: Method not found
- `-32602`: Invalid params
- `-32603`: Internal error
- `-32000`: Godot-specific errors

## 4. Context Engineering

### LLM Optimization Features

#### Rich Tool Descriptions
Each tool includes:
- Clear purpose statement
- Parameter specifications with types
- Usage examples
- Godot-specific context
- Error conditions

#### Progressive Disclosure
- Basic usage patterns first
- Advanced features explained
- Common pitfalls highlighted
- Best practices included

#### Ground Truth Anchoring
- Real Godot node types and properties
- Actual error messages from engine
- Proper path formats
- Valid signal and method names

### Example Enhanced Tool Description

```python
@app.tool()
async def create_node(node_type: str, parent_path: str = ".", node_name: str = "") -> str:
    """Create a new node in the Godot scene with full undo support.

    This tool creates any valid Godot node type and adds it to the scene hierarchy.
    The node will be properly owned by the scene and can be immediately manipulated.

    Args:
        node_type: Godot node class name (e.g., 'Node2D', 'Sprite2D', 'CharacterBody2D',
                   'Label', 'Button', 'Area2D', 'CollisionShape2D', etc.)
        parent_path: Path to parent node (default: "." for scene root)
                     Use paths like "Player", "UI/CanvasLayer", or "Enemies/Enemy1"
        node_name: Custom name for the node (optional - auto-generated if empty)

    Returns: Success message with the created node's path

    Examples:
    - "Create a Sprite2D node as a child of the Player node"
    - "Add a CollisionShape2D to my Area2D node"
    - "Create a new Label node in the UI canvas"
    - "Add a CharacterBody2D for the player character"

    Note: All changes are undoable in Godot's editor.
    """
```

## 5. Security & Reliability

### Connection Security
- Local-only operation (no network exposure)
- WebSocket over localhost only
- No authentication required (development tool)

### Error Recovery
- Automatic reconnection attempts
- Command timeout handling
- Graceful degradation on errors
- Comprehensive logging

### Performance Optimization
- Asynchronous command processing
- Minimal memory footprint
- Efficient node traversal algorithms
- Connection pooling for multiple clients

## 6. Testing Strategy

### Unit Tests
- Individual tool functionality
- Error condition handling
- Parameter validation
- Godot API integration

### Integration Tests
- End-to-end command execution
- WebSocket communication
- Scene state verification
- Undo/redo functionality

### Performance Tests
- Large scene handling
- Concurrent operations
- Memory usage monitoring
- Response time validation

---

This architecture ensures reliable, performant, and maintainable integration between AI assistants and the Godot game engine, providing a solid foundation for AI-assisted game development workflows.