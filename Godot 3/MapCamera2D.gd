class_name MapCamera2D
extends Camera2D

export(float, 0.1, 10) var zoom_factor = 1.25 # set to 1 to disable zooming
export(float, 0.01, 100) var zoom_min = 0.1
export(float, 0.01, 100) var zoom_max = 10
export(bool) var zoom_limited = true
export(bool) var zoom_relative = true
export(bool) var zoom_keyboard = true

export(float, 10000) var pan_speed = 250 # set to 0 to disable panning
export(float, 1000) var pan_margin = 25
export(bool) var pan_keyboard = true

export(bool) var drag = true
export(float, 0, 1) var drag_inertia = 0.1 # set to 0 to stop immediately

var tween_offset = SceneTreeTween.new()
var tween_zoom = SceneTreeTween.new()
var pan_direction setget set_pan_direction
var pan_direction_mouse = Vector2.ZERO
var drag_time
var drag_movement = Vector2()

onready var target_zoom = zoom

func _ready():
	self.pan_direction = Vector2.ZERO
	
	get_viewport().connect('size_changed', self, 'change_zoom')
	
	change_zoom()

func _process(delta):
	if drag_movement == Vector2.ZERO:
		clamp_offset(pan_direction * pan_speed * delta * zoom)
	else:
		drag_movement *= pow(drag_inertia, delta)
		
		clamp_offset(-drag_movement * zoom)
		
		if drag_movement.length_squared() < 0.01:
			set_process(false)
			set_physics_process(false)

func _physics_process(delta):
	_process(delta)

func _unhandled_input(event):
	if event is InputEventMagnifyGesture:
		change_zoom(1 + ((zoom_factor if zoom_factor < 1 else 1 / zoom_factor) - 1) * (event.factor - 1) * 2.5)
	elif event is InputEventPanGesture:
		change_zoom(1 + (zoom_factor - 1) * event.delta.y / 7.5)
	elif event is InputEventMouseButton:
		if event.pressed:
			match event.button_index:
				BUTTON_WHEEL_UP:
					change_zoom(1 / zoom_factor)
				BUTTON_WHEEL_DOWN:
					change_zoom(zoom_factor)
				BUTTON_LEFT:
					if drag:
						Input.set_default_cursor_shape(Input.CURSOR_DRAG) # delete to disable drag cursor
						
						drag_time = OS.get_ticks_msec()
						drag_movement = Vector2()
						
						set_process(false)
						set_physics_process(false)
		elif event.button_index == BUTTON_LEFT && drag_time != null:
			Input.set_default_cursor_shape(Input.CURSOR_ARROW)
			
			if (OS.get_ticks_msec() - drag_time < 100 && drag_movement.length_squared() > 3) || pan_direction != Vector2.ZERO:
				set_process(process_mode == CAMERA2D_PROCESS_IDLE)
				set_physics_process(process_mode == CAMERA2D_PROCESS_PHYSICS)
			
			drag_time = null
	elif event is InputEventMouseMotion:
		pan_direction -= pan_direction_mouse
		pan_direction_mouse = Vector2()
		
		if drag_time != null:
			drag_time = OS.get_ticks_msec()
			drag_movement = event.relative
			
			clamp_offset(-event.relative * zoom)
			
			tween_offset.kill()
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
		
		if pan_direction_mouse != Vector2.ZERO:
			self.pan_direction += pan_direction_mouse
	elif event is InputEventKey:
		if zoom_keyboard && event.pressed:
			match event.scancode:
				KEY_MINUS:
					change_zoom(zoom_factor if zoom_factor > 1 else 1 / zoom_factor, false)
				KEY_EQUAL:
					change_zoom(zoom_factor if zoom_factor < 1 else 1 / zoom_factor, false)
		
		if pan_keyboard && !event.echo:
			match event.scancode:
				KEY_LEFT:
					self.pan_direction -= Vector2(1 if event.pressed else -1, 0)
				KEY_RIGHT:
					self.pan_direction += Vector2(1 if event.pressed else -1, 0)
				KEY_UP:
					self.pan_direction -= Vector2(0, 1 if event.pressed else -1)
				KEY_DOWN:
					self.pan_direction += Vector2(0, 1 if event.pressed else -1)
				KEY_SPACE: # delete to disable keyboard centering
					if event.pressed:
						offset = Vector2.ZERO
						
						tween_offset.kill()

