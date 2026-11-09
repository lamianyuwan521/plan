<#
.SYNOPSIS
Dispatch or follow the remote GitHub Actions unsigned-IPA build and download the artifact.

.DESCRIPTION
Builds github.com/lamianyuwan521/plan on the macos-latest workflow
.github/workflows/ios-build.yml. Does not build locally.
#>
param(
    [ValidateSet("dispatch", "push", "run")]
    [string]$Mode = "dispatch",
    [string]$Ref = "",
    [string]$RunId = "",
    [string]$Workflow = "ios-build.yml",
    [string]$Artifact = "xiaoyier-unsigned-ipa",
    [string]$OutDir = "dist",
    [switch]$AllowStale
)

$ErrorActionPreference = "Stop"
if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
    $PSNativeCommandUseErrorActionPreference = $false
}
$env:GH_PAGER = ""
$env:GH_PROMPT_DISABLED = "1"

$script:Repo = "lamianyuwan521/plan"
$script:Gh = $null
$script:Root = $null
$script:LockStream = $null
$script:LockHeld = $false
$script:LockPath = $null
$script:RefName = ""
$script:RemoteSha = ""
$script:LocalSha = ""
$script:MaxId = [int64]0

function Release-Lock {
    if ($script:LockStream) {
        $script:LockStream.Close()
        $script:LockStream = $null
    }
    if ($script:LockHeld -and $script:LockPath -and (Test-Path -LiteralPath $script:LockPath)) {
        Remove-Item -LiteralPath $script:LockPath -Force -ErrorAction SilentlyContinue
        $script:LockHeld = $false
    }
}

function Die([int]$Code, [string]$Message) {
    Release-Lock
    if ($Code -eq 4) {
        Write-Host $Message
    } else {
        Write-Host "ERROR: $Message"
    }
    exit $Code
}

function Invoke-Git {
    & git -C $script:Root @args
    if ($LASTEXITCODE -ne 0) {
        Die 1 ("git failed: git " + ($args -join " "))
    }
}

function Get-GhText {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$GhArgs)
    $output = & $script:Gh @GhArgs
    return @{
        Code   = $LASTEXITCODE
        Output = $output
    }
}

function Join-NativeText($Output) {
    if ($null -eq $Output) { return "" }
    if ($Output -is [System.Array]) { return ($Output -join "`n") }
    return [string]$Output
}

function Get-Runs {
    $fields = "databaseId,status,conclusion,headSha,headBranch,event,url,createdAt"
    $result = Get-GhText run list --repo $script:Repo --workflow $Workflow --limit 20 --json $fields
    if ($result.Code -ne 0) {
        Die 1 "gh run list failed"
    }
    $text = Join-NativeText $result.Output
    if ([string]::IsNullOrWhiteSpace($text)) { return @() }
    $parsed = $text | ConvertFrom-Json
    if ($null -eq $parsed) { return @() }
    return @($parsed)
}

function Resolve-RepoRoot {
    $dir = $PSScriptRoot
    while ($dir) {
        $workflow = Join-Path $dir ".github\workflows\ios-build.yml"
        if (Test-Path -LiteralPath $workflow) { return $dir }
        $parent = Split-Path -Parent $dir
        if (-not $parent -or $parent -eq $dir) { break }
        $dir = $parent
    }
    Die 1 "Could not find .github/workflows/ios-build.yml above the script."
}

function Resolve-GhPath {
    $cmd = Get-Command gh -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) { return $cmd.Source }
    $candidates = @(
        (Join-Path $env:ProgramFiles "GitHub CLI\gh.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "GitHub CLI\gh.exe"),
        (Join-Path $env:LOCALAPPDATA "GitHub CLI\gh.exe")
    )
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) { return $candidate }
    }
    Die 1 "gh is not installed. Install with: winget install --id GitHub.cli -e --accept-package-agreements --accept-source-agreements. Then rerun this script. Do not dispatch any other way."
}

