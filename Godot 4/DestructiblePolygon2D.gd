@tool
extends Node2D

@export var collidable: bool: set = set_collidable
@export var free_when_empty: bool
# Vertices are deleted if they are less than this number of pixels away from both adjacent vertices.
# A higher value increases performance, but reduces visual and area calculation accuracy.
@export_range(0, 16) var simplification := 8.0

@onready var has_been_collidable = collidable

func _ready():
	if Engine.is_editor_hint():
		return
	
	if collidable:
		for polygon_2d in get_children():
			add_collision_polygon(polygon_2d)
			
			update_bounds_and_area(polygon_2d, polygon_2d.polygon)
	else:
		for polygon_2d in get_children():
			update_bounds_and_area(polygon_2d, polygon_2d.polygon)

# Clips a PackedVector2Array against itself at the specified position, and returns the destructed area in pixels.
func destruct(polygon, at_global_position = Vector2.ZERO):
	var mask = Transform2D(0, at_global_position - global_position) * polygon
	var minX = INF
	var minY = INF
	var maxX = -INF
	var maxY = -INF
	
	for point in mask:
		minX = min(minX, point.x)
		minY = min(minY, point.y)
		maxX = max(maxX, point.x)
		maxY = max(maxY, point.y)
	
	var mask_bounds = Rect2(minX, minY, maxX - minX, maxY - minY)
	var area_sum = 0
	var empty = free_when_empty
	
	for polygon_2d in get_children():
		if polygon_2d.get_meta('bounds').intersects(mask_bounds):
			var old_area = polygon_2d.get_meta('area')
			var new_area = destruct_child(polygon_2d, mask)
			
			area_sum += old_area - new_area
			
			if new_area > 0:
				empty = false
		else:
			empty = false
	
	if empty:
		queue_free()
	
	return area_sum

func destruct_child(polygon_2d, mask):
	var clipped_polygons = Geometry2D.clip_polygons(polygon_2d.polygon, mask)
	
	match clipped_polygons.size():
		0:
			polygon_2d.queue_free()
			
			return 0
		1:
			var polygon = polygon_2d.polygon
			var polygon_size = polygon.size()
			var polygon_changed = polygon_size != clipped_polygons[0].size()
			
			if !polygon_changed:
				var index = clipped_polygons[0].find(polygon[0])
				
				if index == -1:
					polygon_changed = true
				else:
					for j in range(1, polygon_size):
						if clipped_polygons[0][(index + j) % polygon_size] != polygon[j]:
							polygon_changed = true
							
							break
			
			if !polygon_changed:
				return polygon_2d.get_meta('area')
		2:
			if Geometry2D.is_polygon_clockwise(clipped_polygons[1]):
				var boundary_size = clipped_polygons[0].size()
				var hole_size = clipped_polygons[1].size()
				
				for i in boundary_size:
					var link1 = [clipped_polygons[0][i], null]
					
					for j in hole_size:
						link1[1] = clipped_polygons[1][j]
						
						if !Geometry2D.clip_polyline_with_polygon(link1, clipped_polygons[0]).is_empty():
							continue
						
						if !Geometry2D.intersect_polyline_with_polygon(link1, clipped_polygons[1]).is_empty():
							continue
						
						for k in range(i + 1, boundary_size):
							var link2 = [clipped_polygons[0][k], null]
							
							for l in hole_size:
								if l == j:
									continue
								
								link2[1] = clipped_polygons[1][l]
								
								if !Geometry2D.clip_polyline_with_polygon(link2, clipped_polygons[0]).is_empty():
									continue
								
								if !Geometry2D.intersect_polyline_with_polygon(link2, clipped_polygons[1]).is_empty():
									continue
								
								if Geometry2D.segment_intersects_segment(link1[0], link1[1], link2[0], link2[1]) != null:
									continue
								
								var part1 = PackedVector2Array()
								var part2 = PackedVector2Array()
								
								for m in boundary_size:
									if m >= i && m <= k:
										part1.push_back(clipped_polygons[0][m])
									
									if m <= i:
										part2.push_back(clipped_polygons[0][m])
									
									if m >= k:
										part2.insert(m - k, clipped_polygons[0][m])
								
								var m = l
								
								while true:
									part1.push_back(clipped_polygons[1][m])
									
									if m == j:
										break
									
									m = (m + 1) % hole_size
								
								while true:
									part2.push_back(clipped_polygons[1][m])
									
									if m == l:
										break
									
									m = (m + 1) % hole_size
								
								var area1 = update_or_create(polygon_2d, part1, part1.size(), false)
								var area2 = update_or_create(polygon_2d, part2, part2.size(), true)
								
								return area1 + area2
	
	var area_sum = 0
	
	for i in clipped_polygons.size():
		area_sum += update_or_create(polygon_2d, clipped_polygons[i], clipped_polygons[i].size(), i > 0)
	
	return area_sum

