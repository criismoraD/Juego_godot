class_name JefeSubmarinoRio
extends SubmarinoRio

## Jefe Submarino del nivel rÃ­o: reutiliza emerger / plataforma / caÃ±Ã³n de
## SubmarinoRio y aÃ±ade vida 43, barra de vida y bucle Fase1 <-> Fase2.
## Fase1: emerge con 7 piratas + 3 arqueras goblin + 3 imp. Termina al morir
##   la oleada o al recibir 16 de daÃ±o: caÃ±Ã³n final y hundimiento.
## Fase2: se hunde fuera de cÃ¡mara, reaparece sumergido al fondo, dispara 6
##   misiles al cielo que caen en 2 tandas de 3 sobre la canoa centrada.
##   Al resolverse los 6, vuelve a Fase1 hasta ser destruido.

signal vida_cambiada(actual: int, maxima: int)
signal fase_cambiada(nueva_fase: int)
signal jefe_derrotado
signal combate_iniciado

enum FaseJefe { FASE1, TRANSICION_FASE2, FASE2 }

const ESCENA_MISIL: PackedScene = preload("res://Entities/Proyectil_Misil_Submarino/MisilSubmarino.tscn")
const ESCENA_MINA: PackedScene = preload("res://Entities/Proyectil_Mina_Acuatica/MinaAcuatica.tscn")
const ESCENA_GARGOLA: PackedScene = preload("res://Entities/Enemigo_Gargola/Gargola.tscn")
const UMBRAL_VIDA_DANADO: int = 15
const ESCENA_HUMO_ESTILIZADO: PackedScene = preload("res://Levels/Rio_En_Canoa_Con_Parallax/HumoEstilizadoJefe.tscn")
const ESCENA_SUBMARINO_DESTRUIDO: PackedScene = preload("res://Levels/Rio_En_Canoa_Con_Parallax/Modelos/Submarino destruido/Submarino destruido.glb")
const MAT_SUBMARINO_DESTRUIDO: StandardMaterial3D = preload("res://Levels/Rio_En_Canoa_Con_Parallax/SubmarinoDestruido_Mat.tres")
const ESCENA_VFX_BIG_IMPACT_02: PackedScene = preload("res://HitFXFree/assets/BinbunVFX_Vol2/StylizedHitFX/effects/big_impact/vfx_big_impact_02.tscn")
const SFX_BARCO_HUNDIMIENTO: AudioStream = preload("res://Levels/Rio_En_Canoa_Con_Parallax/Audio/Barco pirata hundimiento.mp3")
const ESCENA_EXPLOSION_PILAR: PackedScene = preload("res://Entities/Enemigo_Lonko/Explocion_Pilar.tscn")
const TEXTURA_PIEDRAS_NEGRAS_RES: Texture2D = preload("res://Entities/Enemigo_Lonko/PIEDRAS_NEGRAS_ DESTRUCION.png")
const SFX_EXPLOSION_01: AudioStream = preload("res://Entities/Enemigo_Lonko/EXPLOSION01.mp3")
const SFX_EXPLOSION_02: AudioStream = preload("res://Entities/Enemigo_Lonko/EXPLOSION02.mp3")
const SCRIPT_CANON_VOLADOR: Script = preload("res://Levels/Rio_En_Canoa_Con_Parallax/CanonDestruidoVolador.gd")

const OFFSETS_EXPLOSIONES_CADENA: Array[Vector3] = [
	Vector3(-1.8, 1.2, 0.2),
	Vector3(-0.4, 1.7, -0.1),
	Vector3(1.5, 1.0, 0.2),
	Vector3(-2.8, 0.9, -0.1),
	Vector3(2.6, 1.1, 0.0),
]

@export_category("Jefe - Vida")
@export var vida_maxima_jefe: int = 43
@export var umbral_dano_fase: int = 16

@export_category("Jefe - CaÃ±Ã³n Destruido Volador")
@export var lanzar_canon_destruido: bool = true  ## Si true, expulsa el caÃ±Ã³n destruido volando acrobÃ¡ticamente
@export var impulso_canon_destruido: Vector3 = Vector3(-2.8, 11.2, 1.6)  ## Vector de impulso inicial (hacia arriba y visible al frente)
@export var impulso_tuerca_destruida: Vector3 = Vector3(2.4, 10.2, 1.8)  ## Vector de impulso inicial de la tuerca/rueda (divergente)
@export var variacion_impulso_canon: Vector3 = Vector3(0.8, 1.0, 0.5)  ## Margen aleatorio en los ejes de impulso

@export_category("Jefe - Debug")
@export var permitir_explosion_debug_tecla_x: bool = true  ## Si true, la tecla X detona la destrucciÃ³n inmediata

@export_category("Jefe - DestrucciÃ³n y Hundimiento")
@export var cantidad_explosiones_cadena: int = 5
@export var intervalo_explosiones_cadena: float = 0.14
@export var escala_explosiones_cadena: float = 1.15
@export var paso_cambio_modelo: int = 0
@export var offset_explosion_cola: Vector3 = Vector3(3.2, 0.8, 0.0)
@export var escala_explosion_vfx: float = 1.6
@export var inclinacion_camara_grados: float = 28.0
@export var inclinacion_roll_grados: float = 8.0
@export var duracion_hundimiento_muerte: float = 8.0
@export var profundidad_hundimiento_muerte: float = 7.0
@export var retraso_fin_baile_tras_hundirse: float = 1.5
@export var volumen_inicial_hundimiento_db: float = 2.0
@export var volumen_final_hundimiento_db: float = 9.0

@export_category("Jefe - Estado Dañado (Vida <= 15)")
@export var umbral_vida_danado: int = 15
@export var color_danado_albedo: Color = Color(1.0, 0.45, 0.45)
@export var color_danado_emision: Color = Color(0.5, 0.08, 0.08)
@export var intensidad_emision_danado: float = 0.8
@export var color_danado_canon_albedo: Color = Color(1.0, 0.72, 0.72)
@export var color_danado_canon_emision: Color = Color(0.35, 0.06, 0.06)
@export var intensidad_emision_danado_canon: float = 0.35
@export var offset_humo_superior: Vector3 = Vector3(-0.6, 2.15, 0.0)

@export_category("Jefe - Oleada Fase 1")
@export var oleada_piratas: int = 7
@export var oleada_arqueras: int = 3
@export var oleada_imps: int = 3

const OFFSET_ZONA_VERDE_MIN_X: float = -1.15  ## Popa / remera sentada (Acompanante)
const OFFSET_ZONA_VERDE_MAX_X: float = 1.05   ## Proa / defensora delantera (DefensoraPerrena)

@export_category("Jefe - Fase 2")
@export var profundidad_fase2: float = 2.2
@export var hundimiento_extra_salida: float = 1.6
@export var misiles_totales: int = 6
@export var misiles_por_tanda: int = 3
@export var intervalo_entre_misiles: float = 0.0
@export var intervalo_entre_tandas: float = 2.0
@export var offsets_caida_x: Array[float] = [-0.85, 0.0, 0.85]
@export var offsets_formacion_y: Array[float] = [0.0, 3.2, 1.6]
@export var altura_formacion_y: float = 22.0
@export var altura_caida_y: float = 0.6
@export var posicion_sumergida_fase2: Vector3 = Vector3.ZERO
@export var offset_salida_izquierda: float = 22.0
@export var tiempo_salida_izquierda: float = 4.5

@export_category("Jefe - Fondo Fase 2 (Naufragio)")
@export var fondo_fase2_activo: bool = true  ## Si true, realiza el crucero sumergido de fondo de izquierda a derecha
@export var z_fondo_fase2: float = -39.0  ## Coordenada Z al fondo (donde está el naufragio a ~ -40.95)
@export var y_fondo_fase2: float = -3.2  ## Altura Y sumergido bajo el agua en el canal del fondo
@export var margen_salida_fondo_x: float = 26.0  ## Margen horizontal respecto a la cámara para iniciar y terminar el crucero
@export var duracion_crucero_fondo: float = 12.0  ## Segundos que tarda en recorrer el fondo de izquierda a derecha
@export var escala_modelo_fondo: float = 0.7  ## Escala reducida en el crucero para que parezca más lejos
@export var amplitud_bamboleo_fondo_y: float = 0.22  ## Sube/baja sutil de navegación en metros
@export var periodo_bamboleo_fondo: float = 3.0  ## Segundos por ciclo de bamboleo
@export var amplitud_balanceo_fondo_z: float = 2.5  ## Rolido lateral de navegación en grados
@export var amplitud_cabeceo_fondo_x: float = 1.5  ## Cabeceo de navegación en grados

@export_category("Jefe - Misiles Fondo Cosméticos")
@export var disparar_misiles_fondo_cosmeticos: bool = true  ## Si true, se detiene en el centro y dispara misiles cosméticos hacia arriba
@export var cantidad_misiles_fondo_cosmeticos: int = 3  ## Cantidad de misiles cosméticos disparados hacia arriba
@export var intervalo_misiles_cosmeticos: float = 0.32  ## Rápida sucesión entre cada disparo de misil
@export var pausa_antes_disparo_fondo: float = 0.35  ## Pequeña pausa al detenerse en el naufragio antes de disparar
@export var pausa_despues_disparo_fondo: float = 0.50  ## Pausa tras el último disparo antes de reanudar la marcha
@export var velocidad_subida_misil_fondo: float = 18.0  ## Velocidad vertical de subida de los misiles cosméticos

@export_category("Jefe - Mina Acuática")
@export var mina_offset_cola_x: float = 3.5
@export var mina_offset_frente_z: float = 1.2

@export_category("Jefe - GÃ¡rgolas Fase 2")
@export var gargolas_cantidad: int = 5
@export var gargolas_atacantes_min: int = 2
@export var gargola_rango_mitad_x: float = 3.0
@export var gargola_offset_derecha_x: float = 8.0
@export var gargola_separacion_x: float = 1.5
@export var gargola_altura: float = 4.0
@export var gargola_intervalo: float = 0.0
@export var gargola_velocidad_crucero: float = 2.0
@export var gargola_margen_x: float = 14.0

