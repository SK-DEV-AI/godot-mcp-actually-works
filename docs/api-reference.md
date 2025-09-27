# API Reference

## Tool Categories

This MCP server provides 80 specialized tools organized into logical categories for comprehensive Godot scene manipulation and editor automation.

## 1. Scene Management

### `get_scene_tree() -> str`

Get the complete scene tree structure with all nodes, their types, and hierarchy.

**Returns**: JSON string containing scene tree data with node names, types, paths, and hierarchy.

**Example Usage**:
```python
# Get overview of current scene
scene_data = await get_scene_tree()
print(scene_data)  # Shows complete scene structure
```

**Response Format**:
```json
{
  "scene_path": "/path/to/scene.tscn",
  "root_node": "Main",
  "hierarchy": {
    "Main": {
      "type": "Node2D",
      "children": {
        "Player": {
          "type": "CharacterBody2D",
          "children": {}
        },
        "Enemies": {
          "type": "Node2D",
          "children": {
            "Enemy1": {"type": "Area2D", "children": {}}
          }
        }
      }
    }
  }
}
```

### `get_current_scene_info() -> str`

Get detailed information about the currently edited scene in Godot.

**Returns**: Scene information including path, root node details, and child count.

**Response Format**:
```json
{
  "scene_path": "res://scenes/level1.tscn",
  "scene_name": "level1",
  "root_node_type": "Node2D",
  "root_node_name": "Level1",
  "child_count": 5
}
```

### `open_scene(scene_path: str) -> str`

Open a scene file in the Godot editor.

**Parameters**:
- `scene_path` (str): Path to the scene file to open (e.g., "res://scenes/level1.tscn")

**Returns**: Success confirmation with scene path.

### `save_scene() -> str`

Save the currently edited scene to its existing file path.

**Returns**: Success confirmation with saved scene path.

### `save_scene_as(scene_path: str) -> str`

Save the currently edited scene to a new file path.

**Parameters**:
- `scene_path` (str): New path where to save the scene (must end with .tscn)

**Returns**: Success confirmation with new scene path.

### `create_new_scene(root_node_type: str = "Node2D") -> str`

Create a new empty scene with specified root node type.

**Parameters**:
- `root_node_type` (str): Type of root node for the new scene (default: "Node2D")
                        Common options: "Node2D", "Node3D", "Control", "Node"

**Returns**: Success confirmation with root node details.

**Examples**:
```python
# Create a new 2D scene
await create_new_scene("Node2D")

# Create a new 3D scene
await create_new_scene("Node3D")

# Create a new UI scene
await create_new_scene("Control")
```

### `instantiate_scene(scene_path: str, parent_path: str = ".") -> str`

Instantiate a scene and add it as a child to the specified parent.

**Parameters**:
- `scene_path` (str): Path to the scene file to instantiate (e.g., "res://scenes/enemy.tscn")
- `parent_path` (str): Path to the parent node where to add the instance (default: "." for scene root)

**Returns**: Success confirmation with instance details.

**Examples**:
```python
# Add enemy instance to the scene
await instantiate_scene("res://prefabs/enemy.tscn", ".")

# Spawn player in the Players container
await instantiate_scene("res://prefabs/player.tscn", "Players")

# Add UI panel to canvas
await instantiate_scene("res://ui/health_bar.tscn", "UI/CanvasLayer")
```

### `pack_scene_from_node(node_path: str, save_path: str) -> str`

Create a packed scene from an existing node and save it.

**Parameters**:
- `node_path` (str): Path to the node to pack into a scene
- `save_path` (str): Path where to save the packed scene file (must end with .tscn)

**Returns**: Success confirmation with save details.

**Examples**:
```python
# Create player prefab from existing node
await pack_scene_from_node("Player", "res://prefabs/player.tscn")

# Save enemy setup as reusable scene
await pack_scene_from_node("Enemies/Enemy1", "res://prefabs/enemy.tscn")

# Create UI component prefab
await pack_scene_from_node("UI/HealthBar", "res://ui/health_bar.tscn")
```

### `run_scene() -> str`

Start scene execution in Godot editor.

**Returns**: Success confirmation message.

### `stop_scene() -> str`

Stop the currently running scene.

**Returns**: Success confirmation message.

## 2. Node Operations

### `create_node(node_type: str, parent_path: str = ".", node_name: str = "") -> str`

