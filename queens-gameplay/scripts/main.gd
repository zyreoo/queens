extends Control

@onready var http := $HTTPRequest
@onready var effects := $Effects
@onready var message_label := $MenuContainer/MessageLabel
@onready var queens_button := $GameContainer/queens_button
@onready var room_list := $MenuContainer/RoomList
@onready var center_card_slot := $GameContainer/CenterCardSlot
@onready var room_name_label := $GameContainer/RoomNameLabel
@onready var turn_indicator := $GameContainer/TurnIndicator
@onready var game_over_label := $GameContainer/GameOverLabel

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
var queens_player_index := -1
var MAX_PLAYERS = 4
var is_showing_drawn_card := false
var received_first_turn_card := false

const BASE_URL = "https://web-production-2342a.up.railway.app/"

var _initial_selected_cards = []
var game_started := false
var countdown := 0
var used_deck: Array = []

var animation_time: float = 0.0
const ANIMATION_SPEED: float = 2.0
const ANIMATION_AMPLITUDE: float = 10.0

func _ready():
	var animation_timer = Timer.new()
	animation_timer.name = "CardAnimationTimer"
	animation_timer.wait_time = 0.016
	animation_timer.timeout.connect(_update_card_animations)
	add_child(animation_timer)
	animation_timer.start()
	
	var custom_font = load("res://assets/font/m6x11.ttf")
	if custom_font:
		apply_custom_font($MenuContainer, custom_font)
		apply_custom_font($GameContainer, custom_font)
	
	var menu_container = $MenuContainer
	if menu_container:
		var viewport_size = get_viewport().size
		var menu_size = Vector2(400, 300)
		menu_container.size = menu_size
		menu_container.custom_minimum_size = menu_size
		menu_container.position = Vector2(
			(viewport_size.x - menu_size.x) / 2,
			(viewport_size.y - menu_size.y) / 2
		)
	
	if RoomState.room_id != "":
		room_id = RoomState.room_id
		join_game()
		return
		
	var timestamp = Time.get_unix_time_from_system()
	var random_num = randi() % 1000000
	player_id = "%d_%d" % [timestamp, random_num]
	
	add_child(poll_timer)
	poll_timer.wait_time = 2.0
	poll_timer.timeout.connect(fetch_state)
	
	room_update_timer = Timer.new()
	room_update_timer.wait_time = 2.0
	room_update_timer.timeout.connect(_on_room_update_timer_timeout)
	add_child(room_update_timer)
	room_update_timer.start()
	
	if not http.request_completed.is_connected(_on_request_completed):
		http.request_completed.connect(_on_request_completed)
	
	# Make sure the Queens button is connected
	if queens_button and not queens_button.pressed.is_connected(_on_queens_pressed):
		queens_button.pressed.connect(_on_queens_pressed)
	
	queens_button.visible = false
	
	refresh_room_list()
	call_deferred("get_room_management_nodes")
	call_deferred("add_button_effects_deferred")

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
	http.request(url, headers, HTTPClient.METHOD_POST, body)

