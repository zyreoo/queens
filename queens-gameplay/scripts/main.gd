extends Control

@onready var http := $HTTPRequest
@onready var effects = $Effects
@onready var message_label := $MenuContainer/MessageLabel
@onready var queens_button := $MenuContainer/queens_button
@onready var room_list := $MenuContainer/RoomList
@onready var center_card_slot := $GameContainer/CenterCardSlot
@onready var room_name_label := $GameContainer/RoomNameLabel

var room_management_node: Control = null
var create_room_button: Button = null
var join_button: Button = null
var room_update_timer: Timer

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
	
	# Setup room list update timer
	room_update_timer = Timer.new()
	add_child(room_update_timer)
	room_update_timer.wait_time = 3.0  # Update every 3 seconds
	room_update_timer.timeout.connect(refresh_room_list)
	room_update_timer.start()
	
	# Ensure the http request_completed signal is connected
	if not http.request_completed.is_connected(_on_request_completed):
		http.request_completed.connect(_on_request_completed)
		print("_ready: http.request_completed connected to _on_request_completed.")
	
	if queens_button and not queens_button.pressed.is_connected(_on_queens_pressed):
		queens_button.pressed.connect(_on_queens_pressed)
	
	refresh_room_list()

	call_deferred("get_room_management_nodes")
	call_deferred("add_button_effects_deferred")
	queens_button.visible = false

func get_room_management_nodes():
	var menu_container = get_node_or_null("MenuContainer")
	if menu_container:
		create_room_button = menu_container.get_node_or_null("CreateRoomButton")
		join_button = menu_container.get_node_or_null("JoinButton")

		if create_room_button and not create_room_button.pressed.is_connected(_on_create_room_pressed):
			create_room_button.pressed.connect(_on_create_room_pressed)
			if has_joined and total_players == MAX_PLAYERS:
				create_room_button.hide()
			if join_button and not join_button.pressed.is_connected(_on_join_pressed):
				join_button.pressed.connect(_on_join_pressed)
				if has_joined and total_players == MAX_PLAYERS:
					join_button.hide()

func add_button_effects_deferred():
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
	
	$MenuContainer.visible = false
	$GameContainer.visible = true
	
	# Update room name label when joining
	if room_name_label:
		room_name_label.text = "Room: " + room_id

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
	
