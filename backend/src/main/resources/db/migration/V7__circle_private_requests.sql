-- For a church: some requests are too personal for everyone to read.
-- for_leaders: only the owner and leaders (and the asker) see it.
-- anonymous: members don't see who asked; the owner and leaders still do, so they can care for them.
-- crisis: the asker may be thinking of ending their life (Safety.isCrisis, checked when it is shared,
-- since the text is stored encrypted); leaders are alerted first.
alter table circle_request add column for_leaders boolean not null default false;
alter table circle_request add column anonymous   boolean not null default false;
alter table circle_request add column crisis      boolean not null default false;
