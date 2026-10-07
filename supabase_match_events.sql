-- Таблица событий матча (голы, ассисты, карточки)
CREATE TABLE IF NOT EXISTS match_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID REFERENCES matches(id) ON DELETE CASCADE,
    tournament_id UUID,
    team_id UUID REFERENCES teams(id) ON DELETE CASCADE,
    player_id UUID REFERENCES player_profiles(id) ON DELETE CASCADE,
    assist_player_id UUID REFERENCES player_profiles(id) ON DELETE SET NULL,
    event_type VARCHAR(20) NOT NULL DEFAULT 'goal',
    minute INT DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Индексы для мгновенного построения таблицы бомбардиров
CREATE INDEX IF NOT EXISTS idx_match_events_tournament ON match_events(tournament_id);
CREATE INDEX IF NOT EXISTS idx_match_events_match ON match_events(match_id);
CREATE INDEX IF NOT EXISTS idx_match_events_player ON match_events(player_id);