extends Control

const FRAME := preload("res://assets/ui/Boss Health bar.webp")
const MATTE_SHADER := preload("res://shaders/slime_sheet.gdshader")
const FRAME_REGION := Rect2(164, 144, 769, 229)
const BAR_SIZE := Vector2(485, 144)

var meter: ProgressBar
var health_tween: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	size = BAR_SIZE
	position += Vector2(-BAR_SIZE.x * 0.5, -56.0)

	var frame := TextureRect.new()
	var art := AtlasTexture.new()
	art.atlas = FRAME
	art.region = FRAME_REGION
	art.filter_clip = true
	frame.texture = art
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.size = BAR_SIZE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var material := ShaderMaterial.new()
	material.shader = MATTE_SHADER
	material.set_shader_parameter("trim_pale_edge", false)
	material.set_shader_parameter("matte_lightness", Vector2(0.74, 0.91))
	frame.material = material
	add_child(frame)

	var title := Label.new()
	title.text = "THE GRAVE-LORD"
	title.position = Vector2(0.0, 40.0)
	title.size.x = BAR_SIZE.x
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_outline_color", Color("#171020"))
	title.add_theme_constant_override("outline_size", 6)
	add_child(title)

	meter = ProgressBar.new()
	meter.position = Vector2(45.0, 80.0)
	meter.size = Vector2(395.0, 20.0)
	meter.show_percentage = false
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#925be0")
	fill.set_corner_radius_all(4)
	meter.add_theme_stylebox_override("fill", fill)
	add_child(meter)

func reveal(max_health: int) -> void:
	meter.max_value = max_health
	meter.value = 0
	modulate.a = 0.0
	var entrance := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	entrance.tween_property(self, "modulate:a", 1.0, 0.5)
	entrance.tween_property(self, "offset_top", 8.0, 0.58)
	entrance.tween_property(self, "offset_bottom", 8.0 + BAR_SIZE.y, 0.58)
	health_tween = create_tween()
	health_tween.tween_property(meter, "value", float(max_health), 0.75).set_delay(0.12)

func update_health(value: int) -> void:
	if health_tween != null:
		health_tween.kill()
	health_tween = create_tween()
	health_tween.tween_property(meter, "value", float(value), 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