func _on_request_completed(result, response_code, headers, body):
	print("_on_request_completed called. Result: ", result, ", Response Code: ", response_code, ", Last Request Type: ", last_request_type)

	if result != HTTPRequest.RESULT_SUCCESS:
		print("HTTP request failed: ", result)
		return
		
	var json = JSON.parse_string(body.get_string_from_utf8())
	if !json:
		print("Failed to parse JSON response")
		return
	print("_on_request_completed: JSON parsed successfully.")
		
	if json.get("status") == "error":
		print("_on_request_completed: Received error status: ", json.get("message", ""))
		message_label.text = json.get("message", "Error occurred")
		return
	print("_on_request_completed: No error status.")
		
	print("_on_request_completed: Matching last_request_type...")
	match last_request_type:
		"create_room":
			print("_on_request_completed: Matched 'create_room'. Processing response: ", json)
			room_id = json.get("room_id", "")
			if room_id.is_empty():
				message_label.text = "Failed to create room"
				print("_on_request_completed: Room ID is empty after creation.")
				return
			message_label.text = "Room created! ID: " + room_id
			# Update room name label
			if room_name_label:
				room_name_label.text = "Room: " + room_id
			print("_on_request_completed: Room created, ID: ", room_id, ". Refreshing list and joining game.")
			# Immediately refresh the room list after creating a room
			refresh_room_list()
			# Do NOT call join_game() here directly. It will be called after the room list is refreshed.
			print("_on_request_completed: Exiting 'create_room' case.")
		
		"list_rooms":
			print("_on_request_completed: Matched 'list_rooms'. Processing response: ", json)
			if room_list:
				room_list.clear()
				for room in json.get("rooms", []):
					var room_id = room.get("room_id", "")
					var player_count = room.get("player_count", 0)
					var max_players = room.get("max_players", 2)
					var item_text = "Room %s (%d/%d players)" % [room_id, player_count, max_players]
					room_list.add_item(item_text)
					room_list.set_item_metadata(room_list.get_item_count() - 1, room_id)
			print("_on_request_completed: Room list updated.")
			# If we just created a room, join it after the list is refreshed
			if last_request_type == "create_room": # Check if the previous request was create_room
				print("_on_request_completed: Previous request was create_room. Now joining game.")
				join_game()
				
			print("_on_request_completed: Exiting 'list_rooms' case.")
			
		"join":
			print("_on_request_completed: Matched 'join'. Processing response: ", json)
			player_id = json.get("player_id", player_id)
			player_index = int(json.get("player_index", -1))
			total_players = json.get("total_players", 0)
			has_joined = true
			
			print("_on_request_completed: Player ID: ", player_id, ", Player Index: ", player_index, ", Total Players: ", total_players)
			
			ensure_player_nodes()
			print("_on_request_completed: Called ensure_player_nodes. Iterating through players for setup and hand display.")
			
			for i in range(total_players):
				print("_on_request_completed: Processing player index: ", i)
				var player_node_path = "GameContainer/Player%d" % i
				var player_node = get_node_or_null(player_node_path)
				if is_instance_valid(player_node):
					print("_on_request_completed: Player node ", player_node.name, " is valid.")
					print("_on_request_completed: Calling setup_player for Player%d" % i)
					player_node.setup_player()
					
					# Get initial hand data for this player
					var initial_hand = []
					if json.has("players") and i < json["players"].size() and json["players"][i].has("hand"):
						initial_hand = json["players"][i]["hand"]
					
					# Update the player's hand display with the initial hand data
					print("_on_request_completed: Calling update_hand_display for Player%d with %d cards" % [i, initial_hand.size()])
					player_node.update_hand_display(initial_hand)
				else:
					print("Error: Player node at path ", player_node_path, " is invalid in join case loop.")
			
			message_label.text = "Joined as Player %d" % (player_index + 1)
			poll_timer.start()
			queens_button.visible = true
			
			if json.has("initial_selection_mode"):
				initial_selection_mode = json["initial_selection_mode"]
				print("_on_request_completed: Initial selection mode: ", initial_selection_mode)
				if initial_selection_mode:
					message_label.text = "Select 2 cards to reveal."
					selected_initial_cards = []
					var player_node = get_node("GameContainer/Player%d" % player_index)
					if is_instance_valid(player_node):
						for card in player_node.hand:
							card.disabled = false
				else:
					var player_node = get_node("GameContainer/Player%d" % player_index)
					if is_instance_valid(player_node):
						for card in player_node.hand:
							card.disabled = true
							
			if total_players == MAX_PLAYERS:
				print("_on_request_completed: Max players reached, hiding buttons.")
				if create_room_button:
					create_room_button.hide()
				if join_button:
					join_button.hide()
					
			print("_on_request_completed: Exiting 'join' case.")
		
		"state":
			print("_on_request_completed: Matched 'state'. Processing state update.")
			if json.has("initial_selection_mode"):
				initial_selection_mode = json["initial_selection_mode"]
				if initial_selection_mode:
					message_label.text = "Select 2 cards to reveal."
					selected_initial_cards = []
					var player_node = get_node("GameContainer/Player%d" % player_index)
					if is_instance_valid(player_node) and player_node.is_setup:
						player_node.update_hand_display(player_node.hand.map(func(card): return card.card_data))
				else:
					var player_node = get_node("GameContainer/Player%d" % player_index)
					if is_instance_valid(player_node) and player_node.is_setup:
						player_node.update_hand_display(player_node.hand.map(func(card): return card.card_data))
			
			if json.has("players"):
				for player_data in json["players"]:
					var player_index = player_data["index"]
					if player_data.has("hand"):
						var player_node = get_node("GameContainer/Player%d" % player_index)
						if is_instance_valid(player_node) and player_node.is_setup:
							player_node.update_hand_display(player_data["hand"])
			
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
						var player_node = get_node("GameContainer/Player%d" % player_index)
						if is_instance_valid(player_node) and player_node.is_setup:
							player_node.update_hand_display(hand)
				else:
					if king_player_index == player_index:
						var player_node = get_node("GameContainer/Player%d" % player_index)
						if is_instance_valid(player_node) and player_node.is_setup:
							player_node.update_hand_display(hand)
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
							var player_node = get_node("GameContainer/Player%d" % i)
							if is_instance_valid(player_node) and player_node.is_setup:
								var player_node_update = get_node("GameContainer/Player%d" % i)
								if is_instance_valid(player_node_update) and player_node_update.is_setup:
									player_node_update.update_hand_display(json["players"][i].get("hand", []))
								if i == jack_player_index:
									for card in player_node.hand:
										card.disabled = false
									break
				else:
					if jack_player_index != -1:
						for i in range(total_players):
							var player_node = get_node("GameContainer/Player%d" % i)
							if is_instance_valid(player_node) and player_node.is_setup:
								player_node.update_hand_display(player_node.hand.map(func(card): return card.card_data))
						jack_player_index = -1
				
			if !king_reveal_mode and !jack_swap_mode:
				message_label.text = "Your turn!" if player_index == current_turn_index else "Waiting for player %d" % (current_turn_index + 1)
				if json.has("reaction_mode"):
					reaction_mode = json["reaction_mode"]
					reaction_value = json.get("reaction_value", null)
				if json.has("queens_triggered"):
					queens_triggered = json["queens_triggered"]
					final_round_active = json.get("final_round_active", false)
					queens_player_index = json.get("queens_player_index", -1)
				if json.has("game_over"):
					message_label.text = json["message"]
					poll_timer.stop()
					if json.has("winner"):
						message_label.text = json["message"]
					else:
						message_label.text = json["message"]
					queens_button.disabled = true
					for card in get_node("GameContainer/Player%d" % player_index).hand:
						card.disabled = true
				if json.has("message"):
					if !king_reveal_mode and !jack_swap_mode:
						message_label.text = json["message"]
		
		"select_initial_cards":
			print("_on_request_completed: Matched 'select_initial_cards'.")
			if json.has("initial_selection_mode"):
				initial_selection_mode = json["initial_selection_mode"]
				if !initial_selection_mode:
					message_label.text = "Game starting! First player's turn."
					if json.has("players"):
						for player_data in json["players"]:
							var player_node = get_node("GameContainer/Player%d" % player_data["index"])
							if is_instance_valid(player_node) and player_node.is_setup:
								player_node.update_hand_display(player_data["hand"])
					if json.has("current_turn_index"):
						current_turn_index = json["current_turn_index"]
						message_label.text = "Your turn!" if player_index == current_turn_index else "Waiting for player %d" % (current_turn_index + 1)
			else:
				message_label.text = "Waiting for other players to select their cards..."
				
		"play_card":
			print("_on_request_completed: Matched 'play_card'.")
			awaiting_play_card_response = false
			poll_timer.start()
			if json.has("players"):
				for player_data in json["players"]:
					var player_node = get_node("GameContainer/Player%d" % player_data["index"])
					if is_instance_valid(player_node) and player_node.is_setup:
						player_node.update_hand_display(player_data["hand"])
			if json.has("current_turn_index"):
				current_turn_index = json["current_turn_index"]
				message_label.text = "Your turn!" if player_index == current_turn_index else "Waiting for player %d" % (current_turn_index + 1)
			if json.has("center_card"):
				center_card = json["center_card"]
				show_center_card(center_card)
		
		"jack_swap":
			print("_on_request_completed: Matched 'jack_swap'.")
			# ... rest of jack_swap handling ...
		
		"king_reveal":
			print("_on_request_completed: Matched 'king_reveal'.")
			# ... rest of king_reveal handling ...

		_:
			print("_on_request_completed: Matched unknown type: ", last_request_type, ". Response: ", json)
			
	fetching = false