Create a new node in the Godot scene with full undo support.

**Parameters**:
- `node_type` (str): Godot node class name (e.g., 'Node2D', 'Sprite2D', 'CharacterBody2D')
- `parent_path` (str): Path to parent node (default: "." for scene root)
- `node_name` (str): Custom name for the node (optional - auto-generated if empty)

**Returns**: Success message with created node's path.

**Examples**:
```python
# Create a player character
await create_node("CharacterBody2D", ".", "Player")

# Add a sprite to the player
await create_node("Sprite2D", "Player", "PlayerSprite")

# Create UI elements
await create_node("Button", "UI/CanvasLayer", "StartButton")
```

### `delete_node(node_path: str) -> str`

Remove a node from the scene safely with undo support.

**Parameters**:
- `node_path` (str): Path to the node to delete

**Returns**: Success confirmation.

### `move_node(node_path: str, new_parent_path: str, new_name: str = "") -> str`

Move a node to a new parent and optionally rename it.

**Parameters**:
- `node_path` (str): Path to the node to move
- `new_parent_path` (str): Path to the new parent node
- `new_name` (str): New name for the node (optional)

**Returns**: Success message with new path.

### `duplicate_node(node_path: str, new_name: str = "") -> str`

Create a copy of an existing node.

**Parameters**:
- `node_path` (str): Path to the node to duplicate
- `new_name` (str): Name for the duplicate (optional)

**Returns**: Success message with duplicate path.

### `find_nodes_by_type(node_type: str, search_root: str = ".") -> str`

Find all nodes of a specific type in the scene.

**Parameters**:
- `node_type` (str): Type of nodes to find (e.g., 'Sprite2D', 'Area2D')
- `search_root` (str): Root path to start searching (default: scene root)

**Returns**: List of matching node paths.

### `get_node_children(node_path: str, recursive: bool = false) -> str`

Get children of a node.

**Parameters**:
- `node_path` (str): Path to the parent node
- `recursive` (bool): Whether to get all descendants recursively

**Returns**: List of child node paths.

## 3. Node Properties & Transform

### `get_node_properties(node_path: str) -> str`

Get all properties of a specific node.

**Parameters**:
- `node_path` (str): Path to the node

**Returns**: JSON object with all node properties.

**Response Format**:
```json
{
  "position": [100.0, 200.0],
  "rotation": 0.0,
  "scale": [1.0, 1.0],
  "visible": true,
  "modulate": [1.0, 1.0, 1.0, 1.0],
  "name": "Player",
  "script": null
}
```

### `set_node_property(node_path: str, property_name: str, value: Any) -> str`

Set any property on a Godot node with type validation and undo support.

**Parameters**:
- `node_path` (str): Path to the target node
- `property_name` (str): Property name (e.g., "position", "text", "modulate", "visible")
- `value` (Any): New value matching the property type

**Value Formats**:
- **Vector2**: `[x, y]` for 2D positions/scales
- **Vector3**: `[x, y, z]` for 3D transforms
- **Color**: `[r, g, b, a]` (0-1 range)
- **bool**: `true`/`false`
- **String**: `"text value"`
- **Numbers**: `int` or `float` values

**Examples**:
```python
# Set position
await set_node_property("Player", "position", [100, 200])

# Change text
await set_node_property("ScoreLabel", "text", "Score: 1000")

# Make invisible
await set_node_property("Enemy", "visible", false)

# Set color
await set_node_property("Background", "modulate", [0.5, 0.8, 1.0, 1.0])
```

### `set_node_transform(node_path: str, position: List[float] = None, rotation: List[float] = None, scale: List[float] = None) -> str`

Set position, rotation, and scale of a Godot node with precise control.

**Parameters**:
- `node_path` (str): Path to the node to transform
- `position` (List[float]): `[x, y]` or `[x, y, z]` coordinates (optional)
- `rotation` (List[float]): `[x, y, z]` rotation in degrees (optional)
- `scale` (List[float]): `[x, y]` or `[x, y, z]` scale factors (optional)

**Notes**:
- For 2D nodes: position/scale use `[x, y]`, rotation uses `[rotation_z]`
- For 3D nodes: all parameters use `[x, y, z]`
- Only specify transforms you want to change

### `set_node_visibility(node_path: str, visible: bool) -> str`

Control the visibility of a node.

