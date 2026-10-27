-- ══════════════════════════════════════════════════════════════════════════════
-- 038_sale_items_package_flag.sql
-- إضافة حقل is_package لجدول sale_items + RPC لتقرير مبيعات الباقات
-- ══════════════════════════════════════════════════════════════════════════════

-- 1. إضافة عمود is_package إلى sale_items (لو لم يكن موجوداً)
alter table sale_items
  add column if not exists is_package boolean not null default false;

-- 2. RPC: acc_get_package_sales — حذف النسخة القديمة وإعادة الإنشاء بالنوع الصحيح
drop function if exists acc_get_package_sales(uuid, timestamptz, timestamptz);

create function acc_get_package_sales(
  p_branch_id  uuid        default null,
  p_from       timestamptz default null,
  p_to         timestamptz default null
)
returns table (
  sale_id          uuid,
  local_number     text,
  branch_name      text,
  sold_at          timestamptz,
  product_name     text,
  variant_label    text,
  qty              numeric,
  original_price   numeric,
  cashier_name     text,
  payment_method   text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  select
    s.id                    as sale_id,
    s.local_number,
    b.name                  as branch_name,
    s.sold_at,
    si.product_name,
    si.variant_label,
    si.qty::numeric         as qty,
    si.unit_price           as original_price,
    s.cashier_name,
    s.payment_method
  from sale_items si
  join sales      s  on s.id = si.sale_id
  join branches   b  on b.id = s.branch_id
  where si.is_package = true
    and (p_branch_id is null or s.branch_id = p_branch_id)
    and (p_from      is null or s.sold_at  >= p_from)
    and (p_to        is null or s.sold_at  <= p_to)
  order by s.sold_at desc;
end;
$$;

grant execute on function acc_get_package_sales(uuid, timestamptz, timestamptz)
  to authenticated;

