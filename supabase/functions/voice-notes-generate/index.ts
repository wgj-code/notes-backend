// F-001: voice-notes-generate Edge Function
// 接收转写文本+场景类型，调用DeepSeek生成结构化笔记

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

interface VoiceNoteRequest {
  voice_note_id: string;
  raw_text: string;
  scene_type: 'meeting' | 'chat' | 'monologue' | 'unknown';
  duration_seconds: number;
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

// 内容标题指令（所有场景共用，生成的内容第一行为标题）
const CONTENT_TITLE = `
在输出最前面加一行标题（不超过20字），格式：TITLE: xxx
标题要具体到内容主题，不要用泛称。
`;

// 场景模板
const SCENE_PROMPTS: Record<string, string> = {
  meeting: `你是一个专业的会议纪要助手。请根据以下会议转写文本，生成结构化的会议纪要。
${CONTENT_TITLE}
输出格式（标题之后）：

## 基本信息
- 时间：{根据内容推断}
- 参会人：{根据内容识别}
- 主题：{根据内容总结}

## 议题讨论
1. {议题1}
   - 讨论要点：
   - 结论：

## 待办事项
- [ ] {任务} - 负责人：{姓名}

## 关键决策
- {决策内容}

要求：
- 忠实于原始对话内容
- 识别参会人员
- 提取关键决策和待办事项
- 使用中文输出`,

  chat: `你是一个善于总结的助手。请根据以下闲聊转写文本，生成摘要和金句。
${CONTENT_TITLE}
输出格式（标题之后）：

## 摘要
{一段话总结闲聊内容}

## 金句提取
> {最有价值或有趣的句子1}
> {最有价值或有趣的句子2}
> {最有价值或有趣的句子3}

## 关键话题
- {话题1}
- {话题2}

要求：
- 提取对话中的精华内容
- 金句要有趣、有洞察力或有启发性
- 使用中文输出`,

  monologue: `你是一个善于提炼总结的助手。请根据以下自言自语转写文本，记录全文并提炼总结。
${CONTENT_TITLE}
输出格式（标题之后）：

## 全文记录
{完整保留原始转写文本}

## 提炼总结
{核心观点和想法的提炼}

## 行动建议
- {建议1}
- {建议2}
- {建议3}

要求：
- 全文记录部分必须完整保留原始内容
- 总结要抓住核心思想
- 给出可执行的行动建议
- 使用中文输出`,

  unknown: `你是一个通用的文本处理助手。请根据以下转写文本，生成内容摘要。
${CONTENT_TITLE}
输出格式（标题之后）：

## 摘要
{内容摘要}

## 要点
- {要点1}
- {要点2}
- {要点3}

## 原文
{原始转写文本}

要求：
- 准确概括内容
- 提取关键要点
- 使用中文输出`,
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
    const deepseekApiKey = Deno.env.get('DEEPSEEK_API_KEY')!;
    const deepseekBaseUrl = Deno.env.get('DEEPSEEK_BASE_URL') || 'https://api.deepseek.com';

    if (!deepseekApiKey) {
      return new Response(JSON.stringify({ error: 'DEEPSEEK_API_KEY not configured' }), {
        status: 500,
        headers: { 'Content-Type': 'application/json', ...corsHeaders },
      });
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const body: VoiceNoteRequest = await req.json();
    const { voice_note_id, scene_type, duration_seconds } = body;
    let raw_text = body.raw_text;

    if (!voice_note_id) {
      return new Response(JSON.stringify({ error: 'Missing voice_note_id' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', ...corsHeaders },
      });
    }

    // 如果raw_text为空，使用占位文本
    if (!raw_text) {
      raw_text = '（语音转写内容为空，请根据录音内容生成笔记）';
    }

    // 更新状态为processing
    await supabase
      .from('voice_notes')
      .update({ status: 'processing' })
      .eq('id', voice_note_id);

    // 构建LLM请求
    const systemPrompt = SCENE_PROMPTS[scene_type] || SCENE_PROMPTS.unknown;
    const userMessage = `场景类型：${scene_type}\n录音时长：${Math.floor(duration_seconds / 60)}分${duration_seconds % 60}秒\n\n转写文本：\n${raw_text}`;

    // 调用DeepSeek API
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
          { role: 'user', content: userMessage },
        ],
        temperature: 0.3,
        max_tokens: 4096,
      }),
    });

    if (!response.ok) {
      const errorData = await response.text();
      console.error('DeepSeek API error:', errorData);

      // 更新状态为failed
      await supabase
        .from('voice_notes')
        .update({
          status: 'failed',
          error_message: `LLM API error: ${response.status}`,
        })
        .eq('id', voice_note_id);

      return new Response(JSON.stringify({ error: 'LLM API error', details: errorData }), {
        status: 500,
        headers: { 'Content-Type': 'application/json', ...corsHeaders },
      });
    }

    const llmResponse = await response.json();
    const fullResponse = llmResponse.choices?.[0]?.message?.content;

    if (!fullResponse) {
      await supabase
        .from('voice_notes')
        .update({
          status: 'failed',
          error_message: 'Empty LLM response',
        })
        .eq('id', voice_note_id);

      return new Response(JSON.stringify({ error: 'Empty LLM response' }), {
        status: 500,
        headers: { 'Content-Type': 'application/json', ...corsHeaders },
      });
    }

    // 解析 TITLE 行，提取为独立标题
    let contentTitle = '';
    let generatedNote = fullResponse;
    const titleMatch = fullResponse.match(/^TITLE:\s*(.+)$/m);
    if (titleMatch) {
      contentTitle = titleMatch[1].trim().substring(0, 20);
      generatedNote = fullResponse.replace(/^TITLE:\s*.+$\n?/, '').trim();
    }

    // 更新voice_notes记录
    const { error: updateError } = await supabase
      .from('voice_notes')
      .update({
        generated_note: generatedNote,
        title: contentTitle || null,
        status: 'completed',
      })
      .eq('id', voice_note_id);

    if (updateError) {
      console.error('Update error:', updateError);
      return new Response(JSON.stringify({ error: updateError.message }), {
        status: 500,
        headers: { 'Content-Type': 'application/json', ...corsHeaders },
      });
    }

    return new Response(JSON.stringify({
      ok: true,
      voice_note_id,
      title: contentTitle,
      generated_note: generatedNote,
    }), {
      status: 200,
      headers: { 'Content-Type': 'application/json', ...corsHeaders },
    });
  } catch (err) {
    console.error('voice-notes-generate error:', err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json', ...corsHeaders },
    });
  }
});
