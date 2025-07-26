extends GPUParticles2D


func _ready() -> void:
	$Timer.start(lifetime + 1.0)
	emitting = true

func _on_timer_timeout() -> void:
	queue_free()
