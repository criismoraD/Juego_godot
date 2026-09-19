$text = [System.IO.File]::ReadAllLines("e:\Proyecto Juego Arrathema\Juego_godot\Levels\Rio en canoa con paralax.tscn")
$currentNode = ""
$nodes = @()

for ($i = 0; $i -lt $text.Length; $i++) {
    $line = $text[$i]
    if ($line.StartsWith("[node name=`"")) {
        $parts = $line.Split('"')
        $currentNode = $parts[1]
    }
    elseif ($line.Trim().StartsWith("transform = Transform3D(")) {
        $idx = $line.IndexOf("Transform3D(") + 12
        $endIdx = $line.IndexOf(")", $idx)
        $sub = $line.Substring($idx, $endIdx - $idx)
        $coords = $sub.Split(",")
        if ($coords.Length -ge 12) {
            $x = [float]$coords[9].Trim()
            $y = [float]$coords[10].Trim()
            $z = [float]$coords[11].Trim()
            $nodes += [PSCustomObject]@{ Name = $currentNode; X = $x; Y = $y; Z = $z }
        }
    }
}

Write-Output "Total nodos con transform: $($nodes.Count)"

$pinos = $nodes | Where-Object { $_.Name -like "Pino*" }
$pisos = $nodes | Where-Object { $_.Name -like "Piso nueva*" }
$cord = $nodes | Where-Object { $_.Name -like "PiedraCordillera*" }
$bosq = $nodes | Where-Object { $_.Name -like "BosqueRojo*" }
$arb = $nodes | Where-Object { $_.Name -like "Arboles_*" }

Write-Output "Pinos: $($pinos.Count) | Pisos: $($pisos.Count) | Cordillera: $($cord.Count) | BosqueRojo: $($bosq.Count) | ArbolesPrueba: $($arb.Count)"

for ($x = -40; $x -le 100; $x += 10) {
    $x2 = $x + 10
    $np = ($pinos | Where-Object { $_.X -ge $x -and $_.X -lt $x2 }).Count
    $npi = ($pisos | Where-Object { $_.X -ge $x -and $_.X -lt $x2 }).Count
    $nc = ($cord | Where-Object { $_.X -ge $x -and $_.X -lt $x2 }).Count
    $nb = ($bosq | Where-Object { $_.X -ge $x -and $_.X -lt $x2 }).Count
    $na = ($arb | Where-Object { $_.X -ge $x -and $_.X -lt $x2 }).Count
    Write-Output "Tramo [$($x.ToString('+00;-00'))..$(($x2).ToString('+00;-00'))]: Pinos=$($np.ToString('00')) | Pisos=$($npi.ToString('00')) | Cordillera=$($nc.ToString('00')) | Bosque=$($nb.ToString('00')) | ArbolesPrueba=$($na.ToString('00'))"
}
