extends HBoxContainer

var player_index: int = -1
var player_id: String = ""
var hand: Array = []
var is_local_player: bool = false
var is_initial_selection: bool = false
var selected_initial_cards: Array = []
var card_back_texture = preload("res://assets/card_back-export.png")
var temporarily_revealed_cards = {}
var reveal_timers = {}
var _initial_selected_cards: Array = []

@onready var hand_container = $HandContainer

signal initial_selection_complete(selected_card_ids)

func _ready():
	if not hand_container:
		push_error("HandContainer not found in _ready!")

func setup_player(index: int, id: String):
	player_index = index
	player_id = id
	_initial_selected_cards.clear()
	
	var label = $Label
	if label:
		label.text = "Player " + str(index)

func update_hand_display(new_hand: Array, local_player: bool, initial_selection: bool):
	if not is_instance_valid(hand_container):
		push_error("Error: Hand container not found")
		return
	
	for child in hand_container.get_children():
		child.queue_free()
	
	var cards_added = 0
	var card_width = 100
	var card_height = 150
	var card_spacing = 20
	var total_width = (card_width + card_spacing) * new_hand.size() - card_spacing
	var start_x = (hand_container.size.x - total_width) / 2
	
	hand_container.size = Vector2(1000, 200)
	hand_container.custom_minimum_size = Vector2(1000, 200)
	hand_container.position = Vector2(0, 25)
	
	for card_data in new_hand:
		var card_node = preload("res://scenes/card.tscn").instantiate()
		if not card_node:
			push_error("Error: Failed to instantiate card scene")
			continue
		
		card_node.holding_player = self
		card_node.set_data(card_data)
		card_node.size = Vector2(card_width, card_height)
		card_node.position.x = start_x + (card_width + card_spacing) * cards_added
		card_node.position.y = (hand_container.size.y - card_height) / 2
		
		if local_player:
			if initial_selection:
				card_node.flip_card(false)  # Start face down in initial selection
				if not card_node.pressed.is_connected(_on_card_pressed):
					card_node.pressed.connect(_on_card_pressed.bind(card_node))
			else:
				# Only show face up if not in initial selection and it's the local player
				card_node.flip_card(true)
				if not card_node.pressed.is_connected(_on_card_pressed):
					card_node.pressed.connect(_on_card_pressed.bind(card_node))
		else:
			# For opponent's cards or hidden cards, just show the back
			card_node.flip_card(false)
			card_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		hand_container.add_child(card_node)
		cards_added += 1
	
	if cards_added == 0:
		display_error_card("No cards to display")

func _on_card_pressed(card_node):
	if not card_node:
		return
		
	if not card_node.pressed.is_connected(_on_card_pressed):
		card_node.pressed.connect(_on_card_pressed.bind(card_node))
	
	if is_initial_selection:
		# Check if this card was already selected
		var already_selected = false
		for selected_card in _initial_selected_cards:
			if selected_card.card_id == card_node.card_data.card_id:
				already_selected = true
				break

		if already_selected:
			return

		if _initial_selected_cards.size() >= 2:
			return

		_initial_selected_cards.append(card_node.card_data)
		card_node.temporary_reveal()
		
		if _initial_selected_cards.size() == 2:
			var card_ids = []
			for card in _initial_selected_cards:
				card_ids.append(card.card_id)
			initial_selection_complete.emit(card_ids)
			
			# Disable all cards after selection
			for card in hand_container.get_children():
				card.disabled = true

func clear_hand():
	call_deferred("_deferred_clear_hand_container")
	
func _deferred_clear_hand_container():
	if is_instance_valid(hand_container):
		for child in hand_container.get_children():
			child.queue_free()
	
func add_card(card: Dictionary):
	hand.append(card)
	update_hand_display(hand, is_local_player, is_initial_selection)

func remove_card(card_id: String):
	var card_to_remove = null
	for c in hand:
		if c.id == card_id:
			card_to_remove = c
			break
	
	if card_to_remove:
		hand.erase(card_to_remove)
		update_hand_display(hand, is_local_player, is_initial_selection)
	
func set_initial_selection_mode(enable: bool):
	is_initial_selection = enable
	_initial_selected_cards.clear()
	update_hand_display(hand, is_local_player, is_initial_selection)

func display_error_card(error_message: String):
	var error_card = ColorRect.new()
	error_card.color = Color(0.8, 0, 0, 0.3)
	error_card.custom_minimum_size = Vector2(100, 150)
	error_card.size = Vector2(100, 150)
	error_card.position = Vector2((hand_container.size.x - 100) / 2, (hand_container.size.y - 150) / 2)
	
	var error_label = Label.new()
	error_label.text = error_message
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	error_label.custom_minimum_size = Vector2(100, 150)
	error_label.size = Vector2(100, 150)
	
	error_card.add_child(error_label)
	hand_container.add_child(error_card)
 
