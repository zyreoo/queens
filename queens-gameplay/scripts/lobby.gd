extends Control

@onready var room_list := $RoomList
@onready var refresh_button := $RefreshButton
@onready var join_button := $JoinButton
@onready var message_label := $MessageLabel
@onready var http := $HTTPRequest

var selected_room_id := ""

func _ready():
	refresh_button.pressed.connect(_on_refresh_pressed)
	join_button.pressed.connect(_on_join_pressed)
	room_list.item_selected.connect(_on_room_selected)
	add_child(http)
	http.request_completed.connect(_on_request_completed)
	refresh_rooms()

func refresh_rooms():
	http.request("http://localhost:3000/rooms", [], HTTPClient.METHOD_GET)

func _on_refresh_pressed():
	refresh_rooms()

func _on_room_selected(idx):
	var label = room_list.get_item_text(idx)
	var parts = label.split(" ")
	if parts.size() > 1:
		selected_room_id = parts[1]

func _on_join_pressed():
	if selected_room_id == "":
		message_label.text = "Select a room first!"
		return
	RoomState.room_id = selected_room_id
	get_tree().change_scene("res://scenes/main.tscn")

func _on_request_completed(_result, _code, _headers, body):
	var json = JSON.parse_string(body.get_string_from_utf8())
	if typeof(json) != TYPE_DICTIONARY or not json.has("rooms"):
		message_label.text = "Failed to fetch rooms"
		return
	room_list.clear()
	for room in json["rooms"]:
		var room_id = room.get("room_id", "")
		var player_count = room.get("player_count", 0)
		var max_players = room.get("max_players", 2)
		room_list.add_item("Room %s (%d/%d players)" % [room_id, player_count, max_players]) 
