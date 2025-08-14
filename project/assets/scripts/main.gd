extends Node2D

@export var particle_boundry := Vector2(4000,4000)
@export var particle_amount := 6400
@export var max_distance := 80.
@export var friction_factor := 0.75
@export var force_factor := 100.
@export var particle_color : PackedColorArray

var particle_attract : PackedFloat32Array
var rd := RenderingServer.get_rendering_device()

var last_mouse_position := Vector2.ZERO
var panning := false

var pipeline1
var pipeline2
var uniform_set1
var uniform_set2
var params_buffer
var globals_buffer
var position_buffer
var velocity_buffer
var type_buffer
var attract_buffer
var particle_index_buffer
var cell_buffer
var start_buffer
var particle_data

func _ready():
	var terminal = get_tree().root.get_node("Marksman_Terminal")
	if terminal != null:
		terminal.add_command("reset",_load,[])
	_load()

func _load():
	for i in range(len(particle_color)):
		for k in range(len(particle_color)):
			particle_attract.append(randf_range(-1.0,1.0))
		
	_create_compute2("particle_life", "spatial_hash")
	#_create_compute1("basic/particle_life2D_Basic")
	
	# Camera!
	$Camera.position = particle_boundry/2.0
	# Get Particle 2D ready
	$GPUParticles2D.visibility_rect = Rect2(0.0,0.0,particle_boundry.x,particle_boundry.y)
	
	$GPUParticles2D.amount = particle_amount
	$GPUParticles2D.process_material.set_shader_parameter("colors",particle_color)
	$GPUParticles2D.process_material.get_shader_parameter("particle_data").texture_rd_rid = particle_data
	
	# Debug things
	$Stats/BufferView.material.get_shader_parameter("rendered_image").texture_rd_rid = particle_data

func _input(event):
	
	_ui()
	
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT):
		if event.pressed: panning = true
		else: panning = false
	
	if (event is InputEventMouseMotion and panning):
		$Camera.position -= event.relative / $Camera.zoom
		
	if (event is InputEventMouseButton):
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			$Camera.zoom *= Vector2(1.1,1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			$Camera.zoom /= Vector2(1.1,1.1)

func _process(delta):
	
	$Stats/FPS.text = " FPS: " + str(Engine.get_frames_per_second())
	$Stats/DT.text = " Delta Time: " + str(delta)
	
	if Input.is_action_just_pressed("ui_accept"):
		$Stats.visible = not($Stats.visible)
	
	var packed_delta_time = PackedFloat32Array([delta]).to_byte_array()
	
	var keys = rd.buffer_get_data(cell_buffer).to_float32_array()
	var start = rd.buffer_get_data(start_buffer).to_int32_array()
	#var i = 0;
	#var temp = []
	#while i < keys.size():
		#temp.append(keys[i])
		#i+=3;
	#print(temp)
	
	var compute_list2 := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list2, pipeline2)
	rd.compute_list_bind_uniform_set(compute_list2, uniform_set2, 0)
	rd.compute_list_dispatch(compute_list2, ceili(particle_amount/32), 1, 1)
	rd.compute_list_end()
	
	var compute_list1 := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list1, pipeline1)
	rd.compute_list_bind_uniform_set(compute_list1, uniform_set1, 0)
	rd.compute_list_dispatch(compute_list1, ceili(particle_amount/32), 1, 1)
	rd.compute_list_end()
	
	#print(keys[0]," ",keys[1]," ",keys[2])
	#print(start)
	rd.buffer_update(globals_buffer,0,4,packed_delta_time)

func _ui():
	var debugView = Vector4.ZERO
	
	if $"Stats/Buffer Settings/VBoxContainer/Pos_X/CheckBox".button_pressed: debugView.x = 1.0
	if $"Stats/Buffer Settings/VBoxContainer/Pos_Y/CheckBox".button_pressed: debugView.y = 1.0
	if $"Stats/Buffer Settings/VBoxContainer/Type/CheckBox".button_pressed: debugView.z = 1.0
	
	$Stats/BufferView.material.set_shader_parameter("display",debugView)

