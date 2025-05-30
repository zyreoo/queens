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
var should_trigger_click_action = false;

const BASE_URL = "https://web-production-2342a.up.railway.app/"

@onready var effects = get_node("/root/Main/Effects")
var original_position: Vector2
var drag_start_position: Vector2

func _ready():
	call_deferred("add_button_effects_deferred")
	
	original_position = position
	mouse_filter = Control.MOUSE_FILTER_PASS
	
func set_data(data: Dictionary):
	suit = data["suit"]
	rank = data["rank"]
	value = data["value"]
	card_data = data
	
func flip_card(face_up: bool):
	print("flip_card called with face_up: ", face_up)
	if face_up:
		var image_path = "res://assets/%s_%s.png" % [suit, rank]
		texture_normal = load(image_path)
		if not texture_normal:
			print("Failed to load card image: ", image_path)
			texture_normal = load("res://assets/default_card.png")
		else:
			print("Loaded card image: ", image_path)
			
	else: 
		texture_normal = load("res://assets/card_back_3.png")
		if not texture_normal:
			print("Failed to load card back image: res://assets/card_back_3.png")
			texture_normal = load("res://assets/default_card.png")
	visible = true
			
func _input_event(_viewport, event, _shape_idx):
	var main_script = get_node("/root/Main")
	if !main_script:
		print("Error: Main script not found in card.gd")
		return

	print("Card input event received: ", event)

	if event is InputEventMouseButton:
		print("Mouse button event: ", event.button_index, ", pressed: ", event.pressed)
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				drag_start_position = global_position
				
				var should_trigger_click_action = false
				print("Initial selection mode: ", main_script.initial_selection_mode, ", Holding player: ", holding_player, ", Current player node: ", main_script.get_node("Player%d" % main_script.player_index))
				if main_script.initial_selection_mode and is_instance_valid(holding_player) and holding_player == main_script.get_node("Player%d" % main_script.player_index):
					should_trigger_click_action = true
				elif main_script.king_reveal_mode and main_script.player_index == main_script.king_player_index:
					should_trigger_click_action = true
				elif main_script.jack_swap_mode and main_script.player_index == main_script.jack_player_index:
					should_trigger_click_action = true
					
				if should_trigger_click_action:
					print("Triggering click action on press")
					main_script._on_card_pressed(self)
				else:
					start_drag()
			else:
				var drag_distance = global_position.distance_to(drag_start_position)
				var is_click = drag_distance < 10
				
				if is_click:
					var should_trigger_click_action = false
					if main_script.initial_selection_mode and is_instance_valid(holding_player) and holding_player == main_script.get_node("Player%d" % main_script.player_index):
						should_trigger_click_action = true
					elif main_script.king_reveal_mode and main_script.player_index == main_script.king_player_index:
						should_trigger_click_action = true
					elif main_script.jack_swap_mode and main_script.player_index == main_script.jack_player_index:
						should_trigger_click_action = true

					if should_trigger_click_action:
						print("Triggering click action on release")
						main_script._on_card_pressed(self)
						dragging = false
					else:
						end_drag()
			
func start_drag():
	var main_script = get_node("/root/Main")
	if !main_script:
		dragging = false
		return

	var should_prevent_drag = false
	print("Initial selection mode for drag check: ", main_script.initial_selection_mode, ", Holding player for drag check: ", is_instance_valid(holding_player), ", Current player node for drag check: ", is_instance_valid(main_script.get_node_or_null("Player%d" % main_script.player_index)), ", Match: ", is_instance_valid(holding_player) and is_instance_valid(main_script.get_node_or_null("Player%d" % main_script.player_index)) and holding_player == main_script.get_node("Player%d" % main_script.player_index))
	if main_script.initial_selection_mode and is_instance_valid(holding_player) and holding_player == main_script.get_node("Player%d" % main_script.player_index):
		should_prevent_drag = true
	elif main_script.king_reveal_mode and main_script.player_index == main_script.king_player_index:
		should_prevent_drag = true
	elif main_script.jack_swap_mode and main_script.player_index == main_script.jack_player_index:
		should_prevent_drag = true

	if should_prevent_drag:
		dragging = false
		return

	dragging = true
	drag_start_position = position
	effects.play_card_played_effect(self)

func end_drag():
	if !dragging:
		return
	dragging = false

	# Check game mode to ensure play_card is only called in normal gameplay
	var main_script = get_node("/root/Main")
	if !main_script:
		print("Error: Main script not found in card.gd on end_drag")
		return

	var can_play_card = false
	print("Initial selection mode for play check: ", main_script.initial_selection_mode, ", King reveal mode for play check: ", main_script.king_reveal_mode, ", Jack swap mode for play check: ", main_script.jack_swap_mode, ", Reaction mode for play check: ", main_script.reaction_mode, ", Final round active for play check: ", main_script.final_round_active, ", Player index: ", main_script.player_index, ", Current turn index: ", main_script.current_turn_index, ", Match: ", main_script.player_index == main_script.current_turn_index)
	if !main_script.initial_selection_mode and !main_script.king_reveal_mode and !main_script.jack_swap_mode and !main_script.reaction_mode and !main_script.final_round_active and main_script.player_index == main_script.current_turn_index:
		if position.distance_to(get_node("/root/Main/CenterCardSlot").position) < 100:
			can_play_card = true

	if can_play_card:
		print("Playing card via drag.")
		play_card()
	else:
		print("Not playing card via drag. Animating back.")
		effects.animate_card_move(self, original_position)
	dragging = false

func play_card():
	effects.animate_card_move(self, get_node("/root/Main/CenterCardSlot").position)
	var main_script = get_node("/root/Main")
	if main_script:
		main_script._on_card_played(card_data)

func _process(_delta):
	if dragging:
		position = get_global_mouse_position()

func add_button_effects_deferred():
	if self:
		effects.add_button_effects(self)
