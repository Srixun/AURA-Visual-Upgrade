param(
    [ValidateSet('Install', 'Uninstall', 'Status')]
    [string]$Action = 'Install',
    [string]$InstallPath,
    [ValidateSet('Balanced', 'Cinematic')]
    [string]$Preset = 'Balanced',
    [switch]$SkipProcessCheck,
    [switch]$EnableUnrestricted,
    [switch]$EnableHighDpiOverride,
    [switch]$MigrateLegacyBackup
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

function Restore-OwnedWtfValue([string]$Current, [string]$Backup, [string]$Name, [string]$Expected) {
    $pattern = '(?m)^SET\s+' + [regex]::Escape($Name) + '\s+"([^"]*)"\s*$'
    $currentMatch = [regex]::Match($Current, $pattern)
    if (-not $currentMatch.Success -or $currentMatch.Groups[1].Value -ne $Expected) { return $Current }
    $backupMatch = [regex]::Match($Backup, $pattern)
    if ($backupMatch.Success) { return [regex]::Replace($Current, $pattern, $backupMatch.Value, 1) }
    return [regex]::Replace($Current, $pattern + '\r?\n?', '', 1)
}

function Restore-OwnedDgValue([string]$Current, [string]$Backup, [string]$Name, [string]$Expected) {
    $pattern = '(?m)^' + [regex]::Escape($Name) + '\s*=\s*(.*?)\s*$'
    $currentMatch = [regex]::Match($Current, $pattern)
    if (-not $currentMatch.Success -or $currentMatch.Groups[1].Value -ne $Expected) { return $Current }
    $backupMatch = [regex]::Match($Backup, $pattern)
    if ($backupMatch.Success) { return [regex]::Replace($Current, $pattern, $backupMatch.Value, 1) }
    return $Current
}

function Save-LiveState([string]$TargetPath, [string]$StatePath) {
    New-Item -ItemType Directory -Path $StatePath | Out-Null
    foreach ($name in @('dxgi.dll', 'ReShade.ini', 'Ascension_ReShade_Balanced.ini', 'Ascension_ReShade_Cinematic.ini', 'Ascension_ReShade_RTGI.ini', 'dgVoodoo.conf')) {
        $source = Join-Path $TargetPath $name
        if (Test-Path -LiteralPath $source -PathType Leaf) { Copy-Item -LiteralPath $source -Destination (Join-Path $StatePath $name) }
    }
    $wtf = Join-Path $TargetPath 'WTF\Config.wtf'
    if (Test-Path -LiteralPath $wtf -PathType Leaf) { Copy-Item -LiteralPath $wtf -Destination (Join-Path $StatePath 'Config.wtf') }
    $shaders = Join-Path $TargetPath 'reshade-shaders'
    if (Test-Path -LiteralPath $shaders) { Copy-Item -LiteralPath $shaders -Destination (Join-Path $StatePath 'reshade-shaders') -Recurse }
    $layersPath = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
    $layer = Get-AppCompatLayer $layersPath (Join-Path $TargetPath 'Ascension.exe')
    if ($null -eq $layer) { [System.IO.File]::WriteAllText((Join-Path $StatePath 'Layer.absent'), '') }
    else { [System.IO.File]::WriteAllText((Join-Path $StatePath 'Layer.txt'), $layer) }
}

function Restore-LiveState([string]$TargetPath, [string]$StatePath) {
    foreach ($name in @('dxgi.dll', 'ReShade.ini', 'Ascension_ReShade_Balanced.ini', 'Ascension_ReShade_Cinematic.ini', 'Ascension_ReShade_RTGI.ini', 'dgVoodoo.conf')) {
        $target = Join-Path $TargetPath $name
        if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Force }
        $saved = Join-Path $StatePath $name
        if (Test-Path -LiteralPath $saved -PathType Leaf) { Copy-Item -LiteralPath $saved -Destination $target }
    }
    $wtf = Join-Path $TargetPath 'WTF\Config.wtf'
    $savedWtf = Join-Path $StatePath 'Config.wtf'
    if (Test-Path -LiteralPath $savedWtf) { Copy-Item -LiteralPath $savedWtf -Destination $wtf -Force }
    $shaders = Join-Path $TargetPath 'reshade-shaders'
    if (Test-Path -LiteralPath $shaders) { Remove-Item -LiteralPath $shaders -Recurse -Force }
    $savedShaders = Join-Path $StatePath 'reshade-shaders'
    if (Test-Path -LiteralPath $savedShaders) { Copy-Item -LiteralPath $savedShaders -Destination $shaders -Recurse }
    $layersPath = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
    $gameExe = Join-Path $TargetPath 'Ascension.exe'
    if (Test-Path -LiteralPath (Join-Path $StatePath 'Layer.txt')) {
        if (-not (Test-Path -LiteralPath $layersPath)) { New-Item -Path $layersPath -Force | Out-Null }
        Set-ItemProperty -LiteralPath $layersPath -Name $gameExe -Value ([System.IO.File]::ReadAllText((Join-Path $StatePath 'Layer.txt')))
    } else {
        Remove-ItemProperty -LiteralPath $layersPath -Name $gameExe -ErrorAction SilentlyContinue
    }
}

