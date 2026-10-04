extends Control

signal restart_requested

const HEALTH_COLOR := Color(0.86, 0.25, 0.23)
const STAMINA_COLOR := Color(0.25, 0.78, 0.57)
const PANEL_COLOR := Color(0.025, 0.045, 0.06, 0.86)
const TOUCH_RADIUS := 45.0
const DODGE_RADIUS := 42.0
const SPRINT_RADIUS := 42.0

var player: HazePlayer
var health_value := 100.0
var health_maximum := 100.0
var stamina_value := 100.0
var stamina_maximum := 100.0
var touch_enabled := false
var movement_touch_id := -1
var sprint_touch_id := -1
var movement_origin := Vector2.ZERO
var movement_vector := Vector2.ZERO
var dead := false


func _ready() -> void:
	touch_enabled = OS.has_feature("mobile")
	set_process_input(true)
	queue_redraw()


func setup(value: HazePlayer) -> void:
	player = value
	health_value = player.health
	stamina_value = player.stamina
	player.health_changed.connect(_on_health_changed)
	player.stamina_changed.connect(_on_stamina_changed)
	player.died.connect(_on_player_died)
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	_draw_bar(Vector2(28, 28), 250.0, 18.0, health_value, health_maximum, HEALTH_COLOR)
	draw_string(font, Vector2(30, 22), "VITALITY", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.84, 0.9, 0.94))
	_draw_bar(Vector2(28, 62), 210.0, 12.0, stamina_value, stamina_maximum, STAMINA_COLOR)
	draw_string(font, Vector2(30, 58), "STAMINA", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.72, 0.82, 0.84))
	draw_string(font, Vector2(28, 104), "WASD MOVE   SHIFT SPRINT   SPACE DODGE   LMB ATTACK", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.73, 0.79, 0.82, 0.85))
	if touch_enabled:
		_draw_touch_controls(font)
	if dead:
		_draw_death_overlay(font)


func _draw_bar(position: Vector2, width: float, height: float, value: float, maximum: float, color: Color) -> void:
	draw_rect(Rect2(position, Vector2(width, height)), PANEL_COLOR, true)
	var fraction := clampf(value / maximum, 0.0, 1.0) if maximum > 0.0 else 0.0
	draw_rect(Rect2(position, Vector2(width * fraction, height)), color, true)
	draw_rect(Rect2(position, Vector2(width, height)), Color(0.75, 0.84, 0.86, 0.8), false, 1.0)


func _draw_touch_controls(font: Font) -> void:
	var left_center := movement_origin if movement_touch_id >= 0 else Vector2(94, size.y - 112)
	_draw_touch_circle(left_center, 58.0, Color(0.1, 0.16, 0.19, 0.35))
	_draw_touch_circle(left_center + movement_vector * 34.0, 25.0, Color(0.74, 0.86, 0.88, 0.55))
	var attack_center := Vector2(size.x - 82, size.y - 126)
	var dodge_center := Vector2(size.x - 198, size.y - 85)
	var sprint_center := Vector2(size.x - 314, size.y - 122)
	_draw_touch_circle(attack_center, TOUCH_RADIUS, Color(0.75, 0.25, 0.21, 0.58))
	_draw_touch_circle(dodge_center, DODGE_RADIUS, Color(0.26, 0.55, 0.68, 0.58))
	_draw_touch_circle(sprint_center, SPRINT_RADIUS, Color(0.2, 0.62, 0.42, 0.58))
	draw_string(font, attack_center + Vector2(-20, 5), "HIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	draw_string(font, dodge_center + Vector2(-23, 5), "DODGE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
	draw_string(font, sprint_center + Vector2(-24, 5), "RUN", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)


func _draw_touch_circle(center: Vector2, radius: float, color: Color) -> void:
	draw_circle(center, radius, color)
	draw_arc(center, radius, 0.0, TAU, 36, Color(0.85, 0.92, 0.94, 0.55), 1.5)


func _draw_death_overlay(font: Font) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.02, 0.03, 0.72), true)
	var center := size * 0.5
	draw_string(font, center + Vector2(-95, -8), "YOU FELL", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(0.94, 0.95, 0.92))
	draw_string(font, center + Vector2(-108, 32), "PRESS ENTER OR TAP TO RESTART", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.72, 0.82, 0.84))


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_handle_touch_press(event.index, event.position)
		else:
			_handle_touch_release(event.index)
	elif event is InputEventScreenDrag and event.index == movement_touch_id:
		_update_movement_touch(event.position)
	elif dead and event is InputEventMouseButton and event.pressed:
		restart_requested.emit()


func _handle_touch_press(index: int, position: Vector2) -> void:
	if dead:
		restart_requested.emit()
		return
	if position.x < size.x * 0.44 and position.y > size.y * 0.52 and movement_touch_id < 0:
		movement_touch_id = index
		movement_origin = position
		_update_movement_touch(position)
		return
	if position.distance_to(Vector2(size.x - 82, size.y - 126)) <= TOUCH_RADIUS:
		player.touch_attack()
	elif position.distance_to(Vector2(size.x - 198, size.y - 85)) <= DODGE_RADIUS:
		player.touch_dodge()
	elif position.distance_to(Vector2(size.x - 314, size.y - 122)) <= SPRINT_RADIUS:
		sprint_touch_id = index
		player.set_touch_sprinting(true)


func _handle_touch_release(index: int) -> void:
	if index == movement_touch_id:
		movement_touch_id = -1
		movement_vector = Vector2.ZERO
		player.set_touch_movement(Vector2.ZERO)
	if index == sprint_touch_id:
		sprint_touch_id = -1
		player.set_touch_sprinting(false)
	queue_redraw()


func _update_movement_touch(position: Vector2) -> void:
	movement_vector = ((position - movement_origin) / 52.0).limit_length(1.0)
	player.set_touch_movement(movement_vector)
	queue_redraw()


func _on_health_changed(current: float, maximum: float) -> void:
	health_value = current
	health_maximum = maximum
	queue_redraw()


func _on_stamina_changed(current: float, maximum: float) -> void:
	stamina_value = current
	stamina_maximum = maximum
	queue_redraw()


func _on_player_died() -> void:
	dead = true
	queue_redraw()