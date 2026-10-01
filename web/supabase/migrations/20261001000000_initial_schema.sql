-- Leftovers web: initial schema (web/SPEC.md W4, W5; ../SPEC.md 6.2-6.6, 7.8).
-- Every table has row-level security. A row is visible only to members of its household.

-- ---------------------------------------------------------------------------
-- Households and accounts
-- ---------------------------------------------------------------------------

create table household (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now()
);

create table household_member (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references household (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id),
  unique (household_id, id)
);

create table household_invite (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references household (id) on delete cascade,
  token uuid not null default gen_random_uuid() unique,
  created_by uuid not null references auth.users (id) on delete cascade,
  used_at timestamptz,
  used_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  unique (household_id, id)
);

create table household_settings (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references household (id) on delete cascade,
  quick_send_name text not null default '',
  quick_send_phone text not null default '',
  include_checked boolean not null default false,
  include_meal_plan boolean not null default true,
  created_at timestamptz not null default now(),
  unique (household_id),
  unique (household_id, id)
);

-- ---------------------------------------------------------------------------
-- Library
-- ---------------------------------------------------------------------------

create table ingredient (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references household (id) on delete cascade,
  name text not null default '',
  normalized_name text not null,
  default_unit text not null default 'item'
    check (default_unit in ('item','g','kg','ml','l','tsp','tbsp','cup','clove','slice','tin','pack','bunch','handful','pinch')),
  category text not null default 'other'
    check (category in ('produce','meatFish','dairyEggs','bakery','pantry','frozen','drinks','household','other')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (household_id, id),
  unique (household_id, normalized_name)
);

create table meal (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references household (id) on delete cascade,
  name text not null default '',
  is_breakfast boolean not null default false,
  is_lunch boolean not null default false,
  is_dinner boolean not null default false,
  servings integer not null default 2,
  total_minutes integer,
  notes text not null default '',
  is_favorite boolean not null default false,
  good_as_leftovers boolean not null default true,
  photo_path text,
  thumbnail_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (household_id, id)
);

create table recipe_ingredient (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references household (id) on delete cascade,
  meal_id uuid not null,
  ingredient_id uuid not null,
  quantity double precision,
  unit text not null default 'item'
    check (unit in ('item','g','kg','ml','l','tsp','tbsp','cup','clove','slice','tin','pack','bunch','handful','pinch')),
  note text not null default '',
  sort_index integer not null default 0,
  created_at timestamptz not null default now(),
  unique (household_id, id),
  foreign key (household_id, meal_id) references meal (household_id, id) on delete cascade,
  foreign key (household_id, ingredient_id) references ingredient (household_id, id) on delete restrict
);

create table instruction_step (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references household (id) on delete cascade,
  meal_id uuid not null,
  text text not null default '',
  sort_index integer not null default 0,
  created_at timestamptz not null default now(),
  unique (household_id, id),
  foreign key (household_id, meal_id) references meal (household_id, id) on delete cascade
);

-- ---------------------------------------------------------------------------
-- Planning and shopping
-- ---------------------------------------------------------------------------

create table week_plan (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references household (id) on delete cascade,
  week_id text not null,
  is_archived boolean not null default false,
  archived_at timestamptz,
  archived_shopping jsonb,           -- ArchivedShoppingList (7.8)
  last_shared_at timestamptz,
  last_shared_signature text,
  created_at timestamptz not null default now(),
  unique (household_id, id),
  unique (household_id, week_id)
);

create table meal_slot (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references household (id) on delete cascade,
  week_plan_id uuid not null,
  day_index integer not null check (day_index between 0 and 6),
  meal_type text not null default 'dinner' check (meal_type in ('breakfast','lunch','dinner')),
  meal_id uuid,
  leftover_of_slot_id uuid,
  archived_snapshot jsonb,           -- ArchivedSlot (7.8)
  created_at timestamptz not null default now(),
  unique (household_id, id),
  unique (week_plan_id, day_index, meal_type),
  foreign key (household_id, week_plan_id) references week_plan (household_id, id) on delete cascade,
  foreign key (household_id, meal_id) references meal (household_id, id) on delete set null (meal_id),
  foreign key (household_id, leftover_of_slot_id) references meal_slot (household_id, id)
    on delete set null (leftover_of_slot_id)
);

create table manual_shopping_item (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references household (id) on delete cascade,
  week_plan_id uuid not null,
  ingredient_id uuid not null,
  quantity double precision,
  unit text not null default 'item'
    check (unit in ('item','g','kg','ml','l','tsp','tbsp','cup','clove','slice','tin','pack','bunch','handful','pinch')),
  created_at timestamptz not null default now(),
  unique (household_id, id),
  foreign key (household_id, week_plan_id) references week_plan (household_id, id) on delete cascade,
  foreign key (household_id, ingredient_id) references ingredient (household_id, id) on delete restrict
);

create table shopping_item_state (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references household (id) on delete cascade,
  week_plan_id uuid not null,
  item_key text not null,            -- ingredient id (7.4: merge by id, never by name)
  is_checked boolean not null default false,
  checked_amounts jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (household_id, id),
  unique (week_plan_id, item_key),
  foreign key (household_id, week_plan_id) references week_plan (household_id, id) on delete cascade
);

-- ---------------------------------------------------------------------------
-- Row-level security
-- ---------------------------------------------------------------------------

alter table household enable row level security;
alter table household_member enable row level security;
alter table household_invite enable row level security;
alter table household_settings enable row level security;
alter table ingredient enable row level security;
alter table meal enable row level security;
alter table recipe_ingredient enable row level security;
alter table instruction_step enable row level security;
alter table week_plan enable row level security;
alter table meal_slot enable row level security;
alter table manual_shopping_item enable row level security;
alter table shopping_item_state enable row level security;

-- A user can see only their own membership row (this keeps the policies below free of recursion).
create policy member_select_own on household_member
  for select to authenticated using (user_id = (select auth.uid()));

create policy household_select on household
  for select to authenticated
  using (id in (select household_id from household_member where user_id = (select auth.uid())));

create policy invite_select on household_invite
  for select to authenticated
  using (household_id in (select household_id from household_member where user_id = (select auth.uid())));

create policy invite_insert on household_invite
  for insert to authenticated
  with check (
    created_by = (select auth.uid())
    and used_at is null
    and used_by is null
    and household_id in (select household_id from household_member where user_id = (select auth.uid()))
  );

do $$
declare t text;
begin
  foreach t in array array[
    'household_settings','ingredient','meal','recipe_ingredient','instruction_step',
    'week_plan','meal_slot','manual_shopping_item','shopping_item_state'
  ] loop
    execute format(
      'create policy %I on %I for all to authenticated
         using (household_id in (select household_id from household_member where user_id = (select auth.uid())))
         with check (household_id in (select household_id from household_member where user_id = (select auth.uid())))',
      t || '_household', t);
  end loop;
end $$;

-- Table privileges: signed-out users get nothing; membership and invites are written only by the functions below.
revoke all on all tables in schema public from anon;
revoke insert, update, delete, truncate on household, household_member from authenticated;
revoke update, delete, truncate on household_invite from authenticated;

-- ---------------------------------------------------------------------------
-- The only two security definer functions (W4)
-- ---------------------------------------------------------------------------

create function ensure_household() returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  uid uuid := auth.uid();
  hid uuid;
begin
  if uid is null then
    raise exception 'not_signed_in' using errcode = '28000';
  end if;
  select household_id into hid from household_member where user_id = uid;
  if hid is not null then
    return hid;
  end if;
  insert into household default values returning id into hid;
  insert into household_member (household_id, user_id) values (hid, uid);
  insert into household_settings (household_id) values (hid);
  return hid;
end $$;

create function accept_invite(invite_token uuid) returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  uid uuid := auth.uid();
  inv household_invite%rowtype;
begin
  if uid is null then
    raise exception 'not_signed_in' using errcode = '28000';
  end if;
  if exists (select 1 from household_member where user_id = uid) then
    raise exception 'already_in_household' using errcode = 'P0001';
  end if;
  select * into inv from household_invite where token = invite_token and used_at is null for update;
  if not found then
    raise exception 'invite_invalid' using errcode = 'P0001';
  end if;
  insert into household_member (household_id, user_id) values (inv.household_id, uid);
  update household_invite set used_at = now(), used_by = uid where id = inv.id;
  return inv.household_id;
end $$;

revoke all on function ensure_household() from public, anon;
revoke all on function accept_invite(uuid) from public, anon;
grant execute on function ensure_household() to authenticated;
grant execute on function accept_invite(uuid) to authenticated;
