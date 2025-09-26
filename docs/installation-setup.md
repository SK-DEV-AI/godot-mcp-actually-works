# Installation & Setup Guide

## Prerequisites

### System Requirements

#### Operating System
- **Linux**: Ubuntu 20.04+, Fedora 35+, or equivalent
- **macOS**: 12.0+ (Monterey or later)
- **Windows**: 10/11 with WSL2 recommended for development

#### Software Dependencies
- **Python**: 3.10 or higher
- **Godot Engine**: 4.5.x (latest stable)
- **Git**: For cloning repositories
- **MCP Client**: Claude Desktop, VS Code with MCP extension, or compatible client

### Hardware Requirements
- **RAM**: 4GB minimum, 8GB recommended
- **Storage**: 2GB free space for Godot and project files
- **Network**: Local WebSocket communication only

## Installation Steps

### Step 1: Clone the Repository

```bash
# Clone the Godot MCP Node Control repository
git clone https://github.com/your-username/godot-mcp-node-control.git
cd godot-mcp-node-control
```

### Step 2: Install Python Dependencies

```bash
# Create virtual environment (recommended)
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install required packages
pip install -r requirements.txt
```

**Requirements Breakdown**:
- `fastmcp`: MCP server framework
- `websockets`: WebSocket communication
- `asyncio`: Asynchronous operations
- Additional dependencies for error handling and logging

### Step 3: Set Up Godot Addon

#### Option A: Copy to Existing Project
```bash
# Copy addon to your Godot project
cp -r godot-addon/addons/godot_mcp_node_control /path/to/your/godot/project/addons/
```

#### Option B: Use Demo Project
```bash
# Use the included demo project
cd godot-addon
# Open project.godot in Godot Editor
```

### Step 4: Enable the Plugin

1. **Open Godot Editor**
   - Launch Godot 4.5
   - Open your project (or the demo project)

2. **Access Plugin Settings**
   - Go to `Project` → `Project Settings`
   - Navigate to `Plugins` tab

3. **Enable MCP Plugin**
   - Find "Godot MCP Node Control" in the plugin list
   - Check the "Enable" checkbox
   - Click "OK" to save settings

4. **Verify Installation**
   - Check console for: `"MCP Node Control server listening on port 9080"`
   - Plugin should appear in the bottom panel

### Step 5: Configure MCP Client

#### Claude Desktop (macOS)

**Location**: `~/Library/Application Support/Claude/claude_desktop_config.json`

```json
{
  "mcpServers": {
    "godot-node-control": {
      "command": "python",
      "args": ["/path/to/godot-mcp-node-control/godot-mcp-server.py"],
      "env": {
        "GODOT_HOST": "localhost",
        "GODOT_PORT": "9080"
      }
    }
  }
}
```

#### VS Code with MCP Extension

**Settings JSON**:
```json
{
  "mcp.server.godot-node-control": {
    "command": "python",
    "args": ["/path/to/godot-mcp-node-control/godot-mcp-server.py"],
    "env": {
      "GODOT_HOST": "localhost",
      "GODOT_PORT": "9080"
    }
  }
}
```

#### Other MCP Clients

**Generic Configuration**:
```json
{
  "name": "godot-node-control",
  "command": "python",
  "args": ["/absolute/path/to/godot-mcp-server.py"],
  "env": {
    "GODOT_HOST": "localhost",
    "GODOT_PORT": "9080",
    "PYTHONPATH": "/path/to/project"
  }
}
```

## Configuration Options

### Environment Variables

#### Server Configuration
```bash
# Godot connection settings
GODOT_HOST=localhost          # Godot WebSocket host
GODOT_PORT=9080              # Godot WebSocket port
GODOT_TIMEOUT=30             # Connection timeout in seconds

# Server settings
MCP_SERVER_NAME="Godot Node Control"  # Server display name
MCP_SERVER_VERSION="1.0.0"           # Server version
LOG_LEVEL=INFO                        # Logging verbosity
```

#### Godot Addon Configuration
```gdscript
# In godot-addon/addons/godot_mcp_node_control/mcp_node_control.gd
var port := 9080              # WebSocket port
var debug_mode := true        # Enable debug logging
var max_error_log_size := 100 # Maximum error log entries
```

### Advanced Configuration

#### Custom Port Configuration
If port 9080 is in use, configure a different port:

```bash
# Set environment variable
export GODOT_PORT=9081

# Update Godot addon
# Edit godot-addon/addons/godot_mcp_node_control/mcp_node_control.gd
var port := 9081
```

