-- DBLift Demo - Analytics
-- Description: Analytics and tracking tables
-- Tags: analytics, features

CREATE TABLE user_sessions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    session_token VARCHAR(255) UNIQUE NOT NULL,
    ip_address VARCHAR(45),
    user_agent TEXT,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    last_activity TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    ended_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by VARCHAR(50) DEFAULT 'system' NOT NULL
);

CREATE INDEX idx_user_sessions_user ON user_sessions(user_id);
CREATE INDEX idx_user_sessions_token ON user_sessions(session_token);
CREATE INDEX idx_user_sessions_started ON user_sessions(started_at DESC);

COMMENT ON TABLE user_sessions IS 'User session tracking';

CREATE TABLE page_views (
    id SERIAL PRIMARY KEY,
    session_id INTEGER REFERENCES user_sessions(id) ON DELETE CASCADE,
    page_url VARCHAR(500) NOT NULL,
    referrer VARCHAR(500),
    view_duration INTEGER, -- in seconds
    viewed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by VARCHAR(50) DEFAULT 'system' NOT NULL
);

CREATE INDEX idx_page_views_session ON page_views(session_id);
CREATE INDEX idx_page_views_url ON page_views(page_url);
CREATE INDEX idx_page_views_viewed ON page_views(viewed_at DESC);

COMMENT ON TABLE page_views IS 'Page view tracking for analytics';

