import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
  };

  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: corsHeaders
    });
  }

  try {
    if (req.method === 'POST') {
      // POST 요청 - 인증 헤더 확인
      const authHeader = req.headers.get('authorization');
      const apiKey = req.headers.get('apikey');
      
      console.log('Auth header:', authHeader);
      console.log('API key:', apiKey);
      
      // Supabase 클라이언트 초기화 (anon key 사용)
      const supabaseClient = createClient(
        Deno.env.get('SUPABASE_URL') ?? '', 
        Deno.env.get('SUPABASE_ANON_KEY') ?? ''
      );

      // 딥링크 생성
      const { type, targetId, metadata } = await req.json();
      
      // 고유 링크 ID 생성
      const linkId = crypto.randomUUID();
      
      // 딥링크 데이터 저장
      const { data, error } = await supabaseClient
        .from('deeplinks')
        .insert({
          id: linkId,
          type,
          target_id: targetId,
          metadata,
          created_at: new Date().toISOString(),
          click_count: 0
        });

      if (error) {
        throw error;
      }

      // 딥링크 URL 생성 (Supabase Edge Function URL 사용)
      const deeplinkUrl = `https://bobyanticgtadhimszzi.supabase.co/functions/v1/handle-deeplink/${linkId}`;
      
      return new Response(JSON.stringify({
        success: true,
        url: deeplinkUrl,
        linkId
      }), {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }

    if (req.method === 'GET') {
      // 딥링크 해석 (GET 요청은 인증 불필요)
      const url = new URL(req.url);
      const linkId = url.pathname.split('/').pop();

      if (!linkId) {
        return new Response('Link ID not provided', {
          status: 400,
          headers: corsHeaders
        });
      }

      // Supabase 클라이언트 초기화 (GET 요청용 - 서비스 롤 키 사용)
      const supabaseClientForGet = createClient(
        Deno.env.get('SUPABASE_URL') ?? '', 
        Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
      );

      // 딥링크 데이터 조회
      const { data, error } = await supabaseClientForGet
        .from('deeplinks')
        .select('*')
        .eq('id', linkId)
        .single();

      if (error || !data) {
        // 딥링크를 찾을 수 없는 경우 앱 스토어로 리다이렉트
        return Response.redirect('https://apps.apple.com/app/your-app-id', 302);
      }

      // 클릭 수 증가
      await supabaseClientForGet
        .from('deeplinks')
        .update({
          click_count: data.click_count + 1
        })
        .eq('id', linkId);

      // iOS 앱으로 딥링크 시도, 실패시 앱스토어로 이동
      const appScheme = `soi://deeplink/${data.type}/${data.target_id}`;
      
      const htmlResponse = `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <title>SOI 앱으로 이동 중...</title>
          <meta name="viewport" content="width=device-width, initial-scale=1">
        </head>
        <body>
          <script>
            window.location.href = "${appScheme}";
            setTimeout(() => {
              window.location.href = "https://apps.apple.com/app/your-app-id";
            }, 2000);
          </script>
          <p>SOI 앱으로 이동 중입니다...</p>
          <p>앱이 설치되어 있지 않다면 <a href="https://apps.apple.com/app/your-app-id">여기</a>에서 다운로드하세요.</p>
        </body>
        </html>
      `;

      return new Response(htmlResponse, {
        headers: {
          ...corsHeaders,
          'Content-Type': 'text/html'
        }
      });
    }

    return new Response('Method not allowed', {
      status: 405,
      headers: corsHeaders
    });

  } catch (error) {
    return new Response(JSON.stringify({
      success: false,
      error: error.message
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  }
});