**Parameters**:
- `node_path` (str): Path to the node
- `visible` (bool): Whether the node should be visible

## 4. Signals & Methods

### `connect_signal(from_node_path: str, signal_name: str, to_node_path: str, method_name: str) -> str`

Connect Godot signals between nodes for event-driven programming.

**Parameters**:
- `from_node_path` (str): Path to the node that emits the signal
- `signal_name` (str): Signal name (e.g., "pressed", "body_entered", "timeout")
- `to_node_path` (str): Path to the node that will handle the signal
- `method_name` (str): Method name to call when signal fires

**Common Signals**:
- **UI**: `pressed`, `button_down`, `text_changed`, `item_selected`
- **Physics**: `body_entered`, `body_exited`, `area_entered`, `area_exited`
- **Timers**: `timeout`
- **Animation**: `animation_finished`, `frame_changed`

**Examples**:
```python
# Connect button click
await connect_signal("StartButton", "pressed", "GameManager", "_on_start_pressed")

# Connect collision detection
await connect_signal("Player", "body_entered", "Player", "_on_enemy_collision")

# Connect timer
await connect_signal("SpawnTimer", "timeout", "EnemySpawner", "_spawn_enemy")
```

### `disconnect_signal(from_node_path: str, signal_name: str, to_node_path: str, method_name: str) -> str`

Disconnect a signal connection.

**Parameters**: Same as `connect_signal`

### `get_node_signals(node_path: str) -> str`

Get all signals available on a node.

**Parameters**:
- `node_path` (str): Path to the node

**Returns**: JSON array of available signal names.

### `get_node_methods(node_path: str) -> str`

Get all methods available on a node.

**Parameters**:
- `node_path` (str): Path to the node

**Returns**: JSON array of method objects with names, args count, and return types.

### `call_node_method(node_path: str, method_name: str, args: List[Any] = None) -> str`

Call a method on a node with arguments.

**Parameters**:
- `node_path` (str): Path to the node
- `method_name` (str): Method name to call
- `args` (List[Any]): Arguments to pass (optional)

**Returns**: Method result.

## 5. Scripting

### `add_script_to_node(node_path: str, script_content: str) -> str`

Attach GDScript code to a Godot node to add custom behavior.

**Parameters**:
- `node_path` (str): Path to the node to attach the script to
- `script_content` (str): Complete GDScript code as a string

**Script Requirements**:
- Include `extends NodeType` (optional, inferred from node)
- Use proper GDScript syntax
- Methods like `_ready()`, `_process(delta)`, `_physics_process(delta)`
- Custom methods and variables

**Example Script**:
```gdscript
extends CharacterBody2D

@export var speed = 300.0
@export var jump_velocity = -400.0

func _physics_process(delta):
    # Movement logic
    var direction = Input.get_axis("ui_left", "ui_right")
    velocity.x = direction * speed

    # Jumping
    if Input.is_action_just_pressed("ui_up") and is_on_floor():
        velocity.y = jump_velocity

    move_and_slide()

func take_damage(amount: int):
    health -= amount
    if health <= 0:
        queue_free()
```

## 6. Script Management

### `get_script_content(node_path: str) -> str`

Get the script content from a node.

**Parameters**:
- `node_path` (str): Path to the node with the script

**Returns**: Script content as a formatted string with resource path information.

### `set_script_content(node_path: str, content: str) -> str`

Update the script content on a node.

**Parameters**:
- `node_path` (str): Path to the node with the script
- `content` (str): New GDScript content

**Returns**: Success confirmation with character count.

### `validate_script(content: str) -> str`

Validate GDScript syntax without attaching to a node.

**Parameters**:
- `content` (str): GDScript content to validate

**Returns**: Validation result with success/failure status.

### `create_script_file(filename: str, content: str) -> str`

Create a new GDScript file.

**Parameters**:
- `filename` (str): Name of the script file (without .gd extension)
- `content` (str): GDScript content

**Returns**: Success message with file path.

### `load_script_file(file_path: str) -> str`

Load script content from a file.

**Parameters**:
- `file_path` (str): Path to the script file

**Returns**: Script content with file path information.

### `get_script_variables(node_path: str) -> str`

Get exported variables from a node's script.

**Parameters**:
- `node_path` (str): Path to the node with the script

**Returns**: Formatted list of exported variables with types and values.

**Response Format**:
```
📊 Exported variables in Player script:

• speed (int): 100
• name (String): Player
• health (float): 100.0
```

