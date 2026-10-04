extends CharacterBody3D
class_name HazePlayer

signal health_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
signal died
signal restart_requested

const WALK_SPEED := 5.2
const SPRINT_SPEED := 8.0
const DODGE_SPEED := 12.0
const MAX_HEALTH := 100.0
const MAX_STAMINA := 100.0
const DODGE_COST := 28.0
const SPRINT_DRAIN := 24.0
const STAMINA_REGEN := 19.0

var health := MAX_HEALTH
var stamina := MAX_STAMINA
var invulnerability_time := 0.0
var dodge_time := 0.0
var attack_time := 0.0
var stamina_recovery_delay := 0.0
var touch_movement := Vector2.ZERO
var touch_sprinting := false
var is_dead := false
var hit_targets: Dictionary = {}

@onready var attack_area: Area3D = $AttackArea
@onready var sword_pivot: Node3D = $SwordPivot


func _ready() -> void:
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	health_changed.emit(health, MAX_HEALTH)
	stamina_changed.emit(stamina, MAX_STAMINA)


func _physics_process(delta: float) -> void:
	if is_dead:
		if Input.is_action_just_pressed("restart"):
			restart_requested.emit()
		return

	invulnerability_time = maxf(0.0, invulnerability_time - delta)
	dodge_time = maxf(0.0, dodge_time - delta)
	attack_time = maxf(0.0, attack_time - delta)
	stamina_recovery_delay = maxf(0.0, stamina_recovery_delay - delta)
	_update_sword()
	_update_stamina(delta)

	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	input_vector = (input_vector + touch_movement).limit_length(1.0)
	var camera := get_viewport().get_camera_3d()
	var move_direction := Vector3.ZERO
	if camera != null:
		var camera_right := camera.global_basis.x
		var camera_forward := -camera.global_basis.z
		camera_right.y = 0.0
		camera_forward.y = 0.0
		move_direction = (camera_right.normalized() * input_vector.x - camera_forward.normalized() * input_vector.y).normalized()
	else:
		move_direction = Vector3(input_vector.x, 0.0, input_vector.y).normalized()

	if dodge_time > 0.0:
		velocity.x = _dodge_direction().x * DODGE_SPEED
		velocity.z = _dodge_direction().z * DODGE_SPEED
	else:
		var sprinting := (Input.is_action_pressed("sprint") or touch_sprinting) and input_vector.length_squared() > 0.01 and stamina > 0.0
		var speed := SPRINT_SPEED if sprinting else WALK_SPEED
		velocity.x = move_direction.x * speed
		velocity.z = move_direction.z * speed
		if sprinting:
			stamina = maxf(0.0, stamina - SPRINT_DRAIN * delta)
			stamina_recovery_delay = 0.8
			stamina_changed.emit(stamina, MAX_STAMINA)
		if move_direction.length_squared() > 0.001:
			rotation.y = atan2(-move_direction.x, -move_direction.z)
			if Input.is_action_just_pressed("dodge"):
				_start_dodge(move_direction)

	if Input.is_action_just_pressed("dodge") and dodge_time <= 0.0:
		_start_dodge(move_direction)
	if Input.is_action_just_pressed("attack"):
		_start_attack()

	if not is_on_floor():
		velocity.y -= 24.0 * delta
	else:
		velocity.y = 0.0
	move_and_slide()


func set_touch_movement(value: Vector2) -> void:
	touch_movement = value.limit_length(1.0)


func set_touch_sprinting(value: bool) -> void:
	touch_sprinting = value


func touch_dodge() -> void:
	if is_dead or dodge_time > 0.0 or stamina < DODGE_COST:
		return
	var direction := _current_move_direction()
	_start_dodge(direction)


func touch_attack() -> void:
	_start_attack()


func take_damage(amount: float) -> void:
	if is_dead or invulnerability_time > 0.0:
		return
	health = maxf(0.0, health - amount)
	health_changed.emit(health, MAX_HEALTH)
	if health <= 0.0:
		is_dead = true
		velocity = Vector3.ZERO
		died.emit()


func _start_dodge(direction: Vector3) -> void:
	if dodge_time > 0.0 or stamina < DODGE_COST:
		return
	if direction.length_squared() < 0.001:
		direction = -global_basis.z
	stamina -= DODGE_COST
	stamina_recovery_delay = 0.9
	stamina_changed.emit(stamina, MAX_STAMINA)
	dodge_time = 0.34
	invulnerability_time = 0.42
	velocity.x = direction.normalized().x * DODGE_SPEED
	velocity.z = direction.normalized().z * DODGE_SPEED


func _start_attack() -> void:
	if is_dead or attack_time > 0.0:
		return
	attack_time = 0.42
	hit_targets.clear()
	attack_area.monitoring = true
	get_tree().create_timer(0.2).timeout.connect(_finish_attack_hitbox)
	for body in attack_area.get_overlapping_bodies():
		_apply_attack_hit(body)


func _finish_attack_hitbox() -> void:
	attack_area.monitoring = false


func _apply_attack_hit(body: Node3D) -> void:
	if hit_targets.has(body) or not body.is_in_group("enemies"):
		return
	hit_targets[body] = true
	if body.has_method("take_damage"):
		body.take_damage(35.0)


func _on_attack_area_body_entered(body: Node3D) -> void:
	_apply_attack_hit(body)


func _update_stamina(delta: float) -> void:
	if stamina_recovery_delay > 0.0 or (Input.is_action_pressed("sprint") and touch_movement.length_squared() > 0.01):
		return
	if stamina < MAX_STAMINA:
		stamina = minf(MAX_STAMINA, stamina + STAMINA_REGEN * delta)
		stamina_changed.emit(stamina, MAX_STAMINA)


func _update_sword() -> void:
	if attack_time <= 0.0:
		sword_pivot.rotation.y = 0.0
		return
	var progress := 1.0 - attack_time / 0.42
	sword_pivot.rotation.y = sin(progress * PI) * 1.25


func _current_move_direction() -> Vector3:
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	input_vector = (input_vector + touch_movement).limit_length(1.0)
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector3(input_vector.x, 0.0, input_vector.y).normalized()
	var right := camera.global_basis.x
	var forward := -camera.global_basis.z
	right.y = 0.0
	forward.y = 0.0
	return (right.normalized() * input_vector.x - forward.normalized() * input_vector.y).normalized()


func _dodge_direction() -> Vector3:
	return _current_move_direction() if _current_move_direction().length_squared() > 0.001 else -global_basis.z