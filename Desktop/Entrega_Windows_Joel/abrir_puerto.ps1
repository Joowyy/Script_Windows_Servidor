# Habilita el uso de interfaces gráficas
Add-Type -AssemblyName System.Windows.Forms

# Configura el puerto de escucha y la ruta de 'logs'
$puerto = 7900
$nombreRegla = "Abrir puerto $puerto"
$logFile = "C:\Logs\server_log_8080.txt"
$timeout = 300
$ramThreshold = 25
$alertaMostrada = $false  # Corregido el nombre de la variable

New-NetFirewallRule -DisplayName $nombreRegla -Direction Inbound -LocalPort $puerto -Protocol TCP -Action Allow

Write-Host "Se ha abierto el puerto $puerto"

# Crear directorio si no existe
if (!(Test-Path "C:\Logs")) {
    New-Item -ItemType Directory -Path "C:\Logs" | Out-Null
}

# Iniciar el servidor de escucha
$listener = [System.Net.Sockets.TcpListener]::new($puerto)
$listener.Start()
Write-Host "Servidor escuchando en el puerto $puerto..."

$ultimaConexion = Get-Date

while ($true) {
    if ($listener.Pending()) {
        $cliente = $listener.AcceptTcpClient()
        $ipCliente = $cliente.Client.RemoteEndPoint.Address.IPAddressToString
        $ultimaConexion = Get-Date  # Actualizar el tiempo de la última conexión

        # Guardar en log
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "$timestamp - Conexión desde: $ipCliente" | Out-File -Append -FilePath $logFile

        # Mostrar alerta en pantalla
        [System.Windows.Forms.MessageBox]::Show("Conexión detectada desde: $ipCliente", "Alerta de Conexión", "OK", "Warning")

        # Responder al cliente
        $stream = $cliente.GetStream()
        $writer = New-Object System.IO.StreamWriter($stream)
        $writer.WriteLine("Mensaje recibido en el servidor")
        $writer.Flush()

        # Cerrar la conexión
        $cliente.Close()
    }
    
    # Verificar si ha pasado el tiempo de inactividad
    if ((Get-Date) - $ultimaConexion -gt (New-TimeSpan -Seconds $timeout)) {
        Write-Host "No se detectó actividad en los últimos $timeout segundos. Cerrando el servidor."
        break
    }

    # Verificar el uso de RAM
    $memoriaLibre = (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1MB
    $memoriaTotal = (Get-CimInstance Win32_OperatingSystem).TotalVisibleMemorySize / 1MB
    $ramDisponible = ($memoriaLibre / $memoriaTotal) * 100

    if ($ramDisponible -lt $ramThreshold -and -not $alertaMostrada) {
        [System.Windows.Forms.MessageBox]::Show("Advertencia: RAM por debajo del $ramThreshold%", "Alerta de RAM", "OK", "Warning")
        $alertaMostrada = $true  # Evita que la alerta se repita constantemente
    }
    elseif ($ramDisponible -ge $ramThreshold) {
        $alertaMostrada = $false  # Resetea la alerta cuando la RAM vuelve a un nivel seguro
    }

    Start-Sleep -Seconds 5  # Pequeña espera para reducir uso de CPU
}

# Detener el servidor
$listener.Stop()
Write-Host "Servidor detenido."