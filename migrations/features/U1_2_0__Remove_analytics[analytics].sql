-- DBLift Demo - Remove Analytics (Undo)
-- Description: Drops analytics tracking tables
-- Tags: analytics, features, undo

-- Drop dependent tables first due to foreign key references
DROP TABLE IF EXISTS page_views CASCADE;
DROP TABLE IF EXISTS user_sessions CASCADE;


