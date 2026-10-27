-- ══════════════════════════════════════════════════════════════════════════════
-- 040_meals_report_aggregation_and_costs.sql
-- 1. تصفير سعر وتكلفة البيع لوجبات الباقات (سعرها 0 وتكلفتها 0) حتى لا تُطرح من المكسب
-- 2. تصحيح إجمالي الفواتير السابقة وتطابق ملخص المبيعات مع تقرير بيع الوجبات
-- 3. تقرير الوجبات المحدث (تجميع كل الفروع بدون تكرار + التكلفة والأرباح)
-- ══════════════════════════════════════════════════════════════════════════════

-- ── 1. تصحيح البيانات السابقة: جعل سعر وتكلفة الباقات = 0 وتحديث الفواتير ────
UPDATE public.sale_items
SET unit_price = 0,
    line_total = 0,
    unit_cost  = 0
WHERE is_package = true OR unit_price = 0;

-- تحديث إجمالي الفواتير السابقة في sales التي كان قد أُضيف لها سعر الباقة بالخطأ
UPDATE public.sales s
SET subtotal = coalesce((
      SELECT sum(si.line_total)
      FROM public.sale_items si
      WHERE si.sale_id = s.id
    ), 0),
    total = round(
      coalesce((
        SELECT sum(si.line_total)
        FROM public.sale_items si
        WHERE si.sale_id = s.id
      ), 0) - coalesce(s.discount_amount, 0) + coalesce(s.vat_amount, 0)
    , 2)
WHERE EXISTS (
  SELECT 1 FROM public.sale_items si
  WHERE si.sale_id = s.id
    AND si.is_package = true
);


-- ── 2. تحديث دالة create_sale لتضمن دائماً أن الباقات سعرها وتكلفتها = 0 ─────
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
  v_sale_id uuid;
  v_inv text;
  v_num bigint;
  v_subtotal numeric := 0;
  v_discount numeric := coalesce(nullif(p->>'discount_amount','')::numeric, 0);
  v_vat numeric := coalesce(nullif(p->>'vat_amount','')::numeric, 0);
  v_total numeric;
  v_sold timestamptz := coalesce(nullif(p->>'sold_at','')::timestamptz, now());
  v_is_pkg boolean;
begin
  if v_uid is null then raise exception 'يجب تسجيل الدخول'; end if;
  if v_client is null then raise exception 'client_id مطلوب'; end if;
  if v_branch_id is null then raise exception 'الفرع مطلوب'; end if;

  select * into v_existing from public.sales where client_id = v_client limit 1;
  if found then
    return jsonb_build_object('id', v_existing.id, 'invoice_number', v_existing.invoice_number, 'already_exists', true);
  end if;

  select * into v_branch from public.branches
   where id = v_branch_id and deleted_at is null and is_active;
  if not found then raise exception 'الفرع غير موجود أو غير نشط'; end if;

  select email into v_email from auth.users where id = v_uid;
  v_cashier := split_part(coalesce(v_email, ''), '@', 1);

  -- احتساب المجموع الفرعي مع اعتبار الباقات = 0
  select coalesce(sum(
    case
      when coalesce((item->>'is_package')::boolean, false) = true or coalesce((item->>'unit_price')::numeric, 0) = 0 then 0
      else (item->>'qty')::numeric * (item->>'unit_price')::numeric
    end
  ), 0)
    into v_subtotal
    from jsonb_array_elements(p->'items') as item;

  v_total := round(v_subtotal - v_discount + v_vat, 2);

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

    if v_qty is null or v_qty <= 0 then
      raise exception 'كمية غير صحيحة في أحد الأصناف';
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

    v_pname  := coalesce(nullif(trim(v_item->>'product_name'), ''), v_pname);
    v_vlabel := coalesce(nullif(trim(v_item->>'variant_label'), ''), v_vlabel);
    v_is_pkg := coalesce((v_item->>'is_package')::boolean, (v_price = 0), false);

    -- الباقات: سعرها وتكلفتها كلاهما = 0
    if v_is_pkg then
      v_price := 0;
      v_cost := 0;
    end if;

    insert into public.sale_items (sale_id, product_id, variant_id, product_name, variant_label, qty, unit_price, unit_cost, line_total, is_package)
    values (v_sale_id, v_pid, v_vid, v_pname, v_vlabel, v_qty, v_price, coalesce(v_cost, 0), round(v_qty * v_price, 2), v_is_pkg);
  end loop;

  return jsonb_build_object('id', v_sale_id, 'invoice_number', v_inv, 'already_exists', false);
end;
$function$;

REVOKE ALL ON FUNCTION public.create_sale(jsonb) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.create_sale(jsonb) TO authenticated;


