extends Control

@onready var effects = $Effects
@onready var room_list := $RoomList
@onready var refresh_button := $RefreshButton
@onready var join_button := $JoinButton
@onready var message_label := $MessageLabel
@onready var http := $HTTPRequest

var selected_room_id := ""
const BASE_URL = "https://web-production-2342a.up.railway.app/"

func _ready():
	# Add effects to buttons
	effects.add_button_effects(refresh_button)
	effects.add_button_effects(join_button)
	
	# Connect signals
	refresh_button.pressed.connect(_on_refresh_pressed)
	join_button.pressed.connect(_on_join_pressed)
	room_list.item_selected.connect(_on_room_selected)
	
	refresh_rooms()

func refresh_rooms():
	effects.animate_text_fade(message_label, "Refreshing rooms...")
	http.request(BASE_URL + "rooms", [], HTTPClient.METHOD_GET)

func _on_refresh_pressed():
	refresh_rooms()

func _on_room_selected(idx):
	var label = room_list.get_item_text(idx)
	var parts = label.split(" ")
	if parts.size() > 1:
		selected_room_id = parts[1]
		effects.animate_text_pop(message_label, "Room selected: " + selected_room_id)

func _on_join_pressed():
	if selected_room_id == "":
		effects.animate_text_pop(message_label, "Select a room first!")
		return
	effects.animate_text_fade(message_label, "Joining room...")
	RoomState.room_id = selected_room_id
	get_tree().change_scene("res://scenes/main.tscn")

func _on_request_completed(_result, _code, _headers, body):
	var json = JSON.parse_string(body.get_string_from_utf8())
	if typeof(json) != TYPE_DICTIONARY or not json.has("rooms"):
		effects.animate_text_pop(message_label, "Failed to fetch rooms")
		return
	room_list.clear()
	for room in json["rooms"]:
		var room_id = room.get("room_id", "")
		var player_count = room.get("player_count", 0)
		var max_players = room.get("max_players", 2)
		room_list.add_item("Room %s (%d/%d players)" % [room_id, player_count, max_players])
	effects.animate_text_fade(message_label, "Rooms refreshed!") 
