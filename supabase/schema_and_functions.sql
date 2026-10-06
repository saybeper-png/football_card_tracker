-- ============================================================================
-- ENUM ТИПЫ
-- ============================================================================
CREATE TYPE card_skin_type AS ENUM ('gold', 'totw', 'icon');
CREATE TYPE shop_category AS ENUM ('card_fx', 'card_patch', 'booster', 'sfx_pack', 'celebration');
CREATE TYPE redemption_status AS ENUM ('completed', 'pending', 'approved', 'fulfilled', 'rejected');

-- ============================================================================
-- ТАБЛИЦЫ
-- ============================================================================
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    first_name VARCHAR(60) NOT NULL,
    last_name VARCHAR(60) NOT NULL,
    avatar_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS player_parents (
    parent_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    player_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (parent_id, player_id)
);

CREATE TABLE IF NOT EXISTS player_profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    jersey_number SMALLINT,
    position VARCHAR(10) NOT NULL DEFAULT 'ST',
    club_name VARCHAR(100) DEFAULT 'Football Academy',
    age_group VARCHAR(20) DEFAULT 'U-11',
    level INT NOT NULL DEFAULT 1,
    total_xp INT NOT NULL DEFAULT 0,
    spendable_xp INT NOT NULL DEFAULT 0,
    streak_freezes INT NOT NULL DEFAULT 0 CHECK (streak_freezes BETWEEN 0 AND 2),
    last_freeze_used_date DATE,
    current_streak INT NOT NULL DEFAULT 0,
    max_streak INT NOT NULL DEFAULT 0,
    last_activity_date DATE,
    attr_dri SMALLINT NOT NULL DEFAULT 50 CHECK (attr_dri BETWEEN 1 AND 99),
    attr_spd SMALLINT NOT NULL DEFAULT 50 CHECK (attr_spd BETWEEN 1 AND 99),
    attr_pas SMALLINT NOT NULL DEFAULT 50 CHECK (attr_pas BETWEEN 1 AND 99),
    attr_tec SMALLINT NOT NULL DEFAULT 50 CHECK (attr_tec BETWEEN 1 AND 99),
    attr_wrk SMALLINT NOT NULL DEFAULT 50 CHECK (attr_wrk BETWEEN 1 AND 99),
    attr_pwr SMALLINT NOT NULL DEFAULT 50 CHECK (attr_pwr BETWEEN 1 AND 99),
    ovr SMALLINT GENERATED ALWAYS AS (
        ROUND((attr_dri + attr_spd + attr_pas + attr_tec + attr_wrk + attr_pwr) / 6.0)
    ) STORED,
    active_card_skin card_skin_type NOT NULL DEFAULT 'gold',
    photo_crop_meta JSONB DEFAULT '{"scale": 1.0, "dx": 0.0, "dy": 0.0}'::jsonb,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS workout_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    player_id UUID NOT NULL REFERENCES player_profiles(user_id) ON DELETE CASCADE,
    duration_minutes INT NOT NULL CHECK (duration_minutes > 0),
    xp_earned INT NOT NULL CHECK (xp_earned >= 0),
    is_coach_approved BOOLEAN NOT NULL DEFAULT FALSE,
    coach_feedback TEXT,
    attr_dri_delta SMALLINT NOT NULL DEFAULT 0,
    attr_spd_delta SMALLINT NOT NULL DEFAULT 0,
    attr_pas_delta SMALLINT NOT NULL DEFAULT 0,
    attr_tec_delta SMALLINT NOT NULL DEFAULT 0,
    attr_wrk_delta SMALLINT NOT NULL DEFAULT 0,
    attr_pwr_delta SMALLINT NOT NULL DEFAULT 0,
    completed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS shop_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sku VARCHAR(64) UNIQUE NOT NULL,
    title VARCHAR(120) NOT NULL,
    description TEXT,
    category shop_category NOT NULL,
    price_xp INT NOT NULL CHECK (price_xp > 0),
    min_ovr_required SMALLINT NOT NULL DEFAULT 0,
    min_streak_required INT NOT NULL DEFAULT 0,
    duration_hours INT,
    config_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS player_inventory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    player_id UUID NOT NULL REFERENCES player_profiles(user_id) ON DELETE CASCADE,
    item_id UUID NOT NULL REFERENCES shop_items(id) ON DELETE RESTRICT,
    is_equipped BOOLEAN NOT NULL DEFAULT FALSE,
    expires_at TIMESTAMPTZ,
    acquired_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_player_inventory_item UNIQUE (player_id, item_id)
);

