extends Node3D

# Configuration matching your hardware loop interval (500ms = 0.5 seconds)
const TIME_STEP : float = 0.5 

# Interpolation weight (higher = faster snapping, lower = smoother/slower glide)
# 5.0 to 10.0 is usually the sweet spot for low-frequency data tracking
const SMOOTHING_SPEED : float = 6.0 

var current_index : int = 0
var playback_timer : float = 0.0

# Our container's target orientation matrix we want to slide toward
var target_transform : Transform3D

# Hardcoded test data array to simulate physical movement vectors on Day 1
var mock_vectors : Array = [
	Vector3(0, 0, -1023),    # 1. Standing perfectly vertical at rest
	Vector3(0, 0, -1023),    # 2. Still stationary on the pad
	Vector3(120, -80, 3200),  # 3. Sudden violent forward blast-off spike!
	Vector3(500, -400, 1500), # 4. Upward ascent coasting
	Vector3(1023, -900, -100),# 5. Heavy aerodynamic banking bank/tilt
	Vector3(50, -100, -1023), # 6. Tipping upside down at apogee (peak)
	Vector3(-1023, 1023, -4096), # 7. Sudden crash impact spike!
	Vector3(950, 380, -100)   # 8. Resting horizontally tilted in the grass
]

func _ready() -> void:
	# Initialize our target transform to match our starting position
	target_transform = global_transform

func _physics_process(delta: float) -> void:
	playback_timer += delta
	
	# Every 0.5 seconds, update our target vector destination
	if playback_timer >= TIME_STEP:
		playback_timer = 0.0
		current_index += 1
		
		if current_index >= mock_vectors.size():
			current_index = 0
			print("--- Loop Restarted ---")
			
		var active_vector = mock_vectors[current_index]
		calculate_target_orientation(active_vector)

	# --- THE SMOOTHING ENGINE ---
	# Instead of snapping, we use 'interpolate_with' (Godot's 3D matrix slerp wrapper).
	# This smoothly blends the current orientation into the target orientation frame by frame.
	global_transform = global_transform.interpolate_with(target_transform, SMOOTHING_SPEED * delta)

# Calculates what the orientation matrix SHOULD be based on the sensor vector
func calculate_target_orientation(sensor_force: Vector3) -> void:
	if sensor_force.length() < 0.1:
		sensor_force = Vector3(0, 0, -1)
		
	var target_direction = sensor_force.normalized()
	
	# Store our current transform state so we can alter its basis rotation safely
	var temp_transform = global_transform
	
	# Use an absolute up-vector guard to prevent look_at math errors
	if abs(target_direction.dot(Vector3.UP)) < 0.99:
		temp_transform = temp_transform.looking_at(global_position + target_direction, Vector3.UP)
	else:
		temp_transform = temp_transform.looking_at(global_position + target_direction, Vector3.FORWARD)
		
	# Assign the newly calculated rotational matrix to our target destination
	target_transform = temp_transform

	print("Snapshot #", current_index, " | Data Updated | Vector: ", sensor_force)
