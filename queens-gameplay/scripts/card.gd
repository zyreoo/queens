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


func _ready():
	
	var front_image_path = "res://assets/%s %s.png" % [suit, rank]
	front_texture = load(front_image_path)
	
	self.texture_normal = card_back_texture
	
	connect("pressed", Callable(self, "_on_card_clicked"))




func _on_card_clicked():
	var main = get_tree().get_root().get_node("Main")
	
	if main.in_flip_phase:
		if holding_player == main.players[main.flip_phase_index]:
			if not is_flipped and main.flip_count < 2:
				flip_card()
				main.increment_flip_count()
				
				if main.flip_count ==2:
					await get_tree().create_timer(1.0)
					main.advance_flip_phase()
		else:
			print("not your flip turn")
		return
		
	if not main.allow_manual_flipping:
		return
	if main.swap_mode and main.drawn_card != null:
		main.swap_card_with(self)
	else :
		flip_card()

	
	
func flip_card(force := false):
	var main = get_tree().get_root().get_node("Main")
	
	if force:
		is_flipped = true
		self.texture_normal = front_texture
		return
	
	
	
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

	if main.in_flip_phase and is_flipped and not force:
		main.increment_flip_count()
		
		
func _gui_input(event):
	var main = get_tree().get_root().get_node("Main")
	
	if main.in_flip_phase:
		return 

	if holding_player != main.players[main.current_player_index]:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging = true
		else:
			is_dragging = false

			var center = main.get_node("CenterCardSlot")
			var center_pos = center.global_position
		
			if global_position.distance_to(center_pos) < 150:
				main.play_card_to_center(self)
			else:
				if holding_player and holding_player.has_method("arrange_hand"):
					holding_player.arrange_hand
				
	if holding_player.hand.size() <= 1:
		print("You cant play your last card!")
		return
			
			
func _process(delta):
	if is_dragging:
		global_position = get_global_mouse_position()
		
	if holding_player and holding_player.hand.size() <= 1:
		is_dragging = false
		return 
		
			
			
func play_card_to_center(card):
	if card.get_parent():
		card.get_parent().remove_child(card)
		
	add_child(card)
	card.flip_card()
	card.global_position  = $CenterCardSlot.global_position
	card.set_process(false)

	
		