### `set_script_variable(node_path: str, var_name: str, value: Any) -> str`

Set the value of an exported script variable.

**Parameters**:
- `node_path` (str): Path to the node with the script
- `var_name` (str): Name of the exported variable
- `value` (Any): New value for the variable

**Returns**: Success confirmation with variable assignment.

### `get_script_functions(node_path: str) -> str`

Get functions defined in a node's script.

**Parameters**:
- `node_path` (str): Path to the node with the script

**Returns**: Formatted list of functions with signatures.

**Response Format**:
```
⚡ Functions in Player script:

• _ready() → void (virtual)
• _physics_process(1 args) → void (virtual)
• move(2 args) → void
• take_damage(1 args) → void
```

### `attach_script_to_node(node_path: str, script_path: str) -> str`

Attach an existing script file to a node.

**Parameters**:
- `node_path` (str): Path to the node to attach the script to
- `script_path` (str): Path to the script file to attach

**Returns**: Success confirmation.

### `detach_script_from_node(node_path: str) -> str`

Remove the script from a node.

**Parameters**:
- `node_path` (str): Path to the node to detach the script from

**Returns**: Success confirmation.

## 7. Animation System

### `create_animation_player(parent_path: str = ".", node_name: str = "") -> str`

Create an AnimationPlayer node in the Godot scene with full undo support.

**Parameters**:
- `parent_path` (str): Path to parent node (default: "." for scene root)
- `node_name` (str): Custom name for the AnimationPlayer (optional - auto-generated if empty)

**Returns**: Success message with the created node's path.

**Examples**:
```python
# Create AnimationPlayer for character animations
await create_animation_player("Player", "CharacterAnimator")

# Create AnimationPlayer for UI transitions
await create_animation_player("UI/CanvasLayer", "UITransitions")
```

### `get_animation_player_info(node_path: str) -> str`

Get AnimationPlayer state and properties for debugging and inspection.

**Parameters**:
- `node_path` (str): Path to the AnimationPlayer node

**Returns**: Detailed AnimationPlayer state information including current animation, playback status, and configuration.

### `set_animation_player_property(node_path: str, property_name: str, value: Any) -> str`

Set AnimationPlayer properties like autoplay, speed, and blend settings.

**Parameters**:
- `node_path` (str): Path to the AnimationPlayer node
- `property_name` (str): Property to modify:
  - `"autoplay"`: Animation to play on scene start (string)
  - `"speed_scale"`: Playback speed multiplier (float)
  - `"playback_default_blend_time"`: Default blend duration (float)
  - `"playback_auto_capture"`: Auto-capture mode (bool)
- `value` (Any): New value for the property

**Returns**: Success confirmation.

### `remove_animation_player(node_path: str) -> str`

Remove an AnimationPlayer node from the scene.

**Parameters**:
- `node_path` (str): Path to the AnimationPlayer to remove

**Returns**: Success confirmation.

### `play_animation(player_path: str, animation_name: str = "", custom_blend: float = -1, custom_speed: float = 1.0, from_end: bool = False) -> str`

Play animations with advanced playback controls.

**Parameters**:
- `player_path` (str): Path to the AnimationPlayer node
- `animation_name` (str): Name of animation to play (empty for current/default)
- `custom_blend` (float): Custom blend time in seconds (-1 for default)
- `custom_speed` (float): Playback speed multiplier (1.0 = normal speed)
- `from_end` (bool): Start playback from the end (reverse playback)

**Returns**: Success confirmation with playing animation info.

**Examples**:
```python
# Play walk animation normally
await play_animation("Player/Animator", "walk")

# Play jump with 0.5s blend time
await play_animation("Player/Animator", "jump", custom_blend=0.5)

# Play death animation in reverse
await play_animation("Player/Animator", "death", from_end=True)
```

### `pause_animation(player_path: str) -> str`

Pause the currently playing animation.

**Parameters**:
- `player_path` (str): Path to the AnimationPlayer node

**Returns**: Success confirmation.

### `stop_animation(player_path: str, keep_state: bool = False) -> str`

Stop animation playback with state preservation option.

**Parameters**:
- `player_path` (str): Path to the AnimationPlayer node
- `keep_state` (bool): If true, animated properties remain at current values

**Returns**: Success confirmation.

