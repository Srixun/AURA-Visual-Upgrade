param(
    [ValidateSet('Install', 'Uninstall', 'Status')]
    [string]$Action = 'Install',
    [string]$InstallPath,
    [ValidateSet('Balanced', 'Cinematic')]
    [string]$Preset = 'Balanced',
    [switch]$SkipProcessCheck
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$reShadeUrl = 'https://reshade.me/downloads/ReShade_Setup_6.7.3_Addon.exe'
$reShadeHash = 'C78DB69BD127E98054BD496FB422655F4A1CC664E28F8D12CE9835B2647BC571'
$reShadeThumbprint = '589690208A5E52FB96980C4A6698F50ACD47C49F'
$reShadeRuntimeHash = 'B0A0FA7472D9A153816EDCF7606902EB9C8F262E6100FC9973EC495634DCA2C2'
$packages = @(
    [pscustomobject]@{ Name='official'; Url='https://github.com/crosire/reshade-shaders/archive/6db142b4b1a05c764222e5b0bd9a644b7ccfe1dc.zip'; Hash='12D082C8AB1DBCB5E221E1B6116A0343F3182EE517F09BB966B117ACC7635312' },
    [pscustomobject]@{ Name='immerse'; Url='https://github.com/martymcmodding/iMMERSE/archive/f57d3afa1ebe5d1fd6152d4f6fb9a2e75bd1d1cb.zip'; Hash='F9B0C851C4F184743561AA90D1CE503260CF1E7B5C0E8C34AD5CDCEE3C151A6A' },
    [pscustomobject]@{ Name='quint'; Url='https://github.com/martymcmodding/qUINT/archive/98fed77b26669202027f575a6d8f590426c21ebd.zip'; Hash='2F6FF2F5DD39FF400C07ECBBFD1156604459F44D9028D07FA6D98B84D4CFBFA9' },
    [pscustomobject]@{ Name='glamarye'; Url='https://github.com/rj200/Glamarye_Fast_Effects_for_ReShade/archive/9dd9b826fa2cbea818ef1bc487e5f2e7f427c750.zip'; Hash='8843A74F899585CD1B9B1EC8193B7CC08558E95F292955F649AD0EC05194CEF9' }
)

function Get-Hash([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Get-AppCompatLayer([string]$RegistryPath, [string]$ExecutablePath) {
    $item = Get-ItemProperty -LiteralPath $RegistryPath -ErrorAction SilentlyContinue
    if ($null -eq $item) { return $null }
    $property = $item.PSObject.Properties[$ExecutablePath]
    if ($null -eq $property) { return $null }
    return [string]$property.Value
}

function Assert-Closed {
    if (-not $SkipProcessCheck -and @(Get-Process -Name Ascension -ErrorAction SilentlyContinue).Count -gt 0) {
        throw 'Close all running Ascension clients before changing ReShade.'
    }
}

function Resolve-GamePath([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) {
        Add-Type -AssemblyName System.Windows.Forms
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $dialog.Description = 'Select the wrapped folder containing Ascension.exe'
        $dialog.ShowNewFolderButton = $false
        if (Test-Path -LiteralPath 'D:\Ascensiontest') { $dialog.SelectedPath = 'D:\Ascensiontest' }
        if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { throw 'No Ascension folder was selected.' }
        $Path = $dialog.SelectedPath
    }
    $Path = [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
    if (-not (Test-Path -LiteralPath (Join-Path $Path 'Ascension.exe') -PathType Leaf)) {
        throw "Ascension.exe was not found in '$Path'."
    }
    return $Path
}

function Download-Verified([string]$Url, [string]$Hash, [string]$Destination) {
    Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing
    $actual = Get-Hash $Destination
    if ($actual -ne $Hash) { throw "Downloaded file failed verification. Expected $Hash, received $actual." }
}

function Set-WtfValue([string]$Text, [string]$Name, [string]$Value) {
    $pattern = '(?m)^SET\s+' + [regex]::Escape($Name) + '\s+"[^"]*"\s*$'
    $replacement = 'SET ' + $Name + ' "' + $Value + '"'
    if ([regex]::IsMatch($Text, $pattern)) { return [regex]::Replace($Text, $pattern, $replacement, 1) }
    return $Text.TrimEnd() + [Environment]::NewLine + $replacement + [Environment]::NewLine
}

function Set-DgValue([string]$Text, [string]$Name, [string]$Value) {
    $pattern = '(?m)^' + [regex]::Escape($Name) + '\s*=.*$'
    if (-not [regex]::IsMatch($Text, $pattern)) { throw "dgVoodoo setting '$Name' was not found." }
    return [regex]::Replace($Text, $pattern, ($Name.PadRight(36) + '= ' + $Value), 1)
}

function Copy-TreeContents([string]$Source, [string]$Destination) {
    if (-not (Test-Path -LiteralPath $Source)) { return }
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    Copy-Item -Path (Join-Path $Source '*') -Destination $Destination -Recurse -Force
}

function Write-ReShadeConfiguration([string]$TargetPath, [string]$SelectedPreset) {
    $balancedPreset = @'
Techniques=MartysMods_MXAO@MartysMods_MXAO.fx,Glamarye_Fast_Effects_with_Fake_GI@Glamayre_Fast_Effects.fx,MartysMods_SOLARIS@MartysMods_SOLARIS.fx,Lightroom@qUINT_lightroom.fx,MartyMods_Sharpen@MartysMods_SHARPEN.fx
TechniqueSorting=MartysMods_MXAO@MartysMods_MXAO.fx,Glamarye_Fast_Effects_with_Fake_GI@Glamayre_Fast_Effects.fx,MartysMods_SOLARIS@MartysMods_SOLARIS.fx,Lightroom@qUINT_lightroom.fx,MartyMods_Sharpen@MartysMods_SHARPEN.fx

[MartysMods_MXAO.fx]
MXAO_GLOBAL_SAMPLE_QUALITY_PRESET=1
SHADING_RATE=1
MXAO_SAMPLE_RADIUS=2.000000
MXAO_WORLDSPACE_ENABLE=0
MXAO_SSAO_AMOUNT=0.650000
MXAO_FADE_DEPTH=0.350000
MXAO_FILTER_SIZE=1
MXAO_DEBUG_VIEW_ENABLE=0

[Glamarye_Fast_Effects.fx]
fxaa_enabled=0
sharp_enabled=0
ao_enabled=0
dof_enabled=0
depth_detect=0
sky_detect=0
gi_strength=0.300000
gi_saturation=0.300000
gi_contrast=0.150000
gi_use_depth=1
gi_ao_strength=0.200000
gi_local_ao_strength=0.250000
bounce_multiplier=0.500000
gi_shape=0.040000
gi_dof_safe_mode=0
gi_max_distance=0.700000

[MartysMods_SOLARIS.fx]
HDR_EXPOSURE=0.000000
HDR_WHITEPOINT=7.000000
HDR_BLOOM_INT=0.180000
HDR_BLOOM_RADIUS=0.700000
HDR_BLOOM_HAZYNESS=0.600000
BLOOM_HQ_DOWNSAMPLING=0
BLOOM_DEPTH_MASK=1
BLOOM_DEPTH_MASK_STRENGTH=0.450000

[qUINT_lightroom.fx]
LIGHTROOM_GLOBAL_CONTRAST=0.060000
LIGHTROOM_GLOBAL_SATURATION=0.020000
LIGHTROOM_GLOBAL_VIBRANCE=0.080000
LIGHTROOM_GLOBAL_SHADOWS_CURVE=0.030000
LIGHTROOM_GLOBAL_HIGHLIGHTS_CURVE=-0.020000
LIGHTROOM_ENABLE_VIGNETTE=0

[MartysMods_SHARPEN.fx]
SHARP_AMT=0.350000
QUALITY=0
'@

    $cinematicPreset = @'
Techniques=MartysMods_MXAO@MartysMods_MXAO.fx,Glamarye_Fast_Effects_with_Fake_GI@Glamayre_Fast_Effects.fx,MartysMods_SOLARIS@MartysMods_SOLARIS.fx,Lightroom@qUINT_lightroom.fx,MartyMods_Sharpen@MartysMods_SHARPEN.fx
TechniqueSorting=MartysMods_MXAO@MartysMods_MXAO.fx,Glamarye_Fast_Effects_with_Fake_GI@Glamayre_Fast_Effects.fx,MartysMods_SOLARIS@MartysMods_SOLARIS.fx,Lightroom@qUINT_lightroom.fx,MartyMods_Sharpen@MartysMods_SHARPEN.fx

[MartysMods_MXAO.fx]
MXAO_GLOBAL_SAMPLE_QUALITY_PRESET=2
SHADING_RATE=0
MXAO_SAMPLE_RADIUS=2.500000
MXAO_WORLDSPACE_ENABLE=0
MXAO_SSAO_AMOUNT=0.750000
MXAO_FADE_DEPTH=0.400000
MXAO_FILTER_SIZE=2
MXAO_DEBUG_VIEW_ENABLE=0

[Glamarye_Fast_Effects.fx]
fxaa_enabled=0
sharp_enabled=0
ao_enabled=0
dof_enabled=0
depth_detect=0
sky_detect=0
gi_strength=0.450000
gi_saturation=0.400000
gi_contrast=0.200000
gi_use_depth=1
gi_ao_strength=0.300000
gi_local_ao_strength=0.350000
bounce_multiplier=0.750000
gi_shape=0.050000
gi_dof_safe_mode=0
gi_max_distance=0.800000

[MartysMods_SOLARIS.fx]
HDR_BLOOM_INT=0.220000
HDR_BLOOM_RADIUS=0.750000
HDR_BLOOM_HAZYNESS=0.650000
BLOOM_HQ_DOWNSAMPLING=0
BLOOM_DEPTH_MASK=1
BLOOM_DEPTH_MASK_STRENGTH=0.450000

[qUINT_lightroom.fx]
LIGHTROOM_GLOBAL_CONTRAST=0.080000
LIGHTROOM_GLOBAL_SATURATION=0.030000
LIGHTROOM_GLOBAL_VIBRANCE=0.100000
LIGHTROOM_GLOBAL_SHADOWS_CURVE=0.040000
LIGHTROOM_GLOBAL_HIGHLIGHTS_CURVE=-0.030000
LIGHTROOM_ENABLE_VIGNETTE=0

[MartysMods_SHARPEN.fx]
SHARP_AMT=0.400000
QUALITY=1
'@

    [System.IO.File]::WriteAllText((Join-Path $TargetPath 'Ascension_ReShade_Balanced.ini'), $balancedPreset, (New-Object System.Text.UTF8Encoding($false)))
    [System.IO.File]::WriteAllText((Join-Path $TargetPath 'Ascension_ReShade_Cinematic.ini'), $cinematicPreset, (New-Object System.Text.UTF8Encoding($false)))

    $presetFile = if ($SelectedPreset -eq 'Cinematic') { 'Ascension_ReShade_Cinematic.ini' } else { 'Ascension_ReShade_Balanced.ini' }
    $config = @"
[GENERAL]
EffectSearchPaths=.\reshade-shaders\Shaders\**
TextureSearchPaths=.\reshade-shaders\Textures\**
PresetPath=.\$presetFile
PerformanceMode=1
PreprocessorDefinitions=RESHADE_DEPTH_LINEARIZATION_FAR_PLANE=1000.0,RESHADE_DEPTH_INPUT_IS_REVERSED=0,RESHADE_DEPTH_INPUT_IS_UPSIDE_DOWN=0,RESHADE_DEPTH_INPUT_IS_LOGARITHMIC=0

[INPUT]
KeyOverlay=36,0,0,0
KeyEffects=145,0,0,0

[OVERLAY]
TutorialProgress=4
ShowForceLoadEffectsButton=1
"@
    [System.IO.File]::WriteAllText((Join-Path $TargetPath 'ReShade.ini'), $config, (New-Object System.Text.UTF8Encoding($false)))
}

function Install-ReShade([string]$TargetPath, [string]$SelectedPreset) {
    Assert-Closed
    $dgPath = Join-Path $TargetPath 'd3d9.dll'
    if (-not (Test-Path -LiteralPath $dgPath) -or (Get-Item -LiteralPath $dgPath).VersionInfo.ProductName -ne 'dgVoodoo') {
        throw 'Install the dgVoodoo DX12 wrapper before installing ReShade.'
    }

    $backupPath = Join-Path $TargetPath '.reshade-backup'
    if (-not (Test-Path -LiteralPath $backupPath)) {
        New-Item -ItemType Directory -Path $backupPath | Out-Null
        foreach ($name in @('dxgi.dll', 'ReShade.ini', 'Ascension_ReShade_Balanced.ini', 'Ascension_ReShade_Cinematic.ini', 'Ascension_ReShade_RTGI.ini', 'dgVoodoo.conf')) {
            $source = Join-Path $TargetPath $name
            if (Test-Path -LiteralPath $source -PathType Leaf) { Copy-Item -LiteralPath $source -Destination (Join-Path $backupPath $name) }
        }
        $wtf = Join-Path $TargetPath 'WTF\Config.wtf'
        if (Test-Path -LiteralPath $wtf) { Copy-Item -LiteralPath $wtf -Destination (Join-Path $backupPath 'Config.wtf') }
        $shaderDir = Join-Path $TargetPath 'reshade-shaders'
        if (Test-Path -LiteralPath $shaderDir) { Copy-Item -LiteralPath $shaderDir -Destination (Join-Path $backupPath 'reshade-shaders') -Recurse }

    }

    $layersPath = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
    $gameExe = Join-Path $TargetPath 'Ascension.exe'
    $layerBackup = Join-Path $backupPath 'HighDpiLayer.txt'
    $layerAbsent = Join-Path $backupPath 'HighDpiLayer.absent'
    if (-not (Test-Path -LiteralPath $layerBackup) -and -not (Test-Path -LiteralPath $layerAbsent)) {
        $existingLayer = Get-AppCompatLayer $layersPath $gameExe
        if ($null -eq $existingLayer) {
            [System.IO.File]::WriteAllText($layerAbsent, '', (New-Object System.Text.UTF8Encoding($false)))
        } else {
            [System.IO.File]::WriteAllText($layerBackup, $existingLayer, (New-Object System.Text.UTF8Encoding($false)))
        }
    }

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('AscensionReShade-' + [guid]::NewGuid().ToString('N'))
    try {
        New-Item -ItemType Directory -Path $tempRoot | Out-Null
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $setupPath = Join-Path $tempRoot 'ReShadeSetup.exe'
        Write-Host 'Downloading and verifying ReShade 6.7.3 unrestricted build...'
        Download-Verified $reShadeUrl $reShadeHash $setupPath
        $signature = Get-AuthenticodeSignature -LiteralPath $setupPath
        if ($null -eq $signature.SignerCertificate -or $signature.SignerCertificate.Thumbprint -ne $reShadeThumbprint) {
            throw 'ReShade setup signing certificate did not match the official publisher thumbprint.'
        }

        $roots = @{}
        foreach ($package in $packages) {
            Write-Host "Downloading shader package: $($package.Name)..."
            $archive = Join-Path $tempRoot ($package.Name + '.zip')
            $extract = Join-Path $tempRoot $package.Name
            Download-Verified $package.Url $package.Hash $archive
            Expand-Archive -LiteralPath $archive -DestinationPath $extract -Force
            $roots[$package.Name] = (Get-ChildItem -LiteralPath $extract -Directory | Select-Object -First 1).FullName
        }

        $runtimePath = Join-Path $TargetPath 'dxgi.dll'
        if ((Test-Path -LiteralPath $runtimePath) -and (Get-Hash $runtimePath) -eq $reShadeRuntimeHash) {
            Write-Host 'Existing ReShade 6.7.3 runtime verified.'
        } else {
            $setupArgs = '"' + $gameExe + '" --api dxgi --headless'
            if ((Test-Path -LiteralPath $runtimePath) -and (Get-Item -LiteralPath $runtimePath).VersionInfo.ProductName -eq 'ReShade') {
                $setupArgs += ' --state update'
            }
            $process = Start-Process -FilePath $setupPath -ArgumentList $setupArgs -Wait -PassThru
            if ($process.ExitCode -ne 0) { throw "ReShade setup failed with exit code $($process.ExitCode)." }
        }

        $shaderRoot = Join-Path $TargetPath 'reshade-shaders'
        if (Test-Path -LiteralPath $shaderRoot) { Remove-Item -LiteralPath $shaderRoot -Recurse -Force }
        $shaderDestination = Join-Path $shaderRoot 'Shaders'
        $textureDestination = Join-Path $shaderRoot 'Textures'
        New-Item -ItemType Directory -Path $shaderDestination, $textureDestination -Force | Out-Null

        $officialShaders = Join-Path $roots.official 'Shaders'
        foreach ($name in @('ReShade.fxh', 'ReShadeUI.fxh', 'DisplayDepth.fx')) {
            Copy-Item -LiteralPath (Join-Path $officialShaders $name) -Destination $shaderDestination
        }

        $immerseShaders = Join-Path $roots.immerse 'Shaders'
        foreach ($name in @('MartysMods_MXAO.fx', 'MartysMods_SOLARIS.fx', 'MartysMods_SHARPEN.fx')) {
            Copy-Item -LiteralPath (Join-Path $immerseShaders $name) -Destination $shaderDestination
        }
        Copy-TreeContents (Join-Path $immerseShaders 'MartysMods') (Join-Path $shaderDestination 'MartysMods')
        Copy-TreeContents (Join-Path $roots.immerse 'Textures') $textureDestination

        $quintShaders = Join-Path $roots.quint 'Shaders'
        foreach ($name in @('qUINT_lightroom.fx', 'qUINT_bloom.fx', 'qUINT_common.fxh')) {
            Copy-Item -LiteralPath (Join-Path $quintShaders $name) -Destination $shaderDestination
        }
        Copy-TreeContents (Join-Path $roots.quint 'Textures') $textureDestination

        Copy-Item -LiteralPath (Join-Path $roots.glamarye 'Shaders\Glamayre_Fast_Effects.fx') -Destination $shaderDestination

        $dgConfigPath = Join-Path $TargetPath 'dgVoodoo.conf'
        $dgConfig = [System.IO.File]::ReadAllText($dgConfigPath)
        $dgConfig = Set-DgValue $dgConfig 'OutputAPI' 'd3d12_fl12_0'
        $dgConfig = Set-DgValue $dgConfig 'PresentationModel' 'flip_discard'
        $dgConfig = Set-DgValue $dgConfig 'dgVoodooWatermark' 'false'
        [System.IO.File]::WriteAllText($dgConfigPath, $dgConfig, (New-Object System.Text.UTF8Encoding($false)))

        $wtfPath = Join-Path $TargetPath 'WTF\Config.wtf'
        $wtfConfig = [System.IO.File]::ReadAllText($wtfPath)
        $wtfConfig = Set-WtfValue $wtfConfig 'gxMultisample' '1'
        $wtfConfig = Set-WtfValue $wtfConfig 'maxFPS' '80'
        [System.IO.File]::WriteAllText($wtfPath, $wtfConfig, (New-Object System.Text.UTF8Encoding($false)))

        if (-not (Test-Path -LiteralPath $layersPath)) { New-Item -Path $layersPath -Force | Out-Null }
        $currentLayer = Get-AppCompatLayer $layersPath $gameExe
        $newLayer = if ([string]::IsNullOrWhiteSpace($currentLayer)) { '~ HIGHDPIAWARE' } elseif ($currentLayer -notmatch 'HIGHDPIAWARE') { ($currentLayer.Trim() + ' HIGHDPIAWARE') } else { $currentLayer }
        Set-ItemProperty -LiteralPath $layersPath -Name $gameExe -Value $newLayer

        Remove-Item -LiteralPath (Join-Path $TargetPath 'Ascension_ReShade_RTGI.ini') -Force -ErrorAction SilentlyContinue
        Write-ReShadeConfiguration $TargetPath $SelectedPreset
        if (-not (Test-Path -LiteralPath $runtimePath -PathType Leaf)) { throw 'ReShade did not install dxgi.dll.' }

        Write-Host ''
        Write-Host "ReShade installed successfully with the $SelectedPreset preset." -ForegroundColor Green
        Write-Host 'Renderer chain: D3D9 -> dgVoodoo -> D3D12 -> ReShade'
        Write-Host 'Home: ReShade menu   Scroll Lock: toggle effects'
    } finally {
        if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
    }
}

function Uninstall-ReShade([string]$TargetPath) {
    Assert-Closed
    $backupPath = Join-Path $TargetPath '.reshade-backup'
    if (-not (Test-Path -LiteralPath $backupPath)) { throw 'No ReShade backup was found.' }

    foreach ($name in @('dxgi.dll', 'ReShade.ini', 'ReShade.log', 'Ascension_ReShade_Balanced.ini', 'Ascension_ReShade_Cinematic.ini', 'Ascension_ReShade_RTGI.ini')) {
        $target = Join-Path $TargetPath $name
        if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Force }
        $backup = Join-Path $backupPath $name
        if (Test-Path -LiteralPath $backup -PathType Leaf) { Copy-Item -LiteralPath $backup -Destination $target }
    }
    $shaderTarget = Join-Path $TargetPath 'reshade-shaders'
    if (Test-Path -LiteralPath $shaderTarget) { Remove-Item -LiteralPath $shaderTarget -Recurse -Force }
    $shaderBackup = Join-Path $backupPath 'reshade-shaders'
    if (Test-Path -LiteralPath $shaderBackup) { Copy-Item -LiteralPath $shaderBackup -Destination $shaderTarget -Recurse }
    foreach ($pair in @(@('dgVoodoo.conf','dgVoodoo.conf'), @('Config.wtf','WTF\Config.wtf'))) {
        $source = Join-Path $backupPath $pair[0]
        if (Test-Path -LiteralPath $source) { Copy-Item -LiteralPath $source -Destination (Join-Path $TargetPath $pair[1]) -Force }
    }

    $dgConfigPath = Join-Path $TargetPath 'dgVoodoo.conf'
    if (Test-Path -LiteralPath $dgConfigPath -PathType Leaf) {
        $dgConfig = [System.IO.File]::ReadAllText($dgConfigPath)
        $dgConfig = Set-DgValue $dgConfig 'dgVoodooWatermark' 'false'
        [System.IO.File]::WriteAllText($dgConfigPath, $dgConfig, (New-Object System.Text.UTF8Encoding($false)))
    }

    $layersPath = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
    $gameExe = Join-Path $TargetPath 'Ascension.exe'
    $layerBackup = Join-Path $backupPath 'HighDpiLayer.txt'
    if (Test-Path -LiteralPath $layerBackup) {
        Set-ItemProperty -LiteralPath $layersPath -Name $gameExe -Value ([System.IO.File]::ReadAllText($layerBackup))
    } elseif (Test-Path -LiteralPath (Join-Path $backupPath 'HighDpiLayer.absent')) {
        Remove-ItemProperty -LiteralPath $layersPath -Name $gameExe -ErrorAction SilentlyContinue
    }

    $archive = Join-Path $TargetPath ('.reshade-backup.restored-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    Move-Item -LiteralPath $backupPath -Destination $archive
    Write-Host 'ReShade removed and previous graphics settings restored.' -ForegroundColor Green
}

function Show-Status([string]$TargetPath) {
    $runtime = Join-Path $TargetPath 'dxgi.dll'
    [pscustomobject]@{
        Installed = Test-Path -LiteralPath $runtime
        Runtime = if (Test-Path -LiteralPath $runtime) { (Get-Item -LiteralPath $runtime).VersionInfo.FileVersion } else { $null }
        Preset = if (Test-Path -LiteralPath (Join-Path $TargetPath 'ReShade.ini')) { (Get-Content -LiteralPath (Join-Path $TargetPath 'ReShade.ini') | Where-Object { $_ -like 'PresetPath=*' }) -replace '^PresetPath=', '' } else { $null }
        Backup = Test-Path -LiteralPath (Join-Path $TargetPath '.reshade-backup')
    } | Format-List
}

try {
    $target = Resolve-GamePath $InstallPath
    switch ($Action) {
        'Install' { Install-ReShade $target $Preset }
        'Uninstall' { Uninstall-ReShade $target }
        'Status' { Show-Status $target }
    }
} catch {
    Write-Host ''
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
