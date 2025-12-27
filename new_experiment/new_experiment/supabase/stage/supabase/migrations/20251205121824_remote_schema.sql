drop extension if exists "pg_net";

create extension if not exists "pg_net" with schema "public";


  create table "public"."email_otp" (
    "email" text not null,
    "otp" text not null,
    "expires_at" timestamp with time zone not null,
    "id" uuid not null default gen_random_uuid(),
    "created_at" timestamp with time zone not null default now()
      );


alter table "public"."email_otp" enable row level security;


  create table "public"."player_reputation" (
    "player_id" uuid not null,
    "unique_solutions" integer default 0,
    "respect" integer default 0,
    "updated_at" timestamp with time zone default now()
      );



  create table "public"."players" (
    "id" uuid not null default gen_random_uuid(),
    "username" text not null,
    "ton_wallet" text,
    "created_at" timestamp with time zone default now()
      );



  create table "public"."profiles" (
    "id" uuid not null default auth.uid(),
    "username" text,
    "created_at" timestamp with time zone default now(),
    "is_email_verified" boolean default false,
    "wallet_address" text,
    "wallet_address_verified_at" timestamp with time zone
      );



  create table "public"."score" (
    "player_id" uuid not null,
    "unique_solutions" integer default 0,
    "total_pipeline_length" integer default 0,
    "unique_levels_completed" integer default 0,
    "updated_at" timestamp with time zone default now()
      );

  create table "public"."player_progress" (
    "player_id" uuid not null default auth.uid(),
    "completed_levels" integer[] default '{}'::integer[],
    "highest_unlocked_level_id" integer default 1,
    "updated_at" timestamp with time zone default now()
      );


alter table "public"."score" enable row level security;

alter table "public"."player_progress" enable row level security;

alter table "public"."player_nft_items" enable row level security;


  create table "public"."solutions" (
    "id" bigint generated always as identity not null,
    "player_id" uuid,
    "level_id" bigint not null,
    "pipeline_hash" text not null,
    "pipeline_raw" jsonb not null,
    "pipeline_length" integer not null,
    "created_at" timestamp with time zone default now(),
    "nft_minted" boolean default false,
    "nft_address" text,
    "mint_tx_hash" text,
    "nft_status" text default 'pending',
    "nft_error" text
      );

  create table "public"."unique_pipelines" (
    "pipeline_hash" text not null,
    "level_id" bigint not null,
    "owner_id" uuid not null,
    "pipeline_raw" jsonb not null,
    "pipeline_length" integer not null,
    "metadata_uri" text,
    "nft_address" text,
    "mint_tx_hash" text,
    "nft_status" text default 'pending',
    "nft_error" text,
    "minted_at" timestamp with time zone,
    "created_at" timestamp with time zone default now()
      );

  create table "public"."player_nft_items" (
    "id" uuid not null default gen_random_uuid(),
    "player_id" uuid not null,
    "nft_address" text not null,
    "level_id" integer not null,
    "pipeline_hash" text not null,
    "created_at" timestamp with time zone default now()
      );


CREATE UNIQUE INDEX email_otp_pkey ON public.email_otp USING btree (id);

CREATE UNIQUE INDEX player_reputation_pkey ON public.player_reputation USING btree (player_id);

CREATE UNIQUE INDEX players_pkey ON public.players USING btree (id);

CREATE UNIQUE INDEX players_username_unique ON public.players USING btree (username);

CREATE UNIQUE INDEX profiles_pkey ON public.profiles USING btree (id);

CREATE UNIQUE INDEX score_pkey ON public.score USING btree (player_id);

CREATE UNIQUE INDEX unique_pipelines_pkey ON public.unique_pipelines USING btree (pipeline_hash);

CREATE UNIQUE INDEX player_progress_pkey ON public.player_progress USING btree (player_id);

CREATE UNIQUE INDEX player_nft_items_pkey ON public.player_nft_items USING btree (id);

