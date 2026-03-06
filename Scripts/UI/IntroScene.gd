extends Control

@onready var title_label: Label = $TitleLabel
@onready var wip_image: TextureRect = $ContentPanel/LeftPanel/WipImage
@onready var story_label: Label = $ContentPanel/RightPanel/StoryClip/StoryLabel
@onready var story_clip: Control = $ContentPanel/RightPanel/StoryClip
@onready var skip_button: Button = $SkipButton
@onready var fade_overlay: ColorRect = $FadeOverlay

const SCROLL_SPEED := 25.0  # pixels per second
const SCROLL_PAUSE_START := 2.0  # seconds before scrolling begins

var scrolling := false
var scroll_finished := false
var transitioning := false
var story_end_y := 0.0

func _ready() -> void:
	fade_overlay.color = Color(0, 0, 0, 1)
	fade_overlay.visible = true

	# Start intro music (main theme)
	AudioManager.play_music(1) # BGM_main_theme.mp3

	# Set translated text
	title_label.text = tr("INTRO_TITLE")
	story_label.text = tr("INTRO_STORY")

	# Connect skip button
	skip_button.pressed.connect(_on_skip_pressed)

	# Wait a frame so label sizes are calculated
	await get_tree().process_frame
	await get_tree().process_frame

	# Text starts at position 0 (visible at top of clip area)
	story_label.position.y = 0.0

	# End position: text has scrolled fully above the clip area
	story_end_y = -story_label.size.y - 40.0

	# Fade in
	var tween = create_tween()
	tween.tween_property(fade_overlay, "color:a", 0.0, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(SCROLL_PAUSE_START)
	tween.tween_callback(func(): scrolling = true)

func _process(delta: float) -> void:
	if not scrolling or scroll_finished:
		return

	story_label.position.y -= SCROLL_SPEED * delta

	# Check if scroll is done
	if story_label.position.y <= story_end_y:
		story_label.position.y = story_end_y
		scroll_finished = true
		scrolling = false
		await get_tree().create_timer(2.0).timeout
		_go_to_game()

func _on_skip_pressed() -> void:
	_go_to_game()

func _go_to_game() -> void:
	if transitioning:
		return
	transitioning = true
	set_process(false)

	var tween = create_tween()
	tween.tween_property(fade_overlay, "color:a", 1.0, 0.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tween.finished.connect(func():
		get_tree().change_scene_to_file("res://Scenes/Levels/NIVEL01.tscn")
	)
