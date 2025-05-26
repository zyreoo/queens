extends Node2D

var hand: Array = []
var score: int = 0
var player_id: int = -1

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
	
	
	
	card_instance.flip_card(face_up)
	
	arrange_hand()

func arrange_hand():
	var spacing = 30
	var start_x = 0
	for i in range(hand.size()):
		var card = hand[i]
		card.position = Vector2(start_x + i * spacing, 0)

func calculate_score():
	score = 0
	for card in hand:
		score += card.value
	return score

func update_score_label():
	$Label.text = "Score: %d" % score
