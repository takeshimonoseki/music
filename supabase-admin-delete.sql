-- Supabase SQL Editorで実行する削除用RPCテンプレートです。
-- このファイルには実際の管理パスワードを書かないでください。
--
-- 1. 管理パスワードのSHA-256ハッシュを作る
--    macOS例:
--    printf '%s' 'ここに管理パスワード' | shasum -a 256
--
-- 2. 下の CHANGE_ME_SHA256_HEX を出力された64文字のハッシュに置き換えて、
--    Supabase SQL Editorで実行してください。
--
-- 3. 実際のハッシュに置き換えたSQLは公開リポジトリにcommitしないでください。

create extension if not exists pgcrypto;

create or replace function public.admin_delete_comment(
  comment_uid text,
  admin_password text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  expected_hash constant text := 'CHANGE_ME_SHA256_HEX';
  actual_hash text;
begin
  if expected_hash = 'CHANGE_ME_SHA256_HEX' then
    raise exception 'admin password hash is not configured';
  end if;

  if comment_uid is null or comment_uid !~ '^[0-9]{10,}-[a-z0-9]{6,}$' then
    raise exception 'invalid comment uid';
  end if;

  actual_hash := encode(digest(coalesce(admin_password, ''), 'sha256'), 'hex');
  if actual_hash <> expected_hash then
    raise exception 'invalid admin password';
  end if;

  insert into public.downloads (title, count)
  values ('del::' || comment_uid, 1)
  on conflict (title)
  do update set count = public.downloads.count + 1;

  return true;
end;
$$;

revoke all on function public.admin_delete_comment(text, text) from public;
grant execute on function public.admin_delete_comment(text, text) to anon, authenticated;
