-- =============================================================================
-- 035_fix_closings_sales_and_breakdown.sql
-- إصلاح إجمالي المبيعات ومبيعات الكاش والشبكة في شاشة الإقفالات ولوحة التحكم
-- المشكلة الجذرية: عند إغلاق الوردية، المبيعات لم تتزامن بعد فحُسب
--   expected_cash = opening_cash + 0 = خطأ
-- ثم تزامنت المبيعات فأصبح total_sales صحيح لكن expected_cash بقي خاطئاً
-- الحل:
--   1. تصحيح expected_cash و difference لجميع الورديات المتأثرة
--   2. تحديث acc_get_closings ليحسب cash_sales, expected_cash, difference دائماً من الواقع
--   3. تحديث acc_get_closings_dashboard كذلك
-- =============================================================================

BEGIN;

-- ── 1. إصلاح البيانات التاريخية: جميع الورديات التي expected_cash خاطئ ──────
-- نحسب cash_sales الفعلي من جدول sales، ثم نحدث expected_cash والفرق
UPDATE public.shift_closings sc
SET
  total_sales    = sub.tot,
  cash_sales     = sub.csh,
  card_sales     = sub.crd,
  other_sales    = sub.oth,
  invoices_count = sub.cnt,
  expected_cash  = round(sc.opening_cash + sub.csh, 2),
  difference     = round(sc.counted_cash  - (sc.opening_cash + sub.csh), 2)
FROM (
  SELECT
    sc2.id,
    coalesce(sum(s.total), 0)
        AS tot,
    coalesce(sum(s.total) FILTER (
        WHERE coalesce(s.payment_method, '') ILIKE ANY (
            ARRAY['%cash%','%كاش%','%نقد%'])), 0)
        AS csh,
    coalesce(sum(s.total) FILTER (
        WHERE coalesce(s.payment_method, '') ILIKE ANY (
            ARRAY['%card%','%visa%','%pos%','%network%','%شبكة%','%مدى%','%فيزا%','%بطاق%'])), 0)
        AS crd,
    coalesce(sum(s.total) FILTER (
        WHERE NOT (coalesce(s.payment_method, '') ILIKE ANY (
            ARRAY['%cash%','%كاش%','%نقد%','%card%','%visa%','%pos%','%network%','%شبكة%','%مدى%','%فيزا%','%بطاق%']))), 0)
        AS oth,
    count(s.id) AS cnt
  FROM public.shift_closings sc2
  JOIN public.sales s ON (
    -- ربط بالـ session أولاً
    s.session_id = sc2.session_id
    OR (
      -- ربط بالوقت ككتابة احتياطية
      s.cashier_id = sc2.cashier_id
      AND sc2.opened_at IS NOT NULL
      AND sc2.closed_at IS NOT NULL
      AND s.created_at >= sc2.opened_at
      AND s.created_at <= sc2.closed_at
      AND (sc2.branch_id IS NULL OR s.branch_id = sc2.branch_id)
    )
  )
  WHERE s.status = 'completed'
  GROUP BY sc2.id
) sub
WHERE sc.id = sub.id
  -- نصحح أي وردية فيها expected_cash لا يساوي opening_cash + cash_sales الفعلي
  AND abs(coalesce(sc.expected_cash, 0) - round(sc.opening_cash + sub.csh, 2)) > 0.009;

