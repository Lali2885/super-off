-- סופר עוף — ביטול שלב ב (חירום): מחזיר גישה פתוחה כמו לפני הנעילה. לא נוגע בנתונים.
do $$ declare t text; begin
  foreach t in array array['orders','fresh_stock','frozen_stock','settings','inventory_log','frozen_stock_log',
                           'beit_shemesh_shipments','beit_shemesh_withdrawals','gavash_shipments','gavash_withdrawals','app_users'] loop
    execute format('drop policy if exists so_rollback_all on public.%I', t);
    execute format('create policy so_rollback_all on public.%I for all to anon, authenticated using (true) with check (true)', t);
  end loop;
end $$;
grant select, insert, update, delete on public.app_users to anon, authenticated;
