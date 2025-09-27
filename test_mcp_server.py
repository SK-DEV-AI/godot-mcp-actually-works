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
        self.mock_responses = {}
        self.default_response = {"status": "success", "data": {}}

    def set_mock_response(self, command_type, response):
        self.mock_responses[command_type] = response

    def set_default_response(self, response):
        self.default_response = response

    async def send_command(self, command):
        cmd_type = command.get("type")
        return self.mock_responses.get(cmd_type, self.default_response)

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

async def get_tool_result(client, tool_name, params):
    """Helper to call a tool and get the JSON result."""
    result = await client.call_tool(tool_name, params)
    text_result = str(result.content[0].text) if result.content else "{}"
    try:
        return json.loads(text_result)
    except json.JSONDecodeError:
        print(f"Failed to parse JSON: {text_result}")
        raise

async def test_node_operations(client):
    """Tests for core node operations."""
    print("\n--- Testing Node Operations ---")

    # Test get_scene_tree
    server_module.godot.set_mock_response("get_scene_tree", {"status": "success", "data": {"scene_path": "res://test.tscn"}})
    result = await get_tool_result(client, "get_scene_tree", {})
    assert result["status"] == "success"
    assert result["data"]["scene_path"] == "res://test.tscn"
    print(f"get_scene_tree: PASS")

    # Test create_node
    server_module.godot.set_mock_response("create_node", {"status": "success", "data": {"node_path": "./NewSprite", "node_name": "NewSprite"}})
    result = await get_tool_result(client, "create_node", {"node_type": "Sprite2D"})
    assert result["status"] == "success"
    assert "✅ Created Sprite2D node 'NewSprite' at path: ./NewSprite" in result["data"]["message"]
    print(f"create_node: PASS")

    # Test delete_node
    server_module.godot.set_mock_response("delete_node", {"status": "success"})
    result = await get_tool_result(client, "delete_node", {"node_path": "TestNode"})
    assert result["status"] == "success"
    assert "🗑️ Successfully deleted node: TestNode" in result["data"]["message"]
    print(f"delete_node: PASS")

    # Test set_node_property
    server_module.godot.set_mock_response("set_node_property", {"status": "success"})
    result = await get_tool_result(client, "set_node_property", {"node_path": "Player", "property_name": "position", "value": [100, 200]})
    print(f"set_node_property result: {result}")
    assert result["status"] == "success"
    print(f"set_node_property: PASS")

    # Test error handling
    server_module.godot.set_mock_response("create_node", {"status": "error", "error": "Invalid node type"})
    result = await get_tool_result(client, "create_node", {"node_type": "InvalidType"})
    assert result["status"] == "error"
    assert "❌ Failed to create InvalidType node: Invalid node type" in result["error"]["message"]
    print(f"create_node (error): PASS")

async def test_resource_operations(client):
    """Tests for resource management tools."""
    print("\n--- Testing Resource Operations ---")
    # Test create_resource
    server_module.godot.set_mock_response("create_resource", {"status": "success"})
    result = await get_tool_result(client, "create_resource", {"resource_type": "Texture2D"})
    assert result["status"] == "success"
    assert "📄 Successfully created Texture2D resource" in result["data"]["message"]
    print(f"create_resource: PASS")

    # Test load_resource
    server_module.godot.set_mock_response("load_resource", {"status": "success", "data": {"type": "Texture2D"}})
    result = await get_tool_result(client, "load_resource", {"resource_path": "res://image.png"})
    assert result["status"] == "success"
    assert "📂 Successfully loaded Texture2D resource from res://image.png" in result["data"]["message"]
    assert result["data"]["type"] == "Texture2D"
    print(f"load_resource: PASS")

    # Test error handling
    server_module.godot.set_mock_response("load_resource", {"status": "error", "error": "File not found"})
    result = await get_tool_result(client, "load_resource", {"resource_path": "res://nonexistent.png"})
    assert result["status"] == "error"
    assert "❌ Failed to load resource from res://nonexistent.png: File not found" in result["error"]["message"]
    print(f"load_resource (error): PASS")

