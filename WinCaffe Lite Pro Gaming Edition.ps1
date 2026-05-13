
# ==============================================================
#  WinCaffe Lite Pro Gaming Edition
#  Versione: 1.0a
#  Autore: DarkPlayer84Tv Productions (Luigi Sestili Spurio)
#
#  Release 1.0a:
#  - [BRANDING] Rebranding completo a WinCaffe Lite Pro Gaming Edition.
#  - [UX] Intro retro animata stile old DOS game con supporto theme.mp3 / WinCaffe_Intro.wav.
#  - [UI] Grafica rinnovata in stile pannello tecnico blu/bianco, più moderna e più leggibile.
#  - [MODULAR] Profilo diviso in moduli separati: Base, BO7, Debloat e File I/O.
#  - [REVIEW] Preset ripulito seguendo un controllo online completo su fonti Microsoft/DirectX.
#  - [FIX] HAGS resta scelta esplicita dell'utente; rimossi tweak TDR da sviluppo driver.
#  - [FIX] Menu e uscita rivisti: nessuna riapplicazione involontaria, ritorno corretto al menu principale.
#
#  Changelog v4.1.1 (precedente):
#  - [FIX] Get-NpuReport: rimossa doppia query, filtro null robusto,
#          ErrorAction SilentlyContinue su Win32_PnPEntity.
#  - [FIX] Get-FriendlyGpuReport: avviso esplicito limite CIM DWORD 32-bit (~4GB).
#  - [FIX] WSearch: avviato dopo Set-ServiceStartupIfDifferent se Stopped.
#
#  Changelog v4.1 (precedente):
#  - [FIX] Aggiunta Set-StringValueIfDifferent (idempotente per stringhe)
#  - [FIX] Apply-HyperGamingBase: Tasks\Games ora usa funzioni idempotenti
#  - [FIX] Apply-HyperGamingBase: servizi ora usano Set-ServiceStartupIfDifferent
#  - [FIX] Set-HAGS: usa Set-DwordValueIfDifferent invece di Set-DwordValue
#  - [FIX] Restore-Backups: usa Set-ServiceStartupIfDifferent
#  - [NEW] Get-NpuReport: rileva NPU (Neural Processing Unit) via CIM/PnP
#  - [NEW] New-QuickReport: sezione NPU aggiunta al report hardware
# ==============================================================

#Requires -RunAsAdministrator
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptVersion  = '1.0a'
$ProjectName    = 'WinCaffe Lite Pro Gaming Edition'
$VendorName     = 'DarkPlayer84Tv Productions (Luigi Sestili Spurio) aka DarkPlayer84Tv'
$LegacyDocsRoot = Join-Path $env:ProgramData 'WinCaffe\AllGames_HyperGamingBase'
$DocsRoot       = Join-Path $env:ProgramData 'WinCaffe\LiteProGamingEdition'
$BackupRoot     = Join-Path $DocsRoot 'Backup'
$LogRoot        = Join-Path $DocsRoot 'Logs'
$StateFile          = Join-Path $BackupRoot 'state.json'
$RegistryBackupFile = Join-Path $BackupRoot 'registry-backup.json'
$ServiceBackupFile  = Join-Path $BackupRoot 'services-backup.json'
$PowerBackupFile    = Join-Path $BackupRoot 'power-backup.json'
$WatcherStateFile   = Join-Path $BackupRoot 'watcher-state.json'
$WatcherAgentPath   = Join-Path $DocsRoot 'WinCaffe_Lite_Pro_Gaming_Agent.ps1'
$WatcherTaskName    = 'WinCaffe Lite Pro Gaming Watcher'
$QuickReportFile    = Join-Path $LogRoot 'quick-report.txt'
$SummaryFile        = Join-Path $LogRoot 'summary.json'
$CurrentLog         = Join-Path $LogRoot ("session_{0}.log" -f (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'))
$script:WinCaffeIntroPlayed = $false
$script:WinCaffeIntroWavePath = Join-Path $env:USERPROFILE 'Desktop\WinCaffe_Intro.wav'
$script:WinCaffeIntroMp3Path  = Join-Path $env:USERPROFILE 'Desktop\theme.mp3'
$script:WinCaffeIntroTune = @(
    @(523,90), @(659,90), @(784,120), @(659,90),
    @(523,90), @(659,90), @(880,160), @(784,140),
    @(659,100), @(523,180)
)

try {
    if ((Test-Path $LegacyDocsRoot) -and -not (Test-Path $DocsRoot)) {
        New-Item -ItemType Directory -Force -Path (Split-Path $DocsRoot -Parent) | Out-Null
        Move-Item -LiteralPath $LegacyDocsRoot -Destination $DocsRoot -Force
    }
} catch {}

New-Item -ItemType Directory -Force -Path $DocsRoot, $BackupRoot, $LogRoot | Out-Null

# ---------------------------------------------------------------
# FUNZIONI BASE
# ---------------------------------------------------------------

function Write-Log {
    param(
        [Parameter(Mandatory)] [string]$Message,
        [ValidateSet('INFO','OK','WARN','ERR')] [string]$Level = 'INFO'
    )
    $stamp = Get-Date -Format 'HH:mm:ss'
    $line  = "[$stamp] [$Level] $Message"
    Add-Content -Path $CurrentLog -Value $line -Encoding UTF8
    switch ($Level) {
        'OK'    { Write-Host $line -ForegroundColor Green }
        'WARN'  { Write-Host $line -ForegroundColor Yellow }
        'ERR'   { Write-Host $line -ForegroundColor Red }
        default { Write-Host $line -ForegroundColor Cyan }
    }
}

function Write-UiRule {
    param(
        [string]$Color = 'DarkBlue'
    )
    Write-Host '  ────────────────────────────────────────────────────────────' -ForegroundColor $Color
}

function Write-UiPanel {
    param(
        [Parameter(Mandatory)] [string]$Title,
        [string]$Subtitle = ''
    )

    Write-Host ''
    Write-Host '  ┌──────────────────────────────────────────────────────────┐' -ForegroundColor Blue
    Write-Host ("  │ {0,-56} │" -f $Title) -ForegroundColor White
    if (-not [string]::IsNullOrWhiteSpace($Subtitle)) {
        Write-Host ("  │ {0,-56} │" -f $Subtitle) -ForegroundColor Gray
    }
    Write-Host '  └──────────────────────────────────────────────────────────┘' -ForegroundColor Blue
    Write-Host ''
}

function Write-UiMenuItem {
    param(
        [Parameter(Mandatory)] [string]$Key,
        [Parameter(Mandatory)] [string]$Title,
        [string]$Description = '',
        [string]$Color = 'White'
    )

    Write-Host ("  [{0}] {1}" -f $Key, $Title) -ForegroundColor $Color
    if (-not [string]::IsNullOrWhiteSpace($Description)) {
        Write-Host ("      {0}" -f $Description) -ForegroundColor Gray
    }
}

function Get-WinCaffeLogoLines {
    return @(
        ' __      ___ _   _  ____    _    _____ _____ _____ ',
        ' \ \    / / | \ | |/ ___|  / \  |  ___|  ___| ____|',
        '  \ \/\/ /| |  \| | |     / _ \ | |_  | |_  |  _|  ',
        '   \_/\_/ | | |\  | |___ / ___ \|  _| |  _| | |___ ',
        '          |_|_| \_|\____/_/   \_\_|   |_|   |_____|'
    )
}

function Start-WinCaffeIntroAudio {
    if (Test-Path $script:WinCaffeIntroMp3Path) {
        try {
            Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class WinCaffeMci {
    [DllImport("winmm.dll", CharSet = CharSet.Auto)]
    public static extern int mciSendString(string command, System.Text.StringBuilder buffer, int bufferSize, IntPtr hwndCallback);
}
"@ -ErrorAction SilentlyContinue | Out-Null

            [void][WinCaffeMci]::mciSendString('close wincaffe_intro', $null, 0, [IntPtr]::Zero)
            $openCmd = ('open "{0}" type mpegvideo alias wincaffe_intro' -f $script:WinCaffeIntroMp3Path)
            $playCmd = 'play wincaffe_intro from 0'
            [void][WinCaffeMci]::mciSendString($openCmd, $null, 0, [IntPtr]::Zero)
            [void][WinCaffeMci]::mciSendString($playCmd, $null, 0, [IntPtr]::Zero)
            Write-Log ("Intro audio MP3 rilevato: {0}" -f $script:WinCaffeIntroMp3Path) 'INFO'
            return
        } catch {
            Write-Log ("Intro audio MP3 non riprodotto: {0}" -f $_.Exception.Message) 'WARN'
        }
    }

    if (Test-Path $script:WinCaffeIntroWavePath) {
        try {
            $player = New-Object System.Media.SoundPlayer $script:WinCaffeIntroWavePath
            $player.Play()
            Write-Log ("Intro audio personalizzato rilevato: {0}" -f $script:WinCaffeIntroWavePath) 'INFO'
            return
        } catch {
            Write-Log ("Intro audio personalizzato non riprodotto: {0}" -f $_.Exception.Message) 'WARN'
        }
    }

    foreach ($note in $script:WinCaffeIntroTune) {
        try {
            [console]::Beep([int]$note[0], [int]$note[1])
        } catch {
            Start-Sleep -Milliseconds ([int]$note[1])
        }
    }
}

function Show-WinCaffeStartupIntro {
    if ($script:WinCaffeIntroPlayed) { return }
    $script:WinCaffeIntroPlayed = $true

    $logoLines = Get-WinCaffeLogoLines
    $frameColors = @('DarkBlue','Blue','Cyan','White')
    $maxIndent = 16
    $bootLines = @(
        'WINCAFFE DOS-STYLE BOOTSTRAP',
        'Loading retro control deck modules',
        'Checking gaming profile assets',
        'Preparing performance console'
    )

    try {
        Start-WinCaffeIntroAudio
    } catch {}

    for ($indent = $maxIndent; $indent -ge 2; $indent -= 2) {
        Clear-Host
        Write-Host ''
        foreach ($line in $logoLines) {
            $pad = (' ' * $indent)
            $color = $frameColors[([math]::Abs($indent / 2)) % $frameColors.Count]
            Write-Host ($pad + $line) -ForegroundColor $color
        }
        Write-Host ''
        Write-Host (' ' * ($indent + 2) + 'Lite Pro Gaming Edition') -ForegroundColor Gray
        Start-Sleep -Milliseconds 80
    }

    foreach ($bootLine in $bootLines) {
        Clear-Host
        Write-Host ''
        foreach ($line in $logoLines) {
            Write-Host ('  ' + $line) -ForegroundColor Cyan
        }
        Write-Host ''
        Write-Host '    Lite Pro Gaming Edition' -ForegroundColor Gray
        Write-Host ''
        foreach ($printedLine in $bootLines[0..([array]::IndexOf($bootLines, $bootLine))]) {
            Write-Host ('    ' + $printedLine) -ForegroundColor White
        }
        Start-Sleep -Milliseconds 120
    }

    for ($step = 0; $step -le 24; $step++) {
        Clear-Host
        Write-Host ''
        foreach ($line in $logoLines) {
            Write-Host ('  ' + $line) -ForegroundColor White
        }
        Write-Host ''
        Write-Host '    Lite Pro Gaming Edition' -ForegroundColor Gray
        Write-Host ''
        foreach ($bootLine in $bootLines) {
            Write-Host ('    ' + $bootLine) -ForegroundColor DarkGray
        }

        $filled = '=' * $step
        $empty = '.' * (24 - $step)
        Write-Host ''
        Write-Host ("    [{0}{1}]" -f $filled, $empty) -ForegroundColor Blue
        Write-Host ("    Loading assets {0}%" -f [math]::Round(($step / 24) * 100, 0)) -ForegroundColor White
        Start-Sleep -Milliseconds 45
    }

    foreach ($flashColor in @('White','Cyan','Blue','White')) {
        Clear-Host
        Write-Host ''
        foreach ($line in $logoLines) {
            Write-Host ('  ' + $line) -ForegroundColor $flashColor
        }
        Write-Host ''
        Write-Host '    Lite Pro Gaming Edition' -ForegroundColor Gray
        Write-Host '    Initializing control deck...' -ForegroundColor DarkGray
        Start-Sleep -Milliseconds 90
    }

    Start-Sleep -Milliseconds 260
}

function Write-Banner {
    Clear-Host
    Write-Host ''
    foreach ($line in (Get-WinCaffeLogoLines)) {
        $color = if ($line -like '*_____*') { 'White' } elseif ($line -like '*\_/\_*') { 'Cyan' } else { 'Blue' }
        Write-Host ('  ' + $line) -ForegroundColor $color
    }
    Write-Host ''
    Write-UiPanel -Title 'Lite Pro Gaming Edition' -Subtitle ("Versione {0}   |   Layout modulare Base / BO7 / Debloat / File I/O" -f $ScriptVersion)
}

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Esegui questo script come Amministratore.'
    }
}

