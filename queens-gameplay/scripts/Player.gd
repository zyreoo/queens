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
		return

func setup_player(index: int, id: String):
	player_index = index
	player_id = id
	is_local_player = (id != "")
	_initial_selected_cards.clear()
	
	var label = $Label
	if label:
		label.text = "Player " + str(index)

func update_hand_display(new_hand: Array, local_player: bool, initial_selection: bool):
	if not is_instance_valid(hand_container):
		return
	
	is_initial_selection = initial_selection
	is_local_player = local_player
	
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
			continue
		
		card_node.holding_player = self
		card_node.set_data(card_data)
		
		card_node.size = Vector2(card_width, card_height)
		card_node.position.x = start_x + (card_width + card_spacing) * cards_added
		card_node.position.y = (hand_container.size.y - card_height) / 2
		
		if local_player:
			if initial_selection:
				var was_selected = false
				for selected_card in _initial_selected_cards:
					if selected_card.card_id == card_data.card_id:
						was_selected = true
						card_node.flip_card(true)
						card_node.modulate = Color(1, 1, 0.7)
						break
				if not was_selected:
					card_node.flip_card(false)
					card_node.modulate = Color(1, 1, 1)
					card_node.disabled = false
			else:
				card_node.flip_card(false)
				card_node.modulate = Color(1, 1, 1)
		else:
			card_node.flip_card(false)
			card_node.modulate = Color(1, 1, 1)
			card_node.disabled = true
		
		hand_container.add_child(card_node)
		cards_added += 1

func _on_card_input(event: InputEvent, card_node):
	if not card_node:
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if is_initial_selection and is_local_player:
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
			card_node.flip_card(true)
			card_node.modulate = Color(1, 1, 0.7)
			
			if _initial_selected_cards.size() == 2:
				var card_ids = []
				for card in _initial_selected_cards:
					card_ids.append(card.card_id)
				initial_selection_complete.emit(card_ids)
				
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
	
	if hand_container:
		for card in hand_container.get_children():
			if card.has_method("flip_card"):
				if not enable:
					card.flip_card(false)
					card.modulate = Color(1, 1, 1)
				else:
					var was_selected = false
					for selected_card in _initial_selected_cards:
						if selected_card.card_id == card.card_data.card_id:
							was_selected = true
							card.flip_card(true)
							card.modulate = Color(1, 1, 0.7)
							break
					if not was_selected:
						card.flip_card(false)
						card.modulate = Color(1, 1, 1)

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
 
