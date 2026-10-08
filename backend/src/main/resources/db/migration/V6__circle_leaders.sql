-- For a church: the owner can make members leaders (elders, group leaders), who help look after the
-- circle. A leader or the owner can pin one request to the top as the circle's prayer focus.
alter table circle_member add column leader boolean not null default false;

alter table circle_request add column pinned_at timestamptz;
