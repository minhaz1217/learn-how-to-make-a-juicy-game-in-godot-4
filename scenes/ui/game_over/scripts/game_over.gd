extends Control

signal retry()

func _ready() -> void:
	$VBoxContainer/RetryBtn.grab_focus()

func _on_RetryBtn_pressed() -> void:
	emit_signal("retry")
	queue_free()

func _on_QuitBtn_pressed() -> void:
	get_tree().quit()


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "appear":
		$AnimationPlayer.play("wiggle")
