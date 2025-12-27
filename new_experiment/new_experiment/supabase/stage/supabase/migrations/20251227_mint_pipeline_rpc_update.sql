-- Rewrite mint_pipeline_nft_async_rpc to persist success/error and rely on helper HTTP call.
create or replace function public.mint_pipeline_nft_http_call(
  p_player_id uuid,
  p_level_id bigint,
  p_pipeline_hash text,
  p_raw jsonb,
  p_length int
) returns jsonb
language plpgsql
security definer
set search_path = public, net, extensions
as $$
declare
  v_service_key text;
  v_response jsonb;
begin
  select secret into v_service_key
  from vault.decrypted_secrets
  where name = 'SUPABASE_SERVICE_ROLE_KEY';
  if v_service_key is null then
    raise exception 'service role key missing';
  end if;

  v_response := net.http_request(
    url := 'https://mspqeumqitcomagyorvw.supabase.co/functions/v1/mint_nft',
    method := 'POST',
    headers := jsonb_build_object(
      'Content-Type','application/json',
      'Authorization','Bearer ' || v_service_key,
      'apikey', v_service_key
    ),
    body := jsonb_build_object(
      'player_id', p_player_id,
      'level_id', coalesce(p_level_id, NULL),
      'pipeline_hash', p_pipeline_hash,
      'pipeline_raw', p_raw,
      'pipeline_length', p_length
    ),
    timeout_milliseconds := 15000
  );
  return v_response;
end;
$$;

create or replace function public.mint_pipeline_nft_async_rpc_core(
  p_request_uid uuid,
  p_player_id uuid,
  p_level_id bigint,
  p_pipeline_hash text,
  p_cost int default 5
) returns text
language plpgsql
security definer
set search_path = public, net, extensions
set statement_timeout = '0'
as $$
declare
  v_uid uuid := p_request_uid;
  v_owner uuid;
  v_level bigint;
  v_length int;
  v_raw jsonb;
  v_status text;
  v_cost int := coalesce(p_cost, 5);
  v_wallet text;
  v_response jsonb;
  v_status_code int;
  v_mint_payload jsonb;
  v_minted_address text;
  got_lock boolean;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;
  if p_player_id <> v_uid then
    raise exception 'player_id mismatch';
  end if;

  got_lock := pg_try_advisory_xact_lock(hashtext(p_pipeline_hash));
  if not got_lock then
    raise exception 'mint already in progress';
  end if;

  select wallet_address into v_wallet
  from public.profiles
  where id = p_player_id;
  if v_wallet is null or length(trim(v_wallet)) = 0 then
    raise exception 'wallet_address is required';
  end if;

  select owner_id, level_id, pipeline_length, pipeline_raw, nft_status
  into v_owner, v_level, v_length, v_raw, v_status
  from public.unique_pipelines
  where pipeline_hash = p_pipeline_hash
  limit 1;

  if v_owner is null then
    raise exception 'pipeline not found';
  end if;
  if v_status in ('minted', 'minting') then
    raise exception 'already minted';
  end if;

  if v_cost <= 0 then
    v_cost := 5;
  end if;
  perform public.consume_credits(p_player_id, v_cost, 'mint');

  if v_owner <> p_player_id then
    insert into public.credit_transactions(player_id, amount, credit_type, source)
    values (v_owner, 1, 'earned', 'mint_share');
  end if;

  perform public.activate_free_run_hours(p_player_id, 24);

  update public.unique_pipelines
  set nft_status = 'minting',
      nft_error = null
  where pipeline_hash = p_pipeline_hash;

  v_response := public.mint_pipeline_nft_http_call(
    p_player_id => p_player_id,
    p_level_id => p_level_id,
    p_pipeline_hash => p_pipeline_hash,
    p_raw => v_raw,
    p_length => v_length
  );

  v_status_code := coalesce((v_response->>'status_code')::int, 0);
  if v_status_code between 200 and 299 then
    v_mint_payload := (v_response->>'body')::jsonb;
    v_minted_address := v_mint_payload->>'nft_address';
    update public.unique_pipelines
    set nft_status = 'minted',
        nft_address = coalesce(v_minted_address, v_wallet),
        minted_at = now(),
        nft_error = null
    where pipeline_hash = p_pipeline_hash;
    return 'ok';
  end if;

  update public.unique_pipelines
  set nft_status = 'failed',
      nft_error = coalesce(v_response->>'error', 'mint failed ' || coalesce(v_response->>'status_code','0'))
  where pipeline_hash = p_pipeline_hash;
  raise exception 'mint_nft failed %', p_pipeline_hash;
end;
$$;

create or replace function public.mint_pipeline_nft_async_rpc(
  p_player_id uuid,
  p_level_id bigint,
  p_pipeline_hash text,
  p_cost int default 5
) returns text
language plpgsql
security definer
set search_path = public, net, extensions
set statement_timeout = '0'
as $$
begin
  return public.mint_pipeline_nft_async_rpc_core(auth.uid(), p_player_id, p_level_id, p_pipeline_hash, p_cost);
end;
$$;

create or replace function public.mint_pipeline_nft_async_rpc_for_testing(
  p_request_uid uuid,
  p_player_id uuid,
  p_level_id bigint,
  p_pipeline_hash text,
  p_cost int default 5
) returns text
language plpgsql
security definer
set search_path = public, net, extensions
set statement_timeout = '0'
as $$
begin
  return public.mint_pipeline_nft_async_rpc_core(p_request_uid, p_player_id, p_level_id, p_pipeline_hash, p_cost);
end;
$$;
