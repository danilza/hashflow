alter table public.profiles
    add column if not exists exclusivity_mode text not null default 'open';
