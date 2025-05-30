extends Node2D

@onready var http := $HTTPRequest
@onready var effects = $Effects
@onready var message_label := $MessageLabel
@onready var start_button := $StartGameButton
@onready var queens_button := $queens_button
@onready var room_list := $RoomManagement/RoomList
@onready var center_card_slot := $CenterCardSlot

# Use separate variables for RoomManagement children and get them safely
var room_management_node: Control = null
var create_room_button: Button = null
var join_button: Button = null

var player_id := ""
var room_id := ""
var center_card: Dictionary = {}
var poll_timer := Timer.new()
var current_player_id = null
var fetching := false
var has_joined := false
var player_index := -1
var current_turn_index := -1
var last_request_type := ""
var total_players := 0
var hand: Array = []
var reaction_mode := false
var reaction_value = null
var jack_swap_mode := false
var jack_swap_selection := {"from": null, "to": null}
var queens_triggered := false
var final_round_active := false
var awaiting_play_card_response := false
var initial_selection_mode := false
var selected_initial_cards: Array = []
var king_reveal_mode := false
var king_player_index := -1
var jack_player_index := -1
var queens_player_index := -1
var MAX_PLAYERS = 2


const BASE_URL = "https://web-production-2342a.up.railway.app/"

func _ready():
	if RoomState.room_id != "":
		room_id = RoomState.room_id
		join_game()
		return
	var stored_id = ProjectSettings.get_setting("application/config/player_id", "")
	if typeof(stored_id) != TYPE_STRING or stored_id == "":
		stored_id = str(randi())
	player_id = stored_id
	
	add_child(poll_timer)
	poll_timer.wait_time = 1.0
	poll_timer.timeout.connect(fetch_state)
	
	http.request_completed.connect(_on_request_completed)
	start_button.pressed.connect(_on_start_game_pressed)
	if queens_button:
		queens_button.pressed.connect(_on_queens_pressed)
	
	refresh_room_list()

	# Get references to RoomManagement nodes after they are ready
	call_deferred("get_room_management_nodes")

	# Add effects to buttons (deferred)
	call_deferred("add_button_effects_deferred")

func get_room_management_nodes():
	room_management_node = get_node_or_null("RoomManagement")
	if room_management_node:
		create_room_button = room_management_node.get_node_or_null("CreateRoomButton")
		join_button = room_management_node.get_node_or_null("JoinButton")

		# Connect signals for these buttons here after getting references
		if create_room_button:
			create_room_button.pressed.connect(_on_create_room_pressed)
		if join_button:
			join_button.pressed.connect(_on_join_pressed)

func add_button_effects_deferred():
	# Add effects to buttons - now also check if buttons are valid
	if start_button:
		effects.add_button_effects(start_button)
	if queens_button:
		effects.add_button_effects(queens_button)
	if create_room_button:
		effects.add_button_effects(create_room_button)
	if join_button:
		effects.add_button_effects(join_button)

func _on_create_room_pressed():
	effects.animate_text_fade(message_label, "Creating room...")
	last_request_type = "create_room"
	var url = BASE_URL + "create_room"
	print("Creating room with URL: ", url)
	var headers = [
		"Content-Type: application/json",
		"Accept: application/json",
		"Access-Control-Allow-Origin: *"
	]
	print("Sending request with headers: ", headers)
	var error = http.request(url, headers, HTTPClient.METHOD_POST)
	print("Request error code: ", error)

func refresh_room_list():
	last_request_type = "list_rooms"
	var url = BASE_URL + "rooms"
	print("Fetching rooms with URL: ", url)
	var headers = [
		"Accept: application/json",
		"Access-Control-Allow-Origin: *"
	]
	print("Sending request with headers: ", headers)
	var error = http.request(url, headers, HTTPClient.METHOD_GET)
	print("Request error code: ", error)

func join_room(selected_room_id: String):
	room_id = selected_room_id
	join_game()

func join_game():
	if room_id.is_empty():
		message_label.text = "Please select a room first"
		return
		
	last_request_type = "join"
	var url = BASE_URL + "join"
	print("Joining game with URL: ", url)
	var headers = [
		"Content-Type: application/json",
		"Accept: application/json",
		"Access-Control-Allow-Origin: *"
	]
	var body_dict = { "room_id": room_id }
	if player_id != "":
		body_dict["player_id"] = player_id
	var body = JSON.stringify(body_dict)
	print("Join request body: ", body)
	print("Sending request with headers: ", headers)
	var error = http.request(url, headers, HTTPClient.METHOD_POST, body)
	print("Request error code: ", error)
	
