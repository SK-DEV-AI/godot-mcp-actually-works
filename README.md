# Godot MCP Node Control

A modern Model Context Protocol (MCP) server for controlling Godot Engine nodes, built with FastMCP and designed for Godot 4.5. This project provides AI assistants with powerful tools to manipulate Godot scenes, nodes, and properties through natural language commands.

## Features

- **Full Node Control**: Create, modify, delete, and inspect nodes in Godot scenes
- **Property Management**: Get and set node properties safely
- **Script Attachment**: Add GDScript code to nodes dynamically
- **Scene Management**: Run and stop scenes from MCP commands
- **Signal System**: Connect and disconnect node signals for event-driven programming
- **Transform Control**: Precise position, rotation, and scale manipulation
- **Method Calling**: Execute node methods with parameters
- **Robust Error Handling**: Comprehensive error logging and debug information relay
- **Godot 4.5 Optimized**: Built specifically for the latest Godot features
- **Clean Architecture**: Modular, maintainable codebase following best practices
- **Exact Error Transparency**: LLMs receive precise Godot error messages for intelligent debugging

## Architecture

The system consists of two main components:

1. **MCP Server** (`godot-mcp-server.py`): Built with FastMCP, exposes tools to AI assistants
2. **Godot Addon** (`godot-addon/`): WebSocket server that executes node operations in Godot

Communication happens via WebSocket between the Python MCP server and the GDScript addon.

## 📊 **Current Status & Roadmap**

### ✅ **Phase 1 Complete: Node Control System**
- **42 Tools Implemented**: Complete node manipulation and scene management toolkit
- **Error Transparency**: Exact Godot error messages relayed to LLMs
- **Production Ready**: Tested, documented, and polished
- **Architecture Proven**: Modular design ready for expansion

### 🚀 **Next: Script Management System**
The next major expansion focuses on **Script & Resource Management** - enabling LLMs to create, modify, and debug GDScript code dynamically.

### 📋 **Full Development Roadmap**
See [`docs/roadmap.md`](docs/roadmap.md) for the complete expansion plan covering:
- Script & Resource Management
- Scene Management System
- Animation & Physics Systems
- UI & Audio Systems
- Advanced Features (Multiplayer, Shaders, Build System)

### 🔄 **Development Workflow**
For detailed instructions on adding new tool categories, see [`docs/workflow.md`](docs/workflow.md) - our proven 5-phase process established during Node Control implementation.

## Installation

### Prerequisites

- Python 3.10+
- Godot Engine 4.5+
- An MCP-compatible client (Claude Desktop, etc.)

### 1. Install Python Dependencies

```bash
pip install -r requirements.txt
```

### 2. Set Up Godot Addon

1. Copy the `godot-addon/addons/godot_mcp_node_control/` folder to your Godot project's `addons/` directory
2. Open your Godot project
3. Go to Project → Project Settings → Plugins
4. Enable the "Godot MCP Node Control" plugin

### 3. Configure MCP Client

For Claude Desktop, add to `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "godot-node-control": {
      "command": "python",
      "args": ["/path/to/godot-mcp-server.py"],
      "env": {
        "GODOT_HOST": "localhost",
        "GODOT_PORT": "9080"
      }
    }
  }
}
```

## Usage

Once set up, you can use natural language commands with your AI assistant:

### Basic Node Operations
- "Create a new Sprite2D node in the scene"
- "Set the position of the Player node to (100, 200)"
- "Make the Enemy node invisible"
- "Duplicate the Coin node and name it Coin2"

### Advanced Node Control
- "Move the Player node to be a child of the GameWorld node"
- "Find all Sprite2D nodes in the scene"
- "Connect the 'pressed' signal of Button to the '_on_button_pressed' method of Main"
- "Get all available methods on the Player node"

### Scene Management
- "Get the current scene tree structure"
- "Run the current scene"
- "Stop the running scene"

### Scripting & Properties
- "Add a movement script to the Player node"
- "Set the scale of the Background to (2, 2)"
- "Call the 'jump' method on the Player node"

### Debugging
- "Show me the debug information and any errors"
- "Get all signals available on the Button node"

## Available Tools

### Scene Management
- `get_scene_tree()` - Get complete scene hierarchy with node types and paths
- `run_scene()` - Start scene execution in Godot
- `stop_scene()` - Stop the currently running scene

### Node Operations
- `create_node(node_type, parent_path, node_name)` - Create new nodes with type validation
- `delete_node(node_path)` - Remove nodes from the scene
- `move_node(node_path, new_parent_path, new_name)` - Move nodes to new parents and rename
- `duplicate_node(node_path, new_name)` - Create copies of existing nodes
- `find_nodes_by_type(node_type, search_root)` - Find all nodes of a specific type
- `get_node_children(node_path, recursive)` - Get child nodes (direct or all descendants)