function Show-WinCaffeDisclaimer {
    while ($true) {
        Clear-Host
        Write-UiPanel -Title 'Termini d uso / Ringraziamenti' -Subtitle 'Accettazione iniziale richiesta prima del menu'
        Write-Host '  Ringraziamenti' -ForegroundColor Cyan
        Write-Host 'Questo progetto utilizza anche idee, impostazioni e riferimenti derivati' -ForegroundColor White
        Write-Host 'da settaggi e profili condivisi nel tempo dalla scena OGD / WinCaffe.' -ForegroundColor White
        Write-Host 'Un ringraziamento va a chi ha contribuito a costruire, testare e diffondere' -ForegroundColor White
        Write-Host 'queste basi di tuning e ottimizzazione.' -ForegroundColor White
        Write-Host ''
        Write-Host '  Condizioni d uso' -ForegroundColor Cyan
        Write-Host 'Usando questo script confermi di farlo per tua libera scelta e sotto la tua' -ForegroundColor White
        Write-Host 'esclusiva responsabilita.' -ForegroundColor White
        Write-Host 'Ogni sistema Windows, gioco, driver, BIOS e combinazione hardware puo reagire' -ForegroundColor White
        Write-Host 'in modo diverso alle ottimizzazioni applicate.' -ForegroundColor White
        Write-Host ''
        Write-Host '  Esclusione di responsabilita' -ForegroundColor Cyan
        Write-Host 'L autore, chi distribuisce lo script e chi ha contribuito ai settaggi usati' -ForegroundColor White
        Write-Host 'come riferimento non si assumono responsabilita per cali di prestazioni,' -ForegroundColor White
        Write-Host 'instabilita, incompatibilita, perdita di configurazioni o altri effetti' -ForegroundColor White
        Write-Host 'derivanti dall uso dello script.' -ForegroundColor White
        Write-Host 'Se scegli di proseguire, accetti che ogni modifica venga eseguita su tua' -ForegroundColor White
        Write-Host 'richiesta e per tua iniziativa.' -ForegroundColor White
        Write-Host ''
        Write-Host '  Licenza' -ForegroundColor Cyan
        Write-Host 'Questo progetto e distribuito sotto GNU General Public License v3.0' -ForegroundColor White
        Write-Host '(GPL-3.0).' -ForegroundColor White
        Write-Host 'Testo licenza: https://www.gnu.org/licenses/gpl-3.0.html' -ForegroundColor White
        Write-Host ''
        Write-Host '  Conferma' -ForegroundColor Cyan
        Write-Host 'Per continuare digita ACCETTO. Per uscire usa 0.' -ForegroundColor White
        Write-Host ''
        $accept = Read-Host "Scelta (ACCETTO/0)"
        if ($accept.Trim().ToUpperInvariant() -eq 'ACCETTO') {
            return $true
        }
        if ($accept.Trim() -eq '0') {
            return $false
        }
        Write-Host ''
        Write-Host '  Scelta non valida. Usa ACCETTO per entrare o 0 per uscire.' -ForegroundColor Yellow
        Start-Sleep -Seconds 1
    }
}

function Invoke-WinCaffePostAction {
    [CmdletBinding()]
    param()

    while ($true) {
        Write-Host ''
        Write-Host '  [R] Riavvia ora' -ForegroundColor Yellow
        Write-Host '  [0] Torna al menu principale' -ForegroundColor White
        Write-Host ''
        $next = Read-Host 'Scelta (R/0)'
        switch ($next) {
            'R' { Restart-Computer -Force; return 'REBOOT' }
            'r' { Restart-Computer -Force; return 'REBOOT' }
            '0' { return 'MENU' }
            default {
                Write-Host '  Scelta non valida.' -ForegroundColor Yellow
            }
        }
    }
}

function New-WinCaffeRestorePoint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Description
    )

    $srKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore'

    try {
        Enable-ComputerRestore -Drive 'C:\' -ErrorAction SilentlyContinue
    } catch {}

    try {
        if (-not (Test-Path $srKey)) {
            New-Item -Path $srKey -Force | Out-Null
        }
        $freqCurrent = Get-ItemProperty -Path $srKey -Name 'SystemRestorePointCreationFrequency' -ErrorAction SilentlyContinue
        if ($null -eq $freqCurrent) {
            New-ItemProperty -Path $srKey -Name 'SystemRestorePointCreationFrequency' -Value 0 -PropertyType DWord -Force | Out-Null
        } else {
            Set-ItemProperty -Path $srKey -Name 'SystemRestorePointCreationFrequency' -Value 0 -Type DWord -Force
        }
        Write-Log 'Limite frequenza restore point impostato a 0: creazione illimitata abilitata.' 'OK'
    } catch {
        Write-Log ("Impossibile preparare l'override della frequenza restore point: {0}" -f $_.Exception.Message) 'WARN'
    }

    try {
        Write-Log ("Creazione punto di ripristino: {0}" -f $Description) 'INFO'
        $rpJob = Start-Job -ScriptBlock {
            param($d)
            try {
                Checkpoint-Computer -Description $d -RestorePointType MODIFY_SETTINGS -ErrorAction Stop | Out-Null
                [pscustomobject]@{ Success = $true; Message = 'Checkpoint creato' }
            } catch {
                [pscustomobject]@{ Success = $false; Message = $_.Exception.Message }
            }
        } -ArgumentList $Description

        $rpDone = Wait-Job $rpJob -Timeout 45
        if ($rpDone) {
            $rpRes = Receive-Job $rpJob -ErrorAction SilentlyContinue
            if ($rpRes -and $rpRes.Success) {
                Write-Log ("Punto di ripristino creato: {0}" -f $Description) 'OK'
            } else {
                $msg = if ($rpRes -and $rpRes.Message) { $rpRes.Message } else { 'operazione non confermata da Windows' }
                Write-Log ("Punto di ripristino non creato: {0}" -f $msg) 'WARN'
            }
        } else {
            Stop-Job $rpJob -ErrorAction SilentlyContinue | Out-Null
            Write-Log 'Punto di ripristino non completato entro il timeout: continuo comunque.' 'WARN'
        }
        Remove-Job $rpJob -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Log ("Punto di ripristino non creato: {0}" -f $_.Exception.Message) 'WARN'
    }
}

function Invoke-WinCaffeMenuAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$ActionLabel,
        [Parameter(Mandatory)] [scriptblock]$Action
    )

    $desc = "WinCaffe {0} - {1}" -f $ScriptVersion, $ActionLabel
    if ($desc.Length -gt 255) {
        $desc = $desc.Substring(0,255)
    }

    New-WinCaffeRestorePoint -Description $desc
    & $Action
    return (Invoke-WinCaffePostAction)
}

# ---------------------------------------------------------------
# FUNZIONI REGISTRO - LETTURA SICURA
# ---------------------------------------------------------------

function Get-RegistryValueSafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Name
    )
    try {
        $item = Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop
        return $item.$Name
    } catch {
        return $null
    }
}

# ---------------------------------------------------------------
# FUNZIONI REGISTRO - SCRITTURA IDEMPOTENTE
# ---------------------------------------------------------------

function Set-DwordValueIfDifferent {
    # [v4.0] Controlla il valore attuale prima di scrivere.
    # Scrive solo se mancante o diverso → log chiaro "già corretto" vs "modificato".
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][UInt32]$Value,
        [string]$Label
    )
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
    $current = Get-RegistryValueSafe -Path $Path -Name $Name
    $shown   = if ($Label) { $Label } else { "$Path -> $Name" }
    if ($null -ne $current) {
        try {
            if ([UInt64]$current -eq [UInt64]$Value) {
                Write-Log "Già impostato correttamente, salto: $shown=$current" 'INFO'
                return
            }
        } catch {
            if ([string]$current -eq [string]$Value) {
                Write-Log "Già impostato correttamente, salto: $shown=$current" 'INFO'
                return
            }
        }
    }
    New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType DWord -Force | Out-Null
    Write-Log "Registry impostato: $shown=$Value" 'OK'
}

function Set-StringValueIfDifferent {
    # [v4.1 NEW] Versione idempotente per valori di tipo String.
    # Stessa logica di Set-DwordValueIfDifferent: salta se già corretto.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][string]$Value,
        [string]$Label
    )
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
    $current = Get-RegistryValueSafe -Path $Path -Name $Name
    $shown   = if ($Label) { $Label } else { "$Path -> $Name" }
    if ($null -ne $current -and [string]$current -eq [string]$Value) {
        Write-Log "Già impostato correttamente, salto: $shown=$current" 'INFO'
        return
    }
    New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType String -Force | Out-Null
    Write-Log "Registry impostato: $shown=$Value" 'OK'
}

# ---------------------------------------------------------------
# FUNZIONI REGISTRO - SCRITTURA DIRETTA (usate solo da Rollback)
# ---------------------------------------------------------------

