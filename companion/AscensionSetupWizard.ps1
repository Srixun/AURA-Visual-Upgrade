param(
    [string]$InstallPath,
    [ValidateSet('ReShadeBalanced', 'ReShadeCinematic', 'FrameGeneration', 'DX12Balanced', 'DX11Balanced', 'DX12Performance', 'DX12Quality', 'AddonOnly', 'UninstallReShade', 'Uninstall', 'Status')]
    [string]$Preset,
    [switch]$ListOnly,
    [switch]$SkipProcessCheck
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$installerScript = Join-Path $scriptRoot 'AscensionDX11.ps1'
$profileScript = Join-Path $scriptRoot 'AscensionGraphicsProfiles.ps1'
$reShadeScript = Join-Path $scriptRoot 'AscensionReShade.ps1'
$addonInstallerScript = Join-Path $scriptRoot 'Install-AURAVisualUpgrade.ps1'
if (-not (Test-Path -LiteralPath $addonInstallerScript -PathType Leaf)) {
    $addonInstallerScript = Join-Path (Split-Path -Parent $scriptRoot) 'installer\Install-AURAVisualUpgrade.ps1'
}

function Add-Candidate {
    param(
        [System.Collections.ArrayList]$Candidates,
        [string]$Path,
        [string]$Source
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return
    }
    try {
        $fullPath = [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
    } catch {
        return
    }
    if (-not (Test-Path -LiteralPath (Join-Path $fullPath 'Ascension.exe') -PathType Leaf)) {
        return
    }
    if (@($Candidates | Where-Object { $_.Path -ieq $fullPath }).Count -gt 0) {
        return
    }

    $d3d9Path = Join-Path $fullPath 'd3d9.dll'
    $renderer = 'System/unknown'
    if (Test-Path -LiteralPath $d3d9Path) {
        $product = (Get-Item -LiteralPath $d3d9Path).VersionInfo.ProductName
        $renderer = if ($product -eq 'dgVoodoo') { 'dgVoodoo installed' } elseif ($product -eq 'DXVK') { 'DXVK original' } else { [string]$product }
    }
    $label = if ($Source -eq 'Launcher cache') {
        'Official launcher installation'
    } elseif ($fullPath -match '(?i)test') {
        'Test installation'
    } else {
        'Detected installation'
    }

    [void]$Candidates.Add([pscustomobject]@{
        Path = $fullPath
        Source = $Source
        Label = $label
        Renderer = $renderer
    })
}

function Find-AscensionInstallations {
    $candidates = New-Object System.Collections.ArrayList

    $cachePath = Join-Path $env:APPDATA 'projectascension\Cache\Cache_Data'
    if (Test-Path -LiteralPath $cachePath) {
        foreach ($file in Get-ChildItem -LiteralPath $cachePath -File -ErrorAction SilentlyContinue) {
            try {
                $content = [System.IO.File]::ReadAllText($file.FullName)
                $match = [regex]::Match($content, '"install_root"\s*:\s*"((?:\\.|[^"])*)"')
                if ($match.Success) {
                    $jsonString = '"' + $match.Groups[1].Value + '"'
                    $root = $jsonString | ConvertFrom-Json
                    Add-Candidate $candidates $root 'Launcher cache'
                }
            } catch {
                continue
            }
        }
    }

    foreach ($drive in Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue) {
        if ($drive.Root -notmatch '^[A-Z]:\\$') {
            continue
        }
        foreach ($relative in @(
            'Games\Ascension',
            'Ascension',
            'Ascensiontest',
            'Project Ascension',
            'Games\Project Ascension'
        )) {
            Add-Candidate $candidates (Join-Path $drive.Root $relative) 'Common location'
        }
    }

    foreach ($path in @(
        (Join-Path $env:LOCALAPPDATA 'Ascension'),
        (Join-Path $env:USERPROFILE 'Games\Ascension'),
        (Join-Path $env:USERPROFILE 'Ascension')
    )) {
        Add-Candidate $candidates $path 'User location'
    }

    return @($candidates | Sort-Object @{Expression={ if ($_.Source -eq 'Launcher cache') { 0 } elseif ($_.Label -eq 'Test installation') { 2 } else { 1 } }}, Path)
}

function Select-FolderManually {
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = 'Select the folder containing Ascension.exe'
    $dialog.ShowNewFolderButton = $false
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        throw 'No Ascension folder was selected.'
    }
    if (-not (Test-Path -LiteralPath (Join-Path $dialog.SelectedPath 'Ascension.exe') -PathType Leaf)) {
        throw 'The selected folder does not contain Ascension.exe.'
    }
    return [System.IO.Path]::GetFullPath($dialog.SelectedPath).TrimEnd('\')
}

function Select-Installation {
    param([object[]]$Candidates)

    if ($Candidates.Count -eq 0) {
        Write-Host 'No installation was found automatically. Opening folder selection...' -ForegroundColor Yellow
        return Select-FolderManually
    }

    Write-Host 'Detected Ascension installations:' -ForegroundColor Cyan
    for ($index = 0; $index -lt $Candidates.Count; $index++) {
        $candidate = $Candidates[$index]
        Write-Host "  $($index + 1). $($candidate.Label)"
        Write-Host "     $($candidate.Path) [$($candidate.Renderer)]"
    }
    Write-Host "  $($Candidates.Count + 1). Choose another folder"
    Write-Host '  0. Exit'

    while ($true) {
        $choice = Read-Host 'Installation'
        $number = 0
        if ([int]::TryParse($choice, [ref]$number)) {
            if ($number -eq 0) { exit 0 }
            if ($number -eq $Candidates.Count + 1) { return Select-FolderManually }
            if ($number -ge 1 -and $number -le $Candidates.Count) { return $Candidates[$number - 1].Path }
        }
        Write-Host 'Enter one of the listed numbers.' -ForegroundColor Yellow
    }
}

function Select-Preset {
    Write-Host ''
    Write-Host 'Choose setup:' -ForegroundColor Cyan
    Write-Host '  1. DX12 + Frame Generation + ReShade Balanced (recommended)'
    Write-Host '  2. DX12 + Frame Generation + ReShade Cinematic (higher cost)'
    Write-Host '  3. DX12 + Frame Generation'
    Write-Host '  4. DX12 Balanced'
    Write-Host '  5. DX11 Balanced (most compatible)'
    Write-Host '  6. DX12 Performance'
    Write-Host '  7. DX12 Quality'
    Write-Host '  8. Install/update AURA Visual Upgrade addon only'
    Write-Host '  9. Status only'
    Write-Host '  10. Uninstall ReShade only'
    Write-Host '  11. Uninstall wrapper and restore original files'
    Write-Host '  0. Exit'
    while ($true) {
        switch (Read-Host 'Setup') {
            '1' { return 'ReShadeBalanced' }
            '2' { return 'ReShadeCinematic' }
            '3' { return 'FrameGeneration' }
            '4' { return 'DX12Balanced' }
            '5' { return 'DX11Balanced' }
            '6' { return 'DX12Performance' }
            '7' { return 'DX12Quality' }
            '8' { return 'AddonOnly' }
            '9' { return 'Status' }
            '10' { return 'UninstallReShade' }
            '11' { return 'Uninstall' }
            '0' { exit 0 }
            default { Write-Host 'Enter one of the listed numbers.' -ForegroundColor Yellow }
        }
    }
}

function Invoke-Installer {
    param([string]$Action, [string]$Path, [string]$Renderer)
    $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $installerScript, '-Action', $Action, '-InstallPath', $Path)
    if ($Renderer) { $arguments += @('-Renderer', $Renderer) }
    if ($SkipProcessCheck) { $arguments += '-SkipProcessCheck' }
    & powershell.exe @arguments
    if ($LASTEXITCODE -ne 0) { throw "Installer action '$Action' failed." }
}

function Invoke-Profile {
    param([string]$ProfileName, [string]$Path)
    $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $profileScript, '-Profile', $ProfileName, '-InstallPath', $Path)
    if ($SkipProcessCheck) { $arguments += '-SkipProcessCheck' }
    & powershell.exe @arguments
    if ($LASTEXITCODE -ne 0) { throw "Graphics profile '$ProfileName' failed." }
}

