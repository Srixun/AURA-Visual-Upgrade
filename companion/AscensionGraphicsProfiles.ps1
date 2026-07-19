param(
    [ValidateSet('DX11Balanced', 'DX12Balanced', 'DX12Performance', 'DX12Quality', 'DX12FrameGeneration', 'Restore')]
    [string]$Profile,
    [string]$InstallPath,
    [switch]$SkipProcessCheck
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Select-AscensionFolder {
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = 'Select the wrapped folder containing Ascension.exe'
    $dialog.ShowNewFolderButton = $false
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        throw 'No Ascension folder was selected.'
    }
    return $dialog.SelectedPath
}

function Select-Profile {
    Write-Host 'Select a graphics profile:'
    Write-Host '  1. DX11 Balanced (most compatible)'
    Write-Host '  2. DX12 Balanced (recommended test)'
    Write-Host '  3. DX12 Performance'
    Write-Host '  4. DX12 Quality'
    Write-Host '  5. DX12 Frame Generation (real-FPS cap derived from display refresh)'
    Write-Host '  6. Restore settings from before first profile change'
    $choice = Read-Host 'Choice'
    switch ($choice) {
        '1' { return 'DX11Balanced' }
        '2' { return 'DX12Balanced' }
        '3' { return 'DX12Performance' }
        '4' { return 'DX12Quality' }
        '5' { return 'DX12FrameGeneration' }
        '6' { return 'Restore' }
        default { throw "Invalid profile choice '$choice'." }
    }
}

function Set-DgVoodooValue {
    param([string]$Text, [string]$Name, [string]$Value)
    $pattern = '(?m)^' + [regex]::Escape($Name) + '\s*=.*$'
    if (-not [regex]::IsMatch($Text, $pattern)) {
        throw "dgVoodoo setting '$Name' was not found."
    }
    return [regex]::Replace($Text, $pattern, ($Name.PadRight(36) + '= ' + $Value), 1)
}

function Set-WtfValue {
    param([string]$Text, [string]$Name, [string]$Value)
    $pattern = '(?m)^SET\s+' + [regex]::Escape($Name) + '\s+"[^"]*"\s*$'
    $replacement = 'SET ' + $Name + ' "' + $Value + '"'
    if ([regex]::IsMatch($Text, $pattern)) {
        return [regex]::Replace($Text, $pattern, $replacement, 1)
    }
    return $Text.TrimEnd() + [Environment]::NewLine + $replacement + [Environment]::NewLine
}

function Get-WtfValue {
    param([string]$Text, [string]$Name, [string]$Default)
    $match = [regex]::Match($Text, '(?m)^SET\s+' + [regex]::Escape($Name) + '\s+"([^"]*)"\s*$')
    if ($match.Success) { return $match.Groups[1].Value }
    return $Default
}

