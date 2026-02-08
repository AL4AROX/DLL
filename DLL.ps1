# =======================
# Funciones auxiliares
# =======================

function Write-Color {
    param(
        [string]$Text,
        [string]$Color = "White",
        [switch]$NoNewline
    )

    if ($NoNewline) {
        Write-Host $Text -ForegroundColor $Color -NoNewline
    } else {
        Write-Host $Text -ForegroundColor $Color
    }
}

function Write-Menu {
    param(
        [string]$Text,
        [switch]$IsTitle
    )

    if ($IsTitle) {
        Write-Host $Text -ForegroundColor Cyan
    } else {
        Write-Host $Text
    }
}

# =======================
# DLL Parser
# =======================

function Invoke-DllParser {
    Clear-Host
    
    $SS = @"
      _/_/    _/  _/  _/                                         
   _/    _/  _/  _/        _/_/_/  _/_/_/      _/_/_/    _/_/    
  _/_/_/_/  _/  _/  _/  _/    _/  _/    _/  _/        _/_/_/_/   
 _/    _/  _/  _/  _/  _/    _/  _/    _/  _/        _/          
_/    _/  _/  _/  _/    _/_/_/  _/    _/    _/_/_/    _/_/_/     
"@
    Write-Host $SS -ForegroundColor Magenta
    Write-Host ""

    Write-Menu "========================================================" -IsTitle
    Write-Menu "                  DLL PARSER " -IsTitle
    Write-Menu "========================================================" -IsTitle
    Write-Host ""

    Write-Color "[*] Iniciando DLL Parser..." "Yellow"

    $ProgressPreference = 'SilentlyContinue'

    $pecmdUrl  = "https://github.com/Orbdiff/JARParser/releases/download/Jar/PECmd.exe"
    $pecmdPath = "$env:TEMP\PECmd.exe"

    Write-Color "  Descargando PECmd.exe..." "White" -NoNewline
    try {
        Invoke-WebRequest -Uri $pecmdUrl -OutFile $pecmdPath
        Write-Color " OK" "Green"
    } catch {
        Write-Color " ERROR" "Red"
        Write-Color "[!] No se pudo descargar PECmd.exe" "Red"
        Read-Host "Presiona Enter para continuar"
        return
    }

    Write-Color "  Obteniendo tiempo de inicio del sistema..." "White" -NoNewline
    try {
        $logonTime = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
        Write-Color " OK" "Green"
        Write-Color "  Último inicio: $($logonTime.ToString('yyyy-MM-dd HH:mm:ss'))" "White"
    } catch {
        Write-Color " ERROR" "Red"
        $logonTime = (Get-Date).AddDays(-1)
    }

    $prefetchFolder = "C:\Windows\Prefetch"

    Write-Color "  Buscando archivos PF de rundll32/regsvr32..." "White" -NoNewline
    $files = Get-ChildItem $prefetchFolder -Filter *.pf | Where-Object {
        ($_.Name -match "rundll32|regsvr32") -and ($_.LastWriteTime -gt $logonTime)
    } | Sort-Object LastWriteTime -Descending

    if ($files.Count -gt 0) {
        Write-Color " OK ($($files.Count) encontrados)" "Green"
        Write-Host ""

        $fileCount = 0
        foreach ($file in $files) {
            $fileCount++
            Write-Color "Archivo #$fileCount" "Cyan"
            Write-Color "  Nombre: $($file.Name)" "White"

            Write-Color "  Ejecutando PECmd.exe..." "White" -NoNewline
            try {
                $pecmdOutput = & $pecmdPath -f $file.FullName
                Write-Color " OK" "Green"
            } catch {
                Write-Color " ERROR" "Red"
                continue
            }

            $imports = $pecmdOutput | Where-Object { $_ -match '\\VOLUME|:\\' }

            foreach ($line in $imports) {
                $clean = $line -replace '\\VOLUME{.*?}', 'C:' -replace '^\d+:\s*', ''
                if ($clean -match '\\[^\\]+\.(dll|exe)$') {
                    if (Test-Path $clean) {
                        $sig = Get-AuthenticodeSignature $clean
                        if ($sig.Status -eq 'Valid') {
                            Write-Host "    [FIRMADO] $clean" -ForegroundColor Green
                        } else {
                            Write-Host "    [SIN FIRMA] $clean" -ForegroundColor Red
                        }
                    } else {
                        Write-Host "    [NO EXISTE] $clean" -ForegroundColor DarkGray
                    }
                }
            }
            Write-Host ""
        }
        Write-Color "[+] Análisis completado." "Green"
    } else {
        Write-Color " OK (0 encontrados)" "Green"
    }

    Write-Host ""
    Write-Color "[*] PECmd.exe en: $pecmdPath" "White"
    Read-Host "[*] Presiona Enter para salir"
}

# =======================
# EJECUCIÓN AUTOMÁTICA
# =======================

Invoke-DllParser
