-- סופר עוף, ביטול שלב ג: חזרה לכלל הקודם (כל משתמש פעיל קורא וכותב בכל הטבלאות). לא נוגע בנתונים.
do $$
declare t text; r record;
begin
  foreach t in array array['orders','fresh_stock','frozen_stock','settings','inventory_log','frozen_stock_log',
                           'beit_shemesh_shipments','beit_shemesh_withdrawals','gavash_shipments','gavash_withdrawals'] loop
    for r in select policyname from pg_policies where schemaname = 'public' and tablename = t loop
      execute format('drop policy %I on public.%I', r.policyname, t);
    end loop;
    execute format('create policy so_active_users on public.%I for all to authenticated using (public.so_is_active()) with check (public.so_is_active())', t);
  end loop;
end $$;