@export_category("Jefe - Flash de DaÃ±o")
@export var parpadeo_rojo_activo: bool = true
@export var duracion_flash_rojo: float = 0.12
@export var duracion_rojo_destruido: float = 1.0
@export var color_flash_rojo: Color = Color(1.0, 0.0, 0.0)
@export var intensidad_emision_flash: float = 2.0
@export var altura_max_flash: float = 2.2

var vida_actual_jefe: int = 43
var combate_activo: bool = false
var _fase_jefe: FaseJefe = FaseJefe.FASE1
var _dano_fase: int = 0
var _jefe_muerto: bool = false
var _is_invulnerable: bool = false
var _esta_danado: bool = false
var _material_danado: StandardMaterial3D = null
var _material_danado_canon: StandardMaterial3D = null
var _mallas_canon: Array[MeshInstance3D] = []
var _particulas_humo: GPUParticles3D = null
var _misiles: Array = []
var _misiles_resueltos: int = 0
var _tanda_actual: int = 0
var _secuencia_fase2_activa: bool = false
var _mallas_casco_flash: Array[MeshInstance3D] = []
var _originales_flash: Array = []
var _material_flash_rojo: StandardMaterial3D = null
var _flash_seq: int = 0
var _pos_combate: Vector3 = Vector3.ZERO
var _ref_sumergida_valida: bool = false
var _mina: MinaAcuatica = null
var _gargolas: Array = []
var _gargolas_invocadas: bool = false
var _gargolas_forzadas: Array = []
var _gargolas_ataque_forzado: Array = []
var _modelo_destruido_tscn: Node3D = null
var _canon_destruido_lanzado: bool = false
var _crucero_fondo_completado: bool = false
var _misiles_cosmeticos: Array[MisilSubmarino] = []
var _tween_crucero_fondo: Tween = null
var _tiempo_bamboleo_fondo: float = 0.0
var _y_base_bamboleo_fondo: float = 0.0
var _pivot_bamboleo_fondo: Node3D = null
var _escala_previa_fondo: Vector3 = Vector3.ONE
var _escala_fondo_aplicada: bool = false

@onready var _humo_en_escena: GPUParticles3D = get_node_or_null("PivotFlotacion/HumoEstilizadoJefe") as GPUParticles3D


func _ready() -> void:
	# Oleada fija del jefe antes del _ready base (construye la cola de mezcla).
	cantidad_pirata = oleada_piratas
	cantidad_goblin_arquera = oleada_arqueras
	cantidad_imp = oleada_imps
	cantidad_imp_embajador = 0
	mezclar_orden_aleatorio = false
	vida_actual_jefe = vida_maxima_jefe
	# Margen de frenado de la canoa: la proa de la canoa avanza ~2.5 m por delante
	# de su centro. Con margen 4.8 la canoa frena a 7.2 m del centro del submarino,
	# dejando ~1.0 m libre antes de la plataforma sin solapamiento alguno,
	# manteniendo la plataforma y el caÃ±Ã³n en plano visible principal.
	margen_bloqueo_proa = 4.8
	super._ready()
	add_to_group("jefe_submarino")
	if not canon_disparo_final_realizado.is_connected(_al_disparo_lonko_soltar_mina):
		canon_disparo_final_realizado.connect(_al_disparo_lonko_soltar_mina)
	if not emergido.is_connected(_al_emerger_jefe):
		emergido.connect(_al_emerger_jefe)
	_pos_combate = global_position
	_consumir_referencia_sumergida()
	_crear_material_flash_rojo()
	_crear_material_danado()
	_cachear_mallas_casco_flash()
	_asegurar_particulas_humo()
	_buscar_y_configurar_modelo_destruido_tscn()
	vida_cambiada.emit(vida_actual_jefe, vida_maxima_jefe)


## Si existe el submarino de referencia (JefeSubmarino2) en la escena, toma sus
## coordenadas como punto sumergido de fase 2 y lo borra: solo era referencia.
func _consumir_referencia_sumergida() -> void:
	var nivel := get_parent()
	var ref: Node3D = null
	if is_instance_valid(nivel):
		ref = nivel.find_child("JefeSubmarino2", false, false) as Node3D
	if ref == null and get_tree() != null:
		ref = get_tree().get_first_node_in_group("jefe_submarino_ref") as Node3D
	if not is_instance_valid(ref):
		return
	posicion_sumergida_fase2 = (ref as Node3D).global_position
	_ref_sumergida_valida = true
	ref.queue_free()


func _process(_delta: float) -> void:
	if _jefe_muerto:
		return
	if _fase_jefe == FaseJefe.FASE1:
		super._process(_delta)
		_actualizar_humo_segun_superficie()
		return
	# En TRANSICION_FASE2 / FASE2 el movimiento lo llevan los tweens propios:
	# no delegar a la base para que _procesar_estado_sumergiendose no haga queue_free.
	_procesar_crucero_gargolas(_delta)
	_procesar_bamboleo_fondo(_delta)


func _unhandled_input(event: InputEvent) -> void:
	if not permitir_explosion_debug_tecla_x:
		return
	if event is InputEventKey and not event.echo and event.pressed:
		var es_tecla_x: bool = (event.keycode == KEY_X or event.physical_keycode == KEY_X)
		if es_tecla_x:
			explotar_debug()


func emerger() -> void:
	if not combate_activo:
		combate_activo = true
		combate_iniciado.emit()
	super.emerger()


func esta_en_superficie() -> bool:
	if _jefe_muerto:
		return false
	if _fase_jefe != FaseJefe.FASE1:
		return false
	return super.esta_en_superficie()


func es_enemigo_activo() -> bool:
	if _jefe_muerto:
		return false
	if _fase_jefe != FaseJefe.FASE1:
		return false
	return super.es_enemigo_activo()


func obtener_fase() -> int:
	return int(_fase_jefe)


## Fuerza la detonación y secuencia completa de destrucción del jefe inmediatamente (debug).
func explotar_debug() -> void:
	if _jefe_muerto:
		return
	if is_instance_valid(_tween_crucero_fondo) and _tween_crucero_fondo.is_running():
		_tween_crucero_fondo.kill()
	# Si está sumergido, emergiendo o en fase 2, colocarlo en superficie en el punto de combate
	if current_state == State.SUMERGIDO or current_state == State.EMERGIENDO or _fase_jefe != FaseJefe.FASE1:
		_restaurar_escala_fondo()
		_reposar_pivot_bamboleo()
		rotation_degrees = Vector3.ZERO
		global_position = Vector3(_pos_combate.x, _altura_objetivo_y, _pos_combate.z)
		current_state = State.EN_SUPERFICIE
		combate_activo = true
		flotacion_activa = true
		visible = true
	vida_actual_jefe = 0
	vida_cambiada.emit(0, vida_maxima_jefe)
	_morir_jefe()


func take_damage(amount: float) -> void:
	if _jefe_muerto:
		return
	if _is_invulnerable:
		return
	if _fase_jefe != FaseJefe.FASE1 or not super.esta_en_superficie():
		return
	var dano: int = maxi(1, int(amount))
	vida_actual_jefe = maxi(0, vida_actual_jefe - dano)
	_dano_fase += dano
	vida_cambiada.emit(vida_actual_jefe, vida_maxima_jefe)
	if vida_actual_jefe <= 0:
		_morir_jefe()
		return
	if vida_actual_jefe <= umbral_vida_danado and not _esta_danado:
		_activar_estado_danado()
	_parpadear_rojo_impacto()
	if _dano_fase >= umbral_dano_fase:
		_enemigos_restantes_por_spawnear = 0
		_cola_mezcla.clear()
		_iniciar_sumersion()


func _al_emerger_jefe() -> void:
	if _esta_danado and not _jefe_muerto:
		_activar_humo_danado(true)


func _activar_estado_danado() -> void:
	if _esta_danado:
		return
	_esta_danado = true
	_aplicar_material_danado()
	_activar_humo_danado(true)


func _aplicar_material_danado() -> void:
	if _material_danado == null:
		_crear_material_danado()
	if _material_danado_canon == null:
		_crear_material_danado_canon()
	if _mallas_casco_flash.is_empty():
		_cachear_mallas_casco_flash()
	for mi in _mallas_casco_flash:
		if is_instance_valid(mi):
			mi.material_override = _material_danado
	if _mallas_canon.is_empty():
		_cachear_mallas_canon()
	for mi in _mallas_canon:
		if is_instance_valid(mi):
			mi.material_override = _material_danado_canon


func _crear_material_danado() -> void:
	if is_instance_valid(_material_danado):
		return
	if is_instance_valid(material_submarino):
		_material_danado = material_submarino.duplicate() as StandardMaterial3D
	else:
		var mat_path := "res://Levels/Rio_En_Canoa_Con_Parallax/Submarino_Mat.tres"
		if ResourceLoader.exists(mat_path):
			var cargado := load(mat_path) as StandardMaterial3D
			if cargado != null:
				_material_danado = cargado.duplicate() as StandardMaterial3D
	if _material_danado == null:
		_material_danado = StandardMaterial3D.new()
	_material_danado.albedo_color = color_danado_albedo
	_material_danado.emission_enabled = true
	_material_danado.emission = color_danado_emision
	_material_danado.emission_energy_multiplier = intensidad_emision_danado


func _crear_material_danado_canon() -> void:
	if is_instance_valid(_material_danado_canon):
		return
	var mat_path := "res://Levels/Rio_En_Canoa_Con_Parallax/CanonSubmarino_Mat.tres"
	if ResourceLoader.exists(mat_path):
		var cargado := load(mat_path) as StandardMaterial3D
		if cargado != null:
			_material_danado_canon = cargado.duplicate() as StandardMaterial3D
	if _material_danado_canon == null:
		_material_danado_canon = StandardMaterial3D.new()
	_material_danado_canon.albedo_color = color_danado_canon_albedo
	_material_danado_canon.emission_enabled = true
	_material_danado_canon.emission = color_danado_canon_emision
	_material_danado_canon.emission_energy_multiplier = intensidad_emision_danado_canon


