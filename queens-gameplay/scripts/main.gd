extends Control

@onready var http := $HTTPRequest
@onready var effects := $Effects
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
var is_request_in_progress := false
var initial_selection_mode := false
var selected_initial_cards: Array = []
var king_reveal_mode := false
var king_player_index := -1
var jack_player_index := -1
var queens_player_index := -1
var MAX_PLAYERS = 4

const BASE_URL = "http://localhost:3000/"

var _initial_selected_cards = []
var game_started := false
var countdown := 0
var used_deck: Array = []

func _ready():
	if RoomState.room_id != "":
		room_id = RoomState.room_id
		join_game()
		return
		
	# Always generate a new unique player_id
	var timestamp = Time.get_unix_time_from_system()
	var random_num = randi() % 1000000
	player_id = "%d_%d" % [timestamp, random_num]
	
	add_child(poll_timer)
	poll_timer.wait_time = 1.0
	poll_timer.timeout.connect(fetch_state)
	
	room_update_timer = Timer.new()
	add_child(room_update_timer)
	room_update_timer.wait_time = 3.0
	room_update_timer.timeout.connect(refresh_room_list)
	room_update_timer.start()
	
	if not http.request_completed.is_connected(_on_request_completed):
		http.request_completed.connect(_on_request_completed)
	
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
	if is_request_in_progress:
		return
	
	is_request_in_progress = true
	last_request_type = "create_room"
	var url = BASE_URL + "create_room"
	var headers = ["Content-Type: application/json"]
	var body = "{}"
	
	player_index = 0
	
	$MenuContainer.hide()
	$GameContainer.show()
	
	ensure_player_nodes()
	
	http.request(url, headers, HTTPClient.METHOD_POST, body)

func refresh_room_list():
	if is_request_in_progress:
		return
	is_request_in_progress = true
	last_request_type = "list_rooms"
	var url = BASE_URL + "rooms"
	var headers = [
		"Accept: application/json",
		"Access-Control-Allow-Origin: *"
	]
	http.request(url, headers, HTTPClient.METHOD_GET)

func join_game(selected_room_id: String = ""):
	if not selected_room_id.is_empty():
		room_id = selected_room_id
	
	if room_id.is_empty():
		message_label.text = "Please select a room first"
		return
		
	if is_request_in_progress:
		return
		
	print("[JOIN GAME] Attempting to join room:", room_id)
	
	effects.animate_text_fade(message_label, "Joining room...")
	$MenuContainer.visible = false
	$GameContainer.visible = true
	if room_name_label:
		room_name_label.text = "Room: " + room_id
	
	is_request_in_progress = true
	last_request_type = "join"
	var url = BASE_URL + "join"
	var headers = [
		"Content-Type: application/json",
		"Accept: application/json",
		"Access-Control-Allow-Origin: *"
	]
	var body_dict = { "room_id": room_id }
	if player_id != "":
		body_dict["player_id"] = player_id
	var body = JSON.stringify(body_dict)
	print("[JOIN GAME] Sending request with player_id:", player_id)
	http.request(url, headers, HTTPClient.METHOD_POST, body)

