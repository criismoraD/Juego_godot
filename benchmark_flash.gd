extends SceneTree

func _init():
    var script = load("res://Scripts/Characters/ImpShieldGirl.gd")
    var imp = script.new()

    # Create mock tree
    var root = Node3D.new()
    var escudo = Node3D.new()
    escudo.name = "ESCUDO_IMP"
    for i in range(5):
        var mesh = MeshInstance3D.new()
        escudo.add_child(mesh)
    imp.add_child(escudo)
    root.add_child(imp)

    # Ready
    imp._buscar_escudo()

    # Measure baseline
    var start_time = Time.get_ticks_usec()
    for i in range(1000):
        imp._flash_escudo()
    var end_time = Time.get_ticks_usec()

    print("Baseline _flash_escudo() x1000: ", end_time - start_time, " us")
    quit()
