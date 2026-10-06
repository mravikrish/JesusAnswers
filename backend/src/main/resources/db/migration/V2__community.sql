-- Shared counts: how many people loved, prayed or listened to each prayer, story, chapter and saying.
-- No accounts and no content: only an item key, a hashed install id and a day, so nobody can see who did what.

-- One heart per install per item; removed again when the heart is taken back.
create table heart (
    item       varchar(80) not null,
    device     varchar(64) not null,             -- SHA-256 of the app's random install id + a server salt
    created_at timestamptz not null default now(),
    primary key (item, device)
);

-- Prayed / listened: at most one per install, item and day, so repeated taps don't inflate counts.
create table activity (
    item   varchar(80) not null,
    kind   varchar(16) not null check (kind in ('prayed', 'listened')),
    device varchar(64) not null,
    day    date        not null,
    primary key (item, kind, device, day)
);

create index activity_day on activity (day);
