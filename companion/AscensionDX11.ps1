param(
    [ValidateSet('Install', 'Uninstall', 'Status')]
    [string]$Action = 'Install',
    [string]$InstallPath,
    [ValidateSet('DX11', 'DX12')]
    [string]$Renderer = 'DX11',
    [switch]$SkipProcessCheck
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$dgVoodooVersion = '2.87.3'
$downloadUrl = 'https://github.com/dege-diosg/dgVoodoo2/releases/download/v2.87.3/dgVoodoo2_87_3.zip'
$expectedArchiveHash = '6FB954BED55BF70E948C5045A663A9DF31EA206FAF105E327BAFE46C318F867F'
$managedFiles = @('d3d9.dll', 'd3d10core.dll', 'd3d11.dll', 'dxgi.dll', 'dxvk.conf', 'dgVoodoo.conf', 'dgVoodooCpl.exe')

function Select-AscensionFolder {
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = 'Select the folder containing Ascension.exe'
    $dialog.ShowNewFolderButton = $false

    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        throw 'No Ascension folder was selected.'
    }

    return $dialog.SelectedPath
}

function Get-AscensionPath {
    param([string]$RequestedPath)

    if ([string]::IsNullOrWhiteSpace($RequestedPath)) {
        $RequestedPath = Select-AscensionFolder
    }

    $resolved = [System.IO.Path]::GetFullPath($RequestedPath).TrimEnd('\')
    if (-not (Test-Path -LiteralPath (Join-Path $resolved 'Ascension.exe') -PathType Leaf)) {
        throw "Ascension.exe was not found in '$resolved'."
    }

    return $resolved
}

function Assert-AscensionClosed {
    if ($SkipProcessCheck) {
        return
    }

    $running = @(Get-Process -Name Ascension -ErrorAction SilentlyContinue)
    if ($running.Count -gt 0) {
        throw 'Close all running Ascension clients before installing or uninstalling the wrapper.'
    }
}

function Get-FileSha256 {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Restore-OriginalFiles {
    param(
        [string]$TargetPath,
        [string]$BackupPath,
        [object]$Manifest
    )

    Assert-WrapperBackup -BackupPath $BackupPath -Manifest $Manifest

    foreach ($name in $managedFiles) {
        $target = Join-Path $TargetPath $name
        if (Test-Path -LiteralPath $target) {
            Remove-Item -LiteralPath $target -Force
        }
    }

    foreach ($entry in @($Manifest.OriginalFiles)) {
        $source = Join-Path $BackupPath ([string]$entry.Name)
        $target = Join-Path $TargetPath ([string]$entry.Name)
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
            throw "Backup file '$source' is missing."
        }
        if ((Get-FileSha256 $source) -ne ([string]$entry.Sha256).ToUpperInvariant()) {
            throw "Backup file '$source' failed its integrity check."
        }
        Copy-Item -LiteralPath $source -Destination $target -Force
    }
}

function Get-Manifest {
    param([string]$BackupPath)

    $manifestPath = Join-Path $BackupPath 'manifest.json'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "The backup manifest is missing from '$BackupPath'."
    }
    return (Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json)
}

function Assert-WrapperBackup {
    param([string]$BackupPath, [object]$Manifest)
    if ($null -eq $Manifest -or [int]$Manifest.FormatVersion -ne 1) { throw "Unsupported wrapper backup format in '$BackupPath'." }
    $allowed = @{}
    foreach ($name in $managedFiles) { $allowed[$name.ToLowerInvariant()] = $true }
    $seen = @{}
    foreach ($entry in @($Manifest.OriginalFiles)) {
        $name = [string]$entry.Name
        $key = $name.ToLowerInvariant()
        if (-not $allowed[$key] -or $seen[$key] -or $name -match '[\\/]') { throw "Wrapper backup manifest contains invalid entry '$name'." }
        $seen[$key] = $true
        $source = Join-Path $BackupPath $name
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Wrapper backup file '$source' is missing." }
        if ((Get-FileSha256 $source) -ne ([string]$entry.Sha256).ToUpperInvariant()) { throw "Wrapper backup file '$source' failed verification." }
    }
    return $true
}

