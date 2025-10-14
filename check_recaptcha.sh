#!/bin/bash

echo "🔍 reCAPTCHA 문제 진단 스크립트"
echo "=================================="

# 1. 현재 빌드 모드 확인
echo "📱 현재 빌드 환경:"
if [[ -f "ios/Runner/Debug.xcconfig" ]]; then
    echo "   ✅ Debug 설정 파일 존재"
else
    echo "   ❌ Debug 설정 파일 없음"
fi

if [[ -f "ios/Runner/Release.xcconfig" ]]; then
    echo "   ✅ Release 설정 파일 존재"
else
    echo "   ❌ Release 설정 파일 없음"
fi

# 2. Firebase 설정 확인
echo ""
echo "🔥 Firebase 설정:"
if [[ -f "ios/Runner/GoogleService-Info.plist" ]]; then
    echo "   ✅ GoogleService-Info.plist 존재"
else
    echo "   ❌ GoogleService-Info.plist 없음"
fi

if [[ -f "android/app/google-services.json" ]]; then
    echo "   ✅ google-services.json 존재"
else
    echo "   ❌ google-services.json 없음"
fi

# 3. Info.plist 설정 확인
echo ""
echo "📋 Info.plist 설정:"
if grep -q "FirebaseAuthReCAPTCHABypassEnabled" ios/Runner/Info.plist; then
    echo "   ✅ reCAPTCHA 우회 설정 존재"
else
    echo "   ❌ reCAPTCHA 우회 설정 없음"
fi

if grep -q "remote-notification" ios/Runner/Info.plist; then
    echo "   ✅ 백그라운드 알림 설정 존재"
else
    echo "   ❌ 백그라운드 알림 설정 없음"
fi

# 4. 의존성 확인
echo ""
echo "📦 Flutter 의존성:"
if grep -q "firebase_auth" pubspec.yaml; then
    echo "   ✅ firebase_auth 패키지 존재"
else
    echo "   ❌ firebase_auth 패키지 없음"
fi

if grep -q "firebase_core" pubspec.yaml; then
    echo "   ✅ firebase_core 패키지 존재"
else
    echo "   ❌ firebase_core 패키지 없음"
fi

# 5. 권장 사항
echo ""
echo "💡 권장 사항:"
echo "   1. 테스트 전화번호 사용으로 즉시 해결 (Firebase 콘솔)"
echo "   2. Apple Developer Program 가입 후 APNs 키 설정"
echo "   3. Debug 모드에서 먼저 테스트"
echo "   4. 실제 기기에서 테스트 (시뮬레이터 X)"

echo ""
echo "🚀 테스트 실행:"
echo "   flutter run --debug"
echo "   전화번호: 01012345678"
echo "   인증코드: 123456"

echo ""
echo "📚 자세한 가이드: RECAPTCHA_FIX_GUIDE.md 참조"
