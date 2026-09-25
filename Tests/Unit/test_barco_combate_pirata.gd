extends "res://addons/gut/test.gd"

## Tests del barco pirata de combate (gemelo de la balsa con modelo propio).

const BARCO_SCENE: PackedScene = preload("res://Entities/Ambiente_Barco_Combate_Pirata/BarcoCombatePirata.tscn")
const BALSA_SCENE: PackedScene = preload("res://Entities/Ambiente_Balsa_Pirata/BalsaPirataCombate.tscn")
const CANOA_ESCENA: PackedScene = preload("res://Levels/Rio_En_Canoa_Con_Parallax/CanoaProtagonistaRio.tscn")
const HACHA_SCENE: PackedScene = preload("res://Entities/Proyectil_Hacha_Perrena/HachaPerrena.tscn")

var _root_test: Node3D = null


func before_each() -> void:
	_root_test = Node3D.new()
	_root_test.name = "RootTestBarcoCombate"
	get_tree().root.add_child(_root_test)
	get_tree().current_scene = _root_test


func after_each() -> void:
	if is_instance_valid(_root_test):
		_root_test.free()
	for n in get_tree().root.get_children():
		if n is BarcoCombatePirata or n is EnemyBase:
			n.free()


func _crear_barco() -> BarcoCombatePirata:
	var barco := BARCO_SCENE.instantiate() as BarcoCombatePirata
	assert_not_null(barco, "Debe instanciar BarcoCombatePirata")
	barco.position = Vector3(30.0, 0.0, -7.5)
	barco.activar_al_entrar_en_camara = false
	_root_test.add_child(barco)
	return barco


func test_barco_instancia_con_textura_propia_y_vida() -> void:
	# Arrange & Act
	var barco := _crear_barco()

	# Assert: modelo con su textura, casco enemigo y 16 de vida
	assert_true(barco is BalsaPirataCombate, "Debe heredar el combate de la balsa")
	var modelo := barco.find_child("BarcoModel", true, false)
	assert_not_null(modelo, "Debe traer el modelo del barco")
	var con_textura := false
	for m in modelo.find_children("*", "MeshInstance3D", true, false):
		var mat := (m as MeshInstance3D).material_override as StandardMaterial3D
		if mat and mat.albedo_texture and "Barco Combate Pirata_D" in mat.albedo_texture.resource_path:
			con_textura = true
			break
	assert_true(con_textura, "Debe usar su textura difusa")
	var casco := barco.find_child("CascoBarco", true, false) as StaticBody3D
	assert_not_null(casco, "Debe tener casco con colisión")
	assert_true(casco.collision_layer & 4 != 0, "El casco debe estar en capa de enemigos")
	assert_not_null(barco.find_child("PlataformaCubierta", true, false), "Debe tener plataforma como la balsa")
	assert_almost_eq(barco.vida_actual, 16.0, 0.001, "16 de vida como la balsa")


func test_barco_tres_cubiertas_a_distinta_altura() -> void:
	# Arrange & Act
	var barco := _crear_barco()
	var cub := barco.find_child("PlataformaCubierta", true, false) as Node3D
	assert_not_null(cub, "Debe existir PlataformaCubierta")

	# Assert: 3 cajas (proa/centro/popa) con las cimas escalonadas
	var cimas := []
	for n in cub.find_children("*", "CollisionShape3D", true, false):
		var col := n as CollisionShape3D
		var caja := col.shape as BoxShape3D
		assert_not_null(caja, "Cada cubierta debe ser caja")
		cimas.append(col.position.y + caja.size.y * 0.5)
	assert_eq(cimas.size(), 3, "3 cubiertas: proa, centro y popa")
	cimas.sort()
	assert_gt(cimas[1] - cimas[0], 0.02, "Niveles escalonados 1-2")
	assert_gt(cimas[2] - cimas[1], 0.02, "Niveles escalonados 2-3")

	# Assert: cimas absolutas = constante x escala del modelo (código y cajas amarrados)
	var modelo := barco.find_child("BarcoModel", true, false) as Node3D
	assert_not_null(modelo, "Debe existir BarcoModel")
	var s: float = modelo.scale.x
	var nombres := ["CubiertaProa", "CubiertaCentro", "CubiertaPopa"]
	for n in cub.find_children("*", "CollisionShape3D", true, false):
		var col := n as CollisionShape3D
		if not (col.name in nombres):
			continue
		var idx: int = nombres.find(col.name)
		var caja2 := col.shape as BoxShape3D
		var cima: float = col.position.y + caja2.size.y * 0.5
		var esperada: float = float(BarcoCombatePirata.CUBIERTAS_GLB[idx]["y"]) * s
		assert_almost_eq(cima, esperada, 0.02, "Cima de " + col.name + " = constante")
		# Largo: caja = constante (ambos en local del barco)
		var esp_min: float = float(BarcoCombatePirata.CUBIERTAS_GLB[idx]["x_min"]) * s
		var esp_max: float = float(BarcoCombatePirata.CUBIERTAS_GLB[idx]["x_max"]) * s
		assert_almost_eq(col.position.x - caja2.size.x * 0.5, esp_min, 0.02, "Inicio de " + col.name)
		assert_almost_eq(col.position.x + caja2.size.x * 0.5, esp_max, 0.02, "Fin de " + col.name)


