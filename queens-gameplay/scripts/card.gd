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


func _on_card_clicked():
	var main = get_tree().get_root().get_node("Main")
	
	
	if holding_player != main.players[main.current_player_index]:
		print("not ur turn")
		return
		
	if main.swap_mode and main.drawn_card != null:
		main.swap_card_with(self)
	else :
		flip_card()
	
func _ready():
	
	var front_image_path = "res://assets/%s %s.png" % [suit, rank]
	front_texture = load(front_image_path)
	
	self.texture_normal = card_back_texture
	
	
	var callback = Callable(self, "_on_card_clicked")
	if not is_connected("pressed", callback):
		connect("pressed", callback)

	
func flip_card():
	is_flipped = !is_flipped
	if is_flipped:
		self.texture_normal = front_texture
		
	else:
		self.texture_normal = card_back_texture
			
			
			
		
		
