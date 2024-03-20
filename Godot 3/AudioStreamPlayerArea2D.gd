tool
class_name AudioStreamPlayerArea2D
extends AudioStreamPlayer2D

export(PoolVector2Array) var polygon setget set_polygon # must be clockwise
var previous_hearing_point
var previous_global_transform

onready var viewport = get_viewport() # update manually if changed

func set_polygon(value):
	polygon = value
	
	update()

func _ready():
	if Engine.is_editor_hint() || polygon.empty():
		set_process(false)
		
		return
	
	position += polygon[0]
	
	polygon = Transform2D(0, -polygon[0]).xform(polygon)
	
	move_toward_hearing_point()

# Process after moving the current camera (and calling
# force_update_scroll() on it), by using lower tree order or higher
# process_priority. Consider disabling processing when far away.
func _process(_delta):
	move_toward_hearing_point()

func move_toward_hearing_point():
	var hearing_point = viewport.canvas_transform.affine_inverse().xform(viewport.get_visible_rect().size / 2)
	
	if hearing_point == previous_hearing_point && global_transform == previous_global_transform:
		return
	
	previous_hearing_point = hearing_point
	previous_global_transform = global_transform
	
	var global_polygon = global_transform.xform(polygon)
	
	if Geometry.is_point_in_polygon(hearing_point, global_polygon):
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
			
			match Vector2(sign(previous_point.x - point.x), sign(previous_point.y - point.y)):
				sign_closest_point_on_segment_uncapped_minus_previous_point:
					closest_point_on_segment = previous_point
				sign_point_minus_closest_point_on_segment_uncapped:
					closest_point_on_segment = point
				_:
					closest_point_on_segment = closest_point_on_segment_uncapped
			
			if !Geometry.intersect_polyline_with_polygon_2d([hearing_point, closest_point_on_segment + normal], global_polygon).empty():
				previous_point = point
				
				continue
			
			var vector_to_segment = (closest_point_on_segment - hearing_point).rotated(-global_rotation)
			var distance_to_segment = vector_to_segment.length()
			
			if distance_to_segment > max_distance:
				previous_point = point
				
				continue
			
			var combined_distance_to_segment = abs(vector_to_segment.x) + abs(vector_to_segment.y)
			var weight = pow((1 - distance_to_segment / max_distance), attenuation) * min(previous_point.distance_to(point) / max_distance, 1)
			
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
	
	self.polygon = Transform2D(0, (previous_global_transform.origin - global_position).rotated(-global_rotation) / global_scale).xform(polygon)
	
	previous_global_transform = global_transform

func _draw():
	if !Engine.is_editor_hint() || polygon.size() < 2:
		return
	
	var closed_polygon = PoolVector2Array(polygon)
	
	closed_polygon.push_back(polygon[0])
	
	draw_polyline(closed_polygon, Color8(253, 113, 79), 2)
