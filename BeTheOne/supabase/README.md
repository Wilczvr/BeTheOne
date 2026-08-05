# Uruchomienie Ligi BeTheOne w Supabase

Ten katalog zawiera kompletny fundament bazy dla Ligi BeTheOne. Na tym etapie
nie wysyłamy do Supabase dziennika, zdjęć progresu, masy ciała, kalorii ani
notatek. W chmurze znajdą się wyłącznie pseudonim, wygląd avatara i statystyki
potrzebne do rankingu.

## 1. Włącz logowanie anonimowe

1. Otwórz projekt `hpwkmhsbvqzsxqjkbccr` w panelu Supabase.
2. Przejdź do `Authentication` -> `Sign In / Providers`.
3. Otwórz `Anonymous Sign-Ins`.
4. Włącz tę opcję i zapisz zmianę.

Bez tej opcji aplikacja nie może utworzyć bezpiecznej, prywatnej tożsamości
uczestnika bez wymagania adresu e-mail. Oficjalna dokumentacja:
https://supabase.com/docs/guides/auth/auth-anonymous

Uwaga: konto anonimowe jest początkowo przypisane do danego urządzenia. W
docelowej implementacji dodamy możliwość powiązania go z e-mailem albo
bezpiecznego odzyskania tożsamości. Usunięcie danych przeglądarki przed tym
etapem może usunąć dostęp do anonimowego profilu ligi.

## 1a. Włącz email OTP do odzyskiwania hasła

1. Przejdź do `Authentication` -> `Sign In / Providers`.
2. Włącz provider `Email`.
3. Upewnij się, że wiadomość OTP pokazuje token `{{ .Token }}`. W BeTheOne używamy kodu, nie linku magicznego.
4. W `SQL Editor` uruchom cały plik `app-email-recovery.sql`.

Przejdź do `Authentication` -> `Email Templates` i w szablonach `Confirm signup`
oraz `Magic Link` zostaw tylko kod. Nie dodawaj `{{ .ConfirmationURL }}`, bo kliknięcie
linku może zużyć token i wtedy kod z tej samej wiadomości przestaje działać.

```html
<p>Twój kod tymczasowy BeTheOne:</p>
<p style="font-size: 24px; font-weight: 700; letter-spacing: 4px;">{{ .Token }}</p>
<p>Wpisz ten kod w aplikacji. Nie klikaj linku magicznego, jeśli stary szablon maila jeszcze go zawiera.</p>
```

W `Authentication` -> `URL Configuration` dodaj też adres, z którego uruchamiasz aplikację,
np. `http://localhost:3000` albo właściwy adres lokalny/hostingowy. Przy trybie kod-only link
nie jest potrzebny, ale poprawna konfiguracja URL ogranicza błędy, jeśli Supabase albo stary
szablon nadal wygeneruje link.

### SMTP bez mieszania z adresem aplikacji

Jeśli chcesz szybko sprawdzić, czy kod aplikacji działa, najpierw wyłącz `Enable custom SMTP`
i wyślij maila testowo przez domyślną wysyłkę Supabase. Jeśli Supabase odrzuci adres jako
nieautoryzowany, dodaj ten adres do zespołu projektu albo przejdź na custom SMTP.

Dla Gmaila custom SMTP ustaw tak:

```text
Enable custom SMTP: ON
Sender email address: twoj-adres@gmail.com
Sender name: BeTheOne
Host: smtp.gmail.com
Port number: 465
Username: twoj-adres@gmail.com
Password: hasło aplikacji Google, nie zwykłe hasło do Gmaila
Minimum interval per user: 60 seconds
```

Adres `http://localhost:3000` albo adres hostingu wpisuj wyłącznie w `URL Configuration`,
nie w `SMTP Settings`. Pole `Host` SMTP zawsze oznacza serwer pocztowy, np. `smtp.gmail.com`.

