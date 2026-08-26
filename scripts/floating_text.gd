extends Node2D

# Teks melayang naik lalu memudar (x3, x4, INSANE!, dst).

@onready var label: Label = $Label


func setup(text: String, color: Color, font_size: int) -> void:
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.reset_size()
	label.position = -label.size / 2.0

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:y", position.y - 34.0, 0.7)
	tw.tween_property(self, "modulate:a", 0.0, 0.7).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)
