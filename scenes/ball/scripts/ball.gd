extends CharacterBody2D

signal hit_block(block)

@export var bump_timing_scene: PackedScene = preload("res://scenes/effects/bump/bump_timing.tscn")
@export var bounce_particle_scene : PackedScene = preload("res://scenes/ball/bounce_particles.tscn")
@export var bump_particle_scene : PackedScene = preload("res://scenes/ball/bump_particles.tscn")
@export var explode_particle_scene : PackedScene = preload("res://scenes/ball/ball_explosion_particles.tscn")

@export var speed: float = 400.0
@export var accel: float = 20.0
@export var deccel: float = 3.0
@export var max_normal_angle: float = 15.0
@export var max_speed: float = 1600.0
@export var steering_max_speed: float = 1200.0
@export var steer_force = 110.0
@export var steer_speed = 300.0
@export var max_speed_color: Color
var acceleration: Vector2 = Vector2.ZERO
var attached_to = null
var hit_count: int = 0
var frame_count: int = 0
var no_collision_frame: int = 4
var attracted: bool = false
var attracted_to = null
var frames_since_paddle_collison: int = 0
var max_bump_distance: float = 40.0
var boost_factor_base : float = 1.15
var boost_factor: float = 1.0
var boost_factor_perfect: float = 1.3
var boost_factor_late_early: float = 1.15

@onready var animation_player = $AnimationPlayer
@onready var sprite = $Sprite2D
@onready var sprite_base_scale : Vector2 = sprite.scale

# HitStop
var hitstop_frame = 0
var hitstop_bump_late_early = 5
var hitstop_bump_perfect = 10
var hitstop_paddle = 5
var hitstop_block = 5
var hitstop_bomb = 10


func _ready() -> void:
	randomize()
func _process(delta):
	scale_based_on_velocity()
	color_based_on_velocity()
	
	
func _physics_process(delta: float) -> void:
	
	if hitstop_frame > 0:
		hitstop_frame -= 1
		if hitstop_frame <= 0:
			stop_hitstop()
		return
	
	$VelocityLine.rotation = velocity.angle()
	frames_since_paddle_collison += 1
	
	velocity = lerp(velocity, velocity.limit_length(speed), deccel * delta)
	
	if attached_to:
		global_position = attached_to.global_position
		return
		
	if attracted:
		var steer = Vector2.ZERO
		var desired = (attracted_to - position).normalized() * steer_speed
		steer = (desired - velocity).normalized() * steer_force
		acceleration += steer
		velocity += acceleration * delta
		velocity = velocity.limit_length(steering_max_speed)
#		rotation = velocity.angle()
	
	# Reset every frame to make sure we only attract
	# when pressing the button
	attracted = false
	var velocity_before_collision = velocity
	var collision = move_and_collide(velocity * delta)
	if not collision: return
	Globals.stats["ball_bounces"] += 1
	
	var normal = collision.get_normal()
	sprite.rotation = -normal.angle()
	animation_player.play("bounce")
	# Update the normal with the paddle's velocity if we collide with
	# the paddle
	if collision.get_collider().is_in_group("Paddle"):
		frames_since_paddle_collison = 0
#		print("Normal:", normal)
#		print("Dot:", normal.dot(Vector2.UP))
		spawn_bump_particles(collision.get_position(), normal)
		
		if boost_factor == 1.0:
			start_hitstop(hitstop_paddle)
		
		# Collision from the top, most of the cases
		if normal.dot(Vector2.UP) > 0.0:
#			print("HIT TOP: ", Globals.stats["ball_bounces"])
			
			# Paddle is moving
			if collision.get_collider().velocity.length() > 0:
				var length_before_collison = velocity.length()
				
				velocity.y = -velocity.y
				velocity.x += collision.get_collider().velocity.x * 0.6
				velocity = velocity.normalized()
				velocity *= length_before_collison
				velocity *= (boost_factor + boost_factor_base)
			else:
				## Tilt the normal near the edge
				# Calculate the distance between the collision point and the center of the paddle
				var distance = collision.get_position() - collision.get_collider().global_position
				var amount = distance.x/96.0
				normal = normal.rotated(deg_to_rad(max_normal_angle)*amount)
				velocity = velocity.bounce(normal)*(boost_factor + boost_factor_base)
		else:
#			print("HIT SIDE: ", Globals.stats["ball_bounces"])
			# Check if below half of the thickness
			if collision.get_position().y > collision.get_collider().global_position.y:
