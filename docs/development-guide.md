# Development Guide

## Getting Started with Development

### Development Environment Setup

#### Prerequisites
```bash
# Python development environment
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Development dependencies
pip install pytest black flake8 mypy

# Godot development
# Download Godot 4.5 from https://godotengine.org/download
```

#### IDE Configuration
```json
// VS Code settings.json
{
  "python.defaultInterpreterPath": "./venv/bin/python",
  "python.linting.enabled": true,
  "python.linting.flake8Enabled": true,
  "python.formatting.provider": "black",
  "godot_tools.editor_path": "/path/to/Godot_v4.5-stable"
}
```

### Project Structure Overview

```
godot-mcp-node-control/
├── godot-mcp-server.py          # Main MCP server
├── requirements.txt              # Python dependencies
├── test_mcp_server.py          # Integration tests
├── godot-addon/                  # Godot plugin package
│   ├── project.godot            # Demo project
│   ├── demo_scene.tscn          # Test scene
│   ├── demo_script.gd           # Test script
│   └── addons/godot_mcp_node_control/
│       ├── plugin.cfg           # Plugin configuration
│       ├── mcp_node_control.gd  # Main plugin script
│       └── node_utils.gd        # Node operations
└── docs/                        # Documentation
    ├── project-overview.md
    ├── architecture.md
    ├── technology-stack.md
    ├── api-reference.md
    ├── installation-setup.md
    ├── development-guide.md
    └── changelog.md
```

## Development Workflow

### 1. Making Changes

#### Server-Side Changes
```bash
# Edit server code
vim godot-mcp-server.py

# Run syntax check
python -c "import ast; ast.parse(open('godot-mcp-server.py').read())"

# Run tests
python test_mcp_server.py

# Format code
black godot-mcp-server.py
```

#### Addon-Side Changes
```bash
# Edit addon code
vim godot-addon/addons/godot_mcp_node_control/mcp_node_control.gd

# Reload in Godot
# Press F5 in Godot Editor or Project → Reload Current Project

# Check Godot console for errors
```

### 2. Adding New Tools

#### Step 1: Define Tool in Server
```python
@app.tool()
async def new_tool_name(param1: str, param2: int = 0) -> str:
    """Tool description with examples and parameter details.

    Args:
        param1: Description of first parameter
        param2: Description of second parameter (optional)

    Returns: Description of return value

    Examples:
    - "Example usage description"
    """
    try:
        command = {
            "type": "new_tool_name",
            "params": {
                "param1": param1,
                "param2": param2
            }
        }
        response = await godot.send_command(command)

        if response.get("status") == "success":
            return f"✅ Success message with {param1}"
        else:
            return f"❌ Failed: {response.get('error', 'Unknown error')}"

    except Exception as e:
        return f"❌ Error: {str(e)}"
```

#### Step 2: Implement Handler in Addon
```gdscript
func _handle_new_tool_name(params: Dictionary) -> Dictionary:
    var param1 = params.get("param1", "")
    var param2 = params.get("param2", 0)

    # Validation
    if param1.is_empty():
        return {"error": "param1 is required"}

    # Implementation
    var result = node_utils.new_tool_implementation(param1, param2)
    if result.has("error"):
        _log_error("new_tool_name failed: %s" % result.error)
        return result

    return {"status": "success", "data": result}
```

#### Step 3: Add to Command Router
```gdscript
func _handle_command(command: Dictionary) -> Dictionary:
    var cmd_type = command.get("type", "")
    var params = command.get("params", {})

    match cmd_type:
        # ... existing commands
        "new_tool_name": return _handle_new_tool_name(params)
        # ... other commands
```

#### Step 4: Implement Utility Function
```gdscript
# In node_utils.gd
func new_tool_implementation(param1: String, param2: int) -> Dictionary:
    # Implementation logic
    var error_msg = _validate_editor_access()
    if error_msg:
        return {"error": error_msg}

    # Tool logic here
    return {"result": "success"}
```

### 3. Testing New Features