CREATE TABLE IF NOT EXISTS parental_rewards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    player_id UUID NOT NULL REFERENCES player_profiles(user_id) ON DELETE CASCADE,
    title VARCHAR(150) NOT NULL,
    description TEXT,
    icon_emoji VARCHAR(8) NOT NULL DEFAULT '🎁',
    price_xp INT NOT NULL CHECK (price_xp >= 50),
    is_reusable BOOLEAN NOT NULL DEFAULT TRUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS reward_redemptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    player_id UUID NOT NULL REFERENCES player_profiles(user_id) ON DELETE CASCADE,
    shop_item_id UUID REFERENCES shop_items(id) ON DELETE SET NULL,
    parental_reward_id UUID REFERENCES parental_rewards(id) ON DELETE SET NULL,
    xp_spent INT NOT NULL CHECK (xp_spent > 0),
    status redemption_status NOT NULL DEFAULT 'pending',
    handled_by_parent_id UUID REFERENCES users(id) ON DELETE SET NULL,
    handled_at TIMESTAMPTZ,
    rejection_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_reward_target_exclusive CHECK (
        (shop_item_id IS NOT NULL AND parental_reward_id IS NULL) OR
        (shop_item_id IS NULL AND parental_reward_id IS NOT NULL)
    )
);

CREATE TABLE IF NOT EXISTS user_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    fcm_token TEXT NOT NULL,
    device_platform VARCHAR(10) NOT NULL,
    timezone VARCHAR(50) NOT NULL DEFAULT 'Europe/Moscow',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_user_device UNIQUE (user_id, fcm_token)
);