func _on_queens_pressed():
	var player0_node = $GameContainer/BottomPlayerContainer.get_node_or_null("Player0")
	var player1_node = $GameContainer/TopPlayerContainer.get_node_or_null("Player1")
	
	var player0_score = calculate_player_score(player0_node)
	var player1_score = calculate_player_score(player1_node)
	
	# Send to server
	last_request_type = "call_queens"
	var url = BASE_URL + "call_queens"
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({
		"room_id": room_id,
		"player_index": player_index,
		"player0_score": player0_score,
		"player1_score": player1_score
	})
	http.request(url, headers, HTTPClient.METHOD_POST, body)
	
	# Update local display
	var winner_text = ""
	if player0_score < player1_score:
		winner_text = "Player 0 wins with score " + str(player0_score) + "! (Player 1 had " + str(player1_score) + ")"
	elif player1_score < player0_score:
		winner_text = "Player 1 wins with score " + str(player1_score) + "! (Player 0 had " + str(player0_score) + ")"
	else:
		winner_text = "It's a tie! Both players have score " + str(player0_score)
	
	game_over_label.text = winner_text
	message_label.text = ""
	
	# Show all cards face up
	if player0_node:
		var hand_container = player0_node.get_node("HandContainer")
		if hand_container:
			for card in hand_container.get_children():
				card.disabled = true
				card.flip_card(true)
	
	if player1_node:
		var hand_container = player1_node.get_node("HandContainer")
		if hand_container:
			for card in hand_container.get_children():
				card.disabled = true
				card.flip_card(true)
	
	# Hide Queens button and clear center
	queens_button.visible = false
	show_center_card({})

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
			if last_request_type == "select_initial_cards":
				_initial_selected_cards.clear()
				var player_node = $GameContainer/BottomPlayerContainer.get_node_or_null("Player%d" % player_index)
				if is_instance_valid(player_node):
					var hand_container = player_node.get_node("HandContainer")
					if hand_container:
						for card in hand_container.get_children():
							card.disabled = false
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
				update_turn_indicator()
				
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
						
						if json.has("first_turn_card") and json.first_turn_card != null and player_index == 0:
							var player_node = $GameContainer/BottomPlayerContainer.get_node_or_null("Player%d" % player_index)
							if is_instance_valid(player_node):
								var card_node = preload("res://scenes/card.tscn").instantiate()
								if card_node:
									card_node.holding_player = player_node
									card_node.set_data(json.first_turn_card)
									var hand_container = player_node.get_node("HandContainer")
									if hand_container:
										hand_container.add_child(card_node)
										card_node.flip_card(true)
										card_node.modulate = Color(1, 1, 0.7)
										
										var timer = Timer.new()
										add_child(timer)
										timer.wait_time = 3.0
										timer.one_shot = true
										timer.timeout.connect(func():
											if is_instance_valid(card_node):
												card_node.flip_card(false)
												card_node.modulate = Color(1, 1, 1)
											timer.queue_free()
										)
										timer.start()
						
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
					else:
						game_started = false
						message_label.text = "Waiting for other players..."
				
				if json.has("message"):
					message_label.text = json.message
				
				if json.has("center_card") and json.center_card:
					show_center_card(json.center_card)
		"draw_card":
			if json.has("card"):
				handle_drawn_card(json.card)
		"call_queens":
			if json.has("status") and json.status == "ok":
				pass

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
	
	if for_player_index == player_index:
		player_node.set_initial_selection_mode(initial_selection_mode)
	player_node.update_hand_display(hand_data, for_player_index == player_index, initial_selection_mode)

func show_center_card(card_data):
	if card_data == null:
		card_data = {}
	
	if not center_card_slot:
		return
		
	# If the card is already shown and has the same ID, don't show it again
	if center_card_slot.get_child_count() > 0:
		var existing_card = center_card_slot.get_child(0)
		if existing_card and existing_card.has_method("get_card_id") and card_data.has("card_id"):
			if existing_card.get_card_id() == card_data.card_id:
				return
	
	# Clear existing cards
	for child in center_card_slot.get_children():
		child.queue_free()
	
	# Only create new card if we have valid data
	if card_data and not card_data.is_empty():
		var card_node = preload("res://scenes/card.tscn").instantiate()
		if card_node:
			card_node.set_data(card_data)
			card_node.flip_card(true)
			card_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card_node.focus_mode = Control.FOCUS_NONE
			card_node.mouse_default_cursor_shape = Control.CURSOR_ARROW
			card_node.is_center_card = true
			card_node.position = Vector2.ZERO
			card_node.z_index = 3
			center_card_slot.add_child(card_node)
		
		center_card = card_data.duplicate()
		queens_button.visible = true
	else:
		center_card = {}
		queens_button.visible = false

func update_center_card_slot_position():
	if center_card_slot:
		var viewport_size = get_viewport().size
		var slot_size = Vector2(100, 150)
		center_card_slot.size = slot_size
		center_card_slot.custom_minimum_size = slot_size
		center_card_slot.position = Vector2(
			(viewport_size.x - slot_size.x) / 2,
			(viewport_size.y - slot_size.y) / 2
		)

