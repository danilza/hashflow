-- Remove score/respect auto-increments tied to solution inserts (new version)

do $$
begin
  if exists (select 1 from pg_trigger where tgname = 'trg_update_score_after_solution') then
    drop trigger trg_update_score_after_solution on public.solutions;
  end if;
  if exists (select 1 from pg_proc where proname = 'update_score_after_solution' and pronamespace = 'public'::regnamespace) then
    drop function public.update_score_after_solution();
  end if;
end$$;

-- Adjust record_unique_solution to stop calling update_score or altering credits
create or replace function public.record_unique_solution(
  p_player_id uuid,
  p_level_id bigint,
  p_pipeline_hash text,
  p_pipeline_raw jsonb,
  p_pipeline_length integer,
  p_wallet_address text default null
)
returns table(inserted boolean, nft_address text, mint_tx_hash text)
language plpgsql
as $function$
declare
  solution_inserted boolean := false;
  minted_address text;
  minted_tx text;
  minted_metadata_uri text;
  minted_timestamp timestamptz;
  new_solution_id bigint;
  target_wallet_address text;
begin
  target_wallet_address := nullif(trim(coalesce(p_wallet_address, '')), '');
  if target_wallet_address is null then
    select wallet_address into target_wallet_address
    from public.profiles
    where id = p_player_id
    limit 1;
  end if;

  insert into public.unique_pipelines (
      pipeline_hash,
      level_id,
      owner_id,
      pipeline_raw,
      pipeline_length,
      metadata_uri,
      nft_address,
      mint_tx_hash,
      nft_status,
      nft_error,
      minted_at
  )
  values (
      p_pipeline_hash,
      p_level_id,
      p_player_id,
      p_pipeline_raw,
      p_pipeline_length,
      null,
      null,
      null,
      'pending',
      null,
      null
  )
  on conflict (pipeline_hash) do nothing;

  if found then
    solution_inserted := true;
    insert into public.solutions (
        player_id,
        level_id,
        pipeline_hash,
        pipeline_raw,
        pipeline_length,
        nft_minted,
        nft_address,
        mint_tx_hash,
        nft_status,
        nft_error
    )
    values (
        p_player_id,
        p_level_id,
        p_pipeline_hash,
        p_pipeline_raw,
        p_pipeline_length,
        false,
        null,
        null,
        'pending',
        null
    )
    on conflict (pipeline_hash) do nothing
    returning id into new_solution_id;

    -- No score/credit mutation here. Minting handled elsewhere (edge/worker/client).
  end if;

  return query
  select solution_inserted, null::text as nft_address, null::text as mint_tx_hash;
end;
$function$;
