
create or replace function farm_private.capture_record_edit()
returns trigger language plpgsql security invoker set search_path='' as $$
declare b jsonb; a jsonb; changes jsonb; actor uuid;
begin
 b:=to_jsonb(old)-'password_hash'; a:=to_jsonb(new)-'password_hash';
 select coalesce(jsonb_object_agg(k,jsonb_build_object('before',b->k,'after',a->k)),'{}'::jsonb) into changes
 from jsonb_object_keys(a) k where k<>'updated_at' and b->k is distinct from a->k;
 if tg_table_name='users' and (to_jsonb(old)->>'password_hash') is distinct from (to_jsonb(new)->>'password_hash') then
 changes:=changes||jsonb_build_object('password',jsonb_build_object('before','[hidden]','after','Password changed'));
 end if;
 if changes='{}'::jsonb then return new; end if;
 actor:=nullif(current_setting('farm.actor_id',true),'')::uuid;
 insert into farm_private.audit_logs(actor_id,action,entity_type,entity_id,detail)
 values(actor,'record_edited',tg_table_name,(a->>'id')::uuid,jsonb_build_object('before',b,'after',a,'changes',changes,'reference',coalesce(a->>'code',a->>'sale_no',a->>'tag',a->>'email',a->>'sku',a->>'category')));
 return new;
end $$;
revoke all on function farm_private.capture_record_edit() from public,anon,authenticated;
do $$ declare tbl text; definition text; begin
 foreach tbl in array array['users','batches','inventory_items','animals','hatchery_batches','sales','expenses','feed_batches','egg_collections','production_events','animal_weights'] loop
 execute format('create or replace trigger capture_record_edit after update on farm_private.%I for each row execute function farm_private.capture_record_edit()',tbl);
 end loop;
 select pg_get_functiondef('farm_private.farm_api_impl(text,jsonb,text)'::regprocedure) into definition;
 if position('set_config(''farm.actor_id''' in definition)=0 then
 definition:=replace(definition,'if action=''state'' then','perform set_config(''farm.actor_id'',u.id::text,true);'||chr(10)||' if action=''state'' then');
 execute definition;
 end if;
end $$;
