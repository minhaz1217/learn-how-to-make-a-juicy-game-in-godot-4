extends GPUParticles2D

func _ready() -> void:
	emitting = true
	$BallExplosionParticles2.emitting = true
	$Timer.start(lifetime + 1.0)

func _on_timer_timeout() -> void:
	queue_free()