func _cachear_mallas_canon() -> void:
	_mallas_canon.clear()
	if not is_instance_valid(_canon_modelo):
		_canon_modelo = find_child("CanonModel", true, false) as Node3D
	if not is_instance_valid(_canon_modelo):
		return
	for m in _canon_modelo.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi != null and is_instance_valid(mi):
			_mallas_canon.append(mi)


func _asegurar_particulas_humo() -> void:
	if is_instance_valid(_particulas_humo):
		return
	if is_instance_valid(_humo_en_escena):
		_particulas_humo = _humo_en_escena
		return
	var existente: Node = find_child("HumoEstilizadoJefe", true, false)
	if is_instance_valid(existente) and existente is GPUParticles3D:
		_particulas_humo = existente as GPUParticles3D
		return
	if ESCENA_HUMO_ESTILIZADO != null:
		var instancia: Node = ESCENA_HUMO_ESTILIZADO.instantiate()
		if instancia is GPUParticles3D:
			_particulas_humo = instancia as GPUParticles3D
			var padre: Node = pivot_flotacion if is_instance_valid(pivot_flotacion) else self
			padre.add_child(_particulas_humo)
			_particulas_humo.position = offset_humo_superior


func _activar_humo_danado(encender: bool) -> void:
	_asegurar_particulas_humo()
	if not is_instance_valid(_particulas_humo):
		return
	_particulas_humo.visible = encender
	_particulas_humo.emitting = encender
	if encender:
		_particulas_humo.restart()


func _actualizar_humo_segun_superficie() -> void:
	if not _esta_danado or _jefe_muerto:
		if is_instance_valid(_particulas_humo) and (_particulas_humo.emitting or _particulas_humo.visible):
			_activar_humo_danado(false)
		return
	var en_sup: bool = esta_en_superficie()
	if en_sup:
		if is_instance_valid(_particulas_humo) and not _particulas_humo.emitting:
			_aplicar_material_danado()
			_activar_humo_danado(true)
	else:
		if is_instance_valid(_particulas_humo) and (_particulas_humo.emitting or _particulas_humo.visible):
			_activar_humo_danado(false)


## Material rojo compartido del flash (mismo que BalsaPirataCombate).
func _crear_material_flash_rojo() -> void:
	if is_instance_valid(_material_flash_rojo):
		return
	_material_flash_rojo = StandardMaterial3D.new()
	_material_flash_rojo.albedo_color = color_flash_rojo
	_material_flash_rojo.emission_enabled = true
	_material_flash_rojo.emission = color_flash_rojo
	_material_flash_rojo.emission_energy_multiplier = maxf(intensidad_emision_flash, 0.1)


func _cachear_mallas_casco_flash() -> void:
	_mallas_casco_flash.clear()
	if not is_instance_valid(_canon_modelo):
		_canon_modelo = find_child("CanonModel", true, false) as Node3D
	var raiz: Node = modelo if is_instance_valid(modelo) else self
	for m in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi == null or not is_instance_valid(mi):
			continue
		if is_instance_valid(_canon_modelo) and (mi == _canon_modelo or _canon_modelo.is_ancestor_of(mi)):
			continue
		_mallas_casco_flash.append(mi)


## Parpadeo rojo al impactar, igual que el BarcoCombatePirata: tiÃ±e el casco
## y restaura tras duracion_flash_rojo. Reiniciable ante impactos rÃ¡pidos.
func _parpadear_rojo_impacto() -> void:
	if not parpadeo_rojo_activo:
		return
	if _jefe_muerto:
		return
	if not is_inside_tree() or get_tree() == null:
		return
	if not is_instance_valid(_material_flash_rojo):
		_crear_material_flash_rojo()
	if _mallas_casco_flash.is_empty():
		_cachear_mallas_casco_flash()
	if _mallas_casco_flash.is_empty():
		return
	_flash_seq += 1
	var seq_actual: int = _flash_seq
	# Solo obra viva: el mÃ¡stil sobre la cubierta no flashea (destello en el cielo).
	var tope_y: float = global_position.y + altura_max_flash
	if _originales_flash.is_empty():
		for mi in _mallas_casco_flash:
			if not is_instance_valid(mi):
				continue
			if mi.global_position.y > tope_y:
				continue
			_originales_flash.append({"mesh": mi, "material": mi.material_override})
	for mi in _mallas_casco_flash:
		if not is_instance_valid(mi):
			continue
		if mi.global_position.y > tope_y:
			continue
		mi.material_override = _material_flash_rojo
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	await tree.create_timer(maxf(duracion_flash_rojo, 0.05)).timeout
	if seq_actual != _flash_seq:
		return
	if _jefe_muerto:
		return
	_restaurar_materiales_flash()


func _restaurar_materiales_flash() -> void:
	var mat_destino: Material = _material_danado if _esta_danado else null
	for item in _originales_flash:
		var mi: MeshInstance3D = item["mesh"] as MeshInstance3D
		if not is_instance_valid(mi):
			continue
		mi.material_override = mat_destino if mat_destino != null else (item["material"] as Material)
	_originales_flash.clear()


## Virtual de la base: en el jefe no libera, encadena a fase 2.
## El disparo Lonko lo ejecuta _entrar_fase2 de forma explÃ­cita.
func _iniciar_sumersion() -> void:
	if _jefe_muerto:
		super._sumergirse_y_liberar()
		return
	if _fase_jefe != FaseJefe.FASE1:
		return
	_entrar_fase2()


func _morir_jefe() -> void:
	if _jefe_muerto:
		return
	if is_instance_valid(_tween_crucero_fondo) and _tween_crucero_fondo.is_running():
		_tween_crucero_fondo.kill()
	_crucero_fondo_completado = true
	_restaurar_escala_fondo()
	_reposar_pivot_bamboleo()
	if _fase_jefe != FaseJefe.FASE1:
		rotation_degrees = Vector3.ZERO
		global_position = Vector3(_pos_combate.x, _altura_objetivo_y, _pos_combate.z)
		visible = true
	_jefe_muerto = true
	combate_activo = false
	_secuencia_fase2_activa = false
	_flash_seq += 1
	_originales_flash.clear()
	_activar_humo_danado(false)
	if is_instance_valid(_mina) and not _mina.is_queued_for_deletion():
		_mina.queue_free()
	_mina = null
	_limpiar_gargolas()
	_matar_enemigos_restantes_en_sumersion()
	_limpiar_misiles()
	_restaurar_travesia()
	_curar_jugador_y_perrena()
	jefe_derrotado.emit()
	_ejecutar_secuencia_destruccion()


func _ejecutar_secuencia_destruccion() -> void:
	current_state = State.SUMERGIENDOSE
	flotacion_activa = false
	_detener_goteo_cubierta()
	_generar_onda_emerger()
	if is_in_group("enemies"):
		remove_from_group("enemies")
	if is_in_group("enemigos"):
		remove_from_group("enemigos")
	_desactivar_colisiones()
	_remover_grupos_enemigos_restantes()

	# Perrena celebra bailando desde la destrucciÃ³n hasta 2 s tras hundirse.
	_iniciar_baile_perrena()

	# 1. Sonido "Barco pirata hundimiento" con volumen en crescendo
	var player_sfx: AudioStreamPlayer3D = _reproducir_sfx_hundimiento_crescendo()

	# 2. Iniciar tween de inclinaciÃ³n hacia la cÃ¡mara y hundimiento lento
	_iniciar_tween_hundimiento_muerte(player_sfx)

	# 3. Iniciar cadena de explosiones sucesivas (idÃ©nticas a las del Globo) camuflando el cambio de modelo
	_iniciar_cadena_explosiones_destruccion()


func _buscar_y_configurar_modelo_destruido_tscn() -> void:
	if not is_instance_valid(_modelo_destruido_tscn):
		_modelo_destruido_tscn = get_node_or_null("Submarino destruido2") as Node3D
	if not is_instance_valid(_modelo_destruido_tscn):
		_modelo_destruido_tscn = find_child("*destruido*", true, false) as Node3D
	if is_instance_valid(_modelo_destruido_tscn):
		_modelo_destruido_tscn.visible = false
		if MAT_SUBMARINO_DESTRUIDO != null:
			_aplicar_material_a_arbol(_modelo_destruido_tscn, MAT_SUBMARINO_DESTRUIDO)


func _aplicar_material_a_arbol(nodo: Node, mat: Material) -> void:
	if not is_instance_valid(nodo) or mat == null:
		return
	for m in nodo.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if is_instance_valid(mi) and mi.mesh != null:
			mi.material_override = mat
			for s in range(mi.mesh.get_surface_count()):
				mi.set_surface_override_material(s, mat)


func _sustituir_por_modelo_destruido() -> void:
	# 1. Ocultar los modelos intactos (casco y caÃ±Ã³n)
	if is_instance_valid(modelo):
		modelo.visible = false
	if is_instance_valid(_canon_modelo):
		_canon_modelo.visible = false

	# 1.5 Lanzar el caÃ±Ã³n destruido volando acrobÃ¡ticamente
	_lanzar_canon_destruido_volador()

	# 2. Activar el modelo destruido agregado en la escena (.tscn)
	_buscar_y_configurar_modelo_destruido_tscn()
	if is_instance_valid(_modelo_destruido_tscn):
		_modelo_destruido_tscn.visible = true
		if MAT_SUBMARINO_DESTRUIDO != null:
			_aplicar_material_a_arbol(_modelo_destruido_tscn, MAT_SUBMARINO_DESTRUIDO)
		modelo = _modelo_destruido_tscn
		_aplicar_rojo_transitorio_destruido()
		return

	# Fallback (instanciar si no existe en la escena)
	if ESCENA_SUBMARINO_DESTRUIDO == null:
		return
	var padre: Node = pivot_flotacion if is_instance_valid(pivot_flotacion) else self
	var nuevo_modelo: Node3D = ESCENA_SUBMARINO_DESTRUIDO.instantiate() as Node3D
	if not nuevo_modelo:
		return
	nuevo_modelo.name = "Submarino destruido2"
	padre.add_child(nuevo_modelo)
	nuevo_modelo.transform = Transform3D(Basis().scaled(Vector3(8.0, 8.0, 8.0)), Vector3.ZERO)
	nuevo_modelo.visible = true
	_modelo_destruido_tscn = nuevo_modelo
	modelo = nuevo_modelo
	if MAT_SUBMARINO_DESTRUIDO != null:
		_aplicar_material_a_arbol(nuevo_modelo, MAT_SUBMARINO_DESTRUIDO)
	_aplicar_rojo_transitorio_destruido()


