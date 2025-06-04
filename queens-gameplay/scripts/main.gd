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
	var stored_id = ProjectSettings.get_setting("application/config/player_id", "")
	if typeof(stored_id) != TYPE_STRING or stored_id == "":
		stored_id = str(randi())
	player_id = stored_id
	
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
	
	$MenuContainer.visible = false
	$GameContainer.visible = true
	
	if room_name_label:
		room_name_label.text = "Room: " + room_id

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
		return

	match last_request_type:
		"list_rooms":
			update_room_list(json.rooms)
		"create_room":
			if json.has("room_id"):
				room_id = json.room_id
				if json.has("player_id"):
					player_id = json.player_id
				player_index = int(json.player_index)
				total_players = json.total_players
				current_turn_index = int(json.current_turn_index)
				initial_selection_mode = json.initial_selection_mode
				
				ensure_player_nodes()
				
				if json.has("hand"):
					var player_node = $GameContainer.get_node_or_null("BottomPlayerContainer/Player%d" % player_index)
					if is_instance_valid(player_node):
						player_node.update_hand_display(json.hand, true, initial_selection_mode)
				
				show_center_card(json.center_card)
				$MenuContainer.hide()
				$GameContainer.show()
				room_name_label.text = "Room: " + room_id.left(5) + "..."
				poll_timer.start()
				has_joined = true
		"join":
			if json.has("player_id") and json.has("player_index") and json.has("room_id"):
				player_id = json.player_id
				player_index = int(json.player_index)
				room_id = json.room_id
				total_players = json.total_players if json.has("total_players") else 0
				current_turn_index = int(json.current_turn_index) if json.has("current_turn_index") else -1
				initial_selection_mode = json.initial_selection_mode if json.has("initial_selection_mode") else false
				
				ensure_player_nodes()
				
				if json.has("hand"):
					var local_node = $GameContainer.get_node_or_null("BottomPlayerContainer/Player%d" % player_index)
					if is_instance_valid(local_node):
						local_node.update_hand_display(json.hand, true, initial_selection_mode)
				
				var opponent_index = (player_index + 1) % 2
				var opponent_node = $GameContainer.get_node_or_null("TopPlayerContainer/Player%d" % opponent_index)
				if is_instance_valid(opponent_node):
					opponent_node.update_hand_display([], false, initial_selection_mode)
				
				if json.has("center_card"):
					show_center_card(json.center_card)
				
				$MenuContainer.hide()
				$GameContainer.show()
				room_name_label.text = "Room: " + room_id.left(5) + "..."
				
				poll_timer.start()
				has_joined = true
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
				
				if json.has("players"):
					for p_data in json.players:
						if not p_data.has("index") or not p_data.has("hand") or typeof(p_data.hand) != TYPE_ARRAY:
							continue
							
						var p_index = int(p_data.index)
						var container_name = "BottomPlayerContainer" if p_index == player_index else "TopPlayerContainer"
						var player_node = $GameContainer.get_node_or_null("%s/Player%d" % [container_name, p_index])
						if is_instance_valid(player_node):
							player_node.update_hand_display(p_data.hand, p_index == player_index, initial_selection_mode)
						else:
							ensure_player_nodes()
							player_node = $GameContainer.get_node_or_null("%s/Player%d" % [container_name, p_index])
							if is_instance_valid(player_node):
								player_node.update_hand_display(p_data.hand, p_index == player_index, initial_selection_mode)
				if json.has("center_card"):
					show_center_card(json.center_card)
				if json.has("current_turn_index"):
					current_turn_index = int(json.current_turn_index)
				if json.has("message"):
					message_label.text = json.message
		"play_card":
			if json.has("status") and json.status == "ok":
				if json.has("king_reveal_mode") and json.king_reveal_mode:
					king_reveal_mode = true
					king_player_index = json.king_player_index
					message_label.text = "King played! Choose one of your cards to reveal."
					enable_king_reveal_mode()
				elif json.has("jack_swap_mode") and json.jack_swap_mode:
					jack_swap_mode = true
					jack_player_index = json.jack_player_index
					message_label.text = "Jack played! Select a card to swap."
					enable_jack_swap_mode()
				
				if json.has("players"):
					for p_data in json.players:
						if p_data.has("player_index") and p_data.has("hand"):
							var p_index = int(p_data.player_index)
							var container_name = "BottomPlayerContainer" if p_index == player_index else "TopPlayerContainer"
							var player_node = $GameContainer.get_node_or_null("%s/Player%d" % [container_name, p_index])
							if is_instance_valid(player_node):
								player_node.update_hand_display(p_data.hand, p_index == player_index, initial_selection_mode)
								
								# If this is the next player and they got a new card, show it briefly
								if p_index == (current_turn_index + 1) % total_players and p_data.hand.size() > 0:
									var last_card = p_data.hand[-1]
									if p_index == player_index:
										message_label.text = "Your turn! New card: " + last_card.suit + " " + str(last_card.rank)
									else:
										message_label.text = "Opponent received a new card. Their turn!"
				
				if json.has("center_card"):
					show_center_card(json.center_card)
				if json.has("current_turn_index"):
					var old_turn_index = current_turn_index
					current_turn_index = int(json.current_turn_index)
				if json.has("message"):
					message_label.text = json.message
		"state":
			if json.has("current_turn_index"):
				var old_turn_index = current_turn_index
				current_turn_index = int(json.current_turn_index)
				
				if old_turn_index != current_turn_index:
					if current_turn_index == player_index:
						message_label.text = "Your turn!"
					else:
						message_label.text = "Opponent's turn!"
			
			if json.has("center_card"):
				show_center_card(json.center_card)
			
			if json.has("players"):
				for p_data in json.players:
					if not p_data.has("index"):
						continue
					if not p_data.has("hand"):
						continue
					
					var p_index = int(p_data.index)
					var container_name = "BottomPlayerContainer" if p_index == player_index else "TopPlayerContainer"
					var player_node = $GameContainer.get_node_or_null("%s/Player%d" % [container_name, p_index])
					
					if is_instance_valid(player_node):
						if p_index == player_index and typeof(p_data.hand) == TYPE_ARRAY:
							var old_hand_size = player_node.get_node("HandContainer").get_child_count()
							player_node.update_hand_display(p_data.hand, true, initial_selection_mode)
							
							# If we got a new card and it's our turn, show it
							if p_data.hand.size() > old_hand_size and current_turn_index == player_index:
								var last_card = p_data.hand[-1]
								message_label.text = "Your turn! New card: " + last_card.suit + " " + str(last_card.rank)
					else:
						ensure_player_nodes()
						player_node = $GameContainer.get_node_or_null("%s/Player%d" % [container_name, p_index])
						if is_instance_valid(player_node):
							if p_index == player_index and typeof(p_data.hand) == TYPE_ARRAY:
								player_node.update_hand_display(p_data.hand, true, initial_selection_mode)

		"jack_swap":
			if json.has("status") and json.status == "ok":
				jack_swap_mode = false
				if json.has("player_hand"):
					var player_node = $GameContainer.get_node_or_null("BottomPlayerContainer/Player%d" % player_index)
					if is_instance_valid(player_node):
						player_node.update_hand_display(json.player_hand, true, false)
				
				if json.has("center_card"):
					show_center_card(json.center_card)
				if json.has("current_turn_index"):
					current_turn_index = int(json.current_turn_index)
				message_label.text = "Cards swapped successfully!"
		
		"king_reveal":
			if json.has("status") and json.status == "ok":
				king_reveal_mode = false
				if json.has("center_card"):
					show_center_card(json.center_card)
				if json.has("current_turn_index"):
					current_turn_index = int(json.current_turn_index)
				message_label.text = "Card revealed for 3 seconds!"
				
				disable_all_cards()

	last_request_type = ""

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
	
	if bottom_container:
		for child in bottom_container.get_children():
			child.queue_free()
	else:
		return
		
	if top_container:
		for child in top_container.get_children():
			child.queue_free()
	else:
		return
	
	for i in range(2):
		var container_name = "BottomPlayerContainer" if i == player_index else "TopPlayerContainer"
		
		var container = $GameContainer.get_node_or_null(container_name)
		if not container:
			return
			
		var player_node = preload("res://scenes/Player.tscn").instantiate()
		player_node.name = "Player%d" % i
		
		container.add_child(player_node)
		player_node.setup_player(i, player_id if i == player_index else "")

