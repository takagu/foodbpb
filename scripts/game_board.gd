extends Control

const BOARD_SIZE := 5
const CARD_SIZE := Vector2(140, 76)
const DECK_COPIES_PER_INGREDIENT := 8
const CARD_DATA_PATH := "res://data/cards.json"
const RECIPE_DATA_PATH := "res://data/recipes.json"

var card_definitions: Dictionary = {}
var recipes: Array = []
var deck: Array[String] = []
var board_cards: Dictionary = {}
var fridge_card_id: String = ""
var random := RandomNumberGenerator.new()
var grid: GridContainer
var status_label: Label
var deck_label: Label
var hand_label: Label
var hand_container: HBoxContainer
var fridge_label: Label
var fridge_slot_button: Button
var trash_slot_button: Button
var cook_button: Button
var board_cell_buttons: Dictionary = {}
var highlighted_positions: Dictionary = {}
var drag_source: Dictionary = {}
var drag_start_position := Vector2.ZERO
var deck_drag_pending := false
var drag_in_progress := false
var drag_preview: PanelContainer
var hand_scroll: ScrollContainer
var deck_draw_button: Button

func _ready() -> void:
	_load_game_data()
	_build_deck()
	_build_ui()
	_refresh_board()
	_update_status("山札や手札のカードをドラッグして移動します。材料が光ったら「料理」を押します。")

func _load_game_data() -> void:
	var card_file := FileAccess.open(CARD_DATA_PATH, FileAccess.READ)
	if card_file == null:
		push_error("カードデータを開けません: " + CARD_DATA_PATH)
		return
	var card_text := card_file.get_as_text().trim_prefix("\uFEFF")
	var card_json: Variant = JSON.parse_string(card_text)
	if card_json is Dictionary:
		card_definitions = card_json.get("cards", {})

	var recipe_file := FileAccess.open(RECIPE_DATA_PATH, FileAccess.READ)
	if recipe_file == null:
		push_error("レシピデータを開けません: " + RECIPE_DATA_PATH)
		return
	var recipe_text := recipe_file.get_as_text().trim_prefix("\uFEFF")
	var recipe_json: Variant = JSON.parse_string(recipe_text)
	if recipe_json is Array:
		recipes = recipe_json

func _build_deck() -> void:
	for card_id_variant in card_definitions.keys():
		var card_id := str(card_id_variant)
		var card: Dictionary = card_definitions[card_id]
		if str(card.get("kind", "")) != "ingredient":
			continue
		var copies := int(card.get("deck_copies", 8))
		for _copy in range(copies):
			deck.append(card_id)
	random.randomize()
	deck.shuffle()