## Mantiene el enrojecimiento 1 s sobre el modelo destruido para que el
## cambio quede integrado con el flash de daÃ±o previo.
func _aplicar_rojo_transitorio_destruido() -> void:
	if not is_instance_valid(_modelo_destruido_tscn):
		return
	if not is_instance_valid(_material_flash_rojo):
		_crear_material_flash_rojo()
	if _material_flash_rojo == null:
		return
	var mallas: Array[MeshInstance3D] = []
	for m in _modelo_destruido_tscn.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if is_instance_valid(mi):
			mi.material_override = _material_flash_rojo
			mallas.append(mi)
	if mallas.is_empty() or not is_inside_tree() or get_tree() == null:
		return
	var tree: SceneTree = get_tree()
	await tree.create_timer(maxf(duracion_rojo_destruido, 0.2)).timeout
	if not is_instance_valid(self) or is_queued_for_deletion():
		return
	for mi in mallas:
		if is_instance_valid(mi):
			mi.material_override = MAT_SUBMARINO_DESTRUIDO


func _lanzar_canon_destruido_volador() -> void:
	if not lanzar_canon_destruido or _canon_destruido_lanzado:
		return
	_canon_destruido_lanzado = true

	var root_scene: Node = get_tree().current_scene if is_inside_tree() and get_tree() else null
	if root_scene == null and is_inside_tree() and get_tree():
		root_scene = get_tree().root
	if root_scene == null:
		root_scene = get_parent()
	if root_scene == null:
		root_scene = self

	var spawn_pos: Vector3 = global_position + Vector3(1.2, 1.85, 0.0)
	if is_instance_valid(_canon_modelo):
		spawn_pos = _canon_modelo.global_position

	var cota_agua: float = global_position.y if absf(global_position.y) > 0.01 else -0.3

	# 1. CaÃ±Ã³n destruido volador
	var canon_volador: Node3D = SCRIPT_CANON_VOLADOR.new() as Node3D
	if canon_volador != null:
		canon_volador.set("tipo_pieza", CanonDestruidoVolador.TipoPieza.CANON)
		root_scene.add_child(canon_volador)
		var impulso_final_canon := Vector3(
			impulso_canon_destruido.x + randf_range(-variacion_impulso_canon.x, variacion_impulso_canon.x),
			impulso_canon_destruido.y + randf_range(-variacion_impulso_canon.y, variacion_impulso_canon.y),
			impulso_canon_destruido.z + randf_range(-variacion_impulso_canon.z, variacion_impulso_canon.z)
		)
		if canon_volador.has_method("lanzar"):
			canon_volador.call("lanzar", spawn_pos, impulso_final_canon, cota_agua)

	# 2. Tuerca / rueda destruida voladora (trayectoria acrobÃ¡tica divergente)
	var tuerca_voladora: Node3D = SCRIPT_CANON_VOLADOR.new() as Node3D
	if tuerca_voladora != null:
		tuerca_voladora.set("tipo_pieza", CanonDestruidoVolador.TipoPieza.TUERCA)
		root_scene.add_child(tuerca_voladora)
		var impulso_final_tuerca := Vector3(
			impulso_tuerca_destruida.x + randf_range(-variacion_impulso_canon.x, variacion_impulso_canon.x),
			impulso_tuerca_destruida.y + randf_range(-variacion_impulso_canon.y, variacion_impulso_canon.y),
			impulso_tuerca_destruida.z + randf_range(-variacion_impulso_canon.z, variacion_impulso_canon.z)
		)
		var spawn_pos_tuerca: Vector3 = spawn_pos + Vector3(-0.35, 0.15, 0.25)
		if tuerca_voladora.has_method("lanzar"):
			tuerca_voladora.call("lanzar", spawn_pos_tuerca, impulso_final_tuerca, cota_agua)


func _iniciar_cadena_explosiones_destruccion() -> void:
	if not is_inside_tree() or get_tree() == null:
		_sustituir_por_modelo_destruido()
		_spawn_vfx_explosion_cola()
		return
	_explotar_paso_destruccion(0)


func _explotar_paso_destruccion(indice: int) -> void:
	if not is_inside_tree() or get_tree() == null:
		_sustituir_por_modelo_destruido()
		_spawn_vfx_explosion_cola()
		return

	if indice >= cantidad_explosiones_cadena:
		# Gran explosiÃ³n final en la cola para sellar la destrucciÃ³n
		_spawn_vfx_explosion_cola()
		return

	# PosiciÃ³n del estallido a lo largo del cuerpo del submarino
	var offset_rel: Vector3 = OFFSETS_EXPLOSIONES_CADENA[mini(indice, OFFSETS_EXPLOSIONES_CADENA.size() - 1)]
	var rand_offset := Vector3(randf_range(-0.15, 0.15), randf_range(-0.1, 0.1), randf_range(-0.15, 0.15))
	var spawn_pos: Vector3 = global_position + global_transform.basis * (offset_rel + rand_offset)

	# Estallido visual y sonoro idÃ©ntico a GloboAerostatico
	_spawn_explosion_vfx_pilar(spawn_pos)

	# Camuflar el cambio de modelo: se activa bajo el fuego y humo de la explosiÃ³n
	if indice == paso_cambio_modelo or (indice == 0 and cantidad_explosiones_cadena <= 1):
		_sustituir_por_modelo_destruido()

	# Siguiente estallido en la sucesiÃ³n
	var tree: SceneTree = get_tree()
	if tree != null:
		tree.create_timer(maxf(intervalo_explosiones_cadena, 0.05)).timeout.connect(func() -> void:
			if is_instance_valid(self) and not is_queued_for_deletion():
				_explotar_paso_destruccion(indice + 1)
		)


func _spawn_explosion_vfx_pilar(spawn_pos: Vector3) -> void:
	var root_scene: Node = get_tree().current_scene if is_inside_tree() and get_tree() else null
	if root_scene == null and is_inside_tree() and get_tree():
		root_scene = get_tree().root
	if root_scene == null:
		root_scene = self

	if ESCENA_EXPLOSION_PILAR != null:
		var exp_node := ESCENA_EXPLOSION_PILAR.instantiate() as Node3D
		if exp_node:
			root_scene.add_child(exp_node)
			exp_node.scale = Vector3.ONE * maxf(escala_explosiones_cadena, 0.5)
			exp_node.global_position = spawn_pos
			var tree: SceneTree = get_tree()
			if tree != null:
				tree.create_timer(1.2).timeout.connect(func() -> void:
					if is_instance_valid(exp_node) and not exp_node.is_queued_for_deletion():
						exp_node.queue_free()
				)

	_crear_particulas_rocas_destruccion(spawn_pos)
	_reproducir_sonido_explosion(spawn_pos)


func _crear_particulas_rocas_destruccion(spawn_pos: Vector3) -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	if TEXTURA_PIEDRAS_NEGRAS_RES == null:
		return

	var parts := GPUParticles3D.new()
	parts.name = "ParticulasRocasDestruccionSubmarino"
	parts.amount = 14
	parts.lifetime = 2.5
	parts.one_shot = true
	parts.explosiveness = 0.85

	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(0.4, 0.2, 0.4)
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 50.0
	pmat.initial_velocity_min = 2.5
	pmat.initial_velocity_max = 6.0
	pmat.gravity = Vector3(0, -11.0, 0)
	pmat.scale_min = 0.3
	pmat.scale_max = 0.75
	pmat.anim_offset_min = 0.0
	pmat.anim_offset_max = 1.0
	pmat.angle_min = 0.0
	pmat.angle_max = 360.0
	pmat.angular_velocity_min = -180.0
	pmat.angular_velocity_max = 180.0
	parts.process_material = pmat

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = TEXTURA_PIEDRAS_NEGRAS_RES
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.particles_anim_h_frames = 4
	mat.particles_anim_v_frames = 1
	mat.particles_anim_loop = false
	mat.render_priority = -1

	var quad := QuadMesh.new()
	quad.size = Vector2(0.4, 0.4)
	quad.material = mat
	parts.draw_pass_1 = quad

	var root: Node = get_tree().current_scene
	if root == null:
		root = get_tree().root
	if root == null:
		root = self
	root.add_child(parts)
	parts.global_position = spawn_pos
	parts.emitting = true

	var tree: SceneTree = get_tree()
	if tree != null:
		tree.create_timer(3.5).timeout.connect(func() -> void:
			if is_instance_valid(parts) and not parts.is_queued_for_deletion():
				parts.queue_free()
		)


func _reproducir_sonido_explosion(spawn_pos: Vector3) -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	var stream: AudioStream = SFX_EXPLOSION_01 if randf() < 0.5 else SFX_EXPLOSION_02
	if not stream:
		return

	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = -1.5
	player.unit_size = 18.0
	player.max_distance = 60.0
	player.bus = "Master"

	var root: Node = get_tree().current_scene
	if root == null:
		root = get_tree().root
	if root == null:
		root = self
	root.add_child(player)
	player.global_position = spawn_pos
	player.play()
	player.finished.connect(func() -> void:
		if is_instance_valid(player) and not player.is_queued_for_deletion():
			player.queue_free()
	)