func _on_start_game_pressed():
	effects.animate_text_pop(message_label, "Starting game...")
	message_label.text = "Game start pressed (no-op unless handled on server)"
	
func _on_queens_pressed():
	effects.animate_text_pop(message_label, "Playing Queens!")
	if player_index != current_turn_index:
		message_label.text = "Not your turn!"
		return
	last_request_type = "call_queens"
	var url = BASE_URL + "call_queens"
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({
		"room_id": room_id,
		"player_index": player_index
	})
	http.request(url, headers, HTTPClient.METHOD_POST, body)
	
func _on_request_completed(_result, response_code, _headers, body):
	var json_text: String = body.get_string_from_utf8()
	print("Response code: ", response_code)
	print("Received response for ", last_request_type, ": ", json_text)
	var json = JSON.parse_string(json_text)
	
	poll_timer.start()
	awaiting_play_card_response = false

	if typeof(json) != TYPE_DICTIONARY:
		print("Invalid JSON from server:", json_text)
		message_label.text = "Server response error."
		fetching = false
		return
	if json.has("status") and json["status"] == "error":
		message_label.text = json.get("message", "Unknown server error")
		print("Server returned error:", json.get("message", "Unknown error"))
		fetching = false
		return
		
	match last_request_type:
		"create_room":
			room_id = json.get("room_id", "")
			message_label.text = "Room created! ID: " + room_id
			join_game()
		
		"list_rooms":
			if room_list:
				room_list.clear()
				for room in json.get("rooms", []):
					var room_id = room.get("room_id", "")
					var player_count = room.get("player_count", 0)
					var max_players = room.get("max_players", 2)
					var item_text = "Room %s (%d/%d players)" % [room_id, player_count, max_players]
					room_list.add_item(item_text)
					room_list.set_item_metadata(room_list.get_item_count() - 1, room_id)
		
		"join":
			player_id = json.get("player_id", player_id)
			player_index = int(json.get("player_index", -1))
			total_players = json.get("total_players", 0)
			if json.has("hand"):
				update_player_hand(player_index, json["hand"])
			has_joined = true
			ensure_player_nodes()
			message_label.text = "Joined as Player %d" % (player_index + 1)
			poll_timer.start()
			
			if json.has("initial_selection_mode"):
				initial_selection_mode = json["initial_selection_mode"]
				if initial_selection_mode:
					message_label.text = "Select 2 cards to reveal."
					selected_initial_cards = []
					var player_node = get_node("Player%d" % player_index)
					for card in player_node.hand:
						card.disabled = false
				else:
					var player_node = get_node("Player%d" % player_index)
					for card in player_node.hand:
						card.disabled = true
						
			if total_players == MAX_PLAYERS:
				create_room_button.hide()
				join_button.hide()
		
		"play_card":
			if json.has("hand"):
				hand = json["hand"]
				update_player_hand(player_index, hand)
			
			if json.has("center_card"):
				center_card = json["center_card"]
				show_center_card(center_card)
				
			if json.has("current_turn_index"):
				current_turn_index = int(json["current_turn_index"])
				
			var new_king_reveal_mode = json.get("king_reveal_mode", false)
			if new_king_reveal_mode != king_reveal_mode:
				king_reveal_mode = new_king_reveal_mode
				king_player_index = json.get("king_player_index", -1)
				if king_reveal_mode:
					message_label.text = "Player %d played a King! They are choosing a card to reveal." % (king_player_index + 1)
					if king_player_index == player_index:
						message_label.text = "You played a King! Select a card to reveal."
						update_player_hand(player_index, hand)
				else:
					if king_player_index == player_index:
						update_player_hand(player_index, hand)
					king_player_index = -1
				
			var new_jack_swap_mode = json.get("jack_swap_mode", false)
			if new_jack_swap_mode != jack_swap_mode:
				jack_swap_mode = new_jack_swap_mode
				jack_player_index = json.get("jack_player_index", -1)
				if jack_swap_mode:
					message_label.text = "Player %d played a Jack! They are selecting cards to swap." % (jack_player_index + 1)
					if jack_player_index == player_index:
						message_label.text = "You played a Jack! Select two cards to swap."
						jack_swap_selection = {"from": null, "to": null}
						for i in range(total_players):
							var player_node = get_node("Player%d" % i)
							if json.has("players"):
								for p_data in json["players"]:
									if p_data["index"] == i:
										update_player_hand(i, p_data.get("hand", []))
										if i == jack_player_index:
											for card in player_node.hand:
												card.disabled = false
									break
				else:
					if jack_player_index != -1:
						for i in range(total_players):
							var player_node = get_node("Player%d" % i)
							update_player_hand(i, player_node.hand.map(func(card): return card.card_data))
						jack_player_index = -1
				
			if !king_reveal_mode and !jack_swap_mode:
				message_label.text = "Your turn!" if player_index == current_turn_index else "Waiting for player %d" % (current_turn_index + 1)
		
		"state", "jack_swap", "call_queens", "king_reveal":
			if json.has("players"):
				for player_data in json["players"]:
					var idx = player_data["index"]
					if idx == player_index:
						if player_data.has("hand"):
							hand = player_data["hand"]
							update_player_hand(player_index, hand)
						continue
					var hand_size = player_data["hand_size"]
					var player_node = get_node_or_null("Player%d" % idx)
					if player_node:
						player_node.clear_hand()
						if player_data.has("hand"):
							update_player_hand(idx, player_data["hand"])
						else:
							for i in range(hand_size):
								var dummy_card = preload("res://scenes/Card.tscn").instantiate()
								dummy_card.disabled = true
								dummy_card.flip_card(false)
								player_node.add_card(dummy_card, false)
					
			if json.has("center_card"):
				center_card = json["center_card"]
				show_center_card(center_card)
				
			if json.has("current_turn_index"):
				current_turn_index = int(json["current_turn_index"])
				
				if !king_reveal_mode and !jack_swap_mode:
					message_label.text = "Your turn!" if player_index == current_turn_index else "Waiting for player %d" % (current_turn_index + 1)
				
				if json.has("king_reveal_mode"):
					king_reveal_mode = json["king_reveal_mode"]
					king_player_index = json.get("king_player_index", -1)
					if king_reveal_mode:
						if king_player_index == player_index:
							message_label.text = "You played a King! Select a card to reveal."
							update_player_hand(player_index, hand)
						else:
							message_label.text = "Player %d played a King! They are choosing a card to reveal." % (king_player_index + 1)
					else:
						if king_player_index != -1 and king_player_index == player_index:
							update_player_hand(player_index, hand)
						king_player_index = -1
				
				if json.has("jack_swap_mode"):
					jack_swap_mode = json["jack_swap_mode"]
					jack_player_index = json.get("jack_player_index", -1)
					if jack_swap_mode:
						if jack_player_index == player_index:
							message_label.text = "You played a Jack! Select two cards to swap."
							jack_swap_selection = {"from": null, "to": null}
							for i in range(total_players):
								var player_node = get_node("Player%d" % i)
								update_player_hand(i, player_node.hand.map(func(card): return card.card_data))
					else:
						if jack_player_index != -1:
							for i in range(total_players):
								var player_node = get_node("Player%d" % i)
								update_player_hand(i, player_node.hand.map(func(card): return card.card_data))
						jack_player_index = -1
				
				if json.has("reaction_mode"):
					reaction_mode = json["reaction_mode"]
					reaction_value = json.get("reaction_value", null)
				
				if json.has("queens_triggered"):
					queens_triggered = json["queens_triggered"]
					final_round_active = json.get("final_round_active", false)
					queens_player_index = json.get("queens_player_index", -1)
					
				if json.has("game_over"):
					message_label.text = json["message"]
					if json.has("winner"):
						message_label.text = json["message"]
					else:
						message_label.text = json["message"]
					queens_button.disabled = true
					for card in get_node("Player%d" % player_index).hand:
						card.disabled = true
				
				if json.has("message"):
					if !king_reveal_mode and !jack_swap_mode:
						message_label.text = json["message"]
		
		_:
			print("Received unexpected response type:", last_request_type)
			
	fetching = false

