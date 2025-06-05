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
	print("Called update_hand_display with:", new_hand.size(), "cards, local:", local_player, "selection_mode:", initial_selection)
	
	hand = new_hand
	is_local_player = local_player
	is_initial_selection = initial_selection
	var hand_container = $HandContainer
	if not is_instance_valid(hand_container):
		print("ERROR: HandContainer not found in Player node!")
		push_error("Hand container not found!")
		return
		
	# Clear existing cards and timers
	print("Clearing", reveal_timers.size(), "existing timers")
	for timer in reveal_timers.values():
		if is_instance_valid(timer):
			timer.queue_free()
	reveal_timers.clear()
	temporarily_revealed_cards.clear()
	
	print("Clearing", hand_container.get_child_count(), "existing cards")
	for child in hand_container.get_children():
		child.queue_free()
		
	# Create new cards
	print("Creating", new_hand.size(), "new cards with initial_selection:", initial_selection)
	for card_data in new_hand:
		var card_node = preload("res://scenes/card.tscn").instantiate()
		if not card_node:
			print("ERROR: Failed to instantiate Card scene!")
			continue
			
		# Ensure card_data has required fields
		if not card_data.has("card_id"):
			print("WARNING: Card data missing card_id, skipping card")
			continue
			
		card_node.set_data(card_data)
		
		if is_local_player and initial_selection:
			print("Setting up card", card_data.card_id, "for initial selection")
			card_node.mouse_filter = Control.MOUSE_FILTER_STOP
			card_node.flip_card(false)
			card_node.pressed.connect(_on_card_pressed.bind(card_node))
		else:
			card_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card_node.flip_card(false)
		
		hand_container.add_child(card_node)
		card_node.holding_player = self
		
		# If this card is being temporarily revealed, restore its state
		if card_data.has("card_id") and temporarily_revealed_cards.has(card_data.card_id):
			card_node.flip_card(true)
			card_node.modulate = Color(1.0, 0.9, 0.5)  # Yellow tint for revealed cards
	
	
	hand_container.visible = true
	hand_container.modulate = Color(1, 1, 1) 

func _on_initial_card_pressed(card_node):
	if not is_initial_selection:
		return
		
	# Block all interaction if already 2 cards selected
	if selected_initial_cards.size() >= 2:
		return
		
	var card_id = card_node.card_data.card_id
	
	# If card is already selected, ignore
	if selected_initial_cards.has(card_id):
		return
		
	# If card is being temporarily revealed, ignore
	if temporarily_revealed_cards.has(card_id):
		return
		
	# Temporarily reveal the card
	temporarily_revealed_cards[card_id] = true
	card_node.flip_card(true)
	card_node.modulate = Color(1.0, 0.9, 0.5)  # Slight yellow tint for preview
	
	# Wait for reveal duration
	await get_tree().create_timer(3.0).timeout
	
	# Only proceed if we're still in initial selection mode
	if not is_initial_selection:
		return
		
	# Flip card back down if it wasn't selected
	if not selected_initial_cards.has(card_id):
		card_node.flip_card(false)
		card_node.modulate = Color(1, 1, 1)
	
	temporarily_revealed_cards.erase(card_id)
	
	# Allow selection after preview
	if selected_initial_cards.size() < 2:
		selected_initial_cards.append(card_id)
		card_node.modulate = Color(0.7, 1.0, 0.7)  # Green tint for selected
		
		# If now 2 cards are selected, complete the selection
		if selected_initial_cards.size() == 2:
			emit_signal("initial_selection_complete", selected_initial_cards.duplicate())
			
			# Disable all cards and dim unselected ones
			var hand_container = $HandContainer
			if hand_container:
				for card in hand_container.get_children():
					card.disabled = true
					if not selected_initial_cards.has(card.card_data.card_id):
						card.modulate = Color(0.5, 0.5, 0.5)
						card.flip_card(false)

func _on_card_pressed(card_node):
	if not is_initial_selection:
		return
		
	print("Card pressed during initial selection:", card_node.card_data.card_id)
	
	# Start temporary reveal timer
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 3.0
	timer.one_shot = true
	timer.timeout.connect(func():
		if is_instance_valid(card_node):
			print("Reveal timer finished for card:", card_node.card_data.card_id)
			card_node.flip_card(false)
			card_node.modulate = Color(1, 1, 1)
	)
	
	# Reveal the card
	card_node.flip_card(true)
	card_node.modulate = Color(1.0, 0.9, 0.5)  # Yellow tint
	timer.start()
	
	# Store the timer
	reveal_timers[card_node.card_data.card_id] = timer
	temporarily_revealed_cards.append(card_node.card_data.card_id)
	
	print("Started reveal timer for card:", card_node.card_data.card_id)

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
 
