extends SceneProbe
## The no-code probe (run_probe.py --scene ... --seconds ...): opens a scene,
## lets it run, and reports its tree, what has focus, any errors, and a
## screenshot when the run has a window. A quick "does it load and what's on
## screen" before writing a real probe.

func run() -> void:
	var path := arg("scene", ProjectSettings.get_setting("application/run/main_scene", ""))
	var scene := await open(path)
	if not check(scene != null, "scene %s opened" % path): return
	await seconds(float(arg("seconds", "2")))
	record("scene", path)
	record("focus", focus_path())
	record("tree", tree_text(scene, int(arg("depth", "4"))))
	await screenshot("smoke")
