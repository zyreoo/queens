extends Node2D


var hand = []
var score = 0
var player_id :=-1
var peer_id := -1


func _ready():
	add_to_group("players")

func add_card(card_instance: Node, face_up := false):
	
	if card_instance == null:
		return
	
	if card_instance.get_parent():
		card_instance.get_parent().remove_child(card_instance)
		
	add_child(card_instance)
	hand.append(card_instance)
	
	card_instance.holding_player = self
	card_instance.hand_index = hand.size() - 1
	
	arrange_hand()
		
	var is_local_player = is_local()
	
	if not is_local():
		card_instance.set_mouse_filter(Control.MOUSE_FILTER_IGNORE)
		card_instance.flip_card(false)
	else:
		if face_up:
			card_instance.flip_card(true)
		else:
			card_instance.flip_card(false)
		
	
			
func arrange_hand():
	var spacing_horizontal = 120
	var spacing_vertical = 120
	var total_cards = hand.size()
	var center_offset = (total_cards - 1) /2.0
	var rot = int(round(rotation_degrees))
		
	for i in range(total_cards):
		var card = hand[i]
		if not is_instance_valid(card):
			continue
		card.hand_index = i
		match rot:
			0:
				card.rotation_degrees = 0
				card.position = Vector2(spacing_horizontal * (i - center_offset),0)
			180, -180:
				card.rotation_degrees = 180
				card.position = Vector2(-spacing_horizontal * (i - center_offset), 0)
			90:
				card.rotation_degrees = 90
				card.position = Vector2(0, spacing_vertical * (i - center_offset))
			-90:
				card.rotation_degrees = 90
				card.position = Vector2(0, -spacing_vertical * (i - center_offset))


func calculate_score(_values_dict):
	score = 0
	for card in hand:
		score += card.value
	return score
	
func is_local():
	return peer_id == multiplayer.get_unique_id()


func update_score_label():
	$Label.text = "Score: %d " % score