function Enter-Lock {
    $dist = Join-Path $script:Root "dist"
    New-Item -ItemType Directory -Force -Path $dist | Out-Null
    $script:LockPath = Join-Path $dist "ipa-build.lock"
    try {
        $script:LockStream = [System.IO.File]::Open(
            $script:LockPath,
            [System.IO.FileMode]::OpenOrCreate,
            [System.IO.FileAccess]::ReadWrite,
            [System.IO.FileShare]::None)
    } catch {
        Die 5 "BUSY another build-remote-ipa.ps1 is running. Wait for it. Do not start a second build."
    }
    $bytes = [System.Text.Encoding]::ASCII.GetBytes("$PID")
    $script:LockStream.SetLength(0)
    $script:LockStream.Write($bytes, 0, $bytes.Length)
    $script:LockStream.Flush()
    $script:LockHeld = $true
}

function Get-PorcelainPath([string]$Line) {
    $rest = $Line.Substring([Math]::Min(3, $Line.Length)).Trim()
    if ($rest -match ' -> ') {
        $rest = ($rest -split ' -> ', 2)[1].Trim()
    }
    return $rest.Trim('"')
}

function Test-IsIgnoredPath([string]$Path) {
    return $Path -eq "dist" -or $Path.StartsWith("dist/") -or $Path -eq ".claude" -or $Path.StartsWith(".claude/")
}

function Test-IsSecretPath([string]$Path) {
    return $Path -match '(?i)(^|/)\.env($|\.)|(^|/)credentials\.json$|\.(p12|pem|mobileprovision|keystore)$'
}

function Get-SourceStatus {
    $status = Invoke-Git status --porcelain
    $source = @()
    $ignored = @()
    $secrets = @()
    if ($status) {
        foreach ($line in @($status)) {
            $text = [string]$line
            if ([string]::IsNullOrWhiteSpace($text)) { continue }
            $path = Get-PorcelainPath $text
            if (Test-IsSecretPath $path) {
                $secrets += $path
            } elseif (Test-IsIgnoredPath $path) {
                $ignored += $path
            } else {
                $source += $path
            }
        }
    }
    return @{
        Source  = $source
        Ignored = $ignored
        Secrets = $secrets
    }
}

function Test-IsStale {
    $paths = Get-SourceStatus
    $countsText = (Invoke-Git rev-list --left-right --count "origin/$($script:RefName)...HEAD").Trim()
    $parts = @($countsText -split "\s+")
    $behind = [int]$parts[0]
    $ahead = [int]$parts[1]
    Write-Host "HEAD=$($script:LocalSha)"
    Write-Host "ORIGIN=$($script:RemoteSha)"
    Write-Host "SOURCE_DIRTY=$($paths.Source.Count)"
    Write-Host "IGNORED_DIRTY=$($paths.Ignored.Count)"
    Write-Host "AHEAD=$ahead"
    Write-Host "BEHIND=$behind"
    if ($paths.Secrets.Count -gt 0) {
        Die 1 ("SECRET_BLOCKED " + ($paths.Secrets -join ", ") + ". No commit and no workflow were started.")
    }
    if ($AllowStale) {
        Write-Host "ALLOW_STALE=1"
        return
    }
    # Push mode follows the run created by the push that just happened.
    if ($Mode -eq "push") {
        if ($ahead -gt 0 -or $script:LocalSha -ne $script:RemoteSha) {
            Die 1 "HEAD is not on origin/$($script:RefName). Nothing was dispatched. Push first, then rerun -Mode push."
        }
        if ($paths.Source.Count -gt 0) {
            Die 1 ("SOURCE_DIRTY " + ($paths.Source -join ", ") + ". These files are not in the pushed commit. Commit and push them before building. Do not dispatch another run for the old SHA.")
        }
        return
    }
    if ($paths.Source.Count -gt 0 -or $ahead -gt 0) {
        $listing = if ($paths.Source.Count -gt 0) { $paths.Source -join "`n" } else { "(no uncommitted source; local commits are not on origin)" }
        $message = @(
            "SOURCE_DIRTY",
            "REF=$($script:RefName)",
            "HEAD=$($script:LocalSha)",
            "ORIGIN=$($script:RemoteSha)",
            "SOURCE_DIRTY=$($paths.Source.Count)",
            "AHEAD=$ahead",
            "BEHIND=$behind",
            $listing,
            "Source is not on origin/$($script:RefName). No workflow was started.",
            "Commit the source files (never dist/, .claude/, or secrets), push with 'git push origin HEAD', then rerun -Mode push on main."
        ) -join "`n"
        Die 4 $message
    }
    if ($behind -gt 0) {
        Write-Host "NOTE local is behind origin/$($script:RefName); building ORIGIN."
    }
}

