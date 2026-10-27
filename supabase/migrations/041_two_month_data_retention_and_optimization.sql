-- =============================================================================
-- Migration: 041_two_month_data_retention_and_optimization.sql
-- Description: تطبيق سياسة الاحتفاظ بالبيانات لشهرين فقط وحذف البيانات القديمة
--              وتقليل استهلاك مساحة قاعدة البيانات لأقصى درجة.
-- 
-- القواعد المعتمدة:
--   1) مدة الحفظ بداخل قاعدة البيانات هي شهرين فقط (الشهر السابق والشهر الحالي).
--   2) كل يوم 5 من كل شهر: يتم تشغيل عملية التنظيف وحذف بيانات ما قبل الشهر السابق.
--      مثال: في شهر أكتوبر (10): المحفوظ هو شهر 9 و شهر 10.
--            في يوم 5/10: يُحذف شهر 8 وما قبله.
--            في شهر نوفمبر (11): في 5/11 يُحذف شهر 9 وما قبله، ويتبقى شهر 10 وشهر 11.
--   3) مسح كافة السجلات التشغيلية القديمة: المبيعات، المصروفات، أوامر التوريد،
--      طلبات الفروع، حركات المخزون القديمة، تشغيلات المطبخ، الجرد، الإقفالات،
--      الإشعارات وسجلات التدقيق، وحضور وإجازات وخصومات الموظفين.
--   4) الحفاظ التام على البيانات الأساسية الثابتة: الموظفين، الفروع، المستخدمين،
--      الأصناف، المنتجات، وأرصدة المخزون الفعلية الحالية (inventory_stock).
--   5) عدم تخزين أي تقارير أو ملفات ثابتة في جداول الداتا بيز (الحساب يتم لحظياً عبر RPCs).
-- =============================================================================

-- ═══════════════════════════════════════════════════════════════════
-- § 1. دالة تنظيف الحسابات والعمليات والمخزون والإشعارات (acc_purge_expired_retention_data)
-- ═══════════════════════════════════════════════════════════════════
create or replace function public.acc_purge_expired_retention_data(
  p_force boolean default false
) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_today          date := current_date;
  v_day            int  := extract(day from v_today);
  v_cutoff         date;
  v_sales_cnt      int  := 0;
  v_items_cnt      int  := 0;
  v_exp_cnt        int  := 0;
  v_supply_cnt     int  := 0;
  v_branch_ord_cnt int  := 0;
  v_kitchen_cnt    int  := 0;
  v_stocktake_cnt  int  := 0;
  v_closings_cnt   int  := 0;
  v_movements_cnt  int  := 0;
  v_notif_cnt      int  := 0;
  v_audit_cnt      int  := 0;
  v_log_id         uuid;