function Write-ReShadeBackupManifest([string]$BackupPath, [bool]$Migrated = $false) {
    $files = @()
    foreach ($file in Get-ChildItem -LiteralPath $BackupPath -File -Recurse | Where-Object { $_.Name -ne 'manifest.json' }) {
        $relative = $file.FullName.Substring($BackupPath.Length).TrimStart('\')
        $files += [pscustomobject]@{ Path = $relative; Sha256 = Get-Hash $file.FullName }
    }
    $manifest = [pscustomobject]@{ FormatVersion = 1; CreatedUtc = [DateTime]::UtcNow.ToString('o'); Migrated = $Migrated; Files = $files }
    [System.IO.File]::WriteAllText((Join-Path $BackupPath 'manifest.json'), ($manifest | ConvertTo-Json -Depth 5), (New-Object System.Text.UTF8Encoding($false)))
}

function Assert-ReShadeBackup([string]$BackupPath) {
    $manifestPath = Join-Path $BackupPath 'manifest.json'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        if (-not $MigrateLegacyBackup) {
            throw "Legacy ReShade backup '$BackupPath' has no completion manifest. Review its contents, then rerun with -MigrateLegacyBackup to accept it explicitly."
        }
        $hasDgConfig = Test-Path -LiteralPath (Join-Path $BackupPath 'dgVoodoo.conf') -PathType Leaf
        $hasWtfConfig = Test-Path -LiteralPath (Join-Path $BackupPath 'Config.wtf') -PathType Leaf
        if (-not $hasDgConfig -or -not $hasWtfConfig) {
            throw "ReShade backup '$BackupPath' is incomplete and has no completion manifest."
        }
        Write-Warning 'Migrating a verified legacy ReShade backup to the manifest format.'
        $legacyLayerBackup = Join-Path $BackupPath 'HighDpiLayer.txt'
        $legacyLayerAbsent = Join-Path $BackupPath 'HighDpiLayer.absent'
        $layerManaged = Join-Path $BackupPath 'HighDpiLayer.managed'
        if ((Test-Path -LiteralPath $legacyLayerBackup -PathType Leaf) -or (Test-Path -LiteralPath $legacyLayerAbsent -PathType Leaf)) {
            [System.IO.File]::WriteAllText($layerManaged, '', (New-Object System.Text.UTF8Encoding($false)))
        }
        Write-ReShadeBackupManifest $BackupPath $true
    }
    $manifest = [System.IO.File]::ReadAllText($manifestPath) | ConvertFrom-Json
    if ([int]$manifest.FormatVersion -ne 1) { throw "Unsupported ReShade backup format in '$BackupPath'." }
    foreach ($entry in @($manifest.Files)) {
        $file = Join-Path $BackupPath ([string]$entry.Path)
        if (-not (Test-Path -LiteralPath $file -PathType Leaf) -or (Get-Hash $file) -ne ([string]$entry.Sha256).ToUpperInvariant()) {
            throw "ReShade backup file '$file' failed verification."
        }
    }
}