func update_player_hand(for_player_index: int, hand_data: Array):
	var player_node = get_node("GameContainer/Player%d" % for_player_index)
	if not is_instance_valid(player_node):
		print("Player node not found for index: ", for_player_index)
		return

	if not player_node.is_setup:
		print(player_node.name, " not set up yet. Deferring hand update.")
		player_node.call_deferred("update_hand_display", hand_data)
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
			if initial_selection_mode:
				should_be_clickable = true
			elif king_reveal_mode and king_player_index == player_index:
				should_be_clickable = true
			elif jack_swap_mode and jack_player_index == player_index:
				should_be_clickable = true
			elif current_turn_index == player_index and not reaction_mode and not king_reveal_mode and not jack_swap_mode and not final_round_active:
				should_be_clickable = true
			elif reaction_mode and current_turn_index == player_index and card_data.get("value") == reaction_value:
				should_be_clickable = true
				
			if final_round_active and player_index == queens_player_index:
				should_be_clickable = false

			card.disabled = not should_be_clickable
			card.mouse_filter = Control.MOUSE_FILTER_PASS if should_be_clickable else Control.MOUSE_FILTER_IGNORE

			if should_be_clickable:
				if !card.pressed.is_connected(func(): _on_card_pressed(card)):
					var connection_result = card.pressed.connect(func(): _on_card_pressed(card))
					if connection_result != OK:
						print("Failed to connect pressed signal for card: ", card_data)
			else:
				if card.pressed.is_connected(func(): _on_card_pressed(card)):
					card.pressed.disconnect(func(): _on_card_pressed(card))

		else:
			card.disabled = true
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE

			face_up = card_data.get("is_face_up", false)
			
			if (jack_swap_mode and player_index == jack_player_index) or (king_reveal_mode and player_index == king_player_index):
				should_be_clickable = true
				card.disabled = false
				card.mouse_filter = Control.MOUSE_FILTER_PASS
				
			if should_be_clickable:
				if !card.pressed.is_connected(func(): _on_card_pressed(card)):
					var connection_result = card.pressed.connect(func(): _on_card_pressed(card))
					if connection_result != OK:
						print("Failed to connect pressed signal for card: ", card_data)
				else:
					if card.pressed.is_connected(func(): _on_card_pressed(card)):
						card.pressed.disconnect(func(): _on_card_pressed(card))

		card.flip_card(face_up)

		if face_up and !card.is_center_card:
			_start_face_up_timer(card)

		player_node.add_card(card, for_player_index == player_index)
	player_node.arrange_hand()
	print("Updated hand for player ", for_player_index, " with ", hand_data.size(), " cards.")