func _on_queens_pressed():
	if message_label.text != "": return
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
	is_request_in_progress = false
	
	if result != HTTPRequest.RESULT_SUCCESS:
		return
		
	var json = JSON.parse_string(body.get_string_from_utf8())
	
	if not json:
		return

	if json.has("status") and json.status == "error":
		if json.has("message"):
			message_label.text = json.message
		return

	match last_request_type:
		"list_rooms":
			update_room_list(json.rooms)
		"create_room":
			if json.has("room_id"):
				room_id = json.room_id
				room_name_label.text = "Room: " + room_id.left(5) + "..."
				join_game(room_id)
		"join":
			if json.has("player_id") and json.has("player_index"):
				room_update_timer.stop()
				
				player_id = json.player_id
				player_index = int(json.player_index)
				room_id = json.room_id
				total_players = json.total_players if json.has("total_players") else 0
				current_turn_index = int(json.current_turn_index) if json.has("current_turn_index") else -1
				initial_selection_mode = json.initial_selection_mode if json.has("initial_selection_mode") else false
				
				ensure_player_nodes()
				
				await get_tree().process_frame
				
				$MenuContainer.hide()
				$GameContainer.show()
				room_name_label.text = "Room: " + room_id.left(5) + "..."
				
				has_joined = true
				
				if player_index == 0:
					fetch_state()
				poll_timer.start()
		"state":
			process_state_response(json)
		"select_initial_cards":
			if json.has("status") and json.status == "ok":
				if json.has("game_started") and json.game_started:
					initial_selection_mode = false
					game_started = true
					
					if json.has("all_players_ready") and json.all_players_ready:
						current_turn_index = int(json.current_turn_index)
						queens_button.visible = true
						
						if player_index == current_turn_index:
							message_label.text = "Game started - It's your turn!"
						else:
							message_label.text = "Game started - Opponent's turn!"
						
						for i in range(2):
							var container_name = "BottomPlayerContainer" if i == player_index else "TopPlayerContainer"
							var player_node = $GameContainer.get_node_or_null("%s/Player%d" % [container_name, i])
							if is_instance_valid(player_node):
								var hand_container = player_node.get_node("HandContainer")
								if hand_container:
									for card in hand_container.get_children():
										card.disabled = (i != current_turn_index)
										card.modulate = Color(1, 1, 1)
										if i == player_index:
											card.flip_card(false)
					else:
						game_started = false
						message_label.text = "Waiting for other players..."
				
				if json.has("message"):
					message_label.text = json.message
				
				if json.has("center_card") and json.center_card:
					show_center_card(json.center_card)

func update_player_hand(for_player_index: int, hand_data: Array):
	var container_name = "BottomPlayerContainer" if for_player_index == player_index else "TopPlayerContainer"
	
	var player_node = $GameContainer.get_node_or_null("%s/Player%d" % [container_name, for_player_index])
	if not is_instance_valid(player_node):
		player_node = $GameContainer.get_node_or_null("Player%d" % for_player_index)
		if is_instance_valid(player_node):
			var container = $GameContainer.get_node_or_null(container_name)
			if container:
				player_node.get_parent().remove_child(player_node)
				container.add_child(player_node)
		else:
			push_error("Error: Player node not found")
			return
	
	player_node.update_hand_display(hand_data, for_player_index == player_index, initial_selection_mode)

func show_center_card(card_data: Dictionary):
	if center_card_slot:
		for child in center_card_slot.get_children():
			if child.name != "PreviewCard":
				child.queue_free()
	
	var card_node = preload("res://scenes/card.tscn").instantiate()
	if card_node:
		card_node.set_data(card_data)
		card_node.flip_card(true)
		card_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_node.focus_mode = Control.FOCUS_NONE
		card_node.mouse_default_cursor_shape = Control.CURSOR_ARROW
		card_node.is_center_card = true
		card_node.position = Vector2.ZERO
		center_card_slot.add_child(card_node)
	
	center_card = card_data.duplicate()

