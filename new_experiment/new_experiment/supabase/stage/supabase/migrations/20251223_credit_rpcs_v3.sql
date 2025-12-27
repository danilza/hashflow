-- Replace credit RPCs again: force commit deductions.

begin;
  -- Drop old versions
  do $$
  begin
    if exists (select 1 from pg_proc where proname = 'consume_credits_rpc' and pronamespace = 'public'::regnamespace) then
      drop function public.consume_credits_rpc(uuid, integer, text);
    end if;
    if exists (select 1 from pg_proc where proname = 'charge_run_attempt' and pronamespace = 'public'::regnamespace) then
      drop function public.charge_run_attempt(uuid, bigint, integer, text, text, text);
    end if;
  end$$;

  create or replace function public.consume_credits_rpc(
    p_player_id uuid,
    p_amount int,
    p_source text default 'spend'
  ) returns int
  language plpgsql
  as $$
  declare
    v_balance int := 0;
  begin
    select coalesce(sum(amount), 0) into v_balance
    from public.credit_transactions
    where player_id = p_player_id;

    if v_balance < p_amount then
      raise exception 'Not enough credits';
    end if;

    insert into public.credit_transactions(player_id, amount, credit_type, source)
    values (p_player_id, -p_amount, 'spend', p_source);

    select coalesce(sum(amount), 0) into v_balance
    from public.credit_transactions
    where player_id = p_player_id;

    return v_balance;
  end;
  $$;

  create or replace function public.charge_run_attempt(
    p_player_id uuid,
    p_level_id bigint,
    p_nodes_count int,
    p_pipeline_hash text,
    p_last_pipeline_hash text,
    p_level_tier text
  ) returns int
  language plpgsql
  as $$
  declare
    v_balance int := 0;
    v_moves int := 0;
  begin
    -- lock row if exists
    begin
      select moves_left into v_moves
      from public.credit_refill_state
      where player_id = p_player_id
      for update;
    exception when undefined_table then
      v_moves := 0;
    end;

    if v_moves > 0 then
      update public.credit_refill_state
      set moves_left = greatest(0, moves_left - 1)
      where player_id = p_player_id;
    else
      perform public.consume_credits_rpc(p_player_id, 1, 'run_attempt');
    end if;

    select coalesce(sum(amount), 0) into v_balance
    from public.credit_transactions
    where player_id = p_player_id
    for update;

    return v_balance;
  end;
  $$;
commit;
