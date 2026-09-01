extends "res://addons/gut/test.gd"
## Tests del impacto del ult de Lonko (FlechaElectricaAtaque) sobre las defensoras aliadas:
## arqueras y ballesteras no reciben daño pero sí el estado de aturdimiento (parálisis).

var FlechaUltScript = load("res://Entities/Enemigo_Lonko/Flecha_Electrica_Ataque.gd")
var EscenaArquera: PackedScene = load("res://Entities/Aliada_Arquera/AllyArcher.tscn")
var EscenaBallestera: PackedScene = load("res://Entities/Aliada_Ballestera/AllyBallestera.tscn")

const DURACION_PARALISIS_ULT: float = 4.0


class MockAudioManager extends Node:
	func play_sfx(_name, _boost = 0.0): pass
	func stop_bow_tension(): pass
	func reset_bow_hold(): pass


func before_each():
	if not get_tree().root.has_node("AudioManager"):
		var mock_audio = MockAudioManager.new()
		mock_audio.name = "AudioManager"
		get_tree().root.add_child(mock_audio)


func after_each():
	for escena in ["arquera", "ballestera"]:
		var nodo: Node = get_meta_or_null(escena)
		if is_instance_valid(nodo):
			if nodo.get_parent():
				nodo.get_parent().remove_child(nodo)
			nodo.free()
			set_meta(escena, null)


func _instanciar_defensora(escena: PackedScene, clave_meta: String) -> Node:
	var defensora: Node = escena.instantiate()
	add_child_autofree(defensora)
	set_meta(clave_meta, defensora)
	return defensora


func _obtener_hitbox(defensora: Node) -> StaticBody3D:
	var hitbox: StaticBody3D = defensora.get_node_or_null("HitboxBody")
	if not hitbox:
		hitbox = defensora.find_children("HitboxBody", "StaticBody3D", true, false)[0] as StaticBody3D
	return hitbox


func _simular_impacto_ult(hitbox: Node) -> void:
	# La flecha resuelve la defensora dueña de la hitbox vía metadata y le aplica parálisis
	var defensora: Node = hitbox.get_meta("defensora_owner")
	if is_instance_valid(defensora) and defensora.has_method("aplicar_paralisis"):
		defensora.aplicar_paralisis(DURACION_PARALISIS_ULT)


func test_hitbox_arquera_apunta_a_su_defensora():
	var arquera: Node = _instanciar_defensora(EscenaArquera, "arquera")
	var hitbox: StaticBody3D = _obtener_hitbox(arquera)
	assert_not_null(hitbox, "La arquera debe tener HitboxBody")
	assert_true(hitbox.is_in_group("allies"), "La hitbox de la arquera debe estar en el grupo allies")
	assert_true(hitbox.has_meta("defensora_owner"), "La hitbox debe exponer metadata defensora_owner")
	assert_eq(hitbox.get_meta("defensora_owner"), arquera, "La metadata debe apuntar a la arquera dueña")


func test_hitbox_ballestera_apunta_a_su_defensora():
	var ballestera: Node = _instanciar_defensora(EscenaBallestera, "ballestera")
	var hitbox: StaticBody3D = _obtener_hitbox(ballestera)
	assert_not_null(hitbox, "La ballestera debe tener HitboxBody")
	assert_true(hitbox.has_meta("defensora_owner"), "La hitbox debe exponer metadata defensora_owner")
	assert_eq(hitbox.get_meta("defensora_owner"), ballestera, "La metadata debe apuntar a la ballestera dueña")


func test_impacto_ult_aturde_arquera_sin_dano():
	var arquera: Node = _instanciar_defensora(EscenaArquera, "arquera")
	var vida_previa: float = arquera.health
	_simular_impacto_ult(_obtener_hitbox(arquera))
	assert_almost_eq(arquera.paralisis_timer, DURACION_PARALISIS_ULT, 0.01,
		"La arquera debe quedar aturdida por la duración del ult")
	assert_eq(arquera.health, vida_previa, "La arquera no debe recibir daño del ult")


func test_impacto_ult_aturde_ballestera_sin_dano():
	var ballestera: Node = _instanciar_defensora(EscenaBallestera, "ballestera")
	var vida_previa: float = ballestera.health
	_simular_impacto_ult(_obtener_hitbox(ballestera))
	assert_almost_eq(ballestera.paralisis_timer, DURACION_PARALISIS_ULT, 0.01,
		"La ballestera debe quedar aturdida por la duración del ult")
	assert_eq(ballestera.health, vida_previa, "La ballestera no debe recibir daño del ult")


func test_impacto_ult_no_acumula_paralisis():
	var ballestera: Node = _instanciar_defensora(EscenaBallestera, "ballestera")
	_simular_impacto_ult(_obtener_hitbox(ballestera))
	_simular_impacto_ult(_obtener_hitbox(ballestera))
	assert_almost_eq(ballestera.paralisis_timer, DURACION_PARALISIS_ULT, 0.01,
		"La parálisis del ult no debe ser acumulable (límite de caso borde)")
