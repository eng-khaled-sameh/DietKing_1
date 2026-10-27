-- =============================================================================
-- 032_expenses_approval_and_notifications.sql
-- مسار دورة المصروفات الموحد:
-- 1. تسجيل مصروف الفرع الرئيسي (HQ) بدون فرع فيزيائي واعتماده مباشرة.
-- 2. إرسال مصروفات الفروع بحالة "قيد المراجعة" (pending) مع إشعار للمحاسب.
-- 3. اعتماد أو رفض المصروفات من المحاسب مع إشعار للفرع والكاشير.
-- 4. إتاحة دالة تنظيف المصروفات التجريبية.
-- =============================================================================

BEGIN;

-- 0. حذف أي دوال قديمة أو بإرجاع مختلف لتفادي أي خطأ 42P13
DROP FUNCTION IF EXISTS public.acc_add_expense(jsonb) CASCADE;
DROP FUNCTION IF EXISTS public.acc_add_expense(text, numeric, text, text, text) CASCADE;
DROP FUNCTION IF EXISTS public.get_branch_expenses_summary(uuid, date, date) CASCADE;
DROP FUNCTION IF EXISTS public.get_branch_expenses(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.create_expense(jsonb) CASCADE;
DROP FUNCTION IF EXISTS public.acc_decide_expense(uuid, text, text) CASCADE;
DROP FUNCTION IF EXISTS public.acc_get_all_expenses(timestamptz, timestamptz, uuid, int, timestamptz, uuid) CASCADE;
DROP FUNCTION IF EXISTS public.acc_clear_test_expenses() CASCADE;

-- 1. التأكد من وجود أعمدة الحالة والملاحظات والاعتماد في جدول expense_invoices

-- 1. التأكد من وجود أعمدة الحالة والملاحظات والاعتماد في جدول expense_invoices
ALTER TABLE public.expense_invoices ALTER COLUMN branch_id DROP NOT NULL;
ALTER TABLE public.expense_invoices ALTER COLUMN session_id DROP NOT NULL;

-- حذف أي check constraint قديمة على عمود status لتفادي خطأ 23514
ALTER TABLE public.expense_invoices DROP CONSTRAINT IF EXISTS expense_invoices_status_check;
ALTER TABLE public.expense_invoices DROP CONSTRAINT IF EXISTS expense_invoices_status_fkey;
ALTER TABLE public.expense_invoices DROP CONSTRAINT IF EXISTS chk_expense_status;
ALTER TABLE public.expense_invoices DROP CONSTRAINT IF EXISTS expense_invoices_chk_status;

-- إضافة عمود status إن لم يكن موجوداً
ALTER TABLE public.expense_invoices ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'pending';
ALTER TABLE public.expense_invoices ADD COLUMN IF NOT EXISTS decision_notes text;
ALTER TABLE public.expense_invoices ADD COLUMN IF NOT EXISTS decided_by uuid REFERENCES auth.users(id);
ALTER TABLE public.expense_invoices ADD COLUMN IF NOT EXISTS decided_at timestamptz;

-- إضافة check constraint جديدة تشمل كل الحالات المطلوبة
ALTER TABLE public.expense_invoices
  ADD CONSTRAINT expense_invoices_status_check
  CHECK (status IN ('pending', 'approved', 'rejected', 'posted'));

-- تحويل أي فواتير فروع سابقة إلى قيد المراجعة pending
UPDATE public.expense_invoices
SET status = 'pending', decided_by = NULL, decided_at = NULL, decision_notes = NULL
WHERE branch_id IS NOT NULL;


-- تفعيل RLS وسياسة الوصول لجدول expense_invoices
ALTER TABLE public.expense_invoices ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "expense_invoices_authenticated_policy" ON public.expense_invoices;
CREATE POLICY "expense_invoices_authenticated_policy" ON public.expense_invoices
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- جدول عداد مصروفات الفرع الرئيسي مع تفعيل RLS
CREATE TABLE IF NOT EXISTS public.hq_expense_counter (
  id int PRIMARY KEY DEFAULT 1,
  last_number integer NOT NULL DEFAULT 0
);
ALTER TABLE public.hq_expense_counter ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "hq_counter_auth_policy" ON public.hq_expense_counter;
CREATE POLICY "hq_counter_auth_policy" ON public.hq_expense_counter
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

INSERT INTO public.hq_expense_counter (id, last_number)
VALUES (1, 0)
ON CONFLICT (id) DO NOTHING;

-- 2. تحديث دالة create_expense
DROP FUNCTION IF EXISTS public.create_expense(jsonb) CASCADE;
CREATE OR REPLACE FUNCTION public.create_expense(p jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_client_id uuid := nullif(p->>'client_id', '')::uuid;
  v_branch_id uuid := nullif(p->>'branch_id', '')::uuid;
  v_session_id uuid := nullif(p->>'session_id', '')::uuid;
  v_amount numeric := nullif(p->>'amount', '')::numeric;
  v_vat numeric := coalesce(nullif(p->>'vat_amount', '')::numeric, 0);
  v_expense_date date := coalesce(nullif(p->>'expense_date', '')::date, current_date);
  v_existing public.expense_invoices%rowtype;
  v_branch public.branches%rowtype;
  v_number integer;
  v_invoice_number text;
  v_id uuid;
  v_email text;
  v_status text;
  v_branch_name text;
  v_branch_code text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'يجب تسجيل الدخول أولاً';
  END IF;
  IF NOT _has_role('cashier', 'branch_manager', 'accountant', 'owner') THEN
    RAISE EXCEPTION 'ليس لديك صلاحية تسجيل المصروفات';
  END IF;

  IF v_client_id IS NULL THEN
    v_client_id := gen_random_uuid();
  END IF;

  -- فحص المصروف للفرع الرئيسي HQ (من المحاسب أو المالك)
  IF v_branch_id IS NULL THEN
    IF NOT _has_role('accountant', 'owner') THEN
      RAISE EXCEPTION 'تسجيل مصروفات الفرع الرئيسي خاص بالمحاسب أو المالك فقط';
    END IF;
    v_branch_name := 'الفرع الرئيسي';
    v_branch_code := 'HQ';
    v_status := 'approved'; -- مصروفات الفرع الرئيسي معتمدة مباشرة من المحاسب

    UPDATE public.hq_expense_counter
    SET last_number = last_number + 1
    WHERE id = 1
    RETURNING last_number INTO v_number;

    v_invoice_number := 'EXP-HQ-' || lpad(v_number::text, 6, '0');
  ELSE
    -- فرع فعلي
    IF NOT _has_role('accountant', 'owner') AND NOT _can_act_for_branch(v_branch_id) THEN
      RAISE EXCEPTION 'ليس لديك صلاحية لهذا الفرع';
    END IF;

    SELECT * INTO v_branch
    FROM public.branches
    WHERE id = v_branch_id AND deleted_at IS NULL AND is_active;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'الفرع غير موجود أو غير نشط';
    END IF;

    v_branch_name := v_branch.name;
    v_branch_code := coalesce(nullif(v_branch.code, ''), 'BR');
    
    -- فواتير مصروفات الفروع الفيزيائية تكون دائماً قيد المراجعة بانتظار اعتماد المحاسب
    v_status := 'pending';

    INSERT INTO public.branch_expense_counters (branch_id, last_number)
    VALUES (v_branch.id, 1)
    ON CONFLICT (branch_id)
    DO UPDATE SET last_number = public.branch_expense_counters.last_number + 1
    RETURNING last_number INTO v_number;

    v_invoice_number := 'EXP-' || v_branch_code || '-' || lpad(v_number::text, 6, '0');
  END IF;

  IF coalesce(trim(p->>'category'), '') = '' THEN
    RAISE EXCEPTION 'نوع المصروف مطلوب';
  END IF;
  IF v_amount IS NULL OR v_amount <= 0 OR v_vat < 0 THEN
    RAISE EXCEPTION 'قيمة المصروف غير صحيحة';
  END IF;

  -- التحقق من عدم التكرار عبر client_id
  SELECT * INTO v_existing FROM public.expense_invoices WHERE client_id = v_client_id;
  IF FOUND THEN
    RETURN jsonb_build_object(
      'id', v_existing.id,
      'number', v_existing.invoice_number,
      'invoice_number', v_existing.invoice_number,
      'status', v_existing.status,
      'already_exists', true
    );
  END IF;

  SELECT email INTO v_email FROM auth.users WHERE id = v_uid;

  INSERT INTO public.expense_invoices (
    client_id, invoice_number, branch_id, branch_name, branch_code,
    cashier_id, cashier_name, session_id, category, payee, description,
    amount, vat_amount, total, payment_method, expense_date, notes, status
  ) VALUES (
    v_client_id, v_invoice_number, v_branch_id, v_branch_name, v_branch_code,
    v_uid, split_part(coalesce(v_email, ''), '@', 1), v_session_id,
    trim(p->>'category'), nullif(trim(p->>'payee'), ''), nullif(trim(p->>'description'), ''),
    round(v_amount, 2), round(v_vat, 2), round(v_amount + v_vat, 2),
    case when p->>'payment_method' = 'cash' then 'cash' else 'other' end,
    v_expense_date, nullif(trim(p->>'notes'), ''), v_status
  ) RETURNING id INTO v_id;

  -- إذا كان المصروف قيد المراجعة مرسل من فرع، نرسل إشعاراً فورياً للمحاسب
  IF v_status = 'pending' THEN
    BEGIN
      INSERT INTO public.notifications (
        recipient_role, type, title, body, ref_table, ref_id
      ) VALUES (
        'accountant',
        'expense_submitted',
        'مصروف جديد قيد المراجعة',
        'تم تسجيل مصروف جديد برقم ' || v_invoice_number || ' من فرع ' || v_branch_name || ' بقيمة ' || round(v_amount + v_vat, 2)::text || ' ر.س بانتظار الاعتماد.',
        'expense_invoices',
        v_id::text
      );
    EXCEPTION WHEN OTHERS THEN
      -- استمرار المعاملة حتى لو فشل جدول الإشعارات
    END;
  END IF;

  RETURN jsonb_build_object(
    'id', v_id,
    'number', v_invoice_number,
    'invoice_number', v_invoice_number,
    'status', v_status,
    'already_exists', false
  );
END;
$$;

REVOKE ALL ON FUNCTION public.create_expense(jsonb) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.create_expense(jsonb) TO authenticated;

-- 3. دالة المحاسب لاعتماد أو رفض المصروف acc_decide_expense
DROP FUNCTION IF EXISTS public.acc_decide_expense(uuid, text, text) CASCADE;
CREATE OR REPLACE FUNCTION public.acc_decide_expense(
  p_expense_id uuid,
  p_status     text, -- 'approved' | 'rejected'
  p_notes      text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_exp public.expense_invoices%rowtype;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'يجب تسجيل الدخول أولاً';
  END IF;
  IF NOT _has_role('accountant', 'owner') THEN
    RAISE EXCEPTION 'اعتماد أو رفض المصروفات من صلاحية المحاسب أو المالك فقط';
  END IF;
  IF p_status NOT IN ('approved', 'rejected') THEN
    RAISE EXCEPTION 'الحالة يجب أن تكون إما مقبولة (approved) أو مرفوضة (rejected)';
  END IF;

  SELECT * INTO v_exp FROM public.expense_invoices WHERE id = p_expense_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'فاتورة المصروف غير موجودة';
  END IF;

  UPDATE public.expense_invoices
  SET status = p_status,
      decision_notes = nullif(trim(p_notes), ''),
      decided_by = v_uid,
      decided_at = now()
  WHERE id = p_expense_id;

  -- إرسال إشعار للكاشير في الفرع المعني
  IF v_exp.branch_id IS NOT NULL THEN
    BEGIN
      INSERT INTO public.notifications (
        recipient_role, recipient_branch_id, type, title, body, ref_table, ref_id
      ) VALUES (
        'cashier',
        v_exp.branch_id,
        case when p_status = 'approved' then 'expense_approved' else 'expense_rejected' end,
        case when p_status = 'approved' then 'تم اعتماد المصروف' else 'تم رفض المصروف' end,
        case when p_status = 'approved'
             then 'تم اعتماد فاتورة المصروف رقم ' || coalesce(v_exp.invoice_number, '') || ' بقيمة ' || v_exp.total::text || ' ر.س من قسم الحسابات.'
             else 'تم رفض فاتورة المصروف رقم ' || coalesce(v_exp.invoice_number, '') || coalesce(' — السبب: ' || nullif(trim(p_notes), ''), '')
        end,
        'expense_invoices',
        p_expense_id::text
      );
    EXCEPTION WHEN OTHERS THEN
      -- تجاهل خطأ الإشعار لعدم تعطيل الاعتماد
    END;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'id', p_expense_id,
    'status', p_status
  );
END;
$$;

REVOKE ALL ON FUNCTION public.acc_decide_expense(uuid, text, text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.acc_decide_expense(uuid, text, text) TO authenticated;

-- 4. تحديث دالة acc_get_all_expenses لتعيد كل الحالات مع الفلاتر والمقر الرئيسي
DROP FUNCTION IF EXISTS public.acc_get_all_expenses(timestamptz, timestamptz, uuid, int, timestamptz, uuid) CASCADE;
CREATE OR REPLACE FUNCTION public.acc_get_all_expenses(
  p_from      timestamptz,
  p_to        timestamptz,
  p_branch_id uuid        DEFAULT NULL,
  p_limit     int         DEFAULT 50,
  p_cursor_ts timestamptz DEFAULT NULL,
  p_cursor_id uuid        DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_uid         uuid := auth.uid();
  v_from        timestamptz := coalesce(p_from, date_trunc('month', now()));
  v_to          timestamptz := coalesce(p_to, now());
  v_limit       int := least(greatest(coalesce(p_limit, 50), 1), 200);
  v_rows        jsonb;
  v_tot_approved numeric := 0;
  v_count_all   bigint  := 0;
  v_count_pending bigint := 0;
  v_count_approved bigint := 0;
  v_count_rejected bigint := 0;
  v_by_cat      jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'يجب تسجيل الدخول أولاً';
  END IF;
  IF NOT _has_role('accountant', 'owner', 'branch_manager') THEN
    RAISE EXCEPTION 'صلاحية مرفوضة';
  END IF;

  -- 1) الملخص والأعداد
  SELECT
    coalesce(sum(ei.total) FILTER (WHERE ei.status IN ('approved', 'posted')), 0),
    count(*),
    count(*) FILTER (WHERE ei.status = 'pending'),
    count(*) FILTER (WHERE ei.status IN ('approved', 'posted')),
    count(*) FILTER (WHERE ei.status = 'rejected')
  INTO v_tot_approved, v_count_all, v_count_pending, v_count_approved, v_count_rejected
  FROM public.expense_invoices ei
  WHERE ei.expense_date >= (v_from AT TIME ZONE 'Africa/Cairo')::date
    AND ei.expense_date <= (v_to AT TIME ZONE 'Africa/Cairo')::date
    AND (
      p_branch_id IS NULL
      OR (p_branch_id IS NOT NULL AND ei.branch_id = p_branch_id)
    );

  -- 2) التوزيع حسب الفئة للمعتمدة فقط
  SELECT coalesce(jsonb_object_agg(category, cat_total), '{}'::jsonb)
  INTO v_by_cat
  FROM (
    SELECT ei.category, coalesce(sum(ei.total), 0) AS cat_total
    FROM public.expense_invoices ei
    WHERE ei.status IN ('approved', 'posted')
      AND ei.expense_date >= (v_from AT TIME ZONE 'Africa/Cairo')::date
      AND ei.expense_date <= (v_to AT TIME ZONE 'Africa/Cairo')::date
      AND (p_branch_id IS NULL OR ei.branch_id = p_branch_id)
    GROUP BY ei.category
  ) sub;

  -- 3) قائمة المصروفات بكل الحالات
  SELECT jsonb_agg(row_data)
  INTO   v_rows
  FROM (
    SELECT jsonb_build_object(
      'id',             ei.id,
      'invoice_number', ei.invoice_number,
      'branch_id',      ei.branch_id,
      'branch_name',    coalesce(ei.branch_name, 'الفرع الرئيسي'),
      'cashier_id',     ei.cashier_id,
      'cashier_name',   ei.cashier_name,
      'category',       ei.category,
      'payee',          ei.payee,
      'description',    ei.description,
      'amount',         ei.amount,
      'vat_amount',     ei.vat_amount,
      'total',          ei.total,
      'payment_method', ei.payment_method,
      'expense_date',   ei.expense_date,
      'status',         ei.status,
      'decision_notes', ei.decision_notes,
      'notes',          ei.notes,
      'created_at',     ei.created_at
    ) AS row_data
    FROM public.expense_invoices ei
    WHERE ei.expense_date >= (v_from AT TIME ZONE 'Africa/Cairo')::date
      AND ei.expense_date <= (v_to AT TIME ZONE 'Africa/Cairo')::date
      AND (
        p_branch_id IS NULL
        OR (p_branch_id IS NOT NULL AND ei.branch_id = p_branch_id)
      )
      AND (
        p_cursor_ts IS NULL
        OR (ei.created_at, ei.id) < (p_cursor_ts, p_cursor_id)
      )
    ORDER BY ei.created_at DESC, ei.id DESC
    LIMIT v_limit
  ) sub;

  RETURN jsonb_build_object(
    'summary', jsonb_build_object(
      'total_amount',   v_tot_approved,
      'count',          v_count_all,
      'pending_count',  v_count_pending,
      'approved_count', v_count_approved,
      'rejected_count', v_count_rejected,
      'by_category',    v_by_cat
    ),
    'items', coalesce(v_rows, '[]'::jsonb),
    'limit', v_limit
  );
END;
$$;

REVOKE ALL ON FUNCTION public.acc_get_all_expenses(timestamptz, timestamptz, uuid, int, timestamptz, uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.acc_get_all_expenses(timestamptz, timestamptz, uuid, int, timestamptz, uuid) TO authenticated;

-- 5. تحديث دالة get_branch_expenses لتعيد الحالة وملاحظات القرار للكاشير
DROP FUNCTION IF EXISTS public.get_branch_expenses(uuid) CASCADE;
CREATE OR REPLACE FUNCTION public.get_branch_expenses(p_branch_id uuid)
RETURNS TABLE (
  id uuid,
  client_id uuid,
  number text,
  category text,
  payee text,
  description text,
  amount numeric,
  vat_amount numeric,
  total numeric,
  payment_method text,
  expense_date date,
  notes text,
  status text,
  decision_notes text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'يجب تسجيل الدخول أولاً';
  END IF;

  RETURN QUERY
  SELECT
    ei.id, ei.client_id, ei.invoice_number AS number, ei.category, ei.payee, ei.description,
    ei.amount, ei.vat_amount, ei.total, ei.payment_method, ei.expense_date,
    ei.notes, ei.status, ei.decision_notes, ei.created_at
  FROM public.expense_invoices ei
  WHERE ei.branch_id = p_branch_id
  ORDER BY ei.created_at DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.get_branch_expenses(uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.get_branch_expenses(uuid) TO authenticated;

-- 6. دالة تنظيف المصروفات التجريبية بالكامل
COMMIT;
