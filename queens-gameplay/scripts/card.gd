extends TextureButton

var suit := ""
var rank := ""
var value := 0
var card_data := {}
var is_dragging := false
var drag_offset := Vector2()
var start_position := Vector2()
var holding_player: Node = null
var hand_index: int = -1
var is_center_card := false
var room_id := ""
var fetching := false
var last_request_type := ""
var player_id := ""
var http: HTTPRequest
var initial_click_pos := Vector2.ZERO

const DRAG_THRESHOLD := 10.0
const BASE_URL = "http://localhost:3000/"
const DEFAULT_TEXTURE_PATH = "res://icon.svg"

@onready var effects = get_node("/root/Main/Effects")
var original_position: Vector2
var initial_z_index: int

func _ready():
	call_deferred("add_button_effects_deferred")
	original_position = position
	initial_z_index = z_index
	
	if not is_center_card:
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		disabled = true

func _gui_input(event):
	var main_script = get_node("/root/Main")
	if !main_script:
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Start potential drag
			initial_click_pos = get_global_mouse_position()
			start_position = position
			drag_offset = position - get_global_mouse_position()
			is_dragging = false
		else:
			# Mouse released - check if it was a click or end drag
			var current_pos = get_global_mouse_position()
			var distance = initial_click_pos.distance_to(current_pos)
			
			if distance < DRAG_THRESHOLD:
				# It was a click
				if holding_player and (main_script.initial_selection_mode or main_script.king_reveal_mode):
					holding_player._on_card_input(event, self)
			else:
				# It was a drag - check if we should play the card
				if is_dragging and not disabled and main_script.current_turn_index == main_script.player_index:
					var center_slot = main_script.get_node_or_null("GameContainer/CenterCardSlot")
					if center_slot:
						var slot_rect = center_slot.get_global_rect()
						var card_center = global_position + (size / 2)
						if slot_rect.has_point(card_center):
							play_card()
						else:
							effects.animate_card_move(self, start_position)
			
			# Reset state
			is_dragging = false
			initial_click_pos = Vector2.ZERO
			z_index = initial_z_index
			scale = Vector2(1.0, 1.0)
			main_script.clear_center_preview()
	
	elif event is InputEventMouseMotion:
		# Only start dragging if we're holding the left mouse button
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and initial_click_pos != Vector2.ZERO:
			var current_pos = get_global_mouse_position()
			var distance = initial_click_pos.distance_to(current_pos)
			
			# Start drag if we've moved enough
			if distance > DRAG_THRESHOLD and not main_script.initial_selection_mode:
				is_dragging = true
				z_index = 100
				scale = Vector2(1.1, 1.1)  # Visual feedback
				
				# Update card position
				position = get_global_mouse_position() + drag_offset
				
				# Update preview in center slot
				var center_slot = main_script.get_node_or_null("GameContainer/CenterCardSlot")
				if center_slot:
					var slot_rect = center_slot.get_global_rect()
					var card_center = global_position + (size / 2)
					if slot_rect.has_point(card_center):
						var preview_data = card_data.duplicate()
						preview_data["is_face_up"] = false
						main_script.update_center_preview(preview_data)
					else:
						main_script.clear_center_preview()

func set_data(data: Dictionary):
	if data.has("suit"):
		suit = data["suit"]
	if data.has("rank"):
		rank = data["rank"]
	if data.has("value"):
		value = data["value"]
	card_data = data

func flip_card(face_up: bool):
	if not card_data:
		return
		
	card_data.is_face_up = face_up
	
	if face_up:
		var suit_name = card_data.suit.substr(0, 1).to_upper() + card_data.suit.substr(1).to_lower()
		var image_path = "res://good_cards/%s %s.png" % [suit_name, card_data.rank]
		texture_normal = load(image_path)
	else:
		texture_normal = load("res://assets/card_back-export.png")

func temporary_reveal():
	if not card_data.is_face_up:
		card_data.is_face_up = true
		flip_card(true)
		modulate = Color(1, 1, 0.7)

func play_card():
	var center_slot = get_node("/root/Main/GameContainer/CenterCardSlot")
	if !center_slot:
		return
		
	is_dragging = false
	z_index = initial_z_index
	
	var slot_center = center_slot.global_position + (center_slot.size / 2)
	var target_pos = slot_center - (size / 2)
	
	var main_script = get_node("/root/Main")
	if main_script:
		var played_card_data = card_data.duplicate()
		played_card_data["is_face_up"] = true
		
		main_script._on_card_played(played_card_data)
		main_script.show_center_card(played_card_data)
		main_script.add_to_used_deck(self)
		
		queue_free()

func add_button_effects_deferred():
	if self and !is_center_card:
		effects.add_button_effects(self)

func fetch_state():
	if room_id.is_empty() or player_id.is_empty() or fetching:
		return
	fetching = true
	last_request_type = "state"
	var url = BASE_URL + "state"
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({
		"room_id": room_id,
		"player_id": player_id
	})
	http.request(url, headers, HTTPClient.METHOD_POST, body)

func get_drag_data(_position):
	var drag_preview = TextureButton.new()
	drag_preview.texture_normal = texture_normal
	drag_preview.size = size
	set_drag_preview(drag_preview)
	
	return card_data

func set_card_data(data: Dictionary):
	card_data = data

func _on_card_played():
	var main_script = get_node("/root/Main")
	if !main_script:
		return
		
	var center_slot = main_script.get_node_or_null("GameContainer/CenterCardSlot")
	if center_slot and global_position.distance_to(center_slot.global_position) < 100:
		play_card()
	else:
		effects.animate_card_move(self, original_position)
		main_script.clear_center_preview()
	
	is_dragging = false
	z_index = initial_z_index

func get_rank() -> String:
	return rank

func get_card_id() -> String:
	if card_data and card_data.has("card_id"):
		return card_data.card_id
	return ""