func test_barco_reparte_puestos_en_tres_cubiertas() -> void:
	# Arrange: 3 arqueras ordenadas (una por cubierta)
	var barco := _crear_barco()
	barco.cantidad_goblin_arquera = 3
	barco.mezclar_orden_aleatorio = false
	barco.intervalo_spawn = 0.0
	barco.activar()
	for i in range(5):
		barco._process(0.1)

	# Act: niveles Y locales de los puestos asignados
	var niveles := {}
	for n in barco.find_children("*", "CharacterBody3D", true, false):
		if n is EnemyBase:
			var local_y: float = snappedf(barco.to_local((n as Node3D).global_position).y, 0.01)
			niveles[local_y] = true

	# Assert: 3 alturas distintas = una por cubierta
	assert_eq(niveles.size(), 3, "Los puestos deben cubrir las 3 cubiertas")


func test_barco_despliega_mezcla_embarcada() -> void:
	# Arrange: 2 piratas + 1 arquera
	var barco := _crear_barco()
	barco.cantidad_pirata = 2
	barco.cantidad_goblin_arquera = 1
	barco.mezclar_orden_aleatorio = false
	barco.intervalo_spawn = 0.0
	barco.activar()
	for i in range(5):
		barco._process(0.1)

	# Assert: 3 embarcados atacando
	var total := 0
	for n in barco.find_children("*", "CharacterBody3D", true, false):
		if n is EnemyBase:
			total += 1
			assert_eq((n as Node3D).get_parent(), barco, "Cada tripulante cuelga del barco")
			assert_eq((n as EnemyBase).current_state, EnemyBase.State.SHOOTING, "Atacando al desplegar")
	assert_eq(total, 3, "Mezcla completa embarcada")


func test_barco_se_disuelve_sin_pecio_de_balsa() -> void:
	# Arrange
	var barco := _crear_barco()
	barco.activar()

	# Act: destruir el casco
	barco.destruir_balsa()

	# Assert: disolver con su textura y sin aparecer el pecio de balsa
	assert_null(barco.find_child("BalsaPirataModel", true, false), "No debe aparecer el pecio de balsa")
	var con_disolver := 0
	for m in barco.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi and mi.material_override is ShaderMaterial:
			var sm := mi.material_override as ShaderMaterial
			if sm.shader == BalsaPirataCombate.SHADER_DISOLVER:
				con_disolver += 1
				assert_not_null(sm.get_shader_parameter("albedo_texture"), "Con su textura, no plano")
	assert_gt(con_disolver, 0, "El barco debe disolverse")


func test_barco_casco_aguanta_16_impactos() -> void:
	# Arrange
	var barco := _crear_barco()
	barco.activar()

	# Act & Assert
	barco.take_damage(15.0)
	assert_false(barco.esta_destruida(), "Con 15 sigue a flote")
	barco.take_damage(1.0)
	assert_true(barco.esta_destruida(), "Con 16 se destruye")


