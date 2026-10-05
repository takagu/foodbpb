extends Control

const BOARD_SIZE := 5
const DECK_COPIES_PER_INGREDIENT := 8
const CARD_DATA_PATH := "res://data/cards.json"
const RECIPE_DATA_PATH := "res://data/recipes.json"

var card_definitions: Dictionary = {}
var recipes: Array = []
var deck: Array[String] = []
var board_cards: Dictionary = {}
var fridge_card_id: String = ""
var selected_card: String = ""
var random := RandomNumberGenerator.new()
var grid: GridContainer
var status_label: Label
var deck_label: Label
var hand_label: Label
var hand_container: HBoxContainer
var fridge_label: Label
var fridge_slot_button: Button
var trash_slot_button: Button
var fridge_card_selected := false

func _ready() -> void:
	_load_game_data()
	_build_deck()
	_build_ui()
	_refresh_board()
	_update_status("「カードを引く」で食材を引き、カードを選んで空きマスをクリックしてください。")

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

	var heading := Label.new()
	heading.text = "Foodbpb — 料理パズル"
	heading.add_theme_font_size_override("font_size", 28)
	column.add_child(heading)

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
	fridge_slot_button.pressed.connect(_on_fridge_slot_pressed)
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
	trash_slot_button.pressed.connect(_on_trash_slot_pressed)
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
	var draw_button := _make_storage_button("カードを引く")
	draw_button.pressed.connect(_draw_card)
	deck_content.add_child(draw_button)

	hand_label = Label.new()
	hand_label.text = "手札（カードを選んで配置先をクリック）"
	column.add_child(hand_label)

	var hand_scroll := ScrollContainer.new()
	hand_scroll.custom_minimum_size = Vector2(0, 68)
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
	panel.custom_minimum_size = Vector2(220, 112)
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
	button.custom_minimum_size = Vector2(190, 62)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#080808")
	normal.border_color = Color("#777777")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#202020")
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#353535")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	return button
func _refresh_board() -> void:
	for child in grid.get_children():
		child.queue_free()
	for y in range(BOARD_SIZE):
		for x in range(BOARD_SIZE):
			var position := Vector2i(x, y)
			var cell := Button.new()
			cell.custom_minimum_size = Vector2(112, 58)
			cell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			cell.add_theme_font_size_override("font_size", 17)
			var card_id: String = board_cards.get(position, "")
			if card_id.is_empty():
				cell.text = "·"
				cell.modulate = Color("#c8d1c3")
			else:
				var card: Dictionary = card_definitions.get(card_id, {})
				cell.text = str(card.get("name", card_id))
				cell.tooltip_text = _build_recipe_tooltip(card_id)
				cell.modulate = Color(str(card.get("color", "#ffffff")))
			cell.pressed.connect(_on_cell_pressed.bind(position))
			grid.add_child(cell)

func _draw_card() -> void:
	if deck.is_empty():
		_update_status("山札がありません。盤面のカードはそのまま残ります。")
		return
	var card_id: String = deck.pop_back()
	_add_card_to_hand(card_id)
	_update_deck_count()
	_update_status("引いたカード: %s。手札からカードを選んでください。" % card_definitions.get(card_id, {}).get("name", card_id))

func _add_card_to_hand(card_id: String) -> void:
	var card: Dictionary = card_definitions.get(card_id, {})
	var card_button := Button.new()
	card_button.text = str(card.get("name", card_id))
	card_button.tooltip_text = _build_recipe_tooltip(card_id)
	card_button.set_meta("card_id", card_id)
	card_button.custom_minimum_size = Vector2(140, 48)
	card_button.toggle_mode = true
	card_button.modulate = Color(str(card.get("color", "#ffffff")))
	card_button.pressed.connect(_select_card.bind(card_id, card_button))
	hand_container.add_child(card_button)
func _select_card(card_id: String, card_button: Button) -> void:
	selected_card = card_id
	fridge_card_selected = false
	for child in hand_container.get_children():
		if child is Button:
			child.button_pressed = false
	card_button.button_pressed = true
	_update_storage_slots()
	_update_status("%s を選択中です。盤面、冷蔵庫、ゴミ箱のいずれかをクリックしてください。" % card_definitions.get(card_id, {}).get("name", card_id))