CREATE UNIQUE INDEX player_nft_items_nft_address_key ON public.player_nft_items USING btree (nft_address);

CREATE UNIQUE INDEX solutions_pkey ON public.solutions USING btree (id);

CREATE UNIQUE INDEX solutions_pipeline_hash_key ON public.solutions USING btree (pipeline_hash);

CREATE UNIQUE INDEX solutions_unique_player_level_hash ON public.solutions USING btree (player_id, level_id, pipeline_hash);

alter table "public"."email_otp" add constraint "email_otp_pkey" PRIMARY KEY using index "email_otp_pkey";

alter table "public"."player_reputation" add constraint "player_reputation_pkey" PRIMARY KEY using index "player_reputation_pkey";

alter table "public"."players" add constraint "players_pkey" PRIMARY KEY using index "players_pkey";

alter table "public"."profiles" add constraint "profiles_pkey" PRIMARY KEY using index "profiles_pkey";

alter table "public"."score" add constraint "score_pkey" PRIMARY KEY using index "score_pkey";

alter table "public"."player_progress" add constraint "player_progress_pkey" PRIMARY KEY using index "player_progress_pkey";

alter table "public"."solutions" add constraint "solutions_pkey" PRIMARY KEY using index "solutions_pkey";

alter table "public"."player_nft_items" add constraint "player_nft_items_pkey" PRIMARY KEY using index "player_nft_items_pkey";

alter table "public"."player_nft_items" add constraint "player_nft_items_player_id_fkey" FOREIGN KEY (player_id) REFERENCES public.profiles(id) ON DELETE CASCADE not valid;

alter table "public"."player_nft_items" validate constraint "player_nft_items_player_id_fkey";

alter table "public"."player_nft_items" add constraint "player_nft_items_nft_address_key" UNIQUE using index "player_nft_items_nft_address_key";

alter table "public"."player_reputation" add constraint "fk_player_reputation_profile" FOREIGN KEY (player_id) REFERENCES public.profiles(id) not valid;

alter table "public"."player_reputation" validate constraint "fk_player_reputation_profile";

alter table "public"."player_reputation" add constraint "player_reputation_player_id_fkey" FOREIGN KEY (player_id) REFERENCES public.players(id) ON DELETE CASCADE not valid;

alter table "public"."player_reputation" validate constraint "player_reputation_player_id_fkey";

