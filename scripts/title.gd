extends Control

func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("#1f2922")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 18)
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(layout)

	var title := Label.new()
	title.text = "Foodbpb"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	layout.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "食材を並べて、料理を作ろう"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	layout.add_child(subtitle)

	var play_button := Button.new()
	play_button.text = "ゲームを始める"
	play_button.custom_minimum_size = Vector2(240, 56)
	play_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play_button.pressed.connect(_start_game)
	layout.add_child(play_button)

func _start_game() -> void:
	get_tree().change_scene_to_file("res://scenes/game_board.tscn")