### `seek_animation(player_path: str, seconds: float, update: bool = False, update_only: bool = False) -> str`

Seek to a specific time in the current animation.

**Parameters**:
- `player_path` (str): Path to the AnimationPlayer node
- `seconds` (float): Time position in seconds to seek to
- `update` (bool): If true, update animated properties immediately
- `update_only` (bool): If true, only update properties without changing playback position

**Returns**: Success confirmation with seek position.

### `queue_animation(player_path: str, animation_name: str) -> str`

Add an animation to the playback queue for sequential playing.

**Parameters**:
- `player_path` (str): Path to the AnimationPlayer node
- `animation_name` (str): Name of animation to add to queue

**Returns**: Success confirmation.

### `clear_animation_queue(player_path: str) -> str`

Clear all animations from the playback queue.

**Parameters**:
- `player_path` (str): Path to the AnimationPlayer node

**Returns**: Success confirmation.

### `get_animation_state(player_path: str) -> str`

Get comprehensive animation playback state information.

**Parameters**:
- `player_path` (str): Path to the AnimationPlayer node

**Returns**: Detailed animation state information including current position, speed, queue status.

### `set_animation_speed(player_path: str, speed: float) -> str`

Set the playback speed multiplier for animations.

**Parameters**:
- `player_path` (str): Path to the AnimationPlayer node
- `speed` (float): Speed multiplier (1.0 = normal, 2.0 = double speed, 0.5 = half speed)

**Returns**: Success confirmation with speed setting.

### `create_animation_library(player_path: str, library_name: str) -> str`

Create a new AnimationLibrary for organizing animations.

**Parameters**:
- `player_path` (str): Path to the AnimationPlayer node
- `library_name` (str): Name for the new animation library

**Returns**: Success confirmation.

### `load_animation_library(player_path: str, library_path: str, library_name: str = "") -> str`

Load an AnimationLibrary from a file.

**Parameters**:
- `player_path` (str): Path to the AnimationPlayer node
- `library_path` (str): Path to the animation library file (.res)
- `library_name` (str): Name to assign to the loaded library (optional)

**Returns**: Success confirmation.

### `add_animation_to_library(player_path: str, library_name: str, animation_name: str, animation: Any) -> str`

Add an animation to an existing library.

**Parameters**:
- `player_path` (str): Path to the AnimationPlayer node
- `library_name` (str): Name of the target animation library
- `animation_name` (str): Name for the animation in the library
- `animation` (Any): Animation resource to add

**Returns**: Success confirmation.

### `remove_animation_from_library(player_path: str, library_name: str, animation_name: str) -> str`

Remove an animation from an animation library.

**Parameters**:
- `player_path` (str): Path to the AnimationPlayer node
- `library_name` (str): Name of the animation library
- `animation_name` (str): Name of animation to remove

**Returns**: Success confirmation.

### `get_animation_library_list(player_path: str) -> str`

Get a list of all animations in all libraries.

**Parameters**:
- `player_path` (str): Path to the AnimationPlayer node

**Returns**: Dictionary of libraries with their animations.

### `rename_animation(player_path: str, old_name: str, new_name: str) -> str`

Rename an animation in an AnimationPlayer.

**Parameters**:
- `player_path` (str): Path to the AnimationPlayer node
- `old_name` (str): Current name of the animation
- `new_name` (str): New name for the animation

**Returns**: Success confirmation.

### `create_animation(player_path: str, animation_name: str, length: float = 1.0) -> str`

Create a new empty animation resource.

**Parameters**:
- `player_path` (str): Path to the AnimationPlayer node
- `animation_name` (str): Name for the new animation
- `length` (float): Duration of the animation in seconds

**Returns**: Success confirmation with animation details.

### `get_animation_info(player_path: str, animation_name: str) -> str`

Get detailed information about a specific animation.

**Parameters**:
- `player_path` (str): Path to the AnimationPlayer node
- `animation_name` (str): Name of the animation to inspect

**Returns**: Animation metadata including duration, loop mode, track count.

### `set_animation_property(player_path: str, animation_name: str, property_name: str, value: Any) -> str`

Set properties of an animation like length, loop mode, and step size.

**Parameters**:
- `player_path` (str): Path to the AnimationPlayer node
- `animation_name` (str): Name of the animation to modify
- `property_name` (str): Property to change:
  - `"length"`: Animation duration in seconds (float)
  - `"loop_mode"`: Looping behavior (0=Linear, 1=Clamp, 2=PingPong)
  - `"step"`: Keyframe step size for snapping (float)
