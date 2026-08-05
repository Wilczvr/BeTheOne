# BeTheOne: darmowy hosting HTTPS do testów

## Najważniejsze zasady bezpieczeństwa

1. Publikuj tylko katalog aplikacji: `avatar-image-stage`.
2. Nie publikuj eksportów kopii danych, plików backupu, prywatnych notatek ani żadnych danych użytkowników.
3. Dane użytkownika nadal są przechowywane lokalnie w przeglądarce i zaszyfrowanym vaultcie. Hosting widzi tylko statyczny kod aplikacji.
4. Service worker cache'uje wyłącznie statyczne pliki aplikacji, nie dane użytkownika ani zapytania do Supabase.
5. Po każdej większej aktualizacji podbijaj wersję w `app.js`, `sw.js` oraz query stringi w `index.html`, żeby użytkownicy dostali komunikat aktualizacji.

## Opcja A: GitHub Pages, najlepsza do regularnych aktualizacji

To jest najlepsza ścieżka, jeśli chcesz łatwo wysyłać znajomym nowe wersje.

1. Załóż nowe repozytorium na GitHub, np. `betheone-test`.
2. Wgraj zawartość katalogu `avatar-image-stage` do głównego katalogu repozytorium, czyli tak, żeby `index.html`, `app.js`, `styles.css`, `manifest.webmanifest` i `sw.js` były w root repo.
3. Wejdź w repozytorium na GitHub.
4. Otwórz `Settings`.
5. W menu bocznym wybierz `Pages`.
6. W `Build and deployment` ustaw `Source: Deploy from a branch`.
7. Wybierz branch `main` oraz folder `/(root)`.
8. Kliknij `Save`.
9. Po chwili aplikacja będzie dostępna pod adresem podobnym do `https://twoj-login.github.io/betheone-test/`.
10. W `Settings -> Pages` włącz `Enforce HTTPS`, jeśli nie jest już aktywne.

Aktualizacja aplikacji:

1. Wgraj zmienione pliki do repozytorium.
2. GitHub Pages sam opublikuje nową wersję.
3. Po wejściu do aplikacji service worker pobierze aktualizację i pokaże komunikat `Nowa wersja BeTheOne jest gotowa`.

## Opcja B: Netlify Drop, najszybszy test bez Gita

To jest najprostsze, gdy chcesz dostać link testowy w kilka minut.

1. Wejdź na `https://app.netlify.com/drop`.
2. Przeciągnij cały folder `avatar-image-stage` do okna Netlify Drop.
3. Netlify wygeneruje publiczny link HTTPS.
4. Wyślij link znajomym.

Aktualizacja aplikacji:

1. Po zmianach przeciągnij ponownie zaktualizowany folder do tego samego projektu w Netlify.
2. Jeśli korzystasz bez konta, link może być tymczasowy. Do dłuższych testów lepiej założyć darmowe konto albo użyć GitHub Pages.

## Co sprawdzić po publikacji

1. Otwórz stronę przez `https://`, nie `http://`.
2. W telefonie wybierz w przeglądarce `Dodaj do ekranu głównego` albo `Zainstaluj aplikację`.
3. Sprawdź, czy ikona BeTheOne pokazuje nową rubinową ikonę wilka.
4. Zaloguj się testowym kontem i upewnij się, że dane nie pojawiają się przed logowaniem.
5. Po aktualizacji odśwież stronę i sprawdź, czy pojawia się komunikat o nowej wersji.

## Źródła

- GitHub Pages: https://docs.github.com/en/pages/getting-started-with-github-pages
- GitHub Pages, publikowanie z brancha: https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site
- GitHub Pages, HTTPS: https://docs.github.com/en/pages/getting-started-with-github-pages/securing-your-github-pages-site-with-https
- Netlify Drop: https://app.netlify.com/drop
