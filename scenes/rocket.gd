extends Node3D

# Configuration constants 
const GRAVITY_BASELINE: float = 1000.0  # Total magnitude baseline at rest (milli-g's)
const LAUNCH_THRESHOLD: float = 250.0   # Deviation from 1G required to launch flight
const FLIGHT_SPEED: float = 15.0        # Vertical speed tracking scalar

# Tuning parameters for physics and tilt reactivity
const TILT_SENSITIVITY: float = 0.05    # Controls rocket tilt angles
const VELOCITY_SMOOTHING: float = 0.15  # Smooths out raw step-changes in speed vectors
const ROTATION_SMOOTHING: float = 0.10  # NEW: Controls tilt sluggishness (Lower = smoother/heavier, Higher = snappier)

enum RocketState { IDLE, LAUNCHING, FALLING }

var current_state: int = RocketState.IDLE
var telemetry_data: Array[Dictionary] = []
var current_row_index: int = 0

var playback_timer: float = 0.0
var time_between_samples: float = 0.1 

# Processing vectors
var target_velocity: Vector3 = Vector3.ZERO
var current_velocity: Vector3 = Vector3.ZERO
var target_rotation: Vector3 = Vector3.ZERO # Track target Euler angles globally

# Node references
@onready var rocket_pivot: Node3D = $RocketPivot

func _ready() -> void:
	telemetry_data = TelemetryParser.parse_telemetry_file("res://testing/mock_flight.csv")
	if telemetry_data.is_empty():
		set_physics_process(false)
		push_error("Rocket Error: No telemetry data found.")
		return
		
	if not has_node("RocketPivot"):
		push_error("Rocket Error: Child node 'RocketPivot' missing!")

func _physics_process(delta: float) -> void:
	# CRITICAL PLAYBACK SAFETY BLOCK
	if current_row_index >= telemetry_data.size():
		print("Telemetry playback finished! Forcing final touchdown.")
		transition_to_state(RocketState.IDLE)
		target_velocity = Vector3.ZERO
		current_velocity = Vector3.ZERO
		target_rotation = Vector3.ZERO
		position.y = 0.0 
		
		# Settle upright instantly upon shutdown
		rocket_pivot.basis = Basis.from_euler(Vector3.ZERO)
		set_physics_process(false)
		return

	playback_timer += delta
	if playback_timer >= time_between_samples:
		playback_timer = 0.0
		process_telemetry_snapshot(telemetry_data[current_row_index])
		current_row_index += 1
		
	# 1. POSITION TRACKING: Smoothly blend and apply current velocity translations 
	current_velocity = current_velocity.lerp(target_velocity, VELOCITY_SMOOTHING)
	position += current_velocity * delta
	
	# 2. NEW: CONTINUOUS ROTATION SMOOTHING (Slerp Filter)
	# Convert our target Euler rotation vector into an orientation Basis matrix
	var target_basis: Basis = Basis.from_euler(target_rotation)
	# Spherical interpolation prevents sudden shaking or snapping when raw sensor values spike
	rocket_pivot.basis = rocket_pivot.basis.slerp(target_basis, ROTATION_SMOOTHING)
	
	# GLOBAL SAFETY RAIL: Keep the rocket locked above ground level on ALL frames
	if position.y < 0.0:
		position.y = 0.0
		if current_state == RocketState.FALLING:
			transition_to_state(RocketState.IDLE)

func process_telemetry_snapshot(snapshot: Dictionary) -> void:
	var total_acc: float = snapshot["total_acc"]
	var pure_motion: float = total_acc - GRAVITY_BASELINE
	
	var ax: float = snapshot["acc_x"]
	var az: float = snapshot["acc_z"]

	# 1. CYCLICAL STATE MACHINE 
	if current_state == RocketState.IDLE:
		if abs(pure_motion) > LAUNCH_THRESHOLD:
			transition_to_state(RocketState.LAUNCHING)
			
	elif current_state == RocketState.LAUNCHING:
		if pure_motion < -200.0: 
			transition_to_state(RocketState.FALLING)
			
	elif current_state == RocketState.FALLING:
		if abs(pure_motion) < 180.0 or current_row_index >= telemetry_data.size() - 3:
			transition_to_state(RocketState.IDLE)

	# 2. VECTOR ORIENTATION & DIRECTIONAL VELOCITY CALCULATIONS
	if current_state != RocketState.IDLE:
		var pitch_deg: float = clamp(az * TILT_SENSITIVITY, -45.0, 45.0)
		var roll_deg: float = clamp(-ax * TILT_SENSITIVITY, -45.0, 45.0)
		
		# Set the target rotation vector; _physics_process will smoothly interpolate towards this
		target_rotation = Vector3(deg_to_rad(pitch_deg), 0.0, deg_to_rad(roll_deg))
		
		# Trigonometric Projection: Map pitch/roll degrees to horizontal offsets
		var move_x: float = sin(deg_to_rad(roll_deg)) * FLIGHT_SPEED
		var move_z: float = sin(deg_to_rad(pitch_deg)) * FLIGHT_SPEED
		
		if current_state == RocketState.LAUNCHING:
			target_velocity = Vector3(move_x, FLIGHT_SPEED, move_z)
		elif current_state == RocketState.FALLING:
			target_velocity = Vector3(move_x * 0.5, -FLIGHT_SPEED * 0.4, move_z * 0.5)
			
	else:
		# Settle upright and completely zero out target forces
		target_rotation = Vector3.ZERO
		target_velocity = Vector3.ZERO

## Centralized state messaging helper to keep your console logging clean
func transition_to_state(new_state: int) -> void:
	if current_state == new_state:
		return
	current_state = new_state
	match current_state:
		RocketState.LAUNCHING: print("🚀 State: LAUNCHING")
		RocketState.FALLING:   print("🪂 State: FALLING")
		RocketState.IDLE:      print("🏡 State: IDLE (Touchdown)")
