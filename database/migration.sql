-- Fol-Hope Farm teaching/demo database. Fictional seed data only.
create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;
create schema if not exists farm_private;
revoke all on schema farm_private from public, anon, authenticated;


create table if not exists farm_private.users(
 id uuid primary key default gen_random_uuid(), full_name text not null, email text not null unique,
 password_hash text not null, role text not null check(role in ('admin','manager','storekeeper','sales_officer','division_staff')),
 division_slug text, active boolean not null default true, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists farm_private.sessions(
 token_hash text primary key, user_id uuid not null references farm_private.users(id) on delete cascade,
 expires_at timestamptz not null, created_at timestamptz not null default now()
);
create table if not exists farm_private.login_attempts(email text primary key, attempts int not null default 0, blocked_until timestamptz);
create table if not exists farm_private.divisions(
 slug text primary key, name text not null, description text not null default ''
);
create table if not exists farm_private.units(
 id uuid primary key default gen_random_uuid(), division_slug text not null references farm_private.divisions(slug),
 name text not null, code text not null, kind text not null, created_at timestamptz not null default now(), unique(division_slug,code)
);
create table if not exists farm_private.batches(
 id uuid primary key default gen_random_uuid(), division_slug text not null references farm_private.divisions(slug),
 unit_id uuid references farm_private.units(id), code text not null, subtype text not null default '', start_date date not null default current_date,
 initial_qty numeric(14,2) not null check(initial_qty>=0), quantity_unit text not null, status text not null default 'active' check(status in ('active','closed')),
 notes text not null default '', created_by uuid references farm_private.users(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(division_slug,code)
);
create table if not exists farm_private.inventory_items(
 id uuid primary key default gen_random_uuid(), division_slug text references farm_private.divisions(slug), batch_id uuid references farm_private.batches(id),
 sku text not null unique, product_name text not null, unit text not null, reorder_level numeric(14,2) not null default 0 check(reorder_level>=0),
 item_type text not null default 'product', created_at timestamptz not null default now()
);
create table if not exists farm_private.inventory_movements(
 id uuid primary key default gen_random_uuid(), item_id uuid not null references farm_private.inventory_items(id), division_slug text references farm_private.divisions(slug),
 movement_type text not null, qty_signed numeric(14,2) not null check(qty_signed<>0), reference_type text not null, reference_id uuid,
 effective_date date not null default current_date, actor_id uuid references farm_private.users(id), posted_at timestamptz not null default now(),
 unique(reference_type,reference_id,item_id,movement_type)
);
create table if not exists farm_private.production_events(
 id uuid primary key default gen_random_uuid(), batch_id uuid not null references farm_private.batches(id), event_type text not null,
 event_date date not null default current_date, quantity numeric(14,2) not null check(quantity>0), unit text not null, notes text not null default '',
 actor_id uuid references farm_private.users(id), created_at timestamptz not null default now()
);
create table if not exists farm_private.animals(
 id uuid primary key default gen_random_uuid(), division_slug text not null default 'cattle', tag text not null unique, breed text not null default '',
 sex text not null default 'Unknown', acquired_at date not null default current_date, status text not null default 'active' check(status in('active','sold','deceased')),
 current_weight_kg numeric(12,2) check(current_weight_kg is null or current_weight_kg>0), notes text not null default '',
 created_by uuid references farm_private.users(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists farm_private.animal_weights(
 id uuid primary key default gen_random_uuid(), animal_id uuid not null references farm_private.animals(id), weight_kg numeric(12,2) not null check(weight_kg>0),
 measured_on date not null default current_date, note text not null default '', actor_id uuid references farm_private.users(id), created_at timestamptz not null default now()
);
create table if not exists farm_private.egg_collections(
 id uuid primary key default gen_random_uuid(), batch_id uuid references farm_private.batches(id), collected_on date not null default current_date,
 good_count int not null check(good_count>=0), damaged_count int not null default 0 check(damaged_count>=0), note text not null default '',
 actor_id uuid references farm_private.users(id), created_at timestamptz not null default now()
);
create table if not exists farm_private.hatchery_batches(
 id uuid primary key default gen_random_uuid(), code text not null unique, set_date date not null default current_date,
 hatch_date date, eggs_set int not null check(eggs_set>0), chicks_hatched int not null default 0 check(chicks_hatched>=0), rejected_eggs int not null default 0 check(rejected_eggs>=0),
 note text not null default '', created_by uuid references farm_private.users(id), created_at timestamptz not null default now(),
 check(chicks_hatched+rejected_eggs<=eggs_set)
);
create table if not exists farm_private.sales(
 id uuid primary key default gen_random_uuid(), sale_no text not null unique, division_slug text references farm_private.divisions(slug),
 sale_date date not null default current_date, customer text not null default 'Walk-in customer', status text not null default 'posted' check(status in('posted','void')),
 total_amount numeric(14,2) not null check(total_amount>=0), paid_amount numeric(14,2) not null default 0 check(paid_amount>=0),
 created_by uuid references farm_private.users(id), created_at timestamptz not null default now(), voided_at timestamptz, voided_by uuid references farm_private.users(id)
);
create table if not exists farm_private.sale_lines(
 id uuid primary key default gen_random_uuid(), sale_id uuid not null references farm_private.sales(id) on delete restrict,
 item_id uuid not null references farm_private.inventory_items(id), quantity numeric(14,2) not null check(quantity>0), unit_price numeric(14,2) not null check(unit_price>=0), line_total numeric(14,2) not null check(line_total>=0)
);
create table if not exists farm_private.expenses(
 id uuid primary key default gen_random_uuid(), division_slug text not null references farm_private.divisions(slug), category text not null,
 amount numeric(14,2) not null check(amount>0), expense_date date not null default current_date, description text not null,
 status text not null default 'posted' check(status in('posted','void')), created_by uuid references farm_private.users(id), created_at timestamptz not null default now(), voided_at timestamptz
);
create table if not exists farm_private.feed_batches(
 id uuid primary key default gen_random_uuid(), code text not null unique, produced_on date not null default current_date,
 output_item_id uuid not null references farm_private.inventory_items(id), output_kg numeric(14,2) not null check(output_kg>0), status text not null default 'posted',
 created_by uuid references farm_private.users(id), created_at timestamptz not null default now()
);
create table if not exists farm_private.feed_batch_inputs(
 id uuid primary key default gen_random_uuid(), feed_batch_id uuid not null references farm_private.feed_batches(id),
 ingredient_item_id uuid not null references farm_private.inventory_items(id), quantity_kg numeric(14,2) not null check(quantity_kg>0)
);
create table if not exists farm_private.audit_logs(
 id uuid primary key default gen_random_uuid(), actor_id uuid references farm_private.users(id), action text not null,
 entity_type text not null, entity_id uuid, detail jsonb not null default '{}'::jsonb, occurred_at timestamptz not null default now()
);
create index if not exists movement_item_idx on farm_private.inventory_movements(item_id,posted_at);
create index if not exists events_batch_idx on farm_private.production_events(batch_id,event_date);
create index if not exists sales_date_idx on farm_private.sales(sale_date,status);
create index if not exists expenses_date_idx on farm_private.expenses(expense_date,status);
create index if not exists audit_time_idx on farm_private.audit_logs(occurred_at desc);

-- Exposed public-schema tables are never used. The only Data API door is this
-- fixed-search-path RPC; all data and opaque-token sessions remain private.
create or replace function farm_private.farm_api_impl(action text, payload jsonb default '{}'::jsonb, token text default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u farm_private.users%rowtype; r record; v_id uuid; v_div text; v_qty numeric; v_paid numeric; v_total numeric; v_item uuid; v_batch uuid; v_sale uuid; v_code text; v_item2 uuid; v_item3 uuid; v_old numeric; v_diff numeric; v_d jsonb; v_arr jsonb; v_result jsonb; v_cnt int;
begin
 if action='login' then
  if length(coalesce(payload->>'email',''))>254 or length(coalesce(payload->>'password',''))>256 then raise exception 'Invalid email or password'; end if;
  if exists(select 1 from farm_private.login_attempts where email=lower(trim(payload->>'email')) and blocked_until>now()) then raise exception 'Too many attempts. Try again in 15 minutes.'; end if;
  select * into u from farm_private.users where email=lower(trim(payload->>'email')) and active;
  if not found or u.password_hash <> extensions.crypt(coalesce(payload->>'password',''),u.password_hash) then
   insert into farm_private.login_attempts(email,attempts,blocked_until) values(lower(trim(coalesce(payload->>'email','unknown'))),1,null)
    on conflict(email) do update set attempts=case when farm_private.login_attempts.blocked_until<now() then 1 else farm_private.login_attempts.attempts+1 end,
    blocked_until=case when farm_private.login_attempts.attempts>=4 then now()+interval '15 minutes' else null end;
   return jsonb_build_object('error','Invalid email or password');
  end if;
  delete from farm_private.login_attempts where email=u.email;
  v_code=encode(extensions.gen_random_bytes(32),'hex');
  insert into farm_private.sessions(token_hash,user_id,expires_at) values(encode(extensions.digest(v_code,'sha256'),'hex'),u.id,now()+interval '8 hours');
  return jsonb_build_object('token',v_code,'user',jsonb_build_object('id',u.id,'name',u.full_name,'email',u.email,'role',u.role,'division',u.division_slug));
 end if;
 if action='logout' then delete from farm_private.sessions where token_hash=encode(extensions.digest(coalesce(token,''),'sha256'),'hex'); return jsonb_build_object('ok',true); end if;
 select x.* into u from farm_private.sessions s join farm_private.users x on x.id=s.user_id
 where s.token_hash=encode(extensions.digest(coalesce(token,''),'sha256'),'hex') and s.expires_at>now() and x.active;
 if not found then raise exception 'Session expired. Sign in again.' using errcode='28000'; end if;
 if action='state' then
  v_d=jsonb_build_object(
   'user',jsonb_build_object('id',u.id,'name',u.full_name,'email',u.email,'role',u.role,'division',u.division_slug),
   'divisions',(select coalesce(jsonb_agg(jsonb_build_object('slug',d.slug,'name',d.name,'description',d.description) order by d.name),'[]') from farm_private.divisions d),
   'batches',(select coalesce(jsonb_agg(to_jsonb(b)||jsonb_build_object('unit_name',un.name,'balance',coalesce(m.balance,b.initial_qty)) order by b.created_at desc),'[]') from farm_private.batches b left join farm_private.units un on un.id=b.unit_id left join lateral(select sum(qty_signed) balance from farm_private.inventory_movements where item_id in(select id from farm_private.inventory_items where batch_id=b.id))m on true where u.role<>'division_staff' or b.division_slug=u.division_slug),
   'events',(select coalesce(jsonb_agg(to_jsonb(e)||jsonb_build_object('batch_code',b.code,'division_slug',b.division_slug) order by e.event_date desc,e.created_at desc),'[]') from (select * from farm_private.production_events order by event_date desc limit 120) e join farm_private.batches b on b.id=e.batch_id where u.role<>'division_staff' or b.division_slug=u.division_slug),
   'animals',(select coalesce(jsonb_agg(to_jsonb(a)||jsonb_build_object('weights',(select coalesce(jsonb_agg(to_jsonb(w) order by w.measured_on desc),'[]') from farm_private.animal_weights w where w.animal_id=a.id)) order by a.created_at desc),'[]') from farm_private.animals a where u.role<>'division_staff' or a.division_slug=u.division_slug),
   'eggs',(select coalesce(jsonb_agg(to_jsonb(e)||jsonb_build_object('batch_code',b.code) order by e.collected_on desc),'[]') from farm_private.egg_collections e left join farm_private.batches b on b.id=e.batch_id where u.role<>'division_staff' or u.division_slug='eggs'),
   'hatchery',(select coalesce(jsonb_agg(to_jsonb(h) order by h.set_date desc),'[]') from farm_private.hatchery_batches h where u.role<>'division_staff' or u.division_slug='hatchery'),
   'items',(select coalesce(jsonb_agg(to_jsonb(i)||jsonb_build_object('balance',coalesce(m.balance,0)) order by i.product_name),'[]') from farm_private.inventory_items i left join lateral(select sum(qty_signed) balance from farm_private.inventory_movements where item_id=i.id)m on true where u.role<>'division_staff' or i.division_slug=u.division_slug or i.division_slug is null),
   'sales',(select coalesce(jsonb_agg(to_jsonb(s)||jsonb_build_object('lines',(select coalesce(jsonb_agg(to_jsonb(l)||jsonb_build_object('product_name',i.product_name,'unit',i.unit)),'[]') from farm_private.sale_lines l join farm_private.inventory_items i on i.id=l.item_id where l.sale_id=s.id)) order by s.sale_date desc,s.created_at desc),'[]') from farm_private.sales s where u.role<>'division_staff' or s.division_slug=u.division_slug),
   'expenses',(select coalesce(jsonb_agg(to_jsonb(e) order by e.expense_date desc),'[]') from farm_private.expenses e where u.role<>'division_staff' or e.division_slug=u.division_slug),
   'feed_batches',(select coalesce(jsonb_agg(to_jsonb(f)||jsonb_build_object('output_name',i.product_name,'inputs',(select coalesce(jsonb_agg(to_jsonb(fi)||jsonb_build_object('product_name',ii.product_name)),'[]') from farm_private.feed_batch_inputs fi join farm_private.inventory_items ii on ii.id=fi.ingredient_item_id where fi.feed_batch_id=f.id)) order by f.produced_on desc),'[]') from farm_private.feed_batches f join farm_private.inventory_items i on i.id=f.output_item_id where u.role<>'division_staff' or u.division_slug='feedmill'),
   'users',(case when u.role='admin' then (select coalesce(jsonb_agg(jsonb_build_object('id',id,'full_name',full_name,'email',email,'role',role,'division_slug',division_slug,'active',active) order by full_name),'[]') from farm_private.users) else '[]'::jsonb end),
   'audit',(case when u.role in('admin','manager') then (select coalesce(jsonb_agg(to_jsonb(a)||jsonb_build_object('actor_name',x.full_name) order by a.occurred_at desc),'[]') from (select * from farm_private.audit_logs order by occurred_at desc limit 120)a left join farm_private.users x on x.id=a.actor_id) else '[]'::jsonb end),
   'metrics',jsonb_build_object('stock_count',(select count(*) from farm_private.inventory_items),'low_stock',(select count(*) from (select i.id from farm_private.inventory_items i left join farm_private.inventory_movements m on m.item_id=i.id group by i.id,i.reorder_level having coalesce(sum(m.qty_signed),0)<=i.reorder_level)low_items),'sales_today',(select coalesce(sum(total_amount),0) from farm_private.sales where status='posted' and sale_date=current_date),'expenses_month',(select coalesce(sum(amount),0) from farm_private.expenses where status='posted' and date_trunc('month',expense_date)=date_trunc('month',current_date))));
  return v_d;
 end if;
 if action='report' then
  if u.role='division_staff' then v_div=u.division_slug; else v_div=nullif(payload->>'division','all'); end if;
  return jsonb_build_object('sales',(select coalesce(sum(total_amount),0) from farm_private.sales where status='posted' and sale_date between coalesce(nullif(payload->>'from','')::date,current_date-interval '29 days') and coalesce(nullif(payload->>'to','')::date,current_date) and (v_div is null or division_slug=v_div)),
  'paid',(select coalesce(sum(paid_amount),0) from farm_private.sales where status='posted' and sale_date between coalesce(nullif(payload->>'from','')::date,current_date-interval '29 days') and coalesce(nullif(payload->>'to','')::date,current_date) and (v_div is null or division_slug=v_div)),
  'expenses',(select coalesce(sum(amount),0) from farm_private.expenses where status='posted' and expense_date between coalesce(nullif(payload->>'from','')::date,current_date-interval '29 days') and coalesce(nullif(payload->>'to','')::date,current_date) and (v_div is null or division_slug=v_div)),
  'sales_rows',(select coalesce(jsonb_agg(to_jsonb(s)||jsonb_build_object('division_name',d.name) order by sale_date desc),'[]') from farm_private.sales s left join farm_private.divisions d on d.slug=s.division_slug where status='posted' and sale_date between coalesce(nullif(payload->>'from','')::date,current_date-interval '29 days') and coalesce(nullif(payload->>'to','')::date,current_date) and (v_div is null or division_slug=v_div)),
  'expense_rows',(select coalesce(jsonb_agg(to_jsonb(e)||jsonb_build_object('division_name',d.name) order by expense_date desc),'[]') from farm_private.expenses e left join farm_private.divisions d on d.slug=e.division_slug where status='posted' and expense_date between coalesce(nullif(payload->>'from','')::date,current_date-interval '29 days') and coalesce(nullif(payload->>'to','')::date,current_date) and (v_div is null or e.division_slug=v_div)));
 end if;
 if action='create_record' then
  if u.role not in('admin','manager','division_staff') then raise exception 'Forbidden: role cannot create farm records'; end if;
  v_div=payload->>'division'; if u.role='division_staff' and v_div<>u.division_slug then raise exception 'Forbidden: outside assigned division'; end if;
  v_code=upper(trim(payload->>'code')); v_qty=(payload->>'quantity')::numeric;
  if v_qty<=0 or v_qty>10000000 then raise exception 'Quantity must be positive and within range'; end if;
  if length(v_code)<2 or length(v_code)>40 then raise exception 'Enter a batch code between 2 and 40 characters'; end if;
  if not exists(select 1 from farm_private.divisions where slug=v_div) then raise exception 'Select a valid division'; end if;
  v_item=(select id from farm_private.units where division_slug=v_div and id=(nullif(payload->>'unit_id',''))::uuid);
  insert into farm_private.batches(division_slug,unit_id,code,subtype,start_date,initial_qty,quantity_unit,notes,created_by) values(v_div,v_item,v_code,coalesce(payload->>'subtype',''),coalesce(nullif(payload->>'date','')::date,current_date),v_qty,coalesce(payload->>'unit','head'),coalesce(payload->>'notes',''),u.id) returning id into v_id;
  insert into farm_private.inventory_items(division_slug,batch_id,sku,product_name,unit,reorder_level,item_type) values(v_div,v_id,'BATCH-'||replace(v_id::text,'-',''),v_code||' - '||coalesce(payload->>'product_name',v_code),coalesce(payload->>'unit','head'),greatest(0,coalesce(nullif(payload->>'reorder_level','')::numeric,0)),'production') returning id into v_item;
  insert into farm_private.inventory_movements(item_id,division_slug,movement_type,qty_signed,reference_type,reference_id,effective_date,actor_id) values(v_item,v_div,'opening',v_qty,'batch',v_id,coalesce(nullif(payload->>'date','')::date,current_date),u.id);
  insert into farm_private.audit_logs(actor_id,action,entity_type,entity_id,detail) values(u.id,'create','batch',v_id,jsonb_build_object('code',v_code,'opening',v_qty,'division',v_div)); return jsonb_build_object('id',v_id);
 end if;
 if action='event' then
  if u.role not in('admin','manager','division_staff') then raise exception 'Forbidden'; end if;
  v_id=(payload->>'batch_id')::uuid; v_qty=(payload->>'quantity')::numeric;
  if v_qty<=0 then raise exception 'Quantity must be positive'; end if;
  select division_slug into v_div from farm_private.batches where id=v_id and status='active' for update;
  if not found then raise exception 'Active batch not found'; end if;
  if u.role='division_staff' and u.division_slug<>v_div then raise exception 'Forbidden: outside assigned division'; end if;
  v_code=payload->>'event_type'; if v_code not in('addition','birth','mortality','death','transfer_in','transfer_out','harvest','sale','feed_used','adjustment') then raise exception 'Choose a valid event type'; end if;
  v_item=(select id from farm_private.inventory_items where batch_id=v_id);
  if v_code in('mortality','death','transfer_out','harvest','sale') then v_qty=-v_qty; end if;
  if v_code in('feed_used') then raise exception 'Feed usage is recorded as a note; record stock movements in Inventory'; end if;
  if v_code='adjustment' then if u.role<>'admin' then raise exception 'Forbidden: only admin may adjust stock'; end if; end if;
  if v_qty<0 and (select coalesce(sum(qty_signed),0) from farm_private.inventory_movements where item_id=v_item)+v_qty<0 then raise exception 'This event would make the batch balance negative'; end if;
  insert into farm_private.production_events(batch_id,event_type,event_date,quantity,unit,notes,actor_id) select v_id,v_code,coalesce(nullif(payload->>'date','')::date,current_date),abs(v_qty),quantity_unit,coalesce(payload->>'notes',''),u.id from farm_private.batches where id=v_id returning id into v_sale;
  insert into farm_private.inventory_movements(item_id,division_slug,movement_type,qty_signed,reference_type,reference_id,effective_date,actor_id) values(v_item,v_div,v_code,v_qty,'event',v_sale,coalesce(nullif(payload->>'date','')::date,current_date),u.id);
  insert into farm_private.audit_logs(actor_id,action,entity_type,entity_id,detail) values(u.id,'post_event','production_event',v_sale,jsonb_build_object('event',v_code,'quantity',abs(v_qty),'batch',v_id)); return jsonb_build_object('id',v_sale);
 end if;
 if action='inventory_receive' or action='inventory_issue' then
  if u.role not in('admin','manager','storekeeper') then raise exception 'Forbidden: storekeeper or manager required'; end if;
  v_item=(payload->>'item_id')::uuid; v_qty=(payload->>'quantity')::numeric; if v_qty<=0 then raise exception 'Quantity must be positive'; end if;
  select division_slug into v_div from farm_private.inventory_items where id=v_item for update; if not found then raise exception 'Item not found'; end if;
  if action='inventory_issue' and (select coalesce(sum(qty_signed),0) from farm_private.inventory_movements where item_id=v_item)<v_qty then raise exception 'Insufficient stock'; end if;
  insert into farm_private.inventory_movements(item_id,division_slug,movement_type,qty_signed,reference_type,reference_id,effective_date,actor_id) values(v_item,v_div,case when action='inventory_receive' then 'receipt' else 'issue' end,case when action='inventory_receive' then v_qty else -v_qty end,'manual',gen_random_uuid(),coalesce(nullif(payload->>'date','')::date,current_date),u.id) returning id into v_id;
  insert into farm_private.audit_logs(actor_id,action,entity_type,entity_id,detail) values(u.id,action,'inventory_movement',v_id,jsonb_build_object('item',v_item,'qty',v_qty)); return jsonb_build_object('id',v_id);
 end if;
 if action='save_egg' then
  if u.role not in('admin','manager','division_staff') then raise exception 'Forbidden'; end if;
  v_qty=(payload->>'good')::numeric; v_paid=coalesce(nullif(payload->>'damaged','')::numeric,0); if v_qty<0 or v_paid<0 or (v_qty+v_paid)<=0 then raise exception 'Enter a valid egg collection'; end if;
  v_batch=nullif(payload->>'batch_id','')::uuid; if v_batch is not null then select division_slug into v_div from farm_private.batches where id=v_batch and division_slug='eggs'; if not found then raise exception 'Egg flock not found'; end if; end if;
  if u.role='division_staff' and u.division_slug<>'eggs' then raise exception 'Forbidden'; end if;
  insert into farm_private.egg_collections(batch_id,collected_on,good_count,damaged_count,note,actor_id) values(v_batch,coalesce(nullif(payload->>'date','')::date,current_date),v_qty,v_paid,coalesce(payload->>'notes',''),u.id) returning id into v_id;
  v_item=(select id from farm_private.inventory_items where sku='EGGS-GOOD');
  insert into farm_private.inventory_movements(item_id,division_slug,movement_type,qty_signed,reference_type,reference_id,effective_date,actor_id) values(v_item,'eggs','egg_collection',v_qty,'egg',v_id,coalesce(nullif(payload->>'date','')::date,current_date),u.id);
  insert into farm_private.audit_logs(actor_id,action,entity_type,entity_id,detail) values(u.id,'collect','egg_collection',v_id,jsonb_build_object('good',v_qty,'damaged',v_paid)); return jsonb_build_object('id',v_id);
 end if;
 if action='save_hatchery' then
  if u.role not in('admin','manager','division_staff') or (u.role='division_staff' and u.division_slug<>'hatchery') then raise exception 'Forbidden'; end if;
  v_id=nullif(payload->>'id','')::uuid; v_qty=(payload->>'eggs_set')::numeric; v_paid=coalesce(nullif(payload->>'chicks_hatched','')::numeric,0); v_total=coalesce(nullif(payload->>'rejected_eggs','')::numeric,0);
  if v_qty<=0 or v_paid<0 or v_total<0 or v_paid+v_total>v_qty then raise exception 'Hatched and rejected eggs cannot exceed eggs set'; end if;
  if v_id is null then insert into farm_private.hatchery_batches(code,set_date,hatch_date,eggs_set,chicks_hatched,rejected_eggs,note,created_by) values(upper(trim(payload->>'code')),coalesce(nullif(payload->>'set_date','')::date,current_date),nullif(payload->>'hatch_date','')::date,v_qty,v_paid,v_total,coalesce(payload->>'notes',''),u.id) returning id into v_id;
  else update farm_private.hatchery_batches set eggs_set=v_qty,chicks_hatched=v_paid,rejected_eggs=v_total,hatch_date=nullif(payload->>'hatch_date','')::date,note=coalesce(payload->>'notes','') where id=v_id; if not found then raise exception 'Hatchery batch not found'; end if; end if;
  insert into farm_private.audit_logs(actor_id,action,entity_type,entity_id) values(u.id,case when payload ? 'id' then 'update' else 'create' end,'hatchery_batch',v_id); return jsonb_build_object('id',v_id);
 end if;
 if action='save_animal' then
  if u.role not in('admin','manager','division_staff') or (u.role='division_staff' and u.division_slug<>'cattle') then raise exception 'Forbidden'; end if;
  v_id=nullif(payload->>'id','')::uuid; if v_id is null then insert into farm_private.animals(tag,breed,sex,acquired_at,current_weight_kg,notes,created_by) values(upper(trim(payload->>'tag')),coalesce(payload->>'breed',''),coalesce(payload->>'sex','Unknown'),coalesce(nullif(payload->>'date','')::date,current_date),nullif(payload->>'weight','')::numeric,coalesce(payload->>'notes',''),u.id) returning id into v_id;
  if nullif(payload->>'weight','') is not null then insert into farm_private.animal_weights(animal_id,weight_kg,measured_on,actor_id) values(v_id,(payload->>'weight')::numeric,coalesce(nullif(payload->>'date','')::date,current_date),u.id); end if;
  else update farm_private.animals set breed=coalesce(payload->>'breed',''),sex=coalesce(payload->>'sex','Unknown'),status=coalesce(payload->>'status','active'),notes=coalesce(payload->>'notes',''),updated_at=now() where id=v_id; if not found then raise exception 'Animal not found'; end if; end if;
  insert into farm_private.audit_logs(actor_id,action,entity_type,entity_id) values(u.id,case when payload ? 'id' then 'update' else 'create' end,'animal',v_id); return jsonb_build_object('id',v_id);
 end if;
 if action='animal_weight' then
  if u.role not in('admin','manager','division_staff') then raise exception 'Forbidden'; end if;
  v_id=(payload->>'animal_id')::uuid; v_qty=(payload->>'weight')::numeric; if v_qty<=0 then raise exception 'Weight must be positive'; end if;
  if not exists(select 1 from farm_private.animals where id=v_id and status='active' and (u.role<>'division_staff' or division_slug=u.division_slug)) then raise exception 'Active animal not found or forbidden'; end if;
  insert into farm_private.animal_weights(animal_id,weight_kg,measured_on,note,actor_id) values(v_id,v_qty,coalesce(nullif(payload->>'date','')::date,current_date),coalesce(payload->>'notes',''),u.id); update farm_private.animals set current_weight_kg=v_qty,updated_at=now() where id=v_id;
  insert into farm_private.audit_logs(actor_id,action,entity_type,entity_id,detail) values(u.id,'weight','animal',v_id,jsonb_build_object('weight_kg',v_qty)); return jsonb_build_object('ok',true);
 end if;
 if action='save_sale' then
  if u.role not in('admin','manager','sales_officer','division_staff') then raise exception 'Forbidden: sales role required'; end if;
  if u.role='division_staff' and u.division_slug<>(payload->>'division') then raise exception 'Forbidden'; end if;
  if jsonb_typeof(payload->'lines')<>'array' or jsonb_array_length(payload->'lines')=0 then raise exception 'Add at least one sale line'; end if;
  v_total=0; for v_d in select * from jsonb_array_elements(payload->'lines') loop v_qty=(v_d->>'quantity')::numeric; v_paid=(v_d->>'unit_price')::numeric; if v_qty<=0 or v_paid<0 then raise exception 'Sale quantities must be positive and prices cannot be negative'; end if; v_total=v_total+v_qty*v_paid; end loop;
  v_paid=coalesce(nullif(payload->>'paid','')::numeric,0); if v_paid<0 or v_paid>v_total then raise exception 'Payment cannot exceed the sale total'; end if;
  v_code=upper(trim(coalesce(nullif(payload->>'sale_no',''),'SALE-'||to_char(now(),'YYMMDDHH24MISSMS'))));
  insert into farm_private.sales(sale_no,division_slug,sale_date,customer,total_amount,paid_amount,created_by) values(v_code,payload->>'division',coalesce(nullif(payload->>'date','')::date,current_date),coalesce(nullif(payload->>'customer',''),'Walk-in customer'),v_total,v_paid,u.id) returning id into v_sale;
  for v_d in select * from jsonb_array_elements(payload->'lines') loop v_item=(v_d->>'item_id')::uuid; v_qty=(v_d->>'quantity')::numeric; v_paid=(v_d->>'unit_price')::numeric;
   select division_slug into v_div from farm_private.inventory_items where id=v_item for update; if not found then raise exception 'A selected product is unavailable'; end if;
   if v_div is not null and v_div<>payload->>'division' and not(u.role in('admin','manager') and v_div is null) then raise exception 'Product belongs to a different division'; end if;
   if (select coalesce(sum(qty_signed),0) from farm_private.inventory_movements where item_id=v_item)<v_qty then raise exception 'Insufficient stock for selected item'; end if;
   insert into farm_private.sale_lines(sale_id,item_id,quantity,unit_price,line_total) values(v_sale,v_item,v_qty,v_paid,v_qty*v_paid);
   insert into farm_private.inventory_movements(item_id,division_slug,movement_type,qty_signed,reference_type,reference_id,effective_date,actor_id) values(v_item,payload->>'division','sale',-v_qty,'sale',v_sale,coalesce(nullif(payload->>'date','')::date,current_date),u.id);
  end loop;
  insert into farm_private.audit_logs(actor_id,action,entity_type,entity_id,detail) values(u.id,'post','sale',v_sale,jsonb_build_object('sale_no',v_code,'total',v_total,'paid',v_paid)); return jsonb_build_object('id',v_sale,'sale_no',v_code,'total',v_total);
 end if;
 if action='sale_payment' then
  if u.role not in('admin','manager','sales_officer') then raise exception 'Forbidden'; end if;
  v_sale=(payload->>'id')::uuid; v_paid=(payload->>'amount')::numeric; if v_paid<=0 then raise exception 'Payment must be positive'; end if;
  update farm_private.sales set paid_amount=paid_amount+v_paid where id=v_sale and status='posted' and paid_amount+v_paid<=total_amount returning total_amount-paid_amount into v_old; if not found then raise exception 'Payment exceeds remaining balance or sale is unavailable'; end if;
  insert into farm_private.audit_logs(actor_id,action,entity_type,entity_id,detail) values(u.id,'payment','sale',v_sale,jsonb_build_object('amount',v_paid)); return jsonb_build_object('balance',v_old);
 end if;
 if action='void_sale' then
  if u.role not in('admin','manager') then raise exception 'Forbidden: manager approval required'; end if;
  v_sale=(payload->>'id')::uuid; update farm_private.sales set status='void',voided_at=now(),voided_by=u.id where id=v_sale and status='posted'; if not found then raise exception 'Sale is already void or unavailable'; end if;
  for r in select item_id,sum(quantity) qty from farm_private.sale_lines where sale_id=v_sale group by item_id order by item_id loop insert into farm_private.inventory_movements(item_id,movement_type,qty_signed,reference_type,reference_id,actor_id) values(r.item_id,'sale_reversal',r.qty,'sale_reversal',v_sale,u.id); end loop;
  insert into farm_private.audit_logs(actor_id,action,entity_type,entity_id) values(u.id,'void','sale',v_sale); return jsonb_build_object('ok',true);
 end if;
 if action='save_expense' then
  if u.role not in('admin','manager') then raise exception 'Forbidden: manager approval required'; end if;
  v_qty=(payload->>'amount')::numeric; if v_qty<=0 then raise exception 'Expense must be positive'; end if;
  v_div=payload->>'division'; if u.role='division_staff' and v_div<>u.division_slug then raise exception 'Forbidden'; end if;
  if payload ? 'id' then v_id=(payload->>'id')::uuid; update farm_private.expenses set division_slug=v_div,category=trim(payload->>'category'),amount=v_qty,expense_date=coalesce(nullif(payload->>'date','')::date,current_date),description=trim(payload->>'description') where id=v_id and status='posted'; if not found then raise exception 'Expense not found'; end if;
  else insert into farm_private.expenses(division_slug,category,amount,expense_date,description,created_by) values(v_div,trim(payload->>'category'),v_qty,coalesce(nullif(payload->>'date','')::date,current_date),trim(payload->>'description'),u.id) returning id into v_id; end if;
  insert into farm_private.audit_logs(actor_id,action,entity_type,entity_id,detail) values(u.id,case when payload ? 'id' then 'update' else 'create' end,'expense',v_id,jsonb_build_object('amount',v_qty,'category',payload->>'category')); return jsonb_build_object('id',v_id);
 end if;
 if action='void_expense' then
  if u.role not in('admin','manager') then raise exception 'Forbidden'; end if;
  v_id=(payload->>'id')::uuid; update farm_private.expenses set status='void',voided_at=now() where id=v_id and status='posted'; if not found then raise exception 'Expense unavailable'; end if;
  insert into farm_private.audit_logs(actor_id,action,entity_type,entity_id) values(u.id,'void','expense',v_id); return jsonb_build_object('ok',true);
 end if;
 if action='produce_feed' then
  if u.role not in('admin','manager','division_staff') or (u.role='division_staff' and u.division_slug<>'feedmill') then raise exception 'Forbidden'; end if;
  if jsonb_typeof(payload->'inputs')<>'array' or jsonb_array_length(payload->'inputs')=0 then raise exception 'Add at least one ingredient'; end if;
  v_qty=(payload->>'output_kg')::numeric; if v_qty<=0 then raise exception 'Output must be positive'; end if; v_item=(payload->>'output_item_id')::uuid; v_code=upper(trim(payload->>'code'));
  if exists(select 1 from jsonb_array_elements(payload->'inputs') a join farm_private.inventory_items i on i.id=(a->>'item_id')::uuid where i.unit<>'kg') then raise exception 'Feed ingredients must use kg'; end if;
  for v_d in select * from jsonb_array_elements(payload->'inputs') loop v_item2=(v_d->>'item_id')::uuid; v_paid=(v_d->>'quantity_kg')::numeric; if v_paid<=0 then raise exception 'Ingredient quantities must be positive'; end if; perform 1 from farm_private.inventory_items where id=v_item2 for update; if (select coalesce(sum(qty_signed),0) from farm_private.inventory_movements where item_id=v_item2)<v_paid then raise exception 'Insufficient ingredient stock'; end if; end loop;
  insert into farm_private.feed_batches(code,produced_on,output_item_id,output_kg,created_by) values(v_code,coalesce(nullif(payload->>'date','')::date,current_date),v_item,v_qty,u.id) returning id into v_id;
  for v_d in select * from jsonb_array_elements(payload->'inputs') loop v_item2=(v_d->>'item_id')::uuid; v_paid=(v_d->>'quantity_kg')::numeric; insert into farm_private.feed_batch_inputs(feed_batch_id,ingredient_item_id,quantity_kg) values(v_id,v_item2,v_paid); insert into farm_private.inventory_movements(item_id,movement_type,qty_signed,reference_type,reference_id,effective_date,actor_id) values(v_item2,'feed_consumption',-v_paid,'feed',v_id,coalesce(nullif(payload->>'date','')::date,current_date),u.id); end loop;
  insert into farm_private.inventory_movements(item_id,division_slug,movement_type,qty_signed,reference_type,reference_id,effective_date,actor_id) values(v_item,'feedmill','feed_production',v_qty,'feed',v_id,coalesce(nullif(payload->>'date','')::date,current_date),u.id);
  insert into farm_private.audit_logs(actor_id,action,entity_type,entity_id,detail) values(u.id,'post','feed_batch',v_id,jsonb_build_object('output_kg',v_qty)); return jsonb_build_object('id',v_id);
 end if;
 if action='save_user' then
  if u.role<>'admin' then raise exception 'Forbidden: admin only'; end if;
  v_id=nullif(payload->>'id','')::uuid;
  if v_id is null then if length(coalesce(payload->>'password',''))<10 then raise exception 'New password must be at least 10 characters'; end if;
   insert into farm_private.users(full_name,email,password_hash,role,division_slug) values(trim(payload->>'full_name'),lower(trim(payload->>'email')),extensions.crypt(payload->>'password',extensions.gen_salt('bf',10)),payload->>'role',nullif(payload->>'division_slug','')) returning id into v_id;
  else update farm_private.users set full_name=trim(payload->>'full_name'),role=payload->>'role',division_slug=nullif(payload->>'division_slug',''),active=coalesce((payload->>'active')::boolean,true),updated_at=now(),password_hash=case when length(coalesce(payload->>'password',''))>=10 then extensions.crypt(payload->>'password',extensions.gen_salt('bf',10)) else password_hash end where id=v_id; if not found then raise exception 'User not found'; end if;
  end if;
  insert into farm_private.audit_logs(actor_id,action,entity_type,entity_id) values(u.id,case when payload ? 'id' then 'update' else 'create' end,'user',v_id); return jsonb_build_object('id',v_id);
 end if;
 if action='csv' then
  if u.role='division_staff' then raise exception 'Forbidden'; end if;
  return jsonb_build_object('sales',(select coalesce(jsonb_agg(to_jsonb(s)),'[]') from farm_private.sales s where status='posted'),'expenses',(select coalesce(jsonb_agg(to_jsonb(e)),'[]') from farm_private.expenses e where status='posted'),'movements',(select coalesce(jsonb_agg(to_jsonb(m)||jsonb_build_object('product_name',i.product_name)),'[]') from farm_private.inventory_movements m join farm_private.inventory_items i on i.id=m.item_id));
 end if;
 if action='reset_demo' then raise exception 'Demo reset is disabled on the hosted application'; end if;
 raise exception 'Unknown action';
end $$;

revoke all on all tables in schema farm_private from public, anon, authenticated;
revoke all on all sequences in schema farm_private from public, anon, authenticated;
revoke all on all functions in schema farm_private from public, anon, authenticated;
alter default privileges in schema farm_private revoke all on tables from public, anon, authenticated;
alter default privileges in schema farm_private revoke all on sequences from public, anon, authenticated;
alter default privileges in schema farm_private revoke execute on functions from public, anon, authenticated;

insert into farm_private.divisions(slug,name,description) values
('poultry','Poultry','Flocks, bird movements and mortality'),('piggery','Piggery','Groups, births and animal movements'),('fishery','Fishery','Ponds, stocking and harvests'),('eggs','Egg production','Daily collection and saleable egg stock'),('hatchery','Hatchery','Incubation batches and hatch performance'),('cattle','Cattle','Animal register and weight history'),('feedmill','Feedmill','Ingredient use and feed output') on conflict(slug) do update set name=excluded.name,description=excluded.description;
insert into farm_private.units(division_slug,name,code,kind) values
('poultry','Layer house','LAYERS','batch'),('poultry','Broiler house','BROILERS','batch'),('piggery','Pig pens','PIGS','batch'),('fishery','Grow-out ponds','PONDS','batch'),('eggs','Layer house','EGG-HOUSE','batch'),('hatchery','Incubators','INCUBATOR','batch'),('feedmill','Production line','MILL','batch') on conflict(division_slug,code) do nothing;
insert into farm_private.users(full_name,email,password_hash,role,division_slug) values
('Farm Administrator (Demo)','admin@folhope.demo',extensions.crypt('FarmDemo2026!',extensions.gen_salt('bf',10)),'admin',null),
('Farm Manager (Demo)','manager@folhope.demo',extensions.crypt('FarmDemo2026!',extensions.gen_salt('bf',10)),'manager',null),
('Storekeeper (Demo)','store@folhope.demo',extensions.crypt('FarmDemo2026!',extensions.gen_salt('bf',10)),'storekeeper',null),
('Sales Officer (Demo)','sales@folhope.demo',extensions.crypt('FarmDemo2026!',extensions.gen_salt('bf',10)),'sales_officer',null)
on conflict(email) do nothing;
insert into farm_private.inventory_items(division_slug,sku,product_name,unit,reorder_level,item_type) values
('feedmill','ING-MAIZE','Yellow maize','kg',100,'ingredient'),('feedmill','ING-SOYA','Soybean meal','kg',30,'ingredient'),('feedmill','ING-BRAN','Wheat bran','kg',25,'ingredient'),
('feedmill','FEED-LAYER','Layer mash','kg',100,'finished_feed'),('feedmill','FEED-BROILER','Broiler starter','kg',100,'finished_feed'),('eggs','EGGS-GOOD','Saleable eggs','eggs',50,'product'),
('poultry','VACCINE-NEWCASTLE','Newcastle vaccine','doses',10,'supply'),('poultry','LITTER-SHAVINGS','Wood shavings','bags',10,'supply'),('piggery','PIG-FEED','Pig grower feed','kg',50,'supply'),
('fishery','FISH-FEED','Floating fish feed','kg',50,'supply'),('cattle','CATTLE-FEED','Cattle supplement','kg',20,'supply'),('hatchery','HATCH-TRAYS','Incubation trays','each',5,'supply')
on conflict(sku) do nothing;
-- Fictional, repeatable 30-day demo dataset. Batch and movement inserts are
-- idempotent by stable codes/references, so a schema reinstall preserves data.
insert into farm_private.batches(division_slug,unit_id,code,subtype,start_date,initial_qty,quantity_unit,notes,created_by)
select d.slug,un.id,x.code,x.subtype,current_date-35,x.qty,x.unit,'Fictional demonstration batch',(select id from farm_private.users where email='admin@folhope.demo')
from (values ('poultry','POUL-001','Noiler flock',300::numeric,'birds'),('piggery','PIG-001','Large White group',12,'pigs'),('fishery','POND-01','Catfish',1000,'fish'),('eggs','LAY-001','Layer flock',0,'eggs'),('hatchery','HAT-AREA','Incubation area',0,'eggs'),('cattle','CATTLE-AREA','Cattle group',0,'head'),('feedmill','MILL-AREA','Feed production',0,'kg')) x(slug,code,subtype,qty,unit)
join farm_private.divisions d on d.slug=x.slug left join lateral(select id from farm_private.units where division_slug=d.slug order by id limit 1)un on true
where not exists(select 1 from farm_private.batches b where b.division_slug=d.slug and b.code=x.code);
insert into farm_private.inventory_items(division_slug,batch_id,sku,product_name,unit,reorder_level,item_type)
select b.division_slug,b.id,'BATCH-'||replace(b.id::text,'-',''),b.code||' - '||b.subtype,b.quantity_unit,case when b.division_slug='poultry' then 100 when b.division_slug='piggery' then 4 when b.division_slug='fishery' then 100 else 0 end,'production'
from farm_private.batches b where b.code in('POUL-001','PIG-001','POND-01','LAY-001','HAT-AREA','CATTLE-AREA','MILL-AREA') and not exists(select 1 from farm_private.inventory_items i where i.batch_id=b.id);
insert into farm_private.inventory_movements(item_id,division_slug,movement_type,qty_signed,reference_type,reference_id,effective_date,actor_id)
select i.id,b.division_slug,'opening',b.initial_qty,'batch',b.id,b.start_date,b.created_by from farm_private.batches b join farm_private.inventory_items i on i.batch_id=b.id
where b.initial_qty>0 and b.code in('POUL-001','PIG-001','POND-01') and not exists(select 1 from farm_private.inventory_movements m where m.reference_type='batch' and m.reference_id=b.id and m.movement_type='opening');
-- Housekeeping and feed ingredients have measured, fictional opening balances.
insert into farm_private.inventory_movements(item_id,division_slug,movement_type,qty_signed,reference_type,reference_id,effective_date,actor_id)
select i.id,i.division_slug,'opening',x.qty,'demo_opening',i.id,current_date-30,(select id from farm_private.users where email='admin@folhope.demo')
from (values('ING-MAIZE',120::numeric),('ING-SOYA',30),('ING-BRAN',60),('VACCINE-NEWCASTLE',24),('LITTER-SHAVINGS',18),('PIG-FEED',60),('FISH-FEED',60),('CATTLE-FEED',30),('HATCH-TRAYS',8),('MISC-BAGS',20))x(sku,qty)
join farm_private.inventory_items i on i.sku=x.sku where not exists(select 1 from farm_private.inventory_movements m where m.reference_type='demo_opening' and m.reference_id=i.id);
insert into farm_private.inventory_items(division_slug,sku,product_name,unit,reorder_level,item_type) values('feedmill','MISC-BAGS','Bagged farm produce','bags',5,'product') on conflict(sku) do nothing;
-- The bagged item is inserted above its opening movement.
insert into farm_private.inventory_movements(item_id,division_slug,movement_type,qty_signed,reference_type,reference_id,effective_date,actor_id)
select id,division_slug,'opening',20,'demo_opening',id,current_date-30,(select id from farm_private.users where email='admin@folhope.demo') from farm_private.inventory_items i where sku='MISC-BAGS' and not exists(select 1 from farm_private.inventory_movements m where m.reference_type='demo_opening' and m.reference_id=i.id);
insert into farm_private.production_events(batch_id,event_type,event_date,quantity,unit,notes,actor_id)
select b.id,x.event_type,current_date-2,x.quantity,b.quantity_unit,'Fictional demo acceptance scenario',(select id from farm_private.users where email='admin@folhope.demo')
from (values('POUL-001','mortality',5::numeric),('PIG-001','birth',4),('POND-01','death',20),('POND-01','harvest',150))x(code,event_type,quantity)
join farm_private.batches b on b.code=x.code and b.division_slug=case when x.code='POUL-001' then 'poultry' when x.code='PIG-001' then 'piggery' else 'fishery' end
where not exists(select 1 from farm_private.production_events e where e.batch_id=b.id and e.event_type=x.event_type and e.notes='Fictional demo acceptance scenario');
insert into farm_private.inventory_movements(item_id,division_slug,movement_type,qty_signed,reference_type,reference_id,effective_date,actor_id)
select i.id,b.division_slug,x.event_type,case when x.event_type in('mortality','death','harvest') then -x.quantity else x.quantity end,'demo_event',e.id,e.event_date,e.actor_id
from (values('POUL-001','mortality',5::numeric),('PIG-001','birth',4),('POND-01','death',20),('POND-01','harvest',150))x(code,event_type,quantity)
join farm_private.batches b on b.code=x.code join farm_private.inventory_items i on i.batch_id=b.id
join farm_private.production_events e on e.batch_id=b.id and e.event_type=x.event_type and e.notes='Fictional demo acceptance scenario'
where not exists(select 1 from farm_private.inventory_movements m where m.reference_type='demo_event' and m.reference_id=e.id and m.item_id=i.id);
insert into farm_private.egg_collections(batch_id,collected_on,good_count,damaged_count,note,actor_id)
select b.id,current_date-1,240,10,'Fictional demo collection',(select id from farm_private.users where email='admin@folhope.demo') from farm_private.batches b where b.code='LAY-001' and not exists(select 1 from farm_private.egg_collections where note='Fictional demo collection');
insert into farm_private.inventory_movements(item_id,division_slug,movement_type,qty_signed,reference_type,reference_id,effective_date,actor_id)
select i.id,'eggs','egg_collection',240,'egg',e.id,e.collected_on,e.actor_id from farm_private.egg_collections e join farm_private.inventory_items i on i.sku='EGGS-GOOD' where e.note='Fictional demo collection' and not exists(select 1 from farm_private.inventory_movements m where m.reference_type='egg' and m.reference_id=e.id);
insert into farm_private.hatchery_batches(code,set_date,hatch_date,eggs_set,chicks_hatched,rejected_eggs,note,created_by)
select 'HATCH-DEMO-001',current_date-12,current_date-1,500,400,25,'Fictional demo: 80% hatch rate',(select id from farm_private.users where email='admin@folhope.demo') where not exists(select 1 from farm_private.hatchery_batches where code='HATCH-DEMO-001');
insert into farm_private.animals(tag,breed,sex,acquired_at,current_weight_kg,notes,created_by)
select 'COW-DEMO-001','White Fulani','Female',current_date-40,320,'Fictional demonstration animal',(select id from farm_private.users where email='admin@folhope.demo') where not exists(select 1 from farm_private.animals where tag='COW-DEMO-001');
insert into farm_private.animal_weights(animal_id,weight_kg,measured_on,note,actor_id)
select a.id,320,current_date-1,'Fictional demo weight history',(select id from farm_private.users where email='admin@folhope.demo') from farm_private.animals a where a.tag='COW-DEMO-001' and not exists(select 1 from farm_private.animal_weights where animal_id=a.id);
insert into farm_private.feed_batches(code,produced_on,output_item_id,output_kg,created_by)
select 'FEED-DEMO-001',current_date-2,i.id,150,(select id from farm_private.users where email='admin@folhope.demo') from farm_private.inventory_items i where i.sku='FEED-LAYER' and not exists(select 1 from farm_private.feed_batches where code='FEED-DEMO-001');
insert into farm_private.feed_batch_inputs(feed_batch_id,ingredient_item_id,quantity_kg)
select f.id,i.id,x.qty from farm_private.feed_batches f join (values('ING-MAIZE',120::numeric),('ING-SOYA',30))x(sku,qty) on true join farm_private.inventory_items i on i.sku=x.sku where f.code='FEED-DEMO-001' and not exists(select 1 from farm_private.feed_batch_inputs where feed_batch_id=f.id);
insert into farm_private.inventory_movements(item_id,movement_type,qty_signed,reference_type,reference_id,effective_date,actor_id)
select i.id,'feed_consumption',-fi.quantity_kg,'feed',f.id,f.produced_on,f.created_by from farm_private.feed_batches f join farm_private.feed_batch_inputs fi on fi.feed_batch_id=f.id join farm_private.inventory_items i on i.id=fi.ingredient_item_id where f.code='FEED-DEMO-001' and not exists(select 1 from farm_private.inventory_movements m where m.reference_type='feed' and m.reference_id=f.id and m.item_id=i.id and m.movement_type='feed_consumption');
insert into farm_private.inventory_movements(item_id,division_slug,movement_type,qty_signed,reference_type,reference_id,effective_date,actor_id)
select i.id,'feedmill','feed_production',f.output_kg,'feed',f.id,f.produced_on,f.created_by from farm_private.feed_batches f join farm_private.inventory_items i on i.id=f.output_item_id where f.code='FEED-DEMO-001' and not exists(select 1 from farm_private.inventory_movements m where m.reference_type='feed' and m.reference_id=f.id and m.movement_type='feed_production');
insert into farm_private.sales(sale_no,division_slug,sale_date,customer,total_amount,paid_amount,created_by)
select 'DEMO-SALE-'||lpad(g.n::text,2,'0'),'feedmill',current_date-g.n,'Fictional local buyer',8500,4000,(select id from farm_private.users where email='admin@folhope.demo') from generate_series(1,10)g(n) where not exists(select 1 from farm_private.sales where sale_no='DEMO-SALE-'||lpad(g.n::text,2,'0'));
insert into farm_private.sale_lines(sale_id,item_id,quantity,unit_price,line_total)
select s.id,i.id,1,8500,8500 from farm_private.sales s join farm_private.inventory_items i on i.sku='MISC-BAGS' where s.sale_no like 'DEMO-SALE-%' and not exists(select 1 from farm_private.sale_lines where sale_id=s.id);
insert into farm_private.inventory_movements(item_id,division_slug,movement_type,qty_signed,reference_type,reference_id,effective_date,actor_id)
select i.id,'feedmill','sale',-1,'sale',s.id,s.sale_date,s.created_by from farm_private.sales s join farm_private.sale_lines l on l.sale_id=s.id join farm_private.inventory_items i on i.id=l.item_id where s.sale_no like 'DEMO-SALE-%' and not exists(select 1 from farm_private.inventory_movements m where m.reference_type='sale' and m.reference_id=s.id and m.item_id=i.id);
insert into farm_private.expenses(division_slug,category,amount,expense_date,description,created_by)
select x.division,x.category,x.amount,current_date-x.days_ago,x.description,(select id from farm_private.users where email='admin@folhope.demo') from (values
('poultry','Transport',15000::numeric,2,'Fictional feed delivery'),('cattle','Veterinary',12000,5,'Fictional health supplies'),('feedmill','Supplies',6500,9,'Packaging for demo batch'),('fishery','Transport',8000,12,'Fictional pond supplies'),('piggery','Feed',18000,16,'Fictional pig feed'),('hatchery','Utilities',9500,20,'Fictional power expense'),('eggs','Repairs',4500,24,'Fictional equipment repair'),('poultry','Veterinary',7200,28,'Fictional flock supplies'))x(division,category,amount,days_ago,description)
where not exists(select 1 from farm_private.expenses e where e.description=x.description);
insert into farm_private.users(full_name,email,password_hash,role,division_slug)
select initcap(d.name)||' Staff (Demo)',d.slug||'@folhope.demo',extensions.crypt('FarmDemo2026!',extensions.gen_salt('bf',10)),'division_staff',d.slug from farm_private.divisions d on conflict(email) do nothing;
insert into farm_private.audit_logs(actor_id,action,entity_type,detail)
select u.id,'demo_seed','system','{"source":"synthetic training records"}'::jsonb from farm_private.users u where u.email='admin@folhope.demo' and not exists(select 1 from farm_private.audit_logs where action='demo_seed');


do $$ declare t record; begin for t in select tablename from pg_tables where schemaname='farm_private' loop execute format('alter table farm_private.%I enable row level security',t.tablename); end loop; end $$;

create or replace function public.farm_api(action text,payload jsonb default '{}'::jsonb,token text default null) returns jsonb language sql security invoker set search_path='' as $func$ select farm_private.farm_api_impl(action,payload,token) $func$;
revoke all on function public.farm_api(text,jsonb,text) from public,authenticated;
revoke all on function farm_private.farm_api_impl(text,jsonb,text) from public,authenticated;
grant usage on schema farm_private to anon;
grant execute on function farm_private.farm_api_impl(text,jsonb,text) to anon;
grant execute on function public.farm_api(text,jsonb,text) to anon;
