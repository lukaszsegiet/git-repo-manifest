# Roadmap

Pomysly na dalsza rozbudowe, mniej wiecej w kolejnosci wartosc/koszt.

## Krotkoterminowo

- [ ] **Testy Pester** — `tests/` z testami na parsowaniu opisow z README
      (fixture'y w `tests/fixtures/`) i na logice wyboru akcji w `Restore-Repos.ps1`
      (clone / update / skip) z mockowanym `git`.
- [ ] **`-Prune` w `Restore-Repos.ps1`** — raportuj (a opcjonalnie usuwaj po
      potwierdzeniu) katalogi obecne na dysku, ale nieobecne w manifescie.
- [ ] **Tagi / kategorie w manifescie** — pole `tags: ["cpp", "llm", "cli"]`,
      grupowanie sekcji w `REPOS.md` wedlug tagow, filtr `-Tag` w `Restore-Repos.ps1`.
- [ ] **Rownolegle klonowanie** — `ForEach-Object -Parallel -ThrottleLimit 4`.
      Przy 10 repo nieistotne, przy 100 juz tak. Uwaga na mieszanie sie outputu.
- [ ] **Opis z GitHub API** — pole `description` z API jest zwykle lepsze niz
      heurystyka z README. Wymaga tokenu lub akceptacji limitu 60 req/h.
      Heurystyka README zostaje jako fallback.

## Sredniookresowo

- [ ] **Blokowanie commita (lock)** — zapis `commit` SHA w manifescie i tryb
      `-Pinned` w `Restore-Repos.ps1`, ktory checkoutuje dokladnie ten commit.
      Odtwarzalne srodowisko zamiast "najnowszy main".
- [ ] **Wsparcie dla submodules** — `git clone --recurse-submodules`,
      `git submodule update --init --recursive` przy update.
- [ ] **Obsluga wielu remote'ow** — obecnie brany jest `origin` (lub pierwszy z listy).
      Manifest moglby trzymac `remotes: { origin: "...", upstream: "..." }`.
- [ ] **`REPOS.md` z metrykami** — gwiazdki, jezyk, data ostatniego commita upstream,
      oznaczenie repozytoriow archiwalnych. Wymaga GitHub API.
- [ ] **Cross-platform** — skrypty sa PowerShell 7, wiec teoretycznie dzialaja na
      Linux/macOS. Trzeba przejrzec twarde `\` w sciezkach i przetestowac.

## Dlugoterminowo / do rozwazenia

- [ ] **Modul PowerShell** — `git-repo-manifest.psd1`, cmdlety
      `Export-RepoManifest` / `Restore-RepoManifest`, publikacja w PowerShell Gallery.
      Wtedy warto rozwazyc zmiane nazwy na `PSRepoManifest`.
- [ ] **GitHub Action** — workflow, ktory cyklicznie odswieza `REPOS.md`
      w repozytorium z kolekcja i commituje zmiany.
- [ ] **Wsparcie dla nie-GitHub hostow** — GitLab, Codeberg, Gitea.
      Konwersja `git@` → `https://` juz jest generyczna, ale linki w `REPOS.md`
      zakladaja strukture URL GitHuba.
- [ ] **Import z istniejacych zrodel** — wygenerowanie manifestu z listy gwiazdek
      uzytkownika na GitHubie albo z pliku `.gitmodules`.

## Swiadomie odrzucone

- **Automatyczny `git pull --rebase` lub `reset --hard`** — zbyt ryzykowne,
  uzytkownik moze miec lokalne zmiany w sklonowanych repo. Patrz AGENTS.md, decyzja 5.
- **Usuwanie repozytoriow domyslnie** — narzedzie ma byc bezpieczne w uruchomieniu
  "na slepo". Kazde usuwanie musi byc opt-in i potwierdzone.
