param(
    [ValidateSet('Preview', 'Apply')]
    [string]$Action = 'Apply',
    [string]$InstallPath,
    [switch]$Launch,
    [switch]$SkipProcessCheck,
    [switch]$SkipAddonUpdate
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$wrapperScript = Join-Path $scriptRoot 'AscensionDX11.ps1'
$reShadeScript = Join-Path $scriptRoot 'AscensionReShade.ps1'
$addonUpdater = Join-Path $scriptRoot 'Install-AURAVisualUpgrade.ps1'

function Resolve-InstallPath([string]$RequestedPath) {
    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        $candidate = [System.IO.Path]::GetFullPath($RequestedPath).TrimEnd('\')
        if (Test-Path -LiteralPath (Join-Path $candidate 'Ascension.exe') -PathType Leaf) { return $candidate }
        throw "Ascension.exe was not found in '$candidate'."
    }

    $candidates = New-Object System.Collections.ArrayList
    $cachePath = Join-Path $env:APPDATA 'projectascension\Cache\Cache_Data'
    if (Test-Path -LiteralPath $cachePath) {
        foreach ($file in Get-ChildItem -LiteralPath $cachePath -File -ErrorAction SilentlyContinue) {
            try {
                $content = [System.IO.File]::ReadAllText($file.FullName)
                $match = [regex]::Match($content, '"install_root"\s*:\s*"((?:\\.|[^"])*)"')
                if ($match.Success) {
                    $root = ('"' + $match.Groups[1].Value + '"') | ConvertFrom-Json
                    if (Test-Path -LiteralPath (Join-Path $root 'Ascension.exe') -PathType Leaf) {
                        $full = [System.IO.Path]::GetFullPath($root).TrimEnd('\')
                        if (@($candidates | Where-Object { $_ -ieq $full }).Count -eq 0) { [void]$candidates.Add($full) }
                    }
                }
            } catch {}
        }
    }
    if ($candidates.Count -eq 1) { return [string]$candidates[0] }
    if ($candidates.Count -gt 1) {
        Write-Host 'Multiple launcher installations were found; select the intended folder:' -ForegroundColor Yellow
        $candidates | ForEach-Object { Write-Host "  $_" }
    }

    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = 'Select the folder containing Ascension.exe'
    $dialog.ShowNewFolderButton = $false
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { throw 'No Ascension folder was selected.' }
    return Resolve-InstallPath $dialog.SelectedPath
}

function Get-LuaTable([string]$Text, [string]$VariableName) {
    $marker = $VariableName + ' ='
    $markerIndex = $Text.IndexOf($marker, [StringComparison]::Ordinal)
    if ($markerIndex -lt 0) { throw "Saved variable '$VariableName' was not found." }
    $start = $Text.IndexOf('{', $markerIndex)
    if ($start -lt 0) { throw "Saved variable '$VariableName' is malformed." }

    $depth = 0
    $quoted = $false
    $escaped = $false
    for ($index = $start; $index -lt $Text.Length; $index++) {
        $character = $Text[$index]
        if ($quoted) {
            if ($escaped) { $escaped = $false; continue }
            if ($character -eq '\') { $escaped = $true; continue }
            if ($character -eq '"') { $quoted = $false }
            continue
        }
        if ($character -eq '"') { $quoted = $true; continue }
        if ($character -eq '{') { $depth++ }
        if ($character -eq '}') {
            $depth--
            if ($depth -eq 0) { return $Text.Substring($start, $index - $start + 1) }
        }
    }
    throw "Saved variable '$VariableName' has an unterminated table."
}

function Get-LuaString([string]$Table, [string]$Key, [string]$Default) {
    $match = [regex]::Match($Table, '(?m)\["' + [regex]::Escape($Key) + '"\]\s*=\s*"([^"]*)"')
    if ($match.Success) { return $match.Groups[1].Value }
    return $Default
}

function Get-LuaBoolean([string]$Table, [string]$Key, [bool]$Default) {
    $match = [regex]::Match($Table, '(?m)\["' + [regex]::Escape($Key) + '"\]\s*=\s*(true|false)')
    if ($match.Success) { return $match.Groups[1].Value -eq 'true' }
    return $Default
}

function Get-LuaNumber([string]$Table, [string]$Key, [double]$Default) {
    $match = [regex]::Match($Table, '(?m)\["' + [regex]::Escape($Key) + '"\]\s*=\s*(-?[0-9]+(?:\.[0-9]+)?)')
    if ($match.Success) { return [double]::Parse($match.Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture) }
    return $Default
}

function Get-AuraRequest([string]$TargetPath) {
    $accountRoot = Join-Path $TargetPath 'WTF\Account'
    if (-not (Test-Path -LiteralPath $accountRoot)) { throw 'No WTF\Account directory was found. Launch the game and apply AURA settings first.' }
    $requests = @(Get-ChildItem -LiteralPath $accountRoot -Filter 'AURA_VisualUpgrade.lua' -File -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
    if ($requests.Count -eq 0) { throw 'No AURA Visual Upgrade SavedVariables file was found. Apply settings in-game, then log out.' }

    $requestFile = $requests[0]
    $table = Get-LuaTable ([System.IO.File]::ReadAllText($requestFile.FullName)) 'AURAVisualUpgradeRequest'
    return [pscustomobject]@{
        File = $requestFile.FullName
        Profile = Get-LuaString $table 'profile' 'Custom'
        ExternalRequested = Get-LuaBoolean $table 'externalRequested' $false
        Renderer = Get-LuaString $table 'renderer' 'DX12'
        ReShade = Get-LuaString $table 'reshade' 'Off'
        ReShadeMXAO = Get-LuaBoolean $table 'reshadeMXAO' $true
        ReShadeBounce = Get-LuaBoolean $table 'reshadeBounce' $true
        ReShadeBloom = Get-LuaBoolean $table 'reshadeBloom' $true
        ReShadeColor = Get-LuaBoolean $table 'reshadeColor' $true
        ReShadeSharpen = Get-LuaBoolean $table 'reshadeSharpen' $true
        FrameGeneration = Get-LuaBoolean $table 'frameGeneration' $false
        UnrestrictedReShade = Get-LuaBoolean $table 'unrestrictedReShade' (Get-LuaBoolean $table 'staffApproval' $false)
        BaseFrameCap = [int](Get-LuaNumber $table 'baseFrameCap' 80)
        Serial = [int](Get-LuaNumber $table 'serial' 0)
    }
}

function Invoke-CheckedScript([string]$Script, [string[]]$Arguments) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Script @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Companion action failed in '$(Split-Path $Script -Leaf)'." }
}

function Set-KeyValue([string]$Path, [string]$Name, [string]$Value) {
    $text = [System.IO.File]::ReadAllText($Path)
    $pattern = '(?m)^' + [regex]::Escape($Name) + '\s*=.*$'
    if (-not [regex]::IsMatch($text, $pattern)) { throw "Setting '$Name' was not found in '$Path'." }
    $text = [regex]::Replace($text, $pattern, ($Name.PadRight(36) + '= ' + $Value), 1)
    [System.IO.File]::WriteAllText($Path, $text, (New-Object System.Text.UTF8Encoding($false)))
}

function Set-WtfValue([string]$Path, [string]$Name, [string]$Value) {
    $text = [System.IO.File]::ReadAllText($Path)
    $pattern = '(?m)^SET\s+' + [regex]::Escape($Name) + '\s+"[^"]*"\s*$'
    $replacement = 'SET ' + $Name + ' "' + $Value + '"'
    if ([regex]::IsMatch($text, $pattern)) { $text = [regex]::Replace($text, $pattern, $replacement, 1) }
    else { $text = $text.TrimEnd() + [Environment]::NewLine + $replacement + [Environment]::NewLine }
    [System.IO.File]::WriteAllText($Path, $text, (New-Object System.Text.UTF8Encoding($false)))
}

function Set-ReShadeTechniques([string]$TargetPath, [object]$Request) {
    $presetName = if ($Request.ReShade -eq 'Cinematic') { 'Ascension_ReShade_Cinematic.ini' } else { 'Ascension_ReShade_Balanced.ini' }
    $presetPath = Join-Path $TargetPath $presetName
    if (-not (Test-Path -LiteralPath $presetPath -PathType Leaf)) { throw "ReShade preset '$presetPath' was not found." }
    $techniques = @()
    if ($Request.ReShadeMXAO) { $techniques += 'MartysMods_MXAO@MartysMods_MXAO.fx' }
    if ($Request.ReShadeBounce) { $techniques += 'Glamarye_Fast_Effects_with_Fake_GI@Glamayre_Fast_Effects.fx' }
    if ($Request.ReShadeBloom) { $techniques += 'MartysMods_SOLARIS@MartysMods_SOLARIS.fx' }
    if ($Request.ReShadeColor) { $techniques += 'Lightroom@qUINT_lightroom.fx' }
    if ($Request.ReShadeSharpen) { $techniques += 'MartyMods_Sharpen@MartysMods_SHARPEN.fx' }
    $value = $techniques -join ','
    $text = [System.IO.File]::ReadAllText($presetPath)
    $text = [regex]::Replace($text, '(?m)^Techniques=.*$', 'Techniques=' + $value, 1)
    $text = [regex]::Replace($text, '(?m)^TechniqueSorting=.*$', 'TechniqueSorting=' + $value, 1)
    [System.IO.File]::WriteAllText($presetPath, $text, (New-Object System.Text.UTF8Encoding($false)))
}

try {
    $target = Resolve-InstallPath $InstallPath
    $request = Get-AuraRequest $target
    Write-Host 'AURA Visual Upgrade request' -ForegroundColor Cyan
    Write-Host "  Installation:     $target"
    Write-Host "  SavedVariables:   $($request.File)"
    Write-Host "  Request serial:   $($request.Serial)"
    Write-Host "  Profile:          $($request.Profile)"
    Write-Host "  External changes: $(if ($request.ExternalRequested) { 'Requested' } else { 'Not requested' })"
    Write-Host "  Renderer:         $($request.Renderer)"
    Write-Host "  ReShade:          $($request.ReShade)"
    Write-Host "  Unrestricted:     $(if ($request.UnrestrictedReShade) { 'Enabled' } else { 'Disabled' })"
    Write-Host "  Frame generation: $(if ($request.FrameGeneration) { 'Confirmed manually' } else { 'Not confirmed' })"
    Write-Host "  Base frame cap:   $($request.BaseFrameCap)"

    if ($Action -eq 'Preview') { exit 0 }
    if (-not $SkipAddonUpdate -and (Test-Path -LiteralPath $addonUpdater -PathType Leaf)) {
        Write-Host 'Checking GitHub for AURA addon updates...' -ForegroundColor Cyan
        $updateArguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $addonUpdater, '-Action', 'Install', '-InstallPath', $target)
        if ($SkipProcessCheck) { $updateArguments += '-SkipProcessCheck' }
        & powershell.exe @updateArguments
        if ($LASTEXITCODE -ne 0) { Write-Warning 'Addon update failed; continuing with the currently installed version.' }
        Write-Host ''
    }
    if (-not $SkipProcessCheck -and @(Get-Process -Name Ascension -ErrorAction SilentlyContinue).Count -gt 0) { throw 'Close all Ascension clients before running AURA Visual Sync.' }
    if (-not $request.ExternalRequested) {
        Write-Host ''
        Write-Host 'No external graphics changes were requested. Renderer and ReShade were preserved.' -ForegroundColor Green
        if ($Launch) { Start-Process -FilePath (Join-Path $target 'Ascension.exe') -WorkingDirectory $target }
        exit 0
    }
    if ($request.ReShade -ne 'Off' -and -not $request.UnrestrictedReShade) {
        throw 'The selected ReShade profile uses multiplayer depth access. Enable Unrestricted ReShade in AURA or set the ReShade profile to Off. No external changes were made.'
    }

    $d3d9 = Join-Path $target 'd3d9.dll'
    $product = if (Test-Path -LiteralPath $d3d9) { (Get-Item -LiteralPath $d3d9).VersionInfo.ProductName } else { $null }
    if ($product -ne 'dgVoodoo') {
        $renderer = if ($request.ReShade -ne 'Off') { 'DX12' } else { $request.Renderer }
        $arguments = @('-Action', 'Install', '-Renderer', $renderer, '-InstallPath', $target)
        if ($SkipProcessCheck) { $arguments += '-SkipProcessCheck' }
        Invoke-CheckedScript $wrapperScript $arguments
    }

    if ($request.ReShade -eq 'Off') {
        if (Test-Path -LiteralPath (Join-Path $target '.reshade-backup')) {
            $arguments = @('-Action', 'Uninstall', '-InstallPath', $target)
            if ($SkipProcessCheck) { $arguments += '-SkipProcessCheck' }
            Invoke-CheckedScript $reShadeScript $arguments
        }
    } else {
        $preset = if ($request.ReShade -eq 'Cinematic') { 'Cinematic' } else { 'Balanced' }
        $arguments = @('-Action', 'Install', '-Preset', $preset, '-InstallPath', $target)
        if ($request.UnrestrictedReShade) { $arguments += '-EnableUnrestricted' }
        if ($SkipProcessCheck) { $arguments += '-SkipProcessCheck' }
        Invoke-CheckedScript $reShadeScript $arguments
        Set-ReShadeTechniques $target $request
    }

    $outputApi = if ($request.ReShade -ne 'Off' -or $request.Renderer -eq 'DX12') { 'd3d12_fl12_0' } else { 'd3d11_fl11_0' }
    Set-KeyValue (Join-Path $target 'dgVoodoo.conf') 'OutputAPI' $outputApi
    Set-KeyValue (Join-Path $target 'dgVoodoo.conf') 'PresentationModel' 'flip_discard'
    Set-KeyValue (Join-Path $target 'dgVoodoo.conf') 'dgVoodooWatermark' 'false'
    if ($request.ReShade -ne 'Off') { Set-WtfValue (Join-Path $target 'WTF\Config.wtf') 'gxMultisample' '1' }

    Write-Host ''
    Write-Host 'AURA external request applied successfully.' -ForegroundColor Green
    if ($request.FrameGeneration) {
        Write-Host 'Smooth Motion is self-reported and still must be enabled for Ascension.exe in NVIDIA App.' -ForegroundColor Yellow
        $nvidiaApp = 'C:\Program Files\NVIDIA Corporation\NVIDIA App\CEF\NVIDIA App.exe'
        if (Test-Path -LiteralPath $nvidiaApp) { Start-Process -FilePath $nvidiaApp }
    }
    if ($Launch) { Start-Process -FilePath (Join-Path $target 'Ascension.exe') -WorkingDirectory $target }
} catch {
    Write-Host ''
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