#### Unit Tests
```python
# test_new_feature.py
import pytest
from godot_mcp_server import app

def test_new_tool():
    # Test implementation
    pass
```

#### Integration Tests
```python
# In test_mcp_server.py
async def test_new_tool_integration():
    # Test with actual Godot connection
    pass
```

#### Manual Testing
```bash
# Start server in debug mode
LOG_LEVEL=DEBUG python godot-mcp-server.py

# Test in Godot
# Open demo scene and try new tool
```

## Code Quality Standards

### Python Code Style
```bash
# Formatting
black *.py
isort *.py

# Linting
flake8 *.py --max-line-length=100

# Type checking
mypy *.py --ignore-missing-imports
```

### GDScript Code Style
```gdscript
# Use consistent naming
var my_variable: int = 0
const MY_CONSTANT := 42

func my_function(param: String) -> void:
    # Function body
    pass

# Use type hints
func process(delta: float) -> void:
    # Process logic
    pass
```

### Documentation Standards

#### Function Documentation
```python
def function_name(param1: Type, param2: Type = default) -> ReturnType:
    """One-line description of function.

    Detailed description explaining what the function does,
    its parameters, return values, and any side effects.

    Args:
        param1: Description of param1
        param2: Description of param2 (optional)

    Returns:
        Description of return value

    Raises:
        ExceptionType: When this exception is raised

    Examples:
        >>> function_name("example", 42)
        "result"
    """
```

#### Tool Documentation
```python
@app.tool()
async def tool_name(param: str) -> str:
    """Clear, actionable description for LLM understanding.

    Explain what the tool does, when to use it, and provide
    concrete examples of natural language commands.

    Args:
        param: Parameter description with expected formats

    Returns: Expected output format and content

    Examples:
    - "Natural language example 1"
    - "Natural language example 2"
    """
```

## Debugging and Troubleshooting

### Server-Side Debugging
```python
# Enable debug logging
import logging
logging.basicConfig(level=logging.DEBUG)

# Add debug prints
logger.debug(f"Processing command: {command}")
logger.debug(f"Response: {response}")
```

### Godot-Side Debugging
```gdscript
# Enable debug mode
var debug_mode := true

# Add debug prints
func _debug_print(message: String) -> void:
    if debug_mode:
        print("[MCP Debug] ", message)

# Log errors
func _log_error(message: String) -> void:
    push_error("[MCP Error] " + message)
    error_log.append({
        "timestamp": Time.get_datetime_string_from_system(),
        "message": message
    })
```

### Common Debugging Scenarios

#### Connection Issues
```bash
# Check WebSocket connection
netstat -tlnp | grep 9080

# Test WebSocket manually
python -c "
import websockets
import asyncio

async def test():
    try:
        async with websockets.connect('ws://localhost:9080') as ws:
            print('Connection successful')
    except Exception as e:
        print(f'Connection failed: {e}')

asyncio.run(test())
"
```

#### Command Failures
```python
# Add detailed error logging
try:
    response = await godot.send_command(command)
    logger.debug(f"Command response: {response}")
except Exception as e:
    logger.error(f"Command failed: {e}")
    logger.error(f"Command was: {command}")
```

#### Performance Issues
```python
# Add timing measurements
import time

start_time = time.time()
response = await godot.send_command(command)
end_time = time.time()

logger.debug(f"Command took {end_time - start_time:.3f} seconds")
```

## Performance Optimization

### Memory Management
```python
# Limit log sizes
MAX_ERROR_LOG_SIZE = 100

def add_error_log(error: str) -> None:
    error_log.append(error)
    if len(error_log) > MAX_ERROR_LOG_SIZE:
        error_log.pop(0)
```

### Connection Pooling
```python
# Reuse WebSocket connections
class ConnectionPool:
    def __init__(self):
        self.connections = {}

    async def get_connection(self, host: str, port: int):
        key = f"{host}:{port}"
        if key not in self.connections:
            self.connections[key] = await self._create_connection(host, port)
        return self.connections[key]
```

