extends "res://addons/gut/test.gd"

## Oleada infinita del tutorial: 5 goblins con garrote al iniciar con respawn,
## defensor ImperioMan inmortal, menú "Sube al segundo piso" y BasicAreaVFX_03.

const ESCENA_TUTORIAL: String = "res://Levels/NIVEL_TUTORIAL/NIVEL_TUTORIAL.tscn"
const ESCENA_IMPERIO_MAN: PackedScene = preload("res://Entities/Enemigo_ImperioMan/ImperioMan.tscn")
const ESCENA_GARROTE: PackedScene = preload("res://Entities/Enemigo_Goblin_Garrote/GoblinGarrote.tscn")
const ESCENA_FLECHA: PackedScene = preload("res://Entities/Proyectil_Flecha/Arrow.tscn")

var _nivel: Node = null


func after_each() -> void:
	if is_instance_valid(_nivel):
		_nivel.free()
		_nivel = null


func _cargar_nivel() -> Node:
	var escena := load(ESCENA_TUTORIAL) as PackedScene
	assert_not_null(escena, "NIVEL_TUTORIAL.tscn debe cargar sin errores")
	_nivel = escena.instantiate()
	get_tree().root.add_child(_nivel)
	return _nivel


func _garrotes_vivos(nivel: Node) -> int:
	var n := 0
	for g in (nivel.get("_garrotes") as Array):
		if is_instance_valid(g) and not (g as Node).is_queued_for_deletion():
			n += 1
	return n


## 1. Al iniciar hay 5 goblins con garrote.
func test_oleada_inicial_cinco_garrotes() -> void:
	# Arrange & Act
	var nivel := _cargar_nivel()

	# Assert
	assert_eq((nivel.get("_garrotes") as Array).size(), 5, "Debe haber 5 puestos de garrote")
	assert_eq(_garrotes_vivos(nivel), 5, "Los 5 deben estar vivos al iniciar")
	assert_almost_eq(float((nivel.get("_garrotes") as Array)[0].get("velocidad_correr")), 1.2, 0.01, "Más lentos que lo normal (2.2)")


## 2. Al morir uno, reaparece (respawn infinito).
func test_garrote_respawnea_tras_morir() -> void:
	# Arrange
	var nivel := _cargar_nivel()
	var prota := nivel.get_node_or_null("Player")
	if prota != null and "health" in prota:
		prota.set("health", 9999)
	var garrotes := nivel.get("_garrotes") as Array
	assert_eq(_garrotes_vivos(nivel), 5, "Precondición: 5 vivos")
	(garrotes[0] as Node).call("take_damage", 99999.0)

	# Act: esperar respawn (intervalo 2.0 + polls de 0.3)
	await get_tree().create_timer(3.0).timeout

	# Assert
	assert_eq(_garrotes_vivos(nivel), 5, "Debe reaparecer: oleada infinita")


## 3. El defensor ImperioMan con inmortal ignora todo daño.
func test_imperioman_inmortal_ignora_dano() -> void:
	# Arrange
	var defensor = ESCENA_IMPERIO_MAN.instantiate()
	add_child_autofree(defensor)
	defensor.set("inmortal", true)
	var vida_inicial: int = int(defensor.get("health"))

	# Act
	defensor.call("take_damage", 500.0)
	defensor.call("take_damage", 500.0)

	# Assert
	assert_eq(int(defensor.get("health")), vida_inicial, "Inmortal no pierde vida")


## 4. Menú negro translúcido arriba a la izquierda con el texto.
func test_menu_sube_segundo_piso_en_tutorial() -> void:
	# Arrange & Act
	var nivel := _cargar_nivel()

	# Assert
	var menu := nivel.get_node_or_null("MenuSubeSegundoPiso")
	assert_not_null(menu, "Debe existir MenuSubeSegundoPiso")
	var panel := nivel.get_node_or_null("MenuSubeSegundoPiso/Panel")
	assert_not_null(panel, "Debe tener Panel")
	var texto := nivel.get_node_or_null("MenuSubeSegundoPiso/Panel/Texto") as Label
	assert_not_null(texto, "Debe tener Texto")
	assert_eq(texto.text, "Sube al segundo piso", "Texto del menú")
	assert_lt(panel.position.x + panel.size.x * 0.5, 400.0, "Arriba a la izquierda")


## 5. BasicAreaVFX_03 instanciado para posicionar en editor.
func test_basic_area_vfx_03_en_tutorial() -> void:
	# Arrange & Act
	var nivel := _cargar_nivel()

	# Assert
	var vfx := nivel.get_node_or_null("BasicAreaVFX_03")
	assert_not_null(vfx, "Debe existir BasicAreaVFX_03 para posicionarlo")


class DobleConVida extends Node3D:
	var health: int = 5


func _crear_doble(grupo: String, pos: Vector3) -> DobleConVida:
	var doble := DobleConVida.new()
	doble.add_to_group(grupo)
	add_child_autofree(doble)
	doble.global_position = pos
	return doble


func _crear_garrote(pos: Vector3) -> Node:
	var escena: PackedScene = load("res://Entities/Enemigo_Goblin_Garrote/GoblinGarrote.tscn")
	var garrote = escena.instantiate()
	add_child_autofree(garrote)
	(garrote as Node3D).global_position = pos
	return garrote