func test_barco_inactivo_mantiene_flotacion() -> void:
	# Arrange: sin cámara cerca sigue inactivo (activar_al_entrar_en_camara = false)
	var barco := _crear_barco()
	assert_true(barco.esta_flotando(), "Flota desde el primer frame")

	# Act: varios frames inactivo
	var muestras: Array[float] = []
	for i in range(6):
		await wait_frames(10)
		muestras.append(barco.position.y + barco.rotation_degrees.z)

	# Assert: se mece (sin navegar ni tripular)
	var min_m: float = muestras.min()
	var max_m: float = muestras.max()
	assert_gt(max_m - min_m, 0.0005, "Inactivo también se mece sobre el agua")
	assert_false(barco.esta_navegando(), "Inactivo no navega")


func test_barco_grande_se_detiene_con_proa_fuera() -> void:	# Arrange: casco grande (proa 3 m por delante del origen) navegando a la canoa
	var barco := _crear_barco()
	barco.extension_proa = 3.0
	barco.navegar_al_activar = true
	barco.x_destino_navegacion = -30.0
	barco.velocidad_navegacion_combate = 1.5
	barco.activar()
	var canoa: CanoaProtagonistaRio = CANOA_ESCENA.instantiate() as CanoaProtagonistaRio
	_root_test.add_child(canoa)

	# Act: canoa a dx=5 (dentro de detención base 3.5, fuera de efectiva 6.5)
	canoa.global_position = Vector3(barco._posicion_base.x - 5.0, 0.0, -7.5)
	barco._process(0.1)

	# Assert: detenido aunque el origen siga a 5 m (la proa queda a ~2 m)
	assert_false(barco.esta_navegando(), "Con proa grande debe detenerse antes")
	var dx_final: float = barco._posicion_base.x - canoa.global_position.x
	assert_gte(dx_final, 3.5 + 3.0, "El origen se detiene a detención + proa")

	# Cleanup
	canoa.free()


func test_barco_destruido_tripulacion_muere_normal() -> void:
	# Arrange: 1 arquera a bordo
	var barco := _crear_barco()
	barco.cantidad_goblin_arquera = 1
	barco.intervalo_spawn = 0.0
	barco.navegar_al_activar = false
	barco.activar()
	for i in range(5):
		barco._process(0.2)
	assert_false(barco._enemigos_vivos.is_empty(), "Debe haber tripulación a bordo")
	var tripulante: EnemyBase = barco._enemigos_vivos[0] as EnemyBase
	assert_not_null(tripulante, "La tripulación son enemigos reales")

	# Act: destruir el casco de 16
	barco.take_damage(16.0)

	# Assert: muere con su animación normal, no desaparece
	assert_true(is_instance_valid(tripulante), "No debe desaparecer al instante")
	assert_true(
		tripulante.current_state == EnemyBase.State.DYING or tripulante.current_state == EnemyBase.State.DEAD,
		"Debe entrar en muerte normal con animación"
	)


func test_barco_hundimiento_tiene_sonido_registrado() -> void:
	# Arrange & Act: la clave que reproduce el barco al destruirse
	var clave: String = BarcoCombatePirata.SFX_HUNDIMIENTO

	# Assert: registrada en el AudioManager con el mp3 del barco
	assert_true(AudioManager.sfx_streams.has(clave), "La clave debe estar registrada")
	assert_false((AudioManager.sfx_streams[clave] as Array).is_empty(), "Debe tener el mp3 cargado")


func test_barco_puestos_en_zigzag_para_linea_de_tiro() -> void:
	# Arrange: 9 arqueras (3 por cubierta)
	var barco := _crear_barco()
	barco.cantidad_goblin_arquera = 9
	barco.mezclar_orden_aleatorio = false
	barco._construir_cola_mezcla()
	barco._construir_puestos_cubiertas()

	# Act: agrupar puestos por cubierta (tercio de la cola)
	var total: int = barco._puestos.size()
	assert_eq(total, 9, "9 puestos para 9 tripulantes")

	# Assert: en cada cubierta con >1 ocupante hay zigzag en Z dentro de la caja
	for di in range(3):
		var zs: Array[float] = []
		for k in range(3):
			var p: Vector3 = barco._puestos[di + k * 3]
			zs.append(p.z)
		var z_max: float = float(BarcoCombatePirata.CUBIERTAS_GLB[di]["z"]) * 1.3
		for z in zs:
			assert_lte(absf(z), z_max + 0.001, "Puesto dentro del ancho de cubierta")
		assert_gt(maxf(absf(zs[0] - zs[1]), absf(zs[1] - zs[2])), 0.01, "Zigzag: no en fila india")


