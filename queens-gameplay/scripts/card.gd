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
	
	texture = card_back_texture
	var front_image_path = "res://assets/%s_%s.png" % [suit,rank]
	front_texture = load(front_image_path)	
	
	label_rank_suit = $LabelRankSuit
	label_rank_suit.text = "%s%s" % [rank,suit]
	
	pressed.connect(_on_card_clicked)

	
func flip_card():
	if is_flipped:
		texture = card_back_texture
	
	else:
		texture = front_texture
	is_flipped = !is_flipped
		
