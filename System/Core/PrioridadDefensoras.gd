class_name PrioridadDefensoras
extends RefCounted

## Helper central del sistema de prioridades de las defensoras.
##
## Clases de enemigos:
##   - Voladores: Gárgola, Globo aerostático
##   - Básicos: Imp, Goblin arquero, Goblin ballestero, Limo, Goblin general
##   - Elite: Arquera Lonko, Goblin rosada, Azulina
##   - Guardian: Imp de escudo, Guardiana moradita
##
## Niveles de prioridad:
##   - 0 = sin prioridad: la defensora dispara al azar en un rango, ante su presencia.
##   - 1 = prioridad media: la defensora fija, apunta y dispara al objetivo.
##   - 2 = máxima/alta: la defensora fija inmediatamente a este tipo de enemigos
##     y los elimina de la manera más efectiva posible.
##
## Tabla por defensora:
##   - Arquera: Voladores 2, Básicos 0, Elite 0 (Lonko 1 solo sobre el pilar), Guardian 0.
##   - Ballestera: Voladores 0, Básicos 2, Elite 0 (Rosada 2 solo sin aura barrera), Guardian 0.
##   - Hacha (Perrena): Voladores 0, Básicos 0, Elite 1, Guardian 2.

enum Clase { VOLADOR, BASICO, ELITE, GUARDIAN, DESCONOCIDO }
enum Nivel { SIN = 0, MEDIA = 1, MAXIMA = 2 }


## Clasifica un enemigo en su clase (Volador/Básico/Elite/Guardian).
## Usa tipos (class_name) cuando están disponibles y fallback por nombre/script.
static func clase_de(enemy: Node) -> int:
	if not is_instance_valid(enemy):
		return Clase.DESCONOCIDO
	# --- Por tipo duro (más fiable que el nombre) ---
	if enemy is Gargola or enemy is GloboAerostatico:
		return Clase.VOLADOR
	if enemy is ImpShieldGirl or enemy is GuardianaMoradita:
		return Clase.GUARDIAN
	if enemy is Lonko or enemy is ArqueraRosa or enemy is Azulina:
		return Clase.ELITE
	if enemy is ImpEnemy or enemy is Goblin or enemy is GoblinGirl or enemy is LimoCuadrado or enemy is GoblinGeneral:
		return Clase.BASICO
	# --- Fallback por nombre/script (dummies de test, nodos sin script de clase) ---
	var n: String = enemy.name.to_lower()
	var s: String = ""
	var scr = enemy.get_script()
	if scr and scr is Script:
		s = (scr as Script).resource_path.to_lower()
	if "gargola" in n or "gargola" in s or "gargoyle" in n or "globo" in n or "globo" in s:
		return Clase.VOLADOR
	if ("imp" in n and "escudo" in n) or ("imp" in s and "escudo" in s) or "impshield" in n or "impshield" in s or "imp_escudo" in s:
		return Clase.GUARDIAN
	# Guardiana moradita (nombre tipico "GuardianaMoradita", script Enemigo_Goblina_Escudo_Pesado)
	if "moradita" in n or "moradita" in s or "goblina_escudo" in s:
		return Clase.GUARDIAN
	if "lonko" in n or "lonko" in s or "rosa" in n or "rosa" in s or "azulina" in n or "azulina" in s:
		return Clase.ELITE
	if "goblin" in n or "goblin" in s or "limo" in n or "limo" in s:
		return Clase.BASICO
	if "imp" in n or "imp" in s:
		return Clase.BASICO
	return Clase.DESCONOCIDO


static func es_volador(enemy: Node) -> bool:
	return clase_de(enemy) == Clase.VOLADOR


static func es_basico(enemy: Node) -> bool:
	return clase_de(enemy) == Clase.BASICO


static func es_elite(enemy: Node) -> bool:
	return clase_de(enemy) == Clase.ELITE


static func es_guardian(enemy: Node) -> bool:
	return clase_de(enemy) == Clase.GUARDIAN


static func es_lonko(enemy: Node) -> bool:
	if not is_instance_valid(enemy):
		return false
	if enemy is Lonko:
		return true
	var n: String = enemy.name.to_lower()
	if "lonko" in n:
		return true
	var scr = enemy.get_script()
	if scr and scr is Script and "lonko" in (scr as Script).resource_path.to_lower():
		return true
	return false


static func es_rosada(enemy: Node) -> bool:
	if not is_instance_valid(enemy):
		return false
	if enemy is ArqueraRosa:
		return true
	var n: String = enemy.name.to_lower()
	if "rosa" in n or "rosada" in n:
		return true
	var scr = enemy.get_script()
	if scr and scr is Script:
		var s: String = (scr as Script).resource_path.to_lower()
		if "rosa" in s:
			return true
	return false


## Prioridad de la defensora arquera:
## Voladores 2, Básicos 0, Elite 0 (Lonko 1 solo sobre el pilar), Guardian 0.
static func prioridad_arquera(enemy: Node, lonko_en_pilar_completo: bool = false) -> int:
	if not is_instance_valid(enemy):
		return Nivel.SIN
	if es_volador(enemy):
		return Nivel.MAXIMA
	if es_lonko(enemy) and lonko_en_pilar_completo:
		return Nivel.MEDIA
	return Nivel.SIN


## Prioridad de la defensora ballestera:
## Voladores 0, Básicos 2, Elite 0 (Rosada 2 solo sin aura barrera), Guardian 0.
static func prioridad_ballestera(enemy: Node, rosada_sin_aura: bool = false) -> int:
	if not is_instance_valid(enemy):
		return Nivel.SIN
	if es_basico(enemy):
		return Nivel.MAXIMA
	if es_rosada(enemy) and rosada_sin_aura:
		return Nivel.MAXIMA
	return Nivel.SIN


## Prioridad de la defensora hacha (Perrena):
## Voladores 0, Básicos 0, Elite 1, Guardian 2.
static func prioridad_hacha(enemy: Node) -> int:
	if not is_instance_valid(enemy):
		return Nivel.SIN
	var c: int = clase_de(enemy)
	if c == Clase.GUARDIAN:
		return Nivel.MAXIMA
	if c == Clase.ELITE:
		return Nivel.MEDIA
	return Nivel.SIN