func _spawn_vfx_explosion_cola() -> void:
	if ESCENA_VFX_BIG_IMPACT_02 == null:
		return
	var vfx_inst: Node = ESCENA_VFX_BIG_IMPACT_02.instantiate()
	if not (vfx_inst is Node3D):
		if is_instance_valid(vfx_inst):
			vfx_inst.queue_free()
		return
	var vfx := vfx_inst as Node3D
	var raiz: Node = get_tree().current_scene if is_inside_tree() and get_tree() else null
	if raiz == null and is_inside_tree() and get_tree():
		raiz = get_tree().root
	if raiz == null:
		raiz = self
	raiz.add_child(vfx)

	var punto_cola: Vector3 = global_position + global_transform.basis * offset_explosion_cola
	vfx.global_position = punto_cola
	vfx.scale = Vector3.ONE * maxf(escala_explosion_vfx, 0.5)

	if vfx.has_method("play"):
		vfx.call("play")
	elif "emitting" in vfx:
		vfx.set("emitting", true)

	var tree: SceneTree = get_tree()
	if tree != null:
		tree.create_timer(3.5).timeout.connect(func():
			if is_instance_valid(vfx) and not vfx.is_queued_for_deletion():
				vfx.queue_free()
		)


func _reproducir_sfx_hundimiento_crescendo() -> AudioStreamPlayer3D:
	if SFX_BARCO_HUNDIMIENTO == null:
		return null
	var player := AudioStreamPlayer3D.new()
	player.name = "SfxBarcoHundimiento"
	player.stream = SFX_BARCO_HUNDIMIENTO
	player.unit_size = 35.0
	player.max_distance = 80.0
	player.volume_db = volumen_inicial_hundimiento_db
	player.bus = "Master"
	var raiz: Node = get_tree().current_scene if is_inside_tree() and get_tree() else null
	if raiz == null and is_inside_tree() and get_tree():
		raiz = get_tree().root
	if raiz == null:
		raiz = self
	raiz.add_child(player)
	player.global_position = global_position
	player.play()
	return player


func _iniciar_tween_hundimiento_muerte(player_sfx: AudioStreamPlayer3D) -> void:
	if not is_inside_tree() or get_tree() == null:
		sumersion_completada.emit()
		_finalizar_baile_tras_hundimiento()
		return

	var tw := create_tween()
	tw.set_parallel(true)

	var y_final: float = position.y - maxf(profundidad_hundimiento_muerte, 2.0)
	tw.tween_property(self, "position:y", y_final, duracion_hundimiento_muerte)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	var rot_x_final: float = rotation_degrees.x + inclinacion_camara_grados
	tw.tween_property(self, "rotation_degrees:x", rot_x_final, duracion_hundimiento_muerte)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var rot_z_final: float = rotation_degrees.z + inclinacion_roll_grados
	tw.tween_property(self, "rotation_degrees:z", rot_z_final, duracion_hundimiento_muerte)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if is_instance_valid(player_sfx):
		tw.tween_property(player_sfx, "volume_db", volumen_final_hundimiento_db, duracion_hundimiento_muerte)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	tw.chain().tween_callback(func() -> void:
		if is_instance_valid(player_sfx) and not player_sfx.is_queued_for_deletion():
			player_sfx.queue_free()
		current_state = State.DESAPARECIDO
		sumersion_completada.emit()
		_finalizar_baile_tras_hundimiento()
	)


## Perrena baila desde la destrucciÃ³n: la localiza por grupo y le ordena el
## baile de victoria (si no hay Perrena en escena, no hace nada).
func _iniciar_baile_perrena() -> void:
	if get_tree() == null:
		return
	var perrena: Node = get_tree().get_first_node_in_group("defensora_perrena")
	if is_instance_valid(perrena) and perrena.has_method("iniciar_baile_victoria"):
		perrena.call("iniciar_baile_victoria")


## Al terminar de hundirse, Perrena sigue bailando 2 s mÃ¡s; reciÃ©n ahÃ­ se
## detiene el baile y se libera el jefe.
func _finalizar_baile_tras_hundimiento() -> void:
	if not is_inside_tree() or get_tree() == null:
		_detener_baile_perrena()
		if is_instance_valid(self) and not is_queued_for_deletion():
			queue_free()
		return
	await get_tree().create_timer(maxf(retraso_fin_baile_tras_hundirse, 0.0)).timeout
	if not is_instance_valid(self) or is_queued_for_deletion():
		return
	_detener_baile_perrena()
	queue_free()


func _detener_baile_perrena() -> void:
	if get_tree() == null:
		return
	var perrena: Node = get_tree().get_first_node_in_group("defensora_perrena")
	if is_instance_valid(perrena) and perrena.has_method("detener_baile_victoria"):
		perrena.call("detener_baile_victoria")


## Al destruirse el jefe, los corazones del jugador y la vida de Perrena se rellenan al 100%.
func _curar_jugador_y_perrena() -> void:
	if get_tree() == null:
		return

	# 1. Rellenar corazones del jugador
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		var canoa: Node3D = _obtener_canoa()
		if is_instance_valid(canoa):
			var p = canoa.find_child("Protagonista", true, false)
			if is_instance_valid(p):
				players.append(p)

	for p in players:
		if not is_instance_valid(p):
			continue
		if p.has_method("curar_completo"):
			p.call("curar_completo")
		elif p.has_method("curar") and "vida_maxima" in p:
			p.call("curar", p.get("vida_maxima"))
		elif "vida_maxima" in p and "health" in p:
			p.set("health", p.get("vida_maxima"))
			if p.has_signal("health_changed"):
				p.emit_signal("health_changed", p.get("health"))

	get_tree().call_group("ui_vida_protagonista", "reconectar_player")

	# 2. Rellenar vida de Perrena (defensora y/o jugable)
	var perrenas: Array[Node] = []
	perrenas.append_array(get_tree().get_nodes_in_group("defensora_perrena"))
	perrenas.append_array(get_tree().get_nodes_in_group("defensoras"))
	var canoa: Node3D = _obtener_canoa()
	if is_instance_valid(canoa):
		var perrena_canoa = canoa.find_child("DefensoraPerrena", true, false)
		if is_instance_valid(perrena_canoa) and not perrenas.has(perrena_canoa):
			perrenas.append(perrena_canoa)

	for perrena in perrenas:
		if not is_instance_valid(perrena):
			continue
		if perrena.has_method("curar_completo"):
			perrena.call("curar_completo")
		elif perrena.has_method("curar") and "vida_maxima" in perrena:
			perrena.call("curar", perrena.get("vida_maxima"))
		elif "vida_maxima" in perrena and "health" in perrena:
			perrena.set("health", perrena.get("vida_maxima"))
			if perrena.has_signal("vida_cambiada"):
				perrena.emit_signal("vida_cambiada", perrena.get("health"))


func _limpiar_enemigos_restantes(forzar_queue_free: bool = true) -> void:
	for e in _enemigos_vivos:
		if is_instance_valid(e) and not e.is_queued_for_deletion():
			if e.is_in_group("enemies"):
				e.remove_from_group("enemies")
			if e.is_in_group("enemigos"):
				e.remove_from_group("enemigos")
			if forzar_queue_free:
				e.queue_free()
			elif e.has_method("take_damage"):
				e.call("take_damage", 9999.0)
			elif e.has_method("die"):
				e.call("die")
			elif e.has_method("_die"):
				e.call("_die")
			else:
				e.queue_free()
	_enemigos_vivos.clear()
	_enemigos_restantes_por_spawnear = 0


func _matar_enemigos_restantes_en_sumersion() -> void:
	_limpiar_enemigos_restantes(false)


func _limpiar_misiles() -> void:
	for m in _misiles:
		if is_instance_valid(m) and not m.is_queued_for_deletion():
			m.queue_free()
	_misiles.clear()
	for mc in _misiles_cosmeticos:
		if is_instance_valid(mc) and not mc.is_queued_for_deletion():
			mc.queue_free()
	_misiles_cosmeticos.clear()


# === FASE 2 ===

func _entrar_fase2() -> void:
	if _jefe_muerto or _fase_jefe != FaseJefe.FASE1:
		return
	_activar_humo_danado(false)
	_fase_jefe = FaseJefe.TRANSICION_FASE2
	_is_invulnerable = true
	_secuencia_fase2_activa = true
	_dano_fase = 0
	_misiles_resueltos = 0
	_tanda_actual = 0
	# No se eliminan los enemigos que quedan vivos en cubierta: permanecen
	# sobre la plataforma durante el disparo del caÃ±Ã³n y mueren al sumergirse.
	_enemigos_restantes_por_spawnear = 0
	_cola_mezcla.clear()
	if is_in_group("enemies"):
		remove_from_group("enemies")
	if is_in_group("enemigos"):
		remove_from_group("enemigos")
	var nivel := get_parent()
	if is_instance_valid(nivel) and nivel.has_method("set_travesia_activa"):
		nivel.call("set_travesia_activa", false)
	fase_cambiada.emit(int(_fase_jefe))
	# Igual que el resto de submarinos: al morir la oleada el caÃ±Ã³n dispara el
	# ataque Lonko antes de hundirse. Secuencia explÃ­cita para garantizarlo.
	_disparo_canon_realizado = false
	if canon_disparo_final and _canon_listo_para_disparo():
		super._iniciar_sumersion()
		await get_tree().create_timer(_duracion_secuencia_canon()).timeout
		if not _secuencia_fase2_activa or _jefe_muerto:
			return
	else:
		push_warning("JefeSubmarinoRio: caÃ±Ã³n no listo, se hunde sin disparo Lonko")
	_hundir_hasta_fuera_de_camara()


## DuraciÃ³n total de la despedida del caÃ±Ã³n base (apuntado + pausa + disparo +
## regreso) para hundirse justo despuÃ©s, como los submarinos normales.
func _duracion_secuencia_canon() -> float:
	return maxf(canon_tiempo_apuntado, 0.05) + maxf(canon_pausa_antes_disparo, 0.0) + maxf(canon_duracion_deformacion, 0.05) + maxf(canon_tiempo_regreso, 0.05) + 0.3


