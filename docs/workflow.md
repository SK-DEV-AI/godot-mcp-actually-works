# 🔄 **Godot MCP Server Development Workflow**

## Overview

This document outlines the exact workflow we established for implementing the Node Control tools, providing a repeatable process for adding new tool categories to the Godot MCP server. This workflow ensures consistency, quality, and maintainability across all tool implementations.

## 📋 **Workflow Phases**

### **Phase 1: Research & Analysis** (2-3 days)

#### **1.1 Godot API Research**
```bash
# Research target system APIs using multiple sources:
- Godot Documentation: https://docs.godotengine.org/
- Godot Source Code: https://github.com/godotengine/godot
- Existing Implementations: Study similar systems
- Editor Interface: EditorPlugin, EditorInterface APIs
```

**Key Research Questions:**
- What Godot classes/APIs are available for the target system?
- What are the common use cases and workflows?
- What are the error conditions and edge cases?
- How does the editor interface work with this system?

#### **1.2 Existing Codebase Analysis**
```bash
# Analyze current implementation patterns:
- Review node_utils.gd for error handling patterns
- Study MCP server tool implementations
- Examine WebSocket communication patterns
- Review documentation structure
```

#### **1.3 Tool Specification Design**
**For each tool, define:**
- **Function signature** with parameter types
- **Return value structure** (success/error format)
- **Error conditions** and specific error messages
- **Undo/redo requirements**
- **Performance considerations**

### **Phase 2: Godot Addon Implementation** (2-3 days)

#### **2.1 Create Utility Module**
```gdscript
# Create new utility file (e.g., script_utils.gd, scene_utils.gd)
extends Node

var editor_interface = null

func _ready() -> void:
    if Engine.is_editor_hint():
        editor_interface = EditorInterface

# Implement utility functions with consistent patterns:
# - _validate_editor_access() for editor validation
# - Specific error messages with context
# - Undo/redo integration where applicable
# - Type validation and safety checks
```

**Implementation Pattern:**
```gdscript
func example_tool(param1: String, param2: int) -> Dictionary:
    var error_msg = _validate_editor_access()
    if error_msg:
        return {"error": error_msg}

    # Validate parameters
    if param1.is_empty():
        return {"error": "Parameter 'param1' cannot be empty"}

    # Implement logic with error handling
    var result = perform_operation(param1, param2)
    if result != OK:
        return {"error": "Operation failed: %s" % error_string(result)}

    return {"success": true, "data": result_data}
```

#### **2.2 Error Message Standards**
**Follow these exact error message patterns:**
- `"Invalid parameter: %s"` - for validation failures
- `"Resource not found: %s"` - for missing resources
- `"Operation failed: %s"` - for system failures
- `"Not supported: %s"` - for unsupported operations
- `"Access denied: %s"` - for permission issues

#### **2.3 Integration with Main Plugin**
```gdscript
# In mcp_node_control.gd, add the new utility:
var script_utils = null  # Add this line

func _enter_tree() -> void:
    # ... existing code ...
    script_utils = preload("res://addons/godot_mcp_node_control/script_utils.gd").new()
    script_utils.name = "ScriptUtils"
    add_child(script_utils)
```

### **Phase 3: MCP Server Tool Implementation** (1-2 days)

#### **3.1 Tool Registration Pattern**
```python
@app.tool()
async def example_tool_name(param1: str, param2: int) -> str:
    """Rich tool description with:
    - What the tool does
    - Parameter descriptions with types
    - Return value information
    - Usage examples
    - Important notes about behavior
    """
    try:
        command = {
            "type": "example_tool_name",
            "params": {
                "param1": param1,
                "param2": param2
            }
        }
        response = await godot.send_command(command)

        if response.get("status") == "success":
            # Format success response with emoji and context
            return f"✅ Successfully completed: {response.get('data', {})}"
        else:
            # Relay exact Godot error message
            return f"❌ Failed to complete: {response.get('error', 'Unknown error')}"

    except Exception as e:
        return f"❌ Failed to complete: {str(e)}"
```

#### **3.2 Parameter Validation**
**Client-side validation before sending to Godot:**
```python
# Validate required parameters
if not param1 or not isinstance(param1, str):
    raise ValueError("param1 must be a non-empty string")

# Validate optional parameters with defaults
param2 = param2 or "default_value"
```

#### **3.3 Response Formatting Standards**
**Success Messages:**
- ✅ `Successfully created: {resource_name}`
- 📝 `Successfully attached: {script_name}`
- 🔗 `Successfully connected: {signal_name}`

**Error Messages:**
- ❌ `Failed to create {type}: {godot_error}`
- ❌ `Failed to set {property}: {godot_error}`
- ❌ `Failed to find {resource}: {godot_error}`

### **Phase 4: Testing & Validation** (1 day)