func fetch_state():
	if not has_joined or room_id.is_empty() or player_id.is_empty():
		return
		
	poll_timer.stop()
	
	if is_request_in_progress:
		poll_timer.start()
		return
		
	is_request_in_progress = true
	last_request_type = "state"
	var url = BASE_URL + "state?room_id=" + room_id + "&player_id=" + player_id
	var headers = [
		"Accept: application/json",
		"Access-Control-Allow-Origin: *"
	]
	var error = http.request(url, headers, HTTPClient.METHOD_GET)
	if error != OK:
		poll_timer.start()

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
	if room_list:
		room_list.clear()
		for room in rooms:
			room_id = room.get("room_id", "N/A")
			var player_count = room.get("player_count", 0)
			var max_players = room.get("max_players", 2)
			var label = "Room %s (%d/%d players)" % [room_id.left(5) + "...", player_count, max_players]
			room_list.add_item(label)
			room_list.set_item_metadata(room_list.item_count - 1, room_id)

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
		var already_selected = false
		for selected_card in _initial_selected_cards:
			if selected_card.card_id == card_data.card_id:
				already_selected = true
				break

		if already_selected:
			for i in range(_initial_selected_cards.size()):
				if _initial_selected_cards[i].card_id == card_data.card_id:
					_initial_selected_cards.remove_at(i)
					break
			card_node.flip_card(false)
			message_label.text = "Select %d more card(s)" % (2 - _initial_selected_cards.size())
		else:
			_initial_selected_cards.append(card_data)
			card_node.flip_card(true)
			message_label.text = "Select %d more card(s)" % (2 - _initial_selected_cards.size())

			if _initial_selected_cards.size() == 2:
				send_initial_cards_selection(_initial_selected_cards)
				message_label.text = "Initial cards selected! Wait for other players."
				for card in player_node.get_node("HandContainer").get_children():
					card.disabled = true
					if not _initial_selected_cards.has(card.card_data):
						card.modulate = Color(0.5, 0.5, 0.5)
						card.flip_card(false)
	else:
		card_node.start_drag()