Ten skrypt tworzy tabelę `app_email_recovery` z RLS. Aplikacja zapisuje w niej
wyłącznie sekret odzyskiwania powiązany ze zweryfikowanym użytkownikiem Supabase.
Dziennik, zdjęcia, masa ciała, kalorie i notatki nadal pozostają w zaszyfrowanym
vaultcie lokalnym albo w zaszyfrowanej kopii `app_vault_sync`.

## 2. Utwórz bazę Ligi

1. Przejdź do `SQL Editor` -> `New query`.
2. Otwórz lokalny plik `league-schema.sql`.
3. Wklej całą jego zawartość do edytora.
4. Kliknij `Run` tylko raz i poczekaj na komunikat o powodzeniu.

Skrypt jest idempotentny: można uruchomić go ponownie podczas dalszego rozwoju.
Tworzy on:

- profile rywalizacyjne,
- ligi i członkostwa,
- jeden wspólny token zaproszenia,
- tygodniowe statystyki i ranking,
- rekordy osobiste,
- funkcje tworzenia, dołączania i opuszczania ligi,
- polityki Row Level Security,
- publikację Realtime dla rankingu oraz PR-ów.

## 3. Sprawdź instalację

1. Utwórz kolejne zapytanie w `SQL Editor`.
2. Wklej zawartość `verify-league.sql`.
3. Kliknij `Run`.

Prawidłowy wynik powinien pokazać:

- siedem obiektów ze statusem `OK`,
- `rls_enabled = true` dla sześciu tabel,
- co najmniej jedną politykę dla każdej tabeli,
- dwie tabele Realtime,
- siedem funkcji ze statusem `OK`.

Jeżeli tabela Realtime nie pojawi się w wyniku, sprawdź w `Database` ->
`Publications`, czy dla publikacji `supabase_realtime` zaznaczone są
`league_weekly_snapshots` i `league_personal_records`.

### Aktualizacja istniejącej instalacji

Jeżeli `league-schema.sql` został uruchomiony przed dodaniem integracji do
aplikacji, uruchom jeszcze raz plik `league-token-hotfix.sql` w SQL Editor.
Aktualizuje on trzy funkcje zaproszeń tak, aby korzystały z `pgcrypto` w
schemacie `extensions`, zgodnie z konfiguracją Supabase. Nie usuwa tabel,
profili ani żadnych istniejących danych.

## 4. Konfiguracja aplikacji

Publiczny adres projektu i publishable key są zapisane w pliku
`../league-config.js`. Klucz publishable jest przeznaczony do aplikacji
frontendowej, ale bezpieczeństwo zapewniają polityki RLS ze skryptu SQL.

Nigdy nie dodawaj do aplikacji ani nie przesyłaj:

- `service_role key`,
- hasła bazy danych,
- tokenów administracyjnych Supabase.

Plik `league-client-example.js` pokazuje gotowy kontrakt operacji klienta:
logowanie anonimowe, zapis avatara, tworzenie i dołączanie do ligi, publikację
wyników, pobranie rankingu oraz subskrypcję zmian na żywo. Nie jest jeszcze
ładowany przez `index.html`; zostanie podłączony razem z właściwą zakładką Liga.

## 5. Co będzie kolejnym etapem

Po prawidłowym uruchomieniu obu skryptów można bezpiecznie zbudować w BeTheOne:

- zakładkę `Liga`,
- tworzenie ligi i jednego QR dla wszystkich uczestników,
- dołączanie przez link w formacie `#league=<token>`,
- automatyczne wyliczanie tygodniowego podsumowania z lokalnego skarbca,
- ranking aktualizowany przez Supabase Realtime,
- obracanie kodu zaproszenia i usuwanie uczestników przez właściciela.

Dokumentacja bezpieczeństwa i Realtime:

- https://supabase.com/docs/guides/database/postgres/row-level-security
- https://supabase.com/docs/guides/realtime/postgres-changes
