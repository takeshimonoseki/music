-- ============================================================
--  コメント機能のセットアップ SQL
--  Supabase ダッシュボード → SQL Editor に貼り付けて 1 回実行してください。
--  プロジェクト: mbviclfaijldherrtmyk
--
--  ★ 実行前に、下の 'CHANGE_THIS_PASSWORD' を
--     あなただけが知る好きな管理用パスワードに書き換えてください。
--     （このパスワードは comments.html の「管理人」ボタンで使います）
-- ============================================================

-- 1) コメント用テーブル
create table if not exists public.comments (
  id         bigint generated always as identity primary key,
  name       text        not null default '名無し',
  body       text        not null,
  created_at timestamptz not null default now()
);

-- 2) RLS を有効化（直接の書き込み・削除は禁止。読み取りのみ許可）
alter table public.comments enable row level security;

drop policy if exists "comments read for all" on public.comments;
create policy "comments read for all"
  on public.comments for select
  to anon, authenticated
  using (true);

-- 3) 投稿用 RPC（サーバー側で検証してから挿入）
create or replace function public.post_comment(p_name text, p_body text)
returns public.comments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text;
  v_body text;
  r public.comments;
begin
  v_name := coalesce(nullif(btrim(p_name), ''), '名無し');
  v_body := btrim(coalesce(p_body, ''));

  if length(v_body) = 0 then
    raise exception 'empty comment';
  end if;
  if length(v_body) > 1000 then
    v_body := left(v_body, 1000);
  end if;
  if length(v_name) > 40 then
    v_name := left(v_name, 40);
  end if;

  insert into public.comments (name, body)
  values (v_name, v_body)
  returning * into r;

  return r;
end;
$$;

grant execute on function public.post_comment(text, text) to anon, authenticated;

-- 4) 削除用 RPC（管理用パスワードが一致したときだけ削除）
--    ↓ 'CHANGE_THIS_PASSWORD' を必ず書き換えてください
create or replace function public.delete_comment(p_id bigint, p_pass text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_pass is distinct from 'CHANGE_THIS_PASSWORD' then
    return false;
  end if;
  delete from public.comments where id = p_id;
  return true;
end;
$$;

grant execute on function public.delete_comment(bigint, text) to anon, authenticated;

-- 完了。comments.html が動作するようになります。
