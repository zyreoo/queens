extends Control

var hand: Array = []
var score: int = 0
var player_id: int = -1

const BASE_URL = "https://web-production-2342a.up.railway.app/"

var hand_container: HBoxContainer = null # This will be set by main.gd
var is_setup := false

func _ready():
	print(self.name, " _ready called. Children:", get_children())
	add_to_group("players")
	# hand_container is expected to be valid here if main.gd has set it
	# Add a check just in case, though main.gd should ensure it's set
	if not is_instance_valid(hand_container):
		print("Warning: HandContainer not set by main.gd for ", self.name)

func setup_player():
	print(self.name, " setup_player called")
	# hand_container is guaranteed to be valid here if main.gd set it correctly
	# Add a check just in case
	if not is_instance_valid(hand_container):
		print("Error: HandContainer invalid in setup_player for ", self.name, ". Setup failed.")
		return

	print(self.name, " setup_player: HandContainer is valid.")

	# Process cards that might have been added before setup was complete
	if hand.size() > 0:
		print(self.name, " setup_player: Processing ", hand.size(), " cards added before setup.")
		var temp_hand = hand.duplicate()
		hand.clear()
		for card in temp_hand:
			add_card(card) # Use add_card to properly add to container and hand array

	is_setup = true
	print(self.name, " setup_player finished. is_setup: ", is_setup)

func add_card(card_instance: Node, face_up := false):
	if card_instance == null:
		print(self.name, " add_card: card_instance is null")
		return

	# If not setup, add to a temporary hand array
	if not is_setup:
		print(self.name, " add_card called before setup. Card will be added to temporary hand array.")
		if not hand.has(card_instance):
			hand.append(card_instance)
		return

	# Use the stored hand_container reference after setup
	if not is_instance_valid(hand_container):
		# This should ideally not happen if main.gd set it and setup_player checked
		print("Error: HandContainer invalid in add_card for ", self.name, " after setup.")
		return
	print(self.name, " add_card called after setup. HandContainer is valid. Attempting to add card.")

	if card_instance.get_parent():
		print(self.name, " add_card: Removing card from existing parent.")
		card_instance.get_parent().remove_child(card_instance)

	hand_container.add_child(card_instance)
	print(self.name, " add_card: Added card to HandContainer.")

	# Add to the player's main hand array if not already there
	if not hand.has(card_instance):
		hand.append(card_instance)
	
	card_instance.holding_player = self
	card_instance.hand_index = hand.size() - 1 # Use hand array size for index
	print(self.name, " add_card: Set holding_player and hand_index.")
	
	if card_instance.card_data.has("is_face_up"):
		face_up = card_instance.card_data["is_face_up"]
	
	card_instance.flip_card(face_up)
	print(self.name, " add_card: Flipped card.")
	arrange_hand()
	print(self.name, " add_card: Arranged hand.")

func update_hand_display(hand_data: Array):
	print(self.name, " update_hand_display called with ", hand_data.size(), " cards")
	
	# Ensure hand_container is valid before clearing and adding
	if not is_instance_valid(hand_container):
		print("Error: HandContainer invalid in update_hand_display for ", self.name)
		return

	clear_hand()
	for card_data in hand_data:
		var card = preload("res://scenes/Card.tscn").instantiate()
		card.set_data(card_data)
		add_card(card, card_data.get("is_face_up", false))
	print(self.name, " update_hand_display finished")

func arrange_hand():
	# Use the stored hand_container reference
	if not is_instance_valid(hand_container):
		print("Error: HandContainer invalid in arrange_hand for ", self.name)
		return
	print(self.name, " arrange_hand called. Current hand size: ", hand.size(), ". HandContainer children: ", hand_container.get_child_count() if is_instance_valid(hand_container) else "N/A")
	for i in range(hand.size()):
		var card = hand[i]
		# Ensure card is a valid instance and is a child of hand_container before setting z_index
		if is_instance_valid(card) and card.get_parent() == hand_container:
			card.z_index = i 
	pass
	print(self.name, " arrange_hand finished")
		
func clear_hand():
	print(self.name, " clear_hand called. Current hand size: ", hand.size())
	
	# Use the stored hand_container reference
	if not is_instance_valid(hand_container):
		print("Error: HandContainer invalid in clear_hand for ", self.name)
		return

	# Clear children directly from the valid hand_container reference
	for card in hand_container.get_children():
		card.queue_free()
	hand.clear()
	print(self.name, " clear_hand finished. New hand size: ", hand.size())

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