function Wait-ForMatch {
    param([scriptblock]$Finder, [int]$TimeoutSec, [string]$MissingMessage, [int]$MissingCode)
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        $found = & $Finder
        if ($found) { return $found }
        Start-Sleep -Seconds 5
    }
    Die $MissingCode $MissingMessage
}

function Find-DispatchRun {
    foreach ($run in (Get-Runs)) {
        if ([int64]$run.databaseId -le $script:MaxId) { continue }
        if ([string]$run.event -ne "workflow_dispatch") { continue }
        if ([string]$run.headBranch -ne $script:RefName) { continue }
        if ([string]$run.headSha -ne $script:RemoteSha) { continue }
        return $run
    }
    return $null
}

function Find-PushRun {
    $recent = [datetimeoffset]::UtcNow.AddMinutes(-20)
    foreach ($run in (Get-Runs)) {
        if ([string]$run.event -ne "push") { continue }
        if ([string]$run.headBranch -ne $script:RefName) { continue }
        if ([string]$run.headSha -ne $script:LocalSha) { continue }
        $created = [datetimeoffset]::Parse([string]$run.createdAt)
        if ($created -lt $recent) { continue }
        return $run
    }
    return $null
}

function Wait-Completion([string]$Id) {
    $deadline = (Get-Date).AddMinutes(45)
    $started = Get-Date
    while ((Get-Date) -lt $deadline) {
        $fields = "status,conclusion,url,headSha,event,headBranch"
        $result = Get-GhText run view $Id --repo $script:Repo --json $fields
        if ($result.Code -ne 0) {
            Die 1 "gh run view failed for $Id"
        }
        $view = (Join-NativeText $result.Output) | ConvertFrom-Json
        $elapsed = [int]((Get-Date) - $started).TotalSeconds
        Write-Host ("status={0} conclusion={1} elapsed={2}s" -f $view.status, $view.conclusion, $elapsed)
        Write-Host "RUN_URL=$($view.url)"
        if ([string]$view.status -eq "completed") { return $view }
        Start-Sleep -Seconds 20
    }
    Die 3 "DO_NOT_DISPATCH timed out waiting for run $Id. Do not dispatch another build. Resume with -Mode run -RunId $Id"
}

function Get-GhToken {
    if (-not [string]::IsNullOrWhiteSpace($env:GH_TOKEN)) { return $env:GH_TOKEN.Trim() }
    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_TOKEN)) { return $env:GITHUB_TOKEN.Trim() }
    $token = & $script:Gh auth token
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace([string]$token)) {
        return ([string]$token).Trim()
    }
    return $null
}