function New-ReShadeBackup([string]$TargetPath, [string]$BackupPath) {
    $staging = $BackupPath + '.staging-' + [guid]::NewGuid().ToString('N')
    try {
        New-Item -ItemType Directory -Path $staging | Out-Null
        foreach ($name in @('dxgi.dll', 'ReShade.ini', 'Ascension_ReShade_Balanced.ini', 'Ascension_ReShade_Cinematic.ini', 'Ascension_ReShade_RTGI.ini', 'dgVoodoo.conf')) {
            $source = Join-Path $TargetPath $name
            if (Test-Path -LiteralPath $source -PathType Leaf) { Copy-Item -LiteralPath $source -Destination (Join-Path $staging $name) }
        }
        $wtf = Join-Path $TargetPath 'WTF\Config.wtf'
        if (Test-Path -LiteralPath $wtf -PathType Leaf) { Copy-Item -LiteralPath $wtf -Destination (Join-Path $staging 'Config.wtf') }
        $shaderDir = Join-Path $TargetPath 'reshade-shaders'
        if (Test-Path -LiteralPath $shaderDir) { Copy-Item -LiteralPath $shaderDir -Destination (Join-Path $staging 'reshade-shaders') -Recurse }
        Write-ReShadeBackupManifest $staging
        Assert-ReShadeBackup $staging
        Move-Item -LiteralPath $staging -Destination $BackupPath
    } finally {
        if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath $staging -Recurse -Force }
    }
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
    if (-not $EnableUnrestricted) {
        throw 'The included ReShade presets require unrestricted multiplayer depth access for MXAO and bounce lighting. Rerun with -EnableUnrestricted if you accept the server-policy and anti-cheat risk.'
    }
    $dgPath = Join-Path $TargetPath 'd3d9.dll'
    if (-not (Test-Path -LiteralPath $dgPath) -or (Get-Item -LiteralPath $dgPath).VersionInfo.ProductName -ne 'dgVoodoo') {
        throw 'Install the dgVoodoo DX12 wrapper before installing ReShade.'
    }

    $backupPath = Join-Path $TargetPath '.reshade-backup'
    if (-not (Test-Path -LiteralPath $backupPath)) {
        New-ReShadeBackup $TargetPath $backupPath
    } else { Assert-ReShadeBackup $backupPath }

    $layersPath = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
    $gameExe = Join-Path $TargetPath 'Ascension.exe'
    $layerBackup = Join-Path $backupPath 'HighDpiLayer.txt'
    $layerAbsent = Join-Path $backupPath 'HighDpiLayer.absent'
    $layerManaged = Join-Path $backupPath 'HighDpiLayer.managed'
    if ($EnableHighDpiOverride -and -not (Test-Path -LiteralPath $layerBackup) -and -not (Test-Path -LiteralPath $layerAbsent)) {
        $existingLayer = Get-AppCompatLayer $layersPath $gameExe
        if ($null -eq $existingLayer) {
            [System.IO.File]::WriteAllText($layerAbsent, '', (New-Object System.Text.UTF8Encoding($false)))
        } else {
            [System.IO.File]::WriteAllText($layerBackup, $existingLayer, (New-Object System.Text.UTF8Encoding($false)))
        }
        [System.IO.File]::WriteAllText($layerManaged, '', (New-Object System.Text.UTF8Encoding($false)))
    }

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('AscensionReShade-' + [guid]::NewGuid().ToString('N'))
    $transactionPath = Join-Path $tempRoot 'live-state'
    $transactionReady = $false
    try {
        New-Item -ItemType Directory -Path $tempRoot | Out-Null
        Save-LiveState $TargetPath $transactionPath
        $transactionReady = $true
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $setupPath = Join-Path $tempRoot 'ReShadeSetup.exe'
        Write-Host 'Downloading and verifying ReShade 6.7.3 unrestricted build...'
        Download-Verified $reShadeUrl $reShadeHash $setupPath
        $signature = Get-AuthenticodeSignature -LiteralPath $setupPath
        if ($signature.Status -ne [System.Management.Automation.SignatureStatus]::Valid -or $null -eq $signature.SignerCertificate -or $signature.SignerCertificate.Thumbprint -ne $reShadeThumbprint) {
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
        [System.IO.File]::WriteAllText($wtfPath, $wtfConfig, (New-Object System.Text.UTF8Encoding($false)))

        if ($EnableHighDpiOverride) {
            if (-not (Test-Path -LiteralPath $layersPath)) { New-Item -Path $layersPath -Force | Out-Null }
            $currentLayer = Get-AppCompatLayer $layersPath $gameExe
            $newLayer = if ([string]::IsNullOrWhiteSpace($currentLayer)) { '~ HIGHDPIAWARE' } elseif ($currentLayer -notmatch 'HIGHDPIAWARE') { ($currentLayer.Trim() + ' HIGHDPIAWARE') } else { $currentLayer }
            Set-ItemProperty -LiteralPath $layersPath -Name $gameExe -Value $newLayer
        }

        Remove-Item -LiteralPath (Join-Path $TargetPath 'Ascension_ReShade_RTGI.ini') -Force -ErrorAction SilentlyContinue
        Write-ReShadeConfiguration $TargetPath $SelectedPreset
        if (-not (Test-Path -LiteralPath $runtimePath -PathType Leaf) -or (Get-Hash $runtimePath) -ne $reShadeRuntimeHash) { throw 'The installed ReShade runtime failed its pinned hash verification.' }

        Write-Host ''
        Write-Host "ReShade installed successfully with the $SelectedPreset preset." -ForegroundColor Green
        Write-Host 'Renderer chain: D3D9 -> dgVoodoo -> D3D12 -> ReShade'
        Write-Host 'Home: ReShade menu   Scroll Lock: toggle effects'
    } catch {
        if ($transactionReady) {
            try { Restore-LiveState $TargetPath $transactionPath; Write-Warning 'ReShade installation failed; the previous live state was restored.' }
            catch { Write-Warning "ReShade rollback also failed: $($_.Exception.Message)" }
        }
        throw
    } finally {
        if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
    }
}

