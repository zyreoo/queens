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
	
	if peer_id == multiplayer.get_unique_id():
		card_instance.set_mouse_filter(Control.MOUSE_FILTER_PASS)
	else:
		card_instance.set_mouse_filter(Control.MOUSE_FILTER_IGNORE)

	card_instance.flip_card(face_up)
			
func is_local():
	var peer_id = multiplayer.get_unique_id()
	return peer_id
			
func arrange_hand():
	var spacing = 120
	var total_cards = hand.size()
	var center_offset = (total_cards - 1) /2.0
	var rot = int(round(rotation_degrees))
		
	for i in range(total_cards):
		var card = hand[i]
		if not is_instance_valid(card):
			continue
		card.hand_index = i
		card.position = Vector2(spacing * (i - center_offset), 0)
		card.rotation_degrees = 0 

func calculate_score(_values_dict):
	score = 0
	for card in hand:
		score += card.value
	return score


func update_score_label():
	$Label.text = "Score: %d " % score