-- ── 2. acc_get_closings — قائمة الإقفالات الكاملة (Keyset Pagination) ────────
CREATE OR REPLACE FUNCTION public.acc_get_closings(
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
    RAISE EXCEPTION 'صلاحية مرفوضة';
  END IF;
  IF _has_role('branch_manager') AND NOT _has_role('accountant', 'owner') THEN
    IF p_branch_id IS NULL OR NOT _can_act_for_branch(p_branch_id) THEN
      RAISE EXCEPTION 'مدير الفرع يمكنه عرض إقفالات فرعه فقط';
    END IF;
  END IF;

  SELECT jsonb_agg(row_data)
  INTO   v_rows
  FROM (
    SELECT
      -- نحسب cash_sales الفعلي أولاً ثم نشتق منه expected_cash والفرق
      jsonb_build_object(
        'id',              sc.id,
        'branch_id',       sc.branch_id,
        'branch_name',     coalesce(b.name, '—'),
        'cashier_id',      sc.cashier_id,
        'cashier_name',    coalesce(p.full_name, split_part(u.email, '@', 1), '—'),
        'shift',           coalesce(sc.shift, 'الوردية الأولى'),
        'opening_cash',    coalesce(sc.opening_cash, 0),
        'counted_cash',    coalesce(sc.counted_cash, 0),
        -- إجمالي المبيعات: من المخزن أو يُحسب من جدول sales
        'total_sales',     coalesce(
                             NULLIF(sc.total_sales, 0),
                             (SELECT coalesce(sum(s.total), 0)
                              FROM public.sales s
                              WHERE (s.session_id = sc.session_id
                                     OR (s.cashier_id = sc.cashier_id
                                         AND sc.opened_at IS NOT NULL AND sc.closed_at IS NOT NULL
                                         AND s.created_at BETWEEN sc.opened_at AND sc.closed_at
                                         AND (sc.branch_id IS NULL OR s.branch_id = sc.branch_id)))
                                AND s.status = 'completed'),
                             0
                           ),
        -- مبيعات الكاش: المصدر الأهم لأنه يؤثر على expected_cash
        'cash_sales',      (SELECT coalesce(sum(s.total), 0)
                            FROM public.sales s
                            WHERE (s.session_id = sc.session_id
                                   OR (s.cashier_id = sc.cashier_id
                                       AND sc.opened_at IS NOT NULL AND sc.closed_at IS NOT NULL
                                       AND s.created_at BETWEEN sc.opened_at AND sc.closed_at
                                       AND (sc.branch_id IS NULL OR s.branch_id = sc.branch_id)))
                              AND coalesce(s.payment_method, '') ILIKE ANY (ARRAY['%cash%','%كاش%','%نقد%'])
                              AND s.status = 'completed'),
        -- مبيعات الشبكة
        'card_sales',      (SELECT coalesce(sum(s.total), 0)
                            FROM public.sales s
                            WHERE (s.session_id = sc.session_id
                                   OR (s.cashier_id = sc.cashier_id
                                       AND sc.opened_at IS NOT NULL AND sc.closed_at IS NOT NULL
                                       AND s.created_at BETWEEN sc.opened_at AND sc.closed_at
                                       AND (sc.branch_id IS NULL OR s.branch_id = sc.branch_id)))
                              AND coalesce(s.payment_method, '') ILIKE ANY (ARRAY['%card%','%visa%','%pos%','%network%','%شبكة%','%مدى%','%فيزا%','%بطاق%'])
                              AND s.status = 'completed'),
        'other_sales',     coalesce(sc.other_sales, 0),
        'invoices_count',  coalesce(
                             NULLIF(sc.invoices_count, 0),
                             (SELECT count(*)
                              FROM public.sales s
                              WHERE (s.session_id = sc.session_id
                                     OR (s.cashier_id = sc.cashier_id
                                         AND sc.opened_at IS NOT NULL AND sc.closed_at IS NOT NULL
                                         AND s.created_at BETWEEN sc.opened_at AND sc.closed_at
                                         AND (sc.branch_id IS NULL OR s.branch_id = sc.branch_id)))
                                AND s.status = 'completed'),
                             0
                           ),
        -- ── الحسابات المالية الصحيحة ──────────────────────────────────────
        -- expected_cash = رصيد الافتتاح + مبيعات الكاش الفعلية
        'expected_cash',   round(
                             coalesce(sc.opening_cash, 0) +
                             (SELECT coalesce(sum(s.total), 0)
                              FROM public.sales s
                              WHERE (s.session_id = sc.session_id
                                     OR (s.cashier_id = sc.cashier_id
                                         AND sc.opened_at IS NOT NULL AND sc.closed_at IS NOT NULL
                                         AND s.created_at BETWEEN sc.opened_at AND sc.closed_at
                                         AND (sc.branch_id IS NULL OR s.branch_id = sc.branch_id)))
                                AND coalesce(s.payment_method, '') ILIKE ANY (ARRAY['%cash%','%كاش%','%نقد%'])
                                AND s.status = 'completed'),
                             2
                           ),
        -- difference = الكاش المعدود - الكاش المتوقع الفعلي
        'difference',      round(
                             coalesce(sc.counted_cash, 0) -
                             (
                               coalesce(sc.opening_cash, 0) +
                               (SELECT coalesce(sum(s.total), 0)
                                FROM public.sales s
                                WHERE (s.session_id = sc.session_id
                                       OR (s.cashier_id = sc.cashier_id
                                           AND sc.opened_at IS NOT NULL AND sc.closed_at IS NOT NULL
                                           AND s.created_at BETWEEN sc.opened_at AND sc.closed_at
                                           AND (sc.branch_id IS NULL OR s.branch_id = sc.branch_id)))
                                  AND coalesce(s.payment_method, '') ILIKE ANY (ARRAY['%cash%','%كاش%','%نقد%'])
                                  AND s.status = 'completed')
                             ),
                             2
                           ),
        'has_mismatch',    sc.has_mismatch,
        'opened_at',       sc.opened_at,
        'closed_at',       sc.closed_at,
        'notes',           sc.notes,
        'review', CASE
          WHEN cr.id IS NOT NULL THEN jsonb_build_object(
            'id',                   cr.id,
            'original_difference',  cr.original_difference,
            'reviewed_difference',  cr.reviewed_difference,
            'review_reason',        cr.review_reason,
            'accountant_notes',     cr.accountant_notes,
            'reviewed_at',          cr.reviewed_at,
            'deduction_request_id', cr.deduction_request_id,
            'deduction_status',     dbr.status
          )
          ELSE NULL
        END
      ) AS row_data
    FROM public.shift_closings sc
    LEFT JOIN public.branches b ON b.id = sc.branch_id
    LEFT JOIN auth.users u ON u.id = sc.cashier_id
    LEFT JOIN public.profiles p ON p.id = sc.cashier_id
    LEFT JOIN public.closing_reviews cr ON cr.closing_id = sc.id
    LEFT JOIN public.deduction_bonus_requests dbr ON dbr.id = cr.deduction_request_id
    WHERE sc.closed_at >= v_from AND sc.closed_at <= v_to
      AND (p_branch_id IS NULL OR sc.branch_id = p_branch_id)
      AND (
        p_cursor_ts IS NULL
        OR (sc.closed_at, sc.id) < (p_cursor_ts, p_cursor_id)
      )
    ORDER BY sc.closed_at DESC, sc.id DESC
    LIMIT v_limit
  ) sub;

  RETURN jsonb_build_object(
    'items', coalesce(v_rows, '[]'::jsonb),
    'limit', v_limit
  );
END;
$$;

REVOKE ALL ON FUNCTION public.acc_get_closings(timestamptz, timestamptz, uuid, int, timestamptz, uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.acc_get_closings(timestamptz, timestamptz, uuid, int, timestamptz, uuid) TO authenticated;

-- ── 3. acc_get_closings_dashboard — لوحة التحكم ────────────────────────────
CREATE OR REPLACE FUNCTION public.acc_get_closings_dashboard(
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
  v_uid  uuid := auth.uid();
  v_from timestamptz := coalesce(p_from, date_trunc('month', now()));
  v_to   timestamptz := coalesce(p_to, now());
  v_rows jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'يجب تسجيل الدخول أولاً';
  END IF;
  IF NOT _has_role('accountant', 'owner', 'branch_manager') THEN
    RAISE EXCEPTION 'صلاحية مرفوضة';
  END IF;

  SELECT jsonb_agg(row_data)
  INTO   v_rows
  FROM (
    SELECT jsonb_build_object(
      'id',                  sc.id,
      'branch_name',         coalesce(b.name, '—'),
      'cashier_name',        coalesce(p.full_name, split_part(u.email, '@', 1), '—'),
      'shift',               coalesce(sc.shift, 'الوردية الأولى'),
      -- إجمالي المبيعات محسوب فعلياً
      'total_sales',         (SELECT coalesce(sum(s.total), 0)
                              FROM public.sales s
                              WHERE (s.session_id = sc.session_id
                                     OR (s.cashier_id = sc.cashier_id
                                         AND sc.opened_at IS NOT NULL AND sc.closed_at IS NOT NULL
                                         AND s.created_at BETWEEN sc.opened_at AND sc.closed_at
                                         AND (sc.branch_id IS NULL OR s.branch_id = sc.branch_id)))
                                AND s.status = 'completed'),
      -- الفرق الصحيح = كاش معدود - (رصيد افتتاح + كاش فعلي)
      'difference',          round(
                               coalesce(sc.counted_cash, 0) - (
                                 coalesce(sc.opening_cash, 0) +
                                 (SELECT coalesce(sum(s.total), 0)
                                  FROM public.sales s
                                  WHERE (s.session_id = sc.session_id
                                         OR (s.cashier_id = sc.cashier_id
                                             AND sc.opened_at IS NOT NULL AND sc.closed_at IS NOT NULL
                                             AND s.created_at BETWEEN sc.opened_at AND sc.closed_at
                                             AND (sc.branch_id IS NULL OR s.branch_id = sc.branch_id)))
                                    AND coalesce(s.payment_method, '') ILIKE ANY (ARRAY['%cash%','%كاش%','%نقد%'])
                                    AND s.status = 'completed')
                               ), 2
                             ),
      'closed_at',           sc.closed_at,
      'has_mismatch',        sc.has_mismatch,
      'is_reviewed',         (cr.id IS NOT NULL)
    ) AS row_data
    FROM public.shift_closings sc
    LEFT JOIN public.branches b ON b.id = sc.branch_id
    LEFT JOIN auth.users u ON u.id = sc.cashier_id
    LEFT JOIN public.profiles p ON p.id = sc.cashier_id
    LEFT JOIN public.closing_reviews cr ON cr.closing_id = sc.id
    WHERE sc.closed_at >= v_from AND sc.closed_at <= v_to
      AND (p_branch_id IS NULL OR sc.branch_id = p_branch_id)
    ORDER BY sc.closed_at DESC
    LIMIT 20
  ) sub;

  RETURN coalesce(v_rows, '[]'::jsonb);
END;
$$;

REVOKE ALL ON FUNCTION public.acc_get_closings_dashboard(timestamptz, timestamptz, uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.acc_get_closings_dashboard(timestamptz, timestamptz, uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