func ensure_player_nodes():
	var bottom_container = $GameContainer.get_node_or_null("BottomPlayerContainer")
	var top_container = $GameContainer.get_node_or_null("TopPlayerContainer")
	
	if not bottom_container:
		push_error("Error: Bottom container not found")
		return
		
	if not top_container:
		push_error("Error: Top container not found")
		return
	
	bottom_container.size = Vector2(1000, 250)
	bottom_container.custom_minimum_size = Vector2(1000, 250)
	bottom_container.position = Vector2(50, 500)
	
	top_container.size = Vector2(1000, 250)
	top_container.custom_minimum_size = Vector2(1000, 250)
	top_container.position = Vector2(50, 50)
	
	for child in bottom_container.get_children():
		child.queue_free()
	for child in top_container.get_children():
		child.queue_free()
	
	var player_scene = load("res://scenes/Player.tscn")
	if not player_scene:
		push_error("Error: Failed to load Player.tscn scene file")
		return
	
	var player0_node = player_scene.instantiate()
	if not player0_node:
		push_error("Error: Failed to instantiate Player0 scene")
		return
	
	var hand_container0 = player0_node.get_node_or_null("HandContainer")
	if not hand_container0:
		push_error("Error: HandContainer not found in Player0 node")
		player0_node.queue_free()
		return
	
	player0_node.name = "Player0"
	if player_index == 0:
		bottom_container.add_child(player0_node)
		player0_node.setup_player(0, player_id)
		if not player0_node.initial_selection_complete.is_connected(_on_initial_selection_complete):
			player0_node.initial_selection_complete.connect(_on_initial_selection_complete)
	else:
		top_container.add_child(player0_node)
		player0_node.setup_player(0, "")
	
	var player1_node = player_scene.instantiate()
	if not player1_node:
		push_error("Error: Failed to instantiate Player1 scene")
		return
	
	var hand_container1 = player1_node.get_node_or_null("HandContainer")
	if not hand_container1:
		push_error("Error: HandContainer not found in Player1 node")
		player1_node.queue_free()
		return
	
	player1_node.name = "Player1"
	if player_index == 1:
		bottom_container.add_child(player1_node)
		player1_node.setup_player(1, player_id)
		if not player1_node.initial_selection_complete.is_connected(_on_initial_selection_complete):
			player1_node.initial_selection_complete.connect(_on_initial_selection_complete)
	else:
		top_container.add_child(player1_node)
		player1_node.setup_player(1, "")
	
	$GameContainer.visible = true
	$GameContainer.modulate = Color(1, 1, 1)
	
	bottom_container.visible = true
	bottom_container.modulate = Color(1, 1, 1)
	
	top_container.visible = true
	top_container.modulate = Color(1, 1, 1)
	
	await get_tree().process_frame

func _on_initial_selection_complete(selected_card_ids: Array):
	if is_request_in_progress:
		return

	if room_id.is_empty() or player_id.is_empty():
		return

	is_request_in_progress = true
	last_request_type = "select_initial_cards"
	var url = BASE_URL + "select_initial_cards"
	var headers = ["Content-Type: application/json"]

	var body = JSON.stringify({
		"room_id": room_id,
		"player_index": player_index,
		"selected_card_ids": selected_card_ids
	})
	http.request(url, headers, HTTPClient.METHOD_POST, body)
	message_label.text = "Initial cards selected! Waiting for other players..."

func fetch_state():
	if not has_joined or room_id.is_empty() or player_id.is_empty():
		poll_timer.start()
		return
		
	if is_request_in_progress:
		poll_timer.start()
		return
		
	if not validate_game_state():
		push_error("Error: Invalid game state - reinitializing...")
		reinitialize_game_state()
		return
		
	is_request_in_progress = true
	last_request_type = "state"
	
	var url = BASE_URL + "state?room_id=" + room_id + "&player_id=" + player_id
	
	var headers = [
		"Accept: application/json",
		"Access-Control-Allow-Origin: *"
	]
	
	# Create a timeout timer that will be cleaned up after use
	var timeout_timer = Timer.new()
	timeout_timer.name = "StateRequestTimer"
	add_child(timeout_timer)
	timeout_timer.wait_time = 10.0  # Increased timeout to 10 seconds
	timeout_timer.one_shot = true
	timeout_timer.timeout.connect(func():
		if is_request_in_progress and last_request_type == "state":
			push_error("Error: State fetch request timed out")
			is_request_in_progress = false
			# Retry the request after a short delay
			var retry_timer = Timer.new()
			add_child(retry_timer)
			retry_timer.wait_time = 2.0
			retry_timer.one_shot = true
			retry_timer.timeout.connect(func():
				retry_timer.queue_free()
				fetch_state()
			)
			retry_timer.start()
		timeout_timer.queue_free()
	)
	
	# Connect to request completion to cleanup timer
	if not http.request_completed.is_connected(_on_state_request_completed):
		http.request_completed.connect(_on_state_request_completed)
	
	var error = http.request(url, headers, HTTPClient.METHOD_GET)
	if error != OK:
		push_error("Error: Failed to fetch state, error code: %d" % error)
		is_request_in_progress = false
		timeout_timer.queue_free()
		poll_timer.start()
		return
		
	timeout_timer.start()

