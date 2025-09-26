#!/usr/bin/env python3
"""
Test script for Godot MCP Server
Tests basic functionality without requiring Godot connection
"""

import asyncio
import json
from unittest.mock import AsyncMock, MagicMock
from fastmcp import FastMCP

# Mock the Godot connection for testing
class MockGodotConnection:
    def __init__(self):
        self.connected = True

    async def send_command(self, command):
        # Mock responses for testing
        cmd_type = command.get("type")
        if cmd_type == "get_scene_tree":
            return {
                "status": "success",
                "data": {
                    "root_node": "DemoScene",
                    "scene_path": "res://demo_scene.tscn",
                    "tree": {
                        "name": "DemoScene",
                        "type": "Node2D",
                        "path": ".",
                        "children": [
                            {
                                "name": "Player",
                                "type": "CharacterBody2D",
                                "path": "Player",
                                "children": []
                            }
                        ]
                    }
                }
            }
        elif cmd_type == "create_node":
            return {
                "status": "success",
                "data": {
                    "node_path": "./NewNode",
                    "node_name": "NewNode",
                    "node_type": command["params"]["node_type"]
                }
            }
        elif cmd_type == "get_script_content":
            return {
                "status": "success",
                "data": {
                    "content": "extends Node2D\n\nfunc _ready():\n    pass",
                    "resource_path": ""
                }
            }
        elif cmd_type == "set_script_content":
            return {"status": "success"}
        elif cmd_type == "validate_script":
            content = command["params"]["content"]
            if "extends" in content and "func" in content:
                return {
                    "status": "success",
                    "data": {"valid": True}
                }
            else:
                return {
                    "status": "success",
                    "data": {
                        "valid": False,
                        "error": "Invalid GDScript syntax"
                    }
                }
        elif cmd_type == "create_script_file":
            return {
                "status": "success",
                "data": {
                    "file_path": f"res://scripts/{command['params']['filename']}.gd"
                }
            }
        elif cmd_type == "load_script_file":
            return {
                "status": "success",
                "data": {
                    "content": "extends Node\n\n@export var speed: int = 100",
                    "file_path": command["params"]["file_path"]
                }
            }
        elif cmd_type == "get_script_variables":
            return {
                "status": "success",
                "data": {
                    "variables": [
                        {
                            "name": "speed",
                            "type": "int",
                            "value": 100
                        },
                        {
                            "name": "name",
                            "type": "String",
                            "value": "Player"
                        }
                    ]
                }
            }
        elif cmd_type == "set_script_variable":
            return {"status": "success"}
        elif cmd_type == "get_script_functions":
            return {
                "status": "success",
                "data": {
                    "functions": [
                        {
                            "name": "_ready",
                            "args_count": 0,
                            "return_type": "void",
                            "is_virtual": True
                        },
                        {
                            "name": "move",
                            "args_count": 2,
                            "return_type": "void",
                            "is_virtual": False
                        }
                    ]
                }
            }
        elif cmd_type == "attach_script_to_node":
            return {"status": "success"}
        elif cmd_type == "detach_script_from_node":
            return {"status": "success"}
        elif cmd_type == "get_current_scene_info":
            return {
                "status": "success",
                "data": {
                    "scene_path": "res://test_scene.tscn",
                    "scene_name": "test_scene",
                    "root_node_type": "Node2D",
                    "root_node_name": "TestScene",
                    "child_count": 3
                }
            }
        elif cmd_type == "open_scene":
            scene_path = command["params"]["scene_path"]
            return {
                "status": "success",
                "data": {"scene_path": scene_path}
            }
        elif cmd_type == "save_scene":
            return {
                "status": "success",
                "data": {"scene_path": "res://test_scene.tscn"}
            }
        elif cmd_type == "save_scene_as":
            scene_path = command["params"]["scene_path"]
            return {
                "status": "success",
                "data": {"scene_path": scene_path}
            }
        elif cmd_type == "create_new_scene":
            root_type = command["params"]["root_node_type"]
            return {
                "status": "success",
                "data": {
                    "root_node_type": root_type,
                    "root_node_name": "SceneRoot"
                }
            }
        elif cmd_type == "instantiate_scene":
            scene_path = command["params"]["scene_path"]
            parent_path = command["params"]["parent_path"]
            return {
                "status": "success",
                "data": {
                    "instance_path": f"{parent_path}/Instance",
                    "instance_name": "Instance",
                    "scene_path": scene_path
                }
            }
        elif cmd_type == "pack_scene_from_node":
            node_path = command["params"]["node_path"]
            save_path = command["params"]["save_path"]
            return {
                "status": "success",
                "data": {
                    "save_path": save_path,
                    "node_path": node_path
                }
            }
        else:
            return {"status": "success"}

