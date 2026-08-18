<#
.SYNOPSIS
    Odtwarza strukture katalogow i repozytoria na podstawie repos.json.

.DESCRIPTION
    Dla kazdego wpisu z konfiguracji:
      - jesli katalog nie istnieje -> git clone do wlasciwego miejsca
      - jesli repozytorium juz istnieje -> git fetch + aktualizacja (fast-forward)
      - jesli katalog istnieje, ale nie jest repo git -> pominiecie z ostrzezeniem

.EXAMPLE
    .\Restore-Repos.ps1
    .\Restore-Repos.ps1 -Config repos.json -Target D:\repos -UseHttps
    .\Restore-Repos.ps1 -SkipUpdate -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string] $Config,
    [string] $Target,
    [switch] $UseHttps,
    [switch] $SkipUpdate,
    [int]    $CloneDepth = 0
)

$ErrorActionPreference = 'Stop'

$base = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
if (-not $Config) { $Config = Join-Path $base 'repos.json' }
if (-not (Test-Path -LiteralPath $Config)) { throw "Nie znaleziono konfiguracji: $Config" }
$Config = (Resolve-Path -LiteralPath $Config).Path

if (-not $Target) { $Target = Split-Path -Parent $Config }
if (-not (Test-Path -LiteralPath $Target)) {
    if ($PSCmdlet.ShouldProcess($Target, 'Utworz katalog docelowy')) {
        New-Item -ItemType Directory -Path $Target -Force | Out-Null
    }
}
$Target = (Resolve-Path -LiteralPath $Target).Path

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'Nie znaleziono polecenia git w PATH.' }

$data  = Get-Content -LiteralPath $Config -Raw -Encoding UTF8 | ConvertFrom-Json
$repos = @($data.repositories)
if ($repos.Count -eq 0) { Write-Warning 'Konfiguracja nie zawiera repozytoriow.'; return }

Write-Host "Konfiguracja: $Config" -ForegroundColor Cyan
Write-Host "Katalog docelowy: $Target ($($repos.Count) repo)" -ForegroundColor Cyan

$summary = [ordered]@{ cloned = 0; updated = 0; skipped = 0; failed = 0 }

function Invoke-Git {
    param([string[]] $Arguments)
    $out = & git @Arguments 2>&1
    return [pscustomobject]@{ Ok = ($LASTEXITCODE -eq 0); Output = ($out -join [Environment]::NewLine) }
}

foreach ($repo in $repos) {
    $relative = if ($repo.path) { $repo.path } else { $repo.name }
    if (-not $relative -or -not $repo.url) { Write-Warning 'Wpis bez path/url - pomijam.'; $summary.skipped++; continue }

    $dest = Join-Path $Target ($relative -replace '/', '\')
    $url  = $repo.url
    if ($UseHttps) { $url = $url -replace '^git@([^:]+):', 'https://$1/' }

    Write-Host ''
    Write-Host "[$relative]" -ForegroundColor Yellow

    $isRepo = (Test-Path -LiteralPath (Join-Path $dest '.git'))

    if (-not (Test-Path -LiteralPath $dest)) {
        $parent = Split-Path -Parent $dest
        if ($parent -and -not (Test-Path -LiteralPath $parent)) {
            if ($PSCmdlet.ShouldProcess($parent, 'Utworz katalog')) {
                New-Item -ItemType Directory -Path $parent -Force | Out-Null
            }
        }

        if ($PSCmdlet.ShouldProcess($dest, "git clone $url")) {
            $cloneArgs = @('clone')
            if ($CloneDepth -gt 0) { $cloneArgs += @('--depth', "$CloneDepth") }
            if ($repo.branch -and $repo.branch -notmatch '^[0-9a-f]{7,40}$') { $cloneArgs += @('--branch', $repo.branch) }
            $cloneArgs += @($url, $dest)

            $r = Invoke-Git $cloneArgs
            if ($r.Ok) { Write-Host '  sklonowano' -ForegroundColor Green; $summary.cloned++ }
            else       { Write-Warning "  blad klonowania:`n$($r.Output)"; $summary.failed++ }
        }
        continue
    }

    if (-not $isRepo) {
        Write-Warning '  katalog istnieje, ale to nie jest repozytorium git - pomijam.'
        $summary.skipped++
        continue
    }

    if ($SkipUpdate) { Write-Host '  istnieje - pomijam aktualizacje' -ForegroundColor DarkGray; $summary.skipped++; continue }

    if (-not $PSCmdlet.ShouldProcess($dest, 'git fetch + pull --ff-only')) { continue }

    $fetch = Invoke-Git @('-C', $dest, 'fetch', '--all', '--prune', '--tags')
    if (-not $fetch.Ok) { Write-Warning "  blad fetch:`n$($fetch.Output)"; $summary.failed++; continue }

    $dirty = Invoke-Git @('-C', $dest, 'status', '--porcelain')
    if ($dirty.Output.Trim()) {
        Write-Warning '  lokalne zmiany - pobrano tylko fetch, bez merge.'
        $summary.updated++
        continue
    }

    $pull = Invoke-Git @('-C', $dest, 'pull', '--ff-only')
    if ($pull.Ok) {
        if ($pull.Output -match 'Already up to date|Already up-to-date') { Write-Host '  aktualne' -ForegroundColor DarkGray }
        else { Write-Host '  zaktualizowano' -ForegroundColor Green }
        $summary.updated++
    } else {
        Write-Warning "  nie mozna zaktualizowac (fast-forward niemozliwy):`n$($pull.Output)"
        $summary.failed++
    }
}

Write-Host ''
Write-Host 'Podsumowanie:' -ForegroundColor Cyan
Write-Host ("  sklonowane : {0}" -f $summary.cloned)
Write-Host ("  aktualne   : {0}" -f $summary.updated)
Write-Host ("  pominiete  : {0}" -f $summary.skipped)
Write-Host ("  bledy      : {0}" -f $summary.failed)
