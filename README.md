# git-repo-manifest

Dwa skrypty PowerShell do inwentaryzacji i odtwarzania kolekcji repozytoriow git.

Traktuj to jak `package.json` dla katalogu pelnego sklonowanych repozytoriow: jeden
skrypt zapisuje stan do manifestu, drugi odtwarza go na dowolnej maszynie.

## Wymagania

- PowerShell 7+ (`pwsh`) — skrypty korzystaja z `[System.IO.Path]::GetRelativePath`
  z fallbackiem, ale byly testowane na 7.6
- `git` dostepny w `PATH`

## Export-Repos.ps1

Skanuje drzewo katalogow w poszukiwaniu repozytoriow git i generuje dwa pliki.

```powershell
pwsh .\Export-Repos.ps1 -Root L:\_public
```

Wynik:

| Plik | Zawartosc |
| --- | --- |
| `repos.json` | konfiguracja maszynowa: `name`, `path`, `url`, `branch`, `description` |
| `REPOS.md` | tabela zbiorcza + sekcja szczegolow dla czlowieka |

Parametry:

| Parametr | Domyslnie | Opis |
| --- | --- | --- |
| `-Root` | katalog skryptu | katalog do przeskanowania |
| `-ConfigPath` | `<Root>\repos.json` | sciezka wyjsciowa manifestu |
| `-MarkdownPath` | `<Root>\REPOS.md` | sciezka wyjsciowa dokumentu |
| `-Depth` | `3` | glebokosc rekurencji przy szukaniu `.git` |
| `-RefreshDescriptions` | — | nadpisz opisy recznie zmienione w `repos.json` |

### Opisy

Opis kazdego repozytorium jest wyciagany z pliku `README*` — brany jest pierwszy
sensowny akapit, z pominieciem naglowkow, badge'y, obrazkow, tabel, list, cytatow,
blokow kodu i komentarzy HTML.

**Opisy poprawione recznie w `repos.json` sa zachowywane** przy kolejnych
uruchomieniach. Zeby je nadpisac wersja z README, uzyj `-RefreshDescriptions`.

## Restore-Repos.ps1

Odtwarza strukture katalogow i repozytoria na podstawie `repos.json`.

```powershell
pwsh .\Restore-Repos.ps1 -Config repos.json -Target D:\repos -UseHttps
```

Zachowanie per repozytorium:

| Stan katalogu docelowego | Akcja |
| --- | --- |
| nie istnieje | `git clone` (z gałęzią z manifestu, jesli podana) |
| istnieje, jest repo git | `fetch --all --prune --tags` + `pull --ff-only` |
| istnieje, jest repo git, ma lokalne zmiany | tylko `fetch`, bez merge + ostrzezenie |
| istnieje, nie jest repo git | pominiecie + ostrzezenie |

Parametry:

| Parametr | Domyslnie | Opis |
| --- | --- | --- |
| `-Config` | `<skrypt>\repos.json` | manifest wejsciowy |
| `-Target` | katalog manifestu | gdzie odtworzyc strukture |
| `-UseHttps` | — | konwersja `git@host:x` na `https://host/x` |
| `-SkipUpdate` | — | istniejace repo pomijaj zamiast aktualizowac |
| `-CloneDepth` | `0` | `--depth N` przy klonowaniu (0 = pelna historia) |
| `-WhatIf` | — | pokaz co by sie stalo, bez wykonywania |

Na koncu wypisywane jest podsumowanie: sklonowane / aktualne / pominiete / bledy.

## Typowy przeplyw pracy

```powershell
# na maszynie zrodlowej
pwsh .\Export-Repos.ps1 -Root L:\_public
# ...commit repos.json gdzies, gdzie bedzie dostepny

# na nowej maszynie
pwsh .\Restore-Repos.ps1 -Config repos.json -Target L:\_public -UseHttps
```

## Uwagi

- `repos.json` i `REPOS.md` w katalogu glownym sa **wersjonowane** — to jednoczesnie
  narzedzie i aktualny manifest kolekcji publicznych repozytoriow autora.
  `examples/repos.json` pokazuje format na mniejszym, recznie dopracowanym przykladzie
  (zagniezdzone sciezki, reczny opis).
- Sklonowane repozytoria w katalogu glownym sa ignorowane przez `.gitignore` (`/*/`),
  wiec mozna bezpiecznie uruchomic `Restore-Repos.ps1` wewnatrz tego repo.
- Skrypty nie usuwaja niczego: repozytoria usuniete z manifestu zostaja na dysku.
- `Restore-Repos.ps1` nigdy nie robi merge przy brudnym drzewie roboczym.