func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("#1f2922")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var outer := MarginContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_left", 28)
	outer.add_theme_constant_override("margin_top", 20)
	outer.add_theme_constant_override("margin_right", 28)
	outer.add_theme_constant_override("margin_bottom", 20)
	add_child(outer)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	outer.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)

	var heading := Label.new()
	heading.text = "Foodbpb — 料理パズル"
	heading.add_theme_font_size_override("font_size", 28)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(heading)

	cook_button = Button.new()
	cook_button.text = "料理"
	cook_button.custom_minimum_size = Vector2(130, 44)
	cook_button.add_theme_font_size_override("font_size", 20)
	cook_button.pressed.connect(_cook_board)
	header.add_child(cook_button)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	status_label.clip_text = true
	status_label.custom_minimum_size.y = 30
	column.add_child(status_label)

	grid = GridContainer.new()
	grid.columns = BOARD_SIZE
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	column.add_child(grid)

	var storage_row := HBoxContainer.new()
	storage_row.add_theme_constant_override("separation", 12)
	column.add_child(storage_row)

	var fridge_panel := _make_storage_panel(Color("#151515"))
	storage_row.add_child(fridge_panel)
	var fridge_content := VBoxContainer.new()
	fridge_content.add_theme_constant_override("separation", 6)
	fridge_panel.add_child(fridge_content)
	fridge_label = Label.new()
	fridge_label.text = "冷蔵庫"
	fridge_label.add_theme_font_size_override("font_size", 16)
	fridge_content.add_child(fridge_label)
	fridge_slot_button = _make_storage_button("空き")
	fridge_content.add_child(fridge_slot_button)

	var right_spacer := Control.new()
	right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	storage_row.add_child(right_spacer)

	var trash_panel := _make_storage_panel(Color("#151515"))
	storage_row.add_child(trash_panel)
	var trash_content := VBoxContainer.new()
	trash_content.add_theme_constant_override("separation", 6)
	trash_panel.add_child(trash_content)
	var trash_title := Label.new()
	trash_title.text = "ゴミ箱"
	trash_title.add_theme_font_size_override("font_size", 16)
	trash_content.add_child(trash_title)
	trash_slot_button = _make_storage_button("カードを捨てる")
	trash_content.add_child(trash_slot_button)

	var deck_panel := _make_storage_panel(Color("#151515"))
	storage_row.add_child(deck_panel)
	var deck_content := VBoxContainer.new()
	deck_content.add_theme_constant_override("separation", 6)
	deck_panel.add_child(deck_content)
	deck_label = Label.new()
	deck_label.text = "山札"
	deck_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	deck_label.add_theme_font_size_override("font_size", 16)
	deck_content.add_child(deck_label)
	deck_draw_button = _make_storage_button("カードを引く")
	deck_content.add_child(deck_draw_button)

	hand_label = Label.new()
	hand_label.text = "手札（カードをドラッグして移動）"
	column.add_child(hand_label)

	hand_scroll = ScrollContainer.new()
	hand_scroll.custom_minimum_size = Vector2(0, 94)
	hand_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(hand_scroll)

	hand_container = HBoxContainer.new()
	hand_container.add_theme_constant_override("separation", 8)
	hand_scroll.add_child(hand_container)
	_update_deck_count()
	_update_storage_slots()

func _make_storage_panel(panel_color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = CARD_SIZE + Vector2(24, 50)
	var style := StyleBoxFlat.new()
	style.bg_color = panel_color
	style.border_color = Color("#d6c9a8")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_top = 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	return panel
func _make_storage_button(label_text: String) -> Button:
	var button := Button.new()
	button.text = label_text
	_style_card_button(button, Color("#080808"))
	return button
func _refresh_board() -> void:
	for child in grid.get_children():
		child.queue_free()
	board_cell_buttons.clear()
	highlighted_positions.clear()
	var recipe_matches := _find_board_recipe_matches()
	for recipe_match in recipe_matches:
		for position_variant in recipe_match["positions"]:
			highlighted_positions[position_variant] = true
	if cook_button != null:
		cook_button.disabled = recipe_matches.is_empty()
	for y in range(BOARD_SIZE):
		for x in range(BOARD_SIZE):
			var position := Vector2i(x, y)
			var cell := Button.new()
			cell.custom_minimum_size = CARD_SIZE
			cell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			cell.add_theme_font_size_override("font_size", 17)
			var card_id: String = board_cards.get(position, "")
			if card_id.is_empty():
				cell.text = "空き"
				_style_card_button(cell, Color("#080808"))
			else:
				var card: Dictionary = card_definitions.get(card_id, {})
				var card_color := Color(str(card.get("color", "#ffffff")))
				cell.text = str(card.get("name", card_id))
				cell.tooltip_text = _build_recipe_tooltip(card_id)
				_style_card_button(cell, card_color, highlighted_positions.has(position))
			grid.add_child(cell)
			board_cell_buttons[position] = cell

func _style_card_button(button: Button, card_color: Color, glowing := false) -> void:
	button.custom_minimum_size = CARD_SIZE
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	var normal_style := _make_board_card_style(card_color, glowing)
	var hover_style := normal_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = card_color.lightened(0.12)
	var pressed_style := normal_style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = card_color.darkened(0.12)
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)

