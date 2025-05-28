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

func _ready():
	start_position = position
	mouse_filter = Control.MOUSE_FILTER_PASS
	
func set_data(data: Dictionary):
	suit = data["suit"]
	rank = data["rank"]
	value = data["value"]
	card_data = data
	var image_path = "res://assets/%s_%s.png" % [suit, rank]
	texture_normal = load(image_path)
	
	
func flip_card(face_up: bool):
	if face_up:
		var image_path = "res://assets/%s_%s.png" % [suit, rank]
		texture_normal = load(image_path)
	else: 
		texture_normal = load("res://assets/card_back_3.png")
	if not texture_normal:
		print("Failed to load card back image: res://assets/card_back_3.png")
		texture_normal = load("res://assets/default_card.png")
		visible = true
		
		
func _gui_input(event):
	if is_center_card:
		return
		
	var main = get_node_or_null("/root/Main")
	if not main or (main.player_index != main.current_turn_index and not main.reaction_mode):
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			drag_offset = get_global_mouse_position() - global_position
			if get_parent():
				get_parent().remove_child(self)
			main.add_child(self)
		else:
			dragging = false
			var center = get_node_or_null("/root/Main/CenterCardSlot")
			if center and global_position.distance_to(center.global_position) < 350:
				main._on_card_pressed(card_data)
			else:
				if holding_player:
					if get_parent():
						get_parent().remove_child(self)
					holding_player.add_child(self)
					position = Vector2.ZERO
					holding_player.arrange_hand()
					if not get_rect().has_point(get_local_mouse_position()):
						dragging = false          
						
func _process(_delta):
	if dragging and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		global_position = get_global_mouse_position() - drag_offset