### Node Properties & Transform
- `get_node_properties(node_path)` - Get all properties of a node
- `set_node_property(node_path, property_name, value)` - Set individual node properties
- `set_node_transform(node_path, position, rotation, scale)` - Set position, rotation, and scale
- `set_node_visibility(node_path, visible)` - Control node visibility

### Signals & Methods
- `connect_signal(from_node_path, signal_name, to_node_path, method_name)` - Connect signals between nodes
- `disconnect_signal(from_node_path, signal_name, to_node_path, method_name)` - Disconnect signal connections
- `get_node_signals(node_path)` - List all signals available on a node
- `get_node_methods(node_path)` - List all methods available on a node
- `call_node_method(node_path, method_name, args)` - Call methods on nodes with arguments

### Scripting
- `add_script_to_node(node_path, script_content)` - Attach GDScript code to nodes

### Debugging & Diagnostics
- `get_debug_info()` - Get comprehensive debug information, error logs, and system status

## Development

### Project Structure

```
godot-mcp-node-control/
├── godot-mcp-server.py          # FastMCP server implementation
├── requirements.txt              # Python dependencies
├── test_mcp_server.py           # Test suite for MCP server
├── godot-addon/                  # Godot addon package
│   ├── project.godot            # Demo project file
│   ├── demo_scene.tscn          # Example scene
│   ├── demo_script.gd           # Example script
│   └── addons/
│       └── godot_mcp_node_control/
│           ├── plugin.cfg       # Plugin configuration
│           ├── mcp_node_control.gd  # Main plugin script
│           └── node_utils.gd    # Node operation utilities
├── docs/                        # Comprehensive documentation
│   ├── README.md                # Documentation index
│   ├── project-overview.md      # Project goals and features
│   ├── architecture.md          # System architecture details
│   ├── technology-stack.md      # Tech stack and dependencies
│   ├── api-reference.md         # Complete API documentation
│   ├── installation-setup.md    # Detailed setup instructions
│   ├── development-guide.md     # Development guidelines
│   ├── research-topics.md       # Research findings and analysis
│   ├── roadmap.md               # Development roadmap and priorities
│   ├── workflow.md              # Step-by-step development workflow
│   └── changelog.md             # Version history and changes
└── README.md                    # This file (project overview)
```

### Building from Source

1. Clone this repository
2. Install dependencies: `pip install -r requirements.txt`
3. Copy the addon to your Godot project
4. Enable the plugin in Godot
5. Run the MCP server: `python godot-mcp-server.py`

## Error Handling

The system includes comprehensive error handling:

- **Connection Errors**: Automatic reconnection attempts
- **Node Operation Failures**: Detailed error messages with context
- **Script Compilation**: Validation before attachment
- **Property Validation**: Type checking and existence validation
- **Debug Logging**: Timestamped error logs with full context

## Security

This is designed for **local use only**. No authentication or network security measures are implemented, as it's intended for development environments.

## Contributing

### 🚀 **Adding New Tool Categories**

We have an established **5-phase development workflow** for adding new tool categories. Follow [`docs/workflow.md`](docs/workflow.md) for step-by-step guidance.

**Quick Start for Contributors:**
1. **Choose a Category**: See [`docs/roadmap.md`](docs/roadmap.md) for priority systems
2. **Follow the Workflow**: Research → Design → Implement → Test → Document
3. **Use Established Patterns**: Copy the Node Control implementation patterns
4. **Ensure Error Transparency**: All Godot errors must be relayed exactly to LLMs

### **Development Guidelines**

- **Code Quality**: Follow GDScript and Python best practices
- **Error Handling**: Implement comprehensive error handling with exact Godot error relay
- **Documentation**: Update all relevant docs for new features
- **Testing**: Add unit and integration tests for new functionality
- **Architecture**: Maintain the modular design established in Node Control

### **Current Development Focus**

**🔥 Next Priority: Script Management System**
- Create, modify, and debug GDScript code
- Resource management and asset handling
- Script compilation validation
- Dynamic script attachment and modification

See [`docs/roadmap.md`](docs/roadmap.md) for the complete development roadmap.

## License

MIT License - see LICENSE file for details.

## Acknowledgments

- Built with [FastMCP](https://github.com/jlowin/fastmcp)
- Inspired by the [Model Context Protocol](https://modelcontextprotocol.io)
- Designed for [Godot Engine](https://godotengine.org)