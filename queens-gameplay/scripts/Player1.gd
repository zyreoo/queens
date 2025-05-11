extends Node2D


@export var player_ide: int = -1


var hand = []
var score = 0

func add_card(card_instance: Node, face_up := false):
	
	if card_instance.get_parent():
		card_instance.get_parent().remove_child(card_instance)
		
		
	add_child(card_instance)
	hand.append(card_instance)
	
	
	card_instance.holding_player = self
	card_instance.hand_index = hand.size() - 1
		
	if face_up:
		card_instance.flip_card()
		
	arrange_hand()
	
	
func arrange_hand():
	var spacing_horizontal = 140
	var spacing_vertical = 180
	var total_cards = hand.size()
	var center_offset = (total_cards - 1) /2.0
	var rot = int(round(rotation_degrees))
		
	for i in range(total_cards):
		var card = hand[i]
		if not is_instance_valid(card):
			continue
			
		card.hand_index = i
		

		match rot:
			90:
				card.rotation_degrees = -90
				card.position = Vector2(spacing_vertical * (i - center_offset), 0)
			-90:
				card.rotation_degrees = 90
				card.position = Vector2(-spacing_vertical * (i - center_offset), 0)
			180, -180:
				card.rotation_degrees = 180
				card.position = Vector2(-spacing_horizontal * (i - center_offset), 0)
			_:
				card.rotation_degrees = 0
				card.position = Vector2(spacing_horizontal * (i - center_offset), 0)
		


func calculate_score(_values_dict):
	score = 0
	for card in hand:
		score += card.value
	return score
	
	
func update_score_label():
	$Label.text = "Score: %d " % score