func ensure_player_nodes():
	var bottom_container = $GameContainer.get_node_or_null("BottomPlayerContainer")
	var top_container = $GameContainer.get_node_or_null("TopPlayerContainer")
	
	if not bottom_container:
		push_error("Error: Bottom container not found")
		return
		
	if not top_container:
		push_error("Error: Top container not found")
		return
	
	var viewport_size = get_viewport().size
	var container_width = 1000
	var container_height = 250
	
	bottom_container.size = Vector2(container_width, container_height)
	bottom_container.custom_minimum_size = Vector2(container_width, container_height)
	bottom_container.position = Vector2(
		(viewport_size.x - container_width) / 2,
		viewport_size.y - container_height - 50
	)
	bottom_container.z_index = 2
	
	top_container.size = Vector2(container_width, container_height)
	top_container.custom_minimum_size = Vector2(container_width, container_height)
	top_container.position = Vector2(
		(viewport_size.x - container_width) / 2,
		50
	)
	top_container.z_index = 2
	
	if center_card_slot:
		center_card_slot.z_index = 3
	
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
	
	update_center_card_slot_position()
	
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
	
	var player_node = $GameContainer/BottomPlayerContainer.get_node_or_null("Player%d" % player_index)
	if is_instance_valid(player_node):
		var hand_container = player_node.get_node("HandContainer")
		if hand_container:
			for card in hand_container.get_children():
				card.disabled = true
	
	message_label.text = "Sending initial card selection..."
	http.request(url, headers, HTTPClient.METHOD_POST, body)

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
	
	var timeout_timer = Timer.new()
	timeout_timer.name = "StateRequestTimer"
	add_child(timeout_timer)
	timeout_timer.wait_time = 10.0
	timeout_timer.one_shot = true
	timeout_timer.timeout.connect(func():
		if is_request_in_progress and last_request_type == "state":
			push_error("Error: State fetch request timed out")
			is_request_in_progress = false
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
	var timeout_timer = get_node_or_null("StateRequestTimer")
	if timeout_timer:
		timeout_timer.queue_free()
	
	if http.request_completed.is_connected(_on_state_request_completed):
		http.request_completed.disconnect(_on_state_request_completed)
	
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
		return
		
	if json.has("error"):
		return

	if is_showing_drawn_card:
		return
		
	if json.has("queens_called_by") and int(json.queens_called_by) != player_index:
		var player0_score = int(json.player0_score)
		var player1_score = int(json.player1_score)
		
		var winner_text = ""
		if player0_score < player1_score:
			winner_text = "Player 0 wins with score " + str(player0_score) + "! (Player 1 had " + str(player1_score) + ")"
		elif player1_score < player0_score:
			winner_text = "Player 1 wins with score " + str(player1_score) + "! (Player 0 had " + str(player0_score) + ")"
		else:
			winner_text = "It's a tie! Both players have score " + str(player0_score)
		
		game_over_label.text = winner_text
		message_label.text = ""
		
		var player0_node = $GameContainer/BottomPlayerContainer.get_node_or_null("Player0")
		var player1_node = $GameContainer/TopPlayerContainer.get_node_or_null("Player1")
		
		if player0_node:
			var hand_container = player0_node.get_node("HandContainer")
			if hand_container:
				for card in hand_container.get_children():
					card.disabled = true
					card.flip_card(true)
		
		if player1_node:
			var hand_container = player1_node.get_node("HandContainer")
			if hand_container:
				for card in hand_container.get_children():
					card.disabled = true
					card.flip_card(true)
		
		queens_button.visible = false
		show_center_card({})
		return

	if json.has("game_started"):
		var old_game_started = game_started
		game_started = json.game_started
		if old_game_started != game_started:
			if game_started:
				queens_button.visible = true
				message_label.text = "Game started!"
				received_first_turn_card = false

	if json.has("initial_selection_mode"):
		var old_mode = initial_selection_mode
		initial_selection_mode = json.initial_selection_mode
		if old_mode != initial_selection_mode:
			if initial_selection_mode:
				message_label.text = "Select your initial two cards"
				_initial_selected_cards.clear()
				poll_timer.wait_time = 1.0
			else:
				poll_timer.wait_time = 2.0
				if json.has("first_turn_card") and json.first_turn_card != null:
					received_first_turn_card = true

	if json.has("current_turn_index"):
		var old_turn_index = current_turn_index
		current_turn_index = int(json.current_turn_index)
		
		if old_turn_index != current_turn_index:
			if not initial_selection_mode and game_started:
				if current_turn_index == player_index:
					if json.has("next_player_card") and json.next_player_card != null:
						show_temporary_card(json.next_player_card)
					else:
						start_turn_sequence()
				else:
					message_label.text = "Opponent's turn!"
				update_card_states()

	if json.has("total_players"):
		total_players = json.total_players
	
	if json.has("players") and not is_showing_drawn_card:
		for p_data in json.players:
			if not p_data.has("index"):
				continue
				
			var p_index = int(p_data.index)
			if p_index < 0 or p_index >= MAX_PLAYERS:
				continue
			
			var container_name = "BottomPlayerContainer" if p_index == player_index else "TopPlayerContainer"
			var container = $GameContainer.get_node_or_null(container_name)
			if not container:
				continue
			
			var player_node = container.get_node_or_null("Player%d" % p_index)
			if not is_instance_valid(player_node):
				ensure_player_nodes()
				await get_tree().process_frame
				player_node = container.get_node_or_null("Player%d" % p_index)
				
				if not is_instance_valid(player_node):
					continue
			
			if p_data.has("hand"):
				var hand_data = p_data.hand
				if typeof(hand_data) == TYPE_ARRAY:
					var processed_hand = []
					for card in hand_data:
						if typeof(card) == TYPE_DICTIONARY and card.has("card_id"):
							var card_data = {
								"card_id": card.card_id,
								"is_face_up": card.temporary_reveal if card.has("temporary_reveal") else false,
								"rank": card.rank if card.has("rank") else "0",
								"suit": card.suit if card.has("suit") else "Unknown",
								"value": float(card.rank) if card.has("rank") else 0.0,
								"temporary_reveal": card.temporary_reveal if card.has("temporary_reveal") else false
							}
							processed_hand.append(card_data)
					
					if processed_hand.size() > 0:
						player_node.update_hand_display(processed_hand, p_index == player_index, initial_selection_mode)
	
	if json.has("center_card") and not initial_selection_mode:
			show_center_card(json.center_card)
		
	match last_request_type:
		"king_reveal":
			if json.has("status") and json.status == "ok":
				king_reveal_mode = false
				message_label.text = "Card revealed! Waiting for opponent's turn."
				current_turn_index = int(json.current_turn_index)
				update_card_states()
				
		"play_card":
			if json.has("status") and json.status == "ok":
				if json.has("king_reveal_mode") and json.king_reveal_mode:
					king_reveal_mode = true
					king_player_index = player_index
					message_label.text = "King played! Choose one of your cards to reveal."
					enable_king_reveal_mode()
				elif json.has("next_player_card"):
					if current_turn_index == player_index:
						show_temporary_card(json.next_player_card)
					update_card_states()

func update_card_states():
	for i in range(2):
		var container_name = "BottomPlayerContainer" if i == player_index else "TopPlayerContainer"
		var player_node = $GameContainer.get_node_or_null("%s/Player%d" % [container_name, i])
		if is_instance_valid(player_node):
			var hand_container = player_node.get_node("HandContainer")
			if hand_container:
				for card in hand_container.get_children():
					if i == player_index:
						card.disabled = (current_turn_index != player_index) or initial_selection_mode
						card.modulate = Color(1, 1, 1)
					else:
						card.disabled = true
						card.modulate = Color(1, 1, 1)

func display_container_error(container: Node, error_message: String):
	if not container:
		return
		
	var error_label = Label.new()
	error_label.text = "Error: " + error_message
	error_label.modulate = Color(1, 0, 0)
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(error_label)
	
	var error_bg = ColorRect.new()
	error_bg.custom_minimum_size = Vector2(200, 50)
	error_bg.color = Color(0.8, 0, 0, 0.3)
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
		
	is_request_in_progress = true
	last_request_type = "king_reveal"
	var url = BASE_URL + "king_reveal"
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({
		"room_id": room_id,
		"player_index": player_index,
		"revealed_card_id": card_node.card_data.card_id
	})
	http.request(url, headers, HTTPClient.METHOD_POST, body)
	
	card_node.flip_card(true)
	card_node.modulate = Color(0.7, 1.0, 0.7)
	
	disable_all_cards()
	
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
		
		king_reveal_mode = false
		message_label.text = "Card revealed! Waiting for opponent's turn."
		timer.queue_free()
	)
	timer.start()