- `value` (Any): New value for the property

**Returns**: Success confirmation.

### `add_animation_track(player_path: str, animation_name: str, track_type: int, track_path: str) -> str`

Add a new track to an animation for keyframe data.

**Parameters**:
- `player_path` (str): Path to the AnimationPlayer node
- `animation_name` (str): Name of the animation to modify
- `track_type` (int): Type of track to create:
  - `0`: POSITION_3D (Vector3 position)
  - `1`: ROTATION_3D (Quaternion rotation)
  - `2`: SCALE_3D (Vector3 scale)
  - `3`: BLEND_SHAPE (float blend shape weight)
  - `4`: PROPERTY (generic property animation)
  - `5`: POSITION_2D (Vector2 position)
  - `6`: ROTATION_2D (float rotation)
  - `7`: SCALE_2D (Vector2 scale)
- `track_path` (str): Node path for the track (e.g., "Sprite:position", ".:rotation")

**Returns**: Success confirmation with track index.

### `remove_animation_track(player_path: str, animation_name: str, track_idx: int) -> str`

Remove a track from an animation.

**Parameters**:
- `player_path` (str): Path to the AnimationPlayer node
- `animation_name` (str): Name of the animation to modify
- `track_idx` (int): Index of the track to remove

**Returns**: Success confirmation.

### `insert_keyframe(player_path: str, animation_name: str, track_idx: int, time: float, value: Any) -> str`

Insert a keyframe at a specific time in an animation track.

**Parameters**:
- `player_path` (str): Path to the AnimationPlayer node
- `animation_name` (str): Name of the animation to modify
- `track_idx` (int): Index of the track to add keyframe to
- `time` (float): Time position in seconds for the keyframe
- `value` (Any): Value for the keyframe (type depends on track type)

**Returns**: Success confirmation with keyframe index.

### `remove_keyframe(player_path: str, animation_name: str, track_idx: int, key_idx: int) -> str`

Remove a keyframe from an animation track.

**Parameters**:
- `player_path` (str): Path to the AnimationPlayer node
- `animation_name` (str): Name of the animation to modify
- `track_idx` (int): Index of the track containing the keyframe
- `key_idx` (int): Index of the keyframe to remove

**Returns**: Success confirmation.

### `get_animation_tracks(player_path: str, animation_name: str) -> str`

Get detailed information about all tracks in an animation.

**Parameters**:
- `player_path` (str): Path to the AnimationPlayer node
- `animation_name` (str): Name of the animation to inspect

**Returns**: Array of track information objects.

### `set_blend_time(player_path: str, animation_from: str, animation_to: str, blend_time: float) -> str`

Set blend time between two animations for smooth transitions.

**Parameters**:
- `player_path` (str): Path to the AnimationPlayer node
- `animation_from` (str): Name of the source animation
- `animation_to` (str): Name of the target animation
- `blend_time` (float): Blend duration in seconds

**Returns**: Success confirmation.

### `get_blend_time(player_path: str, animation_from: str, animation_to: str) -> str`

Get the blend time between two animations.

**Parameters**:
- `player_path` (str): Path to the AnimationPlayer node
- `animation_from` (str): Name of the source animation
- `animation_to` (str): Name of the target animation

**Returns**: Blend time in seconds.

### `set_animation_next(player_path: str, animation_from: str, animation_to: str) -> str`

Set the next animation to play automatically after another.

**Parameters**:
- `player_path` (str): Path to the AnimationPlayer node
- `animation_from` (str): Name of the animation that triggers the next
- `animation_to` (str): Name of the animation to play next

**Returns**: Success confirmation.

### `get_animation_next(player_path: str, animation_from: str) -> str`

Get the next animation queued to play after another.

**Parameters**:
- `player_path` (str): Path to the AnimationPlayer node
- `animation_from` (str): Name of the animation to check

**Returns**: Name of the next animation or empty string.

### `set_animation_section(player_path: str, start_time: float = -1, end_time: float = -1) -> str`

Set the playback section for the current animation.

**Parameters**:
- `player_path` (str): Path to the AnimationPlayer node
- `start_time` (float): Start time in seconds (-1 for animation start)
- `end_time` (float): End time in seconds (-1 for animation end)