### Batch Operations
```python
# Group related operations
async def batch_create_nodes(nodes: List[Dict]) -> List[Dict]:
    """Create multiple nodes efficiently"""
    results = []
    for node_data in nodes:
        result = await create_node(**node_data)
        results.append(result)
    return results
```

## Contributing Guidelines

### Pull Request Process
1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** changes (`git commit -m 'Add amazing feature'`)
4. **Push** to branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

### Commit Message Format
```
type(scope): description

[optional body]

[optional footer]
```

**Types**:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `style`: Code style changes
- `refactor`: Code refactoring
- `test`: Testing
- `chore`: Maintenance

### Code Review Checklist
- [ ] Code follows style guidelines
- [ ] Tests added for new functionality
- [ ] Documentation updated
- [ ] No breaking changes without discussion
- [ ] Performance impact assessed
- [ ] Security implications reviewed

## Advanced Development Topics

### Custom Node Types
```gdscript
# Support for custom node classes
func create_custom_node(class_name: String, script_path: String) -> Dictionary:
    var node = ClassDB.instantiate("Node")
    var script = load(script_path)
    node.set_script(script)
    return {"node": node}
```

### Signal System Extensions
```gdscript
# Advanced signal connections
func connect_signals_batch(connections: Array) -> Dictionary:
    for connection in connections:
        var result = connect_signal(
            connection.from_path,
            connection.signal_name,
            connection.to_path,
            connection.method_name
        )
        if result.has("error"):
            return result
    return {"status": "success"}
```

### Resource Management
```gdscript
# Handle Godot resources
func load_and_assign_texture(node_path: String, texture_path: String) -> Dictionary:
    var texture = load(texture_path)
    if not texture:
        return {"error": "Failed to load texture"}

    var node = get_node(node_path)
    node.texture = texture
    return {"status": "success"}
```

### Animation Integration
```gdscript
# Basic animation support
func create_animation_player(node_path: String, animation_name: String) -> Dictionary:
    var anim_player = AnimationPlayer.new()
    var node = get_node(node_path)
    node.add_child(anim_player)

    var animation = Animation.new()
    anim_player.add_animation(animation_name, animation)
    return {"animation_player_path": str(anim_player.get_path())}
```

## Testing Strategies

### Unit Testing
```python
import pytest
from godot_mcp_server import GodotConnection

class MockWebSocket:
    async def send(self, message):
        self.last_message = message

    async def recv(self):
        return '{"status": "success", "data": {}}'

@pytest.fixture
async def mock_connection():
    connection = GodotConnection()
    connection.websocket = MockWebSocket()
    connection.connected = True
    return connection
```

### Integration Testing
```python
# Full system tests
async def test_complete_workflow():
    # Start Godot (would need automation)
    # Start MCP server
    # Execute test scenario
    # Verify results
    pass
```

### Performance Testing
```python
import time
import asyncio

async def benchmark_tool_execution(tool_func, iterations=100):
    times = []
    for _ in range(iterations):
        start = time.time()
        await tool_func()
        end = time.time()
        times.append(end - start)

    avg_time = sum(times) / len(times)
    print(f"Average execution time: {avg_time:.3f}s")
    return avg_time
```

## Deployment and Distribution

### Packaging for Distribution
```bash
# Create Python package
python setup.py sdist bdist_wheel

# Create Godot addon package
zip -r godot-addon.zip godot-addon/
```

### Version Management
```python
# Version configuration
VERSION = "1.0.0"
BUILD_DATE = "2025-09-25"

def get_version_info():
    return {
        "version": VERSION,
        "build_date": BUILD_DATE,
        "godot_version": "4.5",
        "python_version": "3.10+"
    }
```

### Release Process
1. Update version numbers
2. Run full test suite
3. Update changelog
4. Create release tags
5. Build distribution packages
6. Publish to repositories

---

This development guide provides comprehensive information for contributing to and extending the Godot MCP Node Control project, ensuring consistent code quality and development practices.