class_name BarcoCombatePirata
extends BalsaPirataCombate

## Barco pirata de combate: mismo comportamiento que la balsa de combate
## (navegación derecha-izquierda con freno, mezcla pre-posicionada, vida 16,
## destrucción con desintegración). Diferencias: modelo y textura propios.
## No tiene modelo destruido: al hundirse se disuelve intacto (no aparece
## el pecio de balsa).

const MAT_BARCO: Material = preload("res://Entities/Ambiente_Barco_Combate_Pirata/MAT_BARCO_COMBATE_PIRATA.tres")

## Cubiertas medidas del modelo (unidades GLB): {x_min, x_max, y_cima}.
## Proa/babor, cintura y castillo de popa. Deben coincidir con las cajas
## rosadas de la escena (test lo amarra).
const CUBIERTAS_GLB: Array = [
	{"x_min": -0.45, "x_max": -0.10, "y": 0.1175},
	{"x_min": -0.10, "x_max": 0.10, "y": 0.0825},
	{"x_min": 0.10, "x_max": 0.30, "y": 0.2269},
]

var _puestos: Array[Vector3] = []  ## Puestos locales precalculados por cubierta


func _asegurar_materiales() -> void:
	if not MAT_BARCO:
		return
	var modelo := find_child("BarcoModel", true, false)
	if not modelo:
		return
	for m in modelo.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_override = MAT_BARCO


## Sin pecio propio: se hunde y disuelve intacto.
func _sustituir_por_modelo_destruido() -> void:
	pass


## Cubiertas en local del barco (GLB x escala del modelo).
func _cubiertas_local() -> Array:
	var s: float = 1.3
	var modelo := find_child("BarcoModel", true, false) as Node3D
	if is_instance_valid(modelo):
		s = modelo.scale.x
	var decks: Array = []
	for d in CUBIERTAS_GLB:
		decks.append({
			"x_min": float(d["x_min"]) * s,
			"x_max": float(d["x_max"]) * s,
			"y": float(d["y"]) * s,
		})
	return decks


func _construir_cola_mezcla() -> void:
	super._construir_cola_mezcla()
	_construir_puestos_cubiertas()


## Reparte los puestos round-robin entre las 3 cubiertas, centrados en cada una.
func _construir_puestos_cubiertas() -> void:
	_puestos.clear()
	var decks := _cubiertas_local()
	if decks.is_empty() or _total_tripulacion <= 0:
		return
	var por_deck: Array = []
	for d in decks:
		por_deck.append([])
	for i in range(_total_tripulacion):
		(por_deck[i % decks.size()] as Array).append(i)
	var pos_por_indice := {}
	for di in range(decks.size()):
		var miembros: Array = por_deck[di]
		var n: int = miembros.size()
		for k in range(n):
			var t: float = 0.5 if n <= 1 else float(k) / float(n - 1)
			var x: float = lerpf(float(decks[di]["x_min"]), float(decks[di]["x_max"]), t)
			pos_por_indice[miembros[k]] = Vector3(x, float(decks[di]["y"]), 0.0)
	for i in range(_total_tripulacion):
		if pos_por_indice.has(i):
			_puestos.append(pos_por_indice[i])
		else:
			_puestos.append(Vector3(0.0, float(decks[0]["y"]), 0.0))


func _puesto_local(restantes_despues: int) -> Vector3:
	var total: int = maxi(_total_tripulacion, 1)
	var indice: int = clampi(total - 1 - restantes_despues, 0, maxi(_puestos.size() - 1, 0))
	if indice >= 0 and indice < _puestos.size():
		return _puestos[indice]
	return super._puesto_local(restantes_despues)
