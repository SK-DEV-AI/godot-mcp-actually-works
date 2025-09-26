extends Node

@export var speed: float = 100.0

func _ready():
	print("Test script ready!")

func move_forward(delta: float):
	print("Moving forward with speed: ", speed * delta)