func _on_card_played(card_data):
	var player_node = $GameContainer/BottomPlayerContainer.get_node_or_null("Player%d" % player_index)
	if not is_instance_valid(player_node):
		return
		
	if current_turn_index != player_index:
		return
	
	if initial_selection_mode:
		return
	
	send_play_card(card_data.card_id)
	
	if card_data.rank == "13":  # King
		king_reveal_mode = true
		king_player_index = player_index
		message_label.text = "King played! Choose one of your cards to reveal."
		
		show_center_card(card_data)
		
		var hand_container = player_node.get_node("HandContainer")
		if hand_container:
			for card in hand_container.get_children():
				if card.card_data.card_id == card_data.card_id:
					card.disabled = true
					card.modulate = Color(0.7, 0.7, 0.7)
					card.mouse_filter = Control.MOUSE_FILTER_IGNORE
					break
		enable_king_reveal_mode()
		
	elif card_data.rank == "12":  # Queen
		message_label.text = "Queen played! Card will be added to opponent's hand."
		
		# First show the Queen in the center
		show_center_card(card_data.duplicate())
		
		# Calculate opponent index and get their node
		var opponent_index = (player_index + 1) % 2
		var opponent_container_name = "TopPlayerContainer" if opponent_index == 1 else "BottomPlayerContainer"
		
		var opponent_node = $GameContainer.get_node_or_null("%s/Player%d" % [opponent_container_name, opponent_index])
		if opponent_node:
			opponent_node.add_card(card_data.duplicate())
		
		# Remove the Queen from the current player's hand
		var hand_container = player_node.get_node("HandContainer")
		if hand_container:
			for card in hand_container.get_children():
				if card.card_data.card_id == card_data.card_id:
					card.queue_free()
					break
	else:
		show_center_card(card_data)
		message_label.text = "Card played: " + card_data.rank + " of " + card_data.suit
		
		var hand_container = player_node.get_node("HandContainer")
		if hand_container:
			for card in hand_container.get_children():
				if card.card_data.card_id == card_data.card_id:
					card.queue_free()
					break

