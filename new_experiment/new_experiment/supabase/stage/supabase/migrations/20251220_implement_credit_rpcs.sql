-- RPCs for charging attempts and consuming credits. Assumes table public.credit_transactions(player_id uuid, amount int, credit_type text, source text, created_at timestamptz default now()) exists.

-- Drop old versions if exist
do $$
begin
  if exists (select 1 from pg_proc where proname = 'consume_credits_rpc' and pronamespace = 'public'::regnamespace) then
    drop function public.consume_credits_rpc(uuid, integer, text);
  end if;
  if exists (select 1 from pg_proc where proname = 'charge_run_attempt' and pronamespace = 'public'::regnamespace) then
    drop function public.charge_run_attempt(uuid, bigint, integer, text, text, text);
  end if;
end$$;

-- Consume explicit credits
create or replace function public.consume_credits_rpc(
  p_player_id uuid,
  p_amount int,
  p_source text
) returns int
language plpgsql
as $$
declare
  v_balance int := 0;
begin
  -- текущий баланс
  select coalesce(sum(amount), 0) into v_balance
  from public.credit_transactions
  where player_id = p_player_id;

  if v_balance < p_amount then
    raise exception 'Not enough credits';
  end if;

  insert into public.credit_transactions(player_id, amount, credit_type, source)
  values (p_player_id, -p_amount, 'spend', coalesce(p_source, 'spend'));

  select coalesce(sum(amount), 0) into v_balance
  from public.credit_transactions
  where player_id = p_player_id;

  return v_balance;
end;
$$;

-- Charge run attempt: spend move if >0, otherwise spend 1 credit
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
begin
  -- если free-run активен, возвращаем текущий баланс как есть
  if exists (select 1 from public.free_run_state fr where fr.player_id = p_player_id and fr.free_until > now()) then
    select coalesce(sum(amount), 0) into v_balance
    from public.credit_transactions
    where player_id = p_player_id;
    return v_balance;
  end if;

  -- пробуем списать ход: для простоты используем таблицу credit_refill_state как счётчик ходов
  if exists (select 1 from public.credit_refill_state crs where crs.player_id = p_player_id and crs.moves_left > 0) then
    update public.credit_refill_state
    set moves_left = moves_left - 1
    where player_id = p_player_id;
  else
    -- списываем 1 кредит
    perform public.consume_credits_rpc(p_player_id, 1, 'run_attempt');
  end if;

  select coalesce(sum(amount), 0) into v_balance
  from public.credit_transactions
  where player_id = p_player_id;
  return v_balance;
end;
$$;
