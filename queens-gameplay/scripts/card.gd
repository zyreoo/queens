extends TextureButton

var suit := ""
var rank := ""
var value := 0
var card_data := {}
var dragging := false
var drag_offset := Vector2()
var start_position := Vector2()
var original_parent: Node= null
var holding_player: Node = null
var hand_index: int = -1

func _ready():
	start_position = position
	original_parent = get_parent()
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
		texture_normal = load("res://assets/default_card.png")  # Fallback image
		visible = true
func _gui_input(event):
	var main = get_node_or_null("/root/Main")
	if not main:
		return
	
	if main.player_index != main.current_turn_index:
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			original_parent = get_parent()
			drag_offset = get_global_mouse_position() - global_position
			
			if original_parent:
				original_parent.remove_child(self)
			
			main.add_child(self)
			
		else:
			dragging = false
			var center = get_node_or_null("/root/Main/CenterCardSlot")
			if center:
				var card_rect = Rect2(global_position, size)
				var center_rect = center.get_global_rect()
				if card_rect.intersects(center_rect):
					if main.player_index == main.current_turn_index:
						main.play_card(card_data)
						main.show_center_card(card_data)
						queue_free()
						return
					else:
						main.message_label.text = "Not your turn"
			if original_parent:
				original_parent.add_child(self)
			position = start_position

func _process(delta):
	if dragging:
		global_position = get_global_mouse_position() - drag_offset