function Set-DwordValue {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] [UInt32]$Value
    )
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
    New-ItemProperty -Path $Path -Name $Name -PropertyType DWord -Value $Value -Force | Out-Null
    Write-Log ("Registry impostato: {0} -> {1}={2}" -f $Path, $Name, $Value) 'OK'
}

function Set-StringValue {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] [string]$Value
    )
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
    New-ItemProperty -Path $Path -Name $Name -PropertyType String -Value $Value -Force | Out-Null
    Write-Log ("Registry impostato: {0} -> {1}={2}" -f $Path, $Name, $Value) 'OK'
}

# ---------------------------------------------------------------
# FUNZIONI SERVIZI - IDEMPOTENTE
# ---------------------------------------------------------------

function Set-ServiceStartupIfDifferent {
    # [v4.0] Controlla lo StartMode attuale prima di modificare.
    # Salta se già nella configurazione desiderata.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][ValidateSet('Automatic','Manual','Disabled')][string]$StartupType,
        [switch]$TryStop
    )
    try {
        $svc     = Get-CimInstance Win32_Service -Filter ("Name='{0}'" -f $Name) -ErrorAction Stop
        $current = [string]$svc.StartMode
        $target  = switch ($StartupType) {
            'Automatic' { 'Auto' }
            'Manual'    { 'Manual' }
            'Disabled'  { 'Disabled' }
        }
        if ($current -eq $target) {
            Write-Log "Servizio già configurato, salto: $Name StartMode=$current" 'INFO'
        } else {
            Set-Service -Name $Name -StartupType $StartupType -ErrorAction Stop
            Write-Log "Servizio aggiornato: $Name StartMode=$StartupType" 'OK'
        }
        if ($TryStop) {
            Stop-ServiceIfRunningSafe -Name $Name
        }
        return $true
    } catch {
        Write-Log ("Impossibile impostare il servizio {0}: {1}" -f $Name, $_.Exception.Message) 'WARN'
        return $false
    }
}

function Stop-ServiceIfRunningSafe {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Name)
    try {
        $svc = Get-Service -Name $Name -ErrorAction Stop
        if ($svc.Status -eq 'Running') {
            Stop-Service -Name $Name -Force -ErrorAction Stop
            Write-Log "Servizio fermato: $Name" 'OK'
        } else {
            Write-Log "Servizio già fermo, salto: $Name" 'INFO'
        }
    } catch {
        Write-Log ("Impossibile fermare il servizio {0}: {1}" -f $Name, $_.Exception.Message) 'WARN'
    }
}

function Set-ServiceStartup {
    # Versione NON idempotente — usata solo internamente da Restore-Backups
    # quando si vuole forzare il ripristino del valore originale senza controlli.
    param(
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] [ValidateSet('Automatic','Manual','Disabled')] [string]$StartupType,
        [switch]$TryStop
    )
    try {
        Set-Service -Name $Name -StartupType $StartupType -ErrorAction Stop
        Write-Log ("Servizio {0}: StartupType={1}" -f $Name, $StartupType) 'OK'
        if ($TryStop) {
            try {
                Stop-Service -Name $Name -Force -ErrorAction Stop
                Write-Log ("Servizio {0} arrestato." -f $Name) 'OK'
            } catch {
                Write-Log ("Servizio {0} non arrestato: {1}" -f $Name, $_.Exception.Message) 'WARN'
            }
        }
    } catch {
        Write-Log ("Impossibile modificare il servizio {0}: {1}" -f $Name, $_.Exception.Message) 'WARN'
    }
}

# ---------------------------------------------------------------
# FUNZIONE HARDWARE - GPU
# ---------------------------------------------------------------

function Get-FriendlyGpuReport {
    [CmdletBinding()]
    param()
    # Nota tecnica: Win32_VideoController.AdapterRAM e' un campo DWORD a 32-bit.
    # Il valore massimo rappresentabile e' 2^32 - 1 byte (~4GB).
    # Schede con VRAM > 4GB (es. RTX 5080 16GB, RTX 4090 24GB)
    # vengono segnalate da Windows/CIM come ~4GB: viene mostrato un avviso esplicito.
    $CIM_DWORD_MAX_BYTES = [UInt64]4294967295   # 0xFFFFFFFF
    $items = @()
    try {
        $videoControllers = Get-CimInstance Win32_VideoController -ErrorAction Stop
        foreach ($gpu in $videoControllers) {
            $name            = [string]$gpu.Name
            $adapterRamBytes = [UInt64]0
            try { $adapterRamBytes = [UInt64]$gpu.AdapterRAM } catch { $adapterRamBytes = 0 }
            $approxGB = 0
            if ($adapterRamBytes -gt 0) { $approxGB = [Math]::Round($adapterRamBytes / 1GB) }

            $note = if ($adapterRamBytes -ge $CIM_DWORD_MAX_BYTES -or $approxGB -ge 4) {
                'ATTENZIONE: CIM/WMI riporta max ~4GB (limite DWORD 32-bit). VRAM reale probabilmente superiore. Usa GPU-Z per il valore esatto.'
            } else {
                'VRAM reported by Windows/CIM (approximated)'
            }

            $items += [PSCustomObject]@{
                Name     = $name
                ApproxGB = $approxGB
                Note     = $note
            }
        }
    } catch {
        $items += [PSCustomObject]@{
            Name     = 'Unknown GPU'
            ApproxGB = 0
            Note     = 'GPU query failed'
        }
    }
    return $items
}

# ---------------------------------------------------------------
# [v4.1 NEW] FUNZIONE HARDWARE - NPU
# ---------------------------------------------------------------

function Get-NpuReport {
    # [v4.1.1 FIX] Riscritto da zero rispetto alla v4.1.
    #
    # Problema v4.1: la funzione eseguiva due query separate, la prima con
    # codice sintatticamente scorretto (Where-Object annidato con $_ ambiguo),
    # e usava -ErrorAction Stop sul Get-CimInstance principale, che in presenza
    # di dispositivi con nome $null causava eccezioni immediate.
    #
    # Soluzione v4.1.1:
    # - Una sola query con -ErrorAction SilentlyContinue (non blocca su errori parziali)
    # - Filtro esplicito su null/whitespace prima del match per keyword
    # - Keyword aggiornate per Intel Core Ultra (Arrow Lake): "AI Boost", "VPU"
    # - Intel Core Ultra 285K rilevato come "Intel(R) AI Boost" in Device Manager
    [CmdletBinding()]
    param()
    $npuKeywords = @('NPU','Neural','AI Boost','IPU','Hexagon','VPU','GNA','Myriad')
    $found = @()
    try {
        $found = Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue |
            Where-Object {
                # Scarta device senza nome (frequenti in Win32_PnPEntity)
                if ([string]::IsNullOrWhiteSpace($_.Name)) { return $false }
                $devName = [string]$_.Name
                foreach ($kw in $npuKeywords) {
                    if ($devName -match [regex]::Escape($kw)) { return $true }
                }
                return $false
            } | ForEach-Object {
                [PSCustomObject]@{
                    Name     = $_.Name
                    Status   = if ($_.Status) { $_.Status } else { 'Unknown' }
                    DeviceID = if ($_.DeviceID) { $_.DeviceID } else { '' }
                }
            }
    } catch {
        $found = @([PSCustomObject]@{
            Name     = ("Errore query NPU: {0}" -f $_.Exception.Message)
            Status   = 'Error'
            DeviceID = ''
        })
    }
    return $found
}

# ---------------------------------------------------------------
# BACKUP
# ---------------------------------------------------------------

function Save-RegistryValue {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$Name
    )
    $exists  = Test-Path $Path
    $item    = $null
    $present = $false
    if ($exists) {
        try {
            $item    = Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop
            $present = $true
        } catch {
            $present = $false
        }
    }
    [pscustomobject]@{
        Path         = $Path
        Name         = $Name
        PathExists   = $exists
        ValuePresent = $present
        Value        = if ($present) { $item.$Name } else { $null }
    }
}

