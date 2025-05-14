extends TextureButton


@export var suit: String
@export var rank: String
@export var value: int

var card_back_texture = preload("res://assets/Card Back 3.png")
var front_texture : Texture = null
var is_flipped = false
var holding_player : Node = null
var hand_index = -1
var is_dragging = false
var drag_offset = Vector2()

func _ready():
	
	var front_image_path = "res://assets/%s %s.png" % [suit, rank]
	front_texture = load(front_image_path)
	self.texture_normal = card_back_texture
	connect("pressed", Callable(self, "_on_card_clicked"))




func _on_card_clicked():
	var main = get_tree().get_root().get_node("Main")
	
	if is_dragging or (not main.allow_manual_flipping and not main.in_flip_phase):
		return
		
	if is_flipped and not main.in_flip_phase:
		return
	
	#if multiplayer.get_unique_id() != get_multiplayer_authority():
		#return
		
	#rpc("rpc_flip_card")
	
	if main.jack_swap_mode:
		if main.jack_swap_selection["from"] == null:
			main.jack_swap_selection["from"] = self
			self.modulate = Color(1, 1, 0.5)
			main.show_message("selected the first card to swap")
			return
		elif main.jack_swap_selection["to"] == null:
			if self == main.jack_swap_selection["from"]:
				return
			
			main.jack_swap_selection["to"] = self
			self.modulate = Color(1, 1, 0.5)
			main.show_message("swapping cards..")
			main.execute_jack_swap()
			return
		 
	
	if main.in_flip_phase:
		if holding_player == main.players[main.flip_phase_index] and not is_flipped and main.flip_count <2:
			flip_card(true)
			main.increment_flip_count()
			return
		else:
			print("not your flip turn")
			return
		
	if main.swap_mode and main.drawn_card != null:
		main.swap_card_with(self)
		return
		
	if main.allow_manual_flipping and main.awaiting_king_reveal and not is_flipped:
		flip_card(true)
		main.awaiting_king_reveal = false
		main.allow_manual_flipping = false
		return
		
	if not main.allow_manual_flipping and not main.in_flip_phase and not main.jack_swap_mode:
		return
	
	if main.reaction_mode:
		if holding_player == main.players[main.current_player_index]:
			return
		
		if holding_player in main.reacting_players:
			return
		
		main.reacting_players.append(holding_player)
		
		if value == main.reaction_value:
			main.play_card_to_center(self)
			
		else:
			var player = holding_player
			if player:
				main.show_message("penalty card")
				
				if self.get_parent() != player:
					self.get_parent().remove_child(self)
					player.add_child(self)
					
				if not player.hand.has(self):
					player.hand.append(self)
					
				self.holding_player = player
				self.hand_index = player.hand.size() - 1 
				
				self.modulate = Color(1,1,1)
				self.rotation_degrees = player.rotation_degrees
				
				player.arrange_hand()
				
				await get_tree().create_timer(0.5).timeout
				
				main.give_penalty_card(player)
			return 
				
		return
func flip_card(state := false):
	var main = get_tree().get_root().get_node("Main")
	
	if state != null:
		is_flipped = state
	else:
		is_flipped = !is_flipped
		
	self.texture_normal = front_texture if is_flipped else card_back_texture

	

	
	if not main.allow_manual_flipping and not main.in_flip_phase:
		return
		

	if main.in_flip_phase:
		if holding_player != main.players[main.flip_phase_index]:
			print("Not ur turn to flip")
			return
			
		if is_flipped:
			print("Already flipped")
			return
			
		if main.flip_count >= 2:
			return
			
	is_flipped = true
	self.texture_normal = front_texture
	main.flip_count +=1
	
	if main.allow_manual_flipping and is_flipped:
		await get_tree().create_timer(3.0).timeout
		is_flipped = false
		self.texture_normal = card_back_texture

	if main.in_flip_phase and is_flipped:
		main.increment_flip_count()
		
		
func _gui_input(event):
	var main = get_tree().get_root().get_node("Main")
	
	if main.in_flip_phase:
		return 
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging = true
			drag_offset = global_position - event.global_position
		else:
			is_dragging = false
			
			
			var center = main.get_node("CenterCardSlot")
			
			if center == null:
				print("CenterCardSlot not found")
				return
			
			var center_pos = center.global_position
			
			if global_position.distance_to(center_pos) < 350:
				main.play_card_to_center(self)
			else:
				if holding_player and holding_player.has_method("arrange_hand"):
					holding_player.arrange_hand()
		
	if holding_player != null and holding_player.hand.size() <=1:
		main.show_message("you cant play this card")

func _process(delta):
	if is_dragging:
		global_position = get_global_mouse_position() + drag_offset
		
	if holding_player and holding_player.hand.size() <= 1:
		is_dragging = false
		return 
		
