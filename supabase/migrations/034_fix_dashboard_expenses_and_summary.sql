-- =============================================================================
-- 034_fix_dashboard_expenses_and_summary.sql
-- إصلاح ظهور المصروفات في الشاشة الرئيسية (لوحة التحكم) وتقارير المبيعات
-- 1. تحديث دالة acc_get_sales_summary لتشمل المصروفات المعتمدة (status in ('approved', 'posted'))
-- 2. تحديث دالة acc_get_comprehensive_financial_report لتشمل status in ('approved', 'posted')
-- 3. ضمان عمل acc_get_all_expenses للفرع الرئيسي HQ ولكل الفروع
-- =============================================================================

BEGIN;

-- ── 1. دالة ملخص المبيعات والمصروفات للشاشة الرئيسية (acc_get_sales_summary) ──
CREATE OR REPLACE FUNCTION public.acc_get_sales_summary(
  p_from      timestamptz,
  p_to        timestamptz,
  p_branch_id uuid DEFAULT NULL
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
  v_total_sales numeric := 0;
  v_subtotal    numeric := 0;
  v_discount    numeric := 0;
  v_vat         numeric := 0;
  v_cash_sales  numeric := 0;
  v_card_sales  numeric := 0;
  v_inv_count   bigint  := 0;
  v_exp_total   numeric := 0;
  v_exp_cash    numeric := 0;
  v_by_branch   jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'يجب تسجيل الدخول أولاً';
  END IF;
  IF NOT _has_role('accountant', 'owner', 'branch_manager') THEN
    RAISE EXCEPTION 'صلاحية مرفوضة: لا تملك دور محاسب أو مالك';
  END IF;
  IF _has_role('branch_manager') AND NOT _has_role('accountant', 'owner') THEN
    IF p_branch_id IS NULL OR NOT _can_act_for_branch(p_branch_id) THEN
      RAISE EXCEPTION 'مدير الفرع يمكنه عرض مبيعات فرعه فقط';
    END IF;
  END IF;

  -- 1) تجميع المبيعات المكتملة
  SELECT
    coalesce(sum(s.total), 0),
    coalesce(sum(s.subtotal), 0),
    coalesce(sum(s.discount_amount), 0),
    coalesce(sum(s.vat_amount), 0),
    coalesce(sum(s.total) FILTER (WHERE coalesce(s.payment_method, '') ILIKE ANY (ARRAY['%cash%', '%كاش%', '%نقد%'])), 0),
    coalesce(sum(s.total) FILTER (WHERE coalesce(s.payment_method, '') ILIKE ANY (ARRAY['%card%', '%visa%', '%pos%', '%network%', '%شبكة%', '%مدى%', '%فيزا%', '%بطاق%'])), 0),
    count(*)
  INTO
    v_total_sales, v_subtotal, v_discount, v_vat,
    v_cash_sales, v_card_sales, v_inv_count
  FROM public.sales s
  WHERE s.status = 'completed'
    AND s.sold_at >= v_from AND s.sold_at <= v_to
    AND (p_branch_id IS NULL OR s.branch_id = p_branch_id);

  -- 2) تجميع المصروفات المعتمدة (approved أو posted)
  SELECT
    coalesce(sum(ei.total), 0),
    coalesce(sum(ei.total) FILTER (WHERE ei.payment_method = 'cash'), 0)
  INTO v_exp_total, v_exp_cash
  FROM public.expense_invoices ei
  WHERE ei.status IN ('approved', 'posted')
    AND ei.expense_date >= (v_from AT TIME ZONE 'Africa/Cairo')::date
    AND ei.expense_date <= (v_to AT TIME ZONE 'Africa/Cairo')::date
    AND (p_branch_id IS NULL OR ei.branch_id = p_branch_id);

  -- 3) المبيعات لكل فرع
  SELECT coalesce(jsonb_agg(row_data), '[]'::jsonb)
  INTO v_by_branch
  FROM (
    SELECT jsonb_build_object(
      'branch_id',      s.branch_id,
      'branch_name',    coalesce(s.branch_name, b.name, '—'),
      'total_sales',    coalesce(sum(s.total), 0),
      'invoices_count', count(*)
    ) AS row_data
    FROM public.sales s
    LEFT JOIN public.branches b ON b.id = s.branch_id
    WHERE s.status = 'completed'
      AND s.sold_at >= v_from AND s.sold_at <= v_to
      AND (p_branch_id IS NULL OR s.branch_id = p_branch_id)
    GROUP BY s.branch_id, coalesce(s.branch_name, b.name, '—')
    ORDER BY coalesce(sum(s.total), 0) DESC
  ) sub;

  RETURN jsonb_build_object(
    'from',           v_from,
    'to',             v_to,
    'branch_id',      p_branch_id,
    'total_sales',    v_total_sales,
    'gross_sales',    v_subtotal,
    'net_sales',      v_total_sales,
    'total_discount', v_discount,
    'total_vat',      v_vat,
    'cash_sales',     v_cash_sales,
    'card_sales',     v_card_sales,
    'invoices_count', v_inv_count,
    'total_expenses', v_exp_total,
    'cash_expenses',  v_exp_cash,
    'net_revenue',    (v_total_sales - v_exp_total),
    'by_branch',      v_by_branch
  );
