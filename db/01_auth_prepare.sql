-- סופר עוף — שלב א: הכנת כניסה מאובטחת (Supabase Auth). תוספתי בלבד: לא נועל טבלאות ולא משנה נתונים קיימים.
-- כל משתמש ב-app_users מקבל חשבון ב-auth.users עם אותו id.
-- אימייל פנימי = 32 תווי hex ראשונים של SHA-256(שם המשתמש) + @superoff.local
-- סיסמת Auth = ה-password_hash הקיים (SHA-256 של הסיסמה), כך שהסיסמאות הקיימות ממשיכות לעבוד.

create or replace function public.so_email(p_username text) returns text
language sql immutable set search_path = public, extensions as $$
  select left(encode(extensions.digest(p_username, 'sha256'), 'hex'), 32) || '@superoff.local'
$$;

create or replace function public.so_sync_auth_user(p_id uuid, p_username text, p_password_hash text)
returns void language plpgsql security definer set search_path = public, extensions, auth as $$
declare v_email text := public.so_email(p_username);
begin
  if exists (select 1 from auth.users where id = p_id) then
    update auth.users set
      email = v_email,
      encrypted_password = case when p_password_hash is not null then extensions.crypt(p_password_hash, extensions.gen_salt('bf')) else encrypted_password end,
      updated_at = now()
    where id = p_id;
    update auth.identities set identity_data = jsonb_build_object('sub', p_id::text, 'email', v_email, 'email_verified', true), updated_at = now()
    where user_id = p_id and provider = 'email';
  else
    if p_password_hash is null then raise exception 'password required for new user'; end if;
    insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
      confirmation_token, recovery_token, email_change_token_new, email_change, email_change_token_current,
      phone_change, phone_change_token, reauthentication_token)
    values ('00000000-0000-0000-0000-000000000000', p_id, 'authenticated', 'authenticated', v_email,
      extensions.crypt(p_password_hash, extensions.gen_salt('bf')), now(),
      '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb, now(), now(),
      '', '', '', '', '', '', '', '');
    insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
    values (gen_random_uuid(), p_id, p_id::text,
      jsonb_build_object('sub', p_id::text, 'email', v_email, 'email_verified', true), 'email', now(), now(), now());
  end if;
end $$;
revoke all on function public.so_sync_auth_user(uuid, text, text) from public, anon, authenticated;

-- האם המשתמש המחובר פעיל / מנהל (לשימוש בכללי האבטחה)
create or replace function public.so_is_active() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select active from public.app_users where id = auth.uid()), false)
$$;
create or replace function public.so_is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select is_admin and active from public.app_users where id = auth.uid()), false)
$$;

-- ניהול משתמשים — רק מנהל, דרך הפונקציות האלה (לא כתיבה ישירה לטבלה)
create or replace function public.admin_save_user(p_id uuid, p_username text, p_password_hash text,
  p_is_admin boolean, p_permissions jsonb)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid := coalesce(p_id, gen_random_uuid());
begin
  if not public.so_is_admin() then raise exception 'admin only'; end if;
  if coalesce(trim(p_username), '') = '' then raise exception 'username required'; end if;
  if p_id is null then
    if p_password_hash is null then raise exception 'password required'; end if;
    insert into public.app_users (id, username, password_hash, is_admin, active, permissions)
    values (v_id, p_username, p_password_hash, p_is_admin, true, p_permissions);
  else
    update public.app_users set username = p_username, is_admin = p_is_admin, permissions = p_permissions,
      password_hash = coalesce(p_password_hash, password_hash)
    where id = v_id;
  end if;
  perform public.so_sync_auth_user(v_id, p_username, p_password_hash);
  return v_id;
end $$;

create or replace function public.admin_set_active(p_id uuid, p_active boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.so_is_admin() then raise exception 'admin only'; end if;
  if p_id = auth.uid() and not p_active then raise exception 'cannot deactivate yourself'; end if;
  update public.app_users set active = p_active where id = p_id;
end $$;

revoke all on function public.admin_save_user(uuid, text, text, boolean, jsonb) from public, anon;
revoke all on function public.admin_set_active(uuid, boolean) from public, anon;
grant execute on function public.admin_save_user(uuid, text, text, boolean, jsonb) to authenticated;
grant execute on function public.admin_set_active(uuid, boolean) to authenticated;
grant execute on function public.so_is_active() to authenticated;
grant execute on function public.so_is_admin() to authenticated;

-- חשבונות Auth למשתמשים הקיימים (עם הסיסמאות הקיימות)
select public.so_sync_auth_user(id, username, password_hash) from public.app_users;

select json_agg(json_build_object('app_id', a.id, 'auth_ok', u.id is not null)) as migrated
from public.app_users a left join auth.users u on u.id = a.id;
