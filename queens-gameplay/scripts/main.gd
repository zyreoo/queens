extends Node2D


var players = []
var shuffled_deck = []
var deck = []
var suits = ["♣️", "♠️", "♥️", "♦️"]
var ranks = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "A", "K", "J", "Q"]
var values = {"2": 2, "3": 3, "4": 4, "5": 5, "6": 6, "7": 7, "8": 8, "9": 9, "10": 10, "J": 11, "Q": 12, "K": 13, "A": 14}
	
	
	
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
	
	for i in range(4):
		var card_instance = preload("res://scenes/Card.tscn").instantiate()
		
		var card_str = shuffled_deck.pop_back()
		
		
		var card_parts = card_str.split(":")
		var card_suit = card_parts[0]
		var card_rank = card_parts[1]
		card_instance.suit = card_suit
		card_instance.rank = card_rank
		card_instance.value = values[card_rank]
		
		hand.append(card_instance)
		
		player_instance.add_card(card_instance)
		
	print("cards dealkt to the players!")
		
	
		
		
		
		
	