func _start_face_up_timer(card_instance: Node):
	if card_instance.has_meta("reveal_timer"):
		var timer_node = get_node_or_null(card_instance.get_meta("reveal_timer"))
		if is_instance_valid(timer_node):
			timer_node.queue_free()
		card_instance.remove_meta("reveal_timer")

	var reveal_timer = Timer.new()
	card_instance.add_child(reveal_timer)
	reveal_timer.wait_time = 3.0
	reveal_timer.one_shot = true
	
	reveal_timer.timeout.connect(func(): 
		if is_instance_valid(card_instance) and !card_instance.is_center_card:
			card_instance.flip_card(false)
			reveal_timer.queue_free()
			card_instance.remove_meta("reveal_timer")
	)

	reveal_timer.start()
	card_instance.set_meta("reveal_timer", reveal_timer.get_path())
	print("Started 3-second reveal timer for card: ", card_instance.card_data)

func _on_card_pressed(card_instance: Node):
	print("Card pressed: ", card_instance.card_data)
	var card_data = card_instance.card_data

	if initial_selection_mode:
		print("In initial selection mode")
		var player_node = get_node("GameContainer/Player%d" % player_index)

		if !is_instance_valid(card_instance):
			print("Card instance is no longer valid.")
			return

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

		var revealing_count = 0
		for card in player_node.hand:
			if is_instance_valid(card) and card.has_meta("revealing_timer"):
				revealing_count += 1

		print("Current revealing count: ", revealing_count, ", Selected cards: ", selected_initial_cards.size())
		if selected_initial_cards.size() + revealing_count >= 2:
			print("Already selected maximum number of cards")
			return

		print("Flipping card and starting reveal timer")
		card_instance.flip_card(true)
		card_instance.disabled = true

		var reveal_timer = Timer.new()
		card_instance.add_child(reveal_timer)
		reveal_timer.wait_time = 3.0
		reveal_timer.one_shot = true
		reveal_timer.timeout.connect(func(): _on_initial_card_reveal_timeout(card_data.card_id))
		reveal_timer.start()
		card_instance.set_meta("revealing_timer", reveal_timer.get_path())

		message_label.text = "Revealing card... Select %d more." % [2 - (selected_initial_cards.size() + revealing_count + 1)]
		return

	if king_reveal_mode and king_player_index == player_index:
		print("In king reveal mode")
		var player_node = get_node("GameContainer/Player%d" % player_index)

		if !is_instance_valid(card_instance):
			print("Card instance is no longer valid.")
			return

		if card_instance.has_meta("revealing_timer"):
			print("Card is already revealing.")
			return

		print("Flipping card and starting reveal timer")
		card_instance.flip_card(true)
		card_instance.disabled = true

		var reveal_timer = Timer.new()
		card_instance.add_child(reveal_timer)
		card_instance.set_meta("revealing_timer", reveal_timer.get_path())

		message_label.text = "Revealing card for 3 seconds..."
		return

	if jack_swap_mode and jack_player_index == player_index:
		var player_node = get_node("GameContainer/Player%d" % player_index)
		var opponent_node = get_node("GameContainer/Player%d" % ((player_index + 1) % total_players))
		
		if jack_swap_selection["from"] == null:
			if player_node.hand.has(card_data):
				jack_swap_selection["from"] = card_data
				message_label.text = "Now select a card from opponent's hand to swap with."
		else:
			if opponent_node.hand.has(card_data):
				jack_swap_selection["to"] = card_data
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
		awaiting_play_card_response = false
		poll_timer.start()
	else:
		print("Play card request sent: ", payload)

