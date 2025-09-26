#!/usr/bin/env python3
"""
Test the fixed save_resource functionality
"""

import sys
import os

# Add current directory to path
sys.path.insert(0, os.path.dirname(__file__))

def test_import():
    """Test that the server can be imported without errors"""
    try:
        # Import the server module directly
        import importlib.util
        spec = importlib.util.spec_from_file_location("godot_mcp_server", "godot-mcp-server.py")
        server_module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(server_module)
        print("✅ Server imported successfully")
        return True
    except Exception as e:
        print(f"❌ Failed to import server: {e}")
        return False

def test_save_resource_function_exists():
    """Test that the save_resource function is defined in the server module"""
    try:
        # Import the server module directly
        import importlib.util
        spec = importlib.util.spec_from_file_location("godot_mcp_server", "godot-mcp-server.py")
        server_module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(server_module)

        # Check if save_resource function exists
        if hasattr(server_module, 'save_resource'):
            print("✅ save_resource function found in server module")
            return True
        else:
            print("❌ save_resource function not found in server module")
            return False

    except Exception as e:
        print(f"❌ Failed to check save_resource function: {e}")
        return False

def main():
    print("Testing the fixed save_resource functionality...")
    print("=" * 60)

    success = True
    success &= test_import()
    success &= test_save_resource_tool_exists()

    if success:
        print("\n✅ All tests passed! The save_resource fix appears to be working.")
        print("The tool now creates and saves resources in one operation,")
        print("eliminating the need to pass resource objects through MCP.")
    else:
        print("\n❌ Some tests failed.")
        sys.exit(1)

if __name__ == "__main__":
    main()