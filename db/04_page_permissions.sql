-- סופר עוף, שלב ג: הרשאות לפי דף, גם בשרת (ממצא 1 בבדיקת launch-check, 16.11.26)
-- עד עכשיו כל משתמש פעיל יכול היה לכתוב ולמחוק בכל טבלה דרך ה-API, וההגבלה הייתה רק במסך.
-- מהשלב הזה:
--   כתיבה, שינוי ומחיקה: רק מי שיש לו "עריכה" (canEdit) בדף שכותב לטבלה
--   קריאת הזמנות (שמות, טלפונים וכתובות של לקוחות): רק מי שיש לו דף שמשתמש בהזמנות
--   קריאת שאר הטבלאות: נשארת לכל משתמש פעיל (מסך המלאי, הדוחות ומסכים אחרים קוראים אותן)
--   מנהל: הכל, כמו קודם
-- ביטול מיידי: 05_rollback_page_permissions.sql. השלב לא משנה נתונים.
-- להריץ ב-Supabase → SQL Editor → New query → להדביק → Run.

-- 1. האם למשתמש המחובר יש אחד מהדפים (p_write=true בודק את canEdit; אם canEdit חסר, בודק את pages)
create or replace function public.so_can(p_pages text[], p_write boolean)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((
    select active and (
      is_admin
      or coalesce(
           case when p_write then coalesce(permissions->'canEdit', permissions->'pages') else permissions->'pages' end,
           '[]'::jsonb
         ) ?| p_pages
    )
    from public.app_users where id = auth.uid()
  ), false)
$$;
revoke all on function public.so_can(text[], boolean) from public, anon;
grant execute on function public.so_can(text[], boolean) to authenticated;

-- 2. החלפת הכלל הכללי (so_active_users) בכללים לפי טבלה
do $$
declare
  r record;
  -- טבלה | דפים שקוראים (ריק = כל משתמש פעיל) | דפים שכותבים
  rules constant text[][] := array[
    ['orders',                   'orders,deliveries,archive,stats,dashboard', 'orders,deliveries,archive'],
    ['fresh_stock',              '',                                           'inventory'],
    ['frozen_stock',             '',                                           'inventory'],
    ['frozen_stock_log',         '',                                           'inventory'],
    ['inventory_log',            '',                                           'inventory,stats'],
    ['settings',                 '',                                           'orders,contacts,lists,packaging,settings'],
    ['beit_shemesh_shipments',   '',                                           'beit-shemesh'],
    ['beit_shemesh_withdrawals', '',                                           'beit-shemesh'],
    ['gavash_shipments',         '',                                           'gavash'],
    ['gavash_withdrawals',       '',                                           'gavash']
  ];
  i int; t text; rd text; wr text; read_expr text; write_expr text;
begin
  for i in 1 .. array_length(rules, 1) loop
    t := rules[i][1]; rd := rules[i][2]; wr := rules[i][3];
    read_expr  := case when rd = '' then 'public.so_is_active()'
                       else format('public.so_can(%L::text[], false)', '{' || rd || '}') end;
    write_expr := format('public.so_can(%L::text[], true)', '{' || wr || '}');
    for r in select policyname from pg_policies where schemaname = 'public' and tablename = t loop
      execute format('drop policy %I on public.%I', r.policyname, t);
    end loop;
    execute format('alter table public.%I enable row level security', t);
    execute format('create policy so_read   on public.%I for select to authenticated using (%s)', t, read_expr);
    execute format('create policy so_insert on public.%I for insert to authenticated with check (%s)', t, write_expr);
    execute format('create policy so_update on public.%I for update to authenticated using (%s) with check (%s)', t, write_expr, write_expr);
    execute format('create policy so_delete on public.%I for delete to authenticated using (%s)', t, write_expr);
  end loop;
end $$;

-- 3. בדיקה: הכללים החדשים, ומה כל משתמש יכול לערוך (לוודא שאף עובד לא נחסם ממה שהוא צריך)
select username, is_admin, active,
       permissions->'pages'   as pages,
       permissions->'canEdit' as can_edit
from public.app_users order by is_admin desc, username;
