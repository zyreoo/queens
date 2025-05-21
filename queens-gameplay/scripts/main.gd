extends Node2D

@onready var http := $HTTPRequest
@onready var message_label := $MessageLabel
@onready var start_button := $StartGameButton

var player_id: int = -1
var center_card: Dictionary = {}
var poll_timer := Timer.new()
var current_player_id = null

func _ready():
	add_child(poll_timer)
	http.request_completed.connect(_on_request_completed)
	poll_timer.wait_time = 1.0
	poll_timer.timeout.connect(fetch_state)
	poll_timer.start()

	join_game()
	start_button.pressed.connect(_on_start_game)

func join_game():
	var url = "http://localhost:3000/join"
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({"room_id": "room1"})
	var err = http.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		printerr("❌ Failed to join:", err)

func _on_start_game():
	message_label.text = "Game start pressed (no-op unless handled on server)"
	# Optional: trigger a /start_game endpoint if you have one

func _on_request_completed(result, code, headers, body):
	var response_text = body.get_string_from_utf8()
	print("🔍 Raw response:", response_text)
	

	var json = JSON.parse_string(response_text)
	if json == null or typeof(json) != TYPE_DICTIONARY:
		message_label.text = "❌ Invalid response"
		return
		
	var hand_cards = []
	if json.has("hand"):
		hand_cards = json["hand"]
		for card_data in hand_cards:
			add_card_to_hand(card_data)

	if json.has("next_player_id"):
		message_label.text = "✅ Card played!"
		clear_hand()
	
	if json.has("current_player_id"):
		current_player_id = json["current_player_id"]
	
	if json.has("status"):
		# This is a response from /join or /play_card
		if json["status"] == "ok":
			player_id = json.get("player_id", player_id)
			message_label.text = "✅ " + json.get("message", "Joined")
			print("🎴 Hand:", json.get("hand", []))
			print("🃏 Center:", json.get("center_card", {}))
	else:
		# This is a response from /state
		if json.has("center_card"):
			var card = json["center_card"]
			show_center_card(card)
	
		if json.has("current_player_id"):
			if json["current_player_id"] == player_id:
				message_label.text = "🎯 Your turn!"
			else:
				message_label.text = "⌛ Waiting for Player %d" % json["current_player_id"]
				
func add_card_to_hand(card_data: Dictionary):
	var card = preload("res://scenes/Card.tscn").instantiate()
	card.set_data(card_data)
	card.pressed.connect(func(): _on_card_pressed(card_data)) 
	$HandContainer.add_child(card)

func clear_hand():
	for child in get_children():
		if child is TextureButton and child != $HTTPRequest:
			child.queue_free()

func _on_card_pressed(card_data: Dictionary):
	if player_id == null:
		message_label.text = "❌ Not connected"
		return
	var url = "http://localhost:3000/play_card"
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({
		"player_id": player_id,
		"card": card_data
	})
	http.request(url, headers, HTTPClient.METHOD_POST, body)

func show_center_card(card_data: Dictionary):
	if not card_data.has("suit") or not card_data.has("rank"):
		print("❌ Invalid card data:", card_data)
		return

	for child in $CenterCardSlot.get_children():
		child.queue_free()

	var card = preload("res://scenes/Card.tscn").instantiate()
	card.set_data(card_data)
	card.disabled = true
	$CenterCardSlot.add_child(card)


func play_card(card_data: Dictionary):
	if player_id == null:
		message_label.text = "⛔ You are not connected."
		return

	var url = "http://localhost:3000/play_card"
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({"player_id": player_id, "card": card_data})
	http.request(url, headers, HTTPClient.METHOD_POST, body)

func fetch_state():
	var url = "http://localhost:3000/state"
	var err = http.request(url)
	if err != OK:
		message_label.text = "❌ Fetch error: %s" % err