async def test_scene_operations(client):
    """Tests for scene management tools."""
    print("\n--- Testing Scene Operations ---")
    # Test get_current_scene_info
    server_module.godot.set_mock_response("get_current_scene_info", {"status": "success", "data": {"scene_path": "res://level.tscn", "root_node_name": "Level"}})
    result = await get_tool_result(client, "get_current_scene_info", {})
    assert result["status"] == "success"
    assert result["data"]["scene_path"] == "res://level.tscn"
    print(f"get_current_scene_info: PASS")

    # Test open_scene
    server_module.godot.set_mock_response("open_scene", {"status": "success"})
    result = await get_tool_result(client, "open_scene", {"scene_path": "res://new_level.tscn"})
    assert result["status"] == "success"
    assert "📂 Successfully opened scene: res://new_level.tscn" in result["data"]["message"]
    print(f"open_scene: PASS")

async def test_scripting_operations(client):
    """Tests for scripting-related tools."""
    print("\n--- Testing Scripting Operations ---")
    # Test get_script_content
    server_module.godot.set_mock_response("get_script_content", {"status": "success", "data": {"content": "extends Node"}})
    result = await get_tool_result(client, "get_script_content", {"node_path": "Player"})
    assert result["status"] == "success"
    assert result["data"]["content"] == "extends Node"
    print(f"get_script_content: PASS")

    # Test add_script_to_node
    server_module.godot.set_mock_response("add_script_to_node", {"status": "success"})
    result = await get_tool_result(client, "add_script_to_node", {"node_path": "Player", "script_content": "extends Sprite2D"})
    assert result["status"] == "success"
    assert "📝 Successfully attached GDScript to Player" in result["data"]["message"]
    print(f"add_script_to_node: PASS")

async def test_animation_operations(client):
    """Tests for animation-related tools."""
    print("\n--- Testing Animation Operations ---")

    # Test create_animation_player
    server_module.godot.set_mock_response("create_animation_player", {"status": "success", "data": {"node_path": "./AnimationPlayer", "node_name": "AnimationPlayer"}})
    result = await get_tool_result(client, "create_animation_player", {"parent_path": ".", "node_name": "AnimationPlayer"})
    assert result["status"] == "success"
    assert "🎬 Created AnimationPlayer 'AnimationPlayer' at path: ./AnimationPlayer" in result["data"]["message"]
    print(f"create_animation_player: PASS")

    # Test get_animation_player_info
    server_module.godot.set_mock_response("get_animation_player_info", {"status": "success", "data": {"current_animation": "idle", "is_playing": True}})
    result = await get_tool_result(client, "get_animation_player_info", {"node_path": "AnimationPlayer"})
    assert result["status"] == "success"
    assert result["data"]["current_animation"] == "idle"
    print(f"get_animation_player_info: PASS")

    # Test play_animation
    server_module.godot.set_mock_response("play_animation", {"status": "success", "data": {"playing": "walk"}})
    result = await get_tool_result(client, "play_animation", {"player_path": "AnimationPlayer", "animation_name": "walk"})
    assert result["status"] == "success"
    assert "▶️ Playing animation 'walk'" in result["data"]["message"]
    print(f"play_animation: PASS")

    # Test pause_animation
    server_module.godot.set_mock_response("pause_animation", {"status": "success"})
    result = await get_tool_result(client, "pause_animation", {"player_path": "AnimationPlayer"})
    assert result["status"] == "success"
    assert "⏸️ Paused animation on AnimationPlayer" in result["data"]["message"]
    print(f"pause_animation: PASS")

    # Test create_animation
    server_module.godot.set_mock_response("create_animation", {"status": "success", "data": {"message": "Created animation"}})
    result = await get_tool_result(client, "create_animation", {"player_path": "AnimationPlayer", "animation_name": "jump", "length": 1.0})
    assert result["status"] == "success"
    assert "🎬 Created animation 'jump' (1.0s) on AnimationPlayer" in result["data"]["message"]
    print(f"create_animation: PASS")

    # Test add_animation_track
    server_module.godot.set_mock_response("add_animation_track", {"status": "success", "data": {"track_index": 0}})
    result = await get_tool_result(client, "add_animation_track", {"player_path": "AnimationPlayer", "animation_name": "jump", "track_type": 5, "track_path": "Sprite:position"})
    assert result["status"] == "success"
    assert "➕ Added 5 track 'Sprite:position' to animation 'jump'" in result["data"]["message"]
    print(f"add_animation_track: PASS")

    # Test insert_keyframe
    server_module.godot.set_mock_response("insert_keyframe", {"status": "success", "data": {"key_index": 0}})
    result = await get_tool_result(client, "insert_keyframe", {"player_path": "AnimationPlayer", "animation_name": "jump", "track_idx": 0, "time": 0.5, "value": [100, 200]})
    assert result["status"] == "success"
    assert "🔑 Inserted keyframe at 0.5s in track 0 of 'jump'" in result["data"]["message"]
    print(f"insert_keyframe: PASS")

    # Test set_blend_time
    server_module.godot.set_mock_response("set_blend_time", {"status": "success", "data": {"blend_time": 0.5}})
    result = await get_tool_result(client, "set_blend_time", {"player_path": "AnimationPlayer", "animation_from": "walk", "animation_to": "run", "blend_time": 0.5})
    assert result["status"] == "success"
    assert "🔄 Set blend time 0.5s between 'walk' → 'run'" in result["data"]["message"]
    print(f"set_blend_time: PASS")