#### **4.1 Unit Testing Pattern**
```python
# Create test file: test_new_tools.py
import asyncio
import pytest
from godot_mcp_server import app, godot

@pytest.mark.asyncio
async def test_example_tool():
    # Test success case
    result = await app.tools["example_tool"].func(param1="test", param2=42)
    assert "✅ Successfully" in result

    # Test error case
    result = await app.tools["example_tool"].func(param1="", param2=42)
    assert "❌ Failed" in result
    assert "cannot be empty" in result  # Verify exact error message
```

#### **4.2 Integration Testing**
```bash
# Test with actual Godot editor:
1. Start Godot with addon enabled
2. Run MCP server
3. Test each tool manually
4. Verify error messages match Godot editor
5. Test undo/redo functionality
```

#### **4.3 Documentation Testing**
```bash
# Verify documentation:
1. All tools have descriptions
2. Parameter types are documented
3. Examples are provided
4. Error conditions are covered
```

### **Phase 5: Documentation & Polish** (0.5 days)

#### **5.1 Update API Reference**
```markdown
## New Tool Category

### example_tool_name
**Description:** What the tool does

**Parameters:**
- `param1` (string): Description of param1
- `param2` (integer): Description of param2

**Returns:** Success message or error details

**Examples:**
- "Example usage description"
- "Another example with different parameters"

**Notes:**
- Important behavior notes
- Limitations or requirements
```

#### **5.2 Update Changelog**
```markdown
## [Version X.Y.Z] - YYYY-MM-DD

### Added
- **New Tool Category**: Complete implementation with X tools
  - `tool_name_1`: Description
  - `tool_name_2`: Description
  - `tool_name_3`: Description

### Technical Details
- Added `new_utils.gd` with utility functions
- Enhanced error handling for category operations
- Improved parameter validation
```

## 🎯 **Quality Assurance Checklist**

### **Code Quality**
- [ ] All functions have proper type hints
- [ ] Error messages are specific and actionable
- [ ] No hardcoded strings in error handling
- [ ] Consistent naming conventions
- [ ] Proper resource cleanup

### **Error Handling**
- [ ] All Godot errors are relayed exactly
- [ ] No generic "Unknown error" messages
- [ ] Client-side validation prevents invalid calls
- [ ] Network errors are handled gracefully
- [ ] Connection recovery works properly

### **Documentation**
- [ ] All tools have rich descriptions
- [ ] Parameter types and descriptions documented
- [ ] Usage examples provided
- [ ] Error conditions explained
- [ ] Performance considerations noted

### **Testing**
- [ ] Unit tests for all tools
- [ ] Integration tests with Godot
- [ ] Error condition testing
- [ ] Edge case validation
- [ ] Performance testing

## 📊 **Time Estimates by Category**

| Category | Research | Implementation | Testing | Documentation | Total |
|----------|----------|----------------|---------|---------------|-------|
| **Simple Tools** (3-5 tools) | 1 day | 1 day | 0.5 day | 0.5 day | 3 days |
| **Complex Tools** (8-12 tools) | 2 days | 2 days | 1 day | 0.5 day | 5.5 days |
| **System Integration** | 3 days | 3 days | 1.5 days | 1 day | 8.5 days |

## 🚀 **Next Steps for New Categories**

### **Immediate Priority: Script Management**
1. **Research**: GDScript API, EditorScript, ResourceLoader
2. **Design**: 8-10 script manipulation tools
3. **Implement**: `script_utils.gd` with compilation validation
4. **Integrate**: MCP server tools with rich descriptions
5. **Test**: Complex script scenarios and error handling

### **Following Categories** (in priority order):
1. **Scene Management** - Scene lifecycle, instantiation, export
2. **Animation System** - AnimationPlayer, AnimationTree, keyframes
3. **UI System** - Control nodes, themes, layouts
4. **Physics System** - Collision shapes, rigidbodies, joints
5. **Audio System** - Audio players, buses, effects

## 🔧 **Development Tools & Resources**

### **Essential Research Sources**
- **Godot Docs**: https://docs.godotengine.org/en/stable/
- **Godot Source**: https://github.com/godotengine/godot
- **Existing MCP**: Study our node_utils.gd patterns
- **API Reference**: https://docs.godotengine.org/en/stable/classes/

### **Development Environment**
- **Godot 4.5** with our addon enabled
- **Python 3.8+** with FastMCP
- **WebSocket testing** tools for debugging
- **Comprehensive logging** for error diagnosis

### **Testing Strategy**
- **Unit Tests**: Individual tool functionality
- **Integration Tests**: Full Godot ↔ MCP pipeline
- **Error Injection**: Test error handling paths
- **Performance Tests**: Response time validation
- **Compatibility Tests**: Different Godot versions

---

## 📈 **Success Metrics**

- **100% Error Transparency**: All Godot errors relayed exactly
- **Zero Breaking Changes**: Backward compatibility maintained
- **<100ms Response Time**: All operations perform well
- **99.9% Reliability**: Consistent success for valid operations
- **Complete Documentation**: Every tool fully documented with examples

**This workflow has proven successful for the Node Control system and should be followed exactly for all future tool categories.**