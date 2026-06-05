-- F-001: 语音自动笔记功能
-- Date: 2026-06-03
-- Feature: voice notes with scene detection and AI generation

-- 1. Create voice_notes table
CREATE TABLE voice_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) NOT NULL,
  scene_type TEXT NOT NULL CHECK (scene_type IN ('meeting', 'chat', 'monologue', 'unknown')),
  raw_text TEXT NOT NULL,                    -- STT转写全文
  generated_note TEXT,                       -- AI生成的结构化笔记
  audio_file_path TEXT,                      -- 录音文件路径(Supabase Storage)
  duration_seconds INTEGER,                 -- 录音时长(秒)
  status TEXT DEFAULT 'processing' CHECK (status IN ('processing', 'completed', 'failed')),
  error_message TEXT,                        -- 失败原因
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes
CREATE INDEX idx_voice_notes_user_id ON voice_notes(user_id);
CREATE INDEX idx_voice_notes_scene_type ON voice_notes(scene_type);
CREATE INDEX idx_voice_notes_created_at ON voice_notes(created_at DESC);
CREATE INDEX idx_voice_notes_status ON voice_notes(status);

-- RLS policies
ALTER TABLE voice_notes ENABLE ROW LEVEL SECURITY;

-- Users can read their own voice notes
CREATE POLICY "voice_notes_select" ON voice_notes
  FOR SELECT USING (auth.uid() = user_id);

-- Users can insert their own voice notes
CREATE POLICY "voice_notes_insert" ON voice_notes
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can update their own voice notes
CREATE POLICY "voice_notes_update" ON voice_notes
  FOR UPDATE USING (auth.uid() = user_id);

-- Users can delete their own voice notes
CREATE POLICY "voice_notes_delete" ON voice_notes
  FOR DELETE USING (auth.uid() = user_id);

-- 2. Storage bucket for voice recordings
INSERT INTO storage.buckets (id, name, public)
VALUES ('voice-recordings', 'voice-recordings', false)
ON CONFLICT (id) DO NOTHING;

-- Voice recordings RLS (private - only owner can access)
CREATE POLICY "recordings_select" ON storage.objects
  FOR SELECT USING (bucket_id = 'voice-recordings' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "recordings_insert" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'voice-recordings' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "recordings_delete" ON storage.objects
  FOR DELETE USING (bucket_id = 'voice-recordings' AND auth.uid()::text = (storage.foldername(name))[1]);

-- 3. Auto-touch trigger for updated_at
CREATE OR REPLACE FUNCTION voice_notes_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER voice_notes_updated_at
  BEFORE UPDATE ON voice_notes
  FOR EACH ROW
  EXECUTE FUNCTION voice_notes_updated_at();
