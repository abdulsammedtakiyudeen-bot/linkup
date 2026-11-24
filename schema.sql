-- LINKUP v1.0 — Supabase database setup
-- Run this in the SQL Editor of a NEW, SEPARATE Supabase project.
-- Do not run it in your Arabic Learning Dictionary project.
-- This starter schema is intentionally conservative. Review policies before public launch.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique check (username ~ '^[a-z0-9_]{3,24}$'),
  display_name text not null check (char_length(display_name) between 1 and 40),
  bio text not null default '' check (char_length(bio) <= 160),
  avatar_url text,
  is_private boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  content text not null default '' check (char_length(content) <= 2000),
  image_url text,
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint posts_not_empty check (char_length(trim(content)) > 0 or image_url is not null)
);

create table if not exists public.likes (
  user_id uuid not null references public.profiles(id) on delete cascade,
  post_id uuid not null references public.posts(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, post_id)
);

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  post_id uuid not null references public.posts(id) on delete cascade,
  content text not null check (char_length(trim(content)) between 1 and 500),
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.follows (
  follower_id uuid not null references public.profiles(id) on delete cascade,
  following_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, following_id),
  constraint no_self_follow check (follower_id <> following_id)
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  type text not null check (type in ('like','comment','follow','system')),
  message text not null check (char_length(message) <= 300),
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  post_id uuid references public.posts(id) on delete cascade,
  reported_user_id uuid references public.profiles(id) on delete cascade,
  reason text not null check (reason in ('Harassment or bullying','Spam or scam','Hateful or harmful content','Impersonation','Privacy concern','Other')),
  details text check (char_length(details) <= 500),
  status text not null default 'pending' check (status in ('pending','reviewing','resolved','dismissed')),
  created_at timestamptz not null default now(),
  constraint report_target_required check (post_id is not null or reported_user_id is not null)
);

create table if not exists public.blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint no_self_block check (blocker_id <> blocked_id)
);

create index if not exists posts_created_at_idx on public.posts (created_at desc) where deleted_at is null;
create index if not exists posts_user_id_idx on public.posts (user_id, created_at desc) where deleted_at is null;
create index if not exists comments_post_id_idx on public.comments (post_id, created_at) where deleted_at is null;
create index if not exists notifications_user_created_idx on public.notifications (user_id, created_at desc);
create index if not exists follows_following_idx on public.follows (following_id);

-- Create a profile automatically when an auth account is created.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public
as $$
declare
  base_username text;
  final_username text;
begin
  base_username := lower(regexp_replace(coalesce(new.raw_user_meta_data->>'username', split_part(new.email,'@',1), 'member'), '[^a-z0-9_]', '', 'g'));
  base_username := left(base_username, 18);
  if length(base_username) < 3 then base_username := 'member'; end if;
  final_username := base_username || '_' || substr(replace(new.id::text,'-',''),1,5);
  insert into public.profiles(id, username, display_name)
  values(new.id, final_username, coalesce(nullif(new.raw_user_meta_data->>'display_name',''), final_username))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_linkup on auth.users;
create trigger on_auth_user_created_linkup
after insert on auth.users
for each row execute procedure public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.posts enable row level security;
alter table public.likes enable row level security;
alter table public.comments enable row level security;
alter table public.follows enable row level security;
alter table public.notifications enable row level security;
alter table public.reports enable row level security;
alter table public.blocks enable row level security;

-- Profiles: signed-in members can discover public profiles. Owners manage their own profile.
create policy "Authenticated users can read profiles" on public.profiles
for select to authenticated using (true);
create policy "Users insert own profile" on public.profiles
for insert to authenticated with check (auth.uid() = id);
create policy "Users update own profile" on public.profiles
for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);

-- Posts: signed-in users can read non-deleted posts. Owners create/update/delete their own.
create policy "Authenticated users read active posts" on public.posts
for select to authenticated using (deleted_at is null);
create policy "Users create own posts" on public.posts
for insert to authenticated with check (auth.uid() = user_id);
create policy "Users update own posts" on public.posts
for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Users delete own posts" on public.posts
for delete to authenticated using (auth.uid() = user_id);

-- Likes: visible to signed-in users; users can only manage their own likes.
create policy "Authenticated users read likes" on public.likes
for select to authenticated using (true);
create policy "Users create own likes" on public.likes
for insert to authenticated with check (auth.uid() = user_id);
create policy "Users delete own likes" on public.likes
for delete to authenticated using (auth.uid() = user_id);

-- Comments: visible to signed-in users; users manage only their own comments.
create policy "Authenticated users read active comments" on public.comments
for select to authenticated using (deleted_at is null);
create policy "Users create own comments" on public.comments
for insert to authenticated with check (auth.uid() = user_id);
create policy "Users update own comments" on public.comments
for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Users delete own comments" on public.comments
for delete to authenticated using (auth.uid() = user_id);

-- Follows: signed-in users can see relationships and manage only their own outgoing follows.
create policy "Authenticated users read follows" on public.follows
for select to authenticated using (true);
create policy "Users create own follows" on public.follows
for insert to authenticated with check (auth.uid() = follower_id);
create policy "Users delete own follows" on public.follows
for delete to authenticated using (auth.uid() = follower_id);

-- Notifications: only recipient can read/update. Inserts are restricted to recipient self
-- in this starter. Trusted server-side notification automation can be added later.
create policy "Users read own notifications" on public.notifications
for select to authenticated using (auth.uid() = user_id);
create policy "Users update own notifications" on public.notifications
for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Reports: a signed-in member may submit a report for themselves; only server/admin should review.
create policy "Users submit own reports" on public.reports
for insert to authenticated with check (auth.uid() = reporter_id);
create policy "Users read own submitted reports" on public.reports
for select to authenticated using (auth.uid() = reporter_id);

-- Blocks: users can see and manage only their own block list.
create policy "Users read own blocks" on public.blocks
for select to authenticated using (auth.uid() = blocker_id);
create policy "Users create own blocks" on public.blocks
for insert to authenticated with check (auth.uid() = blocker_id);
create policy "Users remove own blocks" on public.blocks
for delete to authenticated using (auth.uid() = blocker_id);

-- IMPORTANT:
-- This starter app does not yet enforce private-account follow approval or block filtering
-- at the database query level. Do not advertise private accounts as secure until that is
-- implemented and independently tested. Keep the site in closed testing until then.
