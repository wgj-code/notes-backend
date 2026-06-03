// deno-lint-ignore-file no-explicit-any
const VOICE_MAP: Record<string, string> = {
  host: "zh-CN-YunxiNeural",
  girl: "zh-CN-XiaoxiaoNeural",
  lady: "zh-CN-XiaohanNeural",
};

const RATE_MAP: Record<string, string> = {
  slow: "-30%",
  normal: "+0%",
  fast: "+30%",
};

Deno.serve(async (req: any) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST",
        "Access-Control-Allow-Headers": "Content-Type",
      },
    });
  }

  try {
    const { text, voice = "host", rate = "normal" } = await req.json();

    if (!text) {
      return new Response(JSON.stringify({ error: "text is required" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    const voiceName = VOICE_MAP[voice] || VOICE_MAP.host;
    const rateValue = RATE_MAP[rate] || RATE_MAP.normal;

    const ssml = `<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='zh-CN'>
      <voice name='${voiceName}'>
        <prosody rate='${rateValue}'>
          ${text}
        </prosody>
      </voice>
    </speak>`;

    // Use Microsoft Cognitive Services TTS REST API
    const tokenEndpoint = "https://eastus.api.cognitive.microsoft.com/sts/v1.0/issueToken";
    const ttsEndpoint = "https://eastus.tts.speech.microsoft.com/cognitiveservices/v1";

    // Get access token (free tier: 500K chars/month)
    const apiKey = Deno.env.get("SPEECH_KEY") || "";
    const tokenRes = await fetch(tokenEndpoint, {
      method: "POST",
      headers: {
        "Ocp-Apim-Subscription-Key": apiKey,
        "Content-Type": "application/x-www-form-urlencoded",
      },
    });

    if (!tokenRes.ok) {
      throw new Error(`Token request failed: ${tokenRes.status}`);
    }

    const accessToken = await tokenRes.text();

    // Synthesize speech
    const ttsRes = await fetch(ttsEndpoint, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${accessToken}`,
        "Content-Type": "application/ssml+xml",
        "X-Microsoft-OutputFormat": "audio-24khz-48kbitrate-mono-mp3",
        "User-Agent": "didi-notes-tts",
      },
      body: ssml,
    });

    if (!ttsRes.ok) {
      const errText = await ttsRes.text();
      throw new Error(`TTS failed: ${ttsRes.status} ${errText}`);
    }

    const audioBuffer = await ttsRes.arrayBuffer();

    return new Response(audioBuffer, {
      headers: {
        "Content-Type": "audio/mpeg",
        "Access-Control-Allow-Origin": "*",
      },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
