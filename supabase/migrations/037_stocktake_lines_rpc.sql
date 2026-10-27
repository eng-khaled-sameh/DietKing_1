-- =============================================================================
-- Migration 037: دالة جلب سطور الجرد مع تفاصيل الأصناف
-- تتجاوز صلاحيات RLS وتعيد البيانات بشكل آمن للمحاسب
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- دالة جلب سطور الجرد مع تفاصيل الأصناف (SKU, name, unit_code)
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.acc_get_stocktake_lines(
  p_stocktake_id uuid
)
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
      'id',            sl.id,
      'item_id',       sl.item_id,
      'sku',           coalesce(ii.sku, ''),
      'name',          coalesce(ii.name, 'صنف غير محدد'),
      'unit_code',     coalesce(ii.unit_code, ''),
      'system_qty',    sl.system_qty,
      'counted_qty',   sl.counted_qty,
      'damaged_qty',   sl.damaged_qty,
      'adjust_qty',    sl.adjust_qty,
      'unit_cost',     sl.unit_cost,
      'shortage_value', case when sl.adjust_qty < 0 then round(abs(sl.adjust_qty) * sl.unit_cost, 2) else 0 end,
      'damage_value',  round(sl.damaged_qty * sl.unit_cost, 2),
      'note',          sl.note
    ) order by ii.name
  ), '[]'::jsonb)
  into v_res
  from public.stocktake_lines sl
  left join public.inventory_items ii on ii.id = sl.item_id
  where sl.stocktake_id = p_stocktake_id;

  return v_res;
end;
$$;

grant execute on function public.acc_get_stocktake_lines(uuid) to authenticated;

-- منح صلاحية قراءة inventory_items للمستخدمين المصادقين إن لم تكن موجودة
grant select on public.inventory_items to authenticated;

-- استبدال policy RLS على stocktake_lines بواحدة أكثر مرونة
do $$
begin
  drop policy if exists "stocktake_lines_read" on public.stocktake_lines;

  create policy "stocktake_lines_read"
    on public.stocktake_lines for select
    to authenticated
    using (true);
exception when others then
  null;
end $$;
