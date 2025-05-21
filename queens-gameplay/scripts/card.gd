extends TextureButton

var suit := ""
var rank := ""
var value := 0
var card_data := {}
var dragging := false
var drag_offset := Vector2()
var start_position := Vector2()

func set_data(data: Dictionary):
	suit = data["suit"]
	rank = data["rank"]
	value = data["value"]
	var image_path = "res://assets/%s %s.png" % [suit, rank]
	texture_normal = load(image_path)

func _gui_input(event):
	if get_node("/root/Main").player_id != get_node("/root/Main").current_player_id:
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			drag_offset = get_global_mouse_position() - global_position
		else:
			dragging = false
			var center = get_node("/root/Main/CenterCardSlot")
			if center and global_position.distance_to(center.global_position) < 150:
				# Tell Main to play this card
				get_node("/root/Main").play_card(card_data)
				queue_free()
			else:
				position = start_position

func _process(delta):
	if dragging:
		global_position = get_global_mouse_position() - drag_offset
