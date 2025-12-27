-- Ensure credit/moves tables and RPCs exist for proper deductions.

-- Create tables if missing
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE schemaname='public' AND tablename='credit_transactions') THEN
    CREATE TABLE public.credit_transactions (
      id bigserial PRIMARY KEY,
      player_id uuid NOT NULL,
      amount int NOT NULL,
      credit_type text,
      source text,
      created_at timestamptz DEFAULT now()
    );
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE schemaname='public' AND tablename='credit_refill_state') THEN
    CREATE TABLE public.credit_refill_state (
      player_id uuid PRIMARY KEY,
      moves_left int DEFAULT 0,
      updated_at timestamptz DEFAULT now()
    );
  END IF;
END$$;

-- Enable RLS
alter table if exists public.credit_transactions enable row level security;
alter table if exists public.credit_refill_state enable row level security;

-- Policies
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='credit_transactions' AND policyname='ct_service_all') THEN
    CREATE POLICY ct_service_all ON public.credit_transactions FOR ALL TO service_role USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='credit_transactions' AND policyname='ct_auth_all') THEN
    CREATE POLICY ct_auth_all ON public.credit_transactions FOR ALL TO authenticated USING (player_id = auth.uid()) WITH CHECK (player_id = auth.uid());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='credit_refill_state' AND policyname='crs_service_all') THEN
    CREATE POLICY crs_service_all ON public.credit_refill_state FOR ALL TO service_role USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='credit_refill_state' AND policyname='crs_auth_all') THEN
    CREATE POLICY crs_auth_all ON public.credit_refill_state FOR ALL TO authenticated USING (player_id = auth.uid()) WITH CHECK (player_id = auth.uid());
  END IF;
END$$;

DO $$
BEGIN
  DROP FUNCTION IF EXISTS public.player_balance CASCADE;
  DROP FUNCTION IF EXISTS public.player_moves_balance CASCADE;
  DROP FUNCTION IF EXISTS public.player_withdrawable CASCADE;
  DROP FUNCTION IF EXISTS public.consume_credits_rpc CASCADE;
  DROP FUNCTION IF EXISTS public.charge_run_attempt CASCADE;
END$$;

CREATE OR REPLACE FUNCTION public.player_balance(p_player_id uuid)
RETURNS int
LANGUAGE sql
AS $$
  SELECT COALESCE(SUM(amount), 0) FROM public.credit_transactions WHERE player_id = p_player_id;
$$;

CREATE OR REPLACE FUNCTION public.player_moves_balance(p_player_id uuid)
RETURNS int
LANGUAGE plpgsql
AS $$
DECLARE v_moves int := 0; BEGIN
  BEGIN
    SELECT moves_left INTO v_moves FROM public.credit_refill_state WHERE player_id = p_player_id;
  EXCEPTION WHEN undefined_table THEN
    v_moves := 0;
  END;
  RETURN COALESCE(v_moves, 0);
END;$$;

CREATE OR REPLACE FUNCTION public.player_withdrawable(p_player_id uuid)
RETURNS int
LANGUAGE sql
AS $$ SELECT 0; $$;

CREATE OR REPLACE FUNCTION public.consume_credits_rpc(p_player_id uuid, p_amount int, p_source text DEFAULT 'spend')
RETURNS int
LANGUAGE plpgsql
AS $$
DECLARE v_balance int := 0; BEGIN
  SELECT COALESCE(SUM(amount), 0) INTO v_balance FROM public.credit_transactions WHERE player_id = p_player_id;
  IF v_balance < p_amount THEN RAISE EXCEPTION 'Not enough credits'; END IF;
  INSERT INTO public.credit_transactions(player_id, amount, credit_type, source)
  VALUES (p_player_id, -p_amount, 'spend', p_source);
  SELECT COALESCE(SUM(amount), 0) INTO v_balance FROM public.credit_transactions WHERE player_id = p_player_id;
  RETURN v_balance;
END;$$;

CREATE OR REPLACE FUNCTION public.charge_run_attempt(
  p_player_id uuid,
  p_level_id bigint,
  p_nodes_count int,
  p_pipeline_hash text,
  p_last_pipeline_hash text,
  p_level_tier text
) RETURNS int
LANGUAGE plpgsql
AS $$
DECLARE v_balance int := 0; v_moves int := 0; BEGIN
  BEGIN
    SELECT moves_left INTO v_moves FROM public.credit_refill_state WHERE player_id = p_player_id FOR UPDATE;
  EXCEPTION WHEN undefined_table THEN
    v_moves := 0;
  END;
  IF NOT FOUND THEN
    INSERT INTO public.credit_refill_state(player_id, moves_left) VALUES (p_player_id, 0)
    ON CONFLICT (player_id) DO NOTHING;
  END IF;

  IF v_moves > 0 THEN
    UPDATE public.credit_refill_state SET moves_left = GREATEST(0, moves_left - 1) WHERE player_id = p_player_id;
  ELSE
    PERFORM public.consume_credits_rpc(p_player_id, 1, 'run_attempt');
  END IF;

  SELECT COALESCE(SUM(amount), 0) INTO v_balance FROM public.credit_transactions WHERE player_id = p_player_id FOR UPDATE;
  RETURN v_balance;
END;$$;
