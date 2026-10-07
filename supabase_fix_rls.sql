-- Включаем RLS и настраиваем полный доступ (CRUD) для anon и authenticated ролей
DO $$
DECLARE
    tbl text;
    tables text[] := ARRAY['teams', 'matches', 'player_profiles', 'match_events', 'tournament_standings', 'tournaments', 'users'];
BEGIN
    FOREACH tbl IN ARRAY tables LOOP
        -- Включаем RLS
        EXECUTE format('ALTER TABLE IF EXISTS %I ENABLE ROW LEVEL SECURITY;', tbl);
        -- Удаляем старую политику, если существовала
        EXECUTE format('DROP POLICY IF EXISTS "public_all_%s" ON %I;', tbl, tbl);
        -- Создаем разрешающую политику для всех операций
        EXECUTE format('CREATE POLICY "public_all_%s" ON %I FOR ALL TO public USING (true) WITH CHECK (true);', tbl, tbl);
    END LOOP;
END $$;

-- Принудительное обновление кэша PostgREST
NOTIFY pgrst, 'reload schema';