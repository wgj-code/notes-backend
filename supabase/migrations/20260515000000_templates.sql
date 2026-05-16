-- V1.3 Migration: note templates
-- Date: 2026-05-15

CREATE TABLE templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  name TEXT NOT NULL,
  title TEXT NOT NULL DEFAULT '',
  content TEXT NOT NULL DEFAULT '',
  is_builtin BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_templates_user_id ON templates(user_id);

ALTER TABLE templates ENABLE ROW LEVEL SECURITY;
CREATE POLICY "templates_select" ON templates FOR SELECT USING (auth.uid() = user_id OR is_builtin = true);
CREATE POLICY "templates_insert" ON templates FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "templates_update" ON templates FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "templates_delete" ON templates FOR DELETE USING (auth.uid() = user_id AND is_builtin = false);

-- Insert default built-in templates (user_id is NULL for built-in)
INSERT INTO templates (user_id, name, title, content, is_builtin) VALUES
  (NULL, '日记', '日常记录', '# {{date}}\n\n## 今天做了什么\n\n\n## 今天学到了什么\n\n\n## 明天计划\n\n', true),
  (NULL, '会议记录', '会议纪要', '# 会议纪要 - {{date}}\n\n## 参会人员\n\n\n## 议题\n\n\n## 结论与行动项\n\n| 行动项 | 负责人 | 截止日期 |\n|---|---|---|\n| | | |\n', true),
  (NULL, '读书笔记', '阅读记录', '# 《书名》读书笔记\n\n## 核心观点\n\n\n## 精彩摘录\n\n\n## 我的思考\n\n', true),
  (NULL, '待办清单', '任务列表', '# 待办清单\n\n## 今天\n- [ ] \n\n## 本周\n- [ ] \n\n## 本月\n- [ ] \n', true),
  (NULL, '自由笔记', '空白笔记', '', true);

-- Trigger for updated_at
CREATE OR REPLACE FUNCTION templates_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER templates_updated_at
  BEFORE UPDATE ON templates
  FOR EACH ROW
  EXECUTE FUNCTION templates_updated_at();