func update_player_hand(for_player_index: int, hand_data: Array):
	var player_node = get_node_or_null("Player%d" % for_player_index)
	if not player_node:
		print("Player node not found for index: ", for_player_index)
		return

	var old_hand_card_ids = player_node.hand.map(func(card): return card.card_data.card_id)
	player_node.clear_hand()

	for i in range(hand_data.size()):
		var card_data = hand_data[i]
		var card = preload("res://scenes/Card.tscn").instantiate()
		card.set_data(card_data)

		var face_up = card_data.get("is_face_up", false)

		var should_be_clickable = false
		if for_player_index == player_index:
			# It's the current player's hand
			if initial_selection_mode:
				# In initial selection mode, all of player's cards are clickable
				should_be_clickable = true
			elif king_reveal_mode and king_player_index == player_index:
				# If current player is the King player, their cards are clickable for reveal
				should_be_clickable = true
			elif jack_swap_mode and jack_player_index == player_index:
				# If current player is the Jack player, their cards are clickable for swap
				should_be_clickable = true
			elif current_turn_index == player_index and not reaction_mode and not king_reveal_mode and not jack_swap_mode and not final_round_active:
				# In normal turn, current player's cards are clickable if not in special modes
				should_be_clickable = true
			elif reaction_mode and current_turn_index == player_index and card_data.get("value") == reaction_value:
				# In reaction mode, current player's cards matching reaction value are clickable
				should_be_clickable = true
				
			# During the final round for the Queens caller, cards are not clickable for playing
			if final_round_active and player_index == queens_player_index:
				should_be_clickable = false

			card.disabled = not should_be_clickable
			card.mouse_filter = Control.MOUSE_FILTER_PASS if should_be_clickable else Control.MOUSE_FILTER_IGNORE

			# Connect pressed signal only if clickable and not already connected
			if should_be_clickable:
				if !card.pressed.is_connected(func(): _on_card_pressed(card_data)):
					var connection_result = card.pressed.connect(func(): _on_card_pressed(card_data))
					if connection_result != OK:
						print("Failed to connect pressed signal for card: ", card_data)
			else:
				# Disconnect if not clickable and connected
				if card.pressed.is_connected(func(): _on_card_pressed(card_data)):
					card.pressed.disconnect(func(): _on_card_pressed(card_data))

			# Timed reveal for newly received cards
			var is_new_card = !old_hand_card_ids.has(card_data.card_id)
			if is_new_card and !card_data.get("is_face_up", false):
				# Flip face up temporarily and start timer
				card.flip_card(true)
				
				# Ensure card is valid and in scene tree before adding timer
				if is_instance_valid(card) and card.is_inside_tree():
					var reveal_timer = Timer.new()
					card.add_child(reveal_timer) # Attach timer to the card
					reveal_timer.wait_time = 2.5 # 2.5 seconds reveal time
					reveal_timer.one_shot = true
					reveal_timer.timeout.connect(func(): card.flip_card(false)) # Flip back face down after timer
					reveal_timer.start()
				else:
					print("Error: Cannot add reveal timer. Card is not valid or not in scene tree.")

		else:
			# It's another player's hand
			card.disabled = true # Other players' cards are generally not clickable for interaction
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE

			# Determine if other players' cards should be face up
			if card_data.get("permanent_face_up", false) or (king_reveal_mode and for_player_index == king_player_index and card_data.get("is_face_up", false)):
				face_up = true
			else:
				face_up = false
			
			# Allow clicking on opponent's cards for Jack swap or King reveal if in those modes
			if (jack_swap_mode and player_index == jack_player_index) or (king_reveal_mode and player_index == king_player_index): # Should only be clickable by the active Jack/King player
				should_be_clickable = true
				card.disabled = false
				card.mouse_filter = Control.MOUSE_FILTER_PASS
				
				if should_be_clickable:
					if !card.pressed.is_connected(func(): _on_card_pressed(card_data)):
						var connection_result = card.pressed.connect(func(): _on_card_pressed(card_data))
						if connection_result != OK:
							print("Failed to connect pressed signal for card: ", card_data)
				else:
					if card.pressed.is_connected(func(): _on_card_pressed(card_data)):
						card.pressed.disconnect(func(): _on_card_pressed(card_data))


		card.flip_card(face_up)
		player_node.add_card(card, for_player_index == player_index)
	player_node.arrange_hand()
	print("Updated hand for player ", for_player_index, " with ", hand_data.size(), " cards.")

