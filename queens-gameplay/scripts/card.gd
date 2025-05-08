extends TextureButton


@export var suit: String
@export var rank: String
@export var value: int

var card_back_texture = preload("res://assets/Card Back 3.png")
var front_texture : Texture = null
var label_rank_suit = null 
var texture = null
var is_flipped = false


func _on_card_clicked():
	flip_card()
	
func _ready():
	
	var front_image_path = "res://assets/%s %s.png" % [suit,rank]
	front_texture = load(front_image_path)	
	
	self.texture_normal = card_back_texture
	
	label_rank_suit = $LabelRankSuit
	label_rank_suit.text = "%s%s" % [rank,suit]
	label_rank_suit.visible = false
	
	var callback = Callable(self, "_on_card_clicked")
	if not is_connected("pressed", callback):
		connect("pressed", callback)
		
	print("Label nodes:", $LabelRankSuit)

	
func flip_card():
	is_flipped = !is_flipped
	if is_flipped:
		self.texture_normal = front_texture
		if label_rank_suit != null:
			label_rank_suit.visible = true
		
	
	else:
		self.texture_normal = card_back_texture
		if label_rank_suit != null:
			label_rank_suit.visible = false
		
		
