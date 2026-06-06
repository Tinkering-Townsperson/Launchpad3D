extends Camera3D

@export var target_node: Node3D

func _process(_delta: float) -> void:
	if target_node:
		look_at(target_node.global_position, Vector3.UP)