function Ensure-Backup {
    if (Test-Path $StateFile) {
        Write-Log 'Backup già presente. Verrà riutilizzato per il rollback.' 'INFO'
        return
    }

    Write-Log 'Creo i backup iniziali prima di modificare il sistema...' 'INFO'

    $regTargets = @(
        @{ Path='HKCU:\Software\Microsoft\GameBar';                                                              Name='AllowAutoGameMode' },
        @{ Path='HKCU:\System\GameConfigStore';                                                                  Name='GameDVR_Enabled' },
        @{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects';                        Name='VisualFXSetting' },
        @{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize';                            Name='EnableTransparency' },
        @{ Path='HKLM:\SOFTWARE\Microsoft\PolicyManager\default\ApplicationManagement\AllowGameDVR';             Name='value' },
        @{ Path='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile';                   Name='NetworkThrottlingIndex' },
        @{ Path='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile';                   Name='SystemResponsiveness' },
        @{ Path='HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management';                      Name='LargeSystemCache' },
        @{ Path='HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters';                          Name='DisableBandwidthThrottling' },
        @{ Path='HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters';                          Name='DisableLargeMtu' },
        @{ Path='HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters';                          Name='FileInfoCacheLifetime' },
        @{ Path='HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers';                                        Name='HwSchMode' },
        @{ Path='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games';       Name='GPU Priority' },
        @{ Path='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games';       Name='Priority' },
        @{ Path='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games';       Name='Scheduling Category' },
        @{ Path='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games';       Name='SFIO Priority' }
    ) | ForEach-Object { Save-RegistryValue -Path $_.Path -Name $_.Name }

    $svcTargets = @('SysMain','DiagTrack','WSearch','MapsBroker','Fax','RemoteRegistry','RetailDemo','dmwappushservice') | ForEach-Object {
        try {
            $svc = Get-CimInstance Win32_Service -Filter ("Name='{0}'" -f $_)
            [pscustomobject]@{ Name=$svc.Name; StartMode=$svc.StartMode; State=$svc.State }
        } catch {
            [pscustomobject]@{ Name=$_; StartMode='Unknown'; State='Unknown' }
        }
    }

    $activeScheme = (& powercfg /getactivescheme) 2>&1 | Out-String
    $powerInfo    = [pscustomobject]@{ ActiveSchemeRaw = $activeScheme.Trim() }

    $watcherExists = $false
    try {
        $null          = Get-ScheduledTask -TaskName $WatcherTaskName -ErrorAction Stop
        $watcherExists = $true
    } catch {
        $watcherExists = $false
    }
    [pscustomobject]@{
        TaskExistsBefore = $watcherExists
        TaskName         = $WatcherTaskName
        AgentPath        = $WatcherAgentPath
    } | ConvertTo-Json -Depth 5 | Set-Content -Path $WatcherStateFile -Encoding UTF8

    $regTargets  | ConvertTo-Json -Depth 5 | Set-Content -Path $RegistryBackupFile -Encoding UTF8
    $svcTargets  | ConvertTo-Json -Depth 5 | Set-Content -Path $ServiceBackupFile  -Encoding UTF8
    $powerInfo   | ConvertTo-Json -Depth 5 | Set-Content -Path $PowerBackupFile    -Encoding UTF8

    [pscustomobject]@{
        Created = (Get-Date).ToString('s')
        Version = $ScriptVersion
        Project = $ProjectName
    } | ConvertTo-Json -Depth 5 | Set-Content -Path $StateFile -Encoding UTF8

    Write-Log 'Backup iniziale creato con successo.' 'OK'
}

# ---------------------------------------------------------------
# PIANO ENERGETICO
# ---------------------------------------------------------------

function Get-UltimatePerformanceGuid {
    $out = (& powercfg /list) 2>&1 | Out-String
    foreach ($line in ($out -split "`r?`n")) {
        if ($line -match '([A-Fa-f0-9\-]{36})' -and
            ($line -match 'Prestazioni eccellenti' -or $line -match 'Ultimate Performance')) {
            return $Matches[1]
        }
    }
    return $null
}

function Enable-UltimatePerformance {
    $guid = Get-UltimatePerformanceGuid
    if (-not $guid) {
        try {
            & powercfg /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 | Out-Null
            Start-Sleep -Milliseconds 400
            $guid = Get-UltimatePerformanceGuid
        } catch {
            Write-Log 'Impossibile duplicare il piano Prestazioni eccellenti.' 'WARN'
        }
    }
    if ($guid) {
        & powercfg /setactive $guid | Out-Null
        Write-Log ("Piano energetico attivo: Prestazioni eccellenti ({0})" -f $guid) 'OK'
    } else {
        Write-Log 'Non sono riuscito ad attivare Prestazioni eccellenti.' 'WARN'
    }
}

# ---------------------------------------------------------------
# AVVIO: SEGNALAZIONE VOCI SOSPETTE (NON RIMUOVE NULLA)
# ---------------------------------------------------------------

function Disable-ConsumerStartupNoise {
    $runKeys = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run'
    )
    foreach ($rk in $runKeys) {
        if (Test-Path $rk) {
            try {
                $item = Get-ItemProperty -Path $rk
                foreach ($prop in $item.PSObject.Properties) {
                    if ($prop.Name -in 'PSPath','PSParentPath','PSChildName','PSDrive','PSProvider') { continue }
                    if ($prop.Value -is [string] -and
                        $prop.Value -match 'OneDrive|Teams|Discord|EdgeUpdate|Adobe|SteamWebHelper|Xbox|Spotify') {
                        Write-Log ("Voce startup rilevata (non rimossa): {0} -> {1}" -f $prop.Name, $prop.Value) 'INFO'
                    }
                }
            } catch {
                Write-Log ("Impossibile leggere {0}: {1}" -f $rk, $_.Exception.Message) 'WARN'
            }
        }
    }
}

function Apply-WinCaffeSafeDebloat {
    [CmdletBinding()]
    param()

    Write-Log 'Avvio debloat gaming-safe: rimuovo solo app consumer e servizi secondari non essenziali.' 'INFO'
    Write-Log 'Conservati: Spotify, Xbox/Gaming, Microsoft login/Hello e servizi compatibili con launcher/anti-cheat.' 'INFO'

    $serviceTargets = @(
        @{ Name='MapsBroker';      Startup='Disabled'; TryStop=$true;  Label='Download mappe offline' },
        @{ Name='Fax';             Startup='Disabled'; TryStop=$true;  Label='Servizio Fax' },
        @{ Name='RemoteRegistry';  Startup='Disabled'; TryStop=$true;  Label='Registro remoto' },
        @{ Name='RetailDemo';      Startup='Disabled'; TryStop=$true;  Label='Modalità demo negozio' },
        @{ Name='dmwappushservice';Startup='Manual';   TryStop=$true;  Label='WAP Push' }
    )

    foreach ($svc in $serviceTargets) {
        try {
            $serviceApplied = Set-ServiceStartupIfDifferent -Name $svc.Name -StartupType $svc.Startup -TryStop:([bool]$svc.TryStop)
            if ($serviceApplied) {
                Write-Log ("Debloat servizi: {0} -> {1}" -f $svc.Label, $svc.Startup) 'OK'
            } else {
                Write-Log ("Debloat servizi non applicato per {0}: salto conferma OK" -f $svc.Name) 'INFO'
            }
        } catch {
            Write-Log ("Debloat servizi saltato per {0}: {1}" -f $svc.Name, $_.Exception.Message) 'WARN'
        }
    }

    $safeRemoveNames = @(
        'Microsoft.BingNews',
        'Microsoft.BingWeather',
        'Microsoft.GetHelp',
        'Microsoft.Getstarted',
        'Microsoft.MicrosoftSolitaireCollection',
        'Microsoft.People',
        'Microsoft.PowerAutomateDesktop',
        'Microsoft.WindowsFeedbackHub',
        'Microsoft.WindowsMaps',
        'Microsoft.ZuneVideo',
        'Clipchamp.Clipchamp'
    )

    $preservePatterns = @(
        '^SpotifyAB\.SpotifyMusic$',
        '^Microsoft\.Xbox',
        '^Microsoft\.GamingApp$',
        '^Microsoft\.GamingServices$',
        '^Microsoft\.StorePurchaseApp$',
        '^Microsoft\.WindowsStore$',
        '^Microsoft\.DesktopAppInstaller$'
    )

    foreach ($pkgName in $safeRemoveNames) {
        try {
            $pkgs = @(Get-AppxPackage -Name $pkgName -ErrorAction SilentlyContinue)
            foreach ($pkg in $pkgs) {
                if (-not $pkg -or [string]::IsNullOrWhiteSpace($pkg.Name)) { continue }
                $preserve = $false
                foreach ($pattern in $preservePatterns) {
                    if ($pkg.Name -match $pattern) { $preserve = $true; break }
                }
                if ($preserve) {
                    Write-Log ("Debloat app: preservata {0}" -f $pkg.Name) 'INFO'
                    continue
                }
                Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction SilentlyContinue
                Write-Log ("Debloat app rimossa per utente corrente: {0}" -f $pkg.Name) 'OK'
            }
        } catch {
            Write-Log ("Debloat app saltato per {0}: {1}" -f $pkgName, $_.Exception.Message) 'WARN'
        }

        try {
            $provPkgs = @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -eq $pkgName })
            foreach ($prov in $provPkgs) {
                if (-not $prov -or [string]::IsNullOrWhiteSpace($prov.DisplayName)) { continue }
                $preserve = $false
                foreach ($pattern in $preservePatterns) {
                    if ($prov.DisplayName -match $pattern) { $preserve = $true; break }
                }
                if ($preserve) {
                    Write-Log ("Debloat provisioned: preservata {0}" -f $prov.DisplayName) 'INFO'
                    continue
                }
                Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName -ErrorAction SilentlyContinue | Out-Null
                Write-Log ("Debloat provisioned rimosso: {0}" -f $prov.DisplayName) 'OK'
            }
        } catch {
            Write-Log ("Debloat provisioned saltato per {0}: {1}" -f $pkgName, $_.Exception.Message) 'WARN'
        }
    }

    Write-Log 'Debloat gaming-safe completato.' 'OK'
}

function Apply-WinCaffeSafeFileIoTweaks {
    [CmdletBinding()]
    param()

    Write-Log 'Avvio ottimizzazioni File I/O stile WinCaffe (versione safe)...' 'INFO'

    try {
        fsutil behavior set disablelastaccess 1 | Out-Null
        Write-Log 'NTFS Last Access Time disattivato.' 'OK'
    } catch {
        Write-Log ("Impossibile impostare disablelastaccess: {0}" -f $_.Exception.Message) 'WARN'
    }

    try {
        fsutil behavior set disable8dot3 1 | Out-Null
        Write-Log 'Creazione nomi 8.3 disattivata.' 'OK'
    } catch {
        Write-Log ("Impossibile impostare disable8dot3: {0}" -f $_.Exception.Message) 'WARN'
    }

    try {
        fsutil behavior set DisableDeleteNotify 0 | Out-Null
        Write-Log 'TRIM/DisableDeleteNotify impostato in modalità corretta per SSD/NVMe.' 'OK'
    } catch {
        Write-Log ("Impossibile impostare DisableDeleteNotify: {0}" -f $_.Exception.Message) 'WARN'
    }

    Set-DwordValueIfDifferent -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'LargeSystemCache' -Value 0 -Label 'HKLM:\...\Memory Management -> LargeSystemCache'

    $lanmanPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters'
    Set-DwordValueIfDifferent -Path $lanmanPath -Name 'DisableBandwidthThrottling' -Value 1 -Label 'HKLM:\...\LanmanWorkstation -> DisableBandwidthThrottling'
    Set-DwordValueIfDifferent -Path $lanmanPath -Name 'DisableLargeMtu' -Value 0 -Label 'HKLM:\...\LanmanWorkstation -> DisableLargeMtu'
    Set-DwordValueIfDifferent -Path $lanmanPath -Name 'FileInfoCacheLifetime' -Value 30 -Label 'HKLM:\...\LanmanWorkstation -> FileInfoCacheLifetime'

    Write-Log 'Ottimizzazioni File I/O safe completate.' 'OK'
}

# ---------------------------------------------------------------
# APPLY LITE PRO GAMING BASE
# Tutte le scritture su registro ora usano funzioni idempotenti.
# I servizi ora usano Set-ServiceStartupIfDifferent.
# ---------------------------------------------------------------
# ---------------------------------------------------------------
# [v4.1 FIX] HAGS
# Era Set-DwordValue (non idempotente). Ora usa Set-DwordValueIfDifferent.
# ---------------------------------------------------------------

function Set-HAGS {
    param([Parameter(Mandatory)] [ValidateSet('On','Off')] [string]$Mode)
    Ensure-Backup
    $value = if ($Mode -eq 'On') { [UInt32]2 } else { [UInt32]1 }
    Set-DwordValueIfDifferent `
        -Path  'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' `
        -Name  'HwSchMode' `
        -Value $value `
        -Label ("GraphicsDrivers -> HwSchMode (HAGS {0})" -f $Mode)
    Write-Log ("HAGS impostato su {0}. Riavvio richiesto." -f $Mode) 'OK'
}

# ---------------------------------------------------------------
# GAMEWATCHER AGENT
# ---------------------------------------------------------------