# Import and patch the real server
import sys
import os
sys.path.insert(0, os.path.dirname(__file__))

# Import the server module directly
import importlib.util
spec = importlib.util.spec_from_file_location("godot_mcp_server", "godot-mcp-server.py")
server_module = importlib.util.module_from_spec(spec)
sys.modules["godot_mcp_server"] = server_module
spec.loader.exec_module(server_module)

# Replace the real Godot connection with mock
original_godot = server_module.godot
server_module.godot = MockGodotConnection()

async def test_tools():
    """Test all MCP tools with mock responses"""
    print("\nTesting MCP Tools...")

    # Use FastMCP Client to test tools
    from fastmcp import Client

    async with Client(server_module.app) as client:
        # Test get_scene_tree
        result = await client.call_tool("get_scene_tree", {})
        result_content = str(result.content[0].text) if result.content else ""
        print(f"get_scene_tree result: {result_content[:100]}...")
        assert "DemoScene" in result_content

        # Test create_node
        result = await client.call_tool("create_node", {"node_type": "Sprite2D", "parent_path": ".", "node_name": "TestSprite"})
        result_content = str(result.content[0].text) if result.content else ""
        print(f"create_node result: {result_content}")
        assert "Created" in result_content and "Sprite2D" in result_content

        # Test other tools
        result = await client.call_tool("get_debug_info", {})
        result_content = str(result.content[0].text) if result.content else ""
        print(f"get_debug_info result: {result_content[:100]}...")
        # Just check that we got a response
        assert len(result_content) > 0

        # Test script management tools
        print("\nTesting Script Management Tools...")

        # Test get_script_content
        result = await client.call_tool("get_script_content", {"node_path": "Player"})
        result_content = str(result.content[0].text) if result.content else ""
        print(f"get_script_content result: {result_content[:100]}...")
        assert "extends Node2D" in result_content

        # Test set_script_content
        new_content = "extends Node2D\n\nfunc _ready():\n    print('Hello World')"
        result = await client.call_tool("set_script_content", {"node_path": "Player", "content": new_content})
        result_content = str(result.content[0].text) if result.content else ""
        print(f"set_script_content result: {result_content}")
        assert "Successfully updated" in result_content

        # Test validate_script - valid
        valid_script = "extends Node2D\n\nfunc _ready():\n    pass"
        result = await client.call_tool("validate_script", {"content": valid_script})
        result_content = str(result.content[0].text) if result.content else ""
        print(f"validate_script (valid) result: {result_content}")
        assert "validation successful" in result_content

        # Test validate_script - invalid
        invalid_script = "invalid syntax here"
        result = await client.call_tool("validate_script", {"content": invalid_script})
        result_content = str(result.content[0].text) if result.content else ""
        print(f"validate_script (invalid) result: {result_content}")
        assert "validation failed" in result_content

        # Test create_script_file
        result = await client.call_tool("create_script_file", {"filename": "TestScript", "content": valid_script})
        result_content = str(result.content[0].text) if result.content else ""
        print(f"create_script_file result: {result_content}")
        assert "Successfully created" in result_content

        # Test load_script_file
        result = await client.call_tool("load_script_file", {"file_path": "res://scripts/TestScript.gd"})
        result_content = str(result.content[0].text) if result.content else ""
        print(f"load_script_file result: {result_content[:100]}...")
        assert "@export var speed" in result_content

        # Test get_script_variables
        result = await client.call_tool("get_script_variables", {"node_path": "Player"})
        result_content = str(result.content[0].text) if result.content else ""
        print(f"get_script_variables result: {result_content}")
        assert "speed" in result_content and "name" in result_content

        # Test set_script_variable
        result = await client.call_tool("set_script_variable", {"node_path": "Player", "var_name": "speed", "value": 200})
        result_content = str(result.content[0].text) if result.content else ""
        print(f"set_script_variable result: {result_content}")
        assert "speed = 200" in result_content

        # Test get_script_functions
        result = await client.call_tool("get_script_functions", {"node_path": "Player"})
        result_content = str(result.content[0].text) if result.content else ""
        print(f"get_script_functions result: {result_content}")
        assert "_ready" in result_content and "move" in result_content

        # Test attach_script_to_node
        result = await client.call_tool("attach_script_to_node", {"node_path": "Enemy", "script_path": "res://scripts/AI.gd"})
        result_content = str(result.content[0].text) if result.content else ""
        print(f"attach_script_to_node result: {result_content}")
        assert "Successfully attached" in result_content

        # Test detach_script_from_node
        result = await client.call_tool("detach_script_from_node", {"node_path": "Enemy"})
        result_content = str(result.content[0].text) if result.content else ""
        print(f"detach_script_from_node result: {result_content}")
        assert "Successfully detached" in result_content

        # Test scene management tools
        print("\nTesting Scene Management Tools...")

        # Test get_current_scene_info
        result = await client.call_tool("get_current_scene_info", {})
        result_content = str(result.content[0].text) if result.content else ""
        print(f"get_current_scene_info result: {result_content}")
        assert "TestScene" in result_content and "Node2D" in result_content

        # Test open_scene
        result = await client.call_tool("open_scene", {"scene_path": "res://scenes/level1.tscn"})
        result_content = str(result.content[0].text) if result.content else ""
        print(f"open_scene result: {result_content}")
        assert "Successfully opened scene" in result_content

        # Test save_scene
        result = await client.call_tool("save_scene", {})
        result_content = str(result.content[0].text) if result.content else ""
        print(f"save_scene result: {result_content}")
        assert "Successfully saved scene" in result_content

        # Test save_scene_as
        result = await client.call_tool("save_scene_as", {"scene_path": "res://scenes/new_scene.tscn"})
        result_content = str(result.content[0].text) if result.content else ""
        print(f"save_scene_as result: {result_content}")
        assert "Successfully saved scene as" in result_content

        # Test create_new_scene
        result = await client.call_tool("create_new_scene", {"root_node_type": "Node3D"})
        result_content = str(result.content[0].text) if result.content else ""
        print(f"create_new_scene result: {result_content}")
        assert "Successfully created new scene" in result_content and "Node3D" in result_content

        # Test instantiate_scene
        result = await client.call_tool("instantiate_scene", {"scene_path": "res://prefabs/enemy.tscn", "parent_path": "Enemies"})
        result_content = str(result.content[0].text) if result.content else ""
        print(f"instantiate_scene result: {result_content}")
        assert "Successfully instantiated" in result_content and "enemy.tscn" in result_content

        # Test pack_scene_from_node
        result = await client.call_tool("pack_scene_from_node", {"node_path": "Player", "save_path": "res://prefabs/player.tscn"})
        result_content = str(result.content[0].text) if result.content else ""
        print(f"pack_scene_from_node result: {result_content}")
        assert "Successfully packed scene" in result_content

    print("All tool tests passed!")

async def test_mcp_server():
    """Test MCP server initialization"""
    print("Testing MCP server initialization...")

    # Create a test app (without description parameter)
    app = FastMCP(name="Test Godot MCP")

    # Add a simple tool
    @app.tool()
    def test_tool() -> str:
        return "Hello from test tool"

    print("MCP server test completed!")

async def main():
    """Run all tests"""
    print("Starting Godot MCP Server Tests...")
    print("=" * 50)

    try:
        await test_tools()
        print()
        await test_mcp_server()
        print()
        print("✅ All tests passed!")

    except Exception as e:
        print(f"❌ Test failed: {e}")
        raise
    finally:
        # Restore original godot connection
        server_module.godot = original_godot

if __name__ == "__main__":
    asyncio.run(main())