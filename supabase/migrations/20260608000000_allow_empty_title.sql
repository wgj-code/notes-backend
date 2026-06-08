-- 允许笔记标题为NULL
-- 修复：用户反馈"允许有内容无标题的笔记"（反馈ID: 872c86d3-d0ba-4177-8f67-62092add17d4）

-- 1. 删除旧的CHECK约束
ALTER TABLE notes DROP CONSTRAINT IF EXISTS notes_title_check;

-- 2. 修改title字段，允许NULL值
ALTER TABLE notes ALTER COLUMN title DROP NOT NULL;

-- 3. 添加新的CHECK约束（允许NULL或非空字符串）
ALTER TABLE notes ADD CONSTRAINT notes_title_check CHECK (title IS NULL OR length(title) > 0);
