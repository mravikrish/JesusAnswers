-- Prayer circles: a few people who pray for each other, joined with a short invite code.
-- No accounts: a member is a salted hash of the app's random install id, as for the shared counts.

create table circle (
    id         bigserial primary key,
    code       varchar(8)  not null unique,     -- e.g. K7P3MX, shown as K7P-3MX
    name       varchar(60) not null,
    created_at timestamptz not null default now()
);

create table circle_member (
    id         bigserial   not null unique,     -- what other members see, so installs can't be linked across circles
    circle_id  bigint      not null references circle (id) on delete cascade,
    device     varchar(64) not null,
    name       varchar(40) not null,
    owner      boolean     not null default false,
    removed    boolean     not null default false,   -- taken out by the owner: can't join again
    joined_at  timestamptz not null default now(),
    primary key (circle_id, device)
);

create index circle_member_device on circle_member (device);

-- A member's prayer request. Leaving the circle takes their requests with them.
create table circle_request (
    id          bigserial   primary key,
    circle_id   bigint      not null references circle (id) on delete cascade,
    device      varchar(64) not null,
    text        text        not null,           -- AES-256-GCM encrypted, like the journey
    created_at  timestamptz not null default now(),
    answered_at timestamptz
);

create index circle_request_circle on circle_request (circle_id, created_at desc);

-- "I prayed for this": once per member and request.
create table circle_prayed (
    request_id bigint      not null references circle_request (id) on delete cascade,
    device     varchar(64) not null,
    primary key (request_id, device)
);

-- Hidden at once for whoever reported it; removed for everyone once enough members have.
create table circle_report (
    request_id bigint      not null references circle_request (id) on delete cascade,
    device     varchar(64) not null,
    primary key (request_id, device)
);
