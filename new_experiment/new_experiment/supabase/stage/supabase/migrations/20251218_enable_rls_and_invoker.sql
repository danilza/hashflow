-- Enable RLS and add basic policies for public tables.
-- Uses defensive checks to avoid failures if objects are missing/altered in stage.

do $$
declare
  t text;
begin
  -- Enable RLS on all exposed tables
  for t in select unnest(array[
    'profiles',
    'players',
    'player_settings',
    'player_reputation',
    'player_moves',
    'solutions',
    'unique_pipelines',
    'nft_listings',
    'credit_transactions',
    'credit_refill_state',
    'free_run_state'
  ]) loop
    begin
      execute format('alter table public.%I enable row level security;', t);
    exception
      when undefined_table then null;
    end;
    -- Service role: full access
    if exists (select 1 from pg_tables where schemaname='public' and tablename=t)
       and not exists (select 1 from pg_policies where schemaname='public' and tablename=t and policyname='service_all') then
      execute format('create policy service_all on public.%I for all to service_role using (true) with check (true);', t);
    end if;
    -- Authenticated: allow reads by default to keep current app flows
    if exists (select 1 from pg_tables where schemaname='public' and tablename=t)
       and not exists (select 1 from pg_policies where schemaname='public' and tablename=t and policyname='auth_select') then
      execute format('create policy auth_select on public.%I for select to authenticated using (true);', t);
    end if;
  end loop;

  -- Ownership-scoped policies where columns are known
  if exists (select 1 from information_schema.columns where table_schema='public' and table_name='profiles' and column_name='id')
     and not exists (select 1 from pg_policies where schemaname='public' and tablename='profiles' and policyname='profiles_self_manage') then
    execute $sql$
      create policy profiles_self_manage
      on public.profiles
      for all
      to authenticated
      using (id = auth.uid())
      with check (id = auth.uid());
    $sql$;
  end if;

  if exists (select 1 from information_schema.columns where table_schema='public' and table_name='players' and column_name='id')
     and not exists (select 1 from pg_policies where schemaname='public' and tablename='players' and policyname='players_self_manage') then
    execute $sql$
      create policy players_self_manage
      on public.players
      for all
      to authenticated
      using (id = auth.uid())
      with check (id = auth.uid());
    $sql$;
  end if;

  -- Tables with player_id ownership
  for t in select unnest(array[
    'player_settings',
    'player_reputation',
    'player_moves',
    'credit_transactions',
    'credit_refill_state',
    'free_run_state',
    'solutions'
  ]) loop
    if exists (select 1 from information_schema.columns where table_schema='public' and table_name=t and column_name='player_id')
       and not exists (select 1 from pg_policies where schemaname='public' and tablename=t and policyname=t || '_auth_write') then
      execute format($fmt$
        create policy %I_auth_write
        on public.%I
        for all
        to authenticated
        using (player_id = auth.uid())
        with check (player_id = auth.uid());
      $fmt$, t, t);
    end if;
  end loop;

  -- Unique pipelines: owner-based writes, open reads already added
  if exists (select 1 from information_schema.columns where table_schema='public' and table_name='unique_pipelines' and column_name='owner_id')
     and not exists (select 1 from pg_policies where schemaname='public' and tablename='unique_pipelines' and policyname='unique_pipelines_owner_write') then
    execute $sql$
      create policy unique_pipelines_owner_write
      on public.unique_pipelines
      for all
      to authenticated
      using (owner_id = auth.uid())
      with check (owner_id = auth.uid());
    $sql$;
  end if;

  -- nft_listings: fall back to authenticated read; keep service_role for writes
  if exists (select 1 from pg_tables where schemaname='public' and tablename='nft_listings')
     and not exists (select 1 from pg_policies where schemaname='public' and tablename='nft_listings' and policyname='nft_listings_auth_read') then
    execute $sql$
      create policy nft_listings_auth_read
      on public.nft_listings
      for select
      to authenticated
      using (true);
    $sql$;
  end if;

  -- Switch views to SECURITY INVOKER to avoid definer bypassing RLS
  perform 1 from information_schema.views where table_schema='public' and table_name='player_level_solution_stats';
  if found then
    execute 'alter view public.player_level_solution_stats set (security_invoker = true);';
  end if;
  perform 1 from information_schema.views where table_schema='public' and table_name='mintable_unique_pipelines';
  if found then
    execute 'alter view public.mintable_unique_pipelines set (security_invoker = true);';
  end if;
  perform 1 from information_schema.views where table_schema='public' and table_name='level_unique_solution_counts';
  if found then
    execute 'alter view public.level_unique_solution_counts set (security_invoker = true);';
  end if;
end
$$;
