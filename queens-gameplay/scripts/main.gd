extends Node2D

var players = []
var shuffled_deck = []
var deck = []
var used_deck = []
var current_player_index = 0
var suits = ["Clubs", "Spades", "Diamonds", "Hearts"]
var ranks = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "13", "12", "14"]
var values = {"2": 2, "3": 3, "4": 4, "5": 5, "6": 6, "7": 7, "8": 8, "9": 9, "10": 10, "11": 11, "12": 12, "13": 13, "14": 14}

var drawn_card = null 
var swap_mode = false
var center_card = null

func _ready():
	print("the main scene is ready")

	var screen_size = get_viewport_rect().size
	var positions = [
		Vector2(screen_size.x /2, 50),
		Vector2(screen_size.x -100, screen_size.y /2),
		Vector2(screen_size.x/2, screen_size.y -100),
		Vector2(100, screen_size.y/2)
	]
	

	for suit in suits:
		for rank in ranks:
			deck.append("%s:%s" % [suit, rank])
	shuffled_deck = deck.duplicate()
	shuffled_deck.shuffle()

	for i in range(4):
		var player_scene = preload("res://scenes/Player.tscn")
		var player_instance = player_scene.instantiate()
		
		match i:
			0: player_instance.rotation_degrees = 180
			1: player_instance.rotation_degrees = -90
			2:player_instance.rotation_degrees = 0
			3:player_instance.rotation_degrees = 90

		if player_instance:
			players.append(player_instance)
			add_child(player_instance)
			player_instance.position = positions[i]
			match i:
				0: player_instance.rotation_degrees = 180
				1: player_instance.rotation_degrees = -90
				2: player_instance.rotation_degrees = 0
				3: player_instance.rotation_degrees = 90
			deal_cards(player_instance)
			
	place_start_card()
			
			

func deal_cards(player_instance):
	for j in range(4):
		var card_instance = preload("res://scenes/Card.tscn").instantiate()
		var card_str = shuffled_deck.pop_back()
		var card_parts = card_str.split(":")
		card_instance.suit = card_parts[0]
		card_instance.rank = card_parts[1]
		card_instance.value = values[card_parts[1]]
		
		var face_up = j < 2
		player_instance.add_card(card_instance, face_up)

func next_turn():
	current_player_index = (current_player_index + 1) % players.size()
	print("Now it's Player %d's turn" % current_player_index)

func _on_draw_card_button_pressed():
	print("button pressed!")
	draw_card_for_current_player()
	
	
func _on_discard_button_pressed():
	if drawn_card == null:
		print("No card to discard")
		return

	print("Discarding: %s%s " % [drawn_card.rank, drawn_card.suit])

	used_deck.append("%s:%s" % [drawn_card.suit, drawn_card.rank])

	remove_child(drawn_card)
	drawn_card.queue_free()
	drawn_card = null 

	next_turn()


func draw_card_for_current_player():
	if deck.size() == 0:
		deck = used_deck
		used_deck = []
		deck.shuffle()

	var card_str = deck.pop_back()
	var card_parts = card_str.split(":")
	drawn_card = preload("res://scenes/Card.tscn").instantiate()
	drawn_card.suit = card_parts[0]
	drawn_card.rank = card_parts[1]
	drawn_card.value = values[card_parts[1]]
	drawn_card.flip_card()
	add_child(drawn_card)

func _on_swap_button_pressed():
	if drawn_card == null:
		print("Nothing to swap")
		return
	swap_mode = true
	print("Swap activated")
	

func place_start_card():
	if deck.size() == 0:
		deck = used_deck
		used_deck =[]
		deck.shuffle()
		
	var card_instance = preload("res://scenes/Card.tscn").instantiate()
	var card_str = deck.pop_back()
	var card_parts = card_str.split(":")
	card_instance.suit = card_parts[0]
	card_instance.rank = card_parts[1]
	card_instance.value = values[card_parts[1]]
	card_instance.flip_card()
	card_instance.position = Vector2(600, 300)
	
	card_instance.flip_card()
	
	print(card_instance)
	add_child(card_instance)
	used_deck.append(card_str)
	

func swap_card_with(clicked_card):
	var player = players[current_player_index]
	print("Swapping with card at index:", clicked_card.hand_index)
	
	player.hand[clicked_card.hand_index] = drawn_card
	
	clicked_card.queue_free()

	
	if drawn_card.get_parent() != null:
		drawn_card.get_parent().remove_child(drawn_card)
	
	drawn_card.holding_player = player
	drawn_card.hand_index = clicked_card.hand_index
	
	
	player.add_child(drawn_card)
	
	if player.has_method("arrange_hand"):
		player.arrange_hand()
	
	

	print("Swapped in card:", drawn_card.rank, drawn_card.suit, "at index", drawn_card.hand_index)
	used_deck.append("%s:%s" % [clicked_card.suit, str(clicked_card.rank)])
	drawn_card = null
	swap_mode = false
	next_turn()
	
	
func play_card_to_center(card):
	
	
	if center_card and center_card.is_inside_tree():
		remove_child(center_card)
		center_card.queue_free()
	
	center_card = card
	remove_child(card)
	add_child(card)
	
	card.global_position = $CenterCardSlot.global_position
	
	card.set_process(false)
	card.set_mouse_filter(Control.MOUSE_FILTER_IGNORE)
	if not card.is_flipped:
		card.flip_card()
	