## Al mismo tiempo del disparo Lonko cae la mina acuÃ¡tica del submarino.
func _al_disparo_lonko_soltar_mina() -> void:
	if _jefe_muerto or _fase_jefe != FaseJefe.TRANSICION_FASE2:
		return
	if not is_inside_tree() or get_tree() == null:
		return
	if is_instance_valid(_mina) and not _mina.is_queued_for_deletion():
		_mina.queue_free()
	_mina = ESCENA_MINA.instantiate() as MinaAcuatica
	if _mina == null:
		return
	var raiz: Node = get_tree().current_scene
	if raiz == null:
		raiz = get_tree().root
	raiz.add_child(_mina)
	var altura_agua: float = global_position.y + 1.0
	var plano_z: float = global_position.z
	var canoa := _obtener_canoa()
	if is_instance_valid(canoa):
		altura_agua = (canoa as Node3D).global_position.y
		plano_z = (canoa as Node3D).global_position.z
	# Cae casi de la cola (+X, popa) en el mismo plano de canoa/vasija para
	# que las flechas la alcancen; el carril la abre en Z hasta rebasar el
	# casco y luego converge al plano (ver MinaAcuatica.fijar_ruta).
	_mina.colocar_en(Vector3(global_position.x + mina_offset_cola_x, altura_agua + _mina.offset_agua_y, plano_z))
	_mina.global_position.z += mina_offset_frente_z
	_mina.fijar_ruta(global_position.x)


