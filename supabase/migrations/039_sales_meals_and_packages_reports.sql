-- ══════════════════════════════════════════════════════════════════════════════
-- 039_sales_meals_and_packages_reports.sql
-- تقرير مبيعات الباقات (محدث) + تقرير الوجبات والمنيو + تحسين create_sale
-- ══════════════════════════════════════════════════════════════════════════════

-- 1. تحديث الأصناف السابقة التي سعرها 0 لتُعتبر باقات
update public.sale_items
   set is_package = true
 where (unit_price = 0 or coalesce(line_total, 0) = 0)
   and is_package = false;

-- 2. تحديث دالة create_sale لتخزين is_package تلقائياً إذا تم تحديدها أو كان السعر 0
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
  v_is_pkg boolean;
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

  select coalesce(sum((item->>'qty')::numeric * (item->>'unit_price')::numeric), 0)
    into v_subtotal
    from jsonb_array_elements(p->'items') as item;

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

    -- الحفاظ على التوصيف الدقيق للصنف المرسل من نقطة البيع
    v_pname  := coalesce(nullif(trim(v_item->>'product_name'), ''), v_pname);
    v_vlabel := coalesce(nullif(trim(v_item->>'variant_label'), ''), v_vlabel);
    v_is_pkg := coalesce((v_item->>'is_package')::boolean, (v_price = 0), false);

    insert into public.sale_items (sale_id, product_id, variant_id, product_name, variant_label, qty, unit_price, unit_cost, line_total, is_package)
    values (v_sale_id, v_pid, v_vid, v_pname, v_vlabel, v_qty, v_price, coalesce(v_cost, 0), round(v_qty * v_price, 2), v_is_pkg);
  end loop;

  return jsonb_build_object('id', v_sale_id, 'invoice_number', v_inv, 'already_exists', false);
end;
$function$;

revoke all on function public.create_sale(jsonb) from public, anon;
grant execute on function public.create_sale(jsonb) to authenticated;


-- 3. دالة تقرير الباقات: اسم الوجبة، وزنها، عدد الوجبات، اسم الفرع
-- أي وجبة سعرها 0 أو معلمة كباقة
drop function if exists acc_get_package_sales(uuid, timestamptz, timestamptz);

create function acc_get_package_sales(
  p_branch_id  uuid        default null,
  p_from       timestamptz default null,
  p_to         timestamptz default null
)
returns table (
  branch_name    text,
  product_name   text,
  variant_label  text,
  total_qty      numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  select
    b.name                                               as branch_name,
    si.product_name,
    coalesce(nullif(trim(si.variant_label), ''), '—')     as variant_label,
    sum(si.qty)::numeric                                 as total_qty
  from sale_items si
  join sales      s  on s.id = si.sale_id
  join branches   b  on b.id = s.branch_id
  where (si.is_package = true or coalesce(si.unit_price, 0) = 0)
    and (p_branch_id is null or s.branch_id = p_branch_id)
    and (p_from      is null or s.sold_at  >= p_from)
    and (p_to        is null or s.sold_at  <= p_to)
  group by b.name, si.product_name, coalesce(nullif(trim(si.variant_label), ''), '—')
  order by b.name, si.product_name, variant_label;
end;
$$;

grant execute on function acc_get_package_sales(uuid, timestamptz, timestamptz)
  to authenticated;


-- 4. دالة تقرير الوجبات (المنيو): الكميات المسحوبة من كل فرع والرصيد المالي لكل وجبة
-- الباقات تُحسب كعدد وجبات عادي لكن في السعر النهائي قيمتها 0
drop function if exists acc_get_meals_report(uuid, timestamptz, timestamptz);

create function acc_get_meals_report(
  p_branch_id  uuid        default null,
  p_from       timestamptz default null,
  p_to         timestamptz default null
)
returns table (
  branch_name      text,
  product_name     text,
  variant_label    text,
  total_qty        numeric,
  package_qty      numeric,
  regular_qty      numeric,
  total_revenue    numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  select
    b.name                                               as branch_name,
    si.product_name,
    coalesce(nullif(trim(si.variant_label), ''), '—')     as variant_label,
    sum(si.qty)::numeric                                 as total_qty,
    sum(case when (si.is_package = true or coalesce(si.unit_price, 0) = 0) then si.qty else 0 end)::numeric as package_qty,
    sum(case when (si.is_package = true or coalesce(si.unit_price, 0) = 0) then 0 else si.qty end)::numeric as regular_qty,
    sum(case when (si.is_package = true or coalesce(si.unit_price, 0) = 0) then 0 else coalesce(si.line_total, si.qty * si.unit_price) end)::numeric as total_revenue
  from sale_items si
  join sales      s  on s.id = si.sale_id
  join branches   b  on b.id = s.branch_id
  where (p_branch_id is null or s.branch_id = p_branch_id)
    and (p_from      is null or s.sold_at  >= p_from)
    and (p_to        is null or s.sold_at  <= p_to)
  group by b.name, si.product_name, coalesce(nullif(trim(si.variant_label), ''), '—')
  order by b.name, si.product_name, variant_label;
end;
$$;

grant execute on function acc_get_meals_report(uuid, timestamptz, timestamptz)
  to authenticated;
