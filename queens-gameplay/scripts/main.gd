extends Node2D

@onready var http := $HTTPRequest
@onready var message_label := $MessageLabel
@onready var start_button := $StartGameButton

var player_id: int = -1
var center_card: Dictionary = {}
var poll_timer := Timer.new()
var current_player_id = null
var fetching := false
var has_joined := false
var player_index := -1
var current_turn_index := -1

func _ready():
	if player_id == -1:
		join_game()
	print("Sending join request...")
	var url = "http://localhost:3000/join"
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({"room_id": "room1"})
	var err = http.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		printerr("Failed to join:", err)
	

func join_game():
	if player_id != -1:
		print("already joineds as player")
		return
		
	var url = "http://localhost:3000/join"
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({"room_id": "room1"})
	var err = http.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		printerr("Failed to join:", err)

func _on_start_game():
	message_label.text = "Game start pressed (no-op unless handled on server)"

func _on_request_completed(result, code, headers, body):
	var json = JSON.parse_string(body.get_string_from_utf8())
	if not json: return

	if json.has("player_index"):
		player_index = int(json["player_index"])
		
	if json.has("current_turn_index"):
		current_turn_index = int(json["current_turn_index"])
		
		if player_index == current_turn_index:
			message_label.text = " Your turn!"
		else:
			message_label.text = " Waiting for player %d" % current_turn_index

	if json.has("hand"):
		for card_data in json["hand"]:
			add_card_to_hand(card_data, player_index)

	if json.has("center_card"):
		show_center_card(json["center_card"])


func _on_card_pressed(card_data: Dictionary):
	if player_index != current_turn_index:
		message_label.text = "not ur turn "
		return
	print("playing card", card_data)
	play_card(card_data)
			
func add_card_to_hand(card_data: Dictionary, for_player_index: int):
	var card = preload("res://scenes/Card.tscn").instantiate()
	card.set_data(card_data)

	if for_player_index == player_index:
		card.pressed.connect(func(): _on_card_pressed(card_data))
		$Player0/HandContainer.add_child(card)
	else:
		card.disabled = true
		card.flip_card(false)
		var hand_node = get_node_or_null("Player%d/HandContainer" % for_player_index)
		if hand_node:
			hand_node.add_child(card)



func clear_hand():
	for child in get_children():
		if child is TextureButton and child != $HTTPRequest:
			child.queue_free()

func show_center_card(card_data: Dictionary):
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