func add_card_to_hand(card_data: Dictionary, for_player_index: int):
	print("Adding card to player", for_player_index, "  local player index:", player_index)
	var card = preload("res://scenes/Card.tscn").instantiate()
	card.set_data(card_data)
	var player_node = get_node_or_null("GameContainer/Player%d" % for_player_index)
	if not player_node:
		return
	if for_player_index == player_index:
		card.flip_card(true)
		card.pressed.connect(func(): _on_card_pressed(card))
		card.disabled = false 
	else:
		card.disabled = true
		card.flip_card(false) 
	player_node.add_card(card, for_player_index == player_index)
	player_node.arrange_hand()

func show_center_card(card_data: Dictionary):
	for child in $"GameContainer/CenterCardSlot".get_children():
		child.queue_free()
	
	if card_data and card_data.has("suit") and card_data.has("rank"):
		var card = preload("res://scenes/Card.tscn").instantiate()
		card.set_data(card_data)
		card.disabled = true
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.is_center_card = true
		card.flip_card(true)
		card.position = Vector2.ZERO
		$"GameContainer/CenterCardSlot".add_child(card)
		print("Center card displayed: ", card_data)
	else:
		print("No valid center card data")
		
func play_card(card_data: Dictionary):
	print("play_card function called, likely unnecessary with current server interaction.")
	pass

func ensure_player_nodes():
	var game_container = get_node_or_null("GameContainer")
	if not game_container:
		print("Error: GameContainer node not found!")
		return
	
	for i in range(total_players):
		var player_node_path = "GameContainer/Player%d" % i
		var player_node = game_container.get_node_or_null(player_node_path)
		
		if not is_instance_valid(player_node):
			print("ensure_player_nodes: Instantiating and adding player node ", player_node_path)
			# Instantiate and add the player node if it doesn't exist
			var p = preload("res://scenes/Player.tscn").instantiate()
			p.name = player_node_path.get_file().replace(".tscn", "") # Set node name
			game_container.add_child(p)
			player_node = p # Use the newly created node
			
		# Ensure the player_node is valid before proceeding
		if is_instance_valid(player_node):
			print("ensure_player_nodes: Player node ", player_node.name, " is valid.")
			print("ensure_player_nodes: Children of ", player_node.name, ": ", player_node.get_children())
			# Get the HandContainer node from the instantiated player node
			var hand_container_node = player_node.get_node_or_null("HandContainer")
			print("ensure_player_nodes: Result of get_node_or_null(\"HandContainer\"): ", hand_container_node)
			if is_instance_valid(hand_container_node):
				# Assign the HandContainer reference to the player script
				player_node.hand_container = hand_container_node
				print(player_node.name, " HandContainer assigned by main.gd.")
			else:
				print("Error: HandContainer not found in instantiated player node ", player_node.name)
		else:
			print("Error: Instantiated player node is invalid: ", player_node_path)

