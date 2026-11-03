-- סופר עוף — שלב ב: נעילת הטבלאות. רק משתמש מחובר ופעיל (app_users.active) ניגש לנתונים.
-- להריץ רק אחרי שהאפליקציה עם הכניסה החדשה באוויר וכל המכשירים נכנסו מחדש. ביטול: 03_rollback_lock.sql

-- 1. מחיקת כל הכללים הקיימים (כולל "גישה לכולם" anon/public)
do $$ declare r record; begin
  for r in select tablename, policyname from pg_policies where schemaname = 'public' loop
    execute format('drop policy %I on public.%I', r.policyname, r.tablename);
  end loop;
end $$;

-- 2. טבלאות נתונים: משתמש מחובר ופעיל בלבד
do $$ declare t text; begin
  foreach t in array array['orders','fresh_stock','frozen_stock','settings','inventory_log','frozen_stock_log',
                           'beit_shemesh_shipments','beit_shemesh_withdrawals','gavash_shipments','gavash_withdrawals'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('create policy so_active_users on public.%I for all to authenticated using (public.so_is_active()) with check (public.so_is_active())', t);
  end loop;
end $$;

-- 3. משתמשים: כל אחד רואה את עצמו, מנהל רואה את כולם. אין כתיבה ישירה (רק admin_save_user / admin_set_active)
alter table public.app_users enable row level security;
create policy so_read_users on public.app_users for select to authenticated using (id = auth.uid() or public.so_is_admin());
revoke all on public.app_users from anon;
revoke insert, update, delete on public.app_users from authenticated;
-- הסיסמה המגובבת לא נשלחת לדפדפן בכלל
revoke select on public.app_users from authenticated;
grant select (id, username, is_admin, active, permissions, created_at) on public.app_users to authenticated;

-- 4. עדכונים חיים בין מכשירים (היו מופעלים רק על 3 טבלאות)
do $$ declare t text; begin
  foreach t in array array['orders','fresh_stock','frozen_stock','settings','frozen_stock_log',
                           'beit_shemesh_withdrawals','gavash_shipments','gavash_withdrawals'] loop
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

select json_agg(json_build_object('t', tablename, 'policy', policyname, 'roles', roles)) as policies_now
from pg_policies where schemaname = 'public';