func _on_card_pressed(card_data: Dictionary):
	print("Card pressed: ", card_data)

	if initial_selection_mode:
		var player_node = get_node("Player%d" % player_index)
		var card_instance = null
		# Find the card instance in the player's hand
		for card in player_node.get_children():
			if card is Node and card.has_method("set_data") and card.card_data.card_id == card_data.card_id:
				card_instance = card
				break

		if !card_instance:
			print("Card instance not found in scene tree for initial selection.")
			return

		# Check if card is already selected or revealing
		var already_selected = false
		for selected_card in selected_initial_cards:
			if selected_card.card_id == card_data.card_id:
				already_selected = true
				break

		if already_selected:
			print("Card already selected for initial reveal.")
			return

		if card_instance.has_meta("revealing_timer"):
			print("Card is already revealing.")
			return

		# Check if we are already revealing 2 cards
		var revealing_count = 0
		for card in player_node.get_children():
			if card.has_meta("revealing_timer"):
				revealing_count += 1

		if selected_initial_cards.size() + revealing_count < 2:
			# Flip card and start timer
			card_instance.flip_card(true)
			card_instance.disabled = true # Disable clicks while revealing

			var reveal_timer = Timer.new()
			player_node.add_child(reveal_timer) # Add timer to player node
			reveal_timer.wait_time = 3.0
			reveal_timer.one_shot = true
			reveal_timer.timeout.connect(func(): _on_initial_card_reveal_timeout(card_data.card_id))
			reveal_timer.start()
			card_instance.set_meta("revealing_timer", reveal_timer.get_path()) # Store timer path

			message_label.text = "Revealing card... Select %d more." % [2 - (selected_initial_cards.size() + revealing_count + 1)]

		return # Don't proceed with play_card logic in initial selection mode

	if jack_swap_mode and jack_player_index == player_index:
		var player_node = get_node("Player%d" % player_index)
		var opponent_node = get_node("Player%d" % ((player_index + 1) % total_players))
		
		if jack_swap_selection["from"] == null:
			# First card selection (from player's hand)
			if player_node.hand.has(card_data):
				jack_swap_selection["from"] = card_data
				message_label.text = "Now select a card from opponent's hand to swap with."
		else:
			# Second card selection (from opponent's hand)
			if opponent_node.hand.has(card_data):
				jack_swap_selection["to"] = card_data
				# Send jack swap request
				last_request_type = "jack_swap"
				var url = BASE_URL + "jack_swap"
				var headers = ["Content-Type: application/json"]
				var payload = {
					"room_id": room_id,
					"player_index": player_index,
					"from_card_id": jack_swap_selection["from"].card_id,
					"to_card_id": jack_swap_selection["to"].card_id
				}
				http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
				jack_swap_selection = {"from": null, "to": null}
		return
	
	if player_index != current_turn_index:
		print("Not your turn! Current turn: ", current_turn_index)
		message_label.text = "Not your turn!"
		return
		
	last_request_type = "play_card"
	var url = BASE_URL + "play_card"
	var headers = ["Content-Type: application/json"]
	var payload = {
		"room_id": room_id,
		"player_index": player_index,
		"card": card_data
	}
	
	poll_timer.stop()
	awaiting_play_card_response = true

	var error = http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if error != OK:
		message_label.text = "Failed to play card"
	else:
		print("Play card request sent: ", payload)

