-- Execute no SQL Editor do Supabase.
-- Antes: em Authentication > Providers > Email, desative "Confirm email".

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nickname text not null unique check (nickname ~ '^[A-Za-z0-9_]{3,20}$')
);

-- Apelido único sem diferenciar maiúsculas de minúsculas
create unique index if not exists profiles_nickname_lower on public.profiles (lower(nickname));

create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, nickname) values (new.id, new.raw_user_meta_data->>'nickname');
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  day date not null,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  nickname text not null default '',
  body text not null check (char_length(body) between 1 and 1000),
  created_at timestamptz not null default now()
);
create index if not exists comments_day_idx on public.comments (day, created_at desc);

-- O apelido do comentário vem sempre do perfil, nunca do navegador
create or replace function public.set_comment_nickname() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  select nickname into new.nickname from public.profiles where id = new.user_id;
  return new;
end $$;

drop trigger if exists comments_set_nickname on public.comments;
create trigger comments_set_nickname before insert on public.comments
  for each row execute function public.set_comment_nickname();

alter table public.profiles enable row level security;
alter table public.comments enable row level security;

drop policy if exists "leitura publica" on public.comments;
drop policy if exists "publicacao publica" on public.comments;
drop policy if exists "ler comentarios" on public.comments;
drop policy if exists "publicar logado" on public.comments;
drop policy if exists "ler perfis" on public.profiles;
create policy "ler perfis" on public.profiles for select using (true);

-- Ranking: dias com ao menos uma reflexão, depois total de reflexões
create or replace view public.ranking as
  select nickname, count(distinct day)::int as dias, count(*)::int as reflexoes
  from public.comments
  group by nickname
  order by dias desc, reflexoes desc;

grant select on public.ranking to anon, authenticated;

-- ===== CASAL: dois usuários conectados veem as reflexões "só do casal" um do outro =====
alter table public.comments add column if not exists visibility text not null default 'publico' check (visibility in ('publico','casal'));

create table if not exists public.couples (
  id uuid primary key default gen_random_uuid(),
  user_a uuid not null references auth.users(id) on delete cascade,
  user_b uuid references auth.users(id) on delete cascade,
  code text not null unique,
  created_at timestamptz not null default now(),
  check (user_b is null or user_a <> user_b)
);
create unique index if not exists couples_user_a on public.couples (user_a);
create unique index if not exists couples_user_b on public.couples (user_b);
alter table public.couples enable row level security;
-- Sem policies de escrita: o app usa só as funções abaixo.

create or replace function public.is_partner(p_user uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.couples c where c.user_b is not null
    and ((c.user_a = auth.uid() and c.user_b = p_user) or (c.user_b = auth.uid() and c.user_a = p_user)))
$$;

drop policy if exists "ler comentarios" on public.comments;
create policy "ler comentarios" on public.comments for select using (
  visibility = 'publico' or user_id = auth.uid() or public.is_partner(user_id)
);
create or replace function public.in_couple() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.couples c where c.user_b is not null and auth.uid() in (c.user_a, c.user_b))
$$;
revoke all on function public.in_couple() from public, anon;
grant execute on function public.in_couple() to authenticated;

drop policy if exists "publicar logado" on public.comments;
create policy "publicar logado" on public.comments for insert to authenticated with check (
  auth.uid() = user_id and (visibility = 'publico' or public.in_couple())
);

-- Situação atual: {"estado":"nenhum"|"aguardando"|"conectado","codigo":...,"parceiro":...}
create or replace function public.couple_status() returns json
language plpgsql stable security definer set search_path = public as $$
declare c public.couples; pn text;
begin
  select * into c from public.couples where auth.uid() in (user_a, user_b) limit 1;
  if not found then return json_build_object('estado','nenhum'); end if;
  if c.user_b is null then return json_build_object('estado','aguardando','codigo',c.code); end if;
  select nickname into pn from public.profiles where id = case when c.user_a = auth.uid() then c.user_b else c.user_a end;
  return json_build_object('estado','conectado','parceiro',pn);
end $$;

create or replace function public.couple_invite() returns json
language plpgsql security definer set search_path = public as $$
declare k text;
begin
  if auth.uid() is null then raise exception 'login'; end if;
  if exists (select 1 from public.couples where auth.uid() in (user_a, user_b)) then return public.couple_status(); end if;
  loop
    k := upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));
    begin
      insert into public.couples (user_a, code) values (auth.uid(), k);
      exit;
    exception when unique_violation then
      if exists (select 1 from public.couples where user_a = auth.uid()) then exit; end if;
    end;
  end loop;
  return public.couple_status();
end $$;

create or replace function public.couple_join(p_code text) returns json
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  if auth.uid() is null then raise exception 'login'; end if;
  if exists (select 1 from public.couples where user_b is not null and auth.uid() in (user_a, user_b)) then raise exception 'ja_conectado'; end if;
  delete from public.couples where user_a = auth.uid() and user_b is null; -- descarta convite próprio pendente
  update public.couples set user_b = auth.uid()
    where code = upper(trim(p_code)) and user_b is null and user_a <> auth.uid();
  get diagnostics n = row_count;
  if n = 0 then raise exception 'codigo_invalido'; end if;
  return public.couple_status();
end $$;

create or replace function public.couple_leave() returns void
language sql security definer set search_path = public as $$
  delete from public.couples where auth.uid() in (user_a, user_b)
$$;

revoke all on function public.couple_status(), public.couple_invite(), public.couple_join(text), public.couple_leave(), public.is_partner(uuid) from public, anon;
grant execute on function public.couple_status(), public.couple_invite(), public.couple_join(text), public.couple_leave(), public.is_partner(uuid) to authenticated;