function Get-AgentTemplate {
@'
param(
    [string]$LogRoot = "$env:ProgramData\WinCaffe\LiteProGamingEdition\Logs"
)

# ==============================================================
#  WinCaffe Lite Pro Gaming Agent - v1.0a
#
#  Modalita':
#  - Priorita' abbassata da High ad AboveNormal.
#    High puo' affamare thread driver/audio/input causando calo FPS.
#    Fonte: https://learn.microsoft.com/en-us/windows/win32/procthread/scheduling-priorities
#  - Timer resolution 0.5ms attivato al primo gioco rilevato e
#    rilasciato automaticamente quando tutti i giochi si chiudono.
#    Basato su OGD_Timer_0.5ms.ps1 (crediti: OGD/DarkPlayer84Tv).
#    NtSetTimerResolution e' una funzione interna NT (ntdll), non
#    documentata ufficialmente da Microsoft: usarla e' comune ma non
#    supportata formalmente.
#    0.5ms = 5000 unita' da 100 nanosecondi.
# ==============================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'SilentlyContinue'
New-Item -ItemType Directory -Force -Path $LogRoot | Out-Null
$AgentLog = Join-Path $LogRoot 'lite-pro-gaming-agent.log'

function Write-AgentLog {
    param([string]$Message)
    $line = "[{0}] [AGENT] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -Path $AgentLog -Value $line -Encoding UTF8
}

# -- P/Invoke: foreground window + timer resolution --
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class WinCaffeNative {
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

    // NtSetTimerResolution: funzione interna NT (ntdll), non documentata ufficialmente.
    // DesiredResolution: in unita' da 100 nanosecondi. 0.5ms = 5000.
    // SetResolution: true per attivare, false per rilasciare.
    // CurrentResolution: valore effettivo dopo la chiamata.
    [DllImport("ntdll.dll")]
    public static extern int NtSetTimerResolution(uint DesiredResolution, bool SetResolution, out uint CurrentResolution);

    [DllImport("ntdll.dll")]
    public static extern int NtQueryTimerResolution(out uint MinimumResolution, out uint MaximumResolution, out uint CurrentResolution);
}
"@

# Timer 0.5ms = 5000 unita' da 100ns
$TIMER_TARGET_100NS = [uint32]5000
$timerActive = $false

function Enable-TimerResolution {
    if ($script:timerActive) { return }
    try {
        $current = [uint32]0
        $ret = [WinCaffeNative]::NtSetTimerResolution($script:TIMER_TARGET_100NS, $true, [ref]$current)
        if ($ret -eq 0) {
            $script:timerActive = $true
            $actualMs = [math]::Round($current / 10000.0, 3)
            Write-AgentLog ("Timer resolution attivata: {0} ms (richiesto 0.500 ms, codice ret={1})" -f $actualMs, $ret)
        } else {
            Write-AgentLog ("NtSetTimerResolution fallita: codice ret={0}" -f $ret)
        }
    } catch {
        Write-AgentLog ("Eccezione Enable-TimerResolution: {0}" -f $_.Exception.Message)
    }
}

function Disable-TimerResolution {
    if (-not $script:timerActive) { return }
    try {
        $current = [uint32]0
        $ret = [WinCaffeNative]::NtSetTimerResolution($script:TIMER_TARGET_100NS, $false, [ref]$current)
        $script:timerActive = $false
        Write-AgentLog ("Timer resolution rilasciata (codice ret={0})" -f $ret)
    } catch {
        Write-AgentLog ("Eccezione Disable-TimerResolution: {0}" -f $_.Exception.Message)
    }
}

$ExcludedNames = @(
    'explorer','dwm','shellexperiencehost','searchhost','searchapp','startmenuexperiencehost','taskmgr',
    'powershell','pwsh','cmd','conhost','msedge','chrome','firefox','opera','discord','steam','steamwebhelper',
    'epicgameslauncher','eadesktop','battle.net','battle.net launcher','ubisoftconnect','goggalaxy','riotclientservices',
    'systemsettings','applicationframehost','lockapp','textinputhost','nvidia app','nvcontainer','rtss','obs64'
)

$KnownGamePathHints = @(
    '\steamapps\common\','\epic games\','\gog galaxy\games\','\battle.net\','\ubisoft\','\ea games\',
    '\xboxgames\','\games\','\riot games\','\playnite\'
)

$Boosted = @{}
Write-AgentLog ('Agent avviato. Priorita target: AboveNormal | Timer: 0.500ms via NtSetTimerResolution.')

while ($true) {
    try {
        $hWnd = [WinCaffeNative]::GetForegroundWindow()
        if ($hWnd -eq [IntPtr]::Zero) { Start-Sleep -Seconds 3; continue }

        [uint32]$pid = 0
        [WinCaffeNative]::GetWindowThreadProcessId($hWnd, [ref]$pid) | Out-Null
        if ($pid -eq 0) { Start-Sleep -Seconds 3; continue }

        $proc  = Get-Process -Id $pid -ErrorAction SilentlyContinue
        if (-not $proc) { Start-Sleep -Seconds 3; continue }

        $pname = $proc.ProcessName.ToLowerInvariant()
        if ($ExcludedNames -contains $pname) { Start-Sleep -Seconds 3; continue }

        $path      = ''
        try { $path = $proc.MainModule.FileName } catch { $path = '' }
        $pathLower = $path.ToLowerInvariant()

        $isCandidate = $false
        foreach ($hint in $KnownGamePathHints) {
            if ($pathLower.Contains($hint)) { $isCandidate = $true; break }
        }
        if (-not $isCandidate) {
            if ($proc.MainWindowTitle -and
                $proc.MainWindowTitle.Trim().Length -ge 2 -and
                $proc.CPU -ge 0.1 -and
                $proc.WorkingSet64 -ge 300MB) {
                $isCandidate = $true
            }
        }

        if ($isCandidate -and -not $Boosted.ContainsKey($pid)) {
            try {
                # AboveNormal invece di High: meno aggressivo, non affama driver/audio/input.
                # Fonte: https://learn.microsoft.com/en-us/windows/win32/procthread/scheduling-priorities
                $proc.PriorityClass = 'AboveNormal'
                $Boosted[$pid] = [pscustomobject]@{
                    Name  = $proc.ProcessName
                    Path  = $path
                    Since = (Get-Date)
                }
                Write-AgentLog ("Boost AboveNormal applicato a PID={0} Name={1}" -f $pid, $proc.ProcessName)

                # Attiva il timer 0.25ms al primo gioco rilevato
                Enable-TimerResolution
            } catch {
                Write-AgentLog ("Impossibile boostare PID={0} Name={1}: {2}" -f $pid, $proc.ProcessName, $_.Exception.Message)
            }
        }

        # Pulizia processi terminati
        foreach ($knownPid in @($Boosted.Keys)) {
            if (-not (Get-Process -Id $knownPid -ErrorAction SilentlyContinue)) {
                $info = $Boosted[$knownPid]
                Write-AgentLog ("Processo terminato PID={0} Name={1}" -f $knownPid, $info.Name)
                $Boosted.Remove($knownPid)
            }
        }

        # Se non ci sono piu' giochi tracciati, rilascia il timer
        if ($Boosted.Count -eq 0 -and $script:timerActive) {
            Disable-TimerResolution
        }

    } catch {}

    Start-Sleep -Seconds 3
}
'@
}

function Apply-BlackOps7WindowsProfile {
    [CmdletBinding()]
    param()

    Write-Log 'Applicazione profilo Windows ad alto FPS per Black Ops 7...' 'INFO'
    Set-DwordValueIfDifferent -Path 'HKCU:\Software\Microsoft\GameBar' -Name 'UseNexusForGameBarEnabled' -Value 0 -Label 'HKCU:\Software\Microsoft\GameBar -> UseNexusForGameBarEnabled'
    Set-DwordValueIfDifferent -Path 'HKCU:\Software\Microsoft\GameBar' -Name 'AllowAutoGameMode' -Value 1 -Label 'HKCU:\Software\Microsoft\GameBar -> AllowAutoGameMode'
    Set-DwordValueIfDifferent -Path 'HKCU:\Software\Microsoft\GameBar' -Name 'AutoGameModeEnabled' -Value 1 -Label 'HKCU:\Software\Microsoft\GameBar -> AutoGameModeEnabled'
    Set-DwordValueIfDifferent -Path 'HKCU:\System\GameConfigStore' -Name 'GameDVR_FSEBehaviorMode' -Value 2 -Label 'HKCU:\System\GameConfigStore -> GameDVR_FSEBehaviorMode'
    Set-DwordValueIfDifferent -Path 'HKCU:\System\GameConfigStore' -Name 'GameDVR_HonorUserFSEBehaviorMode' -Value 1 -Label 'HKCU:\System\GameConfigStore -> GameDVR_HonorUserFSEBehaviorMode'
    Set-DwordValueIfDifferent -Path 'HKCU:\System\GameConfigStore' -Name 'GameDVR_DXGIHonorFSEWindowsCompatible' -Value 1 -Label 'HKCU:\System\GameConfigStore -> GameDVR_DXGIHonorFSEWindowsCompatible'
    Set-DwordValueIfDifferent -Path 'HKCU:\System\GameConfigStore' -Name 'GameDVR_EFSEBehaviorMode' -Value 0 -Label 'HKCU:\System\GameConfigStore -> GameDVR_EFSEBehaviorMode'
    Set-DwordValueIfDifferent -Path 'HKCU:\System\GameConfigStore' -Name 'GameDVR_Enabled' -Value 0 -Label 'HKCU:\System\GameConfigStore -> GameDVR_Enabled'
    Set-DwordValueIfDifferent -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' -Name 'AllowGameDVR' -Value 0 -Label 'HKLM:\...\GameDVR -> AllowGameDVR'
    Set-StringValueIfDifferent -Path 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences' -Name 'DirectXUserGlobalSettings' -Value 'SwapEffectUpgradeEnable=1;VRROptimizeEnable=0;' -Label 'HKCU:\...\UserGpuPreferences -> DirectXUserGlobalSettings (BO7)'
    Set-DwordValueIfDifferent -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl' -Name 'Win32PrioritySeparation' -Value 0x26 -Label 'HKLM:\...\PriorityControl -> Win32PrioritySeparation'
    Set-DwordValueIfDifferent -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' -Name 'SystemResponsiveness' -Value 20 -Label 'HKLM:\...\SystemProfile -> SystemResponsiveness (BO7)'
    Set-DwordValueIfDifferent -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games' -Name 'Priority' -Value 2 -Label 'HKLM:\...\Tasks\Games -> Priority'
    Set-StringValueIfDifferent -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games' -Name 'Scheduling Category' -Value 'Medium' -Label 'HKLM:\...\Tasks\Games -> Scheduling Category'
    Set-DwordValueIfDifferent -Path 'HKCU:\Software\Microsoft\Multimedia\Audio' -Name 'UserDuckingPreference' -Value 3 -Label 'HKCU:\...\Audio -> UserDuckingPreference'
    Write-Log 'Profilo Windows per Black Ops 7 applicato. HAGS resta scelta manuale dal menu. Riavvio consigliato.' 'OK'
}