func send_initial_cards_selection(selected_cards_data: Array):
	if is_request_in_progress:
		return

	if room_id.is_empty() or player_id.is_empty():
		return

	if selected_cards_data.size() != 2:
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

	var player_node = $GameContainer.get_node_or_null("BottomPlayerContainer/Player%d" % player_index)
	if not is_instance_valid(player_node):
		return
		
	var hand_container = player_node.get_node("HandContainer")
	if not hand_container:
		return
		
	var card_data = null
	for card in hand_container.get_children():
		if card.card_data.card_id == card_id:
			card_data = card.card_data
			break
			
	if not card_data:
		return

	is_request_in_progress = true
	last_request_type = "play_card"
	var url = BASE_URL + "play_card"
	var headers = ["Content-Type: application/json"]

	var body = JSON.stringify({
		"room_id": room_id,
		"player_index": player_index,
		"card": card_data
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
		preview_data["is_face_up"] = false
		
		preview_card.set_data(preview_data)
		preview_card.flip_card(false)
		preview_card.modulate.a = 0.5
		preview_card.position = Vector2.ZERO
		preview_card.z_index = 4

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

func _on_card_pressed(card_node):
	if initial_selection_mode:
		var player_node = $GameContainer/BottomPlayerContainer.get_node_or_null("Player%d" % player_index)
		if not is_instance_valid(player_node) or card_node.holding_player != player_node:
			return

		var card_data = card_node.card_data
		if card_data.has("was_initially_seen") and card_data.was_initially_seen:
			return

		if not card_data.has("is_locked"):
			card_data["is_locked"] = false

		if card_data.is_locked:
			return

		var already_selected = false
		for selected_card in _initial_selected_cards:
			if selected_card.card_id == card_data.card_id:
				already_selected = true
				break

		if already_selected:
			return

		if _initial_selected_cards.size() >= 2:
			message_label.text = "You have already selected your two cards!"
			return

		card_node.temporary_reveal()
		_initial_selected_cards.append(card_data)
		
		if _initial_selected_cards.size() < 2:
			message_label.text = "Select %d more card(s)" % (2 - _initial_selected_cards.size())
		else:
			if not is_request_in_progress:
				send_initial_cards_selection(_initial_selected_cards)
				message_label.text = "Initial cards selected! Wait for other players."
				for card in player_node.get_node("HandContainer").get_children():
					card.disabled = true
	else:
		card_node.start_drag()

func start_turn_sequence():
	if initial_selection_mode:
		message_label.text = "Select your initial two cards"
		return
		
	if received_first_turn_card:
		received_first_turn_card = false
		message_label.text = "Your turn! Play a card."
		update_card_states()
		return
	
	message_label.text = "Your turn! Play a card."
	update_card_states()

func handle_drawn_card(card_data: Dictionary):
	if not card_data.has("rank") or not card_data.has("suit"):
		return
		
	var player_node = $GameContainer.get_node_or_null("BottomPlayerContainer/Player%d" % player_index)
	if not is_instance_valid(player_node):
		return
		
	var hand_container = player_node.get_node("HandContainer")
	if not hand_container:
		return
	
	var preview_card = preload("res://scenes/card.tscn").instantiate()
	if not preview_card:
		return
		
	preview_card.holding_player = player_node
	preview_card.set_data(card_data)
	preview_card.flip_card(true)
	preview_card.disabled = true
	preview_card.name = "DrawnCardPreview"
	
	var card_width = 100
	var card_height = 150
	var card_spacing = 20
	
	var final_x = hand_container.position.x + hand_container.size.x - card_width - 20
	var final_y = hand_container.position.y + (hand_container.size.y - card_height) / 2
	
	var viewport_size = get_viewport().size
	preview_card.size = Vector2(card_width, card_height)
	preview_card.position = Vector2(
		(viewport_size.x - card_width) / 2,
		(viewport_size.y - card_height) / 2 - 100
	)
	preview_card.z_index = 101
	
	add_child(preview_card)
	is_showing_drawn_card = true
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	
	tween.tween_property(preview_card, "position:y", preview_card.position.y - 30, 0.3)
	tween.tween_interval(0.5)
	
	tween.tween_method(
		func(t: float):
			var start = preview_card.position
			var end = Vector2(final_x, final_y)
			var arc_pos = start.lerp(end, t)
			arc_pos.y -= sin(t * PI) * 100
			preview_card.position = arc_pos,
		0.0, 1.0, 0.8
	)
	
	tween.tween_callback(func():
		if is_instance_valid(preview_card):
			preview_card.queue_free()
		is_showing_drawn_card = false
		message_label.text = "Your turn! Play a card."
		
		var new_card = preload("res://scenes/card.tscn").instantiate()
		new_card.holding_player = player_node
		new_card.set_data(card_data)
		new_card.size = Vector2(card_width, card_height)
		new_card.position = Vector2(final_x, final_y)
		new_card.flip_card(false)
		hand_container.add_child(new_card)
		
		new_card.scale = Vector2(0.8, 0.8)
		var appear_tween = create_tween()
		appear_tween.tween_property(new_card, "scale", Vector2(1.1, 1.1), 0.2)
		appear_tween.tween_property(new_card, "scale", Vector2(1.0, 1.0), 0.1)
	)

func apply_custom_font(node: Node, font: Font):
	if node is Label or node is Button:
		node.add_theme_font_override("font", font)
	
	for child in node.get_children():
		apply_custom_font(child, font)

func _update_card_animations():
	animation_time += 0.016
	
	for container_name in ["BottomPlayerContainer", "TopPlayerContainer"]:
		var container = $GameContainer.get_node_or_null(container_name)
		if container:
			for player in container.get_children():
				var hand_container = player.get_node_or_null("HandContainer")
				if hand_container:
					var card_index = 0
					for card in hand_container.get_children():
						if card is TextureButton and not card.is_dragging:
							var phase = animation_time * ANIMATION_SPEED + card_index * 0.5
							var offset = sin(phase) * ANIMATION_AMPLITUDE
							
							if not card.has_meta("original_y"):
								card.set_meta("original_y", card.position.y)
							
							var original_y = card.get_meta("original_y")
							card.position.y = original_y + offset
						card_index += 1

func show_temporary_card(card_data: Dictionary):
	var player_node = $GameContainer.get_node_or_null("BottomPlayerContainer/Player%d" % player_index)
	if not is_instance_valid(player_node):
		return
		
	var hand_container = player_node.get_node("HandContainer")
	if not hand_container:
		return
	
	var preview_card = preload("res://scenes/card.tscn").instantiate()
	if not preview_card:
		return
		
	preview_card.holding_player = player_node
	preview_card.set_data(card_data)
	preview_card.flip_card(true)
	preview_card.disabled = true
	preview_card.name = "TemporaryRevealCard"
	
	var card_width = 100
	var card_height = 150
	
	var viewport_size = get_viewport().size
	preview_card.size = Vector2(card_width, card_height)
	preview_card.position = Vector2(
		(viewport_size.x - card_width) / 2,
		(viewport_size.y - card_height) / 2
	)
	preview_card.z_index = 101
	preview_card.modulate = Color(1, 1, 0.7)
	
	add_child(preview_card)
	message_label.text = "You drew this card!"
	
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 3.0
	timer.one_shot = true
	timer.timeout.connect(func():
		if is_instance_valid(preview_card):
			preview_card.queue_free()
		timer.queue_free()
		message_label.text = "Your turn! Play a card."
		update_card_states()
	)
	timer.start()
	
	var new_card = preload("res://scenes/card.tscn").instantiate()
	new_card.holding_player = player_node
	new_card.set_data(card_data)
	new_card.size = Vector2(card_width, card_height)
	new_card.position = Vector2(
		hand_container.position.x + hand_container.size.x - card_width - 20,
		(hand_container.size.y - card_height) / 2
	)
	new_card.flip_card(false)
	hand_container.add_child(new_card)

func update_turn_indicator():
	if not turn_indicator:
		return
		
	if current_turn_index >= 0:
		turn_indicator.text = "Player " + str(current_turn_index)
	else:
		turn_indicator.text = ""

func calculate_player_score(player_node) -> int:
	if not is_instance_valid(player_node):
		return 0
		
	var hand_container = player_node.get_node("HandContainer")
	if not hand_container:
		return 0
		
	var total_score = 0
	for card in hand_container.get_children():
		if card.has_method("get_card_id"):  # Make sure it's a card node
			var card_data = card.card_data
			if card_data.has("rank"):
				match card_data.rank:
					"12":  # Queen
						total_score += 0
					"11", "13":  # Jack or King
						total_score += 10
					"1":  # Ace
						total_score += 1
					_:  # All other cards
						total_score += int(card_data.rank)
	return total_score

func _on_room_update_timer_timeout():
	refresh_room_list()