#### Multiple Godot Projects
For multiple projects, run separate MCP servers:

```json
{
  "mcpServers": {
    "godot-project-1": {
      "command": "python",
      "args": ["/path/to/godot-mcp-server.py"],
      "env": { "GODOT_PORT": "9080" }
    },
    "godot-project-2": {
      "command": "python",
      "args": ["/path/to/godot-mcp-server.py"],
      "env": { "GODOT_PORT": "9081" }
    }
  }
}
```

## Testing the Installation

### Step 1: Start Godot
1. Open your Godot project
2. Ensure the MCP plugin is enabled
3. Check console for connection message

### Step 2: Start MCP Server
```bash
# Activate virtual environment
source venv/bin/activate

# Start the server
python godot-mcp-server.py
```

**Expected Output**:
```
INFO: Connecting to Godot at ws://localhost:9080
INFO: Connected to Godot successfully
INFO: Starting MCP server...
INFO: MCP server running on stdio
```

### Step 3: Test Connection
Use your MCP client to test basic functionality:

**Test Commands**:
- "Get the current scene tree structure"
- "Create a new Node2D called TestNode"
- "Get debug information"

**Expected Results**:
- Scene tree should show current scene structure
- New node should appear in Godot scene tree
- Debug info should show system status

## Troubleshooting

### Common Issues

#### 1. Connection Failed
**Error**: `"Failed to connect to Godot"`

**Solutions**:
```bash
# Check if Godot is running
ps aux | grep godot

# Verify port is available
netstat -tlnp | grep 9080

# Check firewall settings
sudo ufw status
```

#### 2. Plugin Not Loading
**Error**: Plugin doesn't appear in Godot

**Solutions**:
- Ensure addon files are in correct directory structure
- Check `plugin.cfg` file exists and is valid
- Restart Godot Editor
- Check Godot console for plugin loading errors

#### 3. Import Errors
**Error**: `ModuleNotFoundError` in Python

**Solutions**:
```bash
# Reinstall dependencies
pip install -r requirements.txt --force-reinstall

# Check Python version
python --version  # Should be 3.10+

# Update pip
pip install --upgrade pip
```

#### 4. WebSocket Errors
**Error**: WebSocket connection refused

**Solutions**:
- Verify Godot plugin is enabled
- Check port configuration matches
- Ensure no firewall blocking localhost connections
- Try different port if 9080 is in use

### Debug Mode

Enable detailed logging for troubleshooting:

```bash
# Server-side logging
export LOG_LEVEL=DEBUG
python godot-mcp-server.py

# Godot-side logging
# Edit mcp_node_control.gd
var debug_mode := true
```

### Performance Tuning

#### Memory Optimization
```gdscript
# In Godot addon - reduce log size for memory
var max_error_log_size := 50

# Clear logs periodically
func _clear_old_logs():
    if error_log.size() > max_error_log_size:
        error_log = error_log.slice(-max_error_log_size)
```

#### Connection Optimization
```python
# In server - adjust timeouts
GODOT_TIMEOUT=60
GODOT_RECONNECT_ATTEMPTS=5
```

## Development Setup

### Running Tests
```bash
# Run unit tests
python -m pytest tests/

# Run integration tests
python test_mcp_server.py
```

### Development Workflow
```bash
# Make changes to server
# Test with
python godot-mcp-server.py

# Make changes to addon
# Reload in Godot Editor (F5)

# Check logs
tail -f /tmp/godot_mcp_server.log
```

### Building for Distribution
```bash
# Create distributable package
python setup.py sdist bdist_wheel

# Or use modern build
pip install build
python -m build
```

## Security Considerations

### Local Development Only
- **No Network Exposure**: Only listens on localhost
- **No Authentication**: Designed for development environments
- **No External Access**: WebSocket connections are local only

### Production Deployment
⚠️ **Not Recommended**: This tool is designed for local development only.

For production use cases:
- Implement proper authentication
- Add network security measures
- Use secure WebSocket (WSS)
- Add rate limiting and validation

## Support and Community

### Getting Help
- **Documentation**: Check this guide and API reference
- **Issues**: Report bugs on GitHub
- **Discussions**: Join community discussions
- **Logs**: Enable debug mode and share logs

### Contributing
- **Code**: Follow the contribution guidelines
- **Testing**: Add tests for new features
- **Documentation**: Update docs for changes
- **Reviews**: Participate in code reviews

---

This installation guide ensures a smooth setup process for the Godot MCP Node Control system, enabling AI-assisted Godot development workflows.