async def test_type_conversion_operations(client):
    """Tests for type conversion in script variables and node properties."""
    print("\n--- Testing Type Conversion Operations ---")

    # Test set_script_variable with Vector2 array
    server_module.godot.set_mock_response("set_script_variable", {"status": "success"})
    result = await get_tool_result(client, "set_script_variable", {"node_path": "Player", "var_name": "position", "value": [100, 200]})
    assert result["status"] == "success"
    print(f"set_script_variable (Vector2 array): PASS")

    # Test set_script_variable with Color array
    server_module.godot.set_mock_response("set_script_variable", {"status": "success"})
    result = await get_tool_result(client, "set_script_variable", {"node_path": "Player", "var_name": "color", "value": [1, 0, 0, 1]})
    assert result["status"] == "success"
    print(f"set_script_variable (Color array): PASS")

    # Test set_node_property with Vector2 array
    server_module.godot.set_mock_response("set_node_property", {"status": "success"})
    result = await get_tool_result(client, "set_node_property", {"node_path": "Sprite", "property_name": "position", "value": [150, 250]})
    assert result["status"] == "success"
    print(f"set_node_property (Vector2 array): PASS")

    # Test set_node_property with Color array
    server_module.godot.set_mock_response("set_node_property", {"status": "success"})
    result = await get_tool_result(client, "set_node_property", {"node_path": "Sprite", "property_name": "modulate", "value": [0, 1, 0, 1]})
    assert result["status"] == "success"
    print(f"set_node_property (Color array): PASS")

async def test_all_tools():
    """Run tests for all tools."""
    from fastmcp import Client
    async with Client(server_module.app) as client:
        await test_node_operations(client)
        await test_resource_operations(client)
        await test_scene_operations(client)
        await test_scripting_operations(client)
        await test_animation_operations(client)
        await test_type_conversion_operations(client)

async def main():
    """Run all tests"""
    print("Starting Godot MCP Server Tests...")
    print("=" * 50)

    try:
        await test_all_tools()
        print("\n✅ All tests passed!")
    except Exception as e:
        print(f"\n❌ TEST FAILED: {e}")
        import traceback
        traceback.print_exc()
        # Restore original godot connection in case of failure
        server_module.godot = original_godot
        # Re-raise the exception to make sure the script exits with an error code
        raise
    finally:
        # Restore original godot connection
        server_module.godot = original_godot

if __name__ == "__main__":
    asyncio.run(main())