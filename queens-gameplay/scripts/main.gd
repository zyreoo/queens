extends Node2D

@onready var ip_field = $IPField

var players = []
var shuffled_deck = []
var deck = []
var used_deck = []
var current_player_index = 0
var suits = ["Clubs", "Spades", "Diamonds", "Hearts"]
var ranks = ["1","2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "13", "12"]
var values = {"1":1 ,"2": 2, "3": 3, "4": 4, "5": 5, "6": 6, "7": 7, "8": 8, "9": 9, "10": 10, "11": 11, "12": 12, "13": 13}
var drawn_card = null 
var swap_mode = false
var center_card = null
var game_started = false
var in_flip_phase = false
var flip_phase_index = 0
var flip_count = 0
var flipped_this_turn = 0
var jack_swap_mode = false
var awaiting_king_reveal = false
var jack_swap_timer = null
var jack_swap_selection = {
	"from" : null,
	"to" : null
}

var reaction_mode = false
var reaction_value = null
var reacting_players = []

var allow_manual_flipping = true

var queens_triggered := false
var queens_player_index := -1
var final_turns_remaining := 0
var final_round_active := false
var final_turn_count := 0
var final_round_count :=0
var queens_caller_index = null
var turn_advanced_this_frame = false

var peer: WebSocketMultiplayerPeer

var local_peer_id := -1

func _ready():
	print("the main scene is ready")
	
	$StartGameButton.visible = true
	$queens.visible = true
	
	local_peer_id = multiplayer.get_unique_id()
	
	setup_players()
	multiplayer.peer_connected.connect(func(id): print("connected:", id))
	multiplayer.connected_to_server.connect(func(): print("connected to server"))
	multiplayer.connection_failed.connect(func(): print("Connection failed"))
	multiplayer.server_disconnected.connect(func(): print("Server disconnected"))
	
	
func _on_host_button_pressed():
	peer = WebSocketMultiplayerPeer.new()
	var error = peer.create_server(12345, "0.0.0.0")
	if error != OK:
		print("Failed to start server", error)
		return
	multiplayer.multiplayer_peer = peer
	print("Hosting on port 12345")
	
func _on_join_game_pressed():
	var ip = ip_field.text.strip_edges()
	if ip == "": ip = "127.0.0.1"
	peer = WebSocketMultiplayerPeer.new()
	var error = peer.create_client("ws://" + ip+ ":12345")
	if error != OK:
		print("connection failed:", error)
		return
	multiplayer.multiplayer_peer = peer
	print("Connecting to", ip)
	
func _on_start_game_button_pressed():
	if game_started:
		print("game already started")
		return
	
	if multiplayer.is_server():
		await _wait_for_peers_ready()
		_start_game_server()
		
func _wait_for_peers_ready():
	var expected = multiplayer.get_peers().size() +1
	var timeout = 0.5
	var start_time = Time.get_ticks_msec()
	
	while get_tree().get_nodes_in_group("players").size() < expected:
		await get_tree().process_frame
		
		if Time.get_ticks_msec() - start_time > timeout *1000:
			print("Not all players ready")
			break
@rpc("authority")
func _start_game_server():
	if game_started:
		print("already started")
		return
		
	game_started = true
	
	_create_players()
	_shuffle_deck()

	for i in range(players.size()):
		var cards = []
		for j in range(4):
			var card_str = deck.pop_back()
			cards.append(card_str)
		rpc_id(players[i].peer_id, "_receive_initial_hand", cards)

	var center_card_str = deck.pop_back()
	rpc("_set_center_card", center_card_str)
	current_player_index = 0
	rpc("_set_turn", current_player_index)

func _create_players():
	players.clear()
	var screen_size = get_viewport_rect().size
	var positions = [
		Vector2(screen_size.x / 2, 100),
		Vector2(screen_size.x - 100, screen_size.y / 2),
		Vector2(screen_size.x / 2, screen_size.y - 200),
		Vector2(100, screen_size.y / 2)
	]
	var peer_ids = multiplayer.get_peers()
	peer_ids.append(multiplayer.get_unique_id())


	var i = 0
	for peer_id in multiplayer.get_peers():
		var player_scene = preload("res://scenes/Player.tscn")
		var p = player_scene.instantiate()
		add_child(p)
		p.position = positions[i]
		p.rotation_degrees = [0, 90, 180, -90][i]
		p.peer_id = peer_id
		players.append(p)
		
func _shuffle_deck():
	deck.clear()
	for suit in suits:
		for rank in ranks:
			deck.append("%s:%s" % [suit, rank])
	deck.shuffle()
	
func initializate_center_card():
	var start_card_str = shuffled_deck.pop_back()
	var start_card_parts = start_card_str.split(":")
	center_card = preload("res://scenes/Card.tscn").instantiate()
	center_card.suit = start_card_parts[0]
	center_card.rank = start_card_parts[1]
	center_card.value = values[start_card_parts[1]]
	
	center_card.permanent_face_up = true
	
	add_child(center_card)
	center_card.global_position = $CenterCardSlot.global_position
	center_card.flip_card(true)
	
	
func setup_players():
	var screen_size = get_viewport_rect().size
	var positions = [
		Vector2(screen_size.x /2, 100),
		Vector2(screen_size.x - 100, screen_size.y /2),
		Vector2(screen_size.x/2, screen_size.y -200),
		Vector2(100, screen_size.y/2)
	]
	deck.clear()
	for i in range (2):
		for suit in suits:
			for rank in ranks:
				deck.append("%s:%s" % [suit, rank])
		shuffled_deck = deck.duplicate()
		shuffled_deck.shuffle()
	
	
	for i in range (4):
		var player_scene = preload("res://scenes/Player.tscn")
		var player_instance = player_scene.instantiate()
		players.append(player_instance)
		add_child(player_instance)
		player_instance.position = positions[i]
		
		match i:
			0: player_instance.rotation_degrees = 0
			1: player_instance.rotation_degrees = 90
			2:player_instance.rotation_degrees = 180
			3:player_instance.rotation_degrees = -90
		player_instance.set_multiplayer_authority(multiplayer.get_unique_id())
		player_instance.player_id = i
		player_instance.peer_id = multiplayer.get_unique_id()
	

func deal_cards(player_instance):
	for j in range(4):
		var card = create_card_from_deck(player_instance)
		player_instance.add_card(card, j <2 )

func next_turn():
	turn_advanced_this_frame = false
	current_player_index = (current_player_index + 1) % players.size()
	
	if final_round_active and current_player_index == queens_player_index:
		calculate_finbal_score()
		return
	if final_round_active:
		final_round_count +=1
		
		if final_turn_count>= players.size():
			await get_tree().create_timer(2.0).timeout
			calculate_finbal_score()
			return
	print("Now it's Player %d's turn" % current_player_index)
	await give_and_hide_card(players[current_player_index])
	
	
	


func draw_card_for_current_player():
	if deck.size() == 0:
		deck = used_deck
		used_deck = []
		deck.shuffle()

	var current_player = players[current_player_index]
	drawn_card = create_card_from_deck(current_player)
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
	
@rpc("authority")
func play_card_to_center(card):
	var is_current_players_turn = card.holding_player == players[current_player_index]
	var was_current_player = is_current_players_turn
	
	if not reaction_mode and not is_current_players_turn:
		show_message("not ur turn")
		return
	
	if reaction_mode and card.value != reaction_value:
		show_message("invalid card")
		
		var p = card.holding_player
		if p != null:
			if card.get_parent():
				card.get_parent().remove_child(card)
			
			p.add_child(card)
			if not p.hand.has(card):
				p.hand.append(card)
			p.arrange_hand()
			await get_tree().create_timer(0.5).timeout
			give_penalty_card(p)
		return

	if  center_card and center_card.is_inside_tree():
		center_card.get_parent().remove_child(center_card)
		used_deck.append("%s:%s" % [center_card.suit, center_card.rank])
		center_card.queue_free()
		
	center_card = card
	
	if card.holding_player:
		var index = card.hand_index
		if index >= 0 and index < card.holding_player.hand.size():
			card.holding_player.hand.remove_at(index)
			card.holding_player.arrange_hand()
			
			
	if card.get_parent():
		card.get_parent().remove_child(card)
	add_child(card)
	
	card.rotation_degrees = 0
	card.global_position = $CenterCardSlot.global_position
	card.set_process(false)
	card.set_mouse_filter(Control.MOUSE_FILTER_IGNORE)
	card.flip_card(true)
	
	if card.rank == "13":
		show_message("You played a King! Choose one of your cards to reveal.")
		allow_manual_flipping = true 
		awaiting_king_reveal = true

		await get_tree().create_timer(3.0).timeout 
		allow_manual_flipping = false
		awaiting_king_reveal = false
		if was_current_player:
			next_turn()
		return
		
	elif card.rank == "11":
		show_message("you played a jack! you can swap in within 4 seconds")
		jack_swap_mode = true
		jack_swap_selection["from"] = null
		jack_swap_selection["to"] = null
		jack_swap_timer = get_tree().create_timer(4.0)
		await jack_swap_timer.timeout
		if jack_swap_mode:
			jack_swap_mode = false
			show_message("timeout")
			next_turn()
		return
		
	if card.rank == "12":
		show_message("you played a queen")
		var next_player_index = (current_player_index + 1) % players.size()
		var next_player = players[next_player_index]
		
		if card.get_parent():
			card.get_parent().remove_child(card)
		
		next_player.add_card(card, false)
		await get_tree().create_timer(0.8).timeout
		next_turn()
		return 
			
	if card.rank not in ["11", "12", "13"]:
		reaction_value = card.value
		reaction_mode = true
		reacting_players.clear()
		show_message("match")
		
		await get_tree().create_timer(3.0).timeout
		reaction_mode = false
		reaction_value = null
		
		show_message("reaction window closed.")
		
		if was_current_player:
			next_turn()
		return
		
	if was_current_player:
		next_turn()
	
@rpc("any_peer")
func start_turn(index):
	current_player_index = index
	show_message("Player %d turn " % (index+1))
		
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
		
		initializate_center_card()
		await give_and_hide_card(players[current_player_index])


func create_card_from_deck(player: Node = null):
	if shuffled_deck.is_empty():
		print("deck empty")
		return null
		
	var card_str = shuffled_deck.pop_back()
	var card_parts = card_str.split(":")
	var card = preload("res://scenes/Card.tscn").instantiate()
	card.suit = card_parts[0]
	card.rank = card_parts[1]
	card.value = values[card_parts[1]]
	if player:
		card.set_multiplayer_authority(player.peer_id)
	else:
		card.set_multiplayer_authority(1)
		
	return card


@rpc("authority")
func give_and_hide_card(player):
	var card = create_card_from_deck(player)
	if card == null:
		print("deck is empty")
		return
	
	add_child(card)
	card.global_position = Vector2(600,400)
	card.flip_card(true)
	
	await get_tree().create_timer(1.5).timeout
	
	card.flip_card(false)
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
				
	if is_instance_valid(center_card):
		center_card.flip_card(true)
				
func execute_jack_swap():
	jack_swap_mode = false
	var from_card = jack_swap_selection["from"]
	var to_card = jack_swap_selection["to"]
	if from_card == null or to_card==null:
		return
		
	from_card.modulate = Color(1,1,1)
	to_card.modulate = Color(1,1,1)
	
	var from_player = from_card.holding_player
	var to_player = to_card.holding_player
	var from_index = from_card.hand_index
	var to_index = to_card.hand_index
	
	from_player.hand[from_index] = to_card
	to_player.hand[to_index] = from_card
	
	to_card.holding_player = from_player
	to_card.hand_index = from_index
	
	from_card.holding_player = to_player
	from_card.hand_index = to_index
	
	if from_card.get_parent():
		from_card.get_parent().remove_child(from_card)
	if to_card.get_parent():
		to_card.get_parent().remove_child(to_card)
	
	from_player.add_child(to_card)
	to_player.add_child(from_card)
	
	from_player.arrange_hand()
	to_player.arrange_hand()
	
	show_message("swap done")
	await get_tree().create_timer(1.0).timeout
	next_turn()
	
func give_penalty_card(player):
	var card = create_card_from_deck(player)
	if card:
		player.add_card(card, false)
	
func calculate_finbal_score():
	game_started = false
	var scores: Array = []
	var total_other_scores = 0
	var lowest_score = INF
	var queens_score = 0
	
	
	for i in range(players.size()):
		var player = players[i]
		var hand_score = 0
		
		for card in player.hand:
			if not is_instance_valid(card):
				continue 
		
			match card.rank:
				"12" : hand_score += 0
				"1" : hand_score +=1 
				"11", "13" : hand_score += 10
				_ : 
					hand_score += int(card.rank)
				
		player.score = hand_score
		scores.append(hand_score)
		
		if i == queens_player_index:
			queens_score = hand_score
		else:
			total_other_scores += hand_score
			
		if hand_score < lowest_score:
			lowest_score = hand_score
	
	await get_tree().create_timer(1.0).timeout
	
	if queens_score == lowest_score:
		show_message("player %d wins" % (queens_player_index +1))
	
	else:
		show_message("Player %d called Queens but ddnt  have the lowest score.\nThey get all other players points: %d" % [queens_player_index + 1, total_other_scores])
		players[queens_player_index].score = total_other_scores
		for i in range (players.size()):
			if i != queens_player_index:
				players[i].score = 0
	
	await get_tree().create_timer(2.0).timeout
	show_message("Game over")

func _on_queens_pressed():
	final_round_active = true
	queens_player_index = current_player_index
	
	$queens.disabled = true
	print("Current player index when Queens pressed: ", current_player_index)
	print("Queens player index set to: ", queens_player_index)

@rpc("any_peer", "reliable")
func _receive_initial_hand(cards: Array):
	var local_player = _find_local_player()
	
	if local_player == null:
		await get_tree().create_timer(0.5).timeout
		local_player = _find_local_player()
		if local_player == null:
			print("Couldnt find local player!")
			return
			
	for i in range(cards.size()):
		var card_str = cards[i]
		var parts = card_str.split(":")
		if parts.size() != 2:
			print("Invalid card format:", card_str)
			continue
		
		var card = preload("res://scenes/Card.tscn").instantiate()
		card.suit = parts[0]
		card.rank = parts[1]
		card.value = values[parts[1]]
		
		var is_local = local_player.peer_id == multiplayer.get_unique_id()
		var should_flip = i < 2 and is_local
		
		local_player.add_card(card, should_flip)
		

@rpc("any_peer", "reliable")
func _set_center_card(card_str: String):
	if center_card:
		center_card.queue_free()

	var parts = card_str.split(":")
	center_card = preload("res://scenes/Card.tscn").instantiate()
	center_card.suit = parts[0]
	center_card.rank = parts[1]
	center_card.value = values[parts[1]]
	center_card.permanent_face_up = true
	add_child(center_card)
	center_card.global_position = $CenterCardSlot.global_position
	center_card.flip_card(true)

@rpc("any_peer", "reliable")
func _set_turn(index: int):
	current_player_index = index

func _find_local_player():
	for p in get_tree().get_nodes_in_group("players"):
		if p.peer_id == multiplayer.get_unique_id():
			return p
	return null