## 6. Riposta: cada 3 bloqueos contrataca solo con enemigo a melee en rango.
func test_imperioman_riposta_cada_tres_bloqueos() -> void:
	# Arrange: defensor en modo riposta + enemigo a la izquierda en rango
	var defensor = ESCENA_IMPERIO_MAN.instantiate()
	add_child_autofree(defensor)
	defensor.set("riposta_cada_bloqueos", 3)
	var enemigo := _crear_doble("enemies", (defensor as Node3D).global_position + Vector3(-1.0, 0.0, 0.0))
	var vida: int = int(defensor.get("health"))

	# Act: 2 bloqueos
	assert_true(bool(defensor.call("recibir_golpe_melee", 1.0)), "Debe bloquear")
	assert_true(bool(defensor.call("recibir_golpe_melee", 1.0)), "Debe bloquear")

	# Assert: sin atacar y sin daño
	assert_ne(int(defensor.get("current_state")), 1, "Aún no contrataca (van 2)")
	assert_eq(int(defensor.get("health")), vida, "Bloqueado no daña")

	# Act: 3er bloqueo con enemigo en rango
	defensor.call("recibir_golpe_melee", 1.0)

	# Assert: contrataca con espada (ATTACKING = 1)
	assert_eq(int(defensor.get("current_state")), 1, "Al 3er bloqueo contrataca")
	assert_eq(int(defensor.get("health")), vida, "La riposta no le cuesta vida")


## 7. Sin riposta mantiene la conducta clásica (el melee daña).
func test_imperioman_sin_riposta_conducta_clasica() -> void:
	# Arrange
	var defensor = ESCENA_IMPERIO_MAN.instantiate()
	add_child_autofree(defensor)
	defensor.set("riposta_cada_bloqueos", 0)
	var vida: int = int(defensor.get("health"))

	# Act
	var bloqueo: bool = bool(defensor.call("recibir_golpe_melee", 2.0))

	# Assert
	assert_false(bloqueo, "Sin modo riposta no bloquea")
	assert_eq(int(defensor.get("health")), vida - 2, "El melee daña como antes")


## 8. El garrote prioriza al defensor si se le ordena; si no, a la prota.
func test_garrote_prioriza_defensor_sobre_prota() -> void:
	# Arrange: prota a la izquierda, defensor en medio
	var prota := _crear_doble("player", Vector3(-5.0, 0.0, 0.0))
	var defensor := _crear_doble("allies", Vector3(-2.0, 0.0, 0.0))
	var garrote = _crear_garrote(Vector3.ZERO)

	# Act + Assert: por defecto va a por la protagonista
	assert_eq((garrote as Node).call("_buscar_objetivo_cercano"), prota, "Por defecto ataca a la prota")

	# Act: modo oleada tutorial
	(garrote as Node).set("priorizar_defensores", true)

	# Assert: se queda con el defensor (bloquea el paso)
	assert_eq((garrote as Node).call("_buscar_objetivo_cercano"), defensor, "Priorizando va al defensor")


## 9. La flecha de la protagonista daña al garrote aunque tenga recibir_golpe.
func test_flecha_jugadora_dana_garrote() -> void:
	# Arrange: garrote vivo y flecha encima
	var garrote = ESCENA_GARROTE.instantiate()
	add_child_autofree(garrote)
	(garrote as Node3D).global_position = Vector3(5.0, 0.0, 0.0)
	var flecha = ESCENA_FLECHA.instantiate()
	add_child_autofree(flecha)
	(flecha as Node3D).global_position = Vector3(5.0, 0.0, 0.0)
	var vida: int = int(garrote.get("health"))

	# Act: impacto directo al cuerpo
	flecha.call("_on_body_entered", garrote)

	# Assert: con 1 de vida debe morir, no ignorar la flecha
	assert_lt(int(garrote.get("health")), vida, "La flecha debe dañar al garrote")


## 10. En puesto fijo mira a la derecha y no se voltea tras atacar.
func test_imperioman_puesto_fijo_mira_derecha_sin_voltearse() -> void:
	# Arrange: como en el tutorial (estatico, riposta, puesto 90°)
	var defensor = ESCENA_IMPERIO_MAN.instantiate()
	defensor.set("estatico", true)
	defensor.set("riposta_cada_bloqueos", 3)
	defensor.set("rotacion_y_puesto", 270.0)
	add_child_autofree(defensor)
	var modelo := (defensor as Node).find_child("Modelo", true, false) as Node3D
	assert_not_null(modelo, "Debe tener Modelo")
	assert_almost_eq(modelo.rotation_degrees.y, 270.0, 1.0, "Mira al otro lado, escudo a los goblins")

	# Act: termina un ataque (antes giraba a TURNING y se volteaba)
	defensor.call("_cambiar_estado", 1)
	defensor.call("_process_attacking", float(defensor.get("duracion_ataque_total")) + 0.1)

	# Assert: vuelve a defender sin girar (DEFENDING = 2)
	assert_eq(int(defensor.get("current_state")), 2, "En puesto fijo vuelve a DEFENDING")
	assert_almost_eq(modelo.rotation_degrees.y, 270.0, 1.0, "Sin voltearse")


## 11. La riposta también alcanza enemigos a la derecha (ataque simétrico).
func test_imperioman_riposta_lado_derecho() -> void:
	# Arrange: enemigo a la derecha en rango
	var defensor = ESCENA_IMPERIO_MAN.instantiate()
	add_child_autofree(defensor)
	defensor.set("riposta_cada_bloqueos", 3)
	_crear_doble("enemies", (defensor as Node3D).global_position + Vector3(1.0, 0.0, 0.0))
	var vida: int = int(defensor.get("health"))

	# Act: 3 bloqueos
	defensor.call("recibir_golpe_melee", 1.0)
	defensor.call("recibir_golpe_melee", 1.0)
	defensor.call("recibir_golpe_melee", 1.0)

	# Assert: contrataca y sin daño
	assert_eq(int(defensor.get("current_state")), 1, "Al 3er bloqueo contrataca a la derecha")
	assert_eq(int(defensor.get("health")), vida, "Bloqueado no daña")
