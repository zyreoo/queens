extends Node2D

@onready var http := $HTTPRequest
@onready var message_label := $MessageLabel
@onready var start_button := $StartGameButton

var player_id: = ""
var center_card: Dictionary = {}
var poll_timer := Timer.new()
var current_player_id = null
var fetching := false
var has_joined := false
var player_index := -1
var current_turn_index := -1

func _ready():
	player_id = ProjectSettings.get_setting("application/config/player_id", "")
	if player_id == "":
		join_game()
	add_child(poll_timer)
	poll_timer.wait_time = 1.0
	poll_timer.timeout.connect(fetch_state)
	poll_timer.start()
	http.request_completed.connect(_on_request_completed)
	start_button.pressed.connect(_on_start_game)

func join_game():
	print("Sending join request")
	var url = "http://localhost:3000/join"
	var headers = ["Content-Type: application/json"]
	var body_dict = {
	"room_id": "room1"
	}
	if player_id != "":
		body_dict["player_id"] = player_id
	var body = JSON.stringify(body_dict)
	var err = http.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		printerr("Failed to join:", err)


func _on_start_game():
	message_label.text = "Game start pressed (no-op unless handled on server)"

func _on_request_completed(_result, _code, _headers, body):
	var json = JSON.parse_string(body.get_string_from_utf8())
	if not json:
		print("Invalid JSON from server")
		return
		print("Full server response: ", json)
	if json.has("player_id"):
		player_id = json["player_id"]
		ProjectSettings.set_setting("application/config/player_id", player_id)    
	if json.has("player_index"):
		player_index = int(json["player_index"])
	if json.has("current_turn_index"):
			current_turn_index = int(json["current_turn_index"])
	var player_node = get_node_or_null("Player%d" % player_index)
	if player_node:
		player_node.clear_hand()
	if json.has("hand"):
		for card_data in json["hand"]:
			add_card_to_hand(card_data, player_index)
	if json.has("center_card") and json["center_card"] != null and json["center_card"] is Dictionary:
		show_center_card(json["center_card"])
	else:
		print("No valid center card data received:", json.get("center_card", "N/A"))
		
	has_joined = true
	if player_index == current_turn_index:
		message_label.text = "Your turn!"
	else:
		message_label.text = "Waiting for player %d" % current_turn_index
func _on_card_pressed(card_data: Dictionary):
	if player_index != current_turn_index:
		message_label.text = "not ur turn "
		return
	print("playing card", card_data)
	play_card(card_data)
			
func add_card_to_hand(card_data: Dictionary, for_player_index: int):
	print("Adding card to player", for_player_index, "  local player index:", player_index)
	var card = preload("res://scenes/Card.tscn").instantiate()
	card.set_data(card_data)
	
	
	if for_player_index == player_index:
		card.pressed.connect(func(): _on_card_pressed(card_data))
		card.disabled = false 
	else:
		card.disabled = true
		card.flip_card(false) 
		
	var player_node = get_node_or_null("Player%d" % for_player_index)
	if not player_node:
		print("ERROR: Cannot find player node: Player%d" % for_player_index)
		return
		
	print("Adding card to Player%d node" % for_player_index)
	player_node.add_card(card, for_player_index == player_index)
	card.visible = true 

func clear_hand():
	for child in get_children():
		if child is TextureButton and child != $HTTPRequest:
			child.queue_free()

func show_center_card(card_data: Dictionary):
	if card_data == null or not card_data is Dictionary:  # Check for null or invalid type
		print("Invalid or null card data received:", card_data)
		return
	if not card_data.has("suit") or not card_data.has("rank"):
		print("Invalid card data:", card_data)
		return
		
	for child in $CenterCardSlot.get_children():
		child.queue_free()
		
	var card = preload("res://scenes/Card.tscn").instantiate()
	card.set_data(card_data)
	card.disabled = true
	$CenterCardSlot.add_child(card)

func play_card(card_data: Dictionary):
	if player_index != current_turn_index:
		message_label.text = " not ur turn"
		return

	var url = "http://localhost:3000/play_card"
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({"player_index": player_index, "card": card_data})
	http.request(url, headers, HTTPClient.METHOD_POST, body)

func fetch_state():
	if fetching: 
		return
	fetching = true
		
	var url = "http://localhost:3000/state"
	var err = http.request(url)
	if err != OK:
		message_label.text = "Fetch error: %s" % err