function Apply-HyperGamingBaseCore {
    Ensure-Backup
    Write-Log 'Applicazione modulo BASE Hyper Gaming...' 'INFO'

    $powerPlan = Ensure-WinCaffePowerPlan
    if ($powerPlan -and $powerPlan.Guid) {
        Write-Log ("Profilo energetico gaming pronto: {0} ({1})" -f $powerPlan.Name, $powerPlan.Guid) 'OK'
    }

    Set-DwordValueIfDifferent -Path 'HKCU:\Software\Microsoft\GameBar' -Name 'AllowAutoGameMode' -Value 1 -Label 'HKCU:\Software\Microsoft\GameBar -> AllowAutoGameMode'
    Set-DwordValueIfDifferent -Path 'HKCU:\Software\Microsoft\GameBar' -Name 'AutoGameModeEnabled' -Value 1 -Label 'HKCU:\Software\Microsoft\GameBar -> AutoGameModeEnabled'
    Set-DwordValueIfDifferent -Path 'HKCU:\Software\Microsoft\GameBar' -Name 'UseNexusForGameBarEnabled' -Value 0 -Label 'HKCU:\Software\Microsoft\GameBar -> UseNexusForGameBarEnabled'
    Set-DwordValueIfDifferent -Path 'HKCU:\System\GameConfigStore' -Name 'GameDVR_Enabled' -Value 0 -Label 'HKCU:\System\GameConfigStore -> GameDVR_Enabled'
    Set-DwordValueIfDifferent -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' -Name 'AppCaptureEnabled' -Value 0 -Label 'HKCU:\...\GameDVR -> AppCaptureEnabled'
    Set-DwordValueIfDifferent -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' -Name 'AudioCaptureEnabled' -Value 0 -Label 'HKCU:\...\GameDVR -> AudioCaptureEnabled'
    Set-DwordValueIfDifferent -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' -Name 'CursorCaptureEnabled' -Value 0 -Label 'HKCU:\...\GameDVR -> CursorCaptureEnabled'
    Set-DwordValueIfDifferent -Path 'HKCU:\System\GameConfigStore' -Name 'GameDVR_FSEBehaviorMode' -Value 2 -Label 'HKCU:\System\GameConfigStore -> GameDVR_FSEBehaviorMode'
    Set-DwordValueIfDifferent -Path 'HKCU:\System\GameConfigStore' -Name 'GameDVR_HonorUserFSEBehaviorMode' -Value 1 -Label 'HKCU:\System\GameConfigStore -> GameDVR_HonorUserFSEBehaviorMode'
    Set-DwordValueIfDifferent -Path 'HKLM:\SOFTWARE\Microsoft\PolicyManager\default\ApplicationManagement\AllowGameDVR' -Name 'value' -Value 0 -Label 'HKLM:\...\AllowGameDVR -> value'
    Set-DwordValueIfDifferent -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' -Name 'AllowGameDVR' -Value 0 -Label 'HKLM:\...\GameDVR -> AllowGameDVR'
    Set-DwordValueIfDifferent -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' -Name 'VisualFXSetting' -Value 2 -Label 'HKCU:\...\VisualEffects -> VisualFXSetting'
    Set-DwordValueIfDifferent -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'EnableTransparency' -Value 0 -Label 'HKCU:\...\Personalize -> EnableTransparency'
    Set-DwordValueIfDifferent -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' -Name 'NetworkThrottlingIndex' -Value ([UInt32]::MaxValue) -Label 'HKLM:\...\SystemProfile -> NetworkThrottlingIndex'
    Set-DwordValueIfDifferent -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' -Name 'SystemResponsiveness' -Value 20 -Label 'HKLM:\...\SystemProfile -> SystemResponsiveness'
    Set-DwordValueIfDifferent -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl' -Name 'Win32PrioritySeparation' -Value 0x26 -Label 'HKLM:\...\PriorityControl -> Win32PrioritySeparation'
    Set-DwordValueIfDifferent -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' -Name 'PowerThrottlingOff' -Value 0 -Label 'HKLM:\...\PowerThrottling -> PowerThrottlingOff'
    Set-StringValueIfDifferent -Path 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences' -Name 'DirectXUserGlobalSettings' -Value 'SwapEffectUpgradeEnable=1;' -Label 'HKCU:\...\UserGpuPreferences -> DirectXUserGlobalSettings'

    Set-DwordValueIfDifferent -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games' -Name 'Priority' -Value 2 -Label 'HKLM:\...\Tasks\Games -> Priority'
    Set-StringValueIfDifferent -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games' -Name 'Scheduling Category' -Value 'Medium' -Label 'HKLM:\...\Tasks\Games -> Scheduling Category'
    Set-StringValueIfDifferent -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games' -Name 'Background Only' -Value 'False' -Label 'HKLM:\...\Tasks\Games -> Background Only'

    Set-ServiceStartupIfDifferent -Name 'SysMain' -StartupType Manual -TryStop
    Set-ServiceStartupIfDifferent -Name 'DiagTrack' -StartupType Manual -TryStop
    Set-ServiceStartupIfDifferent -Name 'WSearch' -StartupType Manual
    Write-Log 'WSearch lasciato su Manual: approccio più pulito e coerente con WinCaffe 8.0.13.' 'INFO'

    try {
        $hib = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name 'HiberbootEnabled' -ErrorAction Stop
        Write-Log ("Fast Startup attuale: HiberbootEnabled={0}" -f $hib.HiberbootEnabled) 'INFO'
    } catch {
        Write-Log 'Valore Fast Startup non letto.' 'WARN'
    }

    Disable-ConsumerStartupNoise
    Write-Log 'Modulo BASE completato. HAGS resta opzionale. Riavvio consigliato.' 'OK'
}

function Apply-WinCaffeBo7Module {
    Ensure-Backup
    Write-Log 'Applicazione modulo BO7...' 'INFO'
    Apply-BlackOps7WindowsProfile
    Write-Log 'Modulo BO7 completato. Riavvio consigliato.' 'OK'
}

function Apply-WinCaffeDebloatModule {
    Ensure-Backup
    Write-Log 'Applicazione modulo Debloat gaming-safe...' 'INFO'
    Apply-WinCaffeSafeDebloat
    Write-Log 'Modulo Debloat completato. Riavvio consigliato.' 'OK'
}

function Apply-WinCaffeFileIoModule {
    Ensure-Backup
    Write-Log 'Applicazione modulo File I/O...' 'INFO'
    Apply-WinCaffeSafeFileIoTweaks
    Write-Log 'Modulo File I/O completato. Riavvio consigliato.' 'OK'
}

function Apply-HyperGamingBaseAll {
    Ensure-Backup
    Write-Log 'Applicazione profilo completo ALL: Base + BO7 + Debloat + File I/O...' 'INFO'
    Apply-HyperGamingBaseCore
    Apply-WinCaffeBo7Module
    Apply-WinCaffeFileIoModule
    Apply-WinCaffeDebloatModule
    Write-Log 'Profilo ALL completato. Il watcher resta opzionale e non è consigliato con anti-cheat molto sensibili. Riavvio consigliato.' 'OK'
}

function Apply-HyperGamingBase {
    Apply-HyperGamingBaseAll
}

