-- 6A Demo · pgvector 语义搜索基础设施
-- 2026-05-09 · AI Semantic Search 预备迁移

-- 1. Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- 2. note_embeddings table
-- Stores pre-computed embeddings for note content.
-- Each row corresponds to a snapshot of note text at embedding time;
-- stale rows are replaced when re-embedded.
CREATE TABLE note_embeddings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  note_id UUID REFERENCES notes(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) NOT NULL,
  content TEXT NOT NULL,
  embedding vector(384),  -- all-MiniLM-L6-v2 dimension
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Indexes
-- ivfflat index for cosine similarity search; lists=100 is a reasonable
-- starting point for datasets up to ~100k rows; tune after initial data load.
CREATE INDEX idx_note_embeddings_embedding ON note_embeddings
  USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

CREATE INDEX idx_note_embeddings_note_id ON note_embeddings(note_id);
CREATE INDEX idx_note_embeddings_user_id ON note_embeddings(user_id);

-- unique constraint: one embedding row per note (latest wins on upsert)
CREATE UNIQUE INDEX idx_note_embeddings_note_id_unique ON note_embeddings(note_id);

-- 4. RLS policies
ALTER TABLE note_embeddings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "note_embeddings_select" ON note_embeddings
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "note_embeddings_insert" ON note_embeddings
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "note_embeddings_update" ON note_embeddings
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "note_embeddings_delete" ON note_embeddings
  FOR DELETE USING (auth.uid() = user_id);

-- 5. Semantic search RPC function
-- Returns notes ranked by cosine similarity to a query embedding.
-- Filters by auth.uid() so users only see their own notes.
CREATE OR REPLACE FUNCTION search_notes_semantic(
  query_embedding vector(384),
  match_count INT DEFAULT 10,
  match_threshold FLOAT DEFAULT 0.5
)
RETURNS TABLE (
  note_id UUID,
  title TEXT,
  content TEXT,
  similarity FLOAT
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    n.id AS note_id,
    n.title,
    n.content,
    1 - (ne.embedding <=> query_embedding) AS similarity
  FROM note_embeddings ne
  JOIN notes n ON n.id = ne.note_id
  WHERE ne.user_id = auth.uid()
    AND 1 - (ne.embedding <=> query_embedding) > match_threshold
  ORDER BY ne.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;

-- 6. Auto-update updated_at on note_embeddings
CREATE OR REPLACE FUNCTION note_embeddings_touch_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS note_embeddings_updated_at ON note_embeddings;
CREATE TRIGGER note_embeddings_updated_at
  BEFORE UPDATE ON note_embeddings
  FOR EACH ROW
  EXECUTE FUNCTION note_embeddings_touch_updated_at();