func test_barco_activa_efecto_aparicion_morado_y_balsa_no() -> void:
	# Arrange & Act
	var barco := _crear_barco()
	var balsa := BALSA_SCENE.instantiate() as BalsaPirataCombate
	_root_test.add_child(balsa)

	# Assert: solo el barco materializa su tripulación en morado
	assert_true(barco.efecto_aparicion_morado, "El barco debe traer el efecto morado activo")
	assert_false(balsa.efecto_aparicion_morado, "La balsa mantiene el despliegue clásico por defecto")
	assert_eq(barco.color_aparicion_morado, Color(0.8, 0.2, 0.8), "Morado estándar del proyecto")
	assert_almost_eq(barco.duracion_aparicion_morado, 1.2, 0.001, "Misma duración que el escudo al reconstruirse")

	# Cleanup
	balsa.free()


func test_barco_tripulacion_aparece_con_disolucion_morada() -> void:
	# Arrange: 1 arquera, despliegue inmediato
	var barco := _crear_barco()
	barco.cantidad_goblin_arquera = 1
	barco.mezclar_orden_aleatorio = false
	barco.intervalo_spawn = 0.0
	barco.navegar_al_activar = false

	# Act: activar y desplegar un tripulante
	barco.activar()
	barco._process(0.1)

	# Assert: el tripulante usa el shader de disolver con borde morado (como el escudo, en morado)
	assert_false(barco._enemigos_vivos.is_empty(), "Debe haber desplegado al tripulante")
	var tripulante := barco._enemigos_vivos[0] as Node3D
	assert_not_null(tripulante, "El tripulante debe ser un Node3D válido")
	var con_disolver := 0
	for m in tripulante.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi and mi.material_override is ShaderMaterial:
			var sm := mi.material_override as ShaderMaterial
			if sm.shader == BalsaPirataCombate.SHADER_DISOLVER:
				con_disolver += 1
				assert_eq(sm.get_shader_parameter("glow_color"), Color(0.8, 0.2, 0.8), "Borde morado de aparición")
				var dis: float = float(sm.get_shader_parameter("dissolve_amount"))
				assert_gte(dis, 0.0, "Disolución en curso (>= 0)")
				assert_lte(dis, 1.0, "Disolución en curso (<= 1)")
	assert_gt(con_disolver, 0, "El tripulante debe materializarse con disolución")


func test_barco_tripulacion_sombra_pies_sin_disolver() -> void:
	# Arrange: 1 arquera con efecto morado (por defecto en el barco)
	var barco := _crear_barco()
	barco.cantidad_goblin_arquera = 1
	barco.mezclar_orden_aleatorio = false
	barco.intervalo_spawn = 0.0
	barco.navegar_al_activar = false

	# Act: activar y desplegar el tripulante
	barco.activar()
	barco._process(0.1)

	# Assert: la sombra falsa de los pies conserva su shader propio (sin
	# cuadrado blanco: el disolver sin textura base se renderiza blanco)
	assert_false(barco._enemigos_vivos.is_empty(), "Debe haber desplegado al tripulante")
	var tripulante := barco._enemigos_vivos[0] as Node3D
	assert_not_null(tripulante, "El tripulante debe ser un Node3D válido")
	var sombra := tripulante.find_child("SombraMesh", true, false) as MeshInstance3D
	assert_not_null(sombra, "El tripulante debe tener la sombra de pies")
	var sm := sombra.material_override as ShaderMaterial
	assert_not_null(sm, "La sombra debe conservar su material propio")
	assert_ne(sm.shader, BalsaPirataCombate.SHADER_DISOLVER, "La sombra no debe recibir el disolver")
	# Y el cuerpo sí sigue materializándose con el disolver morado
	var con_disolver := 0
	for m in tripulante.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi == sombra:
			continue
		if mi and mi.material_override is ShaderMaterial:
			var dm := mi.material_override as ShaderMaterial
			if dm.shader == BalsaPirataCombate.SHADER_DISOLVER:
				con_disolver += 1
	assert_gt(con_disolver, 0, "El cuerpo debe seguir materializándose con disolución")


