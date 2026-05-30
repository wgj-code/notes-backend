-- B-002: 跨平台同步（UC20-22）
-- Date: 2026-05-30
-- Features: Realtime 订阅 + 乐观锁

-- 1. notes 表新增 version 字段（乐观锁）
ALTER TABLE notes ADD COLUMN version INTEGER DEFAULT 1;

-- 2. folders 表新增 version 字段（乐观锁）
ALTER TABLE folders ADD COLUMN version INTEGER DEFAULT 1;

-- 3. 启用 Realtime 发布
ALTER PUBLICATION supabase_realtime ADD TABLE notes;
ALTER PUBLICATION supabase_realtime ADD TABLE folders;

-- 4. 设置 REPLICA IDENTITY（支持冲突检测，需要 OLD 记录）
ALTER TABLE notes REPLICA IDENTITY FULL;
ALTER TABLE folders REPLICA IDENTITY FULL;

-- 5. 索引优化（version 字段查询）
CREATE INDEX idx_notes_version ON notes(version);
CREATE INDEX idx_folders_version ON folders(version);
