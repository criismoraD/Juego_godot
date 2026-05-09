extends "res://addons/gut/test.gd"

var AudioManagerScript = load("res://Scripts/Core/AudioManager.gd")
var _audio_manager = null

func before_each():
	_audio_manager = AudioManagerScript.new()
	# We add it to the tree to trigger _ready, which calls _setup_players and _load_all_sounds
	get_tree().root.add_child(_audio_manager)

func after_each():
	if is_instance_valid(_audio_manager):
		_audio_manager.get_parent().remove_child(_audio_manager)
		_audio_manager.free()

func test_get_music_player_returns_correct_node():
	var music_player = _audio_manager.get_music_player()
	assert_not_null(music_player, "Music player should not be null")
	assert_true(music_player is AudioStreamPlayer, "Should return an AudioStreamPlayer")
	assert_eq(music_player, _audio_manager.music_player, "Should return the internal music_player instance")
	assert_eq(music_player.name, "Music_Player", "Music player name should be correct")

func test_get_sfx_player_returns_correct_node():
	var sfx_player = _audio_manager.get_sfx_player()
	assert_not_null(sfx_player, "SFX player should not be null")
	assert_true(sfx_player is AudioStreamPlayer, "Should return an AudioStreamPlayer")
	assert_eq(sfx_player, _audio_manager.sfx_player, "Should return the internal sfx_player instance")
	assert_eq(sfx_player.name, "SFX_Player", "SFX player name should be correct")
