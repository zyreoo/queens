extends TextureButton

var suit := ""
var rank := ""
var value := 0
var card_data := {}
var dragging := false
var drag_offset := Vector2()
var start_position := Vector2()
var holding_player: Node = null
var hand_index: int = -1
var is_center_card := false
var room_id := ""
var should_trigger_click_action = false
var fetching := false
var last_request_type := ""
var player_id := ""
var http: HTTPRequest
var last_preview_update := 0.0
var initial_click_pos := Vector2.ZERO
var drag_start_time := 0.0
const DRAG_THRESHOLD := 10.0  # pixels
const CLICK_THRESHOLD := 0.2  # seconds
const PREVIEW_UPDATE_INTERVAL := 0.05
const DRAG_SMOOTHING := 0.5  # Increased for more responsive dragging

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
		if not pressed.is_connected(_on_pressed):
			pressed.connect(_on_pressed)
	else:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		disabled = true

func _on_pressed():
	var main_script = get_node("/root/Main")
	if !main_script:
		return

	if main_script.initial_selection_mode:
		if is_instance_valid(holding_player):
			var current_player = main_script.get_node_or_null("GameContainer/BottomPlayerContainer/Player%d" % main_script.player_index)
			if holding_player == current_player:
				main_script._on_card_pressed(self)
		return
	
	# Only start dragging if no other card is being dragged
	if !is_any_card_dragging():
		start_drag()

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if !event.pressed and dragging:
				end_drag()
	
	if !dragging and event is InputEventMouseMotion:
		if drag_start_time > 0:
			var distance = get_global_mouse_position().distance_to(initial_click_pos)
			if distance > DRAG_THRESHOLD:
				if !is_any_card_dragging():
					start_drag()
	
	if dragging and event is InputEventMouseMotion:
		var target_pos = get_global_mouse_position() + drag_offset
		# Direct position update for more responsive dragging
		global_position = target_pos
		
		var main_script = get_node("/root/Main")
		if main_script:
			var center_slot = main_script.get_node_or_null("GameContainer/CenterCardSlot")
			if center_slot:
				var slot_center = center_slot.global_position + (center_slot.size / 2)
				var card_center = global_position + (size / 2)
				var distance = card_center.distance_to(slot_center)
				
				var current_time = Time.get_ticks_msec() / 1000.0
				if current_time - last_preview_update >= PREVIEW_UPDATE_INTERVAL:
					last_preview_update = current_time
					
					if distance < 100:
						var preview_data = card_data.duplicate()
						preview_data["is_face_up"] = false
						main_script.update_center_preview(preview_data)
					else:
						main_script.clear_center_preview()

func is_any_card_dragging() -> bool:
	var main_script = get_node("/root/Main")
	if !main_script:
		return false
		
	for container_name in ["BottomPlayerContainer", "TopPlayerContainer"]:
		var container = main_script.get_node_or_null("GameContainer/" + container_name)
		if container:
			for player in container.get_children():
				var hand_container = player.get_node_or_null("HandContainer")
				if hand_container:
					for card in hand_container.get_children():
						if card != self and card.has_method("is_dragging") and card.is_dragging():
							return true
	return false

func is_dragging() -> bool:
	return dragging

func start_drag():
	if is_center_card or disabled:
		return
		
	var main_script = get_node("/root/Main")
	if !main_script or !main_script.game_started or main_script.initial_selection_mode:
		return

	dragging = true
	original_position = global_position
	z_index = 100
	drag_offset = global_position - get_global_mouse_position()
	initial_click_pos = get_global_mouse_position()

func end_drag():
	if !dragging:
		return

	var main_script = get_node("/root/Main")
	if !main_script:
		dragging = false
		z_index = initial_z_index
		effects.animate_card_move(self, original_position)
		main_script.clear_center_preview()
		return

	var can_play_card = false
	var center_slot = main_script.get_node_or_null("GameContainer/CenterCardSlot")
	if center_slot:
		var slot_center = center_slot.global_position + (center_slot.size / 2)
		var card_center = global_position + (size / 2)
		var distance = card_center.distance_to(slot_center)
		if distance < 100:
			can_play_card = true
		else:
			main_script.clear_center_preview()
	
	if can_play_card:
		play_card()
	else:
		effects.animate_card_move(self, original_position)
		main_script.clear_center_preview()
	
	dragging = false
	z_index = initial_z_index
	drag_start_time = 0.0

func set_data(data: Dictionary):
	if data.has("suit"):
		suit = data["suit"]
	if data.has("rank"):
		rank = data["rank"]
	if data.has("value"):
		value = data["value"]
	card_data = data

func flip_card(face_up: bool):
	if not face_up:
		var back_texture = load("res://assets/card_back-export.png")
		if back_texture:
			texture_normal = back_texture
		else:
			push_error("Failed to load card back texture")
			texture_normal = load("res://icon.svg")
	else:
		if suit != "" and rank != "" and suit != "Unknown" and rank != "0":
			var suit_name = suit.substr(0, 1).to_upper() + suit.substr(1).to_lower()
			var image_path = "res://good_cards/%s %s.png" % [suit_name, rank]
			var texture = load(image_path)
			if texture:
				texture_normal = texture
			else:
				push_error("Failed to load card texture: " + image_path)
				flip_card(false)  # If we can't load the front texture, show the back
		else:
			# For unknown cards, show the back
			flip_card(false)
	visible = true

func temporary_reveal():
	if not card_data.has("was_initially_seen"):
		card_data["was_initially_seen"] = false
	
	if card_data.was_initially_seen:
		return
		
	disabled = true
	flip_card(true)
	card_data.was_initially_seen = true
	modulate = Color(1, 1, 1)  # Ensure no color tint
	
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 3.0
	timer.one_shot = true
	timer.timeout.connect(func():
		flip_card(false)
		disabled = false
		modulate = Color(1, 1, 1)  # Ensure no color tint after flip
		timer.queue_free()
	)
	timer.start()

func play_card():
	var center_slot = get_node("/root/Main/GameContainer/CenterCardSlot")
	if !center_slot:
		return
		
	dragging = false
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
