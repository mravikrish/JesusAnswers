-- A ready prayer shared into a circle. Only its id is kept: each phone shows the prayer from its own
-- copy, in the reader's language. The request's text is then an optional note (may be empty).
alter table circle_request add column prayer_id varchar(64);

-- A heart on a shared prayer: once per member.
create table circle_heart (
    request_id bigint      not null references circle_request (id) on delete cascade,
    device     varchar(64) not null,
    primary key (request_id, device)
);
