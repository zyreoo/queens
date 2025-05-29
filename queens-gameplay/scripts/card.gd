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

const BASE_URL = "https://web-production-2342a.up.railway.app/"

@onready var effects = get_node("/root/Main/Effects")
var original_position: Vector2
var drag_start_position: Vector2

func _ready():
	effects.add_button_effects(self)
	original_position = position
	mouse_filter = Control.MOUSE_FILTER_PASS
	
func set_data(data: Dictionary):
	suit = data["suit"]
	rank = data["rank"]
	value = data["value"]
	card_data = data
	# The initial flip will be handled by update_player_hand based on is_face_up from server
	
func flip_card(face_up: bool):
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
	# print("Card visibility set to true for: ", suit, " ", rank) # Reduced logging
			
func _input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				start_drag()
			else:
				end_drag()

func start_drag():
	dragging = true
	drag_start_position = position
	effects.play_card_played_effect(self)

func end_drag():
	dragging = false
	if position.distance_to(get_node("/root/Main/CenterCardSlot").position) < 100:
		play_card()
	else:
		effects.animate_card_move(self, original_position)

func play_card():
	effects.animate_card_move(self, get_node("/root/Main/CenterCardSlot").position)
	# ... rest of play card logic ...

func _process(_delta):
	if dragging:
		position = get_global_mouse_position()