function Save-IpaWithCurl([string]$Id, [string]$Tmp) {
    $token = Get-GhToken
    if (-not $token) {
        Die 1 "gh run download failed and no token was available for the curl fallback. Do not dispatch another build."
    }
    $metaText = & $script:Gh api "repos/$($script:Repo)/actions/runs/$Id/artifacts"
    if ($LASTEXITCODE -ne 0) {
        Die 1 "Could not list artifacts for run $Id. Do not dispatch another build."
    }
    $meta = (Join-NativeText $metaText) | ConvertFrom-Json
    $art = @($meta.artifacts) | Where-Object { $_.name -eq $Artifact -and -not $_.expired } | Select-Object -First 1
    if (-not $art) {
        Die 1 "Run $Id has no artifact named $Artifact. Do not dispatch another build."
    }
    if (Test-Path -LiteralPath $Tmp) { Remove-Item -LiteralPath $Tmp -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $Tmp | Out-Null
    $zip = Join-Path $Tmp "artifact.zip"
    $apiUrl = "https://api.github.com/repos/$($script:Repo)/actions/artifacts/$($art.id)/zip"
    & curl.exe -sS -L --retry 3 --retry-delay 5 --retry-all-errors -H "Authorization: Bearer $token" -H "Accept: application/vnd.github+json" -o $zip $apiUrl
    if ($LASTEXITCODE -ne 0) {
        Die 1 "curl could not download artifact $($art.id). Do not dispatch another build."
    }
    Expand-Archive -LiteralPath $zip -DestinationPath $Tmp -Force
}

function Save-Ipa($View, [string]$Id) {
    $tmp = Join-Path $env:TEMP "xiaoyier-ipa-$Id"
    $downloaded = $false
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        if (Test-Path -LiteralPath $tmp) {
            Remove-Item -LiteralPath $tmp -Recurse -Force
        }
        New-Item -ItemType Directory -Force -Path $tmp | Out-Null
        & $script:Gh run download $Id --repo $script:Repo --name $Artifact --dir $tmp
        if ($LASTEXITCODE -eq 0) {
            $downloaded = $true
            break
        }
        Write-Host "DOWNLOAD_ATTEMPT=$attempt failed"
        if ($attempt -lt 3) { Start-Sleep -Seconds 15 }
    }
    if (-not $downloaded) {
        Write-Host "DOWNLOAD_FALLBACK=curl"
        Save-IpaWithCurl $Id $tmp
    }
    $ipa = Get-ChildItem -LiteralPath $tmp -Filter *.ipa -Recurse |
        Sort-Object Length -Descending |
        Select-Object -First 1
    if (-not $ipa -or $ipa.Length -le 0) {
        Die 1 "Artifact $Artifact did not contain an ipa."
    }
    $stream = [System.IO.File]::OpenRead($ipa.FullName)
    try {
        $b0 = $stream.ReadByte()
        $b1 = $stream.ReadByte()
    } finally {
        $stream.Close()
    }
    if ($b0 -ne 0x50 -or $b1 -ne 0x4B) {
        Die 1 "Downloaded file is not a zip/ipa."
    }
    $destDir = Join-Path $script:Root $OutDir
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    $dest = Join-Path $destDir "xiaoyier-unsigned.ipa"
    Copy-Item -LiteralPath $ipa.FullName -Destination $dest -Force
    $item = Get-Item -LiteralPath $dest
    $receipt = [ordered]@{
        repo    = $script:Repo
        ref     = [string]$View.headBranch
        sha     = [string]$View.headSha
        runId   = $Id
        url     = [string]$View.url
        ipa     = $dest
        bytes   = $item.Length
        builtAt = [datetimeoffset]::UtcNow.ToString("o")
    }
    $receiptPath = Join-Path $destDir "ipa-build.json"
    $receipt | ConvertTo-Json | Set-Content -LiteralPath $receiptPath -Encoding UTF8
    $mb = [math]::Round($item.Length / 1MB, 1)
    Write-Host "BUILD_SHA=$($View.headSha)"
    Write-Host "IPA_MB=$mb"
    Write-Host "IPA_READY $dest"
}

function Save-FailureLog([string]$Id) {
    $destDir = Join-Path $script:Root $OutDir
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    $logPath = Join-Path $destDir "ipa-build-failure.log"
    $result = Get-GhText run view $Id --repo $script:Repo --log-failed
    $text = Join-NativeText $result.Output
    Set-Content -LiteralPath $logPath -Value $text -Encoding UTF8
    Write-Host "FAILURE_LOG=$logPath"
    $lines = @(Get-Content -LiteralPath $logPath -Tail 80 -ErrorAction SilentlyContinue)
    foreach ($line in $lines) { Write-Host $line }
}

$script:Root = Resolve-RepoRoot
Set-Location -LiteralPath $script:Root
Write-Host "MODE=$Mode"
Write-Host "ROOT=$($script:Root)"

$remoteUrl = (Invoke-Git remote get-url origin).Trim().TrimEnd("/")
if ($remoteUrl -notmatch '(?i)github\.com[:/]lamianyuwan521/plan(\.git)?$') {
    Die 1 "origin is '$remoteUrl', expected github.com/lamianyuwan521/plan. Refusing to dispatch."
}

