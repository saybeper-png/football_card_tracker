-- 1. Добавляем тип спорта и формат в турниры
ALTER TABLE tournaments 
ADD COLUMN IF NOT EXISTS sport_type VARCHAR(20) DEFAULT 'football',
ADD COLUMN IF NOT EXISTS match_format VARCHAR(20) DEFAULT 'football_7x7';

-- 2. Добавляем командные фолы и тайм-ауты для футзала в таблицу матчей
ALTER TABLE matches 
ADD COLUMN IF NOT EXISTS sport_type VARCHAR(20) DEFAULT 'football',
ADD COLUMN IF NOT EXISTS home_fouls INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS away_fouls INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS home_timeouts INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS away_timeouts INT DEFAULT 0;

-- 3. Добавляем футзальное амплуа в профили игроков
ALTER TABLE player_profiles 
ADD COLUMN IF NOT EXISTS futsal_role VARCHAR(20) DEFAULT 'ALA';

-- 4. Комментарии к колонкам для документации схемы
COMMENT ON COLUMN matches.home_fouls IS 'Командные фолы хозяев (в футзале 6-й фол = дабл-пенальти 10м)';
COMMENT ON COLUMN matches.away_fouls IS 'Командные фолы гостей';