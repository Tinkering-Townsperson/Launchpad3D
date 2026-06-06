extends Node3D

const CSV_PATH : String = "res://testing/mock_flight.csv"
const SMOOTHING_SPEED : float = 6.0 

# Scale down raw 1023 mg units closer to Godot spatial meters
const SCALE_FACTOR : float = 104.3

var flight_rows : Array[Dictionary] = []
var current_row_index : int = 0
var playback_timer : float = 0.0

# Targets for lerp / slerp smoothing
var target_transform : Transform3D
var target_position : Vector3 = Vector3.ZERO
var current_velocity : Vector3 = Vector3.ZERO

func _ready() -> void:
	target_transform = global_transform
	target_position = global_position
	
	flight_rows = TelemetryParser.parse_telemetry_file(CSV_PATH)
	if flight_rows.size() == 0:
		print("Error: No data available in parser.")

func _physics_process(delta: float) -> void:
	if flight_rows.size() == 0:
		return
		
	playback_timer += delta
	
	# Determine the dynamic time gap between data rows
	var current_step_duration = 0.1 # fallback base
	if current_row_index > 0 and current_row_index < flight_rows.size():
		current_step_duration = flight_rows[current_row_index]["time"] - flight_rows[current_row_index - 1]["time"]
	
	# Trigger the next physics frame when our timer hits the true row elapsed gap
	if playback_timer >= current_step_duration:
		playback_timer = 0.0
		current_row_index += 1
		
		if current_row_index >= flight_rows.size():
			# Loop Reset
			current_row_index = 0
			current_velocity = Vector3.ZERO
			target_position = Vector3.ZERO
			global_position = Vector3.ZERO
			print("--- Flight Complete: Resetting to Pad ---")
			return
			
		var active_row = flight_rows[current_row_index]
		process_rocket_physics(active_row, current_step_duration)

	# Smoothly blend to our calculated destinations frame-by-frame
	global_position = global_position.lerp(target_position, SMOOTHING_SPEED * delta)
	global_transform = global_transform.interpolate_with(target_transform, SMOOTHING_SPEED * delta)

func process_rocket_physics(row: Dictionary, dt: float) -> void:
	# --- 1. AXIS REMAPPING CORRECTION ---
	# We remap the Micro:bit's raw vectors to Godot's real dimensions:
	# Micro:bit's local Z (flight path) becomes Godot's local Y (Upward Altitude)
	# Micro:bit's local Y becomes Godot's local Z
	var raw_microbit_force = Vector3(row["acc_x"], row["acc_y"], row["acc_z"])
	
	var godot_mapped_accel = Vector3(
		0,  # Sideways drifting (Left / Right)
		-raw_microbit_force.y, # VERTICAL FLIGHT PATH (Inverting negative Z to positive climbing Y)
		0   # Forward tumbling (Forward / Backward)
	)
	
	# --- 2. GRAVITY CANCELLATION ---
	# Now that gravity is properly mapped onto the vertical Y axis, 
	# we subtract the baseline Earth rest force (-1023 mg) so it doesn't drift away idling
	var gravity_baseline = Vector3(0, 1023, 0)
	var net_flight_forces = godot_mapped_accel - gravity_baseline
	
	# Scale forces to manageable project units
	var real_acceleration = net_flight_forces / SCALE_FACTOR
	
	# --- 3. DYNAMIC TIME STEP INTEGRATION ---
	# Use the true changing time differences (dt) instead of a hardcoded 0.5 variable
	current_velocity += real_acceleration * dt
	target_position += current_velocity * dt
	
	# Hard ceiling fallback: Don't let numerical drift crash the model below your launch floor
	if target_position.y < 0:
		target_position.y = 0
		current_velocity.y = 0

	# --- 4. ORIENTATION TARGETING ---
	# Point the rocket's nose directly in the direction of the net physical forces acting on it
	var orientation_vector = real_acceleration.normalized()
	if orientation_vector.length() > 0.1:
		var temp_transform = global_transform
		if abs(orientation_vector.dot(Vector3.UP)) < 0.99:
			temp_transform = temp_transform.looking_at(global_position + orientation_vector, Vector3.UP)
		else:
			temp_transform = temp_transform.looking_at(global_position + orientation_vector, Vector3.FORWARD)
		target_transform = temp_transform

	print("Row: ", current_row_index, " | Height: ", snapped(target_position.y, 0.1), "m | Speed: ", snapped(current_velocity.y, 0.1), "m/s")