func fetch_state():
	if not has_joined or room_id.is_empty() or player_id.is_empty():
		return
		
	if fetching:
		return
		
	fetching = true
	last_request_type = "state"
	var url = BASE_URL + "state?room_id=" + room_id + "&player_id=" + player_id
	var headers = [
		"Accept: application/json",
		"Access-Control-Allow-Origin: *"
	]
	print("Fetching state with URL: ", url)
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
		var player_node = get_node("GameContainer/Player%d" % player_index)
		var card_instance = null
		for card in player_node.hand:
			if card.card_data.card_id == card_id:
				card_instance = card
				break

		if !card_instance:
			print("Card instance not found after timer.")
			return

		selected_initial_cards.append(card_instance.card_data)
		card_instance.flip_card(false)
		card_instance.disabled = true

		var timer_path = card_instance.get_meta("revealing_timer")
		if timer_path:
			var timer_node = get_node(timer_path)
			if timer_node:
				timer_node.queue_free()
			card_instance.remove_meta("revealing_timer")

		print("Selected initial cards count: ", selected_initial_cards.size())

		if selected_initial_cards.size() == 2:
			message_label.text = "Two cards selected. Sending to server..."
			
			for card in player_node.hand:
				card.disabled = true

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
			poll_timer.stop()
			awaiting_play_card_response = true
			var error = http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
			if error != OK:
				message_label.text = "Failed to send initial card selection"
				awaiting_play_card_response = false
				poll_timer.start()
			else:
				print("Initial card selection sent: ", payload)
				message_label.text = "Waiting for other players..."
		else:
			message_label.text = "Select %d more card(s)." % [2 - selected_initial_cards.size()]

	else:
		print("Timeout occurred outside of initial selection mode.")

func _on_king_reveal_timeout(card_id: String):
	print("King reveal timeout for card: ", card_id)

	if king_reveal_mode:
		var player_node = get_node("GameContainer/Player%d" % player_index)
		var card_instance = null
		for card in player_node.hand:
			if card.card_data.card_id == card_id:
				card_instance = card
				break

		if !card_instance:
			print("Card instance not found after timer.")
			return

		card_instance.flip_card(false)
		card_instance.disabled = true

		var timer_path = card_instance.get_meta("revealing_timer")
		if timer_path:
			var timer_node = get_node(timer_path)
			if timer_node:
				timer_node.queue_free()
			card_instance.remove_meta("revealing_timer")

		last_request_type = "king_reveal"
		var url = BASE_URL + "king_reveal"
		var headers = ["Content-Type: application/json"]
		var payload = {
			"room_id": room_id,
			"player_index": player_index,
			"revealed_card_id": card_id
		}
		poll_timer.stop()
		awaiting_play_card_response = true
		var error = http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
		if error != OK:
			message_label.text = "Failed to send king reveal"
			awaiting_play_card_response = false
			poll_timer.start()
		else:
			print("King reveal sent: ", payload)
			message_label.text = "Waiting for next turn..."
	else:
		print("Timeout occurred outside of king reveal mode.")

func _on_card_played(card_data: Dictionary):
	print("Card played: ", card_data)
	
	if player_index != current_turn_index:
		print("Not current player's turn. Cannot play card.")
		return

	if awaiting_play_card_response:
		print("Already awaiting play card response. Ignoring.")
		return

	awaiting_play_card_response = true
	last_request_type = "play_card"

	var url = BASE_URL + "play_card"
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({
		"room_id": room_id,
		"player_index": player_index,
		"card_id": card_data["card_id"]
	})

	print("Playing card on server. URL: ", url, ", Body: ", body)
	http.request(url, headers, HTTPClient.METHOD_POST, body)
