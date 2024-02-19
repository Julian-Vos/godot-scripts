extends Camera2D

@export_range(0.1, 10) var zoom_factor := 1.25 # set to 1 to disable zooming
@export_range(0.01, 100) var zoom_min := 0.1
@export_range(0.01, 100) var zoom_max := 10.0
@export var zoom_relative := true
@export var zoom_keyboard := true

@export_range(0, 10000) var pan_speed := 250.0 # set to 0 to disable panning
@export_range(0, 1000) var pan_margin := 25.0
@export var pan_keyboard := true

@export var drag := true

var tween_offset
var tween_zoom
var pan_direction: set = set_pan_direction
var pan_direction_mouse = Vector2.ZERO
var dragging = false

@onready var target_zoom = zoom

func _ready():
	pan_direction = Vector2.ZERO
	
	get_viewport().size_changed.connect(clamp_offset)

func _process(delta):
	clamp_offset(pan_direction * pan_speed * delta / zoom)

func _physics_process(delta):
	clamp_offset(pan_direction * pan_speed * delta / zoom)

func _unhandled_input(event):
	if event is InputEventMagnifyGesture:
		change_zoom(1 + ((zoom_factor if zoom_factor > 1 else 1 / zoom_factor) - 1) * (event.factor - 1) * 2.5)
	elif event is InputEventPanGesture:
		change_zoom(1 + (1 / zoom_factor - 1) * event.delta.y / 7.5)
	elif event is InputEventMouseButton:
		if event.pressed:
			match event.button_index:
				MOUSE_BUTTON_WHEEL_UP:
					change_zoom(zoom_factor)
				MOUSE_BUTTON_WHEEL_DOWN:
					change_zoom(1 / zoom_factor)
				MOUSE_BUTTON_LEFT:
					if drag:
						dragging = true
						
						Input.set_default_cursor_shape(Input.CURSOR_DRAG) # delete to disable drag cursor
		elif event.button_index == MOUSE_BUTTON_LEFT:
			dragging = false
			
			Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	elif event is InputEventMouseMotion:
		pan_direction -= pan_direction_mouse
		pan_direction_mouse = Vector2()
		
		if dragging:
			if tween_offset != null:
				tween_offset.kill()
			
			clamp_offset(-event.relative / zoom)
		elif pan_margin > 0:
			var camera_size = get_viewport_rect().size
			
			if event.position.x < pan_margin:
				pan_direction_mouse.x -= 1
			
			if event.position.x >= camera_size.x - pan_margin:
				pan_direction_mouse.x += 1
			
			if event.position.y < pan_margin:
				pan_direction_mouse.y -= 1
			
			if event.position.y >= camera_size.y - pan_margin:
				pan_direction_mouse.y += 1
		
		pan_direction += pan_direction_mouse
	elif event is InputEventKey:
		if zoom_keyboard && event.pressed:
			match event.keycode:
				KEY_MINUS:
					change_zoom(zoom_factor if zoom_factor < 1 else 1 / zoom_factor, false)
				KEY_EQUAL:
					change_zoom(zoom_factor if zoom_factor > 1 else 1 / zoom_factor, false)
		
		if pan_keyboard && !event.echo:
			match event.keycode:
				KEY_LEFT:
					pan_direction -= Vector2(1 if event.pressed else -1, 0)
				KEY_RIGHT:
					pan_direction += Vector2(1 if event.pressed else -1, 0)
				KEY_UP:
					pan_direction -= Vector2(0, 1 if event.pressed else -1)
				KEY_DOWN:
					pan_direction += Vector2(0, 1 if event.pressed else -1)
				KEY_SPACE: # delete to disable keyboard centering
					if event.pressed:
						if tween_offset != null:
							tween_offset.kill()
						
						offset = Vector2.ZERO

func set_pan_direction(new_value):
	pan_direction = new_value
	
	if pan_direction == Vector2.ZERO:
		set_process(false)
		set_physics_process(false)
	elif pan_speed > 0:
		set_process(process_callback == CAMERA2D_PROCESS_IDLE)
		set_physics_process(process_callback == CAMERA2D_PROCESS_PHYSICS)
		
		if tween_offset != null:
			tween_offset.kill()

func clamp_offset(relative = Vector2()): # call after changing global position and setting offset = offset to stay within limits
	var camera_size = get_viewport_rect().size / zoom
	var camera_rect = Rect2(get_screen_center_position() + relative - camera_size / 2, camera_size)
	
	if camera_rect.position.x < limit_left:
		relative.x += limit_left - camera_rect.position.x
		camera_rect.end.x += limit_left - camera_rect.position.x
	
	if camera_rect.end.x > limit_right:
		relative.x -= camera_rect.end.x - limit_right
	
	if camera_rect.end.y > limit_bottom:
		relative.y -= camera_rect.end.y - limit_bottom
		camera_rect.position.y -= camera_rect.end.y - limit_bottom
	
	if camera_rect.position.y < limit_top:
		relative.y += limit_top - camera_rect.position.y
	
	if relative != Vector2.ZERO:
		offset += relative

func change_zoom(factor, with_cursor = true):
	if factor < 1:
		if target_zoom.x < zoom_min || is_equal_approx(target_zoom.x, zoom_min):
			return
		
		if target_zoom.y < zoom_min || is_equal_approx(target_zoom.y, zoom_min):
			return
	elif factor > 1:
		if target_zoom.x > zoom_max || is_equal_approx(target_zoom.x, zoom_max):
			return
		
		if target_zoom.y > zoom_max || is_equal_approx(target_zoom.y, zoom_max):
			return
	else:
		return
	
	target_zoom *= factor
	
	var clamped_zoom = target_zoom
	
	clamped_zoom *= [1, zoom_min / target_zoom.x, zoom_min / target_zoom.y].max()
	clamped_zoom *= [1, zoom_max / target_zoom.x, zoom_max / target_zoom.y].min()
	
	if position_smoothing_enabled && position_smoothing_speed > 0:
		if zoom_relative && pan_direction == Vector2.ZERO:
			var relative_position = get_global_mouse_position() - global_position - offset
			var relative = relative_position - relative_position * zoom / clamped_zoom
			
			if tween_offset != null:
				tween_offset.kill()
			
			tween_offset = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_process_mode(process_callback as Tween.TweenProcessMode)
			tween_offset.tween_property(self, 'offset', offset + relative, 2.5 / position_smoothing_speed)
		
		if tween_zoom != null:
			tween_zoom.kill()
		
		tween_zoom = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_process_mode(process_callback as Tween.TweenProcessMode)
		tween_zoom.tween_method(func(value): set_zoom_level(Vector2.ONE / value), Vector2.ONE / zoom, Vector2.ONE / clamped_zoom, 2.5 / position_smoothing_speed)
	else:
		if zoom_relative && with_cursor:
			var relative_position = get_global_mouse_position() - global_position - offset
			var relative = relative_position - relative_position * zoom / clamped_zoom
			
			zoom = clamped_zoom
			
			clamp_offset(relative)
		else:
			set_zoom_level(clamped_zoom)

func set_zoom_level(new_value):
	zoom = new_value
	
	clamp_offset()
