# super-off

מערכת ניהול לקצביה "סופר עוף" — אפליקציית דף אחד (React + Tailwind בדפדפן, Supabase).

- `index.html` — כל האפליקציה
- `sw.js`, `manifest.json` — התקנה למסך הבית; הדף נטען תמיד מהרשת (no-store)
- `db/` — קבצי SQL שהורצו ב-Supabase:
  - `01_auth_prepare.sql` — חשבונות Supabase Auth למשתמשים, פונקציות `so_is_active` / `so_is_admin` / `admin_save_user` / `admin_set_active`
  - `02_lock_tables.sql` — נעילת הטבלאות (RLS: משתמש מחובר ופעיל בלבד) + עדכונים חיים
  - `03_rollback_lock.sql` — ביטול הנעילה במקרה חירום

## עבודה על המערכת
1. גיבוי לפני כל שינוי (הגדרות ← "הורדת גיבוי מלא").
2. עבודה בענף נפרד, בדיקה, ורק אז מיזוג ל-`main` (GitHub Pages מעלה אוטומטית).
3. שינויים במסד הנתונים — תוספתיים בלבד.

## מבנה נתונים עיקרי (בתוך `orders.data`)
- `route` — `{ id, name, time, courier, date, seq }` סבב משלוחים
- `delivery` — `{ status: 'done' | 'failed', reason, collected, at, by, onwayAt }`
- `city`, `collect` — `{ type, amount }`, `notifiedAt`
