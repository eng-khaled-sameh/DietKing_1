-- =============================================================================
-- ملف تصفير وتجهيز النظام لتسليم العميل (Clean Slate for Production Delivery)
-- DietKing ERP & POS - Supabase Database Wipe Script
--
-- ⚠️ تحذير: هذا الكود يقوم بحذف جميع البيانات التجريبية نهائياً من قاعدة البيانات!
-- 
-- 🟢 البيانات التي سيتم مسحها وتصفيرها بالكامل:
--    1. جميع المبيعات وفواتير الكاشير وبنودها (sales, sale_items).
--    2. جميع إقفالات الورديات ومراجعات المحاسب (shift_closings, closing_reviews).
--    3. جميع المصروفات وفواتير المصروفات (expenses, expense_invoices).
--    4. جميع أوامر التوريد ومشتريات المستودع (supply_orders, supply_order_lines).
--    5. جميع طلبات الفروع من المستودع (branch_orders, branch_order_lines).
--    6. جميع صرفيات وتشغيلات ودفعات المطبخ (kitchen_issues, kitchen_batches).
--    7. جميع عمليات ومراجعات الجرد (stocktakes, stocktake_lines, stocktake_reviews).
--    8. جميع حركات المخزون مع تصفير أرصدة المخزون إلى 0 (inventory_movements, inventory_stock = 0).
--    9. شؤون الموظفين: الحضور والانصراف، الغياب، الإجازات، الخصومات والمكافآت،
--       سجل الرواتب، والموظفين التجريبيين، مع إعادة عداد أكواد الموظفين للرقم 1.
--   10. جميع الإشعارات، سجل التدقيق، وسجلات الحذف (notifications, audit_log, retention_logs).
--   11. تصفير عدادات أرقام المستندات والفواتير لتبدأ من الرقم 1 للعميل (doc_counters).
--
-- 🛡️ البيانات الأساسية المحفوظة التي لن تُحذف أبداً:
--    - الفروع (branches)
--    - حسابات المستخدمين وصلاحيات الدخول (profiles / auth.users)
--    - المنيو وتصنيفاته ومنتجاته وأسعاره وتكاليفه وأوزانه (categories, products, product_variants)
--    - أصناف وخامات المستودع وتصنيفاتها ووحداتها (inventory_items, inventory_categories, inventory_units)
--    - المستودعات والموردين (warehouses, suppliers)
--    - إعدادات النظام والضريبة والمنطقة الزمنية (app_settings)
-- =============================================================================

BEGIN;

-- ── 1. تعطيل مؤقت للـ Triggers إن لزم الأمر لسرعة ونظافة الحذف ────────────────
SET CONSTRAINTS ALL DEFERRED;

-- ── 2. حذف جميع بيانات المبيعات والكاشير ──────────────────────────────────────
TRUNCATE TABLE public.sale_items CASCADE;
TRUNCATE TABLE public.sales CASCADE;

-- ── 3. حذف إقفالات الورديات ومراجعات الإقفالات ─────────────────────────────────
TRUNCATE TABLE public.closing_reviews CASCADE;
TRUNCATE TABLE public.shift_closings CASCADE;

-- ── 4. حذف المصروفات وفواتير المصروفات وعداداتها ──────────────────────────────
TRUNCATE TABLE public.expenses CASCADE;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'expense_invoices') THEN
    EXECUTE 'TRUNCATE TABLE public.expense_invoices CASCADE;';
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'expense_invoice_items') THEN
    EXECUTE 'TRUNCATE TABLE public.expense_invoice_items CASCADE;';
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'hq_expense_counter') THEN
    EXECUTE 'TRUNCATE TABLE public.hq_expense_counter;';
  END IF;
END $$;

-- ── 5. حذف حركات وطلبات وأوامر المخزون والتوريد ───────────────────────────────
TRUNCATE TABLE public.supply_order_lines CASCADE;
TRUNCATE TABLE public.supply_orders CASCADE;

TRUNCATE TABLE public.branch_order_lines CASCADE;
TRUNCATE TABLE public.branch_orders CASCADE;