function Invoke-ReShade {
    param([string]$Action, [string]$Path, [string]$ReShadePreset)
    $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $reShadeScript, '-Action', $Action, '-InstallPath', $Path)
    if ($ReShadePreset) { $arguments += @('-Preset', $ReShadePreset) }
    if ($SkipProcessCheck) { $arguments += '-SkipProcessCheck' }
    & powershell.exe @arguments
    if ($LASTEXITCODE -ne 0) { throw "ReShade action '$Action' failed." }
}

function Install-AuraAddon {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $addonInstallerScript -PathType Leaf)) { throw 'The verified AURA addon installer is missing.' }
    $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $addonInstallerScript, '-Action', 'Install', '-InstallPath', $Path, '-SkipUpdateCheck')
    if ($SkipProcessCheck) { $arguments += '-SkipProcessCheck' }
    & powershell.exe @arguments
    if ($LASTEXITCODE -ne 0) { throw 'AURA Visual Upgrade addon installation failed.' }
}

function Confirm-AscensionClosed {
    if ($SkipProcessCheck) { return }
    while (@(Get-Process -Name Ascension -ErrorAction SilentlyContinue).Count -gt 0) {
        Write-Host ''
        Write-Host 'Ascension is currently running. Close it before continuing.' -ForegroundColor Yellow
        $answer = Read-Host 'Press Enter after closing it, or type Q to quit'
        if ($answer -match '^(?i)q$') { exit 0 }
    }
}

