-- Ensure spending uses an allowed credit_type (paid) to satisfy existing check constraint.
CREATE OR REPLACE FUNCTION public.consume_credits_rpc(p_player_id uuid, p_amount int, p_source text DEFAULT 'spend')
RETURNS int
LANGUAGE plpgsql
AS $$
DECLARE v_balance int := 0; BEGIN
  SELECT COALESCE(SUM(amount), 0) INTO v_balance FROM public.credit_transactions WHERE player_id = p_player_id;
  IF v_balance < p_amount THEN RAISE EXCEPTION 'Not enough credits'; END IF;
  INSERT INTO public.credit_transactions(player_id, amount, credit_type, source)
  VALUES (p_player_id, -p_amount, 'paid', p_source);
  SELECT COALESCE(SUM(amount), 0) INTO v_balance FROM public.credit_transactions WHERE player_id = p_player_id;
  RETURN v_balance;
END;$$;

-- Recreate charge_run_attempt to use the updated consume_credits_rpc
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
