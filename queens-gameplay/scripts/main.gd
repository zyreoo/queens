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
var game_started = false
var in_flip_phase = false
var flip_phase_index = 0
var flip_count = 0
var flipped_this_turn = 0

var allow_manual_flipping = true

func _ready():
	print("the main scene is ready")
	
	$StartGameButton.visible = true
	
	setup_players()
	initializate_center_card()
	
	
func initializate_center_card():
	var start_card_str = shuffled_deck.pop_back()
	var start_card_parts = start_card_str.split(":")
	center_card = preload("res://scenes/Card.tscn").instantiate()
	center_card.suit = start_card_parts[0]
	center_card.rank = start_card_parts[1]
	center_card.value = values[start_card_parts[1]]
	
	add_child(center_card)
	center_card.global_position = $CenterCardSlot.global_position
	center_card.flip_card()
	
	
func setup_players():
	var screen_size = get_viewport_rect().size
	var positions = [
		Vector2(screen_size.x /3, 50),
		Vector2(screen_size.x -100, screen_size.y /2),
		Vector2(screen_size.x/2, screen_size.y -100),
		Vector2(100, screen_size.y/2)
	]
	
	for i in range (2):
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

		players.append(player_instance)
		add_child(player_instance)
		player_instance.position = positions[i]
	

func deal_cards(player_instance):
	for j in range(4):
		var card = create_card_from_deck()
		player_instance.add_card(card, j <2 )

func next_turn():
	current_player_index = (current_player_index + 1) % players.size()
	print("Now it's Player %d's turn" % current_player_index)
	await give_and_hide_card(players[current_player_index])
	


func draw_card_for_current_player():
	if deck.size() == 0:
		deck = used_deck
		used_deck = []
		deck.shuffle()

	drawn_card = create_card_from_deck()
	drawn_card.flip_card()
	add_child(drawn_card)

	

func swap_card_with(clicked_card):
	var player = players[current_player_index]
	print("Swapping with card at index:", clicked_card.hand_index)
	
	player.hand[clicked_card.hand_index] = drawn_card
	
	clicked_card.queue_free()

	
	if drawn_card.get_parent():
		drawn_card.get_parent().remove_child(drawn_card)
	
	drawn_card.holding_player = player
	drawn_card.hand_index = clicked_card.hand_index
	
	
	player.add_child(drawn_card, false)
	
	if player.has_method("arrange_hand"):
		player.arrange_hand()
	
	

	print("Swapped in card:", drawn_card.rank, drawn_card.suit, "at index", drawn_card.hand_index)
	used_deck.append("%s:%s" % [clicked_card.suit, str(clicked_card.rank)])
	drawn_card = null
	swap_mode = false
	next_turn()
	
	
func play_card_to_center(card):
	
	if center_card and center_card.is_inside_tree():
		center_card.get_parent().remove_child(center_card)
		center_card.queue_free()
	
	center_card = card
	card.get_parent().remove_child(card)
		
	add_child(card)
	
	card.global_position = $CenterCardSlot.global_position
	
	card.set_process(false)
	card.set_mouse_filter(Control.MOUSE_FILTER_IGNORE)
	
	
	if not card.is_flipped:
		card.flip_card(true)
		
	if card.rank == "13":
		show_message("You played a King! Choose one of your cards to reveal.")
		allow_manual_flipping = true 

		await get_tree().create_timer(3.0).timeout 
		allow_manual_flipping = false
	
	next_turn()
		
		
func _on_start_game_button_pressed():
	game_started = false
	$StartGameButton.visible = false
	
	flip_phase_index = 0
	in_flip_phase = true
	flip_count = 0
	
	for player in players:
		for j in range(4):
			var card = create_card_from_deck()
			player.add_card(card,false)

		
func handle_initial_flip():
	for i in range(players.size()):
		flip_phase_index = i
		flip_count =0
		var flipped = 0
		for card in players[i].hand:
			if flipped < 2:
				card.flip_card(true)
				await get_tree().create_timer(0.6).timeout
				flipped += 1
		await get_tree().create_timer(0.5).timeout
			
	
func preview_initial_cards():
	for player in players:
		for j in range (2):
			var card_instance = preload("res://scenes/Card.tscn").instantiate()
			var card_str = shuffled_deck.pop_back()
			var card_parts = card_str.split(":")
			
			card_instance.suit = card_parts[0]
			card_instance.rank = card_parts[1]
			card_instance.value = values[card_parts[1]]
			
			var face_up = (player == players[current_player_index])
			player.add_card(card_instance, face_up)
			

func deal_remaining_cards(player):
	for j in range(2):
		var card_instance = preload("res://scenes/Card.tscn").instantiate()
		var card_str = shuffled_deck.pop_back()
		var card_parts = card_str.split(":")
		
		card_instance.suit = card_parts[0]
		card_instance.rank = card_parts[1]
		card_instance.value = values[card_parts[1]]
		
		player.add_card(card_instance, false)
		
		
func advance_flip_phase():
	flip_phase_index +=1
	flip_count = 0
	flipped_this_turn = 0
	
	if flip_phase_index < players.size():
		show_message("Player %d : flip cards" % (flip_phase_index +1))
	
	else:
		in_flip_phase = false
		
		await get_tree().create_timer(1.0).timeout
		hide_all_flipped_cards()
		current_player_index = 0
		game_started = true
		show_message("game starts! player 1's turn.")
		
func create_card_from_deck():
	if shuffled_deck.is_empty():
		print("deck empty")
		return null
		
	var card_str = shuffled_deck.pop_back()
	var card_parts = card_str.split(":")
	var card = preload("res://scenes/Card.tscn").instantiate()
	card.suit = card_parts[0]	
	card.rank = card_parts[1]
	card.value = values[card_parts[1]]
	return card
			
func give_and_hide_card(player):
	var card = create_card_from_deck()
	if card == null:
		print("deck is empty")
		return
		
	add_child(card)
	card.global_position = Vector2(600, 400)
	card.flip_card(true)
	
	await get_tree().create_timer(1.5).timeout
	
	player.add_card(card, false)
	
		
func show_message(text):
	$MessageLabel.text = text
	
	
func increment_flip_count():
	flip_count += 1
	if flip_count ==2:
		advance_flip_phase()
		
		
func hide_all_flipped_cards():
	for player in players:
		for card in player.hand:
			if is_instance_valid(card) and card.is_flipped:
				card.flip_card()
				