func _make_board_card_style(card_color: Color, glowing: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = card_color
	style.set_corner_radius_all(8)
	if glowing:
		style.border_color = Color("#8DFF9A")
		style.set_border_width_all(4)
		style.shadow_color = Color(0.25, 1.0, 0.38, 0.9)
		style.shadow_size = 9
		style.shadow_offset = Vector2.ZERO
	else:
		style.border_color = card_color.lightened(0.28)
		style.set_border_width_all(2)
	return style
func _draw_card() -> void:
	if deck.is_empty():
		_update_status("山札がありません。盤面のカードはそのまま残ります。")
		return
	var card_id: String = deck.pop_back()
	_add_card_to_hand(card_id)
	_update_deck_count()
	_update_status("引いたカード: %s。手札からカードを選んでください。" % card_definitions.get(card_id, {}).get("name", card_id))

func _add_card_to_hand(card_id: String) -> Button:
	var card: Dictionary = card_definitions.get(card_id, {})
	var card_button := Button.new()
	card_button.text = str(card.get("name", card_id))
	card_button.tooltip_text = _build_recipe_tooltip(card_id)
	card_button.set_meta("card_id", card_id)
	card_button.toggle_mode = false
	_style_card_button(card_button, Color(str(card.get("color", "#ffffff"))))
	hand_container.add_child(card_button)
	return card_button

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if deck_drag_pending and not drag_in_progress and event.position.distance_to(drag_start_position) > 10.0:
			drag_in_progress = true
			_show_drag_preview(str(drag_source.get("card_id", "")), event.position)
		if drag_in_progress:
			if is_instance_valid(drag_preview):
				drag_preview.position = event.position + Vector2(12, 12)
			get_viewport().set_input_as_handled()
		return

	if not event is InputEventMouseButton:
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		if drag_in_progress or deck_drag_pending:
			return
		var source := _get_drag_source_at(event.position)
		if source.is_empty():
			return
		drag_source = source
		drag_start_position = event.position
		if str(source["zone"]) == "deck":
			deck_drag_pending = true
		else:
			drag_in_progress = true
			_show_drag_preview(str(source["card_id"]), event.position)
		get_viewport().set_input_as_handled()
		return

	if deck_drag_pending and not drag_in_progress:
		_draw_card()
		_clear_drag_state()
		get_viewport().set_input_as_handled()
	elif drag_in_progress:
		var destination := _get_drop_target_at(event.position)
		if not destination.is_empty():
			_perform_drag_drop(drag_source, destination)
		_clear_drag_state()
		get_viewport().set_input_as_handled()

func _board_position_at(screen_position: Vector2) -> Vector2i:
	for position_variant in board_cell_buttons.keys():
		var position: Vector2i = position_variant
		var cell: Button = board_cell_buttons[position]
		if cell.get_global_rect().has_point(screen_position):
			return position
	return Vector2i(-1, -1)
func _get_drag_source_at(screen_position: Vector2) -> Dictionary:
	var board_position := _board_position_at(screen_position)
	if board_position.x >= 0 and board_cards.has(board_position):
		return {"zone": "board", "card_id": str(board_cards[board_position]), "position": board_position}

	if hand_scroll.get_global_rect().has_point(screen_position):
		for child in hand_container.get_children():
			if child is Button and child.get_global_rect().has_point(screen_position):
				return {"zone": "hand", "card_id": str(child.get_meta("card_id", "")), "control": child}

	if not fridge_card_id.is_empty() and fridge_slot_button.get_global_rect().has_point(screen_position):
		return {"zone": "fridge", "card_id": fridge_card_id}

	if not deck.is_empty() and deck_draw_button.get_global_rect().has_point(screen_position):
		return {"zone": "deck", "card_id": deck.back()}
	return {}

func _get_drop_target_at(screen_position: Vector2) -> Dictionary:
	var board_position := _board_position_at(screen_position)
	if board_position.x >= 0:
		return {"zone": "board", "position": board_position}
	if fridge_slot_button.get_global_rect().has_point(screen_position):
		return {"zone": "fridge"}
	if trash_slot_button.get_global_rect().has_point(screen_position):
		return {"zone": "trash"}
	if hand_scroll.get_global_rect().has_point(screen_position):
		for child in hand_container.get_children():
			if child is Button and child.get_global_rect().has_point(screen_position):
				return {"zone": "hand", "control": child}
		return {"zone": "hand"}
	return {}

func _show_drag_preview(card_id: String, screen_position: Vector2) -> void:
	_clear_drag_preview()
	var card: Dictionary = card_definitions.get(card_id, {})
	drag_preview = PanelContainer.new()
	drag_preview.custom_minimum_size = CARD_SIZE
	drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_preview.z_index = 100
	var preview_style := _make_board_card_style(Color(str(card.get("color", "#343434"))), false)
	preview_style.border_color = Color("#F6E87D")
	drag_preview.add_theme_stylebox_override("panel", preview_style)
	var preview_label := Label.new()
	preview_label.text = str(card.get("name", card_id))
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview_label.add_theme_color_override("font_color", Color.WHITE)
	drag_preview.add_child(preview_label)
	drag_preview.position = screen_position + Vector2(12, 12)
	add_child(drag_preview)

func _clear_drag_preview() -> void:
	if is_instance_valid(drag_preview):
		drag_preview.queue_free()
	drag_preview = null

func _clear_drag_state() -> void:
	drag_in_progress = false
	deck_drag_pending = false
	drag_source.clear()
	_clear_drag_preview()

func _perform_drag_drop(source: Dictionary, destination: Dictionary) -> void:
	var source_zone := str(source.get("zone", ""))
	var destination_zone := str(destination.get("zone", ""))
	var card_id := str(source.get("card_id", ""))
	if source_zone == "deck":
		if destination_zone == "hand":
			_draw_card()
		else:
			_update_status("山札のカードは手札へドラッグしてください。")
		return
	if source_zone == "hand" and destination_zone == "hand":
		var source_control: Button = source.get("control")
		var destination_control: Button = destination.get("control")
		if is_instance_valid(source_control) and is_instance_valid(destination_control) and source_control != destination_control:
			hand_container.move_child(source_control, destination_control.get_index())
		return

	match source_zone:
		"hand":
			_perform_hand_drop(card_id, source, destination)
		"board":
			_perform_board_drop(card_id, source, destination)
		"fridge":
			_perform_fridge_drop(card_id, destination)

func _perform_hand_drop(card_id: String, source: Dictionary, destination: Dictionary) -> void:
	var source_control: Button = source.get("control")
	var destination_zone := str(destination.get("zone", ""))
	match destination_zone:
		"board":
			var target_position: Vector2i = destination["position"]
			var displaced_card := str(board_cards.get(target_position, ""))
			board_cards[target_position] = card_id
			if is_instance_valid(source_control):
				source_control.queue_free()
			if not displaced_card.is_empty():
				_add_card_to_hand(displaced_card)
			_refresh_board()
			_update_status("カードを盤面へ移動しました。")
		"fridge":
			if not fridge_card_id.is_empty():
				_update_status("冷蔵庫は一杯です。カードを盤面へ置くか、先に取り出してください。")
				return
			fridge_card_id = card_id
			if is_instance_valid(source_control):
				source_control.queue_free()
			_update_storage_slots()
			_update_status("カードを冷蔵庫へ移動しました。")
		"trash":
			if is_instance_valid(source_control):
				source_control.queue_free()
			_update_status("カードをゴミ箱へ捨てました。")

func _perform_board_drop(card_id: String, source: Dictionary, destination: Dictionary) -> void:
	var source_position: Vector2i = source["position"]
	var destination_zone := str(destination.get("zone", ""))
	match destination_zone:
		"board":
			_move_board_card(source_position, destination["position"])
		"fridge":
			var displaced_card := fridge_card_id
			fridge_card_id = card_id
			if displaced_card.is_empty():
				board_cards.erase(source_position)
			else:
				board_cards[source_position] = displaced_card
			_refresh_board()
			_update_storage_slots()
		"trash":
			board_cards.erase(source_position)
			_refresh_board()
			_update_status("カードをゴミ箱へ捨てました。")
		"hand":
			board_cards.erase(source_position)
			_add_card_to_hand(card_id)
			_refresh_board()
			_update_status("カードを手札へ移動しました。")

func _perform_fridge_drop(card_id: String, destination: Dictionary) -> void:
	var destination_zone := str(destination.get("zone", ""))
	match destination_zone:
		"board":
			var target_position: Vector2i = destination["position"]
			var displaced_card := str(board_cards.get(target_position, ""))
			board_cards[target_position] = card_id
			fridge_card_id = displaced_card
			_refresh_board()
			_update_storage_slots()
		"trash":
			fridge_card_id = ""
			_update_storage_slots()
			_update_status("冷蔵庫のカードをゴミ箱へ捨てました。")
		"hand":
			_update_status("冷蔵庫のカードは手札へ戻せません。盤面かゴミ箱へ移動してください。")

func _move_board_card(source: Vector2i, destination: Vector2i) -> void:
	if source == destination or not board_cards.has(source):
		return
	var moving_card: String = board_cards[source]
	if board_cards.has(destination):
		var displaced_card: String = board_cards[destination]
		board_cards[destination] = moving_card
		board_cards[source] = displaced_card
	else:
		board_cards.erase(source)
		board_cards[destination] = moving_card
	_refresh_board()
	_update_status("カードを盤面上で移動しました。")
func _build_recipe_tooltip(card_id: String) -> String:
	var card_name := str(card_definitions.get(card_id, {}).get("name", card_id))
	var tooltip := "%s を使うレシピ" % card_name
	var found_recipe := false
	for recipe_variant in recipes:
		if not recipe_variant is Dictionary:
			continue
		var ingredients: Array = recipe_variant.get("ingredients", [])
		if not ingredients.has(card_id):
			continue
		var ingredient_names := ""
		for index in range(ingredients.size()):
			if index > 0:
				ingredient_names += " + "
			var ingredient_id := str(ingredients[index])
			ingredient_names += str(card_definitions.get(ingredient_id, {}).get("name", ingredient_id))
		var result_id := str(recipe_variant.get("result", ""))
		var result_name := str(card_definitions.get(result_id, {}).get("name", result_id))
		var max_distance := int(recipe_variant.get("max_distance", 1))
		tooltip += "\n・%s ← %s（距離%dマス以内）" % [result_name, ingredient_names, max_distance]
		found_recipe = true
	if not found_recipe:
		tooltip += "\nこのカードを使うレシピはありません。"
	return tooltip
func _cook_board() -> void:
	var recipe_matches := _find_board_recipe_matches()
	if recipe_matches.is_empty():
		_update_status("合成できるレシピがありません。")
		return
	var consumed_positions: Dictionary = {}
	var cooked_count := 0
	for recipe_match in recipe_matches:
		var positions: Array = recipe_match["positions"]
		var can_cook := true
		for position_variant in positions:
			if consumed_positions.has(position_variant) or not board_cards.has(position_variant):
				can_cook = false
				break
		if not can_cook:
			continue
		var anchor: Vector2i = recipe_match["anchor"]
		var result_id: String = recipe_match["result"]
		for position_variant in positions:
			var position: Vector2i = position_variant
			consumed_positions[position] = true
			if position != anchor:
				board_cards.erase(position)
		board_cards[anchor] = result_id
		cooked_count += 1
	if cooked_count == 0:
		_update_status("合成対象のカードが重なっているため、料理できませんでした。")
		return
	_refresh_board()
	_update_status("%d品の料理が完成しました。" % cooked_count)

func _find_board_recipe_matches() -> Array[Dictionary]:
	var matches: Array[Dictionary] = []
	var known_signatures: Dictionary = {}
	for recipe_variant in recipes:
		if not recipe_variant is Dictionary:
			continue
		var ingredients: Array = recipe_variant.get("ingredients", [])
		if ingredients.is_empty():
			continue
		for position_variant in board_cards.keys():
			var anchor: Vector2i = position_variant
			var anchor_card_id := str(board_cards[anchor])
			if not ingredients.has(anchor_card_id):
				continue
			var recipe_match: Dictionary = _find_recipe_match_at(anchor, recipe_variant)
			if recipe_match.is_empty():
				continue
			var signature_parts: Array[String] = []
			for match_position in recipe_match["positions"]:
				var match_position_vector: Vector2i = match_position
				signature_parts.append("%d,%d" % [match_position_vector.x, match_position_vector.y])
			signature_parts.sort()
			var signature := str(recipe_variant.get("result", ""))
			for signature_part in signature_parts:
				signature += "|" + signature_part
			if known_signatures.has(signature):
				continue
			known_signatures[signature] = true
			matches.append(recipe_match)
	return matches

func _find_recipe_match_at(anchor: Vector2i, recipe: Dictionary) -> Dictionary:
	if not board_cards.has(anchor):
		return {}
	var ingredients: Array = recipe.get("ingredients", [])
	var anchor_card_id := str(board_cards[anchor])
	var anchor_ingredient_index := ingredients.find(anchor_card_id)
	if anchor_ingredient_index < 0:
		return {}
	var matched_positions: Array = [anchor]
	for ingredient_index in range(ingredients.size()):
		if ingredient_index == anchor_ingredient_index:
			continue
		var ingredient_id := str(ingredients[ingredient_index])
		var match_found := false
		for candidate_variant in board_cards.keys():
			var candidate: Vector2i = candidate_variant
			if matched_positions.has(candidate):
				continue
			if _grid_distance(anchor, candidate) > int(recipe.get("max_distance", 1)):
				continue
			if str(board_cards[candidate]) == ingredient_id:
				matched_positions.append(candidate)
				match_found = true
				break
		if not match_found:
			return {}
	return {
		"anchor": anchor,
		"positions": matched_positions,
		"result": str(recipe.get("result", ""))
	}
func _grid_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

func _update_deck_count() -> void:
	if deck_label != null:
		deck_label.text = "山札: %d枚" % deck.size()
	if deck_draw_button != null:
		deck_draw_button.disabled = deck.is_empty()
		_style_card_button(deck_draw_button, Color("#080808"))
	if trash_slot_button != null:
		_style_card_button(trash_slot_button, Color("#080808"))

func _update_storage_slots() -> void:
	if fridge_slot_button == null:
		return
	if fridge_card_id.is_empty():
		fridge_label.text = "冷蔵庫"
		fridge_slot_button.text = "空き"
		fridge_slot_button.tooltip_text = "カードをここへドラッグして保存"
		_style_card_button(fridge_slot_button, Color("#080808"))
	else:
		var card: Dictionary = card_definitions.get(fridge_card_id, {})
		fridge_label.text = "冷蔵庫（1/1）"
		fridge_slot_button.text = str(card.get("name", fridge_card_id))
		fridge_slot_button.tooltip_text = "盤面かゴミ箱へドラッグできます。手札には戻せません。\n" + _build_recipe_tooltip(fridge_card_id)
		_style_card_button(fridge_slot_button, Color(str(card.get("color", "#ffffff"))))
func _update_status(message: String) -> void:
	if status_label != null:
		status_label.text = message
