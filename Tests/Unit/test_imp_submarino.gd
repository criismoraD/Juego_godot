extends "res://addons/gut/test.gd"

## El Imp corre de la escotilla a su puesto (va_a_correr forzado por el
## submarino) y al llegar hace su ciclo normal de combate con IDLE.

var ImpScript = load("res://Entities/Enemigo_Imp/ImpEnemy.gd")
var _imp = null


func _crear_imp_con_anims() -> void:
	_imp = ImpScript.new()
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	var lib := AnimationLibrary.new()
	lib.add_animation("CORRER", Animation.new())
	lib.add_animation("CAMINAR", Animation.new())
	lib.add_animation("IDLE", Animation.new())
	player.add_animation_library("", lib)
	_imp.add_child(player)
	_imp.anim_player = player
	get_tree().root.add_child(_imp)


func after_each() -> void:
	if is_instance_valid(_imp):
		if _imp.get_parent():
			_imp.get_parent().remove_child(_imp)
		_imp.free()
	_imp = null


func test_imp_corre_escotilla_a_puesto() -> void:
	# Arrange: el submarino fuerza va_a_correr al embarcar
	_crear_imp_con_anims()
	_imp.va_a_correr = true
	# Act: inicia caminata en cubierta
	_imp._on_state_walking()
	# Assert: corre durante el trayecto
	assert_eq(_imp.anim_player.current_animation, "CORRER", "Debe correr de la escotilla al puesto")


func test_imp_en_puesto_hace_ciclo_normal() -> void:
	# Arrange: imp en puesto de combate
	_crear_imp_con_anims()
	# Act: entra a disparar
	_imp._on_state_shooting()
	# Assert: IDLE entre lanzamientos, sin loop de caminata
	assert_eq(_imp.anim_player.current_animation, "IDLE", "En el puesto usa su ciclo normal")
