-- MilkChat: схема базы данных Supabase.
-- Выполните целиком в Supabase Dashboard → SQL Editor (один раз на новый проект).

create extension if not exists pgcrypto;

-- ─── Таблицы ────────────────────────────────────────────────────────────────

create table if not exists public.profiles (
  id           uuid primary key references auth.users on delete cascade,
  username     text unique not null check (username ~ '^[a-zA-Z0-9_]{3,32}$'),
  display_name text not null default '',
  bio          text not null default '',
  avatar_url   text,
  verified     boolean not null default false,
  last_seen    timestamptz not null default now(),
  created_at   timestamptz not null default now()
);

create table if not exists public.chats (
  id           uuid primary key default gen_random_uuid(),
  kind         text not null check (kind in ('direct', 'group', 'channel', 'saved')),
  title        text not null default '',
  handle       text unique,
  about        text not null default '',
  avatar_url   text,
  avatar_emoji text,
  created_by   uuid references public.profiles on delete set null,
  created_at   timestamptz not null default now()
);

create table if not exists public.chat_members (
  chat_id      uuid not null references public.chats on delete cascade,
  user_id      uuid not null references public.profiles on delete cascade,
  role         text not null default 'member' check (role in ('owner', 'admin', 'member')),
  pinned       boolean not null default false,
  muted        boolean not null default false,
  archived     boolean not null default false,
  last_read_at timestamptz not null default now(),
  joined_at    timestamptz not null default now(),
  primary key (chat_id, user_id)
);
create index if not exists chat_members_user_idx on public.chat_members (user_id);

create table if not exists public.messages (
  id         bigint generated always as identity primary key,
  chat_id    uuid not null references public.chats on delete cascade,
  sender_id  uuid not null default auth.uid() references public.profiles on delete cascade,
  body       text not null check (length(body) between 1 and 4096),
  created_at timestamptz not null default now()
);
create index if not exists messages_chat_idx on public.messages (chat_id, created_at desc);

-- ─── Вспомогательные функции ────────────────────────────────────────────────

create or replace function public.is_member(p_chat uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from chat_members where chat_id = p_chat and user_id = auth.uid());
$$;

create or replace function public.can_post(p_chat uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from chat_members m join chats c on c.id = m.chat_id
    where m.chat_id = p_chat and m.user_id = auth.uid()
      and (c.kind <> 'channel' or m.role in ('owner', 'admin'))
  );
$$;

-- ─── Права доступа (RLS) ────────────────────────────────────────────────────

alter table public.profiles     enable row level security;
alter table public.chats        enable row level security;
alter table public.chat_members enable row level security;
alter table public.messages     enable row level security;

drop policy if exists "profiles readable" on public.profiles;
create policy "profiles readable" on public.profiles
  for select to authenticated using (true);
drop policy if exists "profiles self update" on public.profiles;
create policy "profiles self update" on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- Галочку «verified» выдаёт только администратор через Dashboard.
create or replace function public.protect_profile()
returns trigger language plpgsql as $$
begin
  if auth.uid() is not null and new.verified <> old.verified then
    raise exception 'verified is read-only';
  end if;
  return new;
end $$;
drop trigger if exists profiles_protect on public.profiles;
create trigger profiles_protect before update on public.profiles
  for each row execute function public.protect_profile();

drop policy if exists "chats for members" on public.chats;
create policy "chats for members" on public.chats
  for select to authenticated using (public.is_member(id));
drop policy if exists "chats admin update" on public.chats;
create policy "chats admin update" on public.chats
  for update to authenticated using (
    exists (select 1 from public.chat_members m where m.chat_id = chats.id and m.user_id = auth.uid() and m.role in ('owner', 'admin'))
  );

drop policy if exists "members visible to members" on public.chat_members;
create policy "members visible to members" on public.chat_members
  for select to authenticated using (public.is_member(chat_id));
drop policy if exists "member updates own settings" on public.chat_members;
create policy "member updates own settings" on public.chat_members
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "member leaves" on public.chat_members;
create policy "member leaves" on public.chat_members
  for delete to authenticated using (user_id = auth.uid());

drop policy if exists "messages for members" on public.messages;
create policy "messages for members" on public.messages
  for select to authenticated using (public.is_member(chat_id));
drop policy if exists "members send" on public.messages;
create policy "members send" on public.messages
  for insert to authenticated with check (sender_id = auth.uid() and public.can_post(chat_id));
drop policy if exists "authors delete" on public.messages;
create policy "authors delete" on public.messages
  for delete to authenticated using (sender_id = auth.uid());

-- Роль участника нельзя повысить себе самостоятельно.
create or replace function public.protect_member_role()
returns trigger language plpgsql as $$
begin
  if new.role <> old.role or new.chat_id <> old.chat_id or new.user_id <> old.user_id then
    raise exception 'only settings can be changed';
  end if;
  return new;
