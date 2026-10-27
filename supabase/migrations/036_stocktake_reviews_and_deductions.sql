-- =============================================================================
-- Migration 036: Stocktake Reviews, Accountant Audits & Worker Deductions
-- مراجعة واعتماد الجرد وتطبيق خصومات عمال المطبخ والمخزون
-- (آمنة تماماً 100% ولا تحذف أي بيانات سابقة إطلاقاً)
-- =============================================================================

create table if not exists public.stocktake_reviews (
  id                    uuid primary key default gen_random_uuid(),
  stocktake_id          uuid not null references public.stocktakes(id) on delete cascade unique,
  status                text not null default 'pending_review' 
                        check (status in ('pending_review', 'approved', 'approved_with_deduction')),
  reviewed_by           uuid references auth.users(id),
  reviewed_at           timestamptz default now(),
  reviewer_name         text,
  review_notes          text,
  deduction_request_id  uuid references public.deduction_bonus_requests(id) on delete set null,
  deduction_employee_id uuid references public.employees(id) on delete set null,
  deduction_employee_name text,
  deduction_employee_role text,
  deduction_amount      numeric(12,2) default 0,
  shortage_value        numeric(12,2) default 0,
  damage_value          numeric(12,2) default 0,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

alter table public.stocktake_reviews enable row level security;
grant all on table public.stocktake_reviews to authenticated;

-- إنشاء سياسات الأمان بأمان تام دون استخدام DROP
do $$
begin
  if not exists (
    select 1 from pg_policies 
    where tablename = 'stocktake_reviews' and policyname = 'stocktake_reviews_select'
  ) then
    create policy "stocktake_reviews_select"
      on public.stocktake_reviews for select
      to authenticated using (true);
  end if;

  if not exists (
    select 1 from pg_policies 
    where tablename = 'stocktake_reviews' and policyname = 'stocktake_reviews_insert'
  ) then
    create policy "stocktake_reviews_insert"
      on public.stocktake_reviews for insert
      to authenticated with check (true);
  end if;

  if not exists (
    select 1 from pg_policies 
    where tablename = 'stocktake_reviews' and policyname = 'stocktake_reviews_update'
  ) then
    create policy "stocktake_reviews_update"
      on public.stocktake_reviews for update
      to authenticated using (true);
  end if;
end $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- دالة جلب الجرودات الشاملة مع المراجعات والخصومات
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.acc_get_stocktake_audits(
  p_from timestamptz default null,
  p_to   timestamptz default null
) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_res jsonb;
begin
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', st.id,
      'number', st.number,
      'created_at', st.created_at,
      'notes', st.notes,
      'total_items', st.total_items,
      'total_adjust', st.total_adjust,
      'total_damage', st.total_damage,
      'warehouse_id', st.warehouse_id,
      'applied_by', st.applied_by,
      -- التقييم المالي للعجز والتالف
      'shortage_value', coalesce((
        select round(sum(case when sl.adjust_qty < 0 then abs(sl.adjust_qty) * sl.unit_cost else 0 end), 2)
        from public.stocktake_lines sl where sl.stocktake_id = st.id
      ), 0),
      'damage_value', coalesce((
        select round(sum(sl.damaged_qty * sl.unit_cost), 2)
        from public.stocktake_lines sl where sl.stocktake_id = st.id
      ), 0),
      'surplus_value', coalesce((
        select round(sum(case when sl.adjust_qty > 0 then sl.adjust_qty * sl.unit_cost else 0 end), 2)
        from public.stocktake_lines sl where sl.stocktake_id = st.id
      ), 0),
      -- حالة المراجعة والخصم
      'review_status', coalesce(sr.status, 'pending_review'),
      'reviewed_at', sr.reviewed_at,
      'reviewer_name', sr.reviewer_name,
      'review_notes', sr.review_notes,
      'deduction_amount', coalesce(sr.deduction_amount, 0),
      'deduction_employee_id', sr.deduction_employee_id,
      'deduction_employee_name', sr.deduction_employee_name,
      'deduction_employee_role', sr.deduction_employee_role,
      'deduction_request_id', sr.deduction_request_id
    ) order by st.created_at desc
  ), '[]'::jsonb)
  into v_res
  from public.stocktakes st
  left join public.stocktake_reviews sr on sr.stocktake_id = st.id
  where (p_from is null or st.created_at >= p_from)
    and (p_to is null or st.created_at <= p_to);

  return v_res;
