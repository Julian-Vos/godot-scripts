@tool
class_name TextureCircle
extends Node2D
## A node for drawing textured circles, arcs and ellipses, with optional collision.

## Texture to fill the circle with.
@export var texture_fill: Texture: set = set_texture_fill
## Texture to decorate the circle's outline with.
@export var texture_outline: Texture: set = set_texture_outline
## The circle's radius.
@export_range(32, 1024) var radius := 128.0: set = set_radius
## The circle's circumference in degrees.
@export_range(0, 360) var length_degrees := 360.0: set = set_length_degrees
## If [code]true[/code], the node is collidable as a static body (in layer 1).
@export var collidable: bool: set = set_collidable

var _texture_fill_size
var _texture_outline_size
var _slice_width_max = 32
var _length = TAU

func _init():
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

func set_texture_fill(value):
	texture_fill = value
	
	if texture_fill != null:
		_texture_fill_size = texture_fill.get_size()
	
	if texture_outline == null:
		_slice_width_max = _texture_fill_size.x if texture_fill != null else 32
	
	queue_redraw()

func set_texture_outline(value):
	texture_outline = value
	
	if texture_outline != null:
		_texture_outline_size = texture_outline.get_size()
		
		if _texture_outline_size.y > radius:
			radius = _texture_outline_size.y
			
			notify_property_list_changed()
		_slice_width_max = _texture_outline_size.x
	else:
		_slice_width_max = _texture_fill_size.x if texture_fill != null else 32
	
	queue_redraw()

func set_radius(value):
	radius = value
	
	if texture_outline != null && _texture_outline_size.y > radius:
		radius = _texture_outline_size.y
	
	queue_redraw()

func set_length_degrees(value):
	length_degrees = value
	_length = deg_to_rad(value)
	
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
	var slice_angle = atan2(_slice_width_max / 2, radius) * 2
	var slice_count = ceil(TAU / slice_angle)
	
	slice_angle = TAU / slice_count
	slice_count = ceil(_length / slice_angle)
	
	var slice_width_left = tan(slice_angle / 2) * radius
	var slice_width_right = slice_width_left
	
	var radius_left = sqrt(slice_width_left ** 2 + radius ** 2)
	var radius_right = sqrt(slice_width_right ** 2 + radius ** 2)
	var polygon = [Vector2.ZERO]
	
	for i in range(slice_count):
		var angle = slice_angle * i
		
		if i == slice_count - 1:
			slice_width_right = tan((_length - angle) / 2) * radius * 2 - slice_width_left
			radius_right = sqrt(slice_width_right ** 2 + radius ** 2)
		
		draw_set_transform(Vector2.ZERO, slice_angle / 2 + angle, Vector2.ONE)
		
		if texture_fill != null:
			draw_colored_polygon([
				Vector2(-slice_width_left, -radius),
				Vector2(slice_width_right, -radius),
				Vector2(0, 0)
			], Color.WHITE, [
				Vector2(0, 0),
				Vector2(slice_width_left + slice_width_right, 0) / _texture_fill_size,
				Vector2(slice_width_left, radius) / _texture_fill_size
			], texture_fill)
		
		if texture_outline != null:
			var ratio = (radius - _texture_outline_size.y) / radius
			var offset_left = slice_width_left * ratio
			var offset_right = slice_width_right * ratio
			
			draw_colored_polygon([
				Vector2(-slice_width_left, -radius),
				Vector2(slice_width_right, -radius),
				Vector2(offset_right, _texture_outline_size.y - radius),
				Vector2(-offset_left, _texture_outline_size.y - radius)
			], Color.WHITE, [
				Vector2(0, 0),
				Vector2(slice_width_left + slice_width_right, 0) / _texture_outline_size,
				Vector2(0.5 + offset_right / _texture_outline_size.x, 1),
				Vector2(0.5 - offset_left / _texture_outline_size.x, 1)
			], texture_outline)
		
		polygon.push_back(Vector2(sin(angle) * radius_left, -cos(angle) * radius_left))
	
	polygon.push_back(Vector2(sin(_length) * radius_right, -cos(_length) * radius_right))
	
	if collidable:
		$StaticBody2D/CollisionPolygon2D.polygon = polygon