function Install-GameWatcher {
    Ensure-Backup
    $agent = Get-AgentTemplate
    Set-Content -Path $WatcherAgentPath -Value $agent -Encoding UTF8
    Write-Log ("Agent copiato in: {0}" -f $WatcherAgentPath) 'OK'

    try {
        $existing = Get-ScheduledTask -TaskName $WatcherTaskName -ErrorAction SilentlyContinue
        if ($existing) {
            Unregister-ScheduledTask -TaskName $WatcherTaskName -Confirm:$false -ErrorAction SilentlyContinue
            Write-Log 'Task precedente GameWatcher rimosso prima del reinstall.' 'INFO'
        }
    } catch {}

    try {
        $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ("-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"{0}`"" -f $WatcherAgentPath)
        $trigger = New-ScheduledTaskTrigger -AtLogOn
        $principal = New-ScheduledTaskPrincipal -UserId $currentUser -LogonType Interactive -RunLevel Highest
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 0)

        Register-ScheduledTask -TaskName $WatcherTaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description 'WinCaffe automatic game watcher and booster.' -ErrorAction Stop | Out-Null

        $registeredTask = Get-ScheduledTask -TaskName $WatcherTaskName -ErrorAction Stop
        if ($registeredTask) {
            Start-ScheduledTask -TaskName $WatcherTaskName -ErrorAction SilentlyContinue
            Write-Log ("GameWatcher permanente installato ed avviato per l'utente {0}." -f $currentUser) 'OK'
        } else {
            Write-Log 'Registrazione GameWatcher non verificabile dopo il register.' 'WARN'
        }
    } catch {
        Write-Log ("Installazione GameWatcher fallita: {0}" -f $_.Exception.Message) 'ERR'
    }
}

function Remove-GameWatcher {
    try {
        Stop-ScheduledTask -TaskName $WatcherTaskName -ErrorAction SilentlyContinue
        Write-Log 'Richiesto stop del task GameWatcher.' 'INFO'
    } catch {
        Write-Log ("Impossibile fermare il task GameWatcher prima della rimozione: {0}" -f $_.Exception.Message) 'WARN'
    }

    try {
        Unregister-ScheduledTask -TaskName $WatcherTaskName -Confirm:$false -ErrorAction Stop
        Write-Log 'Task GameWatcher rimosso.' 'OK'
    } catch {
        if ($_.Exception.Message -match 'No MSFT_ScheduledTask objects found') {
            Write-Log 'GameWatcher già non installato, salto la rimozione del task.' 'INFO'
        } else {
            Write-Log ("Task GameWatcher non rimosso: {0}" -f $_.Exception.Message) 'WARN'
        }
    }

    try {
        $escapedAgentPath = [Regex]::Escape($WatcherAgentPath)
        $watcherProcesses = Get-CimInstance Win32_Process -Filter "Name='powershell.exe' OR Name='pwsh.exe'" -ErrorAction SilentlyContinue | Where-Object {
            $_.CommandLine -and $_.CommandLine -match $escapedAgentPath
        }
        foreach ($proc in $watcherProcesses) {
            try {
                Stop-Process -Id $proc.ProcessId -Force -ErrorAction Stop
                Write-Log ("Processo GameWatcher terminato: PID={0}" -f $proc.ProcessId) 'OK'
            } catch {
                Write-Log ("Impossibile terminare il processo GameWatcher PID={0}: {1}" -f $proc.ProcessId, $_.Exception.Message) 'WARN'
            }
        }
    } catch {}

    if (Test-Path $WatcherAgentPath) {
        Remove-Item -Path $WatcherAgentPath -Force -ErrorAction SilentlyContinue
        Write-Log 'File agent GameWatcher rimosso.' 'OK'
    }
}

# ---------------------------------------------------------------
# QUICK REPORT (con sezione NPU aggiunta in v4.1)
# ---------------------------------------------------------------

function New-QuickReport {
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("$ProjectName v$ScriptVersion - Quick Report")
    $lines.Add(("Generated: {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')))
    $lines.Add('')

    # -- Hardware base --
    try {
        $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1 Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed
        $ram = Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum
        $os  = Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, BuildNumber

        $lines.Add(("OS:  {0} | Version {1} | Build {2}" -f $os.Caption, $os.Version, $os.BuildNumber))
        $lines.Add(("CPU: {0} | Cores {1} | Logical {2} | MaxClock {3} MHz" -f `
            $cpu.Name, $cpu.NumberOfCores, $cpu.NumberOfLogicalProcessors, $cpu.MaxClockSpeed))
        $ramGb = [math]::Round(($ram.Sum / 1GB), 2)
        $lines.Add(("RAM totale: {0} GB" -f $ramGb))
    } catch {
        $lines.Add(("Errore lettura CPU/RAM/OS: {0}" -f $_.Exception.Message))
    }

    # -- GPU --
    $lines.Add('')
    $lines.Add('GPU:')
    $gpuList = Get-FriendlyGpuReport
    foreach ($g in $gpuList) {
        $lines.Add(("  {0} | VRAM approx {1} GB  ({2})" -f $g.Name, $g.ApproxGB, $g.Note))
    }

    # -- [v4.1 NEW] NPU --
    $lines.Add('')
    $lines.Add('NPU (Neural Processing Unit):')
    $npuList = Get-NpuReport
    if ($npuList.Count -eq 0) {
        $lines.Add('  Nessuna NPU rilevata (o non supportata da questo sistema).')
    } else {
        foreach ($n in $npuList) {
            $lines.Add(("  {0} | Status: {1}" -f $n.Name, $n.Status))
            if ($n.DeviceID) {
                $lines.Add(("    DeviceID: {0}" -f $n.DeviceID))
            }
        }
    }

    # -- Registro: valori chiave --
    $checks = @(
        @{ Label='GameMode';               Path='HKCU:\Software\Microsoft\GameBar';                                            Name='AllowAutoGameMode' },
        @{ Label='GameDVR_Enabled';        Path='HKCU:\System\GameConfigStore';                                               Name='GameDVR_Enabled' },
        @{ Label='VisualFXSetting';        Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects';     Name='VisualFXSetting' },
        @{ Label='EnableTransparency';     Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize';         Name='EnableTransparency' },
        @{ Label='NetworkThrottlingIndex'; Path='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'; Name='NetworkThrottlingIndex' },
        @{ Label='SystemResponsiveness';   Path='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'; Name='SystemResponsiveness' },
        @{ Label='HwSchMode (HAGS)';       Path='HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers';                     Name='HwSchMode' },
        @{ Label='GPU Priority';           Path='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'; Name='GPU Priority' },
        @{ Label='Scheduling Category';    Path='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'; Name='Scheduling Category' }
    )

    $lines.Add('')
    $lines.Add('Registry checks:')
    foreach ($c in $checks) {
        try {
            $item = Get-ItemProperty -Path $c.Path -Name $c.Name -ErrorAction Stop
            $lines.Add(("  - {0}: {1}" -f $c.Label, $item.$($c.Name)))
        } catch {
            $lines.Add(("  - {0}: not set" -f $c.Label))
        }
    }

    # -- Servizi --
    $lines.Add('')
    $lines.Add('Services:')
    foreach ($svcName in 'SysMain','DiagTrack','WSearch') {
        try {
            $svc = Get-CimInstance Win32_Service -Filter ("Name='{0}'" -f $svcName)
            $lines.Add(("  - {0}: StartMode={1}, State={2}" -f $svc.Name, $svc.StartMode, $svc.State))
        } catch {
            $lines.Add(("  - {0}: unavailable" -f $svcName))
        }
    }

    # -- GameWatcher --
    $taskState = 'Not installed'
    try {
        $task      = Get-ScheduledTask -TaskName $WatcherTaskName -ErrorAction Stop
        $taskState = $task.State
    } catch {}
    $lines.Add('')
    $lines.Add(("GameWatcher task: {0}" -f $taskState))
    $lines.Add(("GameWatcher path: {0}" -f $WatcherAgentPath))

    Set-Content -Path $QuickReportFile -Value $lines -Encoding UTF8
    [pscustomobject]@{
        Generated  = (Get-Date).ToString('s')
        ReportFile = $QuickReportFile
        LogFile    = $CurrentLog
    } | ConvertTo-Json -Depth 5 | Set-Content -Path $SummaryFile -Encoding UTF8

    Write-Log ("Quick report creato: {0}" -f $QuickReportFile) 'OK'
    Get-Content -Path $QuickReportFile | ForEach-Object { Write-Host $_ }
}

# ---------------------------------------------------------------
# ROLLBACK
# ---------------------------------------------------------------

function Restore-RegistryValue {
    param([Parameter(Mandatory)] $Entry)
    if (-not $Entry.PathExists) {
        if (Test-Path $Entry.Path) {
            Write-Log ("Il path {0} esiste ora ma prima no. Nessuna rimozione automatica del path." -f $Entry.Path) 'WARN'
        }
        return
    }
    if (-not (Test-Path $Entry.Path)) {
        New-Item -Path $Entry.Path -Force | Out-Null
    }
    if ($Entry.ValuePresent) {
        if ($Entry.Value -is [int] -or $Entry.Value -is [long] -or $Entry.Value -is [uint32]) {
            New-ItemProperty -Path $Entry.Path -Name $Entry.Name -PropertyType DWord -Value ([UInt32]$Entry.Value) -Force | Out-Null
        } else {
            New-ItemProperty -Path $Entry.Path -Name $Entry.Name -PropertyType String -Value ([string]$Entry.Value) -Force | Out-Null
        }
        Write-Log ("Ripristinato {0} -> {1}" -f $Entry.Path, $Entry.Name) 'OK'
    } else {
        try {
            Remove-ItemProperty -Path $Entry.Path -Name $Entry.Name -ErrorAction Stop
            Write-Log ("Valore rimosso: {0} -> {1}" -f $Entry.Path, $Entry.Name) 'OK'
        } catch {
            Write-Log ("Valore {0} -> {1} già assente o non rimovibile." -f $Entry.Path, $Entry.Name) 'WARN'
        }
    }
}

function Restore-Backups {
    if (-not (Test-Path $StateFile)) {
        Write-Log 'Nessun backup trovato: rollback non disponibile.' 'WARN'
        return
    }

    Write-Log 'Avvio rollback completo...' 'INFO'
    Remove-GameWatcher

    if (Test-Path $RegistryBackupFile) {
        $regEntries = Get-Content -Path $RegistryBackupFile -Raw | ConvertFrom-Json
        foreach ($e in $regEntries) {
            Restore-RegistryValue -Entry $e
        }
    }

    if (Test-Path $ServiceBackupFile) {
        $svcEntries = Get-Content -Path $ServiceBackupFile -Raw | ConvertFrom-Json
        foreach ($svc in $svcEntries) {
            # [v4.1 FIX] Usa Set-ServiceStartupIfDifferent invece di Set-ServiceStartup.
            # Salta il servizio se è già nella modalità che era prima dello script.
            if ($svc.StartMode -in 'Auto','Automatic') {
                Set-ServiceStartupIfDifferent -Name $svc.Name -StartupType Automatic
            } elseif ($svc.StartMode -eq 'Manual') {
                Set-ServiceStartupIfDifferent -Name $svc.Name -StartupType Manual
            } elseif ($svc.StartMode -eq 'Disabled') {
                Set-ServiceStartupIfDifferent -Name $svc.Name -StartupType Disabled
            }
        }
    }

    if (Test-Path $PowerBackupFile) {
        $power = Get-Content -Path $PowerBackupFile -Raw | ConvertFrom-Json
        $match = [regex]::Match($power.ActiveSchemeRaw, '([A-Fa-f0-9\-]{36})')
        if ($match.Success) {
            try {
                & powercfg /setactive $match.Groups[1].Value | Out-Null
                Write-Log ("Piano energetico ripristinato: {0}" -f $match.Groups[1].Value) 'OK'
            } catch {
                Write-Log ("Impossibile ripristinare il piano energetico originale: {0}" -f $_.Exception.Message) 'WARN'
            }
        }
    }

    Write-Log 'Rollback completato. Riavvio consigliato.' 'OK'
}

# ---------------------------------------------------------------
# MENU PRINCIPALE
# ---------------------------------------------------------------

function Show-Menu {
    Write-UiPanel -Title 'Control Deck' -Subtitle 'Seleziona il modulo da applicare o lo strumento da usare'
    Write-Host '  Moduli Preset' -ForegroundColor Cyan
    Write-UiMenuItem -Key '1' -Title 'BASE   Core gaming Windows' -Description 'Game Mode, DVR OFF, Flip Model, power plan e core tuning prudente' -Color 'White'
    Write-UiMenuItem -Key 'B' -Title 'BO7    Modulo Black Ops 7' -Description 'Rifiniture specifiche per BO7, senza toccare file di gioco o anti-cheat' -Color 'White'
    Write-UiMenuItem -Key 'D' -Title 'DEBLOAT  Gaming-safe' -Description 'Rimuove solo app consumer e servizi secondari non essenziali' -Color 'White'
    Write-UiMenuItem -Key 'F' -Title 'FILE I/O  Velocita sistema e caricamenti' -Description 'NTFS, TRIM e piccoli tuning safe per trasferimenti e installazioni' -Color 'White'
    Write-UiMenuItem -Key 'A' -Title 'ALL    Base + BO7 + Debloat + File I/O' -Description 'Applica tutto il profilo modulare in sequenza' -Color 'Cyan'
    Write-Host ''
    Write-Host '  Utility' -ForegroundColor Cyan
    Write-UiMenuItem -Key '2' -Title 'Installa watcher permanente' -Description 'Opzionale; meno consigliato con anti-cheat molto sensibili' -Color 'White'
    Write-UiMenuItem -Key '3' -Title 'Rimuovi watcher permanente' -Description 'Ferma e rimuove task, agent e processi watcher' -Color 'White'
    Write-UiMenuItem -Key '4' -Title 'Imposta HAGS su ON' -Description 'Scelta manuale, separata dal preset base' -Color 'White'
    Write-UiMenuItem -Key '5' -Title 'Imposta HAGS su OFF' -Description 'Ripristina HAGS a OFF via registro' -Color 'White'
    Write-UiMenuItem -Key '6' -Title 'Genera Quick Report' -Description 'Crea report rapido con NPU, servizi, HAGS e stato watcher' -Color 'White'
    Write-UiMenuItem -Key '7' -Title 'Rollback completo dai backup' -Description 'Riporta registro, servizi e piano energia allo stato salvato' -Color 'White'
    Write-Host ''
    Write-UiMenuItem -Key '0' -Title 'Esci' -Description 'Chiude il control deck' -Color 'Gray'
    Write-Host ''
}

# ---------------------------------------------------------------
# ENTRY POINT
# ---------------------------------------------------------------

function Get-WinCaffePowerPlan {
    [CmdletBinding()]
    param([string]$Name = 'WinCaffe Lite Pro Gaming Plan')
    try {
        $plans = (& powercfg /list) 2>&1 | Out-String
        foreach ($line in ($plans -split "`r?`n")) {
            $guidMatch = [regex]::Match($line, '([A-Fa-f0-9\-]{36})')
            if ($guidMatch.Success -and $line -match [regex]::Escape($Name)) {
                return [PSCustomObject]@{
                    Guid = $guidMatch.Groups[1].Value
                    Name = $Name
                }
            }
        }
    } catch {}
    return $null
}

function Invoke-WinCaffePowerCfgVerbose {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string[]]$Arguments,
        [Parameter(Mandatory)] [string]$Label
    )

    try {
        & powercfg @Arguments | Out-Null
        Write-Log ("Power plan tweak applicato: {0}" -f $Label) 'OK'
    } catch {
        Write-Log ("Power plan tweak non applicato ({0}): {1}" -f $Label, $_.Exception.Message) 'WARN'
    }
}