func test_barco_tripulacion_sin_efecto_si_se_desactiva() -> void:
	# Arrange: efecto desactivado a mano
	var barco := _crear_barco()
	barco.efecto_aparicion_morado = false
	barco.cantidad_goblin_arquera = 1
	barco.mezclar_orden_aleatorio = false
	barco.intervalo_spawn = 0.0
	barco.navegar_al_activar = false

	# Act
	barco.activar()
	barco._process(0.1)

	# Assert: despliegue clásico sin disolver
	assert_false(barco._enemigos_vivos.is_empty(), "Debe haber desplegado al tripulante")
	var tripulante := barco._enemigos_vivos[0] as Node3D
	var con_disolver := 0
	for m in tripulante.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi and mi.material_override is ShaderMaterial:
			var sm := mi.material_override as ShaderMaterial
			if sm.shader == BalsaPirataCombate.SHADER_DISOLVER:
				con_disolver += 1
	assert_eq(con_disolver, 0, "Sin efecto no debe aplicar disolución al aparecer")


func _recolectar_nadadoras() -> Array:
	var lista: Array = []
	for n in _root_test.find_children("*", "Node3D", true, false):
		if n is PirataNadadora:
			lista.append(n)
	return lista


func _recolectar_ondas() -> Array:
	var lista: Array = []
	for n in _root_test.find_children("*", "Node3D", true, false):
		var nn := n as Node
		if nn and "splash_vfx" in nn.scene_file_path:
			lista.append(nn)
	return lista


func test_barco_destruido_suelta_dos_nadadoras_en_el_agua() -> void:
	# Arrange: barco quieto (sin navegar) para rumbo determinista
	var barco := _crear_barco()
	barco.navegar_al_activar = false
	barco.activar()
	var y_casco: float = barco.global_position.y

	# Act: destruir el casco de 16 impactos
	barco.take_damage(16.0)

	# Assert: 2 nadadoras en escena, a nivel del agua y rumbo a la izquierda
	var nadadoras := _recolectar_nadadoras()
	assert_eq(nadadoras.size(), 2, "Deben aparecer 2 goblin piratas nadadoras")
	assert_eq(barco.obtener_nadadoras().size(), 2, "El barco debe rastrearlas")
	for nad in nadadoras:
		var nd := nad as PirataNadadora
		assert_almost_eq(nd.global_position.y, y_casco + barco.offset_y_agua, 0.05, "En el agua, no en la cubierta")
		assert_eq(nd.direccion_x, -1.0, "Barco quieto: rumbo a la izquierda")
		assert_almost_eq(nd.rotation.y, -PI * 0.5, 0.01, "Girada de lado (perfil) hacia el rumbo")
		assert_almost_eq(nd.scale.x, barco.escala_nadadoras, 0.01, "Tamaño de tripulación")
		assert_eq(nd.tiempo_maximo_visible, 10.0, "10 segundos en cuadro antes de desvanecerse")


func test_nadadoras_no_cuentan_como_enemigas_ni_colisionan() -> void:
	# Arrange & Act
	var barco := _crear_barco()
	barco.navegar_al_activar = false
	barco.activar()
	barco.take_damage(16.0)

	# Assert: decorativas puras (sin grupos, sin físicas) con nado en marcha
	var nadadoras := _recolectar_nadadoras()
	assert_gt(nadadoras.size(), 0, "Debe haber nadadoras para inspeccionar")
	for nad in nadadoras:
		var nd := nad as PirataNadadora
		assert_false(nd.is_in_group("enemies"), "No debe contar como enemiga")
		assert_false(nd.is_in_group("enemigos"), "Tampoco en el grupo en español")
		assert_false((nd as Object) is EnemyBase, "Sin lógica de enemigo")
		assert_eq(nd.find_children("*", "CollisionShape3D", true, false).size(), 0, "Sin colisión")
		assert_eq(nd.find_children("*", "CollisionObject3D", true, false).size(), 0, "Sin cuerpos físicos")
		var ap := nd.find_child("AnimationPlayer", true, false) as AnimationPlayer
		assert_not_null(ap, "Debe traer su AnimationPlayer")
		assert_true(ap.is_playing(), "Nadando desde el primer frame")
		assert_true("nadar" in ap.current_animation.to_lower(), "Con su animación de nadar")
		var frontal_ok := false
		for m in nd.find_children("*", "MeshInstance3D", true, false):
			var mat := (m as MeshInstance3D).material_override as StandardMaterial3D
			if mat and mat.no_depth_test and mat.render_priority == 127:
				frontal_ok = true
				break
		assert_true(frontal_ok, "Material frontal (delante de la canoa, prioridad máxima)")
	var en_grupo: Array = get_tree().get_nodes_in_group("enemies")
	for nad in nadadoras:
		assert_false(en_grupo.has(nad), "El wave spawner no debe verlas")


