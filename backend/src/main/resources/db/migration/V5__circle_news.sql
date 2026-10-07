-- When each "I prayed" came in, so the asker can be told "3 people prayed for you" when they next open the app.
alter table circle_prayed add column at timestamptz not null default now();

create index circle_prayed_at on circle_prayed (at);
