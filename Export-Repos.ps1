<#
.SYNOPSIS
    Skanuje katalog z repozytoriami git i tworzy/aktualizuje:
      - repos.json  (konfiguracja: url + katalog)
      - REPOS.md    (czytelna lista z opisami)

.DESCRIPTION
    Opisy sa pobierane z pliku README repozytorium (pierwszy sensowny akapit).
    Recznie poprawione opisy w istniejacym repos.json sa zachowywane,
    chyba ze uzyto -RefreshDescriptions.

.EXAMPLE
    .\Export-Repos.ps1
    .\Export-Repos.ps1 -Root L:\_public -RefreshDescriptions
#>
[CmdletBinding()]
param(
    [string] $Root,
    [string] $ConfigPath,
    [string] $MarkdownPath,
    [int]    $Depth = 3,
    [switch] $RefreshDescriptions
)

$ErrorActionPreference = 'Stop'

if (-not $Root) {
    $Root = if ($PSScriptRoot) { $PSScriptRoot }
            elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path }
            else { (Get-Location).Path }
}
$Root = (Resolve-Path -LiteralPath $Root).Path
if (-not $ConfigPath)   { $ConfigPath   = Join-Path $Root 'repos.json' }
if (-not $MarkdownPath) { $MarkdownPath = Join-Path $Root 'REPOS.md' }

function Get-RepoDescription {
    param([string] $RepoPath)

    $readme = Get-ChildItem -LiteralPath $RepoPath -File -Filter 'README*' -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in '.md', '.markdown', '.rst', '.txt', '' } |
        Sort-Object { $_.Name -notmatch '(?i)^readme\.(md|markdown)$' }, Name |
        Select-Object -First 1

    if (-not $readme) {
        $readme = Get-ChildItem -LiteralPath $RepoPath -File -Filter 'readme*' -ErrorAction SilentlyContinue |
            Select-Object -First 1
    }
    if (-not $readme) { return '' }

    $lines = Get-Content -LiteralPath $readme.FullName -TotalCount 120 -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $lines) { return '' }

    $buffer = @()
    $inHtmlComment = $false
    foreach ($raw in $lines) {
        $line = $raw.Trim()

        if ($inHtmlComment) { if ($line -match '-->') { $inHtmlComment = $false }; continue }
        if ($line -match '^<!--') { if ($line -notmatch '-->') { $inHtmlComment = $true }; continue }

        if ($line -eq '') { if ($buffer.Count -gt 0) { break } else { continue } }
        if ($line -match '^(#{1,6}\s|=+$|-{3,}$|\*{3,}$)') { continue }   # naglowki / separatory
        if ($line -match '^(\||:?-+:?\|)') { continue }                   # tabele
        if ($line -match '^\s*<') { continue }                            # HTML
        if ($line -match '^\s*>') { continue }                            # cytaty
        if ($line -match '^\s*!?\[') { continue }                         # obrazki / badge
        if ($line -match '^\s*[-*+]\s') { continue }                      # listy
        if ($line -match '^\s*```') { break }                             # blok kodu

        $buffer += $line
        if (($buffer -join ' ').Length -gt 200) { break }
    }

    $text = ($buffer -join ' ')
    $text = $text -replace '!?\[([^\]]*)\]\([^)]*\)', '$1'   # linki markdown -> tekst
    $text = $text -replace '[`*_]', ''
    $text = ($text -replace '\s+', ' ').Trim()

    if ($text.Length -gt 220) {
        $cut = $text.Substring(0, 220)
        $dot = $cut.LastIndexOfAny([char[]]@('.', '!', '?'))
        if ($dot -gt 80) { $text = $cut.Substring(0, $dot + 1) } else { $text = $cut.TrimEnd() + '...' }
    }
    return $text
}

# --- istniejaca konfiguracja (zachowanie recznych opisow) ---------------------
$previous = @{}
if (Test-Path -LiteralPath $ConfigPath) {
    try {
        $old = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($r in @($old.repositories)) { if ($r.path) { $previous[$r.path] = $r } }
    } catch {
        Write-Warning "Nie udalo sie odczytac $ConfigPath : $($_.Exception.Message)"
    }
}

