extends Node2D


var players = []
var shuffled_deck = []
var deck = []
var used_deck = []
var current_player_index = 0
var suits = ["Clubs", "Spades", "Diamonds", "Hearts"]
var ranks = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "13", "12", "14"]
var values = {"2": 2, "3": 3, "4": 4, "5": 5, "6": 6, "7": 7, "8": 8, "9": 9, "10": 10, "11": 11, "12": 12, "13": 13, "14": 14}
	
	
	
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
			
func deal_cards(player_instance):
	var hand = []
	
	for j in range(4):
		var card_instance = preload("res://scenes/Card.tscn").instantiate()
		
		var card_str = shuffled_deck.pop_back()
		
		
		var card_parts = card_str.split(":")
		var card_suit = card_parts[0]
		var card_rank = card_parts[1]
		card_instance.suit = card_suit
		card_instance.rank = card_rank
		card_instance.value = values[card_rank]
		
		var face_up = j < 2
		
		hand.append(card_instance)
		
		player_instance.add_card(card_instance, face_up)
		
	print("cards dealkt to the players!")
	
	
func next_turn():
	current_player_index = (current_player_index+1) %players.size()
	print("Now it's Player %d's turn" % current_player_index)
	
	
func _on_draw_card_button_pressed():
	print("button pressed!")
	draw_card_for_current_player()

func draw_card_for_current_player():
	if deck.size() == 0:
		deck = used_deck
		used_deck = []
		deck.shuffle()
		
	@warning_ignore("unused_variable")
	var player = players[current_player_index]
	
	var card_instance = preload("res://scenes/Card.tscn").instantiate()
		
	var card_str = deck.pop_back()
		
		
	var card_parts = card_str.split(":")
	var card_suit = card_parts[0]
	var card_rank = card_parts[1]
	card_instance.suit = card_suit
	card_instance.rank = card_rank
	card_instance.value = values[card_rank]
	
	card_instance.flip_card()
	add_child(card_instance)
	card_instance.position = Vector2(600, 400)
	
	used_deck.append(card_str)
	
	next_turn()
	
