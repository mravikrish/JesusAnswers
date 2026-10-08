-- Church life: groups within a church, approving new members, the praise wall, prayer chains and
-- sharing a Bible verse.

-- A group (Youth, Women's fellowship, a home group) belongs to its church's circle. Only one level:
-- a group has no groups of its own. If the church's circle goes, its groups stay, on their own.
alter table circle add column parent_id bigint references circle (id) on delete set null;
create index circle_parent on circle (parent_id);

-- When on, someone joining with the code waits until the owner or a leader lets them in.
alter table circle add column approval boolean not null default false;

create table circle_waiting (
    id        bigserial   not null unique,          -- what the leaders see
    circle_id bigint      not null references circle (id) on delete cascade,
    device    varchar(64) not null,
    name      varchar(40) not null,
    asked_at  timestamptz not null default now(),
    primary key (circle_id, device)
);

-- Let in after waiting, to tell them so when they next open the app.
alter table circle_member add column approved boolean not null default false;

-- The praise wall. praise: a praise report shared as such (already answered, never asked).
-- testimony: how God answered, added when marking it answered (encrypted, like the text).
-- Answered prayers stay on the wall for a year; unanswered ones still go after 60 days.
alter table circle_request add column praise    boolean not null default false;
alter table circle_request add column testimony text;
create index circle_request_answered on circle_request (circle_id, answered_at desc) where answered_at is not null;

-- A Bible verse shared into a circle ("JHN 3:16"), shown from each reader's own Bible in their language.
-- The request's text is then an optional note.
alter table circle_request add column verse varchar(16);

-- A prayer chain or fasting days: [slots] turns of [slot_minutes] each, from [starts_at].
-- Members take turns; each phone reminds its owner when their turn comes.
create table circle_chain (
    id           bigserial   primary key,
    circle_id    bigint      not null references circle (id) on delete cascade,
    device       varchar(64) not null,              -- who started it
    title        text        not null,              -- encrypted
    starts_at    timestamptz not null,
    slot_minutes int         not null,
    slots        int         not null,
    created_at   timestamptz not null default now()
);

create index circle_chain_circle on circle_chain (circle_id, starts_at);

create table circle_chain_slot (
    chain_id bigint      not null references circle_chain (id) on delete cascade,
    slot     int         not null,
    device   varchar(64) not null,
    primary key (chain_id, slot, device)
);