-- ── 3. تحديث دالة acc_get_sales_summary (لا تخصم تكلفة الباقات من المكسب) ──
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
  v_total_cost  numeric := 0;
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

  -- 2) تجميع تكلفة المبيعات (فقط للمبيعات العادية، وتكلفة الباقات = 0 حتى لا تُخصم من المكسب)
  SELECT coalesce(sum(
    CASE
      WHEN (si.is_package = true OR coalesce(si.unit_price, 0) = 0) THEN 0
      ELSE si.qty * coalesce(nullif(si.unit_cost, 0), pv.cost, pr.cost, 0)
    END
  ), 0)
  INTO v_total_cost
  FROM public.sale_items si
  JOIN public.sales s ON s.id = si.sale_id
  LEFT JOIN public.product_variants pv ON pv.id = si.variant_id
  LEFT JOIN public.products pr ON pr.id = si.product_id
  WHERE s.status = 'completed'
    AND s.sold_at >= v_from AND s.sold_at <= v_to
    AND (p_branch_id IS NULL OR s.branch_id = p_branch_id);

  -- 3) تجميع المصروفات المعتمدة (approved أو posted)
  SELECT
    coalesce(sum(ei.total), 0),
    coalesce(sum(ei.total) FILTER (WHERE ei.payment_method = 'cash'), 0)
  INTO v_exp_total, v_exp_cash
  FROM public.expense_invoices ei
  WHERE ei.status IN ('approved', 'posted')
    AND ei.expense_date >= (v_from AT TIME ZONE 'Africa/Cairo')::date
    AND ei.expense_date <= (v_to AT TIME ZONE 'Africa/Cairo')::date
    AND (p_branch_id IS NULL OR ei.branch_id = p_branch_id);

  -- 4) المبيعات لكل فرع
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
    'total_cost',     round(v_total_cost, 2),
    'gross_profit',   round(v_total_sales - v_total_cost, 2),
    'profit_margin',  case when v_total_sales > 0 then round((v_total_sales - v_total_cost) / v_total_sales * 100, 1) else 0 end,
    'net_revenue',    (v_total_sales - v_exp_total),
    'by_branch',      v_by_branch
  );
END;
$$;

