// note-generate Edge Function
// 接收用户 prompt，调用 DeepSeek 生成笔记内容

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

interface NoteGenerateRequest {
  prompt: string;
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
    const deepseekApiKey = Deno.env.get('DEEPSEEK_API_KEY')!;
    const deepseekBaseUrl = Deno.env.get('DEEPSEEK_BASE_URL') || 'https://api.deepseek.com';

    if (!deepseekApiKey) {
      return new Response(JSON.stringify({ error: 'DEEPSEEK_API_KEY not configured' }), {
        status: 500,
        headers: { 'Content-Type': 'application/json', ...corsHeaders },
      });
    }

    const body: NoteGenerateRequest = await req.json();
    const { prompt } = body;

    if (!prompt) {
      return new Response(JSON.stringify({ error: 'Missing prompt' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', ...corsHeaders },
      });
    }

    // 构建 LLM 请求 - 直接用用户输入作为 prompt
    const systemPrompt = `你是一个笔记生成助手。请根据用户输入的内容生成笔记。

要求：
- 在输出最前面加一行标题（不超过20字），格式：TITLE: xxx
- 标题要具体到内容主题，不要用泛称
- 内容使用 Markdown 格式
- 使用中文输出`;

    // 调用 DeepSeek API
    const response = await fetch(`${deepseekBaseUrl}/chat/completions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${deepseekApiKey}`,
      },
      body: JSON.stringify({
        model: 'deepseek-chat',
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: prompt },
        ],
        temperature: 0.3,
        max_tokens: 4096,
      }),
    });

    if (!response.ok) {
      const errorData = await response.text();
      console.error('DeepSeek API error:', errorData);
      return new Response(JSON.stringify({ error: 'LLM API error', details: errorData }), {
        status: 500,
        headers: { 'Content-Type': 'application/json', ...corsHeaders },
      });
    }

    const llmResponse = await response.json();
    const fullResponse = llmResponse.choices?.[0]?.message?.content;

    if (!fullResponse) {
      return new Response(JSON.stringify({ error: 'Empty LLM response' }), {
        status: 500,
        headers: { 'Content-Type': 'application/json', ...corsHeaders },
      });
    }

    // 解析 TITLE 行，提取为独立标题
    let title = '';
    let content = fullResponse;
    const titleMatch = fullResponse.match(/^TITLE:\s*(.+)$/m);
    if (titleMatch) {
      title = titleMatch[1].trim().substring(0, 20);
      content = fullResponse.replace(/^TITLE:\s*.+$\n?/, '').trim();
    }

    return new Response(JSON.stringify({
      ok: true,
      title,
      content,
    }), {
      status: 200,
      headers: { 'Content-Type': 'application/json', ...corsHeaders },
    });
  } catch (err) {
    console.error('note-generate error:', err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json', ...corsHeaders },
    });
  }
});