func _on_state_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	# Clean up the timeout timer if it exists
	var timeout_timer = get_node_or_null("StateRequestTimer")
	if timeout_timer:
		timeout_timer.queue_free()
	
	# Disconnect this specific completion handler
	if http.request_completed.is_connected(_on_state_request_completed):
		http.request_completed.disconnect(_on_state_request_completed)
	
	# Process the response
	is_request_in_progress = false
	
	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("Error: State request failed with result code %d" % result)
		poll_timer.start()
		return
		
	if response_code != 200:
		push_error("Error: Server returned status code %d" % response_code)
		poll_timer.start()
		return
		
	var json = JSON.parse_string(body.get_string_from_utf8())
	if not json:
		push_error("Error: Invalid JSON response from server")
		poll_timer.start()
		return
		
	process_state_response(json)
	poll_timer.start()

func validate_game_state() -> bool:
	if not is_instance_valid($GameContainer):
		return false
		
	if player_index < 0 or player_index >= MAX_PLAYERS:
		return false
		
	var bottom_container = $GameContainer.get_node_or_null("BottomPlayerContainer")
	var top_container = $GameContainer.get_node_or_null("TopPlayerContainer")
	
	if not is_instance_valid(bottom_container) or not is_instance_valid(top_container):
		return false
		
	var player_node = $GameContainer.get_node_or_null("%s/Player%d" % ["BottomPlayerContainer", player_index])
	if not is_instance_valid(player_node):
		return false
		
	return true

func reinitialize_game_state():
	current_turn_index = -1
	initial_selection_mode = false
	game_started = false
	_initial_selected_cards.clear()
	
	ensure_player_nodes()
	
	$MenuContainer.hide()
	$GameContainer.show()
	if room_name_label:
		room_name_label.text = "Room: " + room_id.left(5) + "..."
	
	poll_timer.start()

func process_state_response(json: Dictionary):
	if not json:
		push_error("Error: Empty state response")
		return
		
	if json.has("error"):
		push_error("Error from server: " + str(json.error))
		return
		
	if json.has("initial_selection_mode"):
		initial_selection_mode = json.initial_selection_mode
	if json.has("total_players"):
		total_players = json.total_players
	
	if json.has("players"):
		for p_data in json.players:
			if not p_data.has("index"):
				continue
				
			var p_index = int(p_data.index)
			if p_index < 0 or p_index >= MAX_PLAYERS:
				continue
			
			var container_name = "BottomPlayerContainer" if p_index == player_index else "TopPlayerContainer"
			var container = $GameContainer.get_node_or_null(container_name)
			if not container:
				push_error("Container not found: " + container_name)
				continue
			
			var player_node = container.get_node_or_null("Player%d" % p_index)
			if not is_instance_valid(player_node):
				ensure_player_nodes()
				await get_tree().process_frame
				player_node = container.get_node_or_null("Player%d" % p_index)
				
				if not is_instance_valid(player_node):
					push_error("Failed to create player node after ensure_player_nodes")
					continue
			
			if is_instance_valid(player_node):
				if p_data.has("hand"):
					var hand_data = p_data.hand
					if typeof(hand_data) == TYPE_ARRAY:
						var processed_hand = []
						for card in hand_data:
							if typeof(card) == TYPE_DICTIONARY and card.has("card_id"):
								var card_data = {
									"card_id": card.card_id,
									"is_face_up": p_index == player_index,
									"rank": card.rank if card.has("rank") else "0",
									"suit": card.suit if card.has("suit") else "Unknown",
									"value": float(card.rank) if card.has("rank") else 0.0
								}
								processed_hand.append(card_data)
						
						if processed_hand.size() > 0:
							player_node.update_hand_display(processed_hand, p_index == player_index, initial_selection_mode)
						else:
							push_warning("Warning: No valid cards processed for player " + str(p_index))
					else:
						push_warning("Warning: Invalid hand data type for player " + str(p_index))
				else:
					push_warning("Warning: No hand data for player " + str(p_index))
			else:
				push_error("Error: Player node not valid after creation attempt")
	
	if json.has("current_turn_index"):
		var old_turn_index = current_turn_index
		current_turn_index = int(json.current_turn_index)
		
		if old_turn_index != current_turn_index and not initial_selection_mode:
			if current_turn_index == player_index:
				message_label.text = "Your turn!"
			else:
				message_label.text = "Opponent's turn!"
	
	if json.has("center_card") and not initial_selection_mode:
		show_center_card(json.center_card)