**Returns**: Success confirmation.

### `set_animation_section_with_markers(player_path: str, start_marker: str = "", end_marker: str = "") -> str`

Set playback section using named markers in the animation.

**Parameters**:
- `player_path` (str): Path to the AnimationPlayer node
- `start_marker` (str): Name of the start marker (empty for animation start)
- `end_marker` (str): Name of the end marker (empty for animation end)

**Returns**: Success confirmation.

### `add_animation_marker(player_path: str, animation_name: str, marker_name: str, time: float) -> str`

Add a named marker to an animation at a specific time.

**Parameters**:
- `player_path` (str): Path to the AnimationPlayer node
- `animation_name` (str): Name of the animation to modify
- `marker_name` (str): Name for the marker
- `time` (float): Time position in seconds for the marker

**Returns**: Success confirmation.

### `remove_animation_marker(player_path: str, animation_name: str, marker_name: str) -> str`

Remove a named marker from an animation.

**Parameters**:
- `player_path` (str): Path to the AnimationPlayer node
- `animation_name` (str): Name of the animation to modify
- `marker_name` (str): Name of the marker to remove

**Returns**: Success confirmation.

## 8. Debugging & Diagnostics

### `get_debug_info() -> str`

Get comprehensive debug information and error logs from Godot.

**Returns**: JSON object with system status, error logs, and diagnostic information.

**Response Format**:
```json
{
  "godot_version": "4.5.stable",
  "scene_open": true,
  "scene_path": "/path/to/scene.tscn",
  "error_count": 3,
  "recent_errors": [
    {
      "timestamp": "2025-01-25T15:30:00Z",
      "level": "ERROR",
      "message": "Node not found: InvalidPath"
    }
  ],
  "memory_usage": {
    "static": 12582912,
    "dynamic": 8388608
  },
  "connection_status": "connected"
}
```

## Error Handling

All tools return structured error responses when operations fail:

```json
{
  "status": "error",
  "error": "Detailed error message explaining what went wrong"
}
```

### Common Error Types

- **Node Not Found**: Specified node path doesn't exist
- **Invalid Node Type**: Node class doesn't exist in Godot
- **Property Not Found**: Attempted to set non-existent property
- **Script Compilation Error**: GDScript syntax or compilation failure
- **Permission Denied**: Operation not allowed in current editor state
- **Connection Error**: Communication failure with Godot

## Parameter Validation

### Node Paths
- Must be valid Godot node paths
- Use "/" as separator (e.g., "Player/Sprite")
- "." represents scene root
- Relative paths supported

### Node Types
- Must be valid Godot node classes
- Case-sensitive (e.g., "Sprite2D", not "sprite2d")
- Abstract classes cannot be instantiated

### Property Values
- Must match expected property types
- Vectors use array format: `[x, y]` or `[x, y, z]`
- Colors use RGBA format: `[r, g, b, a]` (0.0-1.0)
- Enums use string values

## Performance Considerations

### Batch Operations
For multiple related changes, consider:
1. Creating parent nodes first
2. Setting properties in logical order
3. Connecting signals after all nodes exist

### Memory Management
- Large scenes may impact performance
- Complex scripts increase compilation time
- Frequent undo operations consume memory

### Connection Limits
- WebSocket handles concurrent operations well
- Large result sets are efficiently streamed
- Automatic cleanup prevents memory leaks

## Best Practices

### Scene Organization
```python
# Create structured scene hierarchy
await create_node("Node2D", ".", "GameWorld")
await create_node("Node2D", "GameWorld", "Players")
await create_node("Node2D", "GameWorld", "Enemies")
await create_node("Node2D", "GameWorld", "UI")
```

### Property Setting
```python
# Set related properties together
await set_node_transform("Player", position=[100, 200], scale=[2, 2])
await set_node_property("Player", "modulate", [1, 1, 1, 0.8])
```

### Signal Connections
```python
# Connect related signals
await connect_signal("Player", "health_changed", "UI/HealthBar", "_update_display")
await connect_signal("Player", "died", "GameManager", "_game_over")
```

### Error Handling
```python
# Always check operation results
result = await create_node("InvalidNodeType", ".")
if "error" in result:
    print(f"Failed: {result['error']}")
    # Handle error appropriately
```

This API reference provides complete documentation for all 42 tools, enabling developers to build sophisticated Godot scenes through AI-assisted workflows.