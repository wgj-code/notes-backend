// 6A Demo · 示例 Edge Function
// 用于验证 deno runtime 可用 + 接口联通,后续由组B 开发 Agent 扩展

import { serve } from 'https://deno.land/std@0.208.0/http/server.ts';

serve((req) => {
  const { method } = req;
  return new Response(
    JSON.stringify({
      ok: true,
      method,
      message: '6A Demo · notes-backend hello function v0.1',
      timestamp: new Date().toISOString(),
    }),
    { headers: { 'content-type': 'application/json' } }
  );
});
