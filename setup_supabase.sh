#!/bin/bash

echo "🚀 SOI Supabase 설정 스크립트"

# 1. Supabase 프로젝트가 링크되어 있는지 확인
if [ ! -f "supabase/.temp/project-ref" ]; then
    echo "❌ Supabase 프로젝트가 링크되지 않았습니다."
    echo "다음 명령어로 프로젝트를 링크하세요:"
    echo "supabase link --project-ref YOUR_PROJECT_REF"
    exit 1
fi

echo "✅ Supabase 프로젝트 링크 확인됨"

# 2. 데이터베이스 마이그레이션 적용
echo "📊 데이터베이스 마이그레이션 적용 중..."
supabase db push

if [ $? -eq 0 ]; then
    echo "✅ 데이터베이스 마이그레이션 완료"
else
    echo "❌ 데이터베이스 마이그레이션 실패"
    exit 1
fi

# 3. Edge Function 배포
echo "🔧 Edge Function 배포 중..."
supabase functions deploy handle-deeplink

if [ $? -eq 0 ]; then
    echo "✅ Edge Function 배포 완료"
else
    echo "❌ Edge Function 배포 실패"
    exit 1
fi

# 4. 환경 변수 설정 확인
echo "🔑 환경 변수 확인 중..."
echo "다음 환경 변수가 Supabase에 설정되어 있는지 확인하세요:"
echo "- SUPABASE_URL"
echo "- SUPABASE_ANON_KEY"  
echo "- SUPABASE_SERVICE_ROLE_KEY"

echo ""
echo "🎉 설정 완료!"
echo "이제 딥링크가 다음 URL로 생성됩니다:"
echo "https://YOUR_PROJECT_REF.supabase.co/functions/v1/handle-deeplink/{linkId}"