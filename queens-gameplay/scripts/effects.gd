extends Node

# Animation durations
const BUTTON_HOVER_DURATION := 0.2
const BUTTON_PRESS_DURATION := 0.1
const CARD_MOVE_DURATION := 0.3
const TEXT_FADE_DURATION := 0.5

# Button effects
func add_button_effects(button: Control) -> void:
	button.mouse_entered.connect(func(): _on_button_hover(button, true))
	button.mouse_exited.connect(func(): _on_button_hover(button, false))
	button.pressed.connect(func(): _on_button_press(button))

func _on_button_hover(button: Control, is_hover: bool) -> void:
	var tween = create_tween()
	var scale = Vector2(1.1, 1.1) if is_hover else Vector2(1.0, 1.0)
	tween.tween_property(button, "scale", scale, BUTTON_HOVER_DURATION).set_trans(Tween.TRANS_ELASTIC)

func _on_button_press(button: Control) -> void:
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(0.9, 0.9), BUTTON_PRESS_DURATION)
	tween.tween_property(button, "scale", Vector2(1.0, 1.0), BUTTON_PRESS_DURATION)

# Card movement effects
func animate_card_move(card: Node2D, target_pos: Vector2) -> void:
	var tween = create_tween()
	tween.tween_property(card, "position", target_pos, CARD_MOVE_DURATION).set_trans(Tween.TRANS_ELASTIC)

# Text effects
func animate_text_fade(label: Label, text: String, duration: float = TEXT_FADE_DURATION) -> void:
	label.text = text
	label.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 1.0, duration)
	tween.tween_property(label, "modulate:a", 0.0, duration).set_delay(duration)

func animate_text_pop(label: Label, text: String) -> void:
	label.text = text
	label.scale = Vector2(0.5, 0.5)
	var tween = create_tween()
	tween.tween_property(label, "scale", Vector2(1.2, 1.2), 0.2)
	tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.2)

# Game event effects
func play_card_played_effect(card: Node2D) -> void:
	var tween = create_tween()
	tween.tween_property(card, "scale", Vector2(1.2, 1.2), 0.2)
	tween.tween_property(card, "scale", Vector2(1.0, 1.0), 0.2)

func play_win_effect(node: Node2D) -> void:
	var tween = create_tween()
	tween.tween_property(node, "scale", Vector2(1.5, 1.5), 0.5)
	tween.tween_property(node, "scale", Vector2(1.0, 1.0), 0.5) 