try {
    if ([string]::IsNullOrWhiteSpace($InstallPath)) {
        $InstallPath = Select-AscensionFolder
    }
    $InstallPath = [System.IO.Path]::GetFullPath($InstallPath).TrimEnd('\')
    $exePath = Join-Path $InstallPath 'Ascension.exe'
    $dgConfigPath = Join-Path $InstallPath 'dgVoodoo.conf'
    $wtfConfigPath = Join-Path $InstallPath 'WTF\Config.wtf'
    foreach ($required in @($exePath, $dgConfigPath, $wtfConfigPath)) {
        if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
            throw "Required file '$required' was not found. Install the wrapper first."
        }
    }

    if (-not $SkipProcessCheck -and @(Get-Process -Name Ascension -ErrorAction SilentlyContinue).Count -gt 0) {
        throw 'Close all running Ascension clients before changing graphics profiles.'
    }
    if ([string]::IsNullOrWhiteSpace($Profile)) {
        $Profile = Select-Profile
    }

    $backupPath = Join-Path $InstallPath '.graphics-profile-backup'
    $dgBackup = Join-Path $backupPath 'dgVoodoo.conf'
    $wtfBackup = Join-Path $backupPath 'Config.wtf'

    if ($Profile -eq 'Restore') {
        if (-not (Test-Path -LiteralPath $dgBackup) -or -not (Test-Path -LiteralPath $wtfBackup)) {
            throw "No graphics-profile backup exists in '$backupPath'."
        }
        Copy-Item -LiteralPath $dgBackup -Destination $dgConfigPath -Force
        Copy-Item -LiteralPath $wtfBackup -Destination $wtfConfigPath -Force
        Write-Host 'Original graphics-profile settings restored.' -ForegroundColor Green
        exit 0
    }

    if (-not (Test-Path -LiteralPath $backupPath)) {
        New-Item -ItemType Directory -Path $backupPath | Out-Null
        Copy-Item -LiteralPath $dgConfigPath -Destination $dgBackup
        Copy-Item -LiteralPath $wtfConfigPath -Destination $wtfBackup
    }

    $wtfConfig = [System.IO.File]::ReadAllText($wtfConfigPath)
    $currentFrameCap = Get-WtfValue $wtfConfig 'maxFPS' '60'
    $refreshRate = 0
    [void][int]::TryParse((Get-WtfValue $wtfConfig 'gxRefresh' '0'), [ref]$refreshRate)
    $frameGenerationCap = if ($refreshRate -ge 60) { [math]::Max(30, [math]::Floor($refreshRate / 2)) } else { $currentFrameCap }

    $settings = switch ($Profile) {
        'DX11Balanced' {
            @{
                OutputAPI = 'd3d11_fl11_0'; MSAA = '4'; FarClip = '837'; Shadow = '0'
                GroundDensity = '64'; GroundDistance = '140'; Environment = '1.5'
            }
        }
        'DX12Balanced' {
            @{
                OutputAPI = 'd3d12_fl12_0'; MSAA = '4'; FarClip = '837'; Shadow = '0'
                GroundDensity = '64'; GroundDistance = '140'; Environment = '1.5'
            }
        }
        'DX12Performance' {
            @{
                OutputAPI = 'd3d12_fl12_0'; MSAA = '2'; FarClip = '700'; Shadow = '0'
                GroundDensity = '48'; GroundDistance = '110'; Environment = '1.25'
            }
        }
        'DX12Quality' {
            @{
                OutputAPI = 'd3d12_fl12_0'; MSAA = '4'; FarClip = '1100'; Shadow = '2'
                GroundDensity = '64'; GroundDistance = '140'; Environment = '1.5'
            }
        }
        'DX12FrameGeneration' {
            @{
                OutputAPI = 'd3d12_fl12_0'; MSAA = '4'; FarClip = '837'; Shadow = '0'
                GroundDensity = '64'; GroundDistance = '140'; Environment = '1.5'; FrameCap = [string]$frameGenerationCap
            }
        }
    }

    $dgConfig = [System.IO.File]::ReadAllText($dgConfigPath)
    $dgConfig = Set-DgVoodooValue $dgConfig 'OutputAPI' $settings.OutputAPI
    $dgConfig = Set-DgVoodooValue $dgConfig 'PresentationModel' 'flip_discard'
    $dgConfig = Set-DgVoodooValue $dgConfig 'FPSLimit' '0'
    $dgConfig = Set-DgVoodooValue $dgConfig 'Filtering' 'appdriven'
    $dgConfig = Set-DgVoodooValue $dgConfig 'Antialiasing' 'appdriven'
    $dgConfig = Set-DgVoodooValue $dgConfig 'FastVideoMemoryAccess' 'false'
    $dgConfig = Set-DgVoodooValue $dgConfig 'Default3DRenderFormat' 'argb8888'
    $dgConfig = Set-DgVoodooValue $dgConfig 'D3D12BoundsChecking' 'false'
    $dgConfig = Set-DgVoodooValue $dgConfig 'dgVoodooWatermark' 'false'

    $wtfConfig = Set-WtfValue $wtfConfig 'gxMultisample' $settings.MSAA
    if ($settings.ContainsKey('FrameCap')) { $wtfConfig = Set-WtfValue $wtfConfig 'maxFPS' $settings.FrameCap }
    $wtfConfig = Set-WtfValue $wtfConfig 'farclip' $settings.FarClip
    $wtfConfig = Set-WtfValue $wtfConfig 'shadowLevel' $settings.Shadow
    $wtfConfig = Set-WtfValue $wtfConfig 'groundEffectDensity' $settings.GroundDensity
    $wtfConfig = Set-WtfValue $wtfConfig 'groundEffectDist' $settings.GroundDistance
    $wtfConfig = Set-WtfValue $wtfConfig 'environmentDetail' $settings.Environment

    [System.IO.File]::WriteAllText($dgConfigPath, $dgConfig, (New-Object System.Text.UTF8Encoding($false)))
    [System.IO.File]::WriteAllText($wtfConfigPath, $wtfConfig, (New-Object System.Text.UTF8Encoding($false)))

    Write-Host ''
    Write-Host "Applied profile: $Profile" -ForegroundColor Green
    Write-Host "Renderer:          $($settings.OutputAPI)"
    Write-Host 'Presentation:      flip-discard'
    Write-Host "MSAA:              $($settings.MSAA)x"
    Write-Host "Frame cap:         $(if ($settings.ContainsKey('FrameCap')) { "$($settings.FrameCap) FPS (derived from refresh rate)" } else { "$currentFrameCap FPS (preserved)" })"
    Write-Host "View distance:     $($settings.FarClip)"
    Write-Host "Shadow level:      $($settings.Shadow)"
    if ($Profile -eq 'DX12FrameGeneration') {
        Write-Host ''
        Write-Host 'Next: enable Smooth Motion for Ascension.exe in NVIDIA App.' -ForegroundColor Yellow
        Write-Host "Expected result: approximately $($settings.FrameCap) real FPS plus generated frames toward the display refresh rate."
    }
} catch {
    Write-Host ''
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
