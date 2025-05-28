extends Node2D

@onready var http := $HTTPRequest
@onready var message_label := $MessageLabel
@onready var start_button := $StartGameButton
@onready var queens_button := $queens_button

var player_id := ""
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
	var stored_id = ProjectSettings.get_setting("application/config/player_id", "")
	if typeof(stored_id) != TYPE_STRING or stored_id == "":
		stored_id = str(randi())
	player_id = stored_id
	join_game()
	add_child(poll_timer)
	poll_timer.wait_time = 1.0
	poll_timer.timeout.connect(fetch_state)
	poll_timer.start()
	http.request_completed.connect(_on_request_completed)
	start_button.pressed.connect(_on_start_game)
	if queens_button:
		queens_button.pressed.connect(_on_queens_button_pressed)
		
func join_game():
	last_request_type = "join"
	var url = "http://localhost:3000/join"
	var headers = ["Content-Type: application/json"]
	var body_dict = { "room_id": "room1" }
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
	var body = JSON.stringify({"player_index": player_index})
	http.request(url, headers, HTTPClient.METHOD_POST, body)
	
func _on_request_completed(_result, _code, _headers, body):
	var json_text: String = body.get_string_from_utf8()
	var json = JSON.parse_string(json_text)
	
	if typeof(json) != TYPE_DICTIONARY:
		print("Invalid JSON from server:", json_text)
		return
	if json.has("status") and json["status"] == "error":
		message_label.text = json.get("message", "Unknown error")
		return
		
	if last_request_type == "join":
		player_id = json.get("player_id", player_id)
		player_index = int(json.get("player_index", -1))
		total_players = json.get("total_players", 0)
		if json.has("hand"):
			hand = json["hand"]
			update_player_hand(player_index, hand)
		has_joined = true
		ensure_player_nodes()
		message_label.text = "Joined as Player %d" % (player_index + 1)
		if hand.size() == 0 and json.has("hand"):
			hand = json["hand"]
			update_player_hand(player_index, hand)
		
	if json.has("center_card"):
		if center_card != json["center_card"] or $CenterCardSlot.get_child_count() == 0:
			center_card = json["center_card"]
			if center_card != null:
				show_center_card(center_card)
				print("Center card updated to: ", center_card)
			else:
				for child in $CenterCardSlot.get_children():
					child.queue_free()
				print("Center card cleared")
				
			
	if json.has("current_turn_index"):
		var new_turn_index = int(json["current_turn_index"])
		if current_turn_index != new_turn_index:
			current_turn_index = new_turn_index
			message_label.text = "Your turn!" if player_index == current_turn_index else "Waiting for player %d" % (current_turn_index + 1)
			print("Turn changed to player: ", current_turn_index)
		else:
			message_label.text = "Your turn!" if player_index == current_turn_index else "Waiting for player %d" % (current_turn_index + 1)
		
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
			
			
	if json.has("players"):
		for player_data in json["players"]:
			var idx = player_data["index"]
			if idx == player_index:
				if json.has("hand"):
					hand = json["hand"]
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
						dummy_card.set_data({"suit": "Hearts", "rank": "1", "value": 0})
						dummy_card.disabled = true
						dummy_card.flip_card(false)
						player_node.add_card(dummy_card, false)
					
	if json.has("hand"):
		hand = json["hand"]
		update_player_hand(player_index, hand)
		
	if json.has("player_hand"):
		hand = json["player_hand"]
		update_player_hand(player_index, hand)
		
		
	if json.has("message"):
		message_label.text = json["message"]
		
	fetching = false
func update_player_hand(for_player_index: int, hand_data: Array):
	var player_node = get_node_or_null("Player%d" % for_player_index)
	if not player_node:
		return
	player_node.clear_hand()
	for card_data in hand_data:
		add_card_to_hand(card_data, for_player_index)
	player_node.arrange_hand()
	print("Updated hand for player ", for_player_index, " with ", hand_data.size(), " cards")
	
func _on_card_pressed(card_data: Dictionary):
	if player_index != current_turn_index:
		message_label.text = "not ur turn "
		return
	if reaction_mode and card_data["value"] != reaction_value:
		
		message_label.text = "Invalid card for reaction!"
		return
	if jack_swap_mode:
		if jack_swap_selection["from"] == null:
			
			if card_data["owner_index"] != player_index:
				message_label.text = "First card must be yours!"
				return
			jack_swap_selection["from"] = card_data
			message_label.text = "Selected first card for swap."
			
		elif jack_swap_selection["to"] == null:
			if card_data["owner_index"] == player_index:
				message_label.text = "Second card must be opponent's!"
				return
			jack_swap_selection["to"] = card_data
			
			last_request_type = "jack_swap"
			var url = "http://localhost:3000/jack_swap"
			
			var headers = ["Content-Type: application/json"]
			var body = JSON.stringify({
				"player_index": player_index,
				"from_card_id": jack_swap_selection["from"]["card_id"],
				
				"to_card_id": jack_swap_selection["to"]["card_id"]
			})
			http.request(url, headers, HTTPClient.METHOD_POST, body)
			jack_swap_mode = false
			jack_swap_selection = {"from": null, "to": null}
		return
	play_card(card_data)
			
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
	if not card_data or not card_data.has("suit") or not card_data.has("rank"):
		return
	for child in $CenterCardSlot.get_children():
		child.queue_free()
	var card = preload("res://scenes/Card.tscn").instantiate()
	card.set_data(card_data)
	card.disabled = true
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.is_center_card = true
	$CenterCardSlot.add_child(card)
	print("Center card updated to: ", card_data)
	
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
	if fetching: 
		return
	fetching = true
	last_request_type = "state"
	var url = "http://localhost:3000/state"
	http.request(url)
