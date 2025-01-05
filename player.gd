extends CharacterBody3D

@onready var neck: Node3D = $neck
@onready var head: Node3D = $neck/head
@onready var eyes: Node3D = $neck/head/eyes

@onready var crouching_collision_shape: CollisionShape3D = $crouching_collision_shape
@onready var standing_collision_shape: CollisionShape3D = $standing_collision_shape
@onready var ray_cast_3d: RayCast3D = $RayCast3D

@onready var camera1: Camera3D = $neck/head/eyes/Camera3D
@onready var camera2: Camera3D = $"../Camera3D"
var active_camera = 0

var current_speed = 5.0
var crouching_depth = -0.5
var slide_speed = 10


const head_bobbing_sprinting_speed = 22.0
const head_bobbing_walking_speed = 14.0
const head_bobbing_crouching_speed = 10.0

const head_bobbing_sprinting_intensity = 0.2
const head_bobbing_walking_intensity = 0.1
const head_bobbing_crouching_intensity = 0.05

var head_bobbing_vector = Vector2.ZERO
var head_bobbing_index = 0.0
var head_bobbling_current_intensity = 0.0

var slide_timer = 0.0
var slide_timer_max = 1.0
var slide_vector = Vector2.ZERO

var free_look_tilt_amount = 10

const walking_speed = 5.0
const sprinting_speed = 8.0
const crouching_speed = 3.0
const jump_velocity = 4.5

const mouse_sens = 0.4
var lerp_speed = 10.0

var walking = false
var sprinting = false
var crouching = false
var free_looking = false
var sliding = false

var direction = Vector3.ZERO


func _ready() -> void:
	switch_camera()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("switch"):  # Enter для переключения
		active_camera = (active_camera + 1) % 2  # Переключаем между 0 и 1
		switch_camera()

func switch_camera() -> void:
	camera1.current = (active_camera == 0)
	camera2.current = (active_camera == 1)
	
	if active_camera == 1:
		camera2.look_at(global_transform.origin, Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			if free_looking:
				neck.rotate_y(deg_to_rad(-event.relative.x * mouse_sens))
				neck.rotation.y = clamp(neck.rotation.y, deg_to_rad(-120), deg_to_rad(120))
			else:
				rotate_y(deg_to_rad(-event.relative.x * mouse_sens))
				head.rotate_x(deg_to_rad(-event.relative.y * mouse_sens))
				head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))

func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	print(walking)
	if not is_on_floor():
		velocity += get_gravity() * delta
		
	if Input.is_action_pressed("crouch") || sliding:
		current_speed = lerp(current_speed, crouching_speed, delta * lerp_speed)
		head.position.y = lerp(head.position.y, crouching_depth, delta * lerp_speed)
		standing_collision_shape.disabled = true
		crouching_collision_shape.disabled = false
		
		
		
		if sprinting && input_dir != Vector2.ZERO  && is_on_floor():
			sliding = true
			free_looking = true
			slide_timer = slide_timer_max
			slide_vector = input_dir
			print("slide start")
		
		walking = false
		sprinting = false
		crouching = true

	elif !ray_cast_3d.is_colliding():
		standing_collision_shape.disabled = false
		crouching_collision_shape.disabled = true
		head.position.y = lerp(head.position.y, 0.0, delta * lerp_speed)

		if Input.is_action_pressed("sprint") && is_on_floor():
			current_speed = lerp(current_speed, sprinting_speed, delta * lerp_speed)
			
			walking = false
			sprinting = true
			crouching = false
		else:
			walking = true
			sprinting = false
			crouching = false
			current_speed = lerp(current_speed, walking_speed, delta * lerp_speed)
			
		if Input.is_action_just_pressed("ui_accept") && is_on_floor():
			velocity.y = jump_velocity
			sliding = false
			
	if Input.is_action_pressed("free_look") || sliding:
		free_looking = true
		camera1.rotation.z = -deg_to_rad(neck.rotation.y * free_look_tilt_amount)
	else:
		free_looking = false
		camera1.rotation.z = lerp(camera1.rotation.y, 0.0, delta*lerp_speed)
		neck.rotation.y = lerp(neck.rotation.y, 0.0, delta*lerp_speed)
	
	if sliding:
		slide_timer -= delta
		if slide_timer <= 0:
			sliding = false
			free_looking = false
			print("slide end")
		
	if sprinting:
		head_bobbling_current_intensity = head_bobbing_sprinting_intensity
		head_bobbing_index += head_bobbing_sprinting_speed * delta
	elif walking:
		head_bobbling_current_intensity = head_bobbing_walking_intensity
		head_bobbing_index += head_bobbing_walking_speed * delta
	elif crouching:
		head_bobbling_current_intensity = head_bobbing_crouching_intensity
		head_bobbing_index += head_bobbing_walking_speed * delta
		
	if is_on_floor() && !sliding && input_dir != Vector2.ZERO:
		head_bobbing_vector.y = sin(head_bobbing_index)
		head_bobbing_vector.x = sin(head_bobbing_index/2)+0.5
		
		eyes.position.y = lerp(eyes.position.y, head_bobbing_vector.y*(head_bobbling_current_intensity/2.0), delta * lerp_speed)
		eyes.position.x = lerp(eyes.position.x, head_bobbing_vector.x*(head_bobbling_current_intensity), delta * lerp_speed)

	else:
		eyes.position.y = lerp(eyes.position.y, 0.0, delta * lerp_speed)
		eyes.position.x = lerp(eyes.position.x, 0.0, delta * lerp_speed)
		
	if Input.is_action_just_pressed("ui_restart"):
		get_tree().reload_current_scene()
	if Input.is_action_just_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


	direction = lerp(direction, (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta * lerp_speed) 
	
	if sliding:
		direction = (transform.basis * Vector3(slide_vector.x, 0, slide_vector.y)).normalized()
		current_speed = (slide_timer + 0.1) * slide_speed
		
	if direction.length() > 0:
		if is_on_floor():
			velocity.x = direction.x * current_speed
			velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	move_and_slide()