func display_container_error(container: Node, error_message: String):
	if not container:
		return
		
	# Create error label
	var error_label = Label.new()
	error_label.text = "Error: " + error_message
	error_label.modulate = Color(1, 0, 0)  # Red color
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(error_label)
	
	# Create error background
	var error_bg = ColorRect.new()
	error_bg.custom_minimum_size = Vector2(200, 50)
	error_bg.color = Color(0.8, 0, 0, 0.3)  # Semi-transparent red
	error_bg.show_behind_parent = true
	container.add_child(error_bg)
	


func _on_room_selected(idx):
	if room_list:
		room_id = room_list.get_item_metadata(idx)
		join_game(room_id)

func _on_join_pressed():
	effects.animate_text_fade(message_label, "Joining room...")
	join_game()

func update_message(text: String, is_error: bool = false):
	message_label.modulate = Color(1, 0, 0) if is_error else Color(1, 1, 1)
	effects.animate_text_pop(message_label, text)

func _on_card_reveal_pressed(card_node):
	if not king_reveal_mode:
		return
		
	if is_request_in_progress:
		return
		
	card_node.flip_card(true)
	card_node.modulate = Color(0.7, 1.0, 0.7)
	
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 3.0
	timer.one_shot = true
	timer.timeout.connect(func():
		if is_instance_valid(card_node):
			card_node.flip_card(false)
			card_node.modulate = Color(1, 1, 1)
		
		var player_node = $GameContainer.get_node_or_null("BottomPlayerContainer/Player%d" % player_index)
		if is_instance_valid(player_node):
			var hand_container = player_node.get_node("HandContainer")
			if hand_container:
				for card in hand_container.get_children():
					if card.rank == "13" and card.disabled:
						add_to_used_deck(card)
						card.queue_free()
						break
	)	
	timer.start()
	
	is_request_in_progress = true
	last_request_type = "king_reveal"
	var url = BASE_URL + "king_reveal"
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({
		"room_id": room_id,
		"player_index": player_index,
		"revealed_card_id": card_node.card_data.card_id,
		"temporary_reveal": true
	})
	http.request(url, headers, HTTPClient.METHOD_POST, body)
	
	disable_all_cards()

func _on_card_played(card_data):
	var player_node = $GameContainer.get_node_or_null("BottomPlayerContainer/Player%d" % player_index)
	if not is_instance_valid(player_node):
		return
		
	if current_turn_index != player_index:
		return
	
	if initial_selection_mode:
		return
	
	if card_data.rank == "13":
		king_reveal_mode = true
		king_player_index = player_index
		message_label.text = "King played! Choose one of your cards to reveal."
		
		var hand_container = player_node.get_node("HandContainer")
		if hand_container:
			for card in hand_container.get_children():
				if card.card_data.card_id == card_data.card_id:
					card.disabled = true
					card.modulate = Color(0.7, 0.7, 0.7)
					card.mouse_filter = Control.MOUSE_FILTER_IGNORE
			
		enable_king_reveal_mode()
		
	elif card_data.rank == "11":
		jack_swap_mode = true
		jack_player_index = player_index
		message_label.text = "Jack played! Select a card to swap."
		
		var hand_container = player_node.get_node("HandContainer")
		if hand_container:
			for card in hand_container.get_children():
				if card.card_data.card_id == card_data.card_id:
					card.disabled = true
					card.modulate = Color(0.7, 0.7, 0.7)
					card.mouse_filter = Control.MOUSE_FILTER_IGNORE
			
		enable_jack_swap_mode()
		
	elif card_data.rank == "12":
		message_label.text = "Queen played! Card will be added to opponent's hand."
		show_center_card({})
	else:
		show_center_card(card_data)
	
	send_play_card(card_data.card_id)

