class_name Perrena
extends "res://Entities/Jugador_Arquera/Player.gd"

## Perrena — defensora controlable (variante de la protagonista):
## - Movimientos completos de la protagonista (correr, saltar, agacharse, escaleras).
## - Su ataque principal es la JABALINA del Imp: trayectoria parabólica con arco.
## - Mantiene el HUD y sistema de corazones de la protagonista (señales heredadas).
## - Como defensora invocable tiene 3 de vida (vida_maxima).

const JABALINA_SCENE: PackedScene = preload("res://Entities/Proyectil_Tridente_Imp/ImpTrident.tscn")
const POOL_REF = preload("res://System/Core/ProjectilePool.gd")
const MAT_PERRENA: Material = preload("res://Entities/Jugador_Perrena/PERRENA_MAT.tres")

## El GLB de Perrena trae el rig raíz (Armature) a escala 0.01 (mixamo).
## ESCALA_MODELO compensa para que mida lo mismo que la protagonista.
const ESCALA_MODELO: float = 96.0

## Mapeo de clips del GLB de Perrena -> nombres que el AnimationTree del Player espera.
## Debe registrarse ANTES de que el Player construya su árbol dinámico.
const MAPEO_ANIMS: Dictionary = {
	"Idle": "Armature|Armature|IDLE",
	"Caminar": "Armature|Armature|CAMINAR_ADELANTE",
	"Correr": "Armature|Armature|CORRER_ADELANTE",
	"Disparo arco": "Armature|Armature|DISPARAR",
	"arrojar": "Armature|Armature|TOMAR_FLECHA",
	"Aterrizar": "Armature|Armature|ATERRIZAJE",
	"Saltar": "Armature|Armature|CAER_SALTAR",
	"agacharse": "Armature|Armature|CAER_SALTAR",
	"pararse": "Armature|Armature|IDLE",
	"Muerte 1": "Armature|Armature|MUERTE",
	# Equivalentes aproximados para los estados restantes del árbol del Player
	"@caminar_atras": "Armature|Armature|CAMINAR_ATRAS",
	"@apuntar": "Armature|Armature|APUNTAR_IDLE",
	"@escalar": "Armature|Armature|SUBIR_ESCALERA",
}
const SUBSTITUCIONES_ANIMS: Dictionary = {
	"@caminar_atras": "Caminar",
	"@apuntar": "Idle",
	"@escalar": "Caminar",
}

## Jabalina: arco parabólico configurable (mismos valores base del Imp)
@export_category("Jabalina - Perrena")
@export var arco_altura_min: float = 0.8
@export var arco_altura_max: float = 1.6
@export var gravedad_jabalina: float = 1.0


func _ready():
	# 1. Conectar el AnimationTree al AnimationPlayer del GLB de Perrena
	var tree := find_child("AnimationTree", true, false) as AnimationTree
	var anim_p := find_child("AnimationPlayer", true, false) as AnimationPlayer
	if tree and anim_p:
		tree.anim_player = tree.get_path_to(anim_p)

	# 2. Corregir escala del rig mixamo (0.01 embebido) y aplicar textura
	var modelo := find_child("PerrenaModel", true, false) as Node3D
	if not modelo:
		modelo = find_child("Perrena", true, false) as Node3D
	if modelo:
		modelo.scale = Vector3.ONE * ESCALA_MODELO
		for mesh in modelo.find_children("*", "MeshInstance3D", true, false):
			(mesh as MeshInstance3D).material_override = MAT_PERRENA

	# 3. Registrar los alias de animación ANTES de que el Player construya
	#    su árbol dinámico (si no, los nodos quedarían con clips inexistentes)
	if anim_p:
		_remapear_animaciones_perrena(anim_p)

	# 4. Ahora sí: inicialización completa del Player (árbol, hitbox, sombra, etc.)
	super._ready()


## El AnimationTree dinámico del Player usa nombres "Armature|Armature|XXX" del
## GLB de la protagonista. Perrena trae sus clips con otros nombres: se registran
## alias en la librería para que el árbol los encuentre sin tocar el Player.
func _remapear_animaciones_perrena(anim_p: AnimationPlayer) -> void:
	var lib := anim_p.get_animation_library("")
	if not lib:
		return
	for clip_origen in MAPEO_ANIMS.keys():
		var clip_destino: String = MAPEO_ANIMS[clip_origen]
		if anim_p.has_animation(clip_destino):
			continue
		# Los "@..." usan una animación sustituta de otro clip del mapeo
		var buscar: String = SUBSTITUCIONES_ANIMS.get(clip_origen, clip_origen)
		# Buscar el clip origen por nombre exacto o prefijado
		for candidato in anim_p.get_animation_list():
			if candidato.ends_with(buscar) and not lib.has_animation(clip_destino):
				lib.add_animation(clip_destino, anim_p.get_animation(candidato))
				break


func _init() -> void:
	# Defensora: 3 corazones de vida (los movimientos/HUD se heredan del Player)
	vida_maxima = 3


## Ataque principal: jabalina parabólica del Imp en lugar de la flecha recta.
## El resto del flujo de disparo (múltiples, explosivas, screen shake, sonido)
## se conserva del Player; solo cambia el proyectil NORMAL.
func spawn_arrow_projectile():
	# Calcular datos de disparo (dirección al mouse, origen, carga)
	var data = calculate_shoot_data()
	if not data["valid"]:
		return

	var shoot_dir: Vector3 = data["velocity"].normalized()
	var jab_speed: float = lerp(velocidad_flecha_minima, velocidad_flecha_maxima, last_charge_power)

	# CASO 1: Flechas Múltiples activas (igual que la protagonista)
	if municion_activa == TipoMunicion.MULTIPLE and flechas_multiples > 0:
		super.spawn_arrow_projectile()
		return

	# CASO 2: Flechas Explosivas activas (igual que la protagonista)
	if municion_activa == TipoMunicion.EXPLOSIVA and flechas_explosivas > 0:
		super.spawn_arrow_projectile()
		return

	# CASO PRINCIPAL: jabalina del Imp con arco parabólico
	AudioManager.play_sfx("trident_shot")

	var jabalina := POOL_REF.acquire(JABALINA_SCENE) as ImpTridentProjectile
	if not jabalina:
		return
	jabalina.scale = Vector3.ONE

	# Arco parabólico: sumar altura al cálculo de dirección (mismo patrón del Imp)
	var arco: float = randf_range(arco_altura_min, arco_altura_max)
	var dir_con_arco: Vector3 = shoot_dir + Vector3(0.0, arco * 0.35, 0.0)
	dir_con_arco = dir_con_arco.normalized()

	jabalina.initialize(dir_con_arco, jab_speed / 8.0)
	jabalina.gravedad = gravedad_jabalina

	POOL_REF.activate(jabalina, get_tree().root, data["origin"])

	# Game feel: screen shake como al disparar la protagonista
	if has_node("/root/GameFeel"):
		get_node("/root/GameFeel").on_player_shoot()
