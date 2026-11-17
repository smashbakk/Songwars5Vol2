extends Control

var texture: Texture2D
var locked := false
var elapsed := 0.0
var portrait_material: ShaderMaterial

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if texture:
		var portrait := TextureRect.new()
		portrait.texture = texture
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_SCALE
		portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var shader := Shader.new()
		shader.code = "shader_type canvas_item;\nuniform bool locked = false;\nuniform bool active = false;\nuniform vec2 crop_scale = vec2(1.0);\nvoid fragment(){ vec2 image_uv = vec2(0.5 + (UV.x - 0.5) * crop_scale.x, UV.y * crop_scale.y); vec4 c = texture(TEXTURE, image_uv); if (UV.x < (1.0-UV.y)*0.11 || UV.x > 1.0-UV.y*0.11) discard; float edge = min(min(UV.x - (1.0-UV.y)*0.11, 1.0-UV.y*0.11-UV.x), min(UV.y, 1.0-UV.y)); if (edge < 0.012) c.rgb = mix(c.rgb, vec3(0.15,0.72,1.0), locked ? 0.4 : 0.75 + 0.2 * sin(TIME * (active ? 5.0 : 2.5))); if (locked) { float g = dot(c.rgb, vec3(0.299,0.587,0.114)); c.rgb = mix(c.rgb, vec3(g)*vec3(0.48,0.60,0.75),0.75); } COLOR = c; }"
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("locked", locked)
		portrait.material = mat
		portrait_material = mat
		resized.connect(_update_crop)
		_update_crop()
		add_child(portrait)
		move_child(portrait, 0)
	show_behind_parent = false

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	var points := PackedVector2Array([Vector2(size.x * .11, 1), Vector2(size.x - 1, 1), Vector2(size.x * .89, size.y - 1), Vector2(1, size.y - 1), Vector2(size.x * .11, 1)])
	var pulse := 0.68 + 0.22 * sin(elapsed * 2.5)
	draw_polyline(points, Color(0.17, 0.72, 1.0, pulse if not locked else .35), 2.0, true)

func set_active(value: bool) -> void:
	if portrait_material:
		portrait_material.set_shader_parameter("active", value)

# Keep the full top of the portrait in the short, wide select cards.
func _update_crop() -> void:
	if portrait_material and size.x > 0.0 and size.y > 0.0:
		portrait_material.set_shader_parameter("crop_scale", Vector2(minf(1.0, size.x / size.y), minf(1.0, size.y / size.x)))