func test_nadadora_se_desvanece_como_al_morir_pasado_el_tiempo() -> void:
	# Arrange: timeout corto para no esperar los 10 segundos reales
	var barco := _crear_barco()
	barco.navegar_al_activar = false
	barco.activar()
	barco.take_damage(16.0)
	var nadadoras := _recolectar_nadadoras()
	assert_gt(nadadoras.size(), 0, "Debe haber nadadoras para inspeccionar")
	var nad := nadadoras[0] as PirataNadadora
	nad.tiempo_maximo_visible = 0.05

	# Act: dejar correr el nado unos frames
	await wait_frames(20)

	# Assert: disolución enemiga en curso (borde de muerte del pirata)
	assert_true(is_instance_valid(nad), "Sigue en escena durante el desvanecido")
	assert_true(nad.esta_desvaneciendo(), "Pasado el tiempo debe desvanecerse")
	var con_disolver := 0
	for m in nad.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi and mi.material_override is ShaderMaterial:
			var sm := mi.material_override as ShaderMaterial
			if sm.shader == BalsaPirataCombate.SHADER_DISOLVER:
				con_disolver += 1
				assert_eq(sm.get_shader_parameter("glow_color"), PirataNadadora.COLOR_DESVANECIDO, "Borde de muerte del pirata")
	assert_gt(con_disolver, 0, "Debe desvanecerse con la disolución enemiga")


func test_barco_destruido_genera_onda_del_submarino() -> void:
	# Arrange
	var barco := _crear_barco()
	barco.navegar_al_activar = false
	barco.activar()
	var y_casco: float = barco.global_position.y

	# Act: destruir el casco de 16 impactos
	barco.take_damage(16.0)

	# Assert: anillo de onda sobre la superficie, escalado como el submarino
	var ondas := _recolectar_ondas()
	assert_eq(ondas.size(), 1, "Debe generar la onda al hundirse")
	var onda := ondas[0] as Node3D
	assert_almost_eq(onda.global_position.y, y_casco + barco.offset_y_agua + barco.bajar_onda_y, 0.05, "Sobre la superficie del agua, pegada hacia abajo")
	assert_almost_eq(onda.scale.x, barco.escala_onda_hundirse, 0.01, "Escala configurada")
	assert_lt(barco.escala_onda_hundirse, 3.0, "La onda debe ser contenida, no gigante")


func test_barco_sin_onda_si_se_desactiva() -> void:
	# Arrange & Act
	var barco := _crear_barco()
	barco.navegar_al_activar = false
	barco.mostrar_onda_al_hundirse = false
	barco.activar()
	barco.take_damage(16.0)

	# Assert: sin onda pero con nadadoras igual
	assert_eq(_recolectar_ondas().size(), 0, "Sin flag no debe generar onda")
	assert_eq(_recolectar_nadadoras().size(), 2, "Las nadadoras no dependen de la onda")


func test_barco_sacudida_oleaje_bambolea_y_suaviza() -> void:
	# Arrange: amplitudes base del barco
	var barco := _crear_barco()
	var amp_flot_orig: float = barco.amplitud_flotacion
	var amp_bal_orig: float = barco.amplitud_balanceo
	var amp_cab_orig: float = barco.amplitud_cabeceo

	# Act: sacudida como la del Ult de Perrena
	barco.sacudida_oleaje(2.2, 4.5)

	# Assert: bamboleo amplificado y tween de retorno activo
	assert_gt(barco.amplitud_flotacion, amp_flot_orig, "La flotación debe elevarse con la sacudida")
	assert_gt(barco.amplitud_balanceo, amp_bal_orig, "El balanceo debe elevarse con la sacudida")
	assert_gt(barco.amplitud_cabeceo, amp_cab_orig, "El cabeceo debe elevarse con la sacudida")
	assert_not_null(barco._tween_oleaje, "El tween de oleaje debe haberse creado")
	assert_true(barco._tween_oleaje.is_valid(), "El tween de oleaje debe ser válido")