#				print("BELOW HALF")
				velocity = velocity.bounce(normal)*(boost_factor + boost_factor_base)
			else:
				# Lateral normal respecting the sign checked the collision
				normal = Vector2(sign(normal.x), 0)
				# Rotate the normal upward
				var normal_rotated = normal.rotated(-sign(normal.x)*deg_to_rad(20.0))
				
				# Create the new velocity using the velocity length and the normal direction
				velocity = normal_rotated * velocity.length()
				velocity *= (boost_factor + boost_factor_base)
		# Reset bump boost
		boost_factor = 1.0
	elif collision.get_collider().is_in_group("Bricks"):
		if collision.get_collider().type == collision.get_collider().TYPE.ENERGY or \
			collision.get_collider().type == collision.get_collider().TYPE.EXPLOSIVE:
			velocity = velocity_before_collision
			start_hitstop(hitstop_bomb)
		else:
			velocity = velocity.bounce(normal)
			start_hitstop(hitstop_block)
	else:
#		print("HIT OTHER: ", Globals.stats["ball_bounces"])
		spawn_bounce_particles(collision.get_position(), normal)
		velocity = velocity.bounce(normal)
	
	velocity = velocity.limit_length(max_speed)
	
	if collision.get_collider().is_in_group("Bricks"):
		collision.get_collider().damage(1)
		emit_signal("hit_block", collision.get_collider())
		
#### Visuals ####
func appear() -> void:
	animation_player.play("RESET")
	animation_player.play("appear")

func die() -> void:
	spawn_explode_particles(global_position)

func scale_based_on_velocity() -> void:
	if animation_player.is_playing(): return
	sprite.scale = lerp( sprite_base_scale, sprite_base_scale * Vector2(1.4,.5), velocity.length()/max_speed)
	sprite.rotation = velocity.angle()

func color_based_on_velocity() -> void:
	var val = remap(velocity.length(), speed, max_speed, 0, 1.0)
	sprite.self_modulate = lerp(Color.WHITE, max_speed_color, val)
	$Trail2D.self_modulate = lerp(Color.WHITE, max_speed_color, val)

func spawn_bounce_particles(pos: Vector2, normal: Vector2) -> void:
	var instance = bounce_particle_scene.instantiate()
	get_tree().get_current_scene().add_child(instance)
	instance.global_position = pos
	instance.rotation = normal.angle()

func spawn_bump_particles(pos: Vector2, normal: Vector2) -> void:
	var instance = bump_particle_scene.instantiate()
	get_tree().get_current_scene().add_child(instance)
	instance.global_position = pos
	instance.rotation = normal.angle()
	
func spawn_explode_particles(pos: Vector2) -> void:
	var instance = explode_particle_scene.instantiate()
	get_tree().get_current_scene().add_child(instance)
	instance.global_position = pos

func start_hitstop(hitstop_amount : int) -> void:
	animation_player.pause()
	hitstop_frame = hitstop_amount
	
func stop_hitstop() -> void:
	animation_player.play()
	hitstop_frame = 0


func attract(global_position) -> void:
	attracted = true
	attracted_to = global_position
	
func spawn_bump_timing(type) -> void:
	var instance = bump_timing_scene.instantiate()
	instance.type = type
	get_parent().add_child(instance)
	instance.global_position = global_position
	
func bump_boost(who) -> void:
	var distance = who.global_position.distance_to(global_position)
	var contact_distance = distance - $CollisionShape2D.shape.radius - (who.thickness / 2.0)
	
	# If we're too far, we don't bump
	if contact_distance > max_bump_distance: 
		print("BUMP TOO FAR")
		boost_factor = 1.0
		spawn_bump_timing(Globals.BUMP.TOO_FAR)
		return
	
	# We had a collision recently and we're now boosting: LATE
	if frames_since_paddle_collison > 5 and frames_since_paddle_collison < 20:
		print("BUMP LATE")
		boost_factor = boost_factor_late_early
		Globals.stats["bumps_late"] += 1
		spawn_bump_timing(Globals.BUMP.LATE)
		start_hitstop(hitstop_bump_late_early)
	
	# Bump perfect
	elif frames_since_paddle_collison < 5:
		print("BUMP PERFECT")
		boost_factor = boost_factor_perfect
		Globals.stats["bumps_perfect"] += 1
		spawn_bump_timing(Globals.BUMP.PERFECT)
		start_hitstop(hitstop_bump_perfect)
	# Bump early
	else:
		print("BUMP EARLY")
		boost_factor = boost_factor_late_early
		Globals.stats["bumps_early"] += 1
		spawn_bump_timing(Globals.BUMP.EARLY)
		start_hitstop(hitstop_bump_late_early)

func launch() -> void:
#	velocity = (-global_transform.y).rotated(randf_range(-PI/3.0, PI/3.0)) * speed
	velocity = -global_transform.y * speed
	attached_to = null