REVOKE ALL ON FUNCTION public.acc_get_sales_summary(timestamptz, timestamptz, uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.acc_get_sales_summary(timestamptz, timestamptz, uuid) TO authenticated;


-- ── 4. دالة تقرير الوجبات (المنيو): الباقات سعرها 0 وتكلفتها 0 ولا تخصم من المكسب ──
DROP FUNCTION IF EXISTS public.acc_get_meals_report(uuid, timestamptz, timestamptz);

CREATE OR REPLACE FUNCTION public.acc_get_meals_report(
  p_branch_id  uuid        DEFAULT NULL,
  p_from       timestamptz DEFAULT NULL,
  p_to         timestamptz DEFAULT NULL
)
RETURNS TABLE (
  branch_name      text,
  product_name     text,
  variant_label    text,
  total_qty        numeric,
  unit_cost        numeric,
  total_cost       numeric,
  total_revenue    numeric,
  net_profit       numeric,
  profit_margin    numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_branch_id IS NULL THEN
    -- ── كل الفروع: مجمعة على مستوى الأصناف بدون تكرار فروع ──
    RETURN QUERY
    SELECT
      'جميع الفروع'::text                                  AS branch_name,
      trim(regexp_replace(si.product_name, '\s*-\s*باقة$', '')) AS product_name,
      coalesce(nullif(trim(si.variant_label), ''), '—')     AS variant_label,
      sum(si.qty)::numeric                                 AS total_qty,
      round(coalesce(
        sum(CASE WHEN (si.is_package = true OR coalesce(si.unit_price, 0) = 0) THEN 0 ELSE si.qty * coalesce(nullif(si.unit_cost, 0), pv.cost, pr.cost, 0) END)
        / nullif(sum(CASE WHEN (si.is_package = true OR coalesce(si.unit_price, 0) = 0) THEN 0 ELSE si.qty END), 0)
      , 0), 2)::numeric                                    AS unit_cost,
      round(sum(CASE WHEN (si.is_package = true OR coalesce(si.unit_price, 0) = 0) THEN 0 ELSE si.qty * coalesce(nullif(si.unit_cost, 0), pv.cost, pr.cost, 0) END), 2)::numeric AS total_cost,
      round(sum(CASE WHEN (si.is_package = true OR coalesce(si.unit_price, 0) = 0) THEN 0 ELSE coalesce(si.line_total, si.qty * si.unit_price) END), 2)::numeric AS total_revenue,
      round(
        sum(CASE WHEN (si.is_package = true OR coalesce(si.unit_price, 0) = 0) THEN 0 ELSE coalesce(si.line_total, si.qty * si.unit_price) END)
        - sum(CASE WHEN (si.is_package = true OR coalesce(si.unit_price, 0) = 0) THEN 0 ELSE si.qty * coalesce(nullif(si.unit_cost, 0), pv.cost, pr.cost, 0) END)
      , 2)::numeric                                        AS net_profit,
      CASE
        WHEN sum(CASE WHEN (si.is_package = true OR coalesce(si.unit_price, 0) = 0) THEN 0 ELSE coalesce(si.line_total, si.qty * si.unit_price) END) > 0 THEN
          round(
            (
              sum(CASE WHEN (si.is_package = true OR coalesce(si.unit_price, 0) = 0) THEN 0 ELSE coalesce(si.line_total, si.qty * si.unit_price) END)
              - sum(CASE WHEN (si.is_package = true OR coalesce(si.unit_price, 0) = 0) THEN 0 ELSE si.qty * coalesce(nullif(si.unit_cost, 0), pv.cost, pr.cost, 0) END)
            ) / sum(CASE WHEN (si.is_package = true OR coalesce(si.unit_price, 0) = 0) THEN 0 ELSE coalesce(si.line_total, si.qty * si.unit_price) END) * 100
          , 1)::numeric
        ELSE 0
      END AS profit_margin
    FROM sale_items si
    JOIN sales s ON s.id = si.sale_id
    LEFT JOIN product_variants pv ON pv.id = si.variant_id
    LEFT JOIN products pr ON pr.id = si.product_id
    WHERE (p_from IS NULL OR s.sold_at >= p_from)
      AND (p_to   IS NULL OR s.sold_at <= p_to)
      AND s.status = 'completed'
    GROUP BY trim(regexp_replace(si.product_name, '\s*-\s*باقة$', '')), coalesce(nullif(trim(si.variant_label), ''), '—')
    ORDER BY sum(si.qty) DESC, trim(regexp_replace(si.product_name, '\s*-\s*باقة$', ''));

  ELSE
    -- ── فرع محدد: استخراج مبيعات هذا الفرع فقط ──
    RETURN QUERY
    SELECT
      b.name                                               AS branch_name,
      trim(regexp_replace(si.product_name, '\s*-\s*باقة$', '')) AS product_name,
      coalesce(nullif(trim(si.variant_label), ''), '—')     AS variant_label,
      sum(si.qty)::numeric                                 AS total_qty,
      round(coalesce(
        sum(CASE WHEN (si.is_package = true OR coalesce(si.unit_price, 0) = 0) THEN 0 ELSE si.qty * coalesce(nullif(si.unit_cost, 0), pv.cost, pr.cost, 0) END)
        / nullif(sum(CASE WHEN (si.is_package = true OR coalesce(si.unit_price, 0) = 0) THEN 0 ELSE si.qty END), 0)
      , 0), 2)::numeric                                    AS unit_cost,
      round(sum(CASE WHEN (si.is_package = true OR coalesce(si.unit_price, 0) = 0) THEN 0 ELSE si.qty * coalesce(nullif(si.unit_cost, 0), pv.cost, pr.cost, 0) END), 2)::numeric AS total_cost,
      round(sum(CASE WHEN (si.is_package = true OR coalesce(si.unit_price, 0) = 0) THEN 0 ELSE coalesce(si.line_total, si.qty * si.unit_price) END), 2)::numeric AS total_revenue,
      round(
        sum(CASE WHEN (si.is_package = true OR coalesce(si.unit_price, 0) = 0) THEN 0 ELSE coalesce(si.line_total, si.qty * si.unit_price) END)
        - sum(CASE WHEN (si.is_package = true OR coalesce(si.unit_price, 0) = 0) THEN 0 ELSE si.qty * coalesce(nullif(si.unit_cost, 0), pv.cost, pr.cost, 0) END)
      , 2)::numeric                                        AS net_profit,
      CASE
        WHEN sum(CASE WHEN (si.is_package = true OR coalesce(si.unit_price, 0) = 0) THEN 0 ELSE coalesce(si.line_total, si.qty * si.unit_price) END) > 0 THEN
          round(
            (
              sum(CASE WHEN (si.is_package = true OR coalesce(si.unit_price, 0) = 0) THEN 0 ELSE coalesce(si.line_total, si.qty * si.unit_price) END)
              - sum(CASE WHEN (si.is_package = true OR coalesce(si.unit_price, 0) = 0) THEN 0 ELSE si.qty * coalesce(nullif(si.unit_cost, 0), pv.cost, pr.cost, 0) END)
            ) / sum(CASE WHEN (si.is_package = true OR coalesce(si.unit_price, 0) = 0) THEN 0 ELSE coalesce(si.line_total, si.qty * si.unit_price) END) * 100
          , 1)::numeric
        ELSE 0
      END AS profit_margin
    FROM sale_items si
    JOIN sales s ON s.id = si.sale_id
    JOIN branches b ON b.id = s.branch_id
    LEFT JOIN product_variants pv ON pv.id = si.variant_id
    LEFT JOIN products pr ON pr.id = si.product_id
    WHERE s.branch_id = p_branch_id
      AND (p_from IS NULL OR s.sold_at >= p_from)
      AND (p_to   IS NULL OR s.sold_at <= p_to)
      AND s.status = 'completed'
    GROUP BY b.name, trim(regexp_replace(si.product_name, '\s*-\s*باقة$', '')), coalesce(nullif(trim(si.variant_label), ''), '—')
    ORDER BY sum(si.qty) DESC, trim(regexp_replace(si.product_name, '\s*-\s*باقة$', ''));
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.acc_get_meals_report(uuid, timestamptz, timestamptz)
  TO authenticated;


-- ── 5. تحديث دالة acc_get_sales_detail لدعم الوزن (variant_label) وعلامة is_package في تفاصيل الفاتورة ──
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
          'line_total',    si.line_total,
          'is_package',    coalesce(si.is_package, false)
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

