-- Optional cleanup after integration testing.
-- This removes only the temporary league created during the Codex test run.

delete from public.leagues
where name = 'Test integracji BeTheOne';