-- ============================================================================
-- ХРАНИМЫЕ ПРОЦЕДУРЫ И ФУНКЦИИ
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_is_parent_of(p_player_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM player_parents
        WHERE parent_id = (SELECT auth.uid()) AND player_id = p_player_id
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION fn_set_player_card_skin(p_player_id UUID, p_skin card_skin_type)
RETURNS JSONB AS $$
DECLARE
    v_player player_profiles%ROWTYPE;
BEGIN
    IF auth.uid() IS NOT NULL AND auth.uid() <> p_player_id THEN
        RAISE EXCEPTION 'Access denied' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_player FROM player_profiles WHERE user_id = p_player_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Player not found'; END IF;

    IF p_skin = 'totw' AND v_player.current_streak < 7 THEN
        RAISE EXCEPTION 'TOTW requires 7 days streak';
    END IF;
    IF p_skin = 'icon' AND v_player.ovr < 75 THEN
        RAISE EXCEPTION 'Icon requires 75+ OVR';
    END IF;

    UPDATE player_profiles SET active_card_skin = p_skin, updated_at = NOW() WHERE user_id = p_player_id;
    RETURN jsonb_build_object('success', TRUE, 'active_card_skin', p_skin);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION fn_buy_streak_freeze(p_player_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_player player_profiles%ROWTYPE;
    v_cost CONSTANT INT := 300;
BEGIN
    IF auth.uid() IS NOT NULL AND auth.uid() <> p_player_id THEN
        RAISE EXCEPTION 'Access denied' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_player FROM player_profiles WHERE user_id = p_player_id FOR UPDATE;
    IF v_player.streak_freezes >= 2 THEN RAISE EXCEPTION 'Inventory full'; END IF;
    IF v_player.spendable_xp < v_cost THEN RAISE EXCEPTION 'Not enough XP'; END IF;

    UPDATE player_profiles
    SET spendable_xp = spendable_xp - v_cost,
        streak_freezes = streak_freezes + 1,
        updated_at = NOW()
    WHERE user_id = p_player_id;

    RETURN jsonb_build_object('success', TRUE, 'streak_freezes', v_player.streak_freezes + 1);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION fn_purchase_shop_item(p_player_id UUID, p_item_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_player player_profiles%ROWTYPE;
    v_item shop_items%ROWTYPE;
    v_expires_at TIMESTAMPTZ := NULL;
BEGIN
    SELECT * INTO v_player FROM player_profiles WHERE user_id = p_player_id FOR UPDATE;
    SELECT * INTO v_item FROM shop_items WHERE id = p_item_id AND is_active = TRUE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Item not found'; END IF;

    IF v_player.spendable_xp < v_item.price_xp THEN RAISE EXCEPTION 'Not enough XP'; END IF;
    IF v_player.ovr < v_item.min_ovr_required THEN RAISE EXCEPTION 'OVR too low'; END IF;
    IF v_player.current_streak < v_item.min_streak_required THEN RAISE EXCEPTION 'Streak too low'; END IF;

    IF v_item.duration_hours IS NOT NULL THEN
        v_expires_at := NOW() + (v_item.duration_hours || ' hours')::INTERVAL;
    END IF;

    UPDATE player_profiles SET spendable_xp = spendable_xp - v_item.price_xp, updated_at = NOW() WHERE user_id = p_player_id;

    INSERT INTO player_inventory (player_id, item_id, is_equipped, expires_at)
    VALUES (p_player_id, p_item_id, (v_item.category = 'card_fx'), v_expires_at)
    ON CONFLICT (player_id, item_id) DO UPDATE
    SET expires_at = CASE 
            WHEN v_expires_at IS NOT NULL THEN GREATEST(player_inventory.expires_at, NOW()) + (v_item.duration_hours || ' hours')::INTERVAL
            ELSE NULL 
        END,
        acquired_at = NOW();

    INSERT INTO reward_redemptions (player_id, shop_item_id, xp_spent, status, handled_at)
    VALUES (p_player_id, p_item_id, v_item.price_xp, 'completed', NOW());

    RETURN jsonb_build_object('success', TRUE, 'sku', v_item.sku, 'expires_at', v_expires_at);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION fn_redeem_parental_reward(p_player_id UUID, p_reward_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_player player_profiles%ROWTYPE;
    v_reward parental_rewards%ROWTYPE;
    v_redemption_id UUID;
BEGIN
    SELECT * INTO v_player FROM player_profiles WHERE user_id = p_player_id FOR UPDATE;
    SELECT * INTO v_reward FROM parental_rewards WHERE id = p_reward_id AND player_id = p_player_id AND is_active = TRUE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Reward not available'; END IF;
    IF v_player.spendable_xp < v_reward.price_xp THEN RAISE EXCEPTION 'Not enough XP'; END IF;

    UPDATE player_profiles SET spendable_xp = spendable_xp - v_reward.price_xp, updated_at = NOW() WHERE user_id = p_player_id;
    IF NOT v_reward.is_reusable THEN UPDATE parental_rewards SET is_active = FALSE WHERE id = p_reward_id; END IF;

    INSERT INTO reward_redemptions (player_id, parental_reward_id, xp_spent, status)
    VALUES (p_player_id, p_reward_id, v_reward.price_xp, 'pending')
    RETURNING id INTO v_redemption_id;

    RETURN jsonb_build_object('success', TRUE, 'redemption_id', v_redemption_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION fn_handle_parental_redemption(
    p_parent_id UUID,
    p_redemption_id UUID,
    p_decision redemption_status,
    p_rejection_reason TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_redemption reward_redemptions%ROWTYPE;
BEGIN
    SELECT * INTO v_redemption FROM reward_redemptions WHERE id = p_redemption_id FOR UPDATE;
    IF NOT FOUND OR v_redemption.status <> 'pending' THEN RAISE EXCEPTION 'Pending request not found'; END IF;

    IF NOT EXISTS (SELECT 1 FROM player_parents WHERE parent_id = p_parent_id AND player_id = v_redemption.player_id) THEN
        RAISE EXCEPTION 'Access denied' USING ERRCODE = '42501';
    END IF;

    IF p_decision = 'rejected' THEN
        UPDATE player_profiles SET spendable_xp = spendable_xp + v_redemption.xp_spent, updated_at = NOW() WHERE user_id = v_redemption.player_id;
        UPDATE parental_rewards SET is_active = TRUE WHERE id = v_redemption.parental_reward_id AND is_reusable = FALSE;
    END IF;

    UPDATE reward_redemptions
    SET status = p_decision, handled_by_parent_id = p_parent_id, handled_at = NOW(), rejection_reason = p_rejection_reason
    WHERE id = p_redemption_id;

    RETURN jsonb_build_object('success', TRUE, 'new_status', p_decision);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION fn_get_player_weekly_recap(p_player_id UUID, p_target_date DATE DEFAULT CURRENT_DATE)
RETURNS JSONB AS $$
DECLARE
    v_player RECORD;
    v_start_date DATE := date_trunc('week', p_target_date)::DATE;
    v_end_date DATE := v_start_date + 6;
    v_month_name TEXT;
    v_total_workouts INT := 0;
    v_total_minutes INT := 0;
    v_total_xp INT := 0;
    v_coach_approved_count INT := 0;
    v_latest_coach_feedback TEXT := 'Отличная работа на тренировках!';
    v_gain_dri INT := 0; v_gain_spd INT := 0; v_gain_pas INT := 0;
    v_gain_tec INT := 0; v_gain_wrk INT := 0; v_gain_pwr INT := 0;
    v_start_ovr INT;
    v_week_days JSONB;
BEGIN
    SELECT p.*, u.first_name, u.last_name, u.avatar_url INTO v_player
    FROM player_profiles p JOIN users u ON u.id = p.user_id WHERE p.user_id = p_player_id;

    SELECT COALESCE(COUNT(*), 0), COALESCE(SUM(duration_minutes), 0), COALESCE(SUM(xp_earned), 0),
           COALESCE(COUNT(*) FILTER (WHERE is_coach_approved = TRUE), 0),
           COALESCE(SUM(attr_dri_delta), 0), COALESCE(SUM(attr_spd_delta), 0), COALESCE(SUM(attr_pas_delta), 0),
           COALESCE(SUM(attr_tec_delta), 0), COALESCE(SUM(attr_wrk_delta), 0), COALESCE(SUM(attr_pwr_delta), 0)
    INTO v_total_workouts, v_total_minutes, v_total_xp, v_coach_approved_count,
         v_gain_dri, v_gain_spd, v_gain_pas, v_gain_tec, v_gain_wrk, v_gain_pwr
    FROM workout_sessions
    WHERE player_id = p_player_id AND completed_at::DATE BETWEEN v_start_date AND v_end_date;

    v_start_ovr := ROUND((
        GREATEST(1, v_player.attr_dri - v_gain_dri) + GREATEST(1, v_player.attr_spd - v_gain_spd) +
        GREATEST(1, v_player.attr_pas - v_gain_pas) + GREATEST(1, v_player.attr_tec - v_gain_tec) +
        GREATEST(1, v_player.attr_wrk - v_gain_wrk) + GREATEST(1, v_player.attr_pwr - v_gain_pwr)
    ) / 6.0);

    WITH week_series AS (
        SELECT generate_series(v_start_date, v_end_date, '1 day'::INTERVAL)::DATE AS day_date
    ),
    daily_w AS (
        SELECT completed_at::DATE AS w_date, SUM(duration_minutes) AS day_min
        FROM workout_sessions WHERE player_id = p_player_id AND completed_at::DATE BETWEEN v_start_date AND v_end_date
        GROUP BY completed_at::DATE
    )
    SELECT jsonb_agg(jsonb_build_object(
        'day_label', CASE EXTRACT(ISODOW FROM s.day_date)
            WHEN 1 THEN 'ПН' WHEN 2 THEN 'ВТ' WHEN 3 THEN 'СР' WHEN 4 THEN 'ЧТ'
            WHEN 5 THEN 'ПТ' WHEN 6 THEN 'СБ' WHEN 7 THEN 'ВС' END,
        'date', s.day_date,
        'minutes_trained', COALESCE(w.day_min, 0),
        'status', CASE 
            WHEN s.day_date > CURRENT_DATE THEN 'upcoming'
            WHEN COALESCE(w.day_min, 0) > 0 THEN 'completed'
            WHEN v_player.last_freeze_used_date = s.day_date THEN 'frozen'
            ELSE 'missed' END
    ) ORDER BY s.day_date) INTO v_week_days
    FROM week_series s LEFT JOIN daily_w w ON w.w_date = s.day_date;

    RETURN jsonb_build_object(
        'child_name', v_player.first_name,
        'child_avatar_url', v_player.avatar_url,
        'week_period', EXTRACT(DAY FROM v_start_date) || ' — ' || EXTRACT(DAY FROM v_end_date) || ' сентября',
        'start_ovr', v_start_ovr,
        'current_ovr', v_player.ovr,
        'xp_earned_this_week', v_total_xp,
        'total_workouts', v_total_workouts,
        'total_ball_minutes', v_total_minutes,
        'coach_approved_tasks', v_coach_approved_count,
        'week_days', v_week_days,
        'stat_increments', jsonb_strip_nulls(jsonb_build_object(
            'DRI', CASE WHEN v_gain_dri > 0 THEN v_gain_dri ELSE NULL END,
            'SPD', CASE WHEN v_gain_spd > 0 THEN v_gain_spd ELSE NULL END,
            'PAS', CASE WHEN v_gain_pas > 0 THEN v_gain_pas ELSE NULL END,
            'TEC', CASE WHEN v_gain_tec > 0 THEN v_gain_tec ELSE NULL END,
            'WRK', CASE WHEN v_gain_wrk > 0 THEN v_gain_wrk ELSE NULL END,
            'PWR', CASE WHEN v_gain_pwr > 0 THEN v_gain_pwr ELSE NULL END
        )),
        'coach_feedback', v_latest_coach_feedback
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- ============================================================================
-- RLS ПОЛИТИКИ
-- ============================================================================
ALTER TABLE shop_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE player_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE parental_rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE reward_redemptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "shop_items_read_active" ON shop_items FOR SELECT TO authenticated USING (is_active = TRUE);
CREATE POLICY "inventory_select" ON player_inventory FOR SELECT TO authenticated USING (player_id = (SELECT auth.uid()) OR fn_is_parent_of(player_id));
CREATE POLICY "inventory_update" ON player_inventory FOR UPDATE TO authenticated USING (player_id = (SELECT auth.uid())) WITH CHECK (player_id = (SELECT auth.uid()));
CREATE POLICY "parental_rewards_select" ON parental_rewards FOR SELECT TO authenticated USING (player_id = (SELECT auth.uid()) OR parent_id = (SELECT auth.uid()));
CREATE POLICY "parental_rewards_insert" ON parental_rewards FOR INSERT TO authenticated WITH CHECK (parent_id = (SELECT auth.uid()) AND fn_is_parent_of(player_id));
CREATE POLICY "parental_rewards_update" ON parental_rewards FOR UPDATE TO authenticated USING (parent_id = (SELECT auth.uid())) WITH CHECK (parent_id = (SELECT auth.uid()));
CREATE POLICY "redemptions_select" ON reward_redemptions FOR SELECT TO authenticated USING (player_id = (SELECT auth.uid()) OR fn_is_parent_of(player_id));

ALTER PUBLICATION supabase_realtime ADD TABLE reward_redemptions;