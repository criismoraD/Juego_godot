@tool
extends EditorPlugin

const RUTA_SHADER_TOON := "res://Assets/Shaders/TOON_LINEANEGRA.gdshader"

var Panel_Principal: VBoxContainer
var Etiqueta_Estado: Label
var Boton_Procesar_Glb: Button
var Boton_Panel_Inferior: Button


func _enter_tree() -> void:
	_crear_ui()
	Boton_Panel_Inferior = add_control_to_bottom_panel(Panel_Principal, "Arquera GLB")


func _exit_tree() -> void:
	if Panel_Principal:
		remove_control_from_bottom_panel(Panel_Principal)
		Panel_Principal.queue_free()
		Panel_Principal = null
	Boton_Panel_Inferior = null


func _crear_ui() -> void:
	Panel_Principal = VBoxContainer.new()
	Panel_Principal.name = "Arquera GLB"

	var titulo := Label.new()
	titulo.text = "Procesador GLB"
	Panel_Principal.add_child(titulo)

	var descripcion := Label.new()
	descripcion.text = "Selecciona un archivo .glb en FileSystem y presiona el boton."
	descripcion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Panel_Principal.add_child(descripcion)

	Boton_Procesar_Glb = Button.new()
	Boton_Procesar_Glb.text = "Extraer material + difuso + next_pass"
	Boton_Procesar_Glb.pressed.connect(_on_boton_procesar_glb_presionado)
	Panel_Principal.add_child(Boton_Procesar_Glb)

	Etiqueta_Estado = Label.new()
	Etiqueta_Estado.text = "Estado: esperando seleccion."
	Etiqueta_Estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Panel_Principal.add_child(Etiqueta_Estado)


func _on_boton_procesar_glb_presionado() -> void:
	var rutas_seleccionadas := PackedStringArray()
	var interfaz := get_editor_interface()

	if interfaz.has_method("get_selected_paths"):
		rutas_seleccionadas = interfaz.get_selected_paths()

	if rutas_seleccionadas.is_empty() and interfaz.has_method("get_current_path"):
		var ruta_actual: String = interfaz.get_current_path()
		if not ruta_actual.is_empty():
			rutas_seleccionadas.append(ruta_actual)

	var ruta_glb := _obtener_ruta_glb_seleccionada(rutas_seleccionadas)
	if ruta_glb.is_empty():
		_mostrar_estado("Error: selecciona un archivo .glb en FileSystem.", true)
		return

	var resultado := _procesar_glb_seleccionado(ruta_glb)
	if resultado["error"] != OK:
		_mostrar_estado("Error: %s" % resultado["mensaje"], true)
		return

	if interfaz.get_resource_filesystem():
		interfaz.get_resource_filesystem().scan()

	_mostrar_estado("OK: %s" % resultado["mensaje"], false)


func _obtener_ruta_glb_seleccionada(rutas: PackedStringArray) -> String:
	for ruta in rutas:
		if ruta.to_lower().ends_with(".glb"):
			return ruta
	return ""


func _procesar_glb_seleccionado(ruta_glb: String) -> Dictionary:
	if not _es_ruta_segura(ruta_glb):
		return {
			"error": ERR_INVALID_PARAMETER,
			"mensaje": "Ruta no segura detectada: %s" % ruta_glb
		}

	var shader_toon := ResourceLoader.load(RUTA_SHADER_TOON)
	if not (shader_toon is Shader):
		return {
			"error": ERR_FILE_NOT_FOUND,
			"mensaje": "No se encontro el shader TOON_LINEANEGRA.gdshader."
		}

	var textura_difusa := _buscar_textura_difusa_en_carpeta(ruta_glb)
	var material_final := _crear_material_final(textura_difusa, shader_toon)
	var ruta_material := _generar_ruta_material(ruta_glb)
	var error_guardado_material := ResourceSaver.save(material_final, ruta_material)
	if error_guardado_material != OK:
		return {
			"error": error_guardado_material,
			"mensaje": "No se pudo guardar el material externo."
		}

	var resultado_import := _aplicar_material_externo_en_import(ruta_glb, ruta_material)
	if resultado_import["error"] != OK:
		return resultado_import

	_forzar_reimport_glb(ruta_glb)

	var total_materiales: int = int(resultado_import["total_materiales"])
	var mensaje_ok := "Import actualizado con Use External en %d material(es). Material: %s" % [total_materiales, ruta_material]
	if textura_difusa == null:
		mensaje_ok += " (Sin textura difusa encontrada en carpeta)"

	return {
		"error": OK,
		"mensaje": mensaje_ok
	}


func _crear_material_final(textura_difusa: Texture2D, shader_toon: Shader) -> StandardMaterial3D:
	var material_base := StandardMaterial3D.new()
	material_base.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	if textura_difusa:
		material_base.albedo_texture = textura_difusa

	var material_outline := ShaderMaterial.new()
	material_outline.shader = shader_toon
	material_base.next_pass = material_outline

	return material_base


