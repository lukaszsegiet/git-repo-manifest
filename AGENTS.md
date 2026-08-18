# Kontekst projektu dla agenta

Ten plik jest dla Copilota/agenta wracajacego do projektu po przerwie. Opisuje
**dlaczego** rzeczy wygladaja tak, jak wygladaja, i co jest juz przemyslane.

## Cel projektu

Uzytkownik trzyma kolekcje sklonowanych publicznych repozytoriow w `L:\_public\`.
Potrzebowal sposobu, zeby (a) miec czytelna liste tego, co tam jest, i (b) odtworzyc
caly zestaw na innej maszynie. Stad dwa skrypty:

- `Export-Repos.ps1` — katalog na dysku → `repos.json` + `REPOS.md`
- `Restore-Repos.ps1` — `repos.json` → katalogi na dysku

Wzorzec myslowy: `Brewfile` / `package.json`, ale dla repozytoriow git.

## Decyzje projektowe (nie zmieniaj bez powodu)

1. **PowerShell 7, nie 5.1.** `Get-ChildItem -Depth`, `[System.IO.Path]::GetRelativePath`
   i operator `-in` sa wygodniejsze. W `Export-Repos.ps1` jest fallback dla
   `GetRelativePath` (`.Substring`), gdyby ktos uruchomil na starszym runtime.
2. **`$PSScriptRoot` nie zawsze istnieje.** Skrypty uruchamiane przez `powershell -File`
   z innego katalogu mialy `$Root` ustawiony na katalog wywolania. Dlatego `-Root` jest
   pustym parametrem, a fallback (`$PSScriptRoot` → `$MyInvocation` → `Get-Location`)
   jest rozwiazywany w ciele skryptu.
3. **Opisy z README sa heurystyka i to jest OK.** Filtrowanie odrzuca naglowki, badge,
   HTML, komentarze `<!-- -->`, cytaty `>`, listy, tabele i bloki kodu. Bez tego
   `llm` dostawal opis "import tempfile import subprocess" (README generowany przez cog),
   a `coding-interview-university` — tekst z blockquote.
4. **Reczne opisy maja priorytet.** Przy kolejnym `Export-Repos.ps1` opisy juz obecne
   w `repos.json` sa zachowywane. To celowe: heurystyka nigdy nie bedzie idealna,
   uzytkownik ma poprawiac reczne i nie tracic tego. `-RefreshDescriptions` wymusza nadpisanie.
5. **`Restore-Repos.ps1` nigdy nie merguje brudnego drzewa.** Przy `git status --porcelain`
   niepustym robi tylko `fetch` i ostrzega. Nigdy `pull --rebase`, nigdy `reset --hard`.
   Uzytkownik moze miec lokalne eksperymenty w sklonowanym repo.
6. **`pull --ff-only`, nie `pull`.** Brak automatycznych merge commitow w cudzych repo.
7. **Nic nie jest usuwane.** Repozytorium usuniete z manifestu zostaje na dysku.
   Ewentualny `-Prune` musialby byc opt-in i pytac o potwierdzenie.

## Struktura repo

```
Export-Repos.ps1     # skan → manifest
Restore-Repos.ps1    # manifest → dysk
README.md            # dokumentacja uzytkownika
AGENTS.md            # ten plik
ROADMAP.md           # pomysly na dalsza rozbudowe
repos.json           # ZAKOMMITOWANY manifest kolekcji autora (L:\_public)
REPOS.md             # ZAKOMMITOWANA czytelna lista tej kolekcji
examples/repos.json  # przykladowy manifest (format, zagniezdzone sciezki)
.gitignore           # ignoruje sklonowane repo w korzeniu
```

**Repo pelni podwojna role:** jest narzedziem *i* publiczna lista repozytoriow autora.
Dlatego `repos.json` i `REPOS.md` w korzeniu sa wersjonowane — po uruchomieniu
`Export-Repos.ps1` na `L:\_public` pojawia sie jako zmodyfikowane i to jest oczekiwane.
Nie dodawaj ich do `.gitignore`.

**Uwaga:** `.gitignore` zawiera `/*/` — ignoruje wszystkie katalogi w korzeniu, bo
uzytkownik uruchomil `Restore-Repos.ps1` wewnatrz tego repo i wpadlo tu 10 sklonowanych
projektow. Katalogi projektu (`examples/`, `docs/`, `tests/`, `.github/`) sa odwyjatkowane
przez `!`. Dodajac nowy katalog projektu, dopisz dla niego `!`.

## Format manifestu

```json
{
  "generatedAt": "2026-08-18T10:43:00",
  "root": ".",
  "repositories": [
    {
      "name": "WinReg",
      "path": "cpp/WinReg",
      "url": "git@github.com:GiovanniDicanio/WinReg.git",
      "branch": "master",
      "description": "..."
    }
  ]
}
```

- `path` jest **wzgledny wobec roota** i uzywa `/` jako separatora (przenosnosc).
  `Restore-Repos.ps1` konwertuje na `\` przy budowaniu sciezki.
- `branch` moze byc SHA (detached HEAD) — `Restore-Repos.ps1` wykrywa to regexem
  `^[0-9a-f]{7,40}$` i wtedy nie przekazuje `--branch` do `git clone`.
- Zagniezdzone `path` (np. `cpp/WinReg`) sa obslugiwane — katalogi posrednie sa tworzone.

## Stan testow

Przetestowane recznie (brak automatycznych testow — patrz ROADMAP):

- `Export-Repos.ps1` na `L:\_public\` z 10 repozytoriami — OK
- `Restore-Repos.ps1` klon do pustego katalogu, w tym zagniezdzona sciezka `cpp/WinReg` — OK
- `Restore-Repos.ps1` drugie uruchomienie (update istniejacych) — OK
- katalog istniejacy, nie-git → poprawnie pominiety z ostrzezeniem — OK
- `-WhatIf` z nieistniejacym `-Target` — OK po fixie (patrz nizej)

Nie testowane: `-CloneDepth`, `-SkipUpdate`, detached HEAD, repo bez remote'a,
submodules, repozytoria wymagajace uwierzytelnienia.

### Naprawione bledy

- `-WhatIf` z nieistniejacym `-Target` wywalal sie na `Resolve-Path`, bo katalog nie
  zostal utworzony. Zamienione na `[System.IO.Path]::GetFullPath($Target, $pwd)`,
  ktore normalizuje sciezke bez wymagania jej istnienia. **Uwazaj na ten wzorzec przy
  dodawaniu nowych sciezek** — `Resolve-Path` zaklada istnienie.

## Konwencje

- Commity: Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`)
- Komunikaty skryptow po polsku, bez polskich znakow diakrytycznych
  (unikanie problemow z kodowaniem w konsoli Windows)
- Komentarze w kodzie po polsku, bez diakrytykow
- Blok `.SYNOPSIS` / `.DESCRIPTION` / `.EXAMPLE` w naglowku kazdego skryptu