func _hundir_hasta_fuera_de_camara() -> void:
	if not _secuencia_fase2_activa or _jefe_muerto:
		return
	_matar_enemigos_restantes_en_sumersion()
	_detener_goteo_cubierta()
	_desactivar_colisiones()
	_reproducir_sfx_splash()
	_reproducir_sfx_sumergiendose()
	current_state = State.SUMERGIENDOSE
	var tw := create_tween()
	tw.tween_property(self, "position:y", _y_limite_desaparicion - 8.0, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(_esperar_fuera_de_pantalla)


## Espera a que el casco salga por completo del encuadre antes de reaparecer
## al fondo: sigue bajando hasta que el notificador deja de verse en cÃ¡mara.
func _esperar_fuera_de_pantalla() -> void:
	if not _secuencia_fase2_activa or _jefe_muerto:
		return
	if not is_inside_tree() or get_tree() == null:
		return
	var intentos: int = 0
	while _secuencia_fase2_activa and not _jefe_muerto and intentos < 40:
		var sigue_visible: bool = true
		if is_instance_valid(_notificador_pantalla):
			sigue_visible = _notificador_pantalla.is_on_screen()
		if not sigue_visible:
			break
		position.y -= 0.4
		intentos += 1
		await get_tree().create_timer(0.15).timeout
	_reposicionar_sumergido_al_fondo()


func _obtener_z_fondo_fase2() -> float:
	if _ref_sumergida_valida:
		return posicion_sumergida_fase2.z
	var nivel := get_parent()
	if is_instance_valid(nivel):
		var nauf: Node3D = nivel.find_child("NaufragioMitadParaPosicionar2", true, false) as Node3D
		if not is_instance_valid(nauf):
			nauf = nivel.find_child("*Naufragio*", true, false) as Node3D
		if is_instance_valid(nauf):
			return nauf.global_position.z + 1.95
	return z_fondo_fase2


func _obtener_y_fondo_fase2() -> float:
	if _ref_sumergida_valida:
		return posicion_sumergida_fase2.y
	return y_fondo_fase2


func _obtener_x_centro_fondo() -> float:
	var nivel := get_parent()
	if is_instance_valid(nivel):
		var nauf: Node3D = nivel.find_child("NaufragioMitadParaPosicionar2", true, false) as Node3D
		if not is_instance_valid(nauf):
			nauf = nivel.find_child("*Naufragio*", true, false) as Node3D
		if is_instance_valid(nauf):
			return nauf.global_position.x
	var cam := _obtener_camara_activa()
	if cam != null:
		return cam.global_position.x
	return _pos_combate.x


func _reposicionar_sumergido_al_fondo() -> void:
	if not _secuencia_fase2_activa or _jefe_muerto:
		return
	_fase_jefe = FaseJefe.FASE2
	fase_cambiada.emit(int(_fase_jefe))
	_pausar_travesia_fase2()
	_crucero_fondo_completado = false

	var cam := _obtener_camara_activa()
	var cam_x: float = cam.global_position.x if cam != null else _pos_combate.x

	var z_fondo: float = _obtener_z_fondo_fase2()
	var y_fondo: float = _obtener_y_fondo_fase2()
	var x_inicio: float = cam_x - maxf(margen_salida_fondo_x, 15.0)
	var x_fin: float = cam_x + maxf(margen_salida_fondo_x, 15.0)
	var x_centro: float = _obtener_x_centro_fondo()

	if fondo_fase2_activo:
		global_position = Vector3(x_inicio, y_fondo, z_fondo)
		# Girar 180° en Y para navegar hacia la derecha (+X) mirando al frente
		rotation_degrees = Vector3(0.0, 180.0, 0.0)
		visible = true
		_desactivar_colisiones()
		_disparar_tanda_misiles()
		_aplicar_escala_fondo()
		_preparar_bamboleo_fondo()
		_iniciar_crucero_fondo(x_fin, x_inicio, x_centro)
	else:
		if _ref_sumergida_valida:
			global_position = Vector3(posicion_sumergida_fase2.x, _altura_objetivo_y - profundidad_fase2, posicion_sumergida_fase2.z)
		else:
			if cam != null:
				global_position.x = cam.global_position.x + 3.0
			position.y = _altura_objetivo_y - profundidad_fase2
		_reactivar_colisiones_parcial()
		_disparar_tanda_misiles()


func _iniciar_crucero_fondo(x_fin: float, x_inicio: float = -INF, x_centro: float = -INF) -> void:
	if not _secuencia_fase2_activa or _jefe_muerto:
		return
	if is_instance_valid(_tween_crucero_fondo) and _tween_crucero_fondo.is_running():
		_tween_crucero_fondo.kill()

	if x_inicio == -INF:
		x_inicio = global_position.x
	if x_centro == -INF:
		x_centro = _obtener_x_centro_fondo()

	var dist_total: float = absf(x_fin - x_inicio)
	var dist_1: float = absf(x_centro - x_inicio)
	var dist_2: float = absf(x_fin - x_centro)

	# Si no se disparan misiles cosméticos o el centro no está entre inicio y fin, crucero directo
	if not disparar_misiles_fondo_cosmeticos or dist_total <= 0.001 or (x_centro <= minf(x_inicio, x_fin) or x_centro >= maxf(x_inicio, x_fin)):
		_tween_crucero_fondo = create_tween()
		_tween_crucero_fondo.tween_property(self, "global_position:x", x_fin, maxf(duracion_crucero_fondo, 2.0))\
			.set_trans(Tween.TRANS_LINEAR)
		_tween_crucero_fondo.tween_callback(_on_crucero_fondo_completado)
		return

	var frac_1: float = clampf(dist_1 / dist_total, 0.1, 0.9)
	var frac_2: float = 1.0 - frac_1
	var dur_total: float = maxf(duracion_crucero_fondo, 2.0)
	var duracion_1: float = maxf(dur_total * frac_1, 1.0)
	var duracion_2: float = maxf(dur_total * frac_2, 1.0)

	_tween_crucero_fondo = create_tween()
	# Tramo 1: Navegar de x_inicio hasta el centro de la pantalla (naufragio)
	_tween_crucero_fondo.tween_property(self, "global_position:x", x_centro, duracion_1)\
		.set_trans(Tween.TRANS_LINEAR)

	# Detenerse en el centro: pausa antes de disparar
	_tween_crucero_fondo.tween_interval(maxf(pausa_antes_disparo_fondo, 0.05))

	# Disparar 3 misiles cosméticos hacia arriba en rápida sucesión
	for i in range(cantidad_misiles_fondo_cosmeticos):
		if i > 0:
			_tween_crucero_fondo.tween_interval(maxf(intervalo_misiles_cosmeticos, 0.05))
		_tween_crucero_fondo.tween_callback(_disparar_misil_cosmetico.bind(i))

	# Pausa tras disparar antes de reanudar
	_tween_crucero_fondo.tween_interval(maxf(pausa_despues_disparo_fondo, 0.05))

	# Tramo 2: Reanudar trayectoria normal saliendo de pantalla hasta x_fin
	_tween_crucero_fondo.tween_property(self, "global_position:x", x_fin, duracion_2)\
		.set_trans(Tween.TRANS_LINEAR)

	# Al completar el crucero y salir de pantalla
	_tween_crucero_fondo.tween_callback(_on_crucero_fondo_completado)


func _disparar_misil_cosmetico(indice: int = 0) -> void:
	if not _secuencia_fase2_activa or _jefe_muerto:
		return
	if not is_inside_tree() or get_tree() == null:
		return
	var misil := ESCENA_MISIL.instantiate() as MisilSubmarino
	if misil == null:
		return
	misil.es_cosmetico = true
	misil.velocidad_subida = maxf(velocidad_subida_misil_fondo, 5.0)
	misil.escala_modelo = maxf(escala_modelo_fondo * 0.65, 0.3)

	var raiz: Node = get_tree().current_scene
	if raiz == null:
		raiz = get_parent()
	if raiz == null:
		raiz = get_tree().root
	raiz.add_child(misil)

	# Dispersión sutil sobre la cubierta del submarino (-1.2, 0.0, 1.2)
	var offsets: Array[float] = [-1.2, 0.0, 1.2]
	var off_local_x: float = offsets[indice % offsets.size()]
	misil.global_position = to_global(Vector3(off_local_x, 0.8, 0.0))

	_reproducir_sfx_canon(misil.global_position)
	_misiles_cosmeticos.append(misil)


func _on_crucero_fondo_completado() -> void:
	_crucero_fondo_completado = true
	_restaurar_escala_fondo()
	if not _secuencia_fase2_activa or _jefe_muerto:
		return
	visible = false
	_verificar_retorno_fase1()


## Escala reducida durante el crucero para que parezca más lejos.
## Se aplica fuera de cámara (inicios/fines a ±26 m) y se restaura igual.
func _aplicar_escala_fondo() -> void:
	_escala_previa_fondo = scale
	_escala_fondo_aplicada = true
	scale = Vector3.ONE * maxf(escala_modelo_fondo, 0.2)


func _restaurar_escala_fondo() -> void:
	if not _escala_fondo_aplicada:
		return
	_escala_fondo_aplicada = false
	scale = _escala_previa_fondo


## Reposa el pivot del bamboleo de fondo (muerte/retorno): la base lo retoma.
func _reposar_pivot_bamboleo() -> void:
	var piv := _pivot_bamboleo_fondo
	if not is_instance_valid(piv):
		piv = pivot_flotacion
	if is_instance_valid(piv):
		piv.position.y = 0.0
		piv.rotation = Vector3.ZERO
	_pivot_bamboleo_fondo = null


## Bamboleo sutil de navegación durante el crucero de fondo: mismo lenguaje
## que la flotación de superficie (sine en Y + rolido + cabeceo sobre el pivot)
## para que no cruce tieso. Solo mientras el crucero está en curso (el tween
## de X no pelea: el bamboleo solo toca Y/rotación del pivot).
func _preparar_bamboleo_fondo() -> void:
	_tiempo_bamboleo_fondo = 0.0
	_pivot_bamboleo_fondo = pivot_flotacion
	if not is_instance_valid(_pivot_bamboleo_fondo):
		_pivot_bamboleo_fondo = find_child("PivotFlotacion", true, false) as Node3D
	if is_instance_valid(_pivot_bamboleo_fondo):
		_y_base_bamboleo_fondo = _pivot_bamboleo_fondo.position.y


func _procesar_bamboleo_fondo(delta: float) -> void:
	if _jefe_muerto or not _secuencia_fase2_activa:
		return
	if not fondo_fase2_activo or _crucero_fondo_completado:
		return
	if _fase_jefe != FaseJefe.FASE2:
		return
	if not is_instance_valid(_pivot_bamboleo_fondo):
		return
	_tiempo_bamboleo_fondo += TAU * delta / maxf(periodo_bamboleo_fondo, 0.5)
	var t: float = _tiempo_bamboleo_fondo
	_pivot_bamboleo_fondo.position.y = _y_base_bamboleo_fondo + sin(t) * amplitud_bamboleo_fondo_y
	_pivot_bamboleo_fondo.rotation = Vector3(
		sin(t * 0.75) * deg_to_rad(amplitud_cabeceo_fondo_x),
		0.0,
		sin(t * 0.6) * deg_to_rad(amplitud_balanceo_fondo_z)
	)


## Tras disparar los 6 misiles en modo clásico, el jefe sale de pantalla moviéndose a la izquierda.
func _salir_por_izquierda() -> void:
	if not _secuencia_fase2_activa or _jefe_muerto:
		return
	if not is_inside_tree():
		return
	_desactivar_colisiones()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "global_position:x", global_position.x - maxf(offset_salida_izquierda, 5.0), maxf(tiempo_salida_izquierda, 1.0)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "position:y", position.y - maxf(hundimiento_extra_salida, 0.0), maxf(tiempo_salida_izquierda, 1.0)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(_ocultar_tras_salida)


func _ocultar_tras_salida() -> void:
	if not _secuencia_fase2_activa or _jefe_muerto:
		return
	visible = false


func _disparar_tanda_misiles() -> void:
	if not _secuencia_fase2_activa or _jefe_muerto:
		return
	if not is_inside_tree() or get_tree() == null:
		return
	_misiles.clear()
	_misiles_resueltos = 0
	_tanda_actual = 0
	_gargolas_invocadas = false
	var canoa := _obtener_canoa()
	var boca_pos: Vector3 = _boca_canon.global_position if is_instance_valid(_boca_canon) else global_position
	for i in range(misiles_totales):
		var misil := ESCENA_MISIL.instantiate() as MisilSubmarino
		if misil == null:
			continue
		var raiz: Node = get_tree().current_scene
		if raiz == null:
			raiz = get_tree().root
		raiz.add_child(misil)
		misil.global_position = boca_pos
		var slot: int = i % misiles_por_tanda
		var off_x: float = _obtener_offset_zona_verde(slot)
		if is_instance_valid(canoa):
			misil.fijar_objetivo_canoa(canoa, off_x, altura_caida_y)
		else:
			misil.fijar_punto_caida(_calcular_punto_caida(slot))
		misil.caido.connect(_on_misil_resuelto)
		misil.destruido.connect(_on_misil_resuelto)
		_misiles.append(misil)
	_reproducir_sfx_canon(boca_pos)
	await get_tree().create_timer(0.6).timeout
	if not _secuencia_fase2_activa or _jefe_muerto:
		return
	_lanzar_tanda(_tanda_actual)
	if not fondo_fase2_activo:
		_salir_por_izquierda()


## Suelta la tanda en formación sobre la zona verde de la canoa.
func _lanzar_tanda(indice_tanda: int) -> void:
	if not _secuencia_fase2_activa or _jefe_muerto:
		return
	var canoa := _obtener_canoa()
	var inicio: int = indice_tanda * misiles_por_tanda
	var fin: int = mini(inicio + misiles_por_tanda, _misiles.size())
	for i in range(inicio, fin):
		var misil: MisilSubmarino = _misiles[i] as MisilSubmarino
		if not is_instance_valid(misil):
			continue
		var slot: int = i % misiles_por_tanda
		var off_x: float = _obtener_offset_zona_verde(slot)
		var punto: Vector3
		if is_instance_valid(canoa):
			misil.fijar_objetivo_canoa(canoa, off_x, altura_caida_y)
			punto = Vector3(canoa.global_position.x + off_x, altura_caida_y, canoa.global_position.z)
		else:
			punto = _calcular_punto_caida(slot)
			misil.fijar_punto_caida(punto)
		var off_y: float = offsets_formacion_y[clampi(slot, 0, offsets_formacion_y.size() - 1)] if not offsets_formacion_y.is_empty() else 0.0
		misil.global_position = Vector3(punto.x, altura_formacion_y + off_y, punto.z)
		misil.iniciar_caida()


func _on_misil_resuelto(_misil: MisilSubmarino) -> void:
	if not _secuencia_fase2_activa or _jefe_muerto:
		return
	_misiles_resueltos += 1
	var esperados_tanda: int = mini((_tanda_actual + 1) * misiles_por_tanda, _misiles.size())
	if _misiles_resueltos >= esperados_tanda and _misiles_resueltos < _misiles.size():
		_tanda_actual += 1
		# Tras la primera tanda caen 5 gárgolas por la derecha.
		if _tanda_actual == 1 and not _gargolas_invocadas:
			_gargolas_invocadas = true
			_spawnear_gargolas()
		if is_inside_tree() and get_tree() != null:
			await get_tree().create_timer(intervalo_entre_tandas).timeout
			if not _secuencia_fase2_activa or _jefe_muerto:
				return
			_lanzar_tanda(_tanda_actual)
		return
	if _misiles_resueltos >= _misiles.size():
		_verificar_retorno_fase1()


func _verificar_retorno_fase1() -> void:
	if not _secuencia_fase2_activa or _jefe_muerto:
		return
	if _misiles_resueltos < _misiles.size():
		return
	if fondo_fase2_activo and not _crucero_fondo_completado:
		return
	_volver_a_fase1()


## Tras la primera tanda aparecen 5 gÃ¡rgolas por la derecha para presionar
## durante la segunda tanda. Se limpian al volver a fase 1 o morir el jefe.
func _spawnear_gargolas() -> void:
	if not _secuencia_fase2_activa or _jefe_muerto:
		return
	if not is_inside_tree() or get_tree() == null:
		return
	var cam := _obtener_camara_activa()
	var base_x: float = global_position.x + gargola_offset_derecha_x
	var base_z: float = global_position.z
	if cam != null:
		base_x = cam.global_position.x + gargola_offset_derecha_x
	var canoa := _obtener_canoa()
	if is_instance_valid(canoa):
		base_z = (canoa as Node3D).global_position.z
	for i in range(maxi(gargolas_cantidad, 1)):
		if not _secuencia_fase2_activa or _jefe_muerto:
			return
		var g := ESCENA_GARGOLA.instantiate() as Node3D
		if g == null:
			continue
		var raiz: Node = get_tree().current_scene
		if raiz == null:
			raiz = get_tree().root
		raiz.add_child(g)
		g.global_position = Vector3(base_x + float(i) * maxf(gargola_separacion_x, 0.5), gargola_altura + float(i % 2) * 1.2, base_z)
		_configurar_gargola_fase2(g)
		_gargolas.append(g)
		if gargola_intervalo > 0.0 and i < gargolas_cantidad - 1:
			await get_tree().create_timer(gargola_intervalo).timeout
	# Las primeras N son atacantes designadas: deben abrir fuego a mitad de trayecto.
	_marcar_gargolas_atacantes()


func _limpiar_gargolas() -> void:
	for g in _gargolas:
		if is_instance_valid(g) and not g.is_queued_for_deletion():
			g.queue_free()
	_gargolas.clear()
	_gargolas_forzadas.clear()
	_gargolas_ataque_forzado.clear()
	_gargolas_invocadas = false


## Configura una gÃ¡rgola de fase 2: solo combate en pantalla (nunca ataca
## desde afuera) y caminata larga para que no abra fuego sola antes de entrar.
func _configurar_gargola_fase2(g: Node) -> void:
	if not is_instance_valid(g):
		return
	if "solo_atacar_en_pantalla" in g:
		g.set("solo_atacar_en_pantalla", true)
	if "margen_camara_ataque_x" in g:
		g.set("margen_camara_ataque_x", 6.0)
	if "margen_camara_salida_x" in g:
		g.set("margen_camara_salida_x", 6.0)
	var cam := _obtener_camara_activa()
	if cam:
		g.set("_camara_cache_pantalla", cam)
	if "walked_distance" in g:
		g.set("walked_distance", 0.0)
	if "target_walk_distance" in g:
		g.set("target_walk_distance", randf_range(6.0, 10.0))


## True si la gÃ¡rgola estÃ¡ dentro del encuadre (usa su propia comprobaciÃ³n de
## EnemyBase; fallback a rango X si no dispone de ella, p. ej. en tests).
func _gargola_en_pantalla(g: Node, cam: Camera3D) -> bool:
	if not is_instance_valid(g) or cam == null:
		return true
	var gn := g as Node3D
	if gn == null:
		return true
	var dx: float = gn.global_position.x - cam.global_position.x
	if dx > 6.0 or dx < -6.0:
		return false
	if g.has_method("esta_en_pantalla_o_rango_camara"):
		return bool(g.call("esta_en_pantalla_o_rango_camara"))
	return true


## Las primeras N gÃ¡rgolas son atacantes designadas: al llegar a mitad de
## trayecto (sobre la canoa) se las fuerza a SHOOTING para que no crucen sin atacar.
func _marcar_gargolas_atacantes() -> void:
	_gargolas_forzadas.clear()
	var total: int = mini(maxi(gargolas_atacantes_min, 1), _gargolas.size())
	for i in range(total):
		var g: Node = _gargolas[i]
		if is_instance_valid(g):
			_gargolas_forzadas.append(g)


## Fuerza a una gÃ¡rgola a entrar en combate inmediato (disparo rÃ¡pido).
## Solo dentro del encuadre: jamÃ¡s se fuerza un ataque desde fuera de pantalla.
func _forzar_ataque_gargola(g: Node) -> void:
	if not is_instance_valid(g):
		return
	if g in _gargolas_ataque_forzado:
		return
	var cam := _obtener_camara_activa()
	if not _gargola_en_pantalla(g, cam):
		return
	if g.has_method("puede_atacar"):
		if not bool(g.call("puede_atacar")):
			return
	_gargolas_ataque_forzado.append(g)
	if "intervalo_disparo" in g:
		g.set("intervalo_disparo", minf(float(g.get("intervalo_disparo")), 0.3))
	if "target_walk_distance" in g:
		g.set("target_walk_distance", 0.0)
	if "walked_distance" in g:
		g.set("walked_distance", 999.0)
	if "solo_atacar_en_pantalla" in g:
		g.set("solo_atacar_en_pantalla", true)
	if g.has_method("_change_state"):
		g.call("_change_state", 1)


## Crucero derecha a izquierda: las gÃ¡rgolas por sÃ­ solas se quedan flotando
## en su spawn (fuera de cuadro); aquÃ­ las barremos por la pantalla y al salir
## por la izquierda reentran por la derecha en bucle durante la fase 2.
func _procesar_crucero_gargolas(delta: float) -> void:
	if _gargolas.is_empty() or delta <= 0.0:
		return
	var cam := _obtener_camara_activa()
	if cam == null:
		return
	var canoa := _obtener_canoa()
	var canoa_x: float = cam.global_position.x - 2.94
	if is_instance_valid(canoa):
		canoa_x = (canoa as Node3D).global_position.x
	var vivas: Array = []
	for g in _gargolas:
		if not is_instance_valid(g) or (g as Node3D).is_queued_for_deletion():
			continue
		var gn := g as Node3D
		# Fuera del encuadre: jamÃ¡s atacar desde afuera; se revierte a crucero.
		if not _gargola_en_pantalla(g, cam):
			if "current_state" in g and int(g.get("current_state")) == 1:
				if g.has_method("_change_state"):
					g.call("_change_state", 0)
				if "fase_combate" in g:
					g.set("fase_combate", 0)
				if g.has_method("_apagar_omni_light"):
					g.call("_apagar_omni_light")
			gn.global_position.x -= maxf(gargola_velocidad_crucero, 0.5) * delta
			if gn.global_position.x < cam.global_position.x - gargola_margen_x:
				_reciclar_gargola(g, gn, cam)
				continue
			vivas.append(g)
			continue
		# Atacante designada que alcanza la mitad del trayecto: forzar disparo.
		if g in _gargolas_forzadas and not (g in _gargolas_ataque_forzado):
			if gn.global_position.x <= canoa_x + maxf(gargola_rango_mitad_x, 0.5):
				_forzar_ataque_gargola(g)
		# En combate (SHOOTING=1) se queda fija para completar el ataque en
		# mitad de pantalla en vez de cruzar de largo sin disparar.
		var en_combate: bool = false
		if "current_state" in g:
			en_combate = int(g.get("current_state")) == 1
		if not en_combate:
			gn.global_position.x -= maxf(gargola_velocidad_crucero, 0.5) * delta
		if gn.global_position.x < cam.global_position.x - gargola_margen_x:
			_reciclar_gargola(g, gn, cam)
			continue
		vivas.append(g)
	_gargolas = vivas


## Las gÃ¡rgolas aparecen solo una vez durante la fase 2; al salir por la izquierda
## se eliminan definitivamente y no reentran por la derecha (evita segunda tanda fantasma).
func _reciclar_gargola(g: Node, gn: Node3D, _cam: Camera3D = null) -> void:
	_gargolas_forzadas.erase(g)
	_gargolas_ataque_forzado.erase(g)
	if is_instance_valid(gn) and not gn.is_queued_for_deletion():
		gn.queue_free()


func _obtener_offset_zona_verde(indice: int) -> float:
	var off_x: float = offsets_caida_x[clampi(indice, 0, offsets_caida_x.size() - 1)] if not offsets_caida_x.is_empty() else 0.0
	return clampf(off_x, OFFSET_ZONA_VERDE_MIN_X, OFFSET_ZONA_VERDE_MAX_X)


func _calcular_punto_caida(indice: int) -> Vector3:
	var canoa := _obtener_canoa()
	var off_x: float = _obtener_offset_zona_verde(indice)
	if is_instance_valid(canoa):
		return Vector3(canoa.global_position.x + off_x, altura_caida_y, canoa.global_position.z)
	var cam := _obtener_camara_activa()
	if cam != null:
		var x_estimada_canoa: float = cam.global_position.x - 2.94
		return Vector3(x_estimada_canoa + off_x, altura_caida_y, -7.5)
	return Vector3(global_position.x + off_x, altura_caida_y, global_position.z)


func _volver_a_fase1() -> void:
	if _jefe_muerto:
		return
	if is_instance_valid(_tween_crucero_fondo) and _tween_crucero_fondo.is_running():
		_tween_crucero_fondo.kill()
	_secuencia_fase2_activa = false
	_misiles.clear()
	for mc in _misiles_cosmeticos:
		if is_instance_valid(mc) and not mc.is_queued_for_deletion():
			mc.queue_free()
	_misiles_cosmeticos.clear()
	_misiles_resueltos = 0
	_tanda_actual = 0
	_limpiar_gargolas()
	_dano_fase = 0
	_disparo_canon_realizado = false
	_crucero_fondo_completado = false
	_restaurar_escala_fondo()
	_fase_jefe = FaseJefe.FASE1
	_is_invulnerable = false
	_construir_cola_mezcla()
	_reactivar_colisiones()
	_offsets_deck_usados.clear()
	# Restaurar orientación hacia la izquierda (hacia la canoa)
	rotation_degrees = Vector3.ZERO
	# Vuelve al punto de combate y reemerge desde sumergido como al inicio.
	visible = true
	global_position = Vector3(_pos_combate.x, _altura_objetivo_y - profundidad_sumergido, _pos_combate.z)
	current_state = State.SUMERGIDO
	fase_cambiada.emit(int(_fase_jefe))
	_restaurar_travesia()
	emerger()


# === APOYO NIVEL / CANOA / CÃMARA ===

func _obtener_canoa() -> Node3D:
	if is_inside_tree() and get_tree() != null:
		var canoa_grupo := get_tree().get_first_node_in_group("canoa_protagonista") as Node3D
		if is_instance_valid(canoa_grupo):
			return canoa_grupo
		var escena := get_tree().current_scene
		if is_instance_valid(escena):
			var hallada := escena.find_child("CanoaProtagonistaRio", true, false) as Node3D
			if is_instance_valid(hallada):
				return hallada
	var p: Node = get_parent()
	while is_instance_valid(p):
		var hallada_p := p.find_child("CanoaProtagonistaRio", true, false) as Node3D
		if is_instance_valid(hallada_p):
			return hallada_p
		p = p.get_parent()
	return null


func _pausar_travesia_fase2() -> void:
	var nivel := get_parent()
	if is_instance_valid(nivel) and nivel.has_method("set_travesia_activa"):
		nivel.call("set_travesia_activa", false)


func _centrar_canoa_en_camara() -> void:
	_pausar_travesia_fase2()


func _restaurar_travesia() -> void:
	var nivel := get_parent()
	if is_instance_valid(nivel) and nivel.has_method("set_travesia_activa"):
		nivel.call("set_travesia_activa", true)


func _reactivar_colisiones() -> void:
	for col in find_children("*", "CollisionShape3D", true, false):
		if col is CollisionShape3D:
			(col as CollisionShape3D).set_deferred("disabled", false)


func _reactivar_colisiones_parcial() -> void:
	# En fase 2 el casco y la cubierta NO deben colisionar con la canoa ni la protagonista
	_desactivar_colisiones()
	if is_instance_valid(_canon_modelo):
		for col in _canon_modelo.find_children("*", "CollisionShape3D", true, false):
			if col is CollisionShape3D:
				(col as CollisionShape3D).set_deferred("disabled", false)