func test_hacha_normal_no_sacude_barco() -> void:
	# Arrange: hacha normal contra el barco
	var barco := _crear_barco()
	var amp_bal_orig: float = barco.amplitud_balanceo
	var hacha: HachaPerrenaProjectile = HACHA_SCENE.instantiate() as HachaPerrenaProjectile
	_root_test.add_child(hacha)
	hacha.initialize(Vector3.RIGHT, 1.0, null)
	hacha.es_hacha_especial = false

	# Act: impacto de hacha normal
	hacha._procesar_impacto(barco, Vector3.ZERO, Vector3.UP)

	# Assert: sin bamboleo de oleaje
	assert_eq(barco.amplitud_balanceo, amp_bal_orig, "El hacha normal no debe sacudir el barco")
	hacha.free()


func test_hacha_especial_ult_sacude_barco_combate() -> void:
	# Arrange: hacha Ult de Perrena contra el barco
	var barco := _crear_barco()
	var amp_bal_orig: float = barco.amplitud_balanceo
	var hacha: HachaPerrenaProjectile = HACHA_SCENE.instantiate() as HachaPerrenaProjectile
	_root_test.add_child(hacha)
	hacha.initialize(Vector3.RIGHT, 1.0, null)
	hacha.es_hacha_especial = true

	# Act: impacto del Ult
	hacha._procesar_impacto(barco, Vector3.ZERO, Vector3.UP)

	# Assert: bamboleo activado con tween en curso
	assert_gt(barco.amplitud_balanceo, amp_bal_orig, "El Ult debe sacudir el barco combate pirata")
	assert_not_null(barco._tween_oleaje, "El tween de oleaje debe estar activo tras el Ult")
	assert_true(barco._tween_oleaje.is_valid(), "El tween de oleaje debe ser válido tras el Ult")
	hacha.free()


func test_barco_al_destruirse_su_colision_no_absorbe_flechas() -> void:
	# Arrange: barco activo con su colisión de casco
	var barco := _crear_barco()
	barco.activar()
	var casco := barco.find_child("CascoBarco", true, false) as StaticBody3D
	var plataforma := barco.find_child("PlataformaCubierta", true, false) as AnimatableBody3D
	assert_not_null(casco, "Debe existir el casco")
	assert_true(barco.is_in_group("enemies"), "Precondición: en el grupo de enemigos")

	# Act: destruir el barco
	barco.destruir_balsa()
	await get_tree().physics_frame

	# Assert: la colisión se apaga de inmediato (no absorbe flechas en el hundimiento)
	assert_true(barco.esta_destruida(), "El barco debe estar marcado como destruido")
	assert_false(barco.is_in_group("enemies"), "Al destruirse sale del grupo de enemigos")
	assert_false(barco.is_in_group("enemigos"), "Al destruirse sale del grupo de enemigos")
	assert_eq(casco.collision_layer, 0, "La capa del casco debe quedar en 0 (sin absorber flechas)")
	assert_eq(casco.collision_mask, 0, "El casco no debe colisionar con nada")
	for col in casco.find_children("*", "CollisionShape3D", true, false):
		assert_true((col as CollisionShape3D).disabled, "La forma del casco debe estar desactivada")
	if is_instance_valid(plataforma):
		assert_eq(plataforma.collision_layer, 0, "La cubierta tampoco debe absorber")


func test_balsa_al_destruirse_su_colision_no_absorbe_flechas() -> void:
	# Arrange: balsa de combate activa
	var balsa := BALSA_SCENE.instantiate() as BalsaPirataCombate
	_root_test.add_child(balsa)
	balsa.activar()

	# Act: destruir
	balsa.destruir_balsa()
	await get_tree().physics_frame

	# Assert: colisiones apagadas al destruirse
	assert_false(balsa.is_in_group("enemies"), "La balsa sale del grupo de enemigos")
	for col in balsa.find_children("*", "CollisionShape3D", true, false):
		assert_true((col as CollisionShape3D).disabled, "Todas las formas deben quedar desactivadas")
