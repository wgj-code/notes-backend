-- Add response field to feedback table for closure notifications
ALTER TABLE feedback ADD COLUMN response TEXT;
ALTER TABLE feedback ADD COLUMN responded_at TIMESTAMPTZ;
ALTER TABLE feedback ADD COLUMN is_read BOOLEAN DEFAULT false;

-- Index for unread responses
CREATE INDEX idx_feedback_unread ON feedback(is_read) WHERE response IS NOT NULL;
