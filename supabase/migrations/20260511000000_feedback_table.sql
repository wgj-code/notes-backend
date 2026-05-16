-- V1.3 Migration: user feedback table
-- Date: 2026-05-11
-- Feature: user feedback channel (text + voice + images)

-- 1. Create feedback table
CREATE TABLE feedback (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) NOT NULL,
  content TEXT NOT NULL,           -- text feedback
  voice_url TEXT,                  -- voice recording URL (Supabase Storage)
  images TEXT[] DEFAULT '{}',      -- array of image URLs
  category TEXT DEFAULT 'bug',    -- bug / feature / improvement / other
  status TEXT DEFAULT 'new',      -- new / reviewed / resolved / wontfix
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_feedback_user_id ON feedback(user_id);
CREATE INDEX idx_feedback_status ON feedback(status);
CREATE INDEX idx_feedback_created_at ON feedback(created_at DESC);

-- RLS
ALTER TABLE feedback ENABLE ROW LEVEL SECURITY;
CREATE POLICY "feedback_select" ON feedback FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "feedback_insert" ON feedback FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "feedback_update" ON feedback FOR UPDATE USING (auth.uid() = user_id);

-- 2. Storage bucket for voice recordings
INSERT INTO storage.buckets (id, name, public)
VALUES ('feedback-voice', 'feedback-voice', false)
ON CONFLICT (id) DO NOTHING;

-- Voice storage RLS (private - only owner can access)
CREATE POLICY "voice_select" ON storage.objects
  FOR SELECT USING (bucket_id = 'feedback-voice' AND auth.uid()::text = (storage.foldername(name))[1]);
CREATE POLICY "voice_insert" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'feedback-voice' AND auth.uid()::text = (storage.foldername(name))[1]);

-- 3. Auto-touch trigger for updated_at
CREATE OR REPLACE FUNCTION feedback_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER feedback_updated_at
  BEFORE UPDATE ON feedback
  FOR EACH ROW
  EXECUTE FUNCTION feedback_updated_at();