END;
$$;

REVOKE ALL ON FUNCTION public.acc_get_sales_summary(timestamptz, timestamptz, uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.acc_get_sales_summary(timestamptz, timestamptz, uuid) TO authenticated;


-- ── 2. دالة التقرير المالي الشامل (acc_get_comprehensive_financial_report) ──
CREATE OR REPLACE FUNCTION public.acc_get_comprehensive_financial_report(
  p_from      timestamptz,
  p_to        timestamptz,
  p_branch_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_from timestamptz := coalesce(p_from, date_trunc('month', now()));
  v_to timestamptz := coalesce(p_to, now());
  v_branch_name text := 'الشركة كاملة — جميع الفروع';
  v_sales_count int := 0; v_sales_subtot numeric := 0; v_sales_tax numeric := 0;
  v_sales_total numeric := 0; v_cash_sales numeric := 0; v_card_sales numeric := 0;
  v_exp_count int := 0; v_exp_total numeric := 0; v_exp_by_cat jsonb := '[]'::jsonb;
  v_pur_count int := 0; v_pur_total numeric := 0; v_bo_count int := 0; v_bo_total numeric := 0;
  v_surplus_total numeric := 0; v_shortage_total numeric := 0; v_closings_count int := 0;
BEGIN
  IF v_uid IS NULL OR NOT _has_role('accountant', 'owner', 'branch_manager') THEN
    RAISE EXCEPTION 'صلاحية مرفوضة';
  END IF;
  IF p_branch_id IS NOT NULL THEN
    SELECT name INTO v_branch_name FROM public.branches WHERE id = p_branch_id;
  END IF;

  SELECT count(*), coalesce(sum(subtotal), 0), coalesce(sum(vat_amount), 0), coalesce(sum(total), 0),
    coalesce(sum(CASE WHEN coalesce(payment_method, '') ILIKE ANY (ARRAY['%cash%', '%كاش%', '%نقد%']) THEN total ELSE 0 END), 0),
    coalesce(sum(CASE WHEN coalesce(payment_method, '') ILIKE ANY (ARRAY['%card%', '%visa%', '%pos%', '%network%', '%شبكة%', '%مدى%', '%فيزا%', '%بطاق%']) THEN total ELSE 0 END), 0)
  INTO v_sales_count, v_sales_subtot, v_sales_tax, v_sales_total, v_cash_sales, v_card_sales
  FROM public.sales
  WHERE sold_at >= v_from AND sold_at <= v_to AND (p_branch_id IS NULL OR branch_id = p_branch_id) AND status = 'completed';

  SELECT count(*), coalesce(sum(total), 0) INTO v_exp_count, v_exp_total
  FROM public.expense_invoices
  WHERE status IN ('approved', 'posted')
    AND expense_date >= (v_from AT TIME ZONE 'Africa/Cairo')::date
    AND expense_date <= (v_to AT TIME ZONE 'Africa/Cairo')::date
    AND (p_branch_id IS NULL OR branch_id = p_branch_id);

  SELECT coalesce(jsonb_agg(jsonb_build_object('category', category, 'total', category_total)), '[]'::jsonb)
  INTO v_exp_by_cat
  FROM (
    SELECT category, sum(total) AS category_total
    FROM public.expense_invoices
    WHERE status IN ('approved', 'posted')
      AND expense_date >= (v_from AT TIME ZONE 'Africa/Cairo')::date
      AND expense_date <= (v_to AT TIME ZONE 'Africa/Cairo')::date
      AND (p_branch_id IS NULL OR branch_id = p_branch_id)
    GROUP BY category ORDER BY category_total DESC
  ) categories;

  SELECT count(DISTINCT so.id), coalesce(sum(coalesce(sol.qty_approved, sol.qty_received, sol.qty_requested, 0) * coalesce(sol.unit_cost, 0)), 0)
  INTO v_pur_count, v_pur_total
  FROM public.supply_orders so JOIN public.supply_order_lines sol ON sol.order_id = so.id
  WHERE so.created_at >= v_from AND so.created_at <= v_to AND so.status IN ('approved', 'received');

  SELECT count(DISTINCT bo.id), coalesce(sum(coalesce(bol.qty_approved, bol.qty_requested, 0) * coalesce(ii.avg_cost, 0)), 0)
  INTO v_bo_count, v_bo_total
  FROM public.branch_orders bo JOIN public.branch_order_lines bol ON bol.order_id = bo.id
  LEFT JOIN public.inventory_items ii ON ii.id = bol.item_id
  WHERE bo.created_at >= v_from AND bo.created_at <= v_to
    AND (p_branch_id IS NULL OR bo.branch_id = p_branch_id)
    AND bo.status IN ('approved', 'received', 'fulfilled');

  SELECT count(*),
    coalesce(sum(CASE WHEN actual_cash > system_cash THEN (actual_cash - system_cash) ELSE 0 END), 0),
    coalesce(sum(CASE WHEN actual_cash < system_cash THEN (system_cash - actual_cash) ELSE 0 END), 0)
  INTO v_closings_count, v_surplus_total, v_shortage_total
  FROM public.shift_closings
  WHERE closed_at >= v_from AND closed_at <= v_to AND (p_branch_id IS NULL OR branch_id = p_branch_id);

  RETURN jsonb_build_object(
    'period', jsonb_build_object('from', v_from, 'to', v_to),
    'branch', jsonb_build_object('id', p_branch_id, 'name', v_branch_name),
    'sales', jsonb_build_object(
      'count', v_sales_count, 'subtotal', v_sales_subtot, 'vat_amount', v_sales_tax,
      'total', v_sales_total, 'cash', v_cash_sales, 'card', v_card_sales
    ),
    'expenses', jsonb_build_object('count', v_exp_count, 'total', v_exp_total, 'by_category', v_exp_by_cat),
    'purchases', jsonb_build_object('count', v_pur_count, 'total', v_pur_total),
    'branch_orders', jsonb_build_object('count', v_bo_count, 'total', v_bo_total),
    'closings', jsonb_build_object('count', v_closings_count, 'surplus', v_surplus_total, 'shortage', v_shortage_total),
    'net_profit', (v_sales_total + v_surplus_total) - (v_exp_total + v_pur_total + v_shortage_total)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.acc_get_comprehensive_financial_report(timestamptz, timestamptz, uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.acc_get_comprehensive_financial_report(timestamptz, timestamptz, uuid) TO authenticated;


-- ── 3. دالة تفاصيل المصروفات (acc_get_all_expenses) مع دعم الفرع الرئيسي HQ ──
DROP FUNCTION IF EXISTS public.acc_get_all_expenses(timestamptz, timestamptz, uuid, int, timestamptz, uuid) CASCADE;
DROP FUNCTION IF EXISTS public.acc_get_all_expenses(timestamptz, timestamptz, uuid, int, timestamptz, uuid, boolean) CASCADE;

CREATE OR REPLACE FUNCTION public.acc_get_all_expenses(
  p_from        timestamptz,
  p_to          timestamptz,
  p_branch_id   uuid        DEFAULT NULL,
  p_limit       int         DEFAULT 50,
  p_cursor_ts   timestamptz DEFAULT NULL,
  p_cursor_id   uuid        DEFAULT NULL,
  p_hq_only     boolean     DEFAULT FALSE
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_uid           uuid := auth.uid();
  v_from          timestamptz := coalesce(p_from, date_trunc('month', now()));
  v_to            timestamptz := coalesce(p_to, now());
  v_limit         int := least(greatest(coalesce(p_limit, 50), 1), 200);
  v_rows          jsonb;
  v_tot_approved  numeric := 0;
  v_count_all     bigint  := 0;
  v_count_pending bigint  := 0;
  v_count_approved bigint := 0;
  v_count_rejected bigint := 0;
  v_by_cat        jsonb;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'يجب تسجيل الدخول أولاً'; END IF;
  IF NOT _has_role('accountant', 'owner', 'branch_manager') THEN RAISE EXCEPTION 'صلاحية مرفوضة'; END IF;

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
      (p_branch_id IS NULL AND NOT p_hq_only)
      OR (p_branch_id IS NOT NULL AND ei.branch_id = p_branch_id)
      OR (p_hq_only AND (ei.branch_id IS NULL OR ei.branch_code = 'HQ'))
    );

  SELECT coalesce(jsonb_object_agg(category, cat_total), '{}'::jsonb)
  INTO v_by_cat
  FROM (
    SELECT ei.category, coalesce(sum(ei.total), 0) AS cat_total
    FROM public.expense_invoices ei
    WHERE ei.status IN ('approved', 'posted')
      AND ei.expense_date >= (v_from AT TIME ZONE 'Africa/Cairo')::date
      AND ei.expense_date <= (v_to AT TIME ZONE 'Africa/Cairo')::date
      AND (
        (p_branch_id IS NULL AND NOT p_hq_only)
        OR (p_branch_id IS NOT NULL AND ei.branch_id = p_branch_id)
        OR (p_hq_only AND (ei.branch_id IS NULL OR ei.branch_code = 'HQ'))
      )
    GROUP BY ei.category
  ) sub;

  SELECT jsonb_agg(row_data) INTO v_rows
  FROM (
    SELECT jsonb_build_object(
      'id', ei.id,
      'invoice_number', ei.invoice_number,
      'branch_id', ei.branch_id,
      'branch_code', coalesce(ei.branch_code, 'HQ'),
      'branch_name', coalesce(ei.branch_name, 'الفرع الرئيسي'),
      'cashier_id', ei.cashier_id,
      'cashier_name', ei.cashier_name,
      'category', ei.category,
      'payee', ei.payee,
      'description', ei.description,
      'amount', ei.amount,
      'vat_amount', ei.vat_amount,
      'total', ei.total,
      'payment_method', ei.payment_method,
      'expense_date', ei.expense_date,
      'status', ei.status,
      'decision_notes', ei.decision_notes,
      'notes', ei.notes,
      'created_at', ei.created_at
    ) AS row_data
    FROM public.expense_invoices ei
    WHERE ei.expense_date >= (v_from AT TIME ZONE 'Africa/Cairo')::date
      AND ei.expense_date <= (v_to AT TIME ZONE 'Africa/Cairo')::date
      AND (
        (p_branch_id IS NULL AND NOT p_hq_only)
        OR (p_branch_id IS NOT NULL AND ei.branch_id = p_branch_id)
        OR (p_hq_only AND (ei.branch_id IS NULL OR ei.branch_code = 'HQ'))
      )
      AND (p_cursor_ts IS NULL OR (ei.created_at, ei.id) < (p_cursor_ts, p_cursor_id))
    ORDER BY ei.created_at DESC, ei.id DESC
    LIMIT v_limit
  ) sub;

  RETURN jsonb_build_object(
    'summary', jsonb_build_object(
      'total_amount', v_tot_approved,
      'count', v_count_all,
      'pending_count', v_count_pending,
      'approved_count', v_count_approved,
      'rejected_count', v_count_rejected,
      'by_category', v_by_cat
    ),
    'items', coalesce(v_rows, '[]'::jsonb),
    'limit', v_limit
  );
END;
$$;

REVOKE ALL ON FUNCTION public.acc_get_all_expenses(timestamptz, timestamptz, uuid, int, timestamptz, uuid, boolean) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.acc_get_all_expenses(timestamptz, timestamptz, uuid, int, timestamptz, uuid, boolean) TO authenticated;


-- ── 4. دالة تفاصيل المبيعات والأصناف (acc_get_sales_detail) مع دعم variant_label والوزن ──
CREATE OR REPLACE FUNCTION public.acc_get_sales_detail(
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
  v_uid   uuid := auth.uid();
  v_from  timestamptz := coalesce(p_from, date_trunc('month', now()));
  v_to    timestamptz := coalesce(p_to, now());
  v_limit int := least(greatest(coalesce(p_limit, 50), 1), 200);
  v_rows  jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'يجب تسجيل الدخول أولاً';
  END IF;
  IF NOT _has_role('accountant', 'owner', 'branch_manager') THEN
    RAISE EXCEPTION 'صلاحية مرفوضة: لا تملك دور محاسب أو مالك';
  END IF;
  IF _has_role('branch_manager') AND NOT _has_role('accountant', 'owner') THEN
    IF p_branch_id IS NULL OR NOT _can_act_for_branch(p_branch_id) THEN
      RAISE EXCEPTION 'مدير الفرع يمكنه عرض مبيعات فرعه فقط';
    END IF;
  END IF;

  SELECT jsonb_agg(row_data)
  INTO   v_rows
  FROM (
    SELECT jsonb_build_object(
      'id',              s.id,
      'client_id',       s.client_id,
      'local_number',    s.local_number,
      'invoice_number',  s.invoice_number,
      'branch_id',       s.branch_id,
      'branch_name',     coalesce(s.branch_name, b.name),
      'cashier_id',      s.cashier_id,
      'cashier_name',    s.cashier_name,
      'subtotal',        s.subtotal,
      'discount_amount', s.discount_amount,
      'vat_amount',      s.vat_amount,
      'total',           s.total,
      'status',          s.status,
      'payment_method',  s.payment_method,
      'sold_at',         s.sold_at,
      'items', coalesce((
        SELECT jsonb_agg(jsonb_build_object(
          'id',            si.id,
          'product_id',    si.product_id,
          'variant_id',    si.variant_id,
          'product_name',  si.product_name,
          'variant_label', coalesce(si.variant_label, ''),
          'qty',           si.qty,
          'unit_price',    si.unit_price,
          'unit_cost',     si.unit_cost,
          'line_total',    si.line_total
        ))
        FROM public.sale_items si
        WHERE si.sale_id = s.id
      ), '[]'::jsonb)
    ) AS row_data
    FROM public.sales s
    LEFT JOIN public.branches b ON b.id = s.branch_id
    WHERE s.status = 'completed'
      AND s.sold_at >= v_from AND s.sold_at <= v_to
      AND (p_branch_id IS NULL OR s.branch_id = p_branch_id)
      AND (
        p_cursor_ts IS NULL
        OR (s.sold_at, s.id) < (p_cursor_ts, p_cursor_id)
      )
    ORDER BY s.sold_at DESC, s.id DESC
    LIMIT v_limit
  ) sub;

  RETURN jsonb_build_object(
    'items', coalesce(v_rows, '[]'::jsonb),
    'limit', v_limit
  );
END;
$$;

REVOKE ALL ON FUNCTION public.acc_get_sales_detail(timestamptz, timestamptz, uuid, int, timestamptz, uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.acc_get_sales_detail(timestamptz, timestamptz, uuid, int, timestamptz, uuid) TO authenticated;

-- =============================================================================
-- تحديث create_sale لدعم حفظ التوصيف الدقيق للصنف (نوع اللحم / الدجاج / السمك)
-- =============================================================================
CREATE OR REPLACE FUNCTION public.create_sale(p jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_client uuid := nullif(p->>'client_id','')::uuid;
  v_session uuid := nullif(p->>'session_id','')::uuid;
  v_branch_id uuid := nullif(p->>'branch_id','')::uuid;
  v_branch public.branches%rowtype;
  v_existing public.sales%rowtype;
  v_email text;
  v_cashier text;
  v_item jsonb;
  v_pid uuid;
  v_vid uuid;
  v_qty numeric;
  v_price numeric;
  v_pname text;
  v_vlabel text;
  v_cost numeric;
  v_subtotal numeric;
  v_discount numeric := coalesce(nullif(p->>'discount_amount','')::numeric, 0);
  v_vat numeric := coalesce(nullif(p->>'vat_amount','')::numeric, 0);
  v_total numeric;
  v_sent_total numeric := nullif(p->>'total','')::numeric;
  v_sold timestamptz := coalesce(nullif(p->>'sold_at','')::timestamptz, now());
  v_num integer;
  v_inv text;
  v_sale_id uuid;
begin
  if v_uid is null then raise exception 'يجب تسجيل الدخول'; end if;
  perform public._assert_branch_allowed(v_branch_id);
  if v_client is null then raise exception 'معرّف الفاتورة مطلوب'; end if;
  if v_sold > now() + interval '5 minutes' then v_sold := now(); end if;

  select * into v_existing from public.sales where client_id = v_client;
  if found then
    if v_existing.cashier_id <> v_uid then raise exception 'معرّف الفاتورة مستخدم بالفعل'; end if;
    return jsonb_build_object('id', v_existing.id, 'invoice_number', v_existing.invoice_number, 'already_exists', true);
  end if;

  select * into v_branch from public.branches
   where id = v_branch_id and deleted_at is null and is_active;
  if not found then raise exception 'الفرع غير موجود أو غير نشط'; end if;

  select email into v_email from auth.users where id = v_uid;
  v_cashier := split_part(coalesce(v_email, ''), '@', 1);

  if jsonb_typeof(p->'items') is distinct from 'array' or jsonb_array_length(p->'items') = 0 then
    raise exception 'الفاتورة فارغة';
  end if;

  select coalesce(sum(round((i->>'qty')::numeric * (i->>'unit_price')::numeric, 2)), 0)
    into v_subtotal from jsonb_array_elements(p->'items') i;

  if v_discount < 0 or v_discount > v_subtotal then raise exception 'قيمة الخصم غير صحيحة'; end if;
  if v_vat < 0 then raise exception 'قيمة الضريبة غير صحيحة'; end if;

  v_total := round(v_subtotal - v_discount + v_vat, 2);
  if v_sent_total is not null and abs(v_sent_total - v_total) > 0.01 then
    raise exception 'إجمالي الفاتورة غير متطابق مع الأصناف';
  end if;

  insert into public.branch_invoice_counters (branch_id, last_number)
  values (v_branch.id, 1)
  on conflict (branch_id)
  do update set last_number = public.branch_invoice_counters.last_number + 1
  returning last_number into v_num;

  v_inv := coalesce(nullif(v_branch.code, ''), 'BR') || '-' || lpad(v_num::text, 6, '0');

  insert into public.sales (
    client_id, invoice_number, local_number, branch_id, branch_name, branch_code,
    cashier_id, cashier_name, shift, session_id, payment_method,
    subtotal, discount_amount, discount_percent, vat_rate, vat_amount, total, notes, sold_at
  ) values (
    v_client, v_inv, nullif(p->>'local_number',''), v_branch.id, v_branch.name, v_branch.code,
    v_uid, v_cashier, nullif(p->>'shift',''), v_session,
    coalesce(nullif(p->>'payment_method',''), 'cash'),
    v_subtotal, v_discount, nullif(p->>'discount_percent','')::numeric,
    coalesce(nullif(p->>'vat_rate','')::numeric, 0), v_vat, v_total, nullif(p->>'notes',''), v_sold
  )
  returning id into v_sale_id;

  for v_item in select value from jsonb_array_elements(p->'items')
  loop
    v_qty   := (v_item->>'qty')::numeric;
    v_price := (v_item->>'unit_price')::numeric;
    v_pid   := nullif(v_item->>'product_id','')::uuid;
    v_vid   := nullif(v_item->>'variant_id','')::uuid;

    if v_qty is null or v_qty <= 0 or v_price is null or v_price < 0 then
      raise exception 'كمية أو سعر غير صحيح في أحد الأصناف';
    end if;

    if v_vid is not null then
      select pr.id, pr.name, pv.label, pv.cost into v_pid, v_pname, v_vlabel, v_cost
        from public.product_variants pv join public.products pr on pr.id = pv.product_id
       where pv.id = v_vid;
    else
      select pr.name, null::text, pr.cost into v_pname, v_vlabel, v_cost
        from public.products pr where pr.id = v_pid;
    end if;

    if v_pname is null then raise exception 'أحد المنتجات غير موجود'; end if;

    -- الحفاظ على التوصيف الدقيق للصنف المرسل من نقطة البيع (مثل: وجبة متكاملة (لحم) والوزن)
    v_pname  := coalesce(nullif(trim(v_item->>'product_name'), ''), v_pname);
    v_vlabel := coalesce(nullif(trim(v_item->>'variant_label'), ''), v_vlabel);

    insert into public.sale_items (sale_id, product_id, variant_id, product_name, variant_label, qty, unit_price, unit_cost, line_total)
    values (v_sale_id, v_pid, v_vid, v_pname, v_vlabel, v_qty, v_price, coalesce(v_cost, 0), round(v_qty * v_price, 2));
  end loop;

  return jsonb_build_object('id', v_sale_id, 'invoice_number', v_inv, 'already_exists', false);
end;
$function$;

revoke all on function public.create_sale(jsonb) from public, anon;
grant execute on function public.create_sale(jsonb) to authenticated;

COMMIT;
