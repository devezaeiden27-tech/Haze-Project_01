extends CharacterBody3D
class_name HazeEnemy

const MAX_HEALTH := 70.0
const MOVE_SPEED := 2.3
const ATTACK_RANGE := 1.55
const ATTACK_DAMAGE := 12.0

var health := MAX_HEALTH
var target: CharacterBody3D
var attack_cooldown := 0.0


func _physics_process(delta: float) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	if not is_instance_valid(target) or target.get("is_dead"):
		velocity.x = move_toward(velocity.x, 0.0, MOVE_SPEED * delta * 4.0)
		velocity.z = move_toward(velocity.z, 0.0, MOVE_SPEED * delta * 4.0)
		move_and_slide()
		return

	var to_target := target.global_position - global_position
	to_target.y = 0.0
	var distance := to_target.length()
	if distance > ATTACK_RANGE:
		var direction := to_target.normalized()
		velocity.x = direction.x * MOVE_SPEED
		velocity.z = direction.z * MOVE_SPEED
		rotation.y = atan2(-direction.x, -direction.z)
	elif attack_cooldown <= 0.0:
		attack_cooldown = 1.25
		target.take_damage(ATTACK_DAMAGE)
		velocity.x = 0.0
		velocity.z = 0.0

	if not is_on_floor():
		velocity.y -= 24.0 * delta
	else:
		velocity.y = 0.0
	move_and_slide()


func set_target(value: CharacterBody3D) -> void:
	target = value


func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0.0:
		queue_free()