func add_card_to_hand(card_data: Dictionary, for_player_index: int):
	print("Adding card to player", for_player_index, "  local player index:", player_index)
	var card = preload("res://scenes/Card.tscn").instantiate()
	card.set_data(card_data)
	var player_node = get_node_or_null("Player%d" % for_player_index)
	if not player_node:
		return
	if for_player_index == player_index:
		card.flip_card(true)
		card.pressed.connect(func(): _on_card_pressed(card_data))
		card.disabled = false 
	else:
		card.disabled = true
		card.flip_card(false) 
	player_node.add_card(card, for_player_index == player_index)
	player_node.arrange_hand()

func show_center_card(card_data: Dictionary):
	for child in $CenterCardSlot.get_children():
		child.queue_free()
		
	if card_data and card_data.has("suit") and card_data.has("rank"):
		var card = preload("res://scenes/Card.tscn").instantiate()
		card.set_data(card_data)
		card.disabled = true
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.is_center_card = true
		card.flip_card(true)
		card.position = Vector2.ZERO
		$CenterCardSlot.add_child(card)
		print("Center card displayed: ", card_data)
	else:
		print("No valid center card data")
		
func play_card(card_data: Dictionary):
	print("play_card function called, likely unnecessary with current server interaction.")
	pass

func ensure_player_nodes():
	for i in range(total_players):
		if not has_node("Player%d" % i):
			var p = preload("res://scenes/Player.tscn").instantiate()
			p.name = "Player%d" % i
			add_child(p)

