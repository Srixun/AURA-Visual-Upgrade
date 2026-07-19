param(
    [ValidateSet('Install', 'Update', 'Uninstall', 'Status')]
    [string]$Action = 'Install',
    [string]$InstallPath,
    [switch]$SkipProcessCheck,
    [switch]$SkipUpdateCheck
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$payloadPath = Join-Path $scriptRoot 'AURA_VisualUpgrade.zip'
$payloadHashPath = Join-Path $scriptRoot 'AURA_VisualUpgrade.zip.sha256'
$githubRepository = 'Srixun/AURA-Visual-Upgrade'
$githubApi = "https://api.github.com/repos/$githubRepository/releases/latest"

function Add-Candidate([System.Collections.ArrayList]$Candidates, [string]$Path, [string]$Source) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    try { $fullPath = [System.IO.Path]::GetFullPath($Path).TrimEnd('\') } catch { return }
    if (-not (Test-Path -LiteralPath (Join-Path $fullPath 'Ascension.exe') -PathType Leaf)) { return }
    if (@($Candidates | Where-Object { $_.Path -ieq $fullPath }).Count -gt 0) { return }
    [void]$Candidates.Add([pscustomobject]@{ Path=$fullPath; Source=$Source })
}

function Find-Installations {
    $candidates = New-Object System.Collections.ArrayList
    $cachePath = Join-Path $env:APPDATA 'projectascension\Cache\Cache_Data'
    if (Test-Path -LiteralPath $cachePath) {
        foreach ($file in Get-ChildItem -LiteralPath $cachePath -File -ErrorAction SilentlyContinue) {
            try {
                $content = [System.IO.File]::ReadAllText($file.FullName)
                $match = [regex]::Match($content, '"install_root"\s*:\s*"((?:\\.|[^"])*)"')
                if ($match.Success) {
                    $root = ('"' + $match.Groups[1].Value + '"') | ConvertFrom-Json
                    Add-Candidate $candidates $root 'Official launcher'
                }
            } catch {}
        }
    }
    foreach ($drive in Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue) {
        if ($drive.Root -notmatch '^[A-Z]:\\$') { continue }
        foreach ($relative in @('Games\Ascension', 'Ascension', 'Ascensiontest', 'Project Ascension', 'Games\Project Ascension')) {
            Add-Candidate $candidates (Join-Path $drive.Root $relative) 'Common location'
        }
    }
    return @($candidates | Sort-Object @{Expression={ if ($_.Source -eq 'Official launcher') { 0 } elseif ($_.Path -match '(?i)test') { 2 } else { 1 } }}, Path)
}

function Select-Folder {
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = 'Select the folder containing Ascension.exe'
    $dialog.ShowNewFolderButton = $false
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { throw 'No Ascension folder was selected.' }
    return [System.IO.Path]::GetFullPath($dialog.SelectedPath).TrimEnd('\')
}

function Resolve-InstallPath([string]$RequestedPath) {
    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        $resolved = [System.IO.Path]::GetFullPath($RequestedPath).TrimEnd('\')
        if (-not (Test-Path -LiteralPath (Join-Path $resolved 'Ascension.exe') -PathType Leaf)) { throw "Ascension.exe was not found in '$resolved'." }
        return $resolved
    }

    $candidates = @(Find-Installations)
    if ($candidates.Count -eq 0) { return Select-Folder }
    if ($candidates.Count -eq 1) {
        Write-Host "Automatically detected: $($candidates[0].Path)" -ForegroundColor Cyan
        return $candidates[0].Path
    }

    Write-Host 'Detected Ascension installations:' -ForegroundColor Cyan
    for ($index = 0; $index -lt $candidates.Count; $index++) {
        Write-Host "  $($index + 1). $($candidates[$index].Path) [$($candidates[$index].Source)]"
    }
    Write-Host "  $($candidates.Count + 1). Choose another folder"
    Write-Host '  0. Exit'
    while ($true) {
        $choice = 0
        if ([int]::TryParse((Read-Host 'Installation'), [ref]$choice)) {
            if ($choice -eq 0) { exit 0 }
            if ($choice -eq $candidates.Count + 1) { return Select-Folder }
            if ($choice -ge 1 -and $choice -le $candidates.Count) { return $candidates[$choice - 1].Path }
        }
        Write-Host 'Enter one of the listed numbers.' -ForegroundColor Yellow
    }
}

function Assert-ClientClosed {
    if (-not $SkipProcessCheck -and @(Get-Process -Name Ascension -ErrorAction SilentlyContinue).Count -gt 0) {
        throw 'Close all Ascension clients before installing or removing the addon.'
    }
}

function Get-AddonVersion([string]$AddonPath) {
    $toc = Join-Path $AddonPath 'AURA_VisualUpgrade.toc'
    if (-not (Test-Path -LiteralPath $toc -PathType Leaf)) { return $null }
    $match = [regex]::Match([System.IO.File]::ReadAllText($toc), '(?m)^## Version:\s*(.+?)\s*$')
    if ($match.Success) { return $match.Groups[1].Value }
    return 'Unknown'
}

function ConvertTo-SemanticVersion([string]$Value) {
    if ($Value -notmatch '^\d+\.\d+\.\d+$') { return $null }
    try { return [version]$Value } catch { return $null }
}

function Get-Checksum([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Checksum file '$Path' is missing." }
    $match = [regex]::Match([System.IO.File]::ReadAllText($Path), '(?i)\b([a-f0-9]{64})\b')
    if (-not $match.Success) { throw "Checksum file '$Path' is malformed." }
    return $match.Groups[1].Value.ToUpperInvariant()
}

function Get-PayloadVersion([string]$ArchivePath) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($ArchivePath)
    try {
        $toc = @($archive.Entries | Where-Object { $_.FullName -match '(^|[\\/])AURA_VisualUpgrade[\\/]AURA_VisualUpgrade\.toc$' })
        if ($toc.Count -ne 1) { throw "Addon archive '$ArchivePath' does not contain exactly one AURA TOC file." }
        $reader = New-Object System.IO.StreamReader($toc[0].Open())
        try { $text = $reader.ReadToEnd() } finally { $reader.Dispose() }
        $match = [regex]::Match($text, '(?m)^## Version:\s*(\d+\.\d+\.\d+)\s*$')
        if (-not $match.Success) { throw "Addon archive '$ArchivePath' has no valid version metadata." }
        return $match.Groups[1].Value
    } finally {
        $archive.Dispose()
    }
}

function Get-LatestRelease {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    return Invoke-RestMethod -Uri $githubApi -Headers @{ 'User-Agent'='AURA-Visual-Upgrade-Updater'; 'Accept'='application/vnd.github+json' } -UseBasicParsing
}

function Get-ReleaseAsset([object]$Release, [string]$Name) {
    $asset = @($Release.assets | Where-Object { $_.name -eq $Name })
    if ($asset.Count -ne 1) { throw "Release '$($Release.tag_name)' does not contain exactly one '$Name' asset." }
    return $asset[0]
}

function Download-ReleasePayload([object]$Release) {
    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('AURAVisualUpdate-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempRoot | Out-Null
    try {
        $archive = Join-Path $tempRoot 'AURA_VisualUpgrade.zip'
        $checksum = Join-Path $tempRoot 'AURA_VisualUpgrade.zip.sha256'
        $archiveAsset = Get-ReleaseAsset $Release 'AURA-Visual-Upgrade-Addon.zip'
        $checksumAsset = Get-ReleaseAsset $Release 'AURA-Visual-Upgrade-Addon.zip.sha256'
        Invoke-WebRequest -Uri $archiveAsset.browser_download_url -OutFile $archive -Headers @{ 'User-Agent'='AURA-Visual-Upgrade-Updater' } -UseBasicParsing
        Invoke-WebRequest -Uri $checksumAsset.browser_download_url -OutFile $checksum -Headers @{ 'User-Agent'='AURA-Visual-Upgrade-Updater' } -UseBasicParsing
        $expected = Get-Checksum $checksum
        $actual = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToUpperInvariant()
        if ($actual -ne $expected) { throw "GitHub release payload failed verification. Expected $expected, received $actual." }
        $releaseVersion = ([string]$Release.tag_name).TrimStart('v')
        $payloadVersion = Get-PayloadVersion $archive
        if ($payloadVersion -ne $releaseVersion) { throw "GitHub release $releaseVersion contains addon version $payloadVersion." }
        return [pscustomobject]@{ Path=$archive; Hash=$expected; Version=$payloadVersion; TempRoot=$tempRoot; Source='GitHub Releases' }
    } catch {
        if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
        throw
    }
}

function Get-BundledPayload {
    if (-not (Test-Path -LiteralPath $payloadPath -PathType Leaf)) { throw "Addon payload '$payloadPath' is missing." }
    $expected = Get-Checksum $payloadHashPath
    $actual = (Get-FileHash -LiteralPath $payloadPath -Algorithm SHA256).Hash.ToUpperInvariant()
    if ($actual -ne $expected) { throw "Bundled addon payload failed verification. Expected $expected, received $actual." }
    return [pscustomobject]@{ Path=$payloadPath; Hash=$expected; Version=(Get-PayloadVersion $payloadPath); TempRoot=$null; Source='bundled package' }
}

function Install-Addon([string]$TargetPath, [object]$Payload) {
    Assert-ClientClosed
    $actualHash = (Get-FileHash -LiteralPath $Payload.Path -Algorithm SHA256).Hash.ToUpperInvariant()
    if ($actualHash -ne $Payload.Hash) { throw "Addon payload failed verification. Expected $($Payload.Hash), received $actualHash." }

    $addonRoot = Join-Path $TargetPath 'Interface\AddOns'
    if (-not (Test-Path -LiteralPath $addonRoot)) { New-Item -ItemType Directory -Path $addonRoot -Force | Out-Null }
    $destination = Join-Path $addonRoot 'AURA_VisualUpgrade'
    $backup = $null
    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('AURAVisualUpgrade-' + [guid]::NewGuid().ToString('N'))

    try {
        New-Item -ItemType Directory -Path $tempRoot | Out-Null
        Expand-Archive -LiteralPath $Payload.Path -DestinationPath $tempRoot -Force
        $source = Join-Path $tempRoot 'AURA_VisualUpgrade'
        foreach ($name in @('AURA_VisualUpgrade.toc', 'Core.lua', 'Data.lua', 'UI.lua')) {
            if (-not (Test-Path -LiteralPath (Join-Path $source $name) -PathType Leaf)) { throw "Payload file '$name' is missing." }
        }

        if (Test-Path -LiteralPath $destination) {
            $backup = Join-Path $addonRoot ('.AURA_VisualUpgrade.backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
            Move-Item -LiteralPath $destination -Destination $backup
        }
        Copy-Item -LiteralPath $source -Destination $destination -Recurse
        if ($Payload.Version -and (Get-AddonVersion $destination) -ne $Payload.Version) {
            throw "Installed addon version does not match payload version $($Payload.Version)."
        }

        foreach ($file in Get-ChildItem -LiteralPath $source -File) {
            $installed = Join-Path $destination $file.Name
            if (-not (Test-Path -LiteralPath $installed) -or (Get-FileHash -Algorithm SHA256 $installed).Hash -ne (Get-FileHash -Algorithm SHA256 $file.FullName).Hash) {
                throw "Installed file '$($file.Name)' failed verification."
            }
        }

        Write-Host ''
        Write-Host 'AURA Visual Upgrade installed successfully.' -ForegroundColor Green
        Write-Host "Installation: $destination"
        Write-Host "Version:      $(Get-AddonVersion $destination)"
        Write-Host "Source:       $($Payload.Source)"
        if ($backup) { Write-Host "Backup:       $backup" }
        Write-Host 'Open it in-game with /auravis or the AV minimap button.' -ForegroundColor Cyan
    } catch {
        if (Test-Path -LiteralPath $destination) { Remove-Item -LiteralPath $destination -Recurse -Force }
        if ($backup -and (Test-Path -LiteralPath $backup)) { Move-Item -LiteralPath $backup -Destination $destination }
        throw
    } finally {
        if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
    }
}

function Uninstall-Addon([string]$TargetPath) {
    Assert-ClientClosed
    $destination = Join-Path $TargetPath 'Interface\AddOns\AURA_VisualUpgrade'
    if (-not (Test-Path -LiteralPath $destination)) { throw 'AURA Visual Upgrade is not installed.' }
    $archive = Join-Path (Split-Path -Parent $destination) ('.AURA_VisualUpgrade.uninstalled-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    Move-Item -LiteralPath $destination -Destination $archive
    Write-Host "AURA Visual Upgrade removed. Preserved copy: $archive" -ForegroundColor Green
}

function Show-Status([string]$TargetPath) {
    $destination = Join-Path $TargetPath 'Interface\AddOns\AURA_VisualUpgrade'
    $version = Get-AddonVersion $destination
    $bundledVerified = $false
    try { $bundledVerified = $null -ne (Get-BundledPayload) } catch {}
    $latest = $null
    try { $latest = Get-LatestRelease } catch {}
    $installedSemanticVersion = ConvertTo-SemanticVersion $version
    $latestVersion = if ($latest) { ([string]$latest.tag_name).TrimStart('v') } else { $null }
    $latestSemanticVersion = ConvertTo-SemanticVersion $latestVersion
    [pscustomobject]@{
        Installation = $TargetPath
        AddonInstalled = $null -ne $version
        AddonPath = $destination
        Version = $version
        BundledPayloadVerified = $bundledVerified
        LatestVersion = if ($latestVersion) { $latestVersion } else { 'Unavailable/offline' }
        UpdateAvailable = if ($latestSemanticVersion -and $installedSemanticVersion) { $latestSemanticVersion -gt $installedSemanticVersion } else { $false }
    } | Format-List
}

function Install-WithUpdateCheck([string]$TargetPath, [bool]$RequireRemoteUpdate) {
    $installedPath = Join-Path $TargetPath 'Interface\AddOns\AURA_VisualUpgrade'
    $installedVersion = Get-AddonVersion $installedPath
    $installedSemanticVersion = ConvertTo-SemanticVersion $installedVersion
    $payload = $null
    try {
        if ($SkipUpdateCheck) {
            if ($RequireRemoteUpdate) { throw 'Update checks were disabled with -SkipUpdateCheck.' }
            $payload = Get-BundledPayload
        } else {
            $release = Get-LatestRelease
            $latestVersion = ([string]$release.tag_name).TrimStart('v')
            if ($installedSemanticVersion -and [version]$latestVersion -le $installedSemanticVersion) {
                $description = if ([version]$latestVersion -eq $installedSemanticVersion) { 'already current' } else { "newer than the latest published version $latestVersion" }
                Write-Host "AURA Visual Upgrade $installedVersion is $description; the installed addon was preserved." -ForegroundColor Green
                return
            }
            Write-Host "Using GitHub release $($release.tag_name)..." -ForegroundColor Cyan
            $payload = Download-ReleasePayload $release
        }
    } catch {
        if ($RequireRemoteUpdate) { throw }
        Write-Warning "Online update check unavailable: $($_.Exception.Message)"
        Write-Host 'Using the verified bundled addon payload.' -ForegroundColor Yellow
        $payload = Get-BundledPayload
    }

    $payloadSemanticVersion = ConvertTo-SemanticVersion $payload.Version
    if ($installedSemanticVersion -and $payloadSemanticVersion -and $payloadSemanticVersion -le $installedSemanticVersion) {
        $description = if ($payloadSemanticVersion -eq $installedSemanticVersion) { 'already current' } else { "newer than the available $($payload.Version) payload" }
        Write-Host "AURA Visual Upgrade $installedVersion is $description; the installed addon was preserved." -ForegroundColor Green
        if ($payload.TempRoot -and (Test-Path -LiteralPath $payload.TempRoot)) { Remove-Item -LiteralPath $payload.TempRoot -Recurse -Force }
        return
    }

    try { Install-Addon $TargetPath $payload }
    finally {
        if ($payload -and $payload.TempRoot -and (Test-Path -LiteralPath $payload.TempRoot)) {
            Remove-Item -LiteralPath $payload.TempRoot -Recurse -Force
        }
    }
}

try {
    Write-Host '============================================================' -ForegroundColor DarkCyan
    Write-Host ' AURA Visual Upgrade Addon Installer' -ForegroundColor Cyan
    Write-Host '============================================================' -ForegroundColor DarkCyan
    $target = Resolve-InstallPath $InstallPath
    switch ($Action) {
        'Install' { Install-WithUpdateCheck $target $false }
        'Update' { Install-WithUpdateCheck $target $true }
        'Uninstall' { Uninstall-Addon $target }
        'Status' { Show-Status $target }
    }
} catch {
    Write-Host ''
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