function Set-WinCaffePowerPlanValues {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Guid
    )

    Write-Log ("Applicazione valori power plan su GUID {0}..." -f $Guid) 'INFO'
    Invoke-WinCaffePowerCfgVerbose -Arguments @('/setacvalueindex', $Guid, 'SUB_PROCESSOR', 'PERFBOOSTMODE', '1') -Label 'AC Processor Boost Mode = 1'
    Invoke-WinCaffePowerCfgVerbose -Arguments @('/setdcvalueindex', $Guid, 'SUB_PROCESSOR', 'PERFBOOSTMODE', '1') -Label 'DC Processor Boost Mode = 1'
    Invoke-WinCaffePowerCfgVerbose -Arguments @('/setacvalueindex', $Guid, 'SUB_PROCESSOR', 'PROCTHROTTLEMIN', '5') -Label 'AC CPU min throttle = 5'
    Invoke-WinCaffePowerCfgVerbose -Arguments @('/setdcvalueindex', $Guid, 'SUB_PROCESSOR', 'PROCTHROTTLEMIN', '5') -Label 'DC CPU min throttle = 5'
    Invoke-WinCaffePowerCfgVerbose -Arguments @('/setacvalueindex', $Guid, 'SUB_PROCESSOR', 'PERFINCTHRESHOLD', '10') -Label 'AC perf increase threshold = 10'
    Invoke-WinCaffePowerCfgVerbose -Arguments @('/setacvalueindex', $Guid, 'SUB_PROCESSOR', 'PERFDECTHRESHOLD', '8') -Label 'AC perf decrease threshold = 8'
    Invoke-WinCaffePowerCfgVerbose -Arguments @('/setacvalueindex', $Guid, 'SUB_PROCESSOR', 'PERFINCTIME', '1') -Label 'AC perf increase time = 1'
    Invoke-WinCaffePowerCfgVerbose -Arguments @('/setacvalueindex', $Guid, 'SUB_PROCESSOR', 'PERFDECTIME', '1') -Label 'AC perf decrease time = 1'
    Invoke-WinCaffePowerCfgVerbose -Arguments @('/setacvalueindex', $Guid, 'SUB_DISK', 'DISKIDLE', '0') -Label 'AC disk idle timeout = 0'
    Invoke-WinCaffePowerCfgVerbose -Arguments @('/setdcvalueindex', $Guid, 'SUB_DISK', 'DISKIDLE', '10') -Label 'DC disk idle timeout = 10'
    Invoke-WinCaffePowerCfgVerbose -Arguments @('/setacvalueindex', $Guid, 'SUB_SLEEP', 'STANDBYIDLE', '0') -Label 'AC standby idle = 0'
    Invoke-WinCaffePowerCfgVerbose -Arguments @('/setacvalueindex', $Guid, 'SUB_SLEEP', 'HIBERNATEIDLE', '0') -Label 'AC hibernate idle = 0'
    Invoke-WinCaffePowerCfgVerbose -Arguments @('/setacvalueindex', $Guid, '2a737441-1930-4402-8d77-b2bebba308a3', '48e6b7a6-50f5-4782-a5d4-53bb8f07e226', '0') -Label 'AC USB selective suspend = 0'
    Invoke-WinCaffePowerCfgVerbose -Arguments @('/setdcvalueindex', $Guid, '2a737441-1930-4402-8d77-b2bebba308a3', '48e6b7a6-50f5-4782-a5d4-53bb8f07e226', '0') -Label 'DC USB selective suspend = 0'
    Invoke-WinCaffePowerCfgVerbose -Arguments @('/setactive', $Guid) -Label ("Piano energetico attivo = {0}" -f $Guid)
}

function Ensure-WinCaffePowerPlan {
    [CmdletBinding()]
    param()

    $targetName = 'WinCaffe Lite Pro Gaming Plan'
    $existing = Get-WinCaffePowerPlan -Name $targetName
    if ($existing) {
        Write-Log ("Profilo energetico già presente: {0} ({1})" -f $existing.Name, $existing.Guid) 'INFO'
        Set-WinCaffePowerPlanValues -Guid $existing.Guid
        return $existing
    }

    $sourceGuid = $null
    try {
        $ultimate = Get-UltimatePerformanceGuid
        if ($ultimate) {
            $sourceGuid = $ultimate
            Write-Log ("Power plan sorgente trovato: Prestazioni eccellenti ({0})" -f $sourceGuid) 'INFO'
        } else {
            $dup = (& powercfg /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61) 2>&1 | Out-String
            if ($dup -match '([A-Fa-f0-9\-]{36})') {
                $sourceGuid = $Matches[1]
                Write-Log ("Power plan sorgente duplicato da Ultimate Performance: {0}" -f $sourceGuid) 'INFO'
            }
        }
    } catch {}

    if (-not $sourceGuid) {
        try {
            $list = (& powercfg /list) 2>&1 | Out-String
            foreach ($line in ($list -split "`r?`n")) {
                if ($line -match '([A-Fa-f0-9\-]{36})' -and ($line -match 'High performance' -or $line -match 'Prestazioni elevate')) {
                    $sourceGuid = $Matches[1]
                    Write-Log ("Power plan fallback trovato: Prestazioni elevate ({0})" -f $sourceGuid) 'INFO'
                    break
                }
            }
        } catch {}
    }

    if (-not $sourceGuid) {
        $sourceGuid = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
        Write-Log ("Power plan fallback statico usato: {0}" -f $sourceGuid) 'WARN'
    }

    $newGuid = $null
    try {
        $dupOut = (& powercfg /duplicatescheme $sourceGuid) 2>&1 | Out-String
        if ($dupOut -match '([A-Fa-f0-9\-]{36})') {
            $newGuid = $Matches[1]
            Write-Log ("Nuovo power plan duplicato correttamente: {0}" -f $newGuid) 'OK'
        }
    } catch {}

    if (-not $newGuid) {
        $fallback = Get-WinCaffePowerPlan -Name $targetName
        if ($fallback) {
            Write-Log ("Recupero power plan esistente dopo duplicazione fallita: {0}" -f $fallback.Guid) 'WARN'
            Set-WinCaffePowerPlanValues -Guid $fallback.Guid
            return $fallback
        }
        if ($sourceGuid) {
            Write-Log ("Uso diretto del power plan sorgente senza duplicazione: {0}" -f $sourceGuid) 'WARN'
            Set-WinCaffePowerPlanValues -Guid $sourceGuid
            return [PSCustomObject]@{
                Guid = $sourceGuid
                Name = 'Fallback High/Ultimate Performance'
            }
        }
        return $null
    }

    Invoke-WinCaffePowerCfgVerbose -Arguments @('/changename', $newGuid, $targetName) -Label ("Rinomina piano energetico in '{0}'" -f $targetName) | Out-Null
    Set-WinCaffePowerPlanValues -Guid $newGuid

    return [PSCustomObject]@{
        Guid = $newGuid
        Name = $targetName
    }
}


# ---------------------------------------------------------------
# ENTRY POINT E MENU PRINCIPALE
# ---------------------------------------------------------------
try {
    Test-Admin
    if (-not (Show-WinCaffeDisclaimer)) {
        Write-Log "Uscita richiesta dall'utente prima del menu." 'INFO'
        return
    }
    Show-WinCaffeStartupIntro
    $script:WinCaffeExitRequested = $false
    while (-not $script:WinCaffeExitRequested) {
        Write-Banner
        Write-Host ("Log corrente: {0}" -f $CurrentLog) -ForegroundColor DarkGray
        Show-Menu
        $choice = Read-Host "Seleziona un'opzione"
        switch ($choice) {
            '1' { [void](Invoke-WinCaffeMenuAction -ActionLabel 'BASE' -Action { Apply-HyperGamingBaseCore }); continue }
            'B' { [void](Invoke-WinCaffeMenuAction -ActionLabel 'BO7' -Action { Apply-WinCaffeBo7Module }); continue }
            'b' { [void](Invoke-WinCaffeMenuAction -ActionLabel 'BO7' -Action { Apply-WinCaffeBo7Module }); continue }
            'D' { [void](Invoke-WinCaffeMenuAction -ActionLabel 'DEBLOAT' -Action { Apply-WinCaffeDebloatModule }); continue }
            'd' { [void](Invoke-WinCaffeMenuAction -ActionLabel 'DEBLOAT' -Action { Apply-WinCaffeDebloatModule }); continue }
            'F' { [void](Invoke-WinCaffeMenuAction -ActionLabel 'FILE IO' -Action { Apply-WinCaffeFileIoModule }); continue }
            'f' { [void](Invoke-WinCaffeMenuAction -ActionLabel 'FILE IO' -Action { Apply-WinCaffeFileIoModule }); continue }
            'A' { [void](Invoke-WinCaffeMenuAction -ActionLabel 'ALL' -Action { Apply-HyperGamingBaseAll }); continue }
            'a' { [void](Invoke-WinCaffeMenuAction -ActionLabel 'ALL' -Action { Apply-HyperGamingBaseAll }); continue }
            '2' { [void](Invoke-WinCaffeMenuAction -ActionLabel 'INSTALL GAMEWATCHER' -Action { Install-GameWatcher }); continue }
            '3' { [void](Invoke-WinCaffeMenuAction -ActionLabel 'REMOVE GAMEWATCHER' -Action { Remove-GameWatcher }); continue }
            '4' { [void](Invoke-WinCaffeMenuAction -ActionLabel 'HAGS ON' -Action { Set-HAGS -Mode 'On' }); continue }
            '5' { [void](Invoke-WinCaffeMenuAction -ActionLabel 'HAGS OFF' -Action { Set-HAGS -Mode 'Off' }); continue }
            '6' { [void](Invoke-WinCaffeMenuAction -ActionLabel 'QUICK REPORT' -Action { New-QuickReport }); continue }
            '7' { [void](Invoke-WinCaffeMenuAction -ActionLabel 'ROLLBACK' -Action { Restore-Backups }); continue }
            '0' {
                Write-Log "Uscita richiesta dall'utente." 'INFO'
                $script:WinCaffeExitRequested = $true
                continue
            }
            default {
                Write-Log 'Scelta non valida.' 'WARN'
                Read-Host 'Premi INVIO per tornare al menu' | Out-Null
            }
        }
    }
} catch {
    Write-Log $_.Exception.Message 'ERR'
    throw
}