func _aplicar_material_externo_en_import(ruta_glb: String, ruta_material: String) -> Dictionary:
	var ruta_import := "%s.import" % ruta_glb
	var config := ConfigFile.new()
	var error_carga := config.load(ruta_import)
	if error_carga != OK:
		return {
			"error": error_carga,
			"mensaje": "No se pudo leer el archivo .import del GLB."
		}

	var subrecursos = config.get_value("params", "_subresources", {})
	if not (subrecursos is Dictionary):
		return {
			"error": ERR_PARSE_ERROR,
			"mensaje": "El .import no contiene _subresources valido."
		}

	var materiales = subrecursos.get("materials", {})
	if not (materiales is Dictionary) or materiales.is_empty():
		return {
			"error": ERR_UNAVAILABLE,
			"mensaje": "No se encontraron materiales en _subresources del GLB."
		}

	var uid_material := ResourceLoader.get_resource_uid(ruta_material)
	var uid_texto := ""
	if uid_material > 0:
		uid_texto = ResourceUID.id_to_text(uid_material)

	for nombre_material in materiales.keys():
		var data_material = materiales[nombre_material]
		if data_material is Dictionary:
			data_material["use_external/enabled"] = true
			data_material["use_external/fallback_path"] = ruta_material
			if not uid_texto.is_empty():
				data_material["use_external/path"] = uid_texto
			materiales[nombre_material] = data_material

	subrecursos["materials"] = materiales
	config.set_value("params", "_subresources", subrecursos)

	var error_guardado := config.save(ruta_import)
	if error_guardado != OK:
		return {
			"error": error_guardado,
			"mensaje": "No se pudo guardar el archivo .import con Use External."
		}

	return {
		"error": OK,
		"mensaje": "Import actualizado.",
		"total_materiales": materiales.size()
	}


func _forzar_reimport_glb(ruta_glb: String) -> void:
	var fs = get_editor_interface().get_resource_filesystem()
	if fs and fs.has_method("reimport_files"):
		fs.reimport_files(PackedStringArray([ruta_glb]))
	elif fs:
		fs.scan()


func _buscar_textura_difusa_en_carpeta(ruta_glb: String) -> Texture2D:
	var carpeta := ruta_glb.get_base_dir()

	if not _es_ruta_segura(carpeta):
		return null

	var nombre_base := ruta_glb.get_file().get_basename()

	var candidatos := [
		"%s_D.png" % nombre_base,
		"%s_D.jpg" % nombre_base,
		"%s_D.jpeg" % nombre_base,
		"%s.png" % nombre_base,
		"%s.jpg" % nombre_base,
		"%s.jpeg" % nombre_base,
	]

	for archivo in candidatos:
		var ruta_candidata := carpeta.path_join(archivo)
		if ResourceLoader.exists(ruta_candidata):
			var textura := ResourceLoader.load(ruta_candidata)
			if textura is Texture2D:
				return textura

	var dir := DirAccess.open(carpeta)
	if dir == null:
		return null

	dir.list_dir_begin()
	var archivo_actual := dir.get_next()
	while not archivo_actual.is_empty():
		if not dir.current_is_dir():
			var nombre_minus := archivo_actual.to_lower()
			if nombre_minus.ends_with(".png") or nombre_minus.ends_with(".jpg") or nombre_minus.ends_with(".jpeg") or nombre_minus.ends_with(".webp"):
				var ruta_textura := carpeta.path_join(archivo_actual)
				var textura_encontrada := ResourceLoader.load(ruta_textura)
				if textura_encontrada is Texture2D:
					dir.list_dir_end()
					return textura_encontrada
		archivo_actual = dir.get_next()
	dir.list_dir_end()

	return null


func _generar_ruta_material(ruta_glb: String) -> String:
	var carpeta := ruta_glb.get_base_dir()
	var nombre_glb := ruta_glb.get_file().get_basename()
	var nombre_archivo := "%s_MAT.tres" % nombre_glb
	return carpeta.path_join(nombre_archivo)


func _mostrar_estado(mensaje: String, es_error: bool) -> void:
	if Etiqueta_Estado == null:
		return
	Etiqueta_Estado.text = mensaje
	Etiqueta_Estado.modulate = Color(1, 0.5, 0.5) if es_error else Color(0.7, 1, 0.7)


func _es_ruta_segura(ruta: String) -> bool:
	# Solo permitir rutas dentro de res:// (el sistema de archivos del proyecto)
	if not ruta.begins_with("res://"):
		return false

	# Evitar ataques de path traversal bloqueando secuencias ".."
	# Godot generalmente las normaliza, pero es mejor prevenir explicitamente
	if ".." in ruta or "\\" in ruta:
		return false

	return true