func send_initial_cards_selection(selected_cards_data: Array):
	if is_request_in_progress:
		return

	if room_id.is_empty() or player_id.is_empty():
		return

	is_request_in_progress = true
	last_request_type = "select_initial_cards"
	var url = BASE_URL + "select_initial_cards"
	var headers = ["Content-Type: application/json"]

	var card_ids = []
	for card in selected_cards_data:
		card_ids.append(card.card_id)

	var body = JSON.stringify({
		"room_id": room_id,
		"player_index": player_index,
		"selected_card_ids": card_ids
	})
	http.request(url, headers, HTTPClient.METHOD_POST, body)

func send_play_card(card_id: String):
	if is_request_in_progress:
		return

	if room_id.is_empty() or player_id.is_empty():
		return

	is_request_in_progress = true
	last_request_type = "play_card"
	var url = BASE_URL + "play_card"
	var headers = ["Content-Type: application/json"]

	var body = JSON.stringify({
		"room_id": room_id,
		"player_index": player_index,
		"card_id": card_id
	})
	http.request(url, headers, HTTPClient.METHOD_POST, body)

func update_room_list(rooms: Array):
	if room_list and not has_joined:
		room_list.clear()
		for room in rooms:
			var id = room.get("id", "N/A")
			var player_count = room.get("players", 0)
			var max_players = room.get("max_players", 2)
			var label = "Room %s (%d/%d players)" % [id.left(5) + "...", player_count, max_players]
			room_list.add_item(label)
			room_list.set_item_metadata(room_list.item_count - 1, id)

func update_center_preview(card_data: Dictionary):
	if center_card_slot:
		var preview_card = center_card_slot.get_node_or_null("PreviewCard")
		if not preview_card:
			preview_card = preload("res://scenes/card.tscn").instantiate()
			preview_card.name = "PreviewCard"
			preview_card.is_center_card = true
			center_card_slot.add_child(preview_card)
		
		var preview_data = card_data.duplicate()
		preview_data["is_face_up"] = true
		
		preview_card.set_data(preview_data)
		preview_card.flip_card(true)
		preview_card.modulate.a = 0.5
		preview_card.position = Vector2.ZERO
		preview_card.z_index = 1

func clear_center_preview():
	if center_card_slot:
		var preview_card = center_card_slot.get_node_or_null("PreviewCard")
		if preview_card:
			preview_card.queue_free()

func add_to_used_deck(card_node: Node):
	used_deck.append(card_node.card_data)

func enable_king_reveal_mode():
	var player_node = $GameContainer.get_node_or_null("BottomPlayerContainer/Player%d" % player_index)
	if is_instance_valid(player_node):
		var hand_container = player_node.get_node("HandContainer")
		if hand_container:
			for card in hand_container.get_children():
				if card.has_method("flip_card"):
					card.disabled = false
					if not card.pressed.is_connected(_on_card_reveal_pressed):
						card.pressed.connect(_on_card_reveal_pressed.bind(card))

func enable_jack_swap_mode():
	var player_node = $GameContainer.get_node_or_null("BottomPlayerContainer/Player%d" % player_index)
	if is_instance_valid(player_node):
		var hand_container = player_node.get_node("HandContainer")
		if hand_container:
			for card in hand_container.get_children():
				if card.has_method("flip_card"):
					card.disabled = false
					if not card.pressed.is_connected(_on_card_swap_pressed):
						card.pressed.connect(_on_card_swap_pressed.bind(card))

