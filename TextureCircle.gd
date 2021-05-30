tool
extends Node2D

export(Texture) var texture_fill setget set_texture_fill # import with Repeat enabled
export(Texture) var texture_outline setget set_texture_outline
export(float, 32, 1024) var radius = 128 setget set_radius
export(float, 0, 360) var length_degrees = 360 setget set_length_degrees
export(bool) var collidable setget set_collidable

var texture_fill_size
var texture_outline_size
var slice_width_max = 32
var length = TAU

func set_texture_fill(value):
	texture_fill = value
	
	if texture_fill != null:
		texture_fill_size = texture_fill.get_size()
	
	if texture_outline == null:
		slice_width_max = texture_fill_size.x if texture_fill != null else 32
	
	update()

func set_texture_outline(value):
	texture_outline = value
	
	if texture_outline != null:
		texture_outline_size = texture_outline.get_size() 
		
		if texture_outline_size.y > radius:
			radius = texture_outline_size.y
			
			property_list_changed_notify()
		
		slice_width_max = texture_outline_size.x
	else:
		slice_width_max = texture_fill_size.x if texture_fill != null else 32
	
	update()

func set_radius(value):
	radius = value
	
	if texture_outline != null && texture_outline_size.y > radius:
		radius = texture_outline_size.y
	
	update()

func set_length_degrees(value):
	length_degrees = value
	length = deg2rad(value)
	
	update()

func set_collidable(value):
	collidable = value
	
	if collidable != has_node('StaticBody2D'):
		if collidable:
			var body = StaticBody2D.new()
			
			body.add_child(CollisionPolygon2D.new(), true)
			body.show_behind_parent = true
			
			add_child(body, true)
		else:
			$StaticBody2D.queue_free()
	
	update()

func _draw():
	var slice_angle = atan2(slice_width_max / 2, radius) * 2
	var slice_count = ceil(TAU / slice_angle)
	
	slice_angle = TAU / slice_count
	slice_count = ceil(length / slice_angle)
	
	var slice_width_left = tan(slice_angle / 2) * radius
	var slice_width_right = slice_width_left
	
	var radius_left = sqrt(pow(slice_width_left, 2) + pow(radius, 2))
	var radius_right = sqrt(pow(slice_width_right, 2) + pow(radius, 2))
	var polygon = [Vector2.ZERO]
	
	for i in range(slice_count):
		var angle = slice_angle * i
		
		if i == slice_count - 1:
			slice_width_right = tan((length - angle) / 2) * radius * 2 - slice_width_left
			radius_right = sqrt(pow(slice_width_right, 2) + pow(radius, 2))
		
		draw_set_transform(Vector2.ZERO, slice_angle / 2 + angle, Vector2.ONE)
		
		if texture_fill != null:
			draw_colored_polygon([
				Vector2(-slice_width_left, -radius),
				Vector2(slice_width_right, -radius),
				Vector2(0, 0)
			], Color.white, [
				Vector2(0, 0),
				Vector2(slice_width_left + slice_width_right, 0) / texture_fill_size,
				Vector2(slice_width_left, radius) / texture_fill_size
			], texture_fill)
		
		if texture_outline != null:
			var ratio = (radius - texture_outline_size.y) / radius
			var offset_left = slice_width_left * ratio
			var offset_right = slice_width_right * ratio
			
			draw_colored_polygon([
				Vector2(-slice_width_left, -radius),
				Vector2(slice_width_right, -radius),
				Vector2(offset_right, texture_outline_size.y - radius),
				Vector2(-offset_left, texture_outline_size.y - radius)
			], Color.white, [
				Vector2(0, 0),
				Vector2(slice_width_left + slice_width_right, 0) / texture_outline_size,
				Vector2(0.5 + offset_right / texture_outline_size.x, 1),
				Vector2(0.5 - offset_left / texture_outline_size.x, 1)
			], texture_outline)
		
		polygon.push_back(Vector2(sin(angle) * radius_left, -cos(angle) * radius_left))
	
	polygon.push_back(Vector2(sin(length) * radius_right, -cos(length) * radius_right))
	
	if collidable:
		$StaticBody2D/CollisionPolygon2D.polygon = polygon
