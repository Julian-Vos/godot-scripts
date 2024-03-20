@tool
class_name AudioStreamPlayerArea2D
extends AudioStreamPlayer2D
## A node like [AudioStreamPlayer2D], but plays from a polygonal area rather than a single point.

## The area to play from approximately (must be clockwise).
@export var polygon: PackedVector2Array:
	set(value):
		polygon = value
		
		queue_redraw()
## When changing the current [AudioListener2D] at runtime, set this.
var current_audio_listener: AudioListener2D
var _previous_hearing_point
var _previous_global_transform

## When changing the node's [Viewport] at runtime, set this.
@onready var viewport := get_viewport()

func _ready():
	if Engine.is_editor_hint() || polygon.is_empty():
		set_process(false)
		
		return
	
	for audio_listener in viewport.find_children("", "AudioListener2D", true, false):
		if audio_listener.is_current():
			current_audio_listener = audio_listener
			
			break
	
	position += polygon[0]
	
	polygon *= Transform2D(0, polygon[0])
	
	_move_toward_hearing_point()

## Process after moving the current camera, by using lower tree order or higher [member Node.process_priority].
## Consider disabling processing when far away.
func _process(_delta: float):
	_move_toward_hearing_point()

func _move_toward_hearing_point():
	var hearing_point = viewport.canvas_transform.affine_inverse() * (viewport.get_visible_rect().size / 2) \
		if current_audio_listener == null else current_audio_listener.global_position
	
	if hearing_point == _previous_hearing_point && global_transform == _previous_global_transform:
		return
	
	_previous_hearing_point = hearing_point
	_previous_global_transform = global_transform
	
	var global_polygon = global_transform * polygon
	
	if Geometry2D.is_point_in_polygon(hearing_point, global_polygon):
		global_position = hearing_point
	else:
		var previous_point = global_polygon[-1]
		var horizontal_distance_to_segment_sum = 0
		var vertical_distance_to_segment_sum = 0
		var weight_sum = 0
		var min_distance_to_segment = INF
		
		for point in global_polygon:
			var direction = previous_point.direction_to(point)
			var normal = Vector2(direction.y, -direction.x)
			var distance_to_segment_uncapped = normal.dot(hearing_point) - normal.dot(point)
			
			if distance_to_segment_uncapped < 0:
				previous_point = point
				
				continue
			
			var closest_point_on_segment_uncapped = hearing_point - normal * distance_to_segment_uncapped
			var sign_closest_point_on_segment_uncapped_minus_previous_point = Vector2(
				0 if is_equal_approx(closest_point_on_segment_uncapped.x, previous_point.x) else sign(closest_point_on_segment_uncapped.x - previous_point.x),
				0 if is_equal_approx(closest_point_on_segment_uncapped.y, previous_point.y) else sign(closest_point_on_segment_uncapped.y - previous_point.y)
			)
			var sign_point_minus_closest_point_on_segment_uncapped = Vector2(
				0 if is_equal_approx(point.x, closest_point_on_segment_uncapped.x) else sign(point.x - closest_point_on_segment_uncapped.x),
				0 if is_equal_approx(point.y, closest_point_on_segment_uncapped.y) else sign(point.y - closest_point_on_segment_uncapped.y)
			)
			var closest_point_on_segment
			
			match sign(previous_point - point):
				sign_closest_point_on_segment_uncapped_minus_previous_point:
					closest_point_on_segment = previous_point
				sign_point_minus_closest_point_on_segment_uncapped:
					closest_point_on_segment = point
				_:
					closest_point_on_segment = closest_point_on_segment_uncapped
			
			if !Geometry2D.intersect_polyline_with_polygon([hearing_point, closest_point_on_segment + normal], global_polygon).is_empty():
				previous_point = point
				
				continue
			
			var vector_to_segment = (closest_point_on_segment - hearing_point).rotated(-global_rotation)
			var distance_to_segment = vector_to_segment.length()
			
			if distance_to_segment > max_distance:
				previous_point = point
				
				continue
			
			var combined_distance_to_segment = abs(vector_to_segment.x) + abs(vector_to_segment.y)
			var weight = (1 - distance_to_segment / max_distance) ** attenuation * min(previous_point.distance_to(point) / max_distance, 1)
			
			horizontal_distance_to_segment_sum += vector_to_segment.x / combined_distance_to_segment * weight
			vertical_distance_to_segment_sum += vector_to_segment.y / combined_distance_to_segment * weight
			weight_sum += weight
			
			if distance_to_segment < min_distance_to_segment:
				min_distance_to_segment = distance_to_segment
			
			previous_point = point
		
		if min_distance_to_segment == INF:
			return
		
		var angle = (1 - horizontal_distance_to_segment_sum / weight_sum) * PI / 2
		
		if vertical_distance_to_segment_sum < 0:
			angle = -angle
		
		global_position = hearing_point + Vector2(cos(angle), sin(angle)).rotated(global_rotation) * min_distance_to_segment
	
	polygon *= Transform2D(0, (global_position - _previous_global_transform.origin).rotated(-global_rotation) / global_scale)
	
	_previous_global_transform = global_transform

func _draw():
	if !Engine.is_editor_hint() || polygon.size() < 2:
		return
	
	var closed_polygon = polygon.duplicate()
	
	closed_polygon.push_back(polygon[0])
	
	draw_polyline(closed_polygon, Color8(253, 113, 79), 2)
