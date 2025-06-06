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
var drag_start_pos := Vector2()
const DRAG_THRESHOLD := 5.0
const PREVIEW_UPDATE_INTERVAL := 0.05

const BASE_URL = "http://localhost:3000/"
const DEFAULT_TEXTURE_PATH = "res://icon.svg"

@onready var effects = get_node("/root/Main/Effects")
var original_position: Vector2
var drag_start_position: Vector2
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
	
	start_drag()

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
	
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 3.0
	timer.one_shot = true
	timer.timeout.connect(func():
		flip_card(false)
		disabled = false
		timer.queue_free()
	)
	timer.start()

func _input_event(_viewport, event, _shape_idx):
	var main_script = get_node("/root/Main")
	if !main_script:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if !dragging:
					start_drag()
			else:
				end_drag()

func start_drag():
	if is_center_card:
		dragging = false
		return
		
	var main_script = get_node("/root/Main")
	if !main_script:
		dragging = false
		return

	if !main_script.game_started or main_script.initial_selection_mode:
		dragging = false
		return

	drag_start_pos = get_global_mouse_position()
	original_position = global_position
	z_index = 100
	dragging = true
	drag_offset = global_position - drag_start_pos

func end_drag():
	if drag_start_pos != Vector2.ZERO:
		drag_start_pos = Vector2.ZERO
		return
		
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
	var center_slot = get_node("/root/Main/GameContainer/CenterCardSlot")
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

func _process(_delta):
	if !dragging and drag_start_pos != Vector2.ZERO:
		var current_mouse_pos = get_global_mouse_position()
		var distance = drag_start_pos.distance_to(current_mouse_pos)
		if distance > DRAG_THRESHOLD:
			dragging = true
			drag_start_pos = Vector2.ZERO
	elif dragging:
		var mouse_pos = get_global_mouse_position()
		var new_pos = mouse_pos + drag_offset
		global_position = global_position.lerp(new_pos, 0.5)
		
		var center_slot = get_node("/root/Main/GameContainer/CenterCardSlot")
		if center_slot:
			var slot_center = center_slot.global_position + (center_slot.size / 2)
			var card_center = global_position + (size / 2)
			var distance = card_center.distance_to(slot_center)
			
			var current_time = Time.get_ticks_msec() / 1000.0
			if current_time - last_preview_update >= PREVIEW_UPDATE_INTERVAL:
				last_preview_update = current_time
				
				if distance < 100:
					var main_script = get_node("/root/Main")
					if main_script:
						var preview_data = card_data.duplicate()
						preview_data["is_face_up"] = false  # Keep preview face down
						main_script.update_center_preview(preview_data)
				else:
					var main_script = get_node("/root/Main")
					if main_script:
						main_script.clear_center_preview()

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				start_drag()
			else:
				if dragging:
					var center_slot = get_node("/root/Main/GameContainer/CenterCardSlot")
					if center_slot:
						var slot_center = center_slot.global_position + (center_slot.size / 2)
						var card_center = global_position + (size / 2)
						var distance = card_center.distance_to(slot_center)
						
						if distance < 100:
							var target_pos = slot_center - (size / 2)
							var main_script = get_node("/root/Main")
							if main_script:
								main_script.clear_center_preview()
								play_card()
						else:
							effects.animate_card_move(self, original_position)
							var main_script = get_node("/root/Main")
							if main_script:
								main_script.clear_center_preview()
					
					dragging = false
					z_index = initial_z_index

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
