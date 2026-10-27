-- =============================================================================
-- ملف حذف جميع الموظفين وخامات المطبخ والمستودع وتصنيفاتها
-- DietKing ERP & POS - Supabase Clean Slate: Employees & Kitchen Inventory
--
-- ⚠️ تحذير: هذا الكود يقوم بحذف كامل وجذري لما يلي:
--    1. جميع الموظفين المسجلين من الـ HR وسجلاتهم بالكامل:
--       - سجلات الحضور والانصراف والغياب (attendance_records)
--       - طلبات الإجازات (leave_requests)
--       - طلبات الخصومات والمكافآت (deduction_bonus_requests)
--       - سجل وتاريخ الرواتب (salary_history)
--       - جدول الموظفين نفسه (employees)
--       - إعادة تسلسل كود الموظفين ليبدأ من الرقم 1 (EMP-0001)
--
--    2. جميع خامات ومستلزمات المطبخ والمستودع وتصنيفاتها:
--       - أرصدة المخزون (inventory_stock)
--       - دفتر حركات المخزون (inventory_movements)
--       - سطور أوامر التوريد للمستودع (supply_order_lines)
--       - سطور طلبات الفروع من المستودع (branch_order_lines)
--       - سطور صرفيات المطبخ (kitchen_issue_lines)
--       - دفعات إنتاج المطبخ (kitchen_batches)
--       - سطور ومراجعات الجرد (stocktake_lines, stocktake_reviews)
--       - عمليات واستيراد الأصناف (inventory_imports, inventory_item_ops)
--       - جدول أصناف وخامات المستودع بالكامل (inventory_items)
--       - تصنيفات المخزون (inventory_categories)
--       - وحدات القياس (inventory_units) مع إعادة ضبط الوحدات الأساسية القياسية (كجم، جرام، حبة، لتر...)
--
-- 🛡️ ما الذي يظل محفوظاً ولن يُمس:
--    - الفروع (branches)
--    - حسابات المستخدمين وصلاحيات الدخول (profiles / auth.users)
--    - المنيو ومنتجات البيع وتصنيفاتها وأسعارها وأوزانها (products, categories, product_variants)
--    - المستودعات والموردين (warehouses, suppliers)
--    - إعدادات النظام (app_settings)
-- =============================================================================

BEGIN;

-- ── 1. تعطيل القيود مؤقتاً لتفادي تعارض المفاتيح الخارجية أثناء الحذف الشامل ──
SET CONSTRAINTS ALL DEFERRED;

-- ── 2. حذف جميع بيانات الموظفين المسجلين من قسم الموارد البشرية ──────────────
-- حذف العمليات المرتبطة بالموظفين أولاً
TRUNCATE TABLE public.attendance_records CASCADE;
TRUNCATE TABLE public.leave_requests CASCADE;
TRUNCATE TABLE public.deduction_bonus_requests CASCADE;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'salary_history') THEN
    EXECUTE 'TRUNCATE TABLE public.salary_history CASCADE;';
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'hr_retention_logs') THEN
    EXECUTE 'TRUNCATE TABLE public.hr_retention_logs CASCADE;';
  END IF;
END $$;

-- فك أي ربط للموظفين في مراجعات الجرد
UPDATE public.stocktake_reviews
SET deduction_employee_id = NULL
WHERE deduction_employee_id IS NOT NULL;

-- حذف جدول الموظفين بالكامل
TRUNCATE TABLE public.employees CASCADE;

-- إعادة عداد تسلسل كود الموظفين ليبدأ أول موظف جديد من EMP-0001
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_sequences WHERE schemaname = 'public' AND sequencename = 'employee_code_seq') THEN
    ALTER SEQUENCE public.employee_code_seq RESTART WITH 1;
  END IF;
END $$;


-- ── 3. حذف جميع حركات وسطور ومستندات الخامات المرتبطة بأصناف المخزون ─────────
-- سطور حركات وأوامر التوريد وصرفيات المطبخ والجرد
TRUNCATE TABLE public.inventory_stock CASCADE;
TRUNCATE TABLE public.inventory_movements RESTART IDENTITY CASCADE;

TRUNCATE TABLE public.supply_order_lines CASCADE;
TRUNCATE TABLE public.branch_order_lines CASCADE;
TRUNCATE TABLE public.kitchen_issue_lines CASCADE;
TRUNCATE TABLE public.kitchen_batches CASCADE;
TRUNCATE TABLE public.stocktake_lines CASCADE;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'inventory_imports') THEN
    EXECUTE 'TRUNCATE TABLE public.inventory_imports CASCADE;';
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'inventory_item_ops') THEN
    EXECUTE 'TRUNCATE TABLE public.inventory_item_ops CASCADE;';
  END IF;
END $$;


-- ── 4. حذف أصناف وخامات المطبخ والمستودع وتصنيفاتها بالكامل ───────────────────
-- حذف جميع أصناف الخامات
TRUNCATE TABLE public.inventory_items CASCADE;

-- حذف تصنيفات المخزون
TRUNCATE TABLE public.inventory_categories CASCADE;

-- تفريغ وحدات القياس وإعادة إدراج الوحدات القياسية النظيفة
TRUNCATE TABLE public.inventory_units CASCADE;

INSERT INTO public.inventory_units (code, name_ar, name_en) VALUES
  ('kg',    'كيلوجرام', 'Kilogram'),
  ('g',     'جرام',     'Gram'),
  ('pcs',   'حبة',      'Piece'),
  ('box',   'كرتون',    'Box'),
  ('bag',   'كيس',      'Bag'),
  ('can',   'علبة',     'Can'),
  ('liter', 'لتر',      'Liter'),
  ('ml',    'مليلتر',   'Milliliter'),
  ('meter', 'متر',      'Meter'),
  ('roll',  'رول',      'Roll')
ON CONFLICT (code) DO NOTHING;


-- ── 5. تحديث بصمات المزامنة لتحديث أجهزة النظام ───────────────────────────────
UPDATE public.data_versions
SET version = version + 1,
    updated_at = now();

COMMIT;


-- ── 6. تقرير تأكيد الحذف النظيف ──────────────────────────────────────────────
SELECT 
  'تم حذف جميع الموظفين وخامات المطبخ وتصنيفاتها بنجاح تام' AS status,
  (SELECT count(*) FROM public.employees)             AS remaining_employees_count,
  (SELECT count(*) FROM public.attendance_records)    AS remaining_attendance_count,
  (SELECT count(*) FROM public.leave_requests)        AS remaining_leave_requests_count,
  (SELECT count(*) FROM public.inventory_items)       AS remaining_inventory_items_count,
  (SELECT count(*) FROM public.inventory_categories)  AS remaining_inventory_categories_count,
  (SELECT count(*) FROM public.inventory_stock)       AS remaining_inventory_stock_count,
  (SELECT count(*) FROM public.products)              AS preserved_menu_products_count,
  (SELECT count(*) FROM public.branches)              AS preserved_branches_count,
  (SELECT count(*) FROM public.profiles)              AS preserved_users_count;
