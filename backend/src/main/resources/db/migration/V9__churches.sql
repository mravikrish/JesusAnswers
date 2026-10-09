-- A church is its own kind of circle: the home of the church's circles (Youth, Women's fellowship,
-- a home group), with a prayer wall, prayer chains and a praise wall for the whole church. Only a
-- church holds circles. Family and friends circles stand on their own, as before.
alter table circle add column church boolean not null default false;

-- Circles that already hold groups were churches in all but name.
update circle set church = true where id in (select parent_id from circle where parent_id is not null);
