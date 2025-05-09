extends TextureButton


@export var suit: String
@export var rank: String
@export var value: int

var card_back_texture = preload("res://assets/Card Back 3.png")
var front_texture : Texture = null
var label_rank_suit = null 
var texture = null
var is_flipped = false
var holding_player : Node = null
var hand_index = -1
var is_dragging = false


func _ready():
	
	var front_image_path = "res://assets/%s %s.png" % [suit, rank]
	front_texture = load(front_image_path)
	
	self.texture_normal = card_back_texture
	
	
	var callback = Callable(self, "_on_card_clicked")
	
	connect("pressed", Callable(self, "_on_card_clicked"))




func _on_card_clicked():
	var main = get_tree().get_root().get_node("Main")
	
	
	
	if holding_player != main.players[main.current_player_index]:
		print("not ur turn")
		return
		
	if main.swap_mode and main.drawn_card != null:
		main.swap_card_with(self)
	else :
		flip_card()

	
	
func flip_card():
	is_flipped = !is_flipped
	self.texture_normal = front_texture if is_flipped else card_back_texture
		
		
func _gui_input(event):
	if holding_player != get_tree().get_root().get_node("Main").players[get_tree().get_root().get_node("Main").current_player_index]:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging = true
			
		else:
			is_dragging = false
			var main = get_tree().get_root().get_node("Main")
			var center = main.get_node("CenterCardSlot")
			var center_pos = center.global_position
		
			if global_position.distance_to(center_pos) < 150:
				main.play_card_to_center(self)
			
			
func _process(delta):
	if is_dragging:
		global_position = get_global_mouse_position()
		
			
			
func play_card_to_center(card):
	if card.get_parent():
		card.get_parent().remove_child(card)
		
	add_child(card)
	card.flip_card()
	card.global_position  = $CenterCardSlot.global_position
	card.set_process(false)
			
		
		