func _on_card_swap_pressed(card_node):
	if not jack_swap_mode:
		return
		
	if jack_swap_selection.from == null:
		jack_swap_selection.from = card_node.card_data.card_id
		card_node.modulate = Color(0.7, 1.0, 0.7)
		message_label.text = "Now select opponent's card to swap with"
		
		var opponent_index = (player_index + 1) % 2
		var opponent_node = $GameContainer.get_node_or_null("TopPlayerContainer/Player%d" % opponent_index)
		if is_instance_valid(opponent_node):
			for card in opponent_node.get_node("HandContainer").get_children():
				card.disabled = false
				if not card.pressed.is_connected(_on_card_swap_pressed):
					card.pressed.connect(_on_card_swap_pressed.bind(card))
	else:
		jack_swap_selection.to = card_node.card_data.card_id
		
		is_request_in_progress = true
		last_request_type = "jack_swap"
		var url = BASE_URL + "jack_swap"
		var headers = ["Content-Type: application/json"]
		var body = JSON.stringify({
			"room_id": room_id,
			"player_index": player_index,
			"from_card_id": jack_swap_selection.from,
			"to_card_id": jack_swap_selection.to
		})
		http.request(url, headers, HTTPClient.METHOD_POST, body)
		
		jack_swap_selection = {"from": null, "to": null}
		
		var player_node = $GameContainer.get_node_or_null("BottomPlayerContainer/Player%d" % player_index)
		if is_instance_valid(player_node):
			var hand_container = player_node.get_node("HandContainer")
			if hand_container:
				for card in hand_container.get_children():
					if card.rank == "11" and card.disabled:
						add_to_used_deck(card)
						card.queue_free()
						break
		
		disable_all_cards()

func disable_all_cards():
	for container_name in ["BottomPlayerContainer", "TopPlayerContainer"]:
		for i in range(2):
			var player_node = $GameContainer.get_node_or_null("%s/Player%d" % [container_name, i])
			if is_instance_valid(player_node):
				for card in player_node.get_node("HandContainer").get_children():
					card.disabled = true
					card.modulate = Color(1, 1, 1)
					if card.pressed.is_connected(_on_card_reveal_pressed):
						card.pressed.disconnect(_on_card_reveal_pressed)
					if card.pressed.is_connected(_on_card_swap_pressed):
						card.pressed.disconnect(_on_card_swap_pressed)

func _on_card_pressed(card_node):
	if initial_selection_mode:
		var player_node = $GameContainer/BottomPlayerContainer.get_node_or_null("Player%d" % player_index)
		if not is_instance_valid(player_node) or card_node.holding_player != player_node:
			return

		if _initial_selected_cards.size() >= 2:
			message_label.text = "You have already selected your two cards!"
			return

		var card_data = card_node.card_data
		if card_data.has("was_initially_seen") and card_data.was_initially_seen:
			return

		if not card_data.has("is_locked"):
			card_data["is_locked"] = false

		if card_data.is_locked:
			return

		# Lock all cards during reveal
		for card in player_node.get_node("HandContainer").get_children():
			card.card_data["is_locked"] = true

		# Temporarily reveal the card
		card_node.temporary_reveal()

		# Check if this card was already selected
		var already_selected = false
		for selected_card in _initial_selected_cards:
			if selected_card.card_id == card_data.card_id:
				already_selected = true
				break

		if not already_selected:
			_initial_selected_cards.append(card_data)
			message_label.text = "Select %d more card(s)" % (2 - _initial_selected_cards.size())

			if _initial_selected_cards.size() == 2:
				send_initial_cards_selection(_initial_selected_cards)
				message_label.text = "Initial cards selected! Wait for other players."
				for card in player_node.get_node("HandContainer").get_children():
					card.disabled = true
	else:
		card_node.start_drag()