end;
$$;
grant execute on function public.acc_get_stocktake_audits(timestamptz, timestamptz) to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- دالة اعتماد الجرد دون خصم
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.acc_approve_stocktake_without_deduction(
  p_stocktake_id uuid,
  p_notes text default null,
  p_reviewer_name text default null
) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
begin
  insert into public.stocktake_reviews (
    stocktake_id, status, reviewed_by, reviewed_at, reviewer_name, review_notes
  ) values (
    p_stocktake_id, 'approved', auth.uid(), now(), coalesce(p_reviewer_name, 'المحاسب'), p_notes
  )
  on conflict (stocktake_id) do update set
    status = 'approved',
    reviewed_by = auth.uid(),
    reviewed_at = now(),
    reviewer_name = coalesce(p_reviewer_name, stocktake_reviews.reviewer_name),
    review_notes = coalesce(p_notes, stocktake_reviews.review_notes),
    updated_at = now();

  return jsonb_build_object('success', true, 'status', 'approved');
end;
$$;
grant execute on function public.acc_approve_stocktake_without_deduction(uuid, text, text) to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- دالة اعتماد الجرد مع خصم لعمال المطبخ/المخزون وإرساله لـ HR
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.acc_submit_stocktake_deduction(
  p_stocktake_id uuid,
  p_employee_id uuid,
  p_amount numeric,
  p_notes text,
  p_reviewer_name text default null
) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_emp record;
  v_req_id uuid;
  v_st_num text;
begin
  -- التحقق من الموظف ودوره (عمال المطبخ والمخزون فقط)
  select id, full_name, job_role into v_emp
  from public.employees
  where id = p_employee_id and status = 'active';

  if not found then
    raise exception 'الموظف غير موجود أو غير نشط';
  end if;

  if v_emp.job_role not in ('kitchen_worker', 'chef', 'storekeeper', 'worker') then
    raise exception 'الخصم متاح فقط لعمال المطبخ والمخزون';
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'يجب تحديد مبلغ خصم صحيح';
  end if;

  select number into v_st_num from public.stocktakes where id = p_stocktake_id;

  -- إنشاء طلب الخصم في جدول طلبات الـ HR
  insert into public.deduction_bonus_requests (
    employee_id,
    requested_from,
    type,
    amount_type,
    cash_amount,
    notes,
    status,
    created_by
  ) values (
    p_employee_id,
    'inventory',
    'deduction',
    'cash',
    p_amount,
    coalesce(p_notes, 'خصم عجز جرد مخزون رقم ' || coalesce(v_st_num, '')),
    'pending',
    auth.uid()
  )
  returning id into v_req_id;

  -- تسجيل أو تحديث مراجعة الجرد
  insert into public.stocktake_reviews (
    stocktake_id,
    status,
    reviewed_by,
    reviewed_at,
    reviewer_name,
    review_notes,
    deduction_request_id,
    deduction_employee_id,
    deduction_employee_name,
    deduction_employee_role,
    deduction_amount
  ) values (
    p_stocktake_id,
    'approved_with_deduction',
    auth.uid(),
    now(),
    coalesce(p_reviewer_name, 'المحاسب'),
    p_notes,
    v_req_id,
    p_employee_id,
    v_emp.full_name,
    v_emp.job_role,
    p_amount
  )
  on conflict (stocktake_id) do update set
    status = 'approved_with_deduction',
    reviewed_by = auth.uid(),
    reviewed_at = now(),
    reviewer_name = coalesce(p_reviewer_name, stocktake_reviews.reviewer_name),
    review_notes = coalesce(p_notes, stocktake_reviews.review_notes),
    deduction_request_id = v_req_id,
    deduction_employee_id = p_employee_id,
    deduction_employee_name = v_emp.full_name,
    deduction_employee_role = v_emp.job_role,
    deduction_amount = p_amount,
    updated_at = now();

  return jsonb_build_object(
    'success', true,
    'status', 'approved_with_deduction',
    'deduction_request_id', v_req_id
  );
end;
$$;
grant execute on function public.acc_submit_stocktake_deduction(uuid, uuid, numeric, text, text) to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- دالة جلب عمال المطبخ والمخزون المتاحين للخصم بصلاحية مأمونة
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.acc_get_kitchen_and_warehouse_employees()
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_res jsonb;
begin
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', e.id,
      'code', e.code,
      'full_name', e.full_name,
      'job_role', e.job_role,
      'branch_id', e.branch_id,
      'branch_name', coalesce(b.name, 'المستودع والمطبخ الرئيسي'),
      'basic_salary', e.basic_salary,
      'status', e.status
    ) order by e.full_name
  ), '[]'::jsonb)
  into v_res
  from public.employees e
  left join public.branches b on b.id = e.branch_id
  where e.status = 'active'
    and e.job_role in ('kitchen_worker', 'chef', 'storekeeper', 'worker');

  return v_res;
end;
$$;
grant execute on function public.acc_get_kitchen_and_warehouse_employees() to authenticated;

-- منح قراءة الموظفين للمستخدمين المصادقين لضمان عدم توقف الاستعلامات
grant select on public.employees to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_policies 
    where tablename = 'employees' and policyname = 'employees_select_authenticated'
  ) then
    create policy "employees_select_authenticated"
      on public.employees for select
      to authenticated using (true);
  end if;
end $$;
