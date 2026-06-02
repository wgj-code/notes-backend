// B-012: logs-ingest Edge Function
// 接收结构化日志并写入 app_logs 表
// 写入使用 service_role key，读取看板使用 authenticated key

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

interface LogEntry {
  level: 'error' | 'warn' | 'info' | 'event';
  module: string;
  message: string;
  metadata?: Record<string, unknown>;
  stack?: string;
  device?: Record<string, unknown>;
  source: 'mobile' | 'web' | 'backend';
  user_id?: string;
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { 'Content-Type': 'application/json', ...corsHeaders },
    });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const body = await req.json();
    const logs: LogEntry[] = body.logs || (body.level ? [body] : []);

    if (!Array.isArray(logs) || logs.length === 0) {
      return new Response(JSON.stringify({ error: 'No logs provided' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', ...corsHeaders },
      });
    }

    // 限制单次最多 50 条
    const batch = logs.slice(0, 50).map((log) => ({
      level: log.level,
      module: log.module,
      message: String(log.message).slice(0, 2000),
      metadata: log.metadata || {},
      stack: log.stack ? String(log.stack).slice(0, 3000) : null,
      device: log.device || {},
      source: log.source,
      user_id: log.user_id || null,
    }));

    const { data, error } = await supabase
      .from('app_logs')
      .insert(batch)
      .select('id');

    if (error) {
      console.error('Insert error:', error);
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { 'Content-Type': 'application/json', ...corsHeaders },
      });
    }

    return new Response(JSON.stringify({ ok: true, inserted: data?.length || 0 }), {
      status: 200,
      headers: { 'Content-Type': 'application/json', ...corsHeaders },
    });
  } catch (err) {
    console.error('logs-ingest error:', err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json', ...corsHeaders },
    });
  }
});