$script:Gh = Resolve-GhPath
Write-Host "GH=$($script:Gh)"
& $script:Gh auth status
if ($LASTEXITCODE -ne 0) {
    Die 1 "gh is not logged in. Ask the user to run 'gh auth login' (Actions read/write). Do not invent a token."
}

if (-not $Ref) {
    $Ref = (Invoke-Git rev-parse --abbrev-ref HEAD).Trim()
}
if ($Ref -eq "HEAD") {
    Die 1 "Detached HEAD. Pass -Ref explicitly."
}
$script:RefName = $Ref
$script:LocalSha = (Invoke-Git rev-parse HEAD).Trim()

if ($Mode -eq "run") {
    if (-not $RunId) { Die 1 "Mode run requires -RunId." }
    Enter-Lock
    try {
        $view = Wait-Completion $RunId
        if ([string]$view.conclusion -ne "success") {
            Save-FailureLog $RunId
            Die 1 "Run $RunId finished with conclusion=$($view.conclusion). No IPA from this run."
        }
        Save-Ipa $view $RunId
    } finally {
        Release-Lock
    }
    exit 0
}

& git -C $script:Root fetch origin $script:RefName
if ($LASTEXITCODE -ne 0) {
    Die 1 "FETCH_FAILED origin/$($script:RefName). No workflow was started. Restore access to github.com and rerun this script. Do not dispatch another way."
}
& git -C $script:Root rev-parse --verify --quiet "refs/remotes/origin/$($script:RefName)"
if ($LASTEXITCODE -ne 0) {
    Die 1 "origin/$($script:RefName) does not exist. Push the branch before building."
}
$script:RemoteSha = (Invoke-Git rev-parse "origin/$($script:RefName)").Trim()
Write-Host "REF=$($script:RefName)"
Write-Host "BUILD_SHA=$($script:RemoteSha)"
Test-IsStale

if ($Mode -eq "push" -and $script:RefName -ne "main") {
    Write-Host "NO_PUSH_RUN"
    Write-Host "Push to $($script:RefName) does not start ios-build.yml. Rerun with -Mode dispatch."
    exit 2
}

Enter-Lock
try {
    $run = $null
    if ($Mode -eq "dispatch") {
        $existing = Get-Runs
        $script:MaxId = [int64]0
        foreach ($item in $existing) {
            $idValue = [int64]$item.databaseId
            if ($idValue -gt $script:MaxId) { $script:MaxId = $idValue }
        }
        & $script:Gh workflow run $Workflow --repo $script:Repo --ref $script:RefName
        if ($LASTEXITCODE -ne 0) {
            Die 1 "gh workflow run failed. No follow-up dispatch."
        }
        Write-Host "DISPATCHED ref=$($script:RefName) sha=$($script:RemoteSha)"
        $run = Wait-ForMatch -Finder { Find-DispatchRun } -TimeoutSec 180 -MissingCode 3 -MissingMessage "DO_NOT_DISPATCH workflow_dispatch was sent but the run is not visible yet. Do not dispatch again. Check https://github.com/$($script:Repo)/actions/workflows/$Workflow"
    } elseif ($Mode -eq "push") {
        $run = Wait-ForMatch -Finder { Find-PushRun } -TimeoutSec 180 -MissingCode 3 -MissingMessage "DO_NOT_DISPATCH push to main should have started a run for $($script:LocalSha), but it is not visible yet. Do not workflow_dispatch. Check https://github.com/$($script:Repo)/actions/workflows/$Workflow"
    } else {
        Die 1 "Unknown mode $Mode"
    }

    $id = [string]$run.databaseId
    Write-Host "RUN_ID=$id"
    Write-Host "RUN_URL=$($run.url)"
    $view = Wait-Completion $id
    if ([string]$view.conclusion -ne "success") {
        Save-FailureLog $id
        Die 1 "Run $id finished with conclusion=$($view.conclusion). No IPA from this run."
    }
    Save-Ipa $view $id
} finally {
    Release-Lock
}
exit 0
