extends "res://addons/gut/test.gd"

## Tests unitarios del defensor Imperio Man (clase guardián cuerpo a cuerpo,
## ALIADO): protege a protagonista y defensoras, ataca solo enemigos con su
## tajo, sin daño crítico, con espada imperial y escudo destruible.

const ESCENA_IMPERIO: PackedScene = preload("res://Entities/Enemigo_ImperioMan/ImperioMan.tscn")


class DummyPlayer extends Node3D:
	var health: int = 10

	func _ready() -> void:
		add_to_group("player")
		add_to_group("allies")

	func take_damage(_amount: float) -> void:
		health -= 1


class DummyEnemy extends CharacterBody3D:
	var health: int = 5
	var dano_recibido: int = 0
	var last_hit_position: Vector3 = Vector3.ZERO
	var ultimo_atacante: Node = null

	func _ready() -> void:
		add_to_group("enemies")

	func take_damage(amount: float) -> void:
		dano_recibido += int(amount)
		health -= int(amount)


func _crear_imperio() -> ImperioMan:
	var imperio: ImperioMan = ESCENA_IMPERIO.instantiate() as ImperioMan
	add_child_autofree(imperio)
	imperio.global_position = Vector3.ZERO
	return imperio


func test_instancia_aliada_con_equipo() -> void:
	# Arrange & Act
	var imperio: ImperioMan = _crear_imperio()

	# Assert
	assert_true(imperio.is_in_group("allies"), "Debe estar en el grupo allies")
	assert_false(imperio.is_in_group("enemies"), "Jamás debe estar en enemies")
	assert_eq(imperio.health, 10, "Debe tener 10 de vida")
	var espada: Node3D = imperio.find_child("EspadaImperial", true, false) as Node3D
	assert_not_null(espada, "Espada imperial en mano derecha")
	var attach_escudo: Node = imperio.find_child("BoneAttachment_Escudo", true, false)
	assert_not_null(attach_escudo, "Attachment de escudo en mano izquierda")
	var escudo: Node3D = imperio._nodo_escudo_mano()
	assert_not_null(escudo, "Escudo élfico en mano izquierda")
	assert_true((escudo as Node).find_children("*", "MeshInstance3D", true, false).size() > 0, "El escudo debe tener malla")


func test_tajo_dana_enemigos_y_nunca_al_jugador() -> void:
	# Arrange
	var imperio: ImperioMan = _crear_imperio()
	var enemigo := DummyEnemy.new()
	add_child_autofree(enemigo)
	enemigo.global_position = Vector3(-1.0, 0.0, 0.0)
	var jugador := DummyPlayer.new()
	add_child_autofree(jugador)
	jugador.global_position = Vector3(-1.0, 0.0, 0.0)

	# Act
	imperio._golpe_espada()

	# Assert
	assert_gt(enemigo.dano_recibido, 0, "El tajo debe dañar enemigos en rango")
	assert_eq(enemigo.dano_recibido, 2, "El tajo hace 2 de daño cuerpo a cuerpo")
	assert_eq(enemigo.ultimo_atacante, imperio, "Debe registrar autoría del golpe")
	assert_eq(jugador.health, 10, "Jamás debe dañar a la protagonista")


func test_sin_dano_critico_en_ataque() -> void:
	# Arrange
	var imperio: ImperioMan = _crear_imperio()
	imperio._cambiar_estado(ImperioMan.State.ATTACKING)
	var vida_antes: int = imperio.health

	# Act
	imperio.take_damage(1.0)

	# Assert: sin bono de vulnerabilidad
	assert_eq(imperio.health, vida_antes - 1, "Sin daño crítico en animación")
	assert_false(imperio.es_momento_golpe_critico(), "Sin momento vulnerable")


func test_estatico_no_se_desplaza() -> void:
	# Arrange
	var imperio: ImperioMan = _crear_imperio()
	imperio.estatico = true
	var x_inicial: float = imperio.global_position.x

	# Act: varios frames de patrulla que en modo normal caminaría
	for i in range(20):
		imperio._physics_process(0.05)

	# Assert
	assert_almost_eq(imperio.global_position.x, x_inicial, 0.05, "Estatico no debe moverse")


func test_escudo_elfico_texturado_en_mano() -> void:
	# Arrange
	var imperio: ImperioMan = _crear_imperio()
	var escudo: Node3D = imperio._nodo_escudo_mano()

	# Act & Assert: mallas del escudo con la textura élfica aplicada
	var mallas: Array = (escudo as Node).find_children("*", "MeshInstance3D", true, false)
	assert_gt(mallas.size(), 0, "El escudo debe tener mallas")
	for m in mallas:
		var mi := m as MeshInstance3D
		assert_not_null(mi.material_override, "Cada malla del escudo lleva material")


