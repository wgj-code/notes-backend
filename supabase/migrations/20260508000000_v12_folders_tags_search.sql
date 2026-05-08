-- V1.2 Migration: folders table + notes ALTER + Storage bucket
-- Date: 2026-05-08
-- Features: F1(搜索) / F2(文件夹+标签) / F4(图片Storage)

-- 1. Create folders table
CREATE TABLE folders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) NOT NULL,
  name TEXT NOT NULL,
  parent_id UUID REFERENCES folders(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_folders_user_id ON folders(user_id);
CREATE INDEX idx_folders_parent_id ON folders(parent_id);

ALTER TABLE folders ENABLE ROW LEVEL SECURITY;
CREATE POLICY "folders_select" ON folders FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "folders_insert" ON folders FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "folders_update" ON folders FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "folders_delete" ON folders FOR DELETE USING (auth.uid() = user_id);

-- 2. Add folder_id and tags to notes
ALTER TABLE notes ADD COLUMN folder_id UUID REFERENCES folders(id) ON DELETE SET NULL;
ALTER TABLE notes ADD COLUMN tags TEXT[] DEFAULT '{}';

CREATE INDEX idx_notes_folder_id ON notes(folder_id);
CREATE INDEX idx_notes_tags ON notes USING GIN(tags);

-- 3. Create Storage bucket for note images
INSERT INTO storage.buckets (id, name, public)
VALUES ('note-images', 'note-images', true)
ON CONFLICT (id) DO NOTHING;

-- Storage RLS policies
CREATE POLICY "images_select" ON storage.objects
  FOR SELECT USING (bucket_id = 'note-images');
CREATE POLICY "images_insert" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'note-images'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );
CREATE POLICY "images_delete" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'note-images'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );
