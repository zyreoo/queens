extends Node2D


var hand = []
var score = 0

func add_card(card_instance):
	hand.append(card_instance)
	add_child(card_instance)
	
	var index = hand.size() -1
	var total_cards = hand.size()
	var spacing = 80
	
	match rotation_degrees:
		0,180:
			var x = spacing * (index - (total_cards - 1)/2.0)
			card_instance.position = Vector2(x, 0)
			
		90, -90:
			var y = spacing * (index - (total_cards -1)/2.0)
			card_instance.position = Vector2(0,y)
	
	
func calculate_score(_values_dict):
	score = 0
	for card in hand:
		score += card.value
	return score
	
	
func update_score_label():
	$Label.text = "Score: %d " % score