func _create_compute1(file1:String):
	
	var shader_file1 := load("res://assets/compute/"+file1+".glsl") # Load files	
	var shader_spirv1: RDShaderSPIRV = shader_file1.get_spirv()
	var shader1 = rd.shader_create_from_spirv(shader_spirv1)
	
	pipeline1 = rd.compute_pipeline_create(shader1)
	
	var params := PackedFloat32Array([particle_boundry.x,particle_boundry.y,particle_amount,sqrt(len(particle_attract)),max_distance,friction_factor,force_factor])
	var params_bytes := params.to_byte_array() # Params to bytecode
	
	params_buffer = rd.storage_buffer_create(params_bytes.size(), params_bytes)
	var params_uniform := RDUniform.new()
	params_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	params_uniform.binding = 0
	params_uniform.add_id(params_buffer)
	
	var globals := PackedFloat32Array([0.0])
	var globals_bytes := globals.to_byte_array() # Globals to bytecode
	
	globals_buffer = rd.storage_buffer_create(globals_bytes.size(), globals_bytes)
	var globals_uniform := RDUniform.new()
	globals_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	globals_uniform.binding = 1
	globals_uniform.add_id(globals_buffer)
	
	var positions := PackedVector2Array()
	var velocities := PackedVector2Array()
	var types := PackedInt32Array()
	
	for i in range(particle_amount):
		positions.append(Vector2(randf_range(10.0,particle_boundry.x-10.0),randf_range(10.0,particle_boundry.y-10.0)))
		velocities.append(Vector2.ZERO)
		types.append(i%len(particle_color))
	
	var positions_bytes := positions.to_byte_array() # Positions to bytecode
	var velocities_bytes := velocities.to_byte_array() # Materials to bytecode
	var type_bytes := types.to_byte_array() # Materials to bytecode
	var attract_bytes := particle_attract.to_byte_array() # Attract matrix to bytes

	position_buffer = rd.storage_buffer_create(positions_bytes.size(), positions_bytes)
	var position_uniform := RDUniform.new()
	position_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	position_uniform.binding = 2
	position_uniform.add_id(position_buffer)
	
	velocity_buffer = rd.storage_buffer_create(velocities_bytes.size(), velocities_bytes)
	var velocity_uniform := RDUniform.new()
	velocity_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	velocity_uniform.binding = 3
	velocity_uniform.add_id(velocity_buffer)
	
	type_buffer = rd.storage_buffer_create(type_bytes.size(), type_bytes)
	var type_uniform := RDUniform.new()
	type_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	type_uniform.binding = 4
	type_uniform.add_id(type_buffer)
	
	attract_buffer = rd.storage_buffer_create(attract_bytes.size(), attract_bytes)
	var attract_uniform := RDUniform.new()
	attract_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	attract_uniform.binding = 5
	attract_uniform.add_id(attract_buffer)
	
	# Texture Buffers
	var fmt := RDTextureFormat.new()
	fmt.width = sqrt(particle_amount)
	fmt.height = sqrt(particle_amount)
	fmt.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	var view := RDTextureView.new()
	
	var output_tex := Image.create(particle_amount,1,false,Image.FORMAT_RGBAF)
	
	# Position
	particle_data = rd.texture_create(fmt,view,[output_tex.get_data()])
	var particle_uniform := RDUniform.new()
	particle_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	particle_uniform.binding = 9
	particle_uniform.add_id(particle_data)
	
	var uniforms = [
		params_uniform,
		globals_uniform,
		position_uniform,
		velocity_uniform,
		type_uniform,
		attract_uniform,
		particle_uniform
	]
	
	uniform_set1 = rd.uniform_set_create(uniforms, shader1, 0)
	
