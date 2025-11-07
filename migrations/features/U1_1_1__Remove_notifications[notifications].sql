-- DBLift Demo - Remove Notifications (Undo)
-- Description: Drops notification feature tables
-- Tags: notifications, features, undo

DROP TABLE IF EXISTS notifications CASCADE;
DROP TYPE IF EXISTS notification_channel;
DROP TYPE IF EXISTS notification_type;