function Install-Wrapper {
    param([string]$TargetPath)

    Assert-AscensionClosed
    $backupPath = Join-Path $TargetPath '.dx11-wrapper-backup'
    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('AscensionDX11-' + [guid]::NewGuid().ToString('N'))
    $archivePath = Join-Path $tempRoot 'dgVoodoo.zip'
    $extractPath = Join-Path $tempRoot 'package'
    $createdBackup = $false

    try {
        New-Item -ItemType Directory -Path $tempRoot, $extractPath -Force | Out-Null
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Write-Host "Downloading dgVoodoo $dgVoodooVersion from the official release..."
        Invoke-WebRequest -Uri $downloadUrl -OutFile $archivePath -UseBasicParsing

        $archiveHash = Get-FileSha256 $archivePath
        if ($archiveHash -ne $expectedArchiveHash) {
            throw "The dgVoodoo archive failed verification. Expected $expectedArchiveHash, received $archiveHash."
        }

        Expand-Archive -LiteralPath $archivePath -DestinationPath $extractPath -Force
        $wrapperSource = Join-Path $extractPath 'MS\x86\D3D9.dll'
        $configSource = Join-Path $extractPath 'dgVoodoo.conf'
        $controlPanelSource = Join-Path $extractPath 'dgVoodooCpl.exe'
        foreach ($required in @($wrapperSource, $configSource, $controlPanelSource)) {
            if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
                throw "Required package file '$required' is missing."
            }
        }

        if (Test-Path -LiteralPath $backupPath) {
            $existingManifest = Get-Manifest $backupPath
            $currentExecutableHash = Get-FileSha256 (Join-Path $TargetPath 'Ascension.exe')
            $currentWrapper = Join-Path $TargetPath 'd3d9.dll'
            $currentProduct = if (Test-Path -LiteralPath $currentWrapper) { (Get-Item -LiteralPath $currentWrapper).VersionInfo.ProductName } else { $null }
            if ($currentProduct -ne 'dgVoodoo') {
                if (Test-Path -LiteralPath (Join-Path $TargetPath '.reshade-backup')) {
                    throw 'The launcher replaced the wrapper while AURA ReShade is still installed. Uninstall ReShade before rebasing the wrapper backup.'
                }
                $staleBackup = Join-Path $TargetPath ('.dx11-wrapper-backup.stale-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
                Move-Item -LiteralPath $backupPath -Destination $staleBackup
                Write-Warning "The launcher replaced the wrapper; archived its older backup and will capture a new baseline: $staleBackup"
            } elseif ([string]$existingManifest.AscensionExecutableSha256 -ne $currentExecutableHash) {
                    throw 'Ascension.exe changed after the wrapper backup was created. Run launcher repair until dgVoodoo is replaced, then reinstall to archive the old backup and capture the updated client baseline.'
            }
        }

        if (-not (Test-Path -LiteralPath $backupPath)) {
            $legacyBackupPath = Join-Path $TargetPath '_dxvk_backup'
            $currentD3D9 = Join-Path $TargetPath 'd3d9.dll'
            $currentD3D9Product = if (Test-Path -LiteralPath $currentD3D9) {
                (Get-Item -LiteralPath $currentD3D9).VersionInfo.ProductName
            } else {
                $null
            }
            $useLegacyBackup = $currentD3D9Product -eq 'dgVoodoo' -and (Test-Path -LiteralPath (Join-Path $legacyBackupPath 'd3d9.dll'))
            if ($currentD3D9Product -eq 'dgVoodoo' -and -not $useLegacyBackup) {
                throw 'dgVoodoo is already installed, but no original-file backup was found. Restore the original client files before using this installer.'
            }

            New-Item -ItemType Directory -Path $backupPath | Out-Null
            $createdBackup = $true
            $originalFiles = @()
            foreach ($name in $managedFiles) {
                $source = if ($useLegacyBackup) {
                    Join-Path $legacyBackupPath $name
                } else {
                    Join-Path $TargetPath $name
                }
                if (Test-Path -LiteralPath $source -PathType Leaf) {
                    Copy-Item -LiteralPath $source -Destination (Join-Path $backupPath $name)
                    $originalFiles += [pscustomobject]@{
                        Name = $name
                        Sha256 = Get-FileSha256 $source
                    }
                }
            }

            $manifest = [pscustomobject]@{
                FormatVersion = 1
                CreatedUtc = [DateTime]::UtcNow.ToString('o')
                AscensionExecutableSha256 = Get-FileSha256 (Join-Path $TargetPath 'Ascension.exe')
                OriginalFiles = $originalFiles
            }
            $manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $backupPath 'manifest.json') -Encoding UTF8
            [void](Assert-WrapperBackup -BackupPath $backupPath -Manifest $manifest)
            if ($useLegacyBackup) {
                Write-Host 'Adopted the existing _dxvk_backup as the original-file source.'
            }
        } else {
            $manifest = Get-Manifest $backupPath
            [void](Assert-WrapperBackup -BackupPath $backupPath -Manifest $manifest)
            Write-Host 'Using the existing original-file backup.'
        }

        $reportedVRAM = $null
        $currentConfigPath = Join-Path $TargetPath 'dgVoodoo.conf'
        if (Test-Path -LiteralPath $currentConfigPath -PathType Leaf) {
            $vramMatch = [regex]::Match([System.IO.File]::ReadAllText($currentConfigPath), '(?m)^VRAM\s*=\s*(\S+)\s*$')
            if ($vramMatch.Success) { $reportedVRAM = $vramMatch.Groups[1].Value }
        }

        foreach ($name in $managedFiles) {
            $target = Join-Path $TargetPath $name
            if (Test-Path -LiteralPath $target) {
                Remove-Item -LiteralPath $target -Force
            }
        }

        Copy-Item -LiteralPath $wrapperSource -Destination (Join-Path $TargetPath 'd3d9.dll')
        Copy-Item -LiteralPath $controlPanelSource -Destination (Join-Path $TargetPath 'dgVoodooCpl.exe') -Force

        $outputApi = if ($Renderer -eq 'DX12') { 'd3d12_fl12_0' } else { 'd3d11_fl11_0' }
        $config = [System.IO.File]::ReadAllText($configSource)
        $config = $config -replace '(?m)^OutputAPI\s*=.*$', "OutputAPI                            = $outputApi"
        $config = $config -replace '(?m)^PresentationModel\s*=.*$', 'PresentationModel                    = flip_discard'
        if ($reportedVRAM) { $config = $config -replace '(?m)^VRAM\s*=.*$', ('VRAM'.PadRight(36) + '= ' + $reportedVRAM) }
        $config = $config -replace '(?m)^dgVoodooWatermark\s*=.*$', 'dgVoodooWatermark                   = false'
        $config = $config -replace '(?m)^Default3DRenderFormat\s*=.*$', 'Default3DRenderFormat               = argb8888'
        [System.IO.File]::WriteAllText((Join-Path $TargetPath 'dgVoodoo.conf'), $config, (New-Object System.Text.UTF8Encoding($false)))

        if ((Get-FileSha256 (Join-Path $TargetPath 'd3d9.dll')) -ne (Get-FileSha256 $wrapperSource)) {
            throw 'The installed D3D9 wrapper failed verification.'
        }

        Write-Host ''
        Write-Host "Ascension $Renderer wrapper installed successfully." -ForegroundColor Green
        Write-Host "Installation: $TargetPath"
        Write-Host "Backup:       $backupPath"
        Write-Host "Output API:   $outputApi"
        Write-Host "Reported VRAM: $(if ($reportedVRAM) { "$reportedVRAM (preserved)" } else { 'package default' })"
    } catch {
        if (Test-Path -LiteralPath (Join-Path $backupPath 'manifest.json')) {
            try {
                $rollbackManifest = Get-Manifest $backupPath
                Restore-OriginalFiles -TargetPath $TargetPath -BackupPath $backupPath -Manifest $rollbackManifest
                $originalNames = @($rollbackManifest.OriginalFiles | ForEach-Object { [string]$_.Name })
                foreach ($name in @('dgVoodoo.conf', 'dgVoodooCpl.exe')) {
                    $generated = Join-Path $TargetPath $name
                    if ($name -notin $originalNames -and (Test-Path -LiteralPath $generated)) {
                        Remove-Item -LiteralPath $generated -Force
                    }
                }
                Write-Warning 'Installation failed; original graphics files were restored.'
            } catch {
                Write-Warning "Automatic rollback also failed: $($_.Exception.Message)"
            }
        } elseif ($createdBackup -and (Test-Path -LiteralPath $backupPath)) {
            Remove-Item -LiteralPath $backupPath -Recurse -Force
        }
        throw
    } finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }
}