func set_pan_direction(value):
	pan_direction = value
	
	if pan_direction == Vector2.ZERO || drag_time != null:
		set_process(false)
		set_physics_process(false)
	elif pan_speed > 0:
		set_process(process_mode == CAMERA2D_PROCESS_IDLE)
		set_physics_process(process_mode == CAMERA2D_PROCESS_PHYSICS)
		
		drag_movement = Vector2()
		
		tween_offset.kill()

func clamp_offset(relative := Vector2()): # call after changing global position and setting offset = offset to stay within limits
	var camera_size = get_viewport_rect().size * zoom
	var camera_rect = Rect2(get_camera_screen_center() + relative - camera_size / 2, camera_size)
	
	if camera_rect.position.x < limit_left:
		drag_movement.x = 0
		relative.x += limit_left - camera_rect.position.x
		camera_rect.end.x += limit_left - camera_rect.position.x
	
	if camera_rect.end.x > limit_right:
		drag_movement.x = 0
		relative.x -= camera_rect.end.x - limit_right
	
	if camera_rect.end.y > limit_bottom:
		drag_movement.y = 0
		relative.y -= camera_rect.end.y - limit_bottom
		camera_rect.position.y -= camera_rect.end.y - limit_bottom
	
	if camera_rect.position.y < limit_top:
		drag_movement.y = 0
		relative.y += limit_top - camera_rect.position.y
	
	if relative != Vector2.ZERO:
		offset += relative

func change_zoom(factor = null, with_cursor = true): # call without arguments after changing limits to stay within limits
	var limited_zoom_max = zoom_max
	
	if zoom_limited:
		var max_zoom_within_limits = Vector2(limit_right - limit_left, limit_bottom - limit_top) / get_viewport_rect().size
		
		limited_zoom_max = max([zoom_max, max_zoom_within_limits.x, max_zoom_within_limits.y].min(), zoom_min)
	elif factor == null:
		return
	
	if factor != null:
		if factor < 1:
			if target_zoom.x < zoom_min || is_equal_approx(target_zoom.x, zoom_min):
				return
			
			if target_zoom.y < zoom_min || is_equal_approx(target_zoom.y, zoom_min):
				return
		elif factor > 1:
			if target_zoom.x > limited_zoom_max || is_equal_approx(target_zoom.x, limited_zoom_max):
				return
			
			if target_zoom.y > limited_zoom_max || is_equal_approx(target_zoom.y, limited_zoom_max):
				return
		else:
			return
		
		target_zoom *= factor
	
	var clamped_zoom = target_zoom
	
	clamped_zoom *= [1, zoom_min / target_zoom.x, zoom_min / target_zoom.y].max()
	clamped_zoom *= [1, limited_zoom_max / target_zoom.x, limited_zoom_max / target_zoom.y].min()
	
	if factor == null:
		set_zoom(clamped_zoom)
		
		target_zoom = zoom
	elif smoothing_enabled && smoothing_speed > 0:
		if zoom_relative && with_cursor && !is_processing() && !is_physics_processing():
			var relative_position = get_global_mouse_position() - global_position - offset
			var relative = relative_position - relative_position / zoom * clamped_zoom
			
			tween_offset.kill()
			tween_offset = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_process_mode(process_mode)
			tween_offset.tween_property(self, 'offset', offset + relative, 2.5 / smoothing_speed)
		
		tween_zoom.kill()
		tween_zoom = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_process_mode(process_mode)
		tween_zoom.tween_method(self, 'set_zoom', zoom, clamped_zoom, 2.5 / smoothing_speed)
	else:
		if zoom_relative && with_cursor:
			var relative_position = get_global_mouse_position() - global_position - offset
			var relative = relative_position - relative_position / zoom * clamped_zoom
			
			zoom = clamped_zoom
			
			clamp_offset(relative)
		else:
			set_zoom(clamped_zoom)

func set_zoom(value):
	zoom = value
	
	clamp_offset()
