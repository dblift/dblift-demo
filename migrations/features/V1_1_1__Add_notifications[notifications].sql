-- DBLift Demo - Notifications
-- Description: Notification system
-- Tags: notifications, features

CREATE TYPE notification_type AS ENUM ('info', 'warning', 'error', 'success');
CREATE TYPE notification_channel AS ENUM ('email', 'sms', 'push', 'in_app');

CREATE TABLE notifications (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type notification_type DEFAULT 'info' NOT NULL,
    channel notification_channel DEFAULT 'in_app' NOT NULL,
    title VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    read BOOLEAN DEFAULT FALSE,
    sent_at TIMESTAMP,
    read_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by VARCHAR(50) DEFAULT 'system' NOT NULL
);

CREATE INDEX idx_notifications_user ON notifications(user_id);
CREATE INDEX idx_notifications_read ON notifications(user_id, read) WHERE read = FALSE;
CREATE INDEX idx_notifications_created ON notifications(created_at DESC);

COMMENT ON TABLE notifications IS 'User notifications';

