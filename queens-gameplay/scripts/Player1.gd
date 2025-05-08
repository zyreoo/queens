extends Node2D


var hand = []
var score = 0

func add_card(card_instance: Node, face_up := false):
	hand.append(card_instance)
	add_child(card_instance)
	
	var index = hand.size() -1
	var total_cards = hand.size()
	var spacing_horizontal = 100
	var spacing_vertical = 140
	
	
	var rot = int(round(rotation_degrees))
	
	if abs(rot) ==90:
		var y = spacing_vertical*(index - (total_cards-1)/2.0)
		card_instance.position = Vector2(0,y)
		
	else:
		var x = spacing_horizontal * (index - (total_cards-1)/2.0)
		card_instance.position = Vector2(x, 0)
		
	if face_up:
		card_instance.flip_card()
	

func calculate_score(_values_dict):
	score = 0
	for card in hand:
		score += card.value
	return score
	
	
func update_score_label():
	$Label.text = "Score: %d " % score