end $$;
drop trigger if exists chat_members_protect on public.chat_members;
create trigger chat_members_protect before update on public.chat_members
  for each row execute function public.protect_member_role();

-- ─── Регистрация: профиль + чат «Избранное» ─────────────────────────────────

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_chat uuid;
begin
  insert into profiles (id, username, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'username', 'user_' || substr(new.id::text, 1, 8)),
    coalesce(new.raw_user_meta_data ->> 'display_name', '')
  );
  insert into chats (kind, title, created_by) values ('saved', 'Избранное', new.id)
  returning id into v_chat;
  insert into chat_members (chat_id, user_id, role) values (v_chat, new.id, 'owner');
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ─── RPC ────────────────────────────────────────────────────────────────────

create or replace function public.open_direct_chat(p_peer uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_chat uuid;
begin
  if auth.uid() is null or p_peer = auth.uid() then
    raise exception 'invalid peer';
  end if;
  select c.id into v_chat
  from chats c
  join chat_members a on a.chat_id = c.id and a.user_id = auth.uid()
  join chat_members b on b.chat_id = c.id and b.user_id = p_peer
  where c.kind = 'direct'
  limit 1;
  if v_chat is null then
    insert into chats (kind, created_by) values ('direct', auth.uid()) returning id into v_chat;
    insert into chat_members (chat_id, user_id, role)
    values (v_chat, auth.uid(), 'member'), (v_chat, p_peer, 'member');
  end if;
  return v_chat;
end $$;

create or replace function public.create_group(p_title text, p_members uuid[], p_channel boolean default false)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_chat uuid;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  insert into chats (kind, title, created_by)
  values (case when p_channel then 'channel' else 'group' end, p_title, auth.uid())
  returning id into v_chat;
  insert into chat_members (chat_id, user_id, role) values (v_chat, auth.uid(), 'owner');
  insert into chat_members (chat_id, user_id)
  select v_chat, u from unnest(p_members) u
  where u <> auth.uid() and exists (select 1 from profiles where id = u)
  on conflict do nothing;
  return v_chat;
end $$;

-- Список чатов текущего пользователя со всем, что нужно экрану «Чаты».
create or replace function public.my_chats()
returns table (
  id uuid, kind text, title text, handle text, avatar_url text, avatar_emoji text,
  verified boolean, last_message text, last_sender_name text, last_from_me boolean,
  last_read boolean, last_at timestamptz, unread bigint, pinned boolean, muted boolean,
  archived boolean, member_count bigint, peer_id uuid
) language sql stable security definer set search_path = public as $$
  select
    c.id, c.kind,
    case when c.kind = 'direct' then coalesce(nullif(p.display_name, ''), p.username) else c.title end,
    case when c.kind = 'direct' then '@' || p.username else c.handle end,
    case when c.kind = 'direct' then p.avatar_url else c.avatar_url end,
    c.avatar_emoji,
    coalesce(p.verified, false),
    lm.body, coalesce(nullif(sp.display_name, ''), sp.username), lm.sender_id = auth.uid(),
    coalesce(lm.created_at <= (
      select max(o.last_read_at) from chat_members o
      where o.chat_id = c.id and o.user_id <> auth.uid()
    ), false),
    coalesce(lm.created_at, c.created_at),
    (select count(*) from messages x
      where x.chat_id = c.id and x.created_at > me.last_read_at and x.sender_id <> auth.uid()),
    me.pinned, me.muted, me.archived,
    (select count(*) from chat_members y where y.chat_id = c.id),
    p.id
  from chat_members me
  join chats c on c.id = me.chat_id
  left join lateral (
    select m.user_id from chat_members m
    where c.kind = 'direct' and m.chat_id = c.id and m.user_id <> auth.uid() limit 1
  ) peer on true
  left join profiles p on p.id = peer.user_id
  left join lateral (
    select * from messages m where m.chat_id = c.id order by m.created_at desc limit 1
  ) lm on true
  left join profiles sp on sp.id = lm.sender_id
  where me.user_id = auth.uid();
$$;

-- ─── Realtime и хранилище аватарок ──────────────────────────────────────────

do $$
begin
  alter publication supabase_realtime add table public.messages;
exception when duplicate_object then null;
end $$;
do $$
begin
  alter publication supabase_realtime add table public.chat_members;
exception when duplicate_object then null;
end $$;

insert into storage.buckets (id, name, public) values ('avatars', 'avatars', true)
on conflict (id) do nothing;

drop policy if exists "avatar upload own folder" on storage.objects;
create policy "avatar upload own folder" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "avatar update own folder" on storage.objects;
create policy "avatar update own folder" on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
