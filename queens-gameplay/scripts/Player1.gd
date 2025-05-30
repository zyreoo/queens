extends Node2D

var hand: Array = []
var score: int = 0
var player_id: int = -1

const BASE_URL = "https://web-production-2342a.up.railway.app/"

@onready var hand_container = $HandContainer

func _ready():
	add_to_group("players")

func add_card(card_instance: Node, face_up := false):
	if card_instance == null:
		return

	if card_instance.get_parent():
		card_instance.get_parent().remove_child(card_instance)

	hand_container.add_child(card_instance)
	hand.append(card_instance)
	card_instance.holding_player = self
	card_instance.hand_index = hand.size() - 1
	
	if card_instance.card_data.has("is_face_up"):
		face_up = card_instance.card_data["is_face_up"]
	
	card_instance.flip_card(face_up)
	arrange_hand()

func arrange_hand():
	var spacing = 30
	var total_width = (hand.size() - 1) * spacing
	var start_x = -total_width / 2  
	var screen_size = get_viewport_rect().size
	for i in range(hand.size()):
		var card = hand[i]
		var x_pos = start_x + i * spacing
		card.position = Vector2(x_pos, 0)  
		card.z_index = i 
		var global_card_pos = card.global_position
		if global_card_pos.x < 0:
			card.position.x -= global_card_pos.x 
		elif global_card_pos.x + card.size.x > screen_size.x:
			card.position.x -= (global_card_pos.x + card.size.x - screen_size.x)
		print("Arranged card ", i, " at position: ", card.position, " visible: ", card.visible)
			
		
func clear_hand():
	for card in hand:
		card.queue_free()
	hand.clear()
		
func calculate_score():
	score = 0
	for card in hand:
		if card.card_data["rank"] == "12":
			score += 0
		elif card.card_data["rank"] == "1":
			score += 1
		elif card.card_data["rank"] in ["11", "13"]:
			score += 10
		else:
			score += int(card.card_data["rank"])
	return score

func update_score_label():
	$Label.text = "Score: %d" % score