TRUNCATE TABLE public.kitchen_issue_lines CASCADE;
TRUNCATE TABLE public.kitchen_issues CASCADE;
TRUNCATE TABLE public.kitchen_batches CASCADE;

TRUNCATE TABLE public.stocktake_reviews CASCADE;
TRUNCATE TABLE public.stocktake_lines CASCADE;
TRUNCATE TABLE public.stocktakes CASCADE;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'inventory_imports') THEN
    EXECUTE 'TRUNCATE TABLE public.inventory_imports CASCADE;';
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'inventory_item_ops') THEN
    EXECUTE 'TRUNCATE TABLE public.inventory_item_ops CASCADE;';
  END IF;
END $$;

-- دفتر حركات المخزون
TRUNCATE TABLE public.inventory_movements RESTART IDENTITY CASCADE;

-- تصفير رصيد المخزون لجميع الأصناف والخامات (تصبح الكمية 0.000 جاهزة للجرد الفعلي الأول)
UPDATE public.inventory_stock
SET quantity = 0,
    updated_at = now();

-- ── 6. حذف شؤون الموظفين (حضور، إجازات، خصومات، مكافآت، رواتب، موظفين) ────────
TRUNCATE TABLE public.attendance_records CASCADE;
TRUNCATE TABLE public.leave_requests CASCADE;
TRUNCATE TABLE public.deduction_bonus_requests CASCADE;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'salary_history') THEN
    EXECUTE 'TRUNCATE TABLE public.salary_history CASCADE;';
  END IF;
END $$;

-- حذف الموظفين التجريبيين
TRUNCATE TABLE public.employees CASCADE;

-- إعادة تسلسل كود الموظفين ليبدأ من الرقم 1 (EMP-0001)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_sequences WHERE schemaname = 'public' AND sequencename = 'employee_code_seq') THEN
    ALTER SEQUENCE public.employee_code_seq RESTART WITH 1;
  END IF;
END $$;

-- ── 7. حذف الإشعارات وسجلات التدقيق وسجلات الحذف ──────────────────────────────
TRUNCATE TABLE public.notification_reads CASCADE;
TRUNCATE TABLE public.notifications CASCADE;
TRUNCATE TABLE public.audit_log RESTART IDENTITY CASCADE;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'admin_approvals') THEN
    EXECUTE 'TRUNCATE TABLE public.admin_approvals CASCADE;';
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'acc_retention_logs') THEN
    EXECUTE 'TRUNCATE TABLE public.acc_retention_logs CASCADE;';
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'hr_retention_logs') THEN
    EXECUTE 'TRUNCATE TABLE public.hr_retention_logs CASCADE;';
  END IF;
END $$;

-- ── 8. تصفير عدادات أرقام المستندات لتبدأ من رقم 1 عند العميل ─────────────────
TRUNCATE TABLE public.doc_counters;

-- ── 9. تحديث بصمات المزامنة (Data Versions) لتحديث أجهزة الكاشير والمستخدمين ──
UPDATE public.data_versions
SET version = version + 1,
    updated_at = now();

COMMIT;

-- ── 10. تقرير تأكيد التصفير (Verification Report) ──────────────────────────────
SELECT 
  'تم تصفير النظام بنجاح وهو الآن جاهز لتسليم العميل بنسبة 100%' AS status,
  (SELECT count(*) FROM public.sales) AS sales_count,
  (SELECT count(*) FROM public.shift_closings) AS closings_count,
  (SELECT count(*) FROM public.supply_orders) AS supply_orders_count,
  (SELECT count(*) FROM public.branch_orders) AS branch_orders_count,
  (SELECT count(*) FROM public.inventory_movements) AS movements_count,
  (SELECT coalesce(sum(quantity), 0) FROM public.inventory_stock) AS total_stock_on_hand,
  (SELECT count(*) FROM public.employees) AS employees_count,
  (SELECT count(*) FROM public.attendance_records) AS attendance_count,
  (SELECT count(*) FROM public.products) AS preserved_products_count,
  (SELECT count(*) FROM public.branches) AS preserved_branches_count,
  (SELECT count(*) FROM public.profiles) AS preserved_users_count;
