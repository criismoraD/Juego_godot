extends Node3D

## Escena de prueba interactiva para el sistema de Ragdoll de IMP_CUERPO.

@onready var imp_ragdoll: ImpCuerpoRagdoll = %ImpCuerpoRagdoll
@onready var btn_activar: Button = %BtnActivarRagdoll
@onready var btn_impulso: Button = %BtnActivarImpulso
@onready var btn_reiniciar: Button = %BtnReiniciar
@onready var lbl_estado: Label = %LblEstado


func _ready() -> void:
	_configurar_botones()
	_actualizar_estado("Listo para iniciar simulación")


func _configurar_botones() -> void:
	if btn_activar:
		btn_activar.pressed.connect(func():
			if imp_ragdoll:
				imp_ragdoll.activar_ragdoll(Vector3.ZERO)
				_actualizar_estado("Ragdoll ACTIVADO (Caída libre)")
		)

	if btn_impulso:
		btn_impulso.pressed.connect(func():
			if imp_ragdoll:
				var impulso := Vector3(randf_range(-2.0, 2.0), randf_range(4.0, 7.0), randf_range(-1.0, 1.0))
				imp_ragdoll.activar_ragdoll(impulso)
				_actualizar_estado("Ragdoll ACTIVADO con impulso " + str(impulso.snapped(Vector3(0.1, 0.1, 0.1))))
		)

	if btn_reiniciar:
		btn_reiniciar.pressed.connect(func():
			if imp_ragdoll:
				imp_ragdoll.reiniciar()
				_actualizar_estado("Posición y huesos REINICIADOS")
		)


func _actualizar_estado(mensaje: String) -> void:
	if lbl_estado:
		lbl_estado.text = "Estado: " + mensaje
