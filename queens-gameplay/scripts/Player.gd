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

signal initial_selection_complete(selected_card_ids)

func _ready():
	var hand_container = $HandContainer
	if not hand_container:
		push_error("HandContainer not found in _ready!")

func setup_player(index: int, id: String):
	player_index = index
	player_id = id
	
	var label = $Label
	if label:
		label.text = "Player " + str(index)

func update_hand_display(new_hand: Array, local_player: bool, initial_selection: bool):
	if typeof(new_hand) != TYPE_ARRAY:
		return
		
	hand = new_hand
	is_local_player = local_player
	is_initial_selection = initial_selection
	
	var hand_container = $HandContainer
	if not is_instance_valid(hand_container):
		return
	
	for timer in reveal_timers.values():
		if is_instance_valid(timer):
			timer.queue_free()
	reveal_timers.clear()
	temporarily_revealed_cards.clear()
	
	for child in hand_container.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	for card_data in new_hand:
		if typeof(card_data) != TYPE_DICTIONARY:
			continue
			
		var card_node = preload("res://scenes/card.tscn").instantiate()
		if not card_node:
			continue
			
		if not card_data.has("card_id"):
			card_node.queue_free()
			continue
			
		card_node.set_data(card_data)
		card_node.holding_player = self
		
		if local_player:
			card_node.mouse_filter = Control.MOUSE_FILTER_STOP
			
			if initial_selection:
				card_node.flip_card(false)
			else:
				card_node.flip_card(true)
		else:
			card_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card_node.flip_card(false)
			card_node.disabled = true
		
		hand_container.add_child(card_node)
	
	hand_container.visible = true
	hand_container.modulate = Color(1, 1, 1)

func _on_card_pressed(card_node):
	if not is_initial_selection:
		return
		
	if selected_initial_cards.size() >= 2:
		return
		
	var card_id = card_node.card_data.card_id
	var already_selected = selected_initial_cards.has(card_id)
	
	if already_selected:
		selected_initial_cards.erase(card_id)
		card_node.flip_card(false)
		card_node.modulate = Color(1, 1, 1)
	else:
		selected_initial_cards.append(card_id)
		card_node.flip_card(true)
		card_node.modulate = Color(0.7, 1.0, 0.7)
		
		if selected_initial_cards.size() == 2:
			emit_signal("initial_selection_complete", selected_initial_cards.duplicate())
			
			var hand_container = $HandContainer
			if hand_container:
				for card in hand_container.get_children():
					card.disabled = true
					if not selected_initial_cards.has(card.card_data.card_id):
						card.modulate = Color(0.5, 0.5, 0.5)
						card.flip_card(false)
					else:
						card.modulate = Color(0.7, 1.0, 0.7)

func clear_hand():
	call_deferred("_deferred_clear_hand_container")
	
func _deferred_clear_hand_container():
	var hand_container = $"HandContainer"
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
	selected_initial_cards.clear()
	update_hand_display(hand, is_local_player, is_initial_selection)
 