func _on_cell_pressed(position: Vector2i) -> void:
	if selected_card.is_empty() and not fridge_card_selected:
		_update_status("手札か冷蔵庫のカードを選んでください。")
		return
	if board_cards.has(position):
		_update_status("そこにはカードがあります。空きマスを選んでください。")
		return
	var placed_id: String
	if fridge_card_selected:
		placed_id = fridge_card_id
		fridge_card_id = ""
		fridge_card_selected = false
	else:
		placed_id = selected_card
		_remove_card_from_hand(placed_id)
		selected_card = ""
	board_cards[position] = placed_id
	_update_storage_slots()
	var dish_name := _resolve_recipes(position)
	_refresh_board()
	if dish_name.is_empty():
		_update_status("%s を配置しました。" % card_definitions.get(placed_id, {}).get("name", placed_id))
	else:
		_update_status("レシピ完成！ %s ができました。" % dish_name)

func _remove_card_from_hand(card_id: String) -> void:
	for child in hand_container.get_children():
		if child is Button and str(child.get_meta("card_id", "")) == card_id:
			child.queue_free()
			return

func _on_fridge_slot_pressed() -> void:
	if not fridge_card_id.is_empty():
		selected_card = ""
		fridge_card_selected = not fridge_card_selected
		for child in hand_container.get_children():
			if child is Button:
				child.button_pressed = false
		_update_storage_slots()
		if fridge_card_selected:
			_update_status("冷蔵庫のカードを選択中です。盤面に置くか、ゴミ箱をクリックして捨ててください。")
		else:
			_update_status("冷蔵庫の選択を解除しました。")
		return
	if selected_card.is_empty():
		_update_status("冷蔵庫に保存する手札カードを選んでください。")
		return
	fridge_card_id = selected_card
	_remove_card_from_hand(selected_card)
	selected_card = ""
	fridge_card_selected = false
	_update_storage_slots()
	_update_status("カードを冷蔵庫に保存しました。冷蔵庫カードをクリックすると盤面かゴミ箱へ移動できます。")

func _on_trash_slot_pressed() -> void:
	if fridge_card_selected and not fridge_card_id.is_empty():
		fridge_card_id = ""
		fridge_card_selected = false
		_update_storage_slots()
		_update_status("冷蔵庫のカードをゴミ箱へ捨てました。")
		return
	if not selected_card.is_empty():
		var discarded_id := selected_card
		_remove_card_from_hand(discarded_id)
		selected_card = ""
		_update_storage_slots()
		_update_status("%s をゴミ箱へ捨てました。" % card_definitions.get(discarded_id, {}).get("name", discarded_id))
		return
	_update_status("捨てるカードを手札か冷蔵庫から選んでください。")

func _update_storage_slots() -> void:
	if fridge_slot_button == null:
		return
	if fridge_card_id.is_empty():
		fridge_label.text = "冷蔵庫"
		fridge_slot_button.text = "空き"
		fridge_slot_button.tooltip_text = ''
	else:
		fridge_label.text = "冷蔵庫（選択中）" if fridge_card_selected else "冷蔵庫"
		fridge_slot_button.text = str(card_definitions.get(fridge_card_id, {}).get("name", fridge_card_id))
		fridge_slot_button.tooltip_text = _build_recipe_tooltip(fridge_card_id)
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
func _resolve_recipes(placed_at: Vector2i) -> String:
	for recipe_variant in recipes:
		if not recipe_variant is Dictionary:
			continue
		var ingredients: Array = recipe_variant.get("ingredients", [])
		if ingredients.is_empty():
			continue
		var max_distance := int(recipe_variant.get("max_distance", 1))
		var matched_positions: Array = []
		var recipe_matches := true
		for ingredient_variant in ingredients:
			var ingredient_id := str(ingredient_variant)
			var match_found := false
			for candidate_variant in board_cards.keys():
				var candidate: Vector2i = candidate_variant
				if matched_positions.has(candidate):
					continue
				if candidate != placed_at and _grid_distance(placed_at, candidate) > max_distance:
					continue
				if str(board_cards[candidate]) == ingredient_id:
					matched_positions.append(candidate)
					match_found = true
					break
			if not match_found:
				recipe_matches = false
				break
		if not recipe_matches:
			continue
		var result_id := str(recipe_variant.get("result", ""))
		if result_id.is_empty() or not card_definitions.has(result_id):
			continue
		for consumed_position in matched_positions:
			if consumed_position != placed_at:
				board_cards.erase(consumed_position)
		board_cards[placed_at] = result_id
		return str(card_definitions[result_id].get("name", result_id))
	return ""

func _grid_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

func _update_deck_count() -> void:
	if deck_label != null:
		deck_label.text = "山札: %d枚" % deck.size()
func _update_status(message: String) -> void:
	if status_label != null:
		status_label.text = message
