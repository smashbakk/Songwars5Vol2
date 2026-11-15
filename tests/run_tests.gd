extends SceneTree

# Property of LiveLayer Technology LLC.
# Run with: godot4 --headless --path . --script tests/run_tests.gd

func _initialize() -> void:
	var failures: Array = []
	var suite_paths: Array = ["res://tests/test_combat.gd", "res://tests/test_air_combat.gd", "res://tests/test_cpu_mobility.gd", "res://tests/test_damage_pacing.gd", "res://tests/test_progression.gd"]
	for suite_path in suite_paths:
		var suite = load(suite_path)
		if suite == null or not suite.can_instantiate():
			failures.append("Could not load suite: " + suite_path)
			continue
		var result: Array = suite.run()
		failures.append_array(result)
	if failures.is_empty():
		print("PASS — all fight simulation and progression checks passed.")
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL — " + str(failure))
		printerr("FAILED: %d checks." % failures.size())
		quit(1)