function Uninstall-Wrapper {
    param([string]$TargetPath)

    Assert-AscensionClosed
    $backupPath = Join-Path $TargetPath '.dx11-wrapper-backup'
    $manifest = Get-Manifest $backupPath
    [void](Assert-WrapperBackup -BackupPath $backupPath -Manifest $manifest)
    $currentExecutableHash = Get-FileSha256 (Join-Path $TargetPath 'Ascension.exe')
    if ([string]$manifest.AscensionExecutableSha256 -ne $currentExecutableHash) {
        throw 'Ascension.exe changed after this wrapper backup was created. Refusing to restore files from an older client generation; run launcher repair until dgVoodoo is replaced, then reinstall to capture a new baseline.'
    }
    $reShadeBackup = Join-Path $TargetPath '.reshade-backup'
    $reShadeScript = Join-Path $PSScriptRoot 'AscensionReShade.ps1'
    if (Test-Path -LiteralPath $reShadeBackup) {
        if (-not (Test-Path -LiteralPath $reShadeScript -PathType Leaf)) {
            throw 'ReShade is installed, but AscensionReShade.ps1 is unavailable for safe removal.'
        }
        $reShadeArguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $reShadeScript, '-Action', 'Uninstall', '-InstallPath', $TargetPath)
        if ($SkipProcessCheck) { $reShadeArguments += '-SkipProcessCheck' }
        & powershell.exe @reShadeArguments
        if ($LASTEXITCODE -ne 0) { throw 'ReShade removal failed; wrapper uninstall was cancelled.' }
    }
    $profileBackupPath = Join-Path $TargetPath '.graphics-profile-backup'

    Restore-OriginalFiles -TargetPath $TargetPath -BackupPath $backupPath -Manifest $manifest
    foreach ($entry in @($manifest.OriginalFiles)) {
        $restored = Join-Path $TargetPath ([string]$entry.Name)
        if ((Get-FileSha256 $restored) -ne ([string]$entry.Sha256).ToUpperInvariant()) {
            throw "Restored file '$restored' failed verification. The backup has been retained."
        }
    }

    $archivedBackup = Join-Path $TargetPath ('.dx11-wrapper-backup.restored-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    Move-Item -LiteralPath $backupPath -Destination $archivedBackup
    if (Test-Path -LiteralPath $profileBackupPath) {
        $archivedProfileBackup = Join-Path $TargetPath ('.graphics-profile-backup.restored-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
        Move-Item -LiteralPath $profileBackupPath -Destination $archivedProfileBackup
    }

    Write-Host ''
    Write-Host 'The graphics wrapper was removed and original files were restored.' -ForegroundColor Green
    Write-Host "Preserved backup: $archivedBackup"
}

function Show-Status {
    param([string]$TargetPath)

    $wrapperPath = Join-Path $TargetPath 'd3d9.dll'
    $backupPath = Join-Path $TargetPath '.dx11-wrapper-backup'
    $product = $null
    if (Test-Path -LiteralPath $wrapperPath) {
        $product = (Get-Item -LiteralPath $wrapperPath).VersionInfo.ProductName
    }

    Write-Host "Installation: $TargetPath"
    Write-Host "D3D9 product: $product"
    Write-Host "Backup found: $(Test-Path -LiteralPath (Join-Path $backupPath 'manifest.json'))"
    Write-Host "DX11 config:  $(Test-Path -LiteralPath (Join-Path $TargetPath 'dgVoodoo.conf'))"
    Write-Host "ReShade:      $(Test-Path -LiteralPath (Join-Path $TargetPath 'ReShade.ini'))"
    Write-Host "AURA addon:   $(Test-Path -LiteralPath (Join-Path $TargetPath 'Interface\AddOns\AURA_VisualUpgrade\AURA_VisualUpgrade.toc'))"
}

try {
    $targetPath = Get-AscensionPath $InstallPath
    switch ($Action) {
        'Install' { Install-Wrapper $targetPath }
        'Uninstall' { Uninstall-Wrapper $targetPath }
        'Status' { Show-Status $targetPath }
    }
} catch {
    Write-Host ''
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
