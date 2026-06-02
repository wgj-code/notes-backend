-- B-012: 异常打点+日志自动化收集
-- 创建 app_logs 表用于集中存储结构化日志

CREATE TABLE app_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  level TEXT NOT NULL CHECK (level IN ('error', 'warn', 'info', 'event')),
  module TEXT NOT NULL,
  message TEXT NOT NULL,
  metadata JSONB DEFAULT '{}',
  stack TEXT,
  device JSONB DEFAULT '{}',
  source TEXT NOT NULL CHECK (source IN ('mobile', 'web', 'backend')),
  user_id UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 索引：按时间倒序 + 按 level/source 筛选
CREATE INDEX idx_app_logs_created_at ON app_logs (created_at DESC);
CREATE INDEX idx_app_logs_level ON app_logs (level);
CREATE INDEX idx_app_logs_source ON app_logs (source);
CREATE INDEX idx_app_logs_module ON app_logs (module);

-- RLS: 仅 service_role 可写入，authenticated 可读取（看板用）
ALTER TABLE app_logs ENABLE ROW LEVEL SECURITY;

-- service_role 完全控制（Edge Function 用 service_role key 写入）
CREATE POLICY "service_role_all" ON app_logs
  FOR ALL
  USING (auth.role() = 'service_role');

-- authenticated 用户可读（日志看板用）
CREATE POLICY "authenticated_read" ON app_logs
  FOR SELECT
  USING (auth.role() = 'authenticated');
