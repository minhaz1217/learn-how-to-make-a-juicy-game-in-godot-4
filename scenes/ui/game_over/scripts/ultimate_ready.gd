extends Control


func _ready() -> void:
	$Shaker.start(1.5)
	scale = Vector2.ZERO
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.1,1.1), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(queue_free)