func _create_compute2(file1:String,file2:String):
	
	var shader_file1 := load("res://assets/compute/"+file1+".glsl") # Load files
	var shader_file2 := load("res://assets/compute/"+file2+".glsl")
	
	var shader_spirv1: RDShaderSPIRV = shader_file1.get_spirv()
	var shader_spirv2: RDShaderSPIRV = shader_file2.get_spirv()
	
	var shader1 = rd.shader_create_from_spirv(shader_spirv1)
	var shader2 = rd.shader_create_from_spirv(shader_spirv2)
	
	pipeline1 = rd.compute_pipeline_create(shader1)
	pipeline2 = rd.compute_pipeline_create(shader2)
	
	var params := PackedFloat32Array([particle_boundry.x,particle_boundry.y,particle_amount,sqrt(len(particle_attract)),max_distance,friction_factor,force_factor])
	var params_bytes := params.to_byte_array() # Params to bytecode
	
	params_buffer = rd.storage_buffer_create(params_bytes.size(), params_bytes)
	var params_uniform := RDUniform.new()
	params_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	params_uniform.binding = 0
	params_uniform.add_id(params_buffer)
	
	var globals := PackedFloat32Array([0.0])
	var globals_bytes := globals.to_byte_array() # Globals to bytecode
	
	globals_buffer = rd.storage_buffer_create(globals_bytes.size(), globals_bytes)
	var globals_uniform := RDUniform.new()
	globals_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	globals_uniform.binding = 1
	globals_uniform.add_id(globals_buffer)
	
	var positions := PackedVector2Array()
	var velocities := PackedVector2Array()
	var types := PackedInt32Array()
	var particle_index := PackedInt32Array()
	var cells := PackedVector3Array()
	var start := PackedInt32Array()
	
	for i in range(particle_amount):
		positions.append(Vector2(randf_range(10.0,particle_boundry.x-10.0),randf_range(10.0,particle_boundry.y-10.0)))
		velocities.append(Vector2.ZERO)
		types.append(i%len(particle_color))
		particle_index.append(i)
		
	cells = _init_spatial(positions)
	start = _init_start(cells)
	
	var positions_bytes := positions.to_byte_array() # Positions to bytecode
	var velocities_bytes := velocities.to_byte_array() # Materials to bytecode
	var type_bytes := types.to_byte_array() # Materials to bytecode
	var attract_bytes := particle_attract.to_byte_array() # Attract matrix to bytes
	var particle_index_bytes := particle_index.to_byte_array() # Particle Indexing
	var cell_bytes := cells.to_byte_array() # Cell keys to bytes
	var start_bytes := start.to_byte_array() # Start indicies to bytes

	position_buffer = rd.storage_buffer_create(positions_bytes.size(), positions_bytes)
	var position_uniform := RDUniform.new()
	position_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	position_uniform.binding = 2
	position_uniform.add_id(position_buffer)
	
	velocity_buffer = rd.storage_buffer_create(velocities_bytes.size(), velocities_bytes)
	var velocity_uniform := RDUniform.new()
	velocity_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	velocity_uniform.binding = 3
	velocity_uniform.add_id(velocity_buffer)
	
	type_buffer = rd.storage_buffer_create(type_bytes.size(), type_bytes)
	var type_uniform := RDUniform.new()
	type_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	type_uniform.binding = 4
	type_uniform.add_id(type_buffer)
	
	attract_buffer = rd.storage_buffer_create(attract_bytes.size(), attract_bytes)
	var attract_uniform := RDUniform.new()
	attract_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	attract_uniform.binding = 5
	attract_uniform.add_id(attract_buffer)
	
	particle_index_buffer = rd.storage_buffer_create(particle_index_bytes.size(), particle_index_bytes)
	var particle_index_uniform := RDUniform.new()
	particle_index_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	particle_index_uniform.binding = 6
	particle_index_uniform.add_id(particle_index_buffer)
	
	cell_buffer = rd.storage_buffer_create(cell_bytes.size(), cell_bytes)
	var cell_uniform := RDUniform.new()
	cell_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	cell_uniform.binding = 7
	cell_uniform.add_id(cell_buffer)
	
	start_buffer = rd.storage_buffer_create(start_bytes.size(), start_bytes)
	var start_uniform := RDUniform.new()
	start_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	start_uniform.binding = 8
	start_uniform.add_id(start_buffer)
	
	# Texture Buffers
	var fmt := RDTextureFormat.new()
	fmt.width = sqrt(particle_amount)
	fmt.height = sqrt(particle_amount)
	fmt.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	var view := RDTextureView.new()
	
	var output_tex := Image.create(particle_amount,1,false,Image.FORMAT_RGBAF)
	
	# Position
	particle_data = rd.texture_create(fmt,view,[output_tex.get_data()])
	var particle_uniform := RDUniform.new()
	particle_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	particle_uniform.binding = 9
	particle_uniform.add_id(particle_data)
	
	var uniforms = [
		params_uniform,
		globals_uniform,
		position_uniform,
		velocity_uniform,
		type_uniform,
		attract_uniform,
		particle_index_uniform,
		cell_uniform,
		start_uniform,
		particle_uniform
	]
	
	uniform_set1 = rd.uniform_set_create(uniforms, shader1, 0)
	uniform_set2 = rd.uniform_set_create(uniforms, shader2, 0)

func _init_spatial(positions:PackedVector2Array):
	var spatial_data = []
	for i in range(len(positions)):
		
		var cell : Vector2i = floor(positions[i] / max_distance)
		var hash_value = (cell.x*15823*12582917) + (cell.y*15823*12582917)
		var key = hash_value % 100
		
		spatial_data.append(Vector3i(i,hash_value,key))
	
	spatial_data.sort_custom(func(a,b): return a.x < b.x)
	
	return spatial_data
	
func _init_start(spatial_data:PackedVector3Array):
	var start = PackedInt32Array()
	var last_instance = -1
	for i in range(len(spatial_data)):
		if int(spatial_data[i].z) != last_instance:
			start.append(int(spatial_data[i].z))
			start.append(i)
			last_instance = int(spatial_data[i].z)
	return start