func test_muerte_disuelve_y_emite_died() -> void:
	# Arrange
	var imperio: ImperioMan = _crear_imperio()
	var senal_emitida: bool = false
	imperio.died.connect(func(): senal_emitida = true)

	# Act
	imperio.take_damage(99.0)
	assert_eq(imperio.current_state, ImperioMan.State.DYING, "Debe entrar en DYING")
	await wait_seconds(1.8)

	# Assert
	assert_true(senal_emitida, "Debe emitir died al disolverse")
	assert_false(is_instance_valid(imperio), "Debe liberarse tras la disolución")


func test_escudo_mano_marcado_como_defensa_aliada() -> void:
	# Arrange
	var imperio: ImperioMan = _crear_imperio()

	# Act: áreas del escudo de mano (las flechas del jugador las ignoran si no son enemigas)
	var areas: Array = imperio.find_children("*", "Area3D", true, false)
	assert_gt(areas.size(), 0, "El escudo de mano debe tener Area3D")

	# Assert: ninguna debe figurar como escudo enemigo (si no, el jugador podría dañarlo)
	for area in areas:
		if "es_escudo_enemigo" in area:
			assert_false(bool(area.get("es_escudo_enemigo")), "El escudo aliado no es escudo enemigo")
		if "es_pilar_enemigo" in area:
			assert_false(bool(area.get("es_pilar_enemigo")), "El escudo aliado no es pilar enemigo")


func test_no_ataca_sin_enemigos() -> void:
	# Arrange: puesto fijo como en el tutorial, sin enemigos en la escena
	var imperio: ImperioMan = _crear_imperio()
	imperio.estatico = true

	# Act: varios frames de lógica (en modo normal antes atacaba por temporizador)
	for i in range(20):
		imperio._physics_process(0.05)

	# Assert: queda defendiendo en idle, jamás en ATTACKING
	assert_eq(imperio.current_state, ImperioMan.State.DEFENDING, "Sin enemigos no ejecuta ataque")


func test_ataca_cuando_enemigo_entra_en_rango() -> void:
	# Arrange: puesto fijo con un enemigo dentro del alcance de espada
	var imperio: ImperioMan = _crear_imperio()
	imperio.estatico = true
	var enemigo := DummyEnemy.new()
	add_child_autofree(enemigo)
	enemigo.global_position = Vector3(-1.0, 0.0, 0.0)

	# Act
	for i in range(5):
		imperio._physics_process(0.05)

	# Assert
	assert_eq(imperio.current_state, ImperioMan.State.ATTACKING, "Con enemigo en rango sí ataca")


func test_disolucion_amarilla_como_enemigos() -> void:
	# Arrange
	var imperio: ImperioMan = _crear_imperio()

	# Assert: mismo amarillo de EnemyBase (1.0, 0.6, 0.2)
	assert_eq(imperio.color_borde_disolucion, Color(1.0, 0.6, 0.2), "Disolución amarilla de enemigos")


func test_tajo_dana_solo_un_enemigo_con_multiples_en_rango() -> void:
	# Arrange
	var imperio: ImperioMan = _crear_imperio()
	var enemigo_a := DummyEnemy.new()
	add_child_autofree(enemigo_a)
	enemigo_a.global_position = Vector3(-0.8, 0.0, 0.0)

	var enemigo_b := DummyEnemy.new()
	add_child_autofree(enemigo_b)
	enemigo_b.global_position = Vector3(-1.2, 0.0, 0.0)

	# Act
	imperio._golpe_espada()

	# Assert (AAA): solo un enemigo recibe daño a la vez
	var total_golpeados: int = 0
	if enemigo_a.dano_recibido > 0:
		total_golpeados += 1
	if enemigo_b.dano_recibido > 0:
		total_golpeados += 1

	assert_eq(total_golpeados, 1, "El ataque de espada debe dañar exactamente a un enemigo a la vez")


func test_imperio_man_mantiene_orientacion_derecha_siempre() -> void:
	# Arrange
	var imperio: ImperioMan = _crear_imperio()
	var rot_esperada: float = imperio.rotacion_y_modelo

	# Act: intentar forzar estado TURNING o rotación contraria
	imperio._cambiar_estado(ImperioMan.State.TURNING)
	imperio._physics_process(0.05)

	# Assert (AAA): se mantiene mirando a la derecha y no se queda volteado
	assert_almost_eq(imperio.model_root.rotation_degrees.y, rot_esperada, 0.1, "Siempre debe mirar a la derecha")
	assert_ne(imperio.current_state, ImperioMan.State.TURNING, "No debe quedarse en TURNING volteado")