# --- skan repozytoriow -------------------------------------------------------
Write-Host "Skanowanie: $Root" -ForegroundColor Cyan
$gitDirs = Get-ChildItem -LiteralPath $Root -Directory -Recurse -Depth $Depth -Filter '.git' -Force -ErrorAction SilentlyContinue

$repos = foreach ($g in $gitDirs) {
    $repoPath = Split-Path -Parent $g.FullName
    $relative = if ([System.IO.Path].GetMethod('GetRelativePath', [type[]]@([string], [string]))) {
        [System.IO.Path]::GetRelativePath($Root, $repoPath)
    } else {
        $repoPath.Substring($Root.Length).TrimStart('\', '/')
    }
    $relative = $relative.Replace('\', '/')

    $url = (& git -C $repoPath remote get-url origin 2>$null | Select-Object -First 1)
    if (-not $url) {
        $firstRemote = (& git -C $repoPath remote 2>$null | Select-Object -First 1)
        if ($firstRemote) { $url = (& git -C $repoPath remote get-url $firstRemote 2>$null | Select-Object -First 1) }
    }
    if (-not $url) { Write-Warning "Pomijam '$relative' - brak zdalnego repozytorium."; continue }

    $branch = (& git -C $repoPath symbolic-ref --short HEAD 2>$null | Select-Object -First 1)
    if (-not $branch) { $branch = (& git -C $repoPath rev-parse --short HEAD 2>$null | Select-Object -First 1) }

    $lastCommit = (& git -C $repoPath log -1 --format=%cI 2>$null | Select-Object -First 1)

    $prev = $previous[$relative]
    $description =
        if ($prev -and $prev.description -and -not $RefreshDescriptions) { $prev.description }
        else { Get-RepoDescription -RepoPath $repoPath }

    [pscustomobject]@{
        name        = Split-Path -Leaf $repoPath
        path        = $relative
        url         = $url.Trim()
        branch      = $branch
        description = $description
        lastCommit  = $lastCommit
    }
}

$repos = @($repos | Sort-Object name)
if ($repos.Count -eq 0) { Write-Warning 'Nie znaleziono zadnych repozytoriow.'; return }

# --- repos.json --------------------------------------------------------------
$config = [pscustomobject]@{
    generatedAt  = (Get-Date).ToString('s')
    root         = '.'
    repositories = $repos | Select-Object name, path, url, branch, description
}
$config | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ConfigPath -Encoding UTF8
Write-Host "Zapisano: $ConfigPath ($($repos.Count) repo)" -ForegroundColor Green

# --- REPOS.md ----------------------------------------------------------------
$md = [System.Collections.Generic.List[string]]::new()
$md.Add('# Repozytoria publiczne')
$md.Add('')
$md.Add("Wygenerowano: $(Get-Date -Format 'yyyy-MM-dd HH:mm') - liczba repozytoriow: **$($repos.Count)**")
$md.Add('')
$md.Add('| Repozytorium | Opis | Zrodlo |')
$md.Add('| --- | --- | --- |')
foreach ($r in $repos) {
    $webUrl = $r.url -replace '^git@([^:]+):', 'https://$1/' -replace '\.git$', ''
    $desc   = if ($r.description) { $r.description -replace '\|', '\|' } else { '_brak opisu_' }
    $md.Add("| [$($r.name)]($webUrl) | $desc | ``$($r.url)`` |")
}
$md.Add('')
$md.Add('## Szczegoly')
$md.Add('')
foreach ($r in $repos) {
    $webUrl = $r.url -replace '^git@([^:]+):', 'https://$1/' -replace '\.git$', ''
    $md.Add("### $($r.name)")
    $md.Add('')
    $md.Add("- **Katalog:** ``$($r.path)``")
    $md.Add("- **URL:** [$webUrl]($webUrl)")
    if ($r.branch)     { $md.Add("- **Galaz:** ``$($r.branch)``") }
    if ($r.lastCommit) { $md.Add("- **Ostatni commit:** $($r.lastCommit)") }
    $md.Add('')
    if ($r.description) { $md.Add($r.description); $md.Add('') }
}
$md.Add('---')
$md.Add('')
$md.Add('Odtworzenie tego zestawu: `.\Restore-Repos.ps1`')

Set-Content -LiteralPath $MarkdownPath -Value ($md -join [Environment]::NewLine) -Encoding UTF8
Write-Host "Zapisano: $MarkdownPath" -ForegroundColor Green
