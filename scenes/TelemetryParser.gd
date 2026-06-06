class_name TelemetryParser
extends RefCounted

# Parses a micro:bit flight telemetry file and returns an array of dictionaries.
# Because it is marked 'static', you do not need to call .new() to use it!
static func parse_telemetry_file(path: String) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	
	# Verify path safety
	if not FileAccess.file_exists(path):
		push_error("TelemetryParser Error: Target file not found at " + path)
		return records
		
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("TelemetryParser Error: Unable to open read-stream for file: " + path)
		return records
		
	# Extract and process the header row
	var headers = file.get_csv_line()
	if headers.size() < 7:
		push_error("TelemetryParser Error: CSV columns are malformed or insufficient.")
		file.close()
		return records
		
	# Dynamic column index lookup to prevent issues if column order shifts
	var idx_time = headers.find("Time (seconds)")
	var idx_ax = headers.find("acc_x")
	var idx_ay = headers.find("acc_y")
	var idx_az = headers.find("acc_z")
	var idx_mag = headers.find("mag")
	var idx_sound = headers.find("sound")
	var idx_temp = headers.find("temp")
	
	# Fallback safety checking
	if idx_time == -1 or idx_ax == -1 or idx_ay == -1 or idx_az == -1:
		push_warning("TelemetryParser Warning: Exact headers not matched. Using default position indexes.")
		idx_time = 0
		idx_ax = 1
		idx_ay = 2
		idx_az = 3
		idx_mag = 4
		idx_sound = 5
		idx_temp = 6

	# Read data lines until the end of file (EOF) buffer boundary
	while not file.eof_reached():
		var columns = file.get_csv_line()
		
		# Guard clause: skip blank rows or trailing endlines
		if columns.size() < 7 or columns[0].strip_edges() == "":
			continue
			
		var ax = columns[idx_ax].to_float()
		var ay = columns[idx_ay].to_float()
		var az = columns[idx_az].to_float()
		
		# Pre-package raw readings into useful structures
		# Inside the parser loop, where you construct the data_snapshot dictionary:
		var data_snapshot = {
			"time": columns[idx_time].to_float(),
			"acc_x": ax,
			"acc_y": ay,
			"acc_z": az,
			# NEW: Calculate overall G-Force magnitude regardless of tilt orientation
			"total_acc": sqrt(ax*ax + ay*ay + az*az),
			"mag": columns[idx_mag].to_float(),
			"sound": columns[idx_sound].to_float(),
			"temp": columns[idx_temp].to_float()
		}
		
		records.append(data_snapshot)
		
		
	file.close()
	print("TelemetryParser: Successfully loaded ", records.size(), " data lines.")
	return records
