extends HBoxContainer

var player_index: int = -1
var player_id: String = ""
var hand: Array = []
var is_local_player: bool = false
var is_initial_selection: bool = false
var selected_initial_cards: Array = []
var card_back_texture = preload("res://assets/card_back-export.png")
var temporarily_revealed_cards = {}

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
	hand = new_hand
	is_local_player = local_player
	is_initial_selection = initial_selection
	var hand_container = $"HandContainer"
	if not is_instance_valid(hand_container):
		hand_container = $"HandContainer"
		if not is_instance_valid(hand_container):
			push_error("Hand container not found!")
			return
			
	for child in hand_container.get_children():
		child.queue_free()
	
	var main_script = get_node("/root/Main")
	if not main_script:
		push_error("Main script not found!")
		return
		
	for card in hand:
		var card_scene = preload("res://scenes/card.tscn")
		if !card_scene:
			push_error("Failed to load card scene!")
			continue
			
		var card_node = card_scene.instantiate()
		if !is_instance_valid(card_node):
			push_error("Failed to instantiate card node!")
			continue
			
		card_node.set_data(card)
		card_node.holding_player = self
		
		# Always start with cards face-down and disabled
		if card_node.has_method("flip_card"):
			card_node.flip_card(false)
			card_node.modulate = Color(1, 1, 1)
			card_node.disabled = true
			
			# During initial selection phase
			if initial_selection:
				# Show selected cards to everyone
				if card.has("selected") and card.selected:
					card_node.flip_card(true)
					card_node.modulate = Color(0.7, 1.0, 0.7)  # Green tint for selected
				# Only the player can select their own cards
				if local_player:
					card_node.disabled = false
			# During normal gameplay
			else:
				# Keep cards face-down by default
				card_node.flip_card(false)
				card_node.modulate = Color(1, 1, 1)
				
				# Show new card briefly if it's the last card and we just got it
				if local_player and card == hand[-1] and main_script.current_turn_index == player_index:
					card_node.flip_card(true)
					# Create a timer to flip it back
					var timer = Timer.new()
					add_child(timer)
					timer.wait_time = 2.0
					timer.one_shot = true
					timer.timeout.connect(func(): 
						if is_instance_valid(card_node) and card_node.has_method("flip_card"):
							card_node.flip_card(false)
						timer.queue_free()
					)
					timer.start()
				
				# Enable interaction for current player during their turn
				if local_player and main_script.current_turn_index == player_index and main_script.game_started:
					card_node.disabled = false
				
				# Handle revealed cards (through King effect)
				if card.has("is_face_up") and card.is_face_up:
					card_node.flip_card(true)
					card_node.modulate = Color(1.0, 0.7, 0.7)  # Red tint for revealed
		else:
			push_error("Card node does not have flip_card method!")
			continue
		
		hand_container.add_child(card_node)

func _on_initial_card_pressed(card_id):
	if not is_initial_selection:
		return
		
	# Block all interaction if already 2 cards selected
	if selected_initial_cards.size() >= 2:
		return
		
	if selected_initial_cards.has(card_id):
		return
		
	if temporarily_revealed_cards.has(card_id):
		return
		
	# Temporarily reveal the card
	temporarily_revealed_cards[card_id] = true
	update_hand_display(hand, is_local_player, is_initial_selection)
	
	# Wait for reveal duration
	await get_tree().create_timer(3.0).timeout
	
	# Only proceed if we're still in initial selection mode
	if not is_initial_selection:
		return
		
	temporarily_revealed_cards.erase(card_id)
	
	# If less than 2 selected, allow selection after preview
	if selected_initial_cards.size() < 2:
		selected_initial_cards.append(card_id)
		update_hand_display(hand, is_local_player, is_initial_selection)
		
		# If now 2 cards are selected, complete the selection
		if selected_initial_cards.size() == 2:
			is_initial_selection = false
			update_hand_display(hand, is_local_player, is_initial_selection)
			emit_signal("initial_selection_complete", selected_initial_cards.duplicate())

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
 