func update_or_create(polygon_2d, polygon, size, new):
	if size > 128:
		var i = size / 2
		var step = 1
		
		while true:
			for j in size:
				var k = (j + i) % size
				
				if !Geometry2D.clip_polyline_with_polygon([polygon[j], polygon[k]], polygon).is_empty():
					continue
				
				var part1 = PackedVector2Array()
				var part2 = PackedVector2Array()
				var l = j
				
				while true:
					part1.push_back(polygon[l])
					
					if l == k:
						break
					
					l = (l + 1) % size
				
				while true:
					part2.push_back(polygon[l])
					
					if l == j:
						break
					
					l = (l + 1) % size
				
				var area1 = update_or_create(polygon_2d, part1, i + 1, new)
				var area2 = update_or_create(polygon_2d, part2, size - i + 1, true)
				
				return area1 + area2
			
			i += step
			
			step = -step
			step += sign(step)
	
	if simplification > 0:
		var simplified_polygon = PackedVector2Array()
		var previous_point = polygon[polygon.size() - 1]
		var previous_distance = previous_point.distance_to(polygon[polygon.size() - 2])
		
		for point in polygon:
			var distance = point.distance_to(previous_point)
			
			if previous_distance >= simplification || distance >= simplification:
				simplified_polygon.push_back(previous_point)
				
				previous_distance = distance
			else:
				previous_distance += distance
			
			previous_point = point
		
		if simplified_polygon.size() < 3:
			if !new:
				polygon_2d.queue_free()
			
			return 0
		
		polygon = simplified_polygon
	
	if new:
		polygon_2d = polygon_2d.duplicate()
		# polygon_2d.modulate = Color(randf(), randf(), randf())
		
		call_deferred('add_child', polygon_2d)
	
	polygon_2d.polygon = polygon
	
	if has_been_collidable:
		polygon_2d.get_child(0).get_child(0).polygon = polygon
	
	return update_bounds_and_area(polygon_2d, polygon)

func update_bounds_and_area(polygon_2d, polygon):
	var minX = INF
	var minY = INF
	var maxX = -INF
	var maxY = -INF
	var area = 0
	var previous_point = polygon[polygon.size() - 1]
	
	for point in polygon:
		minX = min(minX, point.x)
		minY = min(minY, point.y)
		maxX = max(maxX, point.x)
		maxY = max(maxY, point.y)
		
		area += previous_point.x * point.y
		area -= previous_point.y * point.x
		
		previous_point = point
	
	polygon_2d.set_meta('bounds', Rect2(minX, minY, maxX - minX, maxY - minY))
	polygon_2d.set_meta('area', area / 2)
	
	return area / 2

func add_collision_polygon(polygon_2d):
	var static_body_2d = StaticBody2D.new()
	var collision_polygon_2d = CollisionPolygon2D.new()
	
	collision_polygon_2d.polygon = polygon_2d.polygon
	
	static_body_2d.add_child(collision_polygon_2d)
	polygon_2d.add_child(static_body_2d)

func set_collidable(value):
	collidable = value
	
	if Engine.is_editor_hint() || !is_inside_tree():
		return
	
	if collidable:
		if has_been_collidable:
			for polygon_2d in get_children():
				polygon_2d.get_child(0).get_child(0).set_deferred('disabled', false)
		else:
			for polygon_2d in get_children():
				add_collision_polygon(polygon_2d)
			
			has_been_collidable = true
	elif has_been_collidable:
		for polygon_2d in get_children():
			polygon_2d.get_child(0).get_child(0).set_deferred('disabled', true)

func _get_configuration_warnings():
	var children = get_children()
	
	for child in children:
		if !child is Polygon2D:
			return ['A DestructiblePolygon2D may only have Polygon2D children.']
	
	if children.size() == 0:
		return ['A DestructiblePolygon2D requires at least one Polygon2D child to define its initial polygon(s).']
	
	return []