alter table "public"."score" add constraint "score_player_id_fkey" FOREIGN KEY (player_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."score" validate constraint "score_player_id_fkey";

alter table "public"."player_progress" add constraint "player_progress_player_id_fkey" FOREIGN KEY (player_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."player_progress" validate constraint "player_progress_player_id_fkey";

alter table "public"."solutions" add constraint "solutions_player_id_fkey" FOREIGN KEY (player_id) REFERENCES public.players(id) ON DELETE CASCADE not valid;

alter table "public"."solutions" validate constraint "solutions_player_id_fkey";

alter table "public"."solutions" add constraint "solutions_unique_player_level_hash" UNIQUE using index "solutions_unique_player_level_hash";

alter table "public"."solutions" add constraint "solutions_nft_status_check" CHECK (nft_status in ('pending'::text, 'minted'::text, 'failed'::text));

alter table "public"."unique_pipelines" add constraint "unique_pipelines_pkey" PRIMARY KEY using index "unique_pipelines_pkey";

alter table "public"."unique_pipelines" add constraint "unique_pipelines_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES public.players(id) ON DELETE CASCADE not valid;

alter table "public"."unique_pipelines" validate constraint "unique_pipelines_owner_id_fkey";

alter table "public"."unique_pipelines" add constraint "unique_pipelines_nft_status_check" CHECK (nft_status in ('pending'::text, 'minted'::text, 'failed'::text));

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.build_otp_payload(email text, otp text)
 RETURNS text
 LANGUAGE sql
AS $function$
  select format('{"email":"%s","otp":"%s"}', email, otp);
$function$
;

CREATE OR REPLACE FUNCTION public.confirm_email(p_email text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
    v_user_id uuid;
begin
    update auth.users
    set email_confirmed_at = now()
    where email = p_email
    returning id into v_user_id;

    -- гарантируем, что профиль существует
    insert into public.profiles (id, username)
    values (v_user_id, split_part(p_email, '@', 1))
    on conflict do nothing;

    -- отмечаем email подтверждённым
    update public.profiles
    set is_email_verified = true
    where id = v_user_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.get_player_level_stats(p_player_id uuid)
 RETURNS TABLE(level_id bigint, my_unique_solutions integer, all_unique_solutions integer, player_share_percent numeric, avg_pipeline_length numeric)
 LANGUAGE sql
AS $function$
  select
    level_id,
    my_unique_solutions,
    all_unique_solutions,
    player_share_percent,
    avg_pipeline_length
  from player_level_solution_stats
  where player_id = p_player_id
  order by level_id;
$function$
;

CREATE OR REPLACE FUNCTION public.get_player_solution_nfts(p_player_id uuid DEFAULT NULL)
 RETURNS TABLE(pipeline_hash text, level_id bigint, pipeline_length integer, metadata_uri text, nft_address text, mint_tx_hash text, minted_at timestamp with time zone)
 LANGUAGE sql
AS $function$
  select
    up.pipeline_hash,
    up.level_id,
    up.pipeline_length,
    up.metadata_uri,
    up.nft_address,
    up.mint_tx_hash,
    up.minted_at
  from public.player_nft_items pni
  join public.unique_pipelines up on up.pipeline_hash = pni.pipeline_hash
  where pni.player_id = coalesce(p_player_id, auth.uid())
    and pni.player_id = auth.uid()
  order by coalesce(up.minted_at, pni.created_at) desc nulls last, pni.created_at desc;
$function$
;

CREATE OR REPLACE FUNCTION public.handle_auth_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  v_username text;
begin
  -- если email есть → берем до @
  if new.email is not null then
    v_username := split_part(new.email, '@', 1);
  else
    -- если нет email (например password register ещё не подтвердил)
    -- используем user metadata или uid
    v_username := coalesce(new.raw_user_meta_data->>'username', new.id::text);
  end if;

  insert into public.profiles (id, username)
  values (new.id, v_username)
  on conflict do nothing;

  insert into public.players (id, username)
  values (new.id, v_username)
  on conflict do nothing;

  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.handle_missing_profile()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
begin
  insert into public.profiles (id, username)
  values (new.id, split_part(new.email, '@', 1))
  on conflict do nothing;

  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.http_request(url text, method text, headers jsonb, body text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
begin
  return (
    select pg_net.http_request(
      url := url,
      method := method,
      headers := headers,
      body := body
    )
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.leaderboard_by_unique_solutions()
 RETURNS TABLE(user_id uuid, username text, unique_solutions bigint, total_score bigint, last_score_date timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
    select
        profiles.id as user_id,
        profiles.username,
        count(distinct scores.mode || ':' || scores.score) as unique_solutions,
        sum(scores.score) as total_score,
        max(scores.created_at) as last_score_date
    from scores
    join profiles on profiles.id = scores.user_id
    group by profiles.id, profiles.username
    order by unique_solutions desc, total_score desc
$function$
;

create or replace view "public"."level_unique_solution_counts" as  SELECT level_id,
    count(*) AS unique_solutions
   FROM ( SELECT DISTINCT solutions.player_id,
            solutions.pipeline_hash,
            solutions.level_id
           FROM public.solutions) t
  GROUP BY level_id
  ORDER BY level_id;


create or replace view "public"."player_level_solution_stats" as  SELECT s.player_id,
    s.level_id,
    count(DISTINCT s.pipeline_hash) AS my_unique_solutions,
    COALESCE(l.unique_solutions, (0)::bigint) AS all_unique_solutions,
    round((((count(DISTINCT s.pipeline_hash))::numeric / (NULLIF(l.unique_solutions, 0))::numeric) * (100)::numeric), 1) AS player_share_percent,
    (avg(s.pipeline_length))::numeric(10,2) AS avg_pipeline_length
   FROM (public.solutions s
     LEFT JOIN public.level_unique_solution_counts l USING (level_id))
  GROUP BY s.player_id, s.level_id, l.unique_solutions
  ORDER BY s.level_id;


CREATE OR REPLACE FUNCTION public.prevent_duplicate_emails()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
begin
  -- Если email уже существует — кидаем ошибку
  if exists (
    select 1 from auth.users where lower(email) = lower(new.email)
  ) then
    raise exception 'User with this email already exists';
  end if;

  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.record_unique_solution(p_player_id uuid, p_level_id bigint, p_pipeline_hash text, p_pipeline_raw jsonb, p_pipeline_length integer, p_wallet_address text DEFAULT NULL)
 RETURNS TABLE(inserted boolean, nft_address text, mint_tx_hash text)
 LANGUAGE plpgsql
AS $function$
declare
  solution_inserted boolean := false;
  minted_address text;
  minted_tx text;
  minted_metadata_uri text;
  minted_timestamp timestamptz;
  new_solution_id bigint;
  mint_response http_response;
  mint_payload jsonb;
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

    if new_solution_id is not null then
      perform public.update_score(p_player_id);
      begin
        mint_response := http_request(
          '/functions/v1/mint_nft'::text,
          'POST'::text,
          jsonb_build_object(
            'Content-Type','application/json'
          ),
          jsonb_build_object(
            'player_id', p_player_id,
            'level_id', p_level_id,
            'pipeline_hash', p_pipeline_hash,
            'pipeline_raw', p_pipeline_raw,
            'pipeline_length', p_pipeline_length,
            'wallet_address', target_wallet_address
          )::text
        );

        if mint_response.status_code between 200 and 299 then
          mint_payload := mint_response.body::jsonb;
          minted_address := mint_payload->>'nft_address';
          minted_tx := mint_payload->>'blockchain_tx';
          minted_metadata_uri := mint_payload->>'metadata_uri';
          minted_timestamp := null;
          if (mint_payload ? 'minted_at') then
            begin
              minted_timestamp := (mint_payload->>'minted_at')::timestamptz;
            exception when others then
              minted_timestamp := now();
            end;
          end if;
          if minted_timestamp is null then
            minted_timestamp := now();
          end if;

          if minted_address is not null then
            update public.unique_pipelines
            set nft_address = minted_address,
                mint_tx_hash = minted_tx,
                metadata_uri = minted_metadata_uri,
                minted_at = minted_timestamp,
                nft_status = 'minted',
                nft_error = null
            where pipeline_hash = p_pipeline_hash;

            update public.solutions
            set nft_minted = true,
                nft_address = minted_address,
                mint_tx_hash = minted_tx,
                nft_status = 'minted',
                nft_error = null
            where id = new_solution_id;

            insert into public.player_nft_items (
                player_id,
                nft_address,
                level_id,
                pipeline_hash
            )
            values (
                p_player_id,
                minted_address,
                p_level_id,
                p_pipeline_hash
            )
            on conflict (nft_address) do nothing;
          else
            update public.unique_pipelines
            set nft_status = 'failed',
                nft_error = 'mint_nft returned no nft_address'
            where pipeline_hash = p_pipeline_hash;
            update public.solutions
            set nft_status = 'failed',
                nft_error = 'mint_nft returned no nft_address'
            where id = new_solution_id;
          end if;
        else
          update public.unique_pipelines
          set nft_status = 'failed',
              nft_error = format('mint_nft status %s', mint_response.status_code)
          where pipeline_hash = p_pipeline_hash;
          update public.solutions
          set nft_status = 'failed',
              nft_error = format('mint_nft status %s', mint_response.status_code)
          where id = new_solution_id;
        end if;
      exception
        when others then
          raise notice 'mint_nft failed: %', sqlerrm;
          update public.unique_pipelines
          set nft_status = 'failed',
              nft_error = sqlerrm
          where pipeline_hash = p_pipeline_hash;
          update public.solutions
          set nft_status = 'failed',
              nft_error = sqlerrm
          where id = new_solution_id;
      end;
    end if;
  end if;

  return query select solution_inserted, minted_address, minted_tx;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.set_player_progress(p_player_id uuid, p_completed_levels integer[], p_highest_unlocked_level_id integer)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
begin
  insert into public.player_progress (player_id, completed_levels, highest_unlocked_level_id, updated_at)
  values (p_player_id, coalesce(p_completed_levels, '{}'::integer[]), greatest(1, p_highest_unlocked_level_id), now())
  on conflict (player_id) do update
    set completed_levels = excluded.completed_levels,
        highest_unlocked_level_id = excluded.highest_unlocked_level_id,
        updated_at = now();
end;
$function$
;

CREATE OR REPLACE FUNCTION public.send_otp_trigger()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
begin
  perform http_request(
    '/functions/v1/send_otp'::text,
    'POST'::text,
    jsonb_build_object('Content-Type','application/json')::jsonb,
    jsonb_build_object(
      'email', NEW.email,
      'otp', NEW.otp
    )::text  -- body must be TEXT
  );
  return NEW;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.update_reputation_after_solution()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
declare
  current_unique int;
begin
  -- пересчитываем уникальные решения для игрока
  select count(*) into current_unique
  from public.solutions
  where player_id = NEW.player_id;

  -- upsert в таблицу репутации
  insert into public.player_reputation(player_id, unique_solutions, respect, updated_at)
  values (NEW.player_id, current_unique, current_unique * 10, now())
  on conflict (player_id) do update
    set unique_solutions = current_unique,
        respect = current_unique * 10,
        updated_at = now();

  return NEW;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.update_score(p_player_id uuid)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
declare
  v_unique_solutions int;
begin
  select count(*) into v_unique_solutions
  from public.solutions s
  where s.player_id = p_player_id;

  update public.player_reputation pr
  set unique_solutions = v_unique_solutions,
      respect = v_unique_solutions,
      updated_at = now()
  where pr.player_id = p_player_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.update_score_after_solution()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  update public.score
  set 
    unique_solutions = unique_solutions + 1,
    total_pipeline_length = total_pipeline_length + NEW.pipeline_length,
    unique_levels_completed = unique_levels_completed + 1,
    updated_at = now()
  where player_id = NEW.player_id;

  return NEW;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.verify_email(p_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  UPDATE auth.users
  SET email_confirmed_at = now()
  WHERE id = p_user_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.verify_otp(p_email text, p_code text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare v_cnt int;
begin
  select count(*) into v_cnt
  from public.email_otp
  where email = p_email
    and otp = p_code
    and expires_at > now();

  if v_cnt = 0 then
    raise exception 'Invalid or expired OTP';
  end if;

  return true;
end;
$function$
;

grant delete on table "public"."email_otp" to "anon";

grant insert on table "public"."email_otp" to "anon";

grant references on table "public"."email_otp" to "anon";

grant select on table "public"."email_otp" to "anon";

grant trigger on table "public"."email_otp" to "anon";

grant truncate on table "public"."email_otp" to "anon";

grant update on table "public"."email_otp" to "anon";

grant delete on table "public"."email_otp" to "authenticated";

grant insert on table "public"."email_otp" to "authenticated";

grant references on table "public"."email_otp" to "authenticated";

grant select on table "public"."email_otp" to "authenticated";

grant trigger on table "public"."email_otp" to "authenticated";

grant truncate on table "public"."email_otp" to "authenticated";

grant update on table "public"."email_otp" to "authenticated";

grant delete on table "public"."email_otp" to "service_role";

grant insert on table "public"."email_otp" to "service_role";

grant references on table "public"."email_otp" to "service_role";

grant select on table "public"."email_otp" to "service_role";

grant trigger on table "public"."email_otp" to "service_role";

grant truncate on table "public"."email_otp" to "service_role";

grant update on table "public"."email_otp" to "service_role";

grant delete on table "public"."player_reputation" to "anon";

grant insert on table "public"."player_reputation" to "anon";

grant references on table "public"."player_reputation" to "anon";

grant select on table "public"."player_reputation" to "anon";

grant trigger on table "public"."player_reputation" to "anon";

grant truncate on table "public"."player_reputation" to "anon";

grant update on table "public"."player_reputation" to "anon";

grant delete on table "public"."player_reputation" to "authenticated";

grant insert on table "public"."player_reputation" to "authenticated";

grant references on table "public"."player_reputation" to "authenticated";

grant select on table "public"."player_reputation" to "authenticated";

grant trigger on table "public"."player_reputation" to "authenticated";

grant truncate on table "public"."player_reputation" to "authenticated";

grant update on table "public"."player_reputation" to "authenticated";

grant delete on table "public"."player_reputation" to "service_role";

grant insert on table "public"."player_reputation" to "service_role";

grant references on table "public"."player_reputation" to "service_role";

grant select on table "public"."player_reputation" to "service_role";

grant trigger on table "public"."player_reputation" to "service_role";

grant truncate on table "public"."player_reputation" to "service_role";

grant update on table "public"."player_reputation" to "service_role";

grant delete on table "public"."players" to "anon";

grant insert on table "public"."players" to "anon";

grant references on table "public"."players" to "anon";

grant select on table "public"."players" to "anon";

grant trigger on table "public"."players" to "anon";

grant truncate on table "public"."players" to "anon";

grant update on table "public"."players" to "anon";

grant delete on table "public"."players" to "authenticated";

grant insert on table "public"."players" to "authenticated";

grant references on table "public"."players" to "authenticated";

grant select on table "public"."players" to "authenticated";

grant trigger on table "public"."players" to "authenticated";

grant truncate on table "public"."players" to "authenticated";

grant update on table "public"."players" to "authenticated";

grant delete on table "public"."players" to "service_role";

grant insert on table "public"."players" to "service_role";

grant references on table "public"."players" to "service_role";

grant select on table "public"."players" to "service_role";

grant trigger on table "public"."players" to "service_role";

grant truncate on table "public"."players" to "service_role";

grant update on table "public"."players" to "service_role";

grant delete on table "public"."profiles" to "anon";

grant insert on table "public"."profiles" to "anon";

grant references on table "public"."profiles" to "anon";

grant select on table "public"."profiles" to "anon";

grant trigger on table "public"."profiles" to "anon";

grant truncate on table "public"."profiles" to "anon";

grant update on table "public"."profiles" to "anon";

grant delete on table "public"."profiles" to "authenticated";

grant insert on table "public"."profiles" to "authenticated";

grant references on table "public"."profiles" to "authenticated";

grant select on table "public"."profiles" to "authenticated";

grant trigger on table "public"."profiles" to "authenticated";

grant truncate on table "public"."profiles" to "authenticated";

grant update on table "public"."profiles" to "authenticated";

grant delete on table "public"."profiles" to "service_role";

grant insert on table "public"."profiles" to "service_role";

grant references on table "public"."profiles" to "service_role";

grant select on table "public"."profiles" to "service_role";

grant trigger on table "public"."profiles" to "service_role";

grant truncate on table "public"."profiles" to "service_role";

grant update on table "public"."profiles" to "service_role";

grant delete on table "public"."score" to "anon";

grant insert on table "public"."score" to "anon";

grant references on table "public"."score" to "anon";

grant select on table "public"."score" to "anon";

grant trigger on table "public"."score" to "anon";

grant truncate on table "public"."score" to "anon";

grant update on table "public"."score" to "anon";

grant delete on table "public"."player_progress" to "anon";

grant insert on table "public"."player_progress" to "anon";

grant references on table "public"."player_progress" to "anon";

grant select on table "public"."player_progress" to "anon";

grant trigger on table "public"."player_progress" to "anon";

grant truncate on table "public"."player_progress" to "anon";

grant update on table "public"."player_progress" to "anon";

grant delete on table "public"."player_nft_items" to "anon";

grant insert on table "public"."player_nft_items" to "anon";

grant references on table "public"."player_nft_items" to "anon";

grant select on table "public"."player_nft_items" to "anon";

grant trigger on table "public"."player_nft_items" to "anon";

grant truncate on table "public"."player_nft_items" to "anon";

grant update on table "public"."player_nft_items" to "anon";

grant delete on table "public"."score" to "authenticated";

grant insert on table "public"."score" to "authenticated";

grant references on table "public"."score" to "authenticated";

grant select on table "public"."score" to "authenticated";

grant trigger on table "public"."score" to "authenticated";

grant truncate on table "public"."score" to "authenticated";

grant update on table "public"."score" to "authenticated";

grant delete on table "public"."player_progress" to "authenticated";

grant insert on table "public"."player_progress" to "authenticated";

grant references on table "public"."player_progress" to "authenticated";

grant select on table "public"."player_progress" to "authenticated";

grant trigger on table "public"."player_progress" to "authenticated";

grant truncate on table "public"."player_progress" to "authenticated";

grant update on table "public"."player_progress" to "authenticated";

grant delete on table "public"."player_nft_items" to "authenticated";

grant insert on table "public"."player_nft_items" to "authenticated";

grant references on table "public"."player_nft_items" to "authenticated";

grant select on table "public"."player_nft_items" to "authenticated";

grant trigger on table "public"."player_nft_items" to "authenticated";

grant truncate on table "public"."player_nft_items" to "authenticated";

grant update on table "public"."player_nft_items" to "authenticated";

grant delete on table "public"."score" to "service_role";

grant insert on table "public"."score" to "service_role";

grant references on table "public"."score" to "service_role";

grant select on table "public"."score" to "service_role";

grant trigger on table "public"."score" to "service_role";

grant truncate on table "public"."score" to "service_role";

grant update on table "public"."score" to "service_role";

grant delete on table "public"."player_progress" to "service_role";

grant insert on table "public"."player_progress" to "service_role";

grant references on table "public"."player_progress" to "service_role";

grant select on table "public"."player_progress" to "service_role";

grant trigger on table "public"."player_progress" to "service_role";

grant truncate on table "public"."player_progress" to "service_role";

grant update on table "public"."player_progress" to "service_role";

grant delete on table "public"."player_nft_items" to "service_role";

grant insert on table "public"."player_nft_items" to "service_role";

grant references on table "public"."player_nft_items" to "service_role";

grant select on table "public"."player_nft_items" to "service_role";

grant trigger on table "public"."player_nft_items" to "service_role";

grant truncate on table "public"."player_nft_items" to "service_role";

grant update on table "public"."player_nft_items" to "service_role";

grant delete on table "public"."solutions" to "anon";

grant insert on table "public"."solutions" to "anon";

grant references on table "public"."solutions" to "anon";

grant select on table "public"."solutions" to "anon";

grant trigger on table "public"."solutions" to "anon";

grant truncate on table "public"."solutions" to "anon";

grant update on table "public"."solutions" to "anon";

grant delete on table "public"."unique_pipelines" to "anon";

grant insert on table "public"."unique_pipelines" to "anon";

grant references on table "public"."unique_pipelines" to "anon";

grant select on table "public"."unique_pipelines" to "anon";

grant trigger on table "public"."unique_pipelines" to "anon";

grant truncate on table "public"."unique_pipelines" to "anon";

grant update on table "public"."unique_pipelines" to "anon";

grant delete on table "public"."solutions" to "authenticated";

grant insert on table "public"."solutions" to "authenticated";

grant references on table "public"."solutions" to "authenticated";

grant select on table "public"."solutions" to "authenticated";

grant trigger on table "public"."solutions" to "authenticated";

grant truncate on table "public"."solutions" to "authenticated";

grant update on table "public"."solutions" to "authenticated";

grant delete on table "public"."unique_pipelines" to "authenticated";

grant insert on table "public"."unique_pipelines" to "authenticated";

grant references on table "public"."unique_pipelines" to "authenticated";

grant select on table "public"."unique_pipelines" to "authenticated";

grant trigger on table "public"."unique_pipelines" to "authenticated";

grant truncate on table "public"."unique_pipelines" to "authenticated";

grant update on table "public"."unique_pipelines" to "authenticated";

grant delete on table "public"."solutions" to "service_role";

grant insert on table "public"."solutions" to "service_role";

grant references on table "public"."solutions" to "service_role";

grant select on table "public"."solutions" to "service_role";

grant trigger on table "public"."solutions" to "service_role";

grant truncate on table "public"."solutions" to "service_role";

grant update on table "public"."solutions" to "service_role";

grant delete on table "public"."unique_pipelines" to "service_role";

grant insert on table "public"."unique_pipelines" to "service_role";

grant references on table "public"."unique_pipelines" to "service_role";

grant select on table "public"."unique_pipelines" to "service_role";

grant trigger on table "public"."unique_pipelines" to "service_role";

grant truncate on table "public"."unique_pipelines" to "service_role";

grant update on table "public"."unique_pipelines" to "service_role";


  create policy "Allow OTP insert"
  on "public"."email_otp"
  as permissive
  for insert
  to anon, authenticated
with check (true);



  create policy "Allow OTP select"
  on "public"."email_otp"
  as permissive
  for select
  to anon, authenticated
using (true);



  create policy "otp_insert"
  on "public"."email_otp"
  as permissive
  for insert
  to anon, authenticated
with check (true);



  create policy "otp_select"
  on "public"."email_otp"
  as permissive
  for select
  to anon, authenticated
using (true);



  create policy "Leaderboard users can see profiles"
  on "public"."profiles"
  as permissive
  for select
  to authenticated
using (true);



  create policy "Leaderboard scores visible"
  on "public"."score"
  as permissive
  for select
  to authenticated
using (true);



  create policy "Users can see their own score"
  on "public"."score"
  as permissive
  for select
  to public
using ((player_id = auth.uid()));



  create policy "Users can update their own score"
  on "public"."score"
  as permissive
  for update
  to public
using ((player_id = auth.uid()));

  create policy "Players can insert their progress"
  on "public"."player_progress"
  as permissive
  for insert
  to authenticated
with check ((player_id = auth.uid()));



  create policy "Players can read their progress"
  on "public"."player_progress"
  as permissive
  for select
  to authenticated
using ((player_id = auth.uid()));



  create policy "Players can update their progress"
  on "public"."player_progress"
  as permissive
  for update
  to authenticated
using ((player_id = auth.uid()));

  create policy "Players view their nft items"
  on "public"."player_nft_items"
  as permissive
  for select
  to authenticated
using ((player_id = auth.uid()));


CREATE TRIGGER trg_update_reputation_after_solution AFTER INSERT ON public.solutions FOR EACH ROW EXECUTE FUNCTION public.update_reputation_after_solution();

CREATE TRIGGER trg_update_score_after_solution AFTER INSERT ON public.solutions FOR EACH ROW EXECUTE FUNCTION public.update_score_after_solution();

CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_auth_user();
