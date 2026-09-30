extends SceneTree

const Importer = preload("res://ui/theme/palette_importer.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2 or args.size() > 3:
		printerr("Usage: godot --headless --path . --script res://ui/theme/tools/import_palette.gd -- input.hex output.tres [Name]")
		quit(1)
		return
	var result := Importer.import_file(args[0], args[1], args[2] if args.size() == 3 else args[1].get_file().get_basename())
	if not result.get("error", "").is_empty():
		printerr(result.error)
		quit(1)
		return
	print("Palette created: " + args[1])
	quit()