try {
    Clear-Host
    Write-Host '============================================================' -ForegroundColor DarkCyan
    Write-Host ' Ascension Modern Graphics Setup' -ForegroundColor Cyan
    Write-Host ' DX11, DX12, ReShade, quality profiles, and frame generation' -ForegroundColor Gray
    Write-Host '============================================================' -ForegroundColor DarkCyan
    Write-Host ''

    $candidates = @(Find-AscensionInstallations)
    if ($ListOnly) {
        $candidates | Select-Object Label,Path,Renderer,Source | Format-Table -AutoSize
        exit 0
    }

    if ([string]::IsNullOrWhiteSpace($InstallPath)) {
        $InstallPath = Select-Installation $candidates
    } else {
        $InstallPath = [System.IO.Path]::GetFullPath($InstallPath).TrimEnd('\')
        if (-not (Test-Path -LiteralPath (Join-Path $InstallPath 'Ascension.exe') -PathType Leaf)) {
            throw "Ascension.exe was not found in '$InstallPath'."
        }
    }
    if ([string]::IsNullOrWhiteSpace($Preset)) {
        $Preset = Select-Preset
    }

    Write-Host ''
    Write-Host "Target: $InstallPath" -ForegroundColor Cyan
    Write-Host "Setup:  $Preset"

    if ($Preset -eq 'Status') {
        Invoke-Installer 'Status' $InstallPath $null
        exit 0
    }

    Confirm-AscensionClosed
    if ($Preset -eq 'AddonOnly') {
        Install-AuraAddon $InstallPath
        Write-Host 'Open it in-game with /auravis or the AV minimap button.' -ForegroundColor Cyan
        exit 0
    }
    if ($Preset -eq 'UninstallReShade') {
        Invoke-ReShade 'Uninstall' $InstallPath $null
        exit 0
    }
    if ($Preset -eq 'Uninstall') {
        Invoke-Installer 'Uninstall' $InstallPath $null
        exit 0
    }

    $renderer = if ($Preset -eq 'DX11Balanced') { 'DX11' } else { 'DX12' }
    $usesReShade = $Preset -in @('ReShadeBalanced', 'ReShadeCinematic')
    $profileName = if ($Preset -eq 'FrameGeneration' -or $usesReShade) { 'DX12FrameGeneration' } else { $Preset }
    if ($usesReShade) {
        $staffApproval = Read-Host 'Confirm Ascension staff approved unrestricted depth ReShade for your account (Y/N)'
        if ($staffApproval -notmatch '^(?i)y$') { throw 'ReShade installation cancelled because staff approval was not confirmed.' }
    }
    Invoke-Installer 'Install' $InstallPath $renderer
    Invoke-Profile $profileName $InstallPath
    if ($usesReShade) {
        $reShadePreset = if ($Preset -eq 'ReShadeCinematic') { 'Cinematic' } else { 'Balanced' }
        Invoke-ReShade 'Install' $InstallPath $reShadePreset
        Install-AuraAddon $InstallPath
    }

    Write-Host ''
    Write-Host 'Setup completed successfully.' -ForegroundColor Green
    if ($Preset -eq 'FrameGeneration' -or $usesReShade) {
        Write-Host ''
        Write-Host 'One NVIDIA setting remains:' -ForegroundColor Yellow
        Write-Host '  NVIDIA App > Graphics > Program Settings > Ascension.exe'
        Write-Host '  Set Smooth Motion to On.'
        $nvidiaApp = 'C:\Program Files\NVIDIA Corporation\NVIDIA App\CEF\NVIDIA App.exe'
        if (-not $SkipProcessCheck -and (Test-Path -LiteralPath $nvidiaApp)) {
            Start-Process -FilePath $nvidiaApp
        }
    }
    if (-not $SkipProcessCheck) {
        $launch = Read-Host 'Launch Ascension now? (Y/N)'
        if ($launch -match '^(?i)y$') {
            Start-Process -FilePath (Join-Path $InstallPath 'Ascension.exe') -WorkingDirectory $InstallPath
        }
    }
} catch {
    Write-Host ''
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