func fetch_state():
	if not has_joined or room_id.is_empty():
		return
		
	if fetching:
		return
		
	fetching = true
	last_request_type = "state"
	var url = BASE_URL + "state?room_id=" + room_id
	var headers = [
		"Accept: application/json",
		"Access-Control-Allow-Origin: *"
	]
	var error = http.request(url, headers, HTTPClient.METHOD_GET)
	print("State request error code: ", error)

func _on_room_selected(idx):
	if room_list:
		var label = room_list.get_item_text(idx)
		var parts = label.split(" ")
		if parts.size() > 1:
			var selected_room_id = parts[1]
			join_room(selected_room_id)

func _on_join_pressed():
	effects.animate_text_fade(message_label, "Joining room...")
	join_game()

func update_message(text: String, is_error: bool = false):
	message_label.modulate = Color(1, 0, 0) if is_error else Color(1, 1, 1)
	effects.animate_text_pop(message_label, text)

func _on_initial_card_reveal_timeout(card_id: String):
	print("Initial card reveal timeout for card: ", card_id)

	if initial_selection_mode:
		var player_node = get_node("Player%d" % player_index)
		var card_instance = null
		# Find the card instance in the player's hand
		for card in player_node.get_children():
			if card is Node and card.has_method("set_data") and card.card_data.card_id == card_id:
				card_instance = card
				break

		if !card_instance:
			print("Card instance not found after timer.")
			return

		# Card has been revealed for 3 seconds, add to selected list
		selected_initial_cards.append(card_instance.card_data)

		# Clean up the timer
		var timer_path = card_instance.get_meta("revealing_timer")
		if timer_path:
			var timer_node = get_node(timer_path)
			if timer_node:
				timer_node.queue_free()
			card_instance.remove_meta("revealing_timer")

		print("Selected initial cards count: ", selected_initial_cards.size())

		# Check if two cards have been selected
		if selected_initial_cards.size() == 2:
			message_label.text = "Two cards selected. Sending to server..."
			# Keep cards face up after selection based on current logic

			# Send selected cards to server
			last_request_type = "select_initial_cards"
			var url = BASE_URL + "select_initial_cards"
			var headers = ["Content-Type: application/json"]
			var selected_ids = []
			for card in selected_initial_cards:
				selected_ids.append(card.card_id)
			var payload = {
				"room_id": room_id,
				"player_index": player_index,
				"selected_card_ids": selected_ids
			}
			poll_timer.stop() # Stop polling while waiting for server response
			awaiting_play_card_response = true # Use this flag to prevent further polling
			var error = http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
			if error != OK:
				message_label.text = "Failed to send initial card selection"
				awaiting_play_card_response = false
				poll_timer.start()
			else:
				print("Initial card selection sent: ", payload)
				message_label.text = "Waiting for other players..."

		# The cards remain face up after being selected according to the current logic.
		# If they should flip back face down, uncomment the following line:
		# card_instance.flip_card(false)


	else:
		# This case should not happen if initial_selection_mode is handled correctly
		print("Timeout occurred outside of initial selection mode.")

func _on_card_played(card_data: Dictionary):
	print("Card played via drag: ", card_data)
	
	# This function is called from card.gd when a card is dragged to the center
	# Send the played card data to the server
	
	if player_index != current_turn_index:
		print("Not your turn! Cannot play card via drag.")
		message_label.text = "Not your turn!"
		# Optionally, animate the card back to hand if played out of turn
		return
	
	last_request_type = "play_card"
	var url = BASE_URL + "play_card"
	var headers = ["Content-Type: application/json"]
	var payload = {
		"room_id": room_id,
		"player_index": player_index,
		"card": card_data
	}
	
	poll_timer.stop() # Stop polling while waiting for server response
	awaiting_play_card_response = true # Use this flag to prevent further polling
	
	var error = http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if error != OK:
		message_label.text = "Failed to play card"
		awaiting_play_card_response = false
		poll_timer.start()
	else:
		print("Play card request sent via drag: ", payload)
