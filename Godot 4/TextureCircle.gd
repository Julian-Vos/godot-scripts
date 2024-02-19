@tool
extends Node2D

@export var texture_fill: Texture: set = set_texture_fill
@export var texture_outline: Texture: set = set_texture_outline
@export_range(32, 1024) var radius := 128.0: set = set_radius
@export_range(0, 360) var length_degrees := 360.0: set = set_length_degrees
@export var collidable: bool: set = set_collidable

var texture_fill_size
var texture_outline_size
var slice_width_max = 32
var length = TAU

func _init():
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

func set_texture_fill(value):
	texture_fill = value
	
	if texture_fill != null:
		texture_fill_size = texture_fill.get_size()
	
	if texture_outline == null:
		slice_width_max = texture_fill_size.x if texture_fill != null else 32
	
	queue_redraw()

func set_texture_outline(value):
	texture_outline = value
	
	if texture_outline != null:
		texture_outline_size = texture_outline.get_size() 
		
		if texture_outline_size.y > radius:
			radius = texture_outline_size.y
			
			notify_property_list_changed()
		
		slice_width_max = texture_outline_size.x
	else:
		slice_width_max = texture_fill_size.x if texture_fill != null else 32
	
	queue_redraw()

func set_radius(value):
	radius = value
	
	if texture_outline != null && texture_outline_size.y > radius:
		radius = texture_outline_size.y
	
	queue_redraw()

func set_length_degrees(value):
	length_degrees = value
	length = deg_to_rad(value)
	
	queue_redraw()

func set_collidable(value):
	collidable = value
	
	if is_inside_tree():
		queue_redraw()
	else:
		await ready
	
	if collidable != has_node('StaticBody2D'):
		if collidable:
			var body = StaticBody2D.new()
			
			body.add_child(CollisionPolygon2D.new(), true)
			body.show_behind_parent = true
			
			add_child(body, true)
		else:
			$StaticBody2D.queue_free()

func _draw():
	var slice_angle = atan2(slice_width_max / 2, radius) * 2
	var slice_count = ceil(TAU / slice_angle)
	
	slice_angle = TAU / slice_count
	slice_count = ceil(length / slice_angle)
	
	var slice_width_left = tan(slice_angle / 2) * radius
	var slice_width_right = slice_width_left
	
	var radius_left = sqrt(slice_width_left ** 2 + radius ** 2)
	var radius_right = sqrt(slice_width_right ** 2 + radius ** 2)
	var polygon = [Vector2.ZERO]
	
	for i in range(slice_count):
		var angle = slice_angle * i
		
		if i == slice_count - 1:
			slice_width_right = tan((length - angle) / 2) * radius * 2 - slice_width_left
			radius_right = sqrt(slice_width_right ** 2 + radius ** 2)
		
		draw_set_transform(Vector2.ZERO, slice_angle / 2 + angle, Vector2.ONE)
		
		if texture_fill != null:
			draw_colored_polygon([
				Vector2(-slice_width_left, -radius),
				Vector2(slice_width_right, -radius),
				Vector2(0, 0)
			], Color.WHITE, [
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
			], Color.WHITE, [
				Vector2(0, 0),
				Vector2(slice_width_left + slice_width_right, 0) / texture_outline_size,
				Vector2(0.5 + offset_right / texture_outline_size.x, 1),
				Vector2(0.5 - offset_left / texture_outline_size.x, 1)
			], texture_outline)
		
		polygon.push_back(Vector2(sin(angle) * radius_left, -cos(angle) * radius_left))
	
	polygon.push_back(Vector2(sin(length) * radius_right, -cos(length) * radius_right))
	
	if collidable:
		$StaticBody2D/CollisionPolygon2D.polygon = polygon
