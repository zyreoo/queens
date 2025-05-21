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

	arrange_hand()
	card_instance.flip_card(face_up)

func arrange_hand():
	var spacing = 120
	var total_cards = hand.size()
	var center_offset = (total_cards - 1) / 2.0

	for i in range(total_cards):
		var card = hand[i]
		if not is_instance_valid(card):
			continue
		card.hand_index = i
		card.position = Vector2(spacing * (i - center_offset), 0)
		card.rotation_degrees = 0

func calculate_score():
	score = 0
	for card in hand:
		score += card.value
	return score

func update_score_label():
	$Label.text = "Score: %d" % score