function Uninstall-ReShade([string]$TargetPath) {
    Assert-Closed
    $backupPath = Join-Path $TargetPath '.reshade-backup'
    if (-not (Test-Path -LiteralPath $backupPath)) { throw 'No ReShade backup was found.' }
    Assert-ReShadeBackup $backupPath

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
    $dgConfigPath = Join-Path $TargetPath 'dgVoodoo.conf'
    $dgBackupPath = Join-Path $backupPath 'dgVoodoo.conf'
    if ((Test-Path -LiteralPath $dgConfigPath) -and (Test-Path -LiteralPath $dgBackupPath)) {
        $current = [System.IO.File]::ReadAllText($dgConfigPath)
        $backup = [System.IO.File]::ReadAllText($dgBackupPath)
        $current = Restore-OwnedDgValue $current $backup 'OutputAPI' 'd3d12_fl12_0'
        $current = Restore-OwnedDgValue $current $backup 'PresentationModel' 'flip_discard'
        $current = Restore-OwnedDgValue $current $backup 'dgVoodooWatermark' 'false'
        [System.IO.File]::WriteAllText($dgConfigPath, $current, (New-Object System.Text.UTF8Encoding($false)))
    }
    $wtfPath = Join-Path $TargetPath 'WTF\Config.wtf'
    $wtfBackupPath = Join-Path $backupPath 'Config.wtf'
    if ((Test-Path -LiteralPath $wtfPath) -and (Test-Path -LiteralPath $wtfBackupPath)) {
        $current = [System.IO.File]::ReadAllText($wtfPath)
        $backup = [System.IO.File]::ReadAllText($wtfBackupPath)
        $current = Restore-OwnedWtfValue $current $backup 'gxMultisample' '1'
        [System.IO.File]::WriteAllText($wtfPath, $current, (New-Object System.Text.UTF8Encoding($false)))
    }

    $layersPath = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
    $gameExe = Join-Path $TargetPath 'Ascension.exe'
    $layerBackup = Join-Path $backupPath 'HighDpiLayer.txt'
    if ((Test-Path -LiteralPath (Join-Path $backupPath 'HighDpiLayer.managed')) -and (Test-Path -LiteralPath $layerBackup)) {
        Set-ItemProperty -LiteralPath $layersPath -Name $gameExe -Value ([System.IO.File]::ReadAllText($layerBackup))
    } elseif ((Test-Path -LiteralPath (Join-Path $backupPath 'HighDpiLayer.managed')) -and (Test-Path -LiteralPath (Join-Path $backupPath 'HighDpiLayer.absent'))) {
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
