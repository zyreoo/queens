extends Node2D

@onready var http := $HTTPRequest
@onready var message_label := $MessageLabel
@onready var start_button := $StartGameButton
@onready var queens_button := $queens_button
@onready var create_room_button := $RoomManagement/CreateRoomButton
@onready var room_list := $RoomManagement/RoomList
@onready var center_card_slot := $CenterCardSlot

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
	start_button.pressed.connect(_on_start_game)
	if queens_button:
		queens_button.pressed.connect(_on_queens_button_pressed)
	if create_room_button:
		create_room_button.pressed.connect(_on_create_room)
	
	refresh_room_list()

func _on_create_room():
	last_request_type = "create_room"
	var url = "http://localhost:3000/create_room"
	var headers = ["Content-Type: application/json"]
	http.request(url, headers, HTTPClient.METHOD_POST)

func refresh_room_list():
	last_request_type = "list_rooms"
	var url = "http://localhost:3000/rooms"
	http.request(url, [], HTTPClient.METHOD_GET)

func join_room(selected_room_id: String):
	room_id = selected_room_id
	join_game()

func join_game():
	if room_id.is_empty():
		message_label.text = "Please select a room first"
		return
		
	last_request_type = "join"
	var url = "http://localhost:3000/join"
	var headers = ["Content-Type: application/json"]
	var body_dict = { "room_id": room_id }
	if player_id != "":
		body_dict["player_id"] = player_id
	var body = JSON.stringify(body_dict)
	http.request(url, headers, HTTPClient.METHOD_POST, body)
	
func _on_start_game():
	message_label.text = "Game start pressed (no-op unless handled on server)"
	
func _on_queens_button_pressed():
	if player_index != current_turn_index:
		message_label.text = "Not your turn!"
		return
	last_request_type = "call_queens"
	var url = "http://localhost:3000/call_queens"
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({
		"room_id": room_id,
		"player_index": player_index
	})
	http.request(url, headers, HTTPClient.METHOD_POST, body)
	
func _on_request_completed(_result, _code, _headers, body):
	var json_text: String = body.get_string_from_utf8()
	var json = JSON.parse_string(json_text)
	
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
			
		"play_card", "state", "jack_swap", "call_queens":
			if json.has("center_card"):
				center_card = json["center_card"]
				show_center_card(center_card)
				
			if json.has("current_turn_index"):
				current_turn_index = int(json["current_turn_index"])
				message_label.text = "Your turn!" if player_index == current_turn_index else "Waiting for player %d" % (current_turn_index + 1)
				
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
					
			if json.has("reaction_mode"):
				reaction_mode = json["reaction_mode"]
				reaction_value = json.get("reaction_value", null)
				
			if json.has("jack_swap_mode") and json["jack_swap_mode"]:
				jack_swap_mode = true
				message_label.text = "jack played! Select a card to swap."
				
			if json.has("queens_triggered"):
				queens_triggered = json["queens_triggered"]
				final_round_active = json.get("final_round_active", false)
				
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
				message_label.text = json["message"]
		
	fetching = false

func update_player_hand(for_player_index: int, hand_data: Array):
	var player_node = get_node_or_null("Player%d" % for_player_index)
	if not player_node:
		print("Player node not found for index: ", for_player_index)
		return

	var is_initial_deal = (for_player_index == player_index and hand_data.size() == 4 and player_node.hand.size() == 0)

	player_node.clear_hand()

	for i in range(hand_data.size()):
		var card_data = hand_data[i]
		var card = preload("res://scenes/Card.tscn").instantiate()
		card.set_data(card_data)

		var face_up = false
		if for_player_index == player_index:
			card.disabled = false
			if is_initial_deal:
				face_up = (i < 2)
			else:
				face_up = true
				
			if card.pressed.is_connected(func(): _on_card_pressed(card_data)):
				card.pressed.disconnect(func(): _on_card_pressed(card_data))
			var connection_result = card.pressed.connect(func(): _on_card_pressed(card_data))
			if connection_result != OK:
				print("Failed to connect pressed signal for card: ", card_data)
		else:
			card.disabled = true
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE
			face_up = false
		card.flip_card(face_up)
		player_node.add_card(card, for_player_index == player_index)
	player_node.arrange_hand()
	print("Updated hand for player ", for_player_index, " with ", hand_data.size(), " cards.")

func _on_card_pressed(card_data: Dictionary):
	print("Card pressed: ", card_data)
	if player_index != current_turn_index:
		print("Not your turn! Current turn: ", current_turn_index)
		message_label.text = "Not your turn!"
		return
		
	last_request_type = "play_card"
	var url = "http://localhost:3000/play_card"
	var headers = ["Content-Type: application/json"]
	var payload = {
		"room_id": room_id,
		"player_index": player_index,
		"card": card_data
	}
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
		$CenterCardSlot.add_child(card)
		print("Center card displayed: ", card_data)
	else:
		print("No valid center card data")
		
func play_card(card_data: Dictionary):
	if player_index != current_turn_index and not reaction_mode:
		message_label.text = " not ur turn"
		return
	last_request_type = "play_card"
	var url = "http://localhost:3000/play_card"
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({"player_index": player_index, "card": card_data})
	print("Playing card: ", card_data)
	http.request(url, headers, HTTPClient.METHOD_POST, body)
	fetch_state()
	
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
	var url = "http://localhost:3000/state?room_id=" + room_id
	http.request(url, [], HTTPClient.METHOD_GET)

func _on_room_selected(idx):
	if room_list:
		var label = room_list.get_item_text(idx)
		var parts = label.split(" ")
		if parts.size() > 1:
			var selected_room_id = parts[1]
			join_room(selected_room_id)
