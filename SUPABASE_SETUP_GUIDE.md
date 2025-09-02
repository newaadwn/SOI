# Supabase 딥링크 서비스 설정 가이드

## 1. Supabase 프로젝트 생성

1. [Supabase](https://supabase.com)에 접속하여 계정 생성/로그인
2. "New Project" 클릭
3. 프로젝트 정보 입력:
   - **Name**: SOI-Deeplinks (또는 원하는 이름)
   - **Database Password**: 강력한 비밀번호 설정
   - **Region**: Northeast Asia (Seoul) 선택
4. "Create new project" 클릭하여 생성 완료

## 2. Edge Functions 생성

### 2.1 Supabase CLI 설치 (선택사항)
```bash
npm install -g supabase
```

### 2.2 웹 UI에서 Edge Function 생성

1. Supabase 대시보드에서 "Edge Functions" 탭 클릭
2. "Create a new function" 클릭
3. Function name: `handle-deeplink`
4. 아래 코드를 함수에 추가:

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

interface DeeplinkRequest {
  type: 'photo' | 'category' | 'profile' | 'invite';
  targetId: string;
  metadata?: {
    title?: string;
    description?: string;
    imageUrl?: string;
    inviterId?: string;
    inviterName?: string;
  };
}

serve(async (req) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  }

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Supabase 클라이언트 초기화
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    if (req.method === 'POST') {
      // 딥링크 생성
      const { type, targetId, metadata }: DeeplinkRequest = await req.json()
      
      // 고유 링크 ID 생성
      const linkId = crypto.randomUUID()
      
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
        })

      if (error) {
        throw error
      }

      // 딥링크 URL 생성
      const deeplinkUrl = `https://soi-app.page.link/${linkId}`
      
      return new Response(
        JSON.stringify({ 
          success: true, 
          url: deeplinkUrl,
          linkId 
        }),
        { 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    if (req.method === 'GET') {
      // 딥링크 해석
      const url = new URL(req.url)
      const linkId = url.pathname.split('/').pop()

      if (!linkId) {
        return new Response('Link ID not provided', { status: 400, headers: corsHeaders })
      }

      // 딥링크 데이터 조회
      const { data, error } = await supabaseClient
        .from('deeplinks')
        .select('*')
        .eq('id', linkId)
        .single()

      if (error || !data) {
        // 딥링크를 찾을 수 없는 경우 앱 스토어로 리다이렉트
        return Response.redirect('https://apps.apple.com/app/your-app-id', 302)
      }

      // 클릭 수 증가
      await supabaseClient
        .from('deeplinks')
        .update({ click_count: data.click_count + 1 })
        .eq('id', linkId)

      // iOS 앱으로 딥링크 시도, 실패시 앱스토어로 이동
      const appScheme = `soi://deeplink/${data.type}/${data.target_id}`
      
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
      `

      return new Response(htmlResponse, {
        headers: { ...corsHeaders, 'Content-Type': 'text/html' }
      })
    }

    return new Response('Method not allowed', { status: 405, headers: corsHeaders })

  } catch (error) {
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { 
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
```

## 3. Database 테이블 생성

1. Supabase 대시보드에서 "Table Editor" 탭 클릭
2. "Create a new table" 클릭
3. 테이블 설정:
   - **Name**: `deeplinks`
   - **Description**: "App deeplink storage"

4. 다음 컬럼들 추가:

| Column Name | Type | Default Value | Extra |
|-------------|------|---------------|-------|
| id | text | | Primary Key |
| type | text | | Not Null |
| target_id | text | | Not Null |
| metadata | jsonb | | Nullable |
| created_at | timestamptz | now() | Not Null |
| click_count | int4 | 0 | Not Null |

## 4. 프로젝트 설정 값 가져오기

1. Supabase 대시보드에서 "Settings" → "API" 클릭
2. 다음 값들을 복사:
   - **Project URL**: `https://your-project-id.supabase.co`
   - **anon public key**: `eyJhbGc...` (공개 키)

## 5. Flutter 앱에 설정 적용

`lib/services/supabase_deeplink_service.dart` 파일에서 다음 부분을 수정:

```dart
class SupabaseDeeplinkService {
  static const String _supabaseUrl = 'https://your-project-id.supabase.co';  // 여기에 실제 URL 입력
  static const String _supabaseAnonKey = 'eyJhbGc...';  // 여기에 실제 anon key 입력
  static const String _edgeFunctionUrl = '$_supabaseUrl/functions/v1/handle-deeplink';
```

## 6. 도메인 설정 (선택사항)

더 깔끔한 URL을 원한다면:

1. 도메인 구매 (예: soi-app.com)
2. Supabase의 Custom Domain 기능 사용
3. DNS 설정으로 `soi-app.page.link`를 커스텀 도메인으로 연결

## 7. 테스트

설정 완료 후 앱에서 테스트:

```dart
// 친구 초대 링크 생성 테스트
final inviteLink = await SupabaseDeeplinkService.createFriendInviteLink(
  inviterId: 'current_user_id',
  inviterName: '홍길동',
);
print('생성된 초대 링크: $inviteLink');
```

## 8. 보안 고려사항

1. **RLS (Row Level Security)** 설정:
   ```sql
   ALTER TABLE deeplinks ENABLE ROW LEVEL SECURITY;
   
   CREATE POLICY "Public read access" ON deeplinks 
   FOR SELECT USING (true);
   
   CREATE POLICY "Authenticated insert" ON deeplinks 
   FOR INSERT WITH CHECK (true);
   ```

2. **Rate Limiting**: Edge Function에서 IP별 요청 제한 추가
3. **URL 유효기간**: 필요시 `expires_at` 컬럼 추가

## 9. 모니터링

Supabase 대시보드에서 확인 가능:
- Edge Function 로그
- Database 사용량
- 딥링크 클릭 통계

---

이 가이드를 따라 설정하면 Firebase와 함께 Supabase를 사용한 하이브리드 딥링크 시스템을 구축할 수 있습니다. 기존 Firebase 기능은 그대로 유지되면서 딥링크 기능만 Supabase를 통해 제공됩니다.
