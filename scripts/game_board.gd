extends Control

const BOARD_SIZE := 5
const DECK_COPIES_PER_INGREDIENT := 8
const CARD_DATA_PATH := "res://data/cards.json"
const RECIPE_DATA_PATH := "res://data/recipes.json"

var card_definitions: Dictionary = {}
var recipes: Array = []
var deck: Array[String] = []
var board_cards: Dictionary = {}
var selected_card: String = ""
var random := RandomNumberGenerator.new()
var grid: GridContainer
var status_label: Label
var deck_label: Label
var hand_label: Label
var hand_container: HBoxContainer

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
	for ingredient_id in ["potato", "meat"]:
		for _copy in range(DECK_COPIES_PER_INGREDIENT):
			deck.append(ingredient_id)
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
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size.y = 30
	column.add_child(status_label)

	grid = GridContainer.new()
	grid.columns = BOARD_SIZE
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	column.add_child(grid)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 12)
	column.add_child(controls)

	var draw_button := Button.new()
	draw_button.text = "カードを引く"
	draw_button.custom_minimum_size = Vector2(150, 42)
	draw_button.pressed.connect(_draw_card)
	controls.add_child(draw_button)

	deck_label = Label.new()
	deck_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	controls.add_child(deck_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(spacer)

	var fridge_label := Label.new()
	fridge_label.text = "冷蔵庫: 今後追加"
	fridge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fridge_label.modulate = Color(0.7, 0.75, 0.7)
	controls.add_child(fridge_label)

	hand_label = Label.new()
	hand_label.text = "手札（置くカードを選択）"
	column.add_child(hand_label)

	hand_container = HBoxContainer.new()
	hand_container.add_theme_constant_override("separation", 8)
	column.add_child(hand_container)
	_update_deck_count()

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
				cell.modulate = Color(str(card.get("color", "#ffffff")))
			cell.pressed.connect(_on_cell_pressed.bind(position))
			grid.add_child(cell)

func _draw_card() -> void:
	if deck.is_empty():
		_update_status("山札がありません。盤面のカードはそのまま残ります。")
		return
	var card_id: String = deck.pop_back()
	var card: Dictionary = card_definitions.get(card_id, {})
	var card_button := Button.new()
	card_button.text = str(card.get("name", card_id))
	card_button.custom_minimum_size = Vector2(140, 48)
	card_button.toggle_mode = true
	card_button.modulate = Color(str(card.get("color", "#ffffff")))
	card_button.pressed.connect(_select_card.bind(card_id, card_button))
	hand_container.add_child(card_button)
	_update_deck_count()
	_update_status("引いたカード: %s。手札からカードを選んで配置してください。" % card.get("name", card_id))

func _select_card(card_id: String, card_button: Button) -> void:
	selected_card = card_id
	for child in hand_container.get_children():
		if child is Button:
			child.button_pressed = false
	card_button.button_pressed = true
	_update_status("%s を選択中です。盤面の空きマスをクリックしてください。" % card_definitions.get(card_id, {}).get("name", card_id))
func _on_cell_pressed(position: Vector2i) -> void:
	if selected_card.is_empty():
		_update_status("先に手札のカードを選んでください。")
		return
	if board_cards.has(position):
		_update_status("そこにはカードがあります。空きマスを選んでください。")
		return
	board_cards[position] = selected_card
	var placed_id := selected_card
	selected_card = ""
	_remove_one_from_hand(placed_id)
	var dish_name := _resolve_recipes(position)
	_refresh_board()
	if dish_name.is_empty():
		_update_status("%s を配置しました。" % card_definitions.get(placed_id, {}).get("name", placed_id))
	else:
		_update_status("レシピ完成！ %s ができました。" % dish_name)

func _remove_one_from_hand(card_id: String) -> void:
	for child in hand_container.get_children():
		if child is Button and child.text == str(card_definitions.get(card_id, {}).get("name", card_id)):
			child.queue_free()
			return
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







