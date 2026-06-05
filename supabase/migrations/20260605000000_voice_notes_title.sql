-- F-001-R1: voice_notes 表增加 title 列（个性化标题）
ALTER TABLE voice_notes ADD COLUMN title TEXT;

-- 已有记录用 scene_type 兜底
UPDATE voice_notes SET title = CASE scene_type
  WHEN 'meeting' THEN '会议'
  WHEN 'chat' THEN '闲聊'
  WHEN 'monologue' THEN '思考'
  ELSE '语音笔记'
END WHERE title IS NULL;