begin
  -- التنفيذ التلقائي يبدأ من يوم 5 في الشهر (أول 4 أيام مهلة لإقفال وتصدير الشهر المنصرم)
  if v_day < 5 and not p_force then
    return jsonb_build_object(
      'status', 'skipped',
      'reason', 'Retention purge executes on or after day 5 of the month',
      'current_day', v_day
    );
  end if;

  -- الحد الفاصل: أول يوم من الشهر السابق (now - 1 month)
  -- كل ما قبل هذا التاريخ يُحذف نهائياً لضمان بقاء شهرين فقط (السابق والحالي)
  v_cutoff := date_trunc('month', v_today - interval '1 month')::date;

  -- 1. المبيعات وبنودها
  with del_items as (
    delete from public.sale_items
    where sale_id in (select id from public.sales where sold_at::date < v_cutoff)
    returning id
  )
  select count(*) into v_items_cnt from del_items;

  with del_sales as (
    delete from public.sales
    where sold_at::date < v_cutoff
    returning id
  )
  select count(*) into v_sales_cnt from del_sales;

  -- 2. المصروفات
  with del_exp as (
    delete from public.expenses
    where expense_date < v_cutoff
    returning id
  )
  select count(*) into v_exp_cnt from del_exp;

  -- 3. طلبات وأوامر التوريد
  delete from public.supply_order_lines
  where order_id in (select id from public.supply_orders where created_at::date < v_cutoff);

  with del_supply as (
    delete from public.supply_orders
    where created_at::date < v_cutoff
    returning id
  )
  select count(*) into v_supply_cnt from del_supply;

  -- 4. طلبات الفروع
  delete from public.branch_order_lines
  where order_id in (select id from public.branch_orders where created_at::date < v_cutoff);

  with del_bo as (
    delete from public.branch_orders
    where created_at::date < v_cutoff
    returning id
  )
  select count(*) into v_branch_ord_cnt from del_bo;

  -- 5. صرفيات ودفعات المطبخ
  delete from public.kitchen_issue_lines
  where issue_id in (select id from public.kitchen_issues where created_at::date < v_cutoff);

  delete from public.kitchen_issues
  where created_at::date < v_cutoff;

  with del_batches as (
    delete from public.kitchen_batches
    where created_at::date < v_cutoff
    returning id
  )
  select count(*) into v_kitchen_cnt from del_batches;

  -- 6. مراجعات وسطور وعمليات الجرد القديمة
  delete from public.stocktake_reviews
  where stocktake_id in (select id from public.stocktakes where created_at::date < v_cutoff);

  delete from public.stocktake_lines
  where stocktake_id in (select id from public.stocktakes where created_at::date < v_cutoff);

  with del_stk as (
    delete from public.stocktakes
    where created_at::date < v_cutoff
    returning id
  )
  select count(*) into v_stocktake_cnt from del_stk;

  -- 7. مراجعات الإقفالات وإقفالات الورديات القديمة
  delete from public.closing_reviews
  where closing_id in (select id from public.shift_closings where closed_at::date < v_cutoff);

  with del_closings as (
    delete from public.shift_closings
    where closed_at::date < v_cutoff
    returning id
  )
  select count(*) into v_closings_cnt from del_closings;

  -- 8. حركات المخزون القديمة المنتهية (مع بقاء أرصدة inventory_stock سليمة ومحدثة)
  with del_mov as (
    delete from public.inventory_movements
    where created_at::date < v_cutoff
    returning id
  )
  select count(*) into v_movements_cnt from del_mov;

  -- 9. قراءات الإشعارات والإشعارات القديمة
  delete from public.notification_reads
  where notification_id in (select id from public.notifications where created_at::date < v_cutoff);

  with del_notif as (
    delete from public.notifications
    where created_at::date < v_cutoff
    returning id
  )
  select count(*) into v_notif_cnt from del_notif;

  -- 10. سجل التدقيق القديم (Audit Log)
  with del_audit as (
    delete from public.audit_log
    where changed_at::date < v_cutoff
    returning id
  )
  select count(*) into v_audit_cnt from del_audit;

  -- 11. تنظيف سجلات الحذف القديمة نفسها (أقدم من 3 أشهر) لعدم تراكمها
  delete from public.acc_retention_logs
  where purged_at::date < (v_today - interval '3 month')::date;

  -- 12. تسجيل إحصائيات الحذف
  insert into public.acc_retention_logs (
    cutoff_date, sales_deleted, sale_items_deleted,
    expenses_deleted, supply_orders_del, closings_deleted, details
  ) values (
    v_cutoff, v_sales_cnt, v_items_cnt,
    v_exp_cnt, v_supply_cnt, v_closings_cnt,
    jsonb_build_object(
      'executed_at', now(),
      'forced', p_force,
      'today', v_today,
      'branch_orders_deleted', v_branch_ord_cnt,
      'kitchen_batches_deleted', v_kitchen_cnt,
      'stocktakes_deleted', v_stocktake_cnt,
      'movements_deleted', v_movements_cnt,
      'notifications_deleted', v_notif_cnt,
      'audit_logs_deleted', v_audit_cnt
    )
  ) returning id into v_log_id;

  return jsonb_build_object(
    'status', 'success',
    'log_id', v_log_id,
    'cutoff_date', v_cutoff,
    'sales_deleted', v_sales_cnt,
    'sale_items_deleted', v_items_cnt,
    'expenses_deleted', v_exp_cnt,
    'supply_orders_deleted', v_supply_cnt,
    'branch_orders_deleted', v_branch_ord_cnt,
    'stocktakes_deleted', v_stocktake_cnt,
    'closings_deleted', v_closings_cnt,
    'movements_deleted', v_movements_cnt,
    'notifications_deleted', v_notif_cnt,
    'audit_logs_deleted', v_audit_cnt
  );
end;
$$;

revoke all on function public.acc_purge_expired_retention_data(boolean) from public, anon;
grant execute on function public.acc_purge_expired_retention_data(boolean) to authenticated;


-- ═══════════════════════════════════════════════════════════════════
-- § 2. دالة تنظيف الموارد البشرية (hr_purge_expired_retention_data)
-- ═══════════════════════════════════════════════════════════════════
create or replace function public.hr_purge_expired_retention_data(
  p_force boolean default false
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_today       date := current_date;
  v_day         int  := extract(day from v_today);
  v_cutoff      date;
  v_att_count   int  := 0;
  v_leave_count int  := 0;
  v_ded_count   int  := 0;
  v_log_id      uuid;
begin
  if v_day < 5 and not p_force then
    return jsonb_build_object(
      'status', 'skipped',
      'reason', 'Retention purge executes on or after day 5 of the month',
      'current_day', v_day
    );
  end if;

  -- الحد الفاصل: أول يوم من الشهر السابق (now - 1 month)
  v_cutoff := date_trunc('month', v_today - interval '1 month')::date;

  -- 1. حذف سجلات الحضور
  with del_att as (
    delete from public.attendance_records
    where record_date < v_cutoff
    returning id
  )
  select count(*) into v_att_count from del_att;

  -- 2. حذف سجلات الإجازات
  with del_leave as (
    delete from public.leave_requests
    where end_date < v_cutoff
    returning id
  )
  select count(*) into v_leave_count from del_leave;

  -- 3. حذف سجلات الخصومات والمكافآت
  with del_ded as (
    delete from public.deduction_bonus_requests
    where created_at::date < v_cutoff
    returning id
  )
  select count(*) into v_ded_count from del_ded;

  -- 4. تنظيف سجلات الحذف القديمة نفسها (أقدم من 3 أشهر)
  delete from public.hr_retention_logs
  where purged_at::date < (v_today - interval '3 month')::date;

  -- 5. تسجيل في سجلات الاحتفاظ
  insert into public.hr_retention_logs (
    cutoff_date, attendance_deleted, leaves_deleted, deductions_deleted, details
  ) values (
    v_cutoff, v_att_count, v_leave_count, v_ded_count,
    jsonb_build_object(
      'executed_at', now(),
      'forced', p_force,
      'today', v_today
    )
  ) returning id into v_log_id;

  return jsonb_build_object(
    'status', 'success',
    'log_id', v_log_id,
    'cutoff_date', v_cutoff,
    'attendance_deleted', v_att_count,
    'leaves_deleted', v_leave_count,
    'deductions_deleted', v_ded_count
  );
end;
$$;

revoke all on function public.hr_purge_expired_retention_data(boolean) from public, anon;
grant execute on function public.hr_purge_expired_retention_data(boolean) to authenticated;


-- ═══════════════════════════════════════════════════════════════════
-- § 3. دالة التنظيف الموحدة الشاملة للنظام (system_purge_all_expired_data)
-- ═══════════════════════════════════════════════════════════════════
create or replace function public.system_purge_all_expired_data(
  p_force boolean default false
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_acc_res jsonb;
  v_hr_res  jsonb;
begin
  -- استدعاء تنظيف الحسابات والمخزون
  v_acc_res := public.acc_purge_expired_retention_data(p_force);
  -- استدعاء تنظيف الموارد البشرية
  v_hr_res  := public.hr_purge_expired_retention_data(p_force);

  return jsonb_build_object(
    'executed_at', now(),
    'policy', '2_months_retention (previous and current month)',
    'accounting_and_operations', v_acc_res,
    'human_resources', v_hr_res
  );
end;
$$;

revoke all on function public.system_purge_all_expired_data(boolean) from public, anon;
grant execute on function public.system_purge_all_expired_data(boolean) to authenticated;


-- ═══════════════════════════════════════════════════════════════════
-- § 4. دالة فحص ومراقبة استهلاك مساحة التخزين (system_get_storage_stats)
-- ═══════════════════════════════════════════════════════════════════
create or replace function public.system_get_storage_stats()
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_tables jsonb;
begin
  select jsonb_agg(
    jsonb_build_object(
      'table_name', t.table_name,
      'row_count', coalesce(s.n_live_tup, 0),
      'total_size', pg_size_pretty(pg_total_relation_size(quote_ident(t.table_schema) || '.' || quote_ident(t.table_name)))
    ) order by coalesce(s.n_live_tup, 0) desc
  ) into v_tables
  from information_schema.tables t
  left join pg_stat_user_tables s on s.schemaname = t.table_schema and s.relname = t.table_name
  where t.table_schema = 'public' and t.table_type = 'BASE TABLE';

  return jsonb_build_object(
    'generated_at', now(),
    'database_size', pg_size_pretty(pg_database_size(current_database())),
    'tables', coalesce(v_tables, '[]'::jsonb)
  );
end;
$$;

revoke all on function public.system_get_storage_stats() from public, anon;
grant execute on function public.system_get_storage_stats() to authenticated;


-- ═══════════════════════════════════════════════════════════════════
-- § 5. جدولة مهام pg_cron التلقائية شهرياً
-- ═══════════════════════════════════════════════════════════════════
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    -- إزالة المهام السابقة لتوحيدها
    perform cron.unschedule('acc-monthly-retention-purge')
      where exists (select 1 from cron.job where jobname = 'acc-monthly-retention-purge');
    perform cron.unschedule('hr-monthly-retention-purge')
      where exists (select 1 from cron.job where jobname = 'hr-monthly-retention-purge');
    perform cron.unschedule('system-monthly-retention-purge')
      where exists (select 1 from cron.job where jobname = 'system-monthly-retention-purge');

    -- جدولة التنظيف الشامل يوم 5 من كل شهر الساعة 00:20 ليلاً
    perform cron.schedule(
      'system-monthly-retention-purge',
      '20 0 5 * *',
      'select public.system_purge_all_expired_data(false);'
    );
  end if;
exception when others then
  raise notice 'pg_cron not available: %', sqlerrm;
end;
$$;
