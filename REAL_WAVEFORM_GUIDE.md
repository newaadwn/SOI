## 실제 오디오 파형 구현 가이드

### 방법 1: 서버 사이드 파형 생성 (추천)

Firebase Functions를 사용해서 오디오 업로드 시 자동으로 파형 데이터를 생성하는 방법입니다.

#### 1단계: Firebase Functions 설정

```javascript
// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { Storage } = require('@google-cloud/storage');
const ffmpeg = require('fluent-ffmpeg');
const path = require('path');
const os = require('os');
const fs = require('fs');

admin.initializeApp();

exports.generateWaveform = functions.storage.object().onFinalize(async (object) => {
  const filePath = object.name;
  
  // 오디오 파일인지 확인
  if (!filePath.includes('/audio/') || !filePath.match(/\.(m4a|mp3|wav)$/i)) {
    return null;
  }

  const bucket = admin.storage().bucket();
  const tempFilePath = path.join(os.tmpdir(), path.basename(filePath));
  const waveformPath = tempFilePath.replace(/\.(m4a|mp3|wav)$/i, '.json');

  try {
    // 1. 오디오 파일 다운로드
    await bucket.file(filePath).download({ destination: tempFilePath });

    // 2. FFmpeg로 파형 데이터 추출
    const waveformData = await extractWaveform(tempFilePath);

    // 3. Firestore에 파형 데이터 저장
    const pathParts = filePath.split('/');
    const categoryId = pathParts[pathParts.length - 3]; // categories/{categoryId}/audio/{filename}
    const photoId = path.basename(filePath, path.extname(filePath));

    await admin.firestore()
      .collection('categories')
      .doc(categoryId)
      .collection('photos')
      .doc(photoId)
      .update({
        waveformData: waveformData
      });

    console.log('Waveform generated successfully for:', filePath);
  } catch (error) {
    console.error('Error generating waveform:', error);
  } finally {
    // 임시 파일 정리
    if (fs.existsSync(tempFilePath)) fs.unlinkSync(tempFilePath);
    if (fs.existsSync(waveformPath)) fs.unlinkSync(waveformPath);
  }
});

async function extractWaveform(audioPath) {
  return new Promise((resolve, reject) => {
    const waveformData = [];
    
    ffmpeg(audioPath)
      .audioFilter('aresample=16000') // 16kHz로 리샘플링
      .format('f32le') // 32비트 float 포맷
      .on('error', reject)
      .pipe()
      .on('data', (chunk) => {
        // 오디오 데이터를 파형으로 변환
        const samples = new Float32Array(chunk.buffer);
        for (let i = 0; i < samples.length; i += 1024) { // 다운샘플링
          const slice = samples.slice(i, i + 1024);
          const amplitude = Math.sqrt(slice.reduce((sum, sample) => sum + sample * sample, 0) / slice.length);
          waveformData.push(Math.min(amplitude * 10, 1.0)); // 정규화
        }
      })
      .on('end', () => {
        resolve(waveformData);
      });
  });
}
```

#### 2단계: PhotoDataModel에 waveformData 필드 추가

```dart
// lib/models/photo_data_model.dart
class PhotoDataModel {
  final String id;
  final String imageUrl;
  final String audioUrl;
  final String userID;
  final List<String> userIds;
  final String categoryId;
  final DateTime createdAt;
  final PhotoStatus status;
  final List<double>? waveformData; // 새로 추가

  PhotoDataModel({
    required this.id,
    required this.imageUrl,
    required this.audioUrl,
    required this.userID,
    required this.userIds,
    required this.categoryId,
    required this.createdAt,
    this.status = PhotoStatus.active,
    this.waveformData, // 새로 추가
  });

  factory PhotoDataModel.fromFirestore(Map<String, dynamic> data, String id) {
    return PhotoDataModel(
      id: id,
      imageUrl: data['imageUrl'] ?? '',
      audioUrl: data['audioUrl'] ?? '',
      userID: data['userID'] ?? '',
      userIds: (data['userIds'] as List?)?.cast<String>() ?? [],
      categoryId: data['categoryId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: PhotoStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => PhotoStatus.active,
      ),
      waveformData: (data['waveformData'] as List?)?.cast<double>(), // 새로 추가
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'imageUrl': imageUrl,
      'audioUrl': audioUrl,
      'userID': userID,
      'userIds': userIds,
      'categoryId': categoryId,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status.name,
      'waveformData': waveformData, // 새로 추가
    };
  }
}
```

#### 3단계: CustomWaveformWidget 수정

실제 파형 데이터가 있으면 사용하고, 없으면 기존의 임시 파형을 사용하도록 수정:

```dart
// lib/views/widgets/custom_waveform_widget.dart
class CustomWaveformWidget extends StatefulWidget {
  final double width;
  final double height;
  final Color waveColor;
  final Color progressColor;
  final double progress;
  final bool isPlaying;
  final VoidCallback? onTap;
  final String? audioUrl;
  final List<double>? realWaveformData; // 실제 파형 데이터

  const CustomWaveformWidget({
    Key? key,
    required this.width,
    required this.height,
    this.waveColor = Colors.grey,
    this.progressColor = Colors.blue,
    this.progress = 0.0,
    this.isPlaying = false,
    this.onTap,
    this.audioUrl,
    this.realWaveformData, // 새로 추가
  }) : super(key: key);

  @override
  State<CustomWaveformWidget> createState() => _CustomWaveformWidgetState();
}

class _CustomWaveformWidgetState extends State<CustomWaveformWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  List<double> _waveformData = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    
    _generateWaveformData();
    _animationController.forward();
  }

  void _generateWaveformData() {
    // 실제 파형 데이터가 있으면 사용
    if (widget.realWaveformData != null && widget.realWaveformData!.isNotEmpty) {
      _waveformData = widget.realWaveformData!;
      return;
    }

    // 없으면 기존의 임시 파형 생성
    final seed = widget.audioUrl?.hashCode ?? 12345;
    final random = math.Random(seed);
    final points = (widget.width / 3).round();
    
    _waveformData = List.generate(points, (index) {
      final baseHeight = 0.3 + (random.nextDouble() * 0.7);
      final variation = math.sin(index * 0.1) * 0.2;
      return (baseHeight + variation).clamp(0.1, 1.0);
    });
  }

  // ... 나머지 코드는 동일
}
```

### 방법 2: 클라이언트 사이드 FFI 사용

Flutter에서 직접 오디오 분석을 하려면 FFI(Foreign Function Interface)를 사용해서 네이티브 라이브러리를 호출할 수 있습니다.

#### 장점:
- 서버 의존성 없음
- 실시간 파형 생성 가능
- 오프라인에서도 동작

#### 단점:
- 구현 복잡도 높음
- 각 플랫폼별 네이티브 코드 필요
- 앱 크기 증가

### 추천 구현 순서

1. **1단계**: 서버 사이드 파형 생성 구현
2. **2단계**: 새로 업로드되는 오디오에 실제 파형 적용
3. **3단계**: 기존 오디오들을 백그라운드에서 점진적 처리
4. **4단계**: 필요시 클라이언트 사이드 실시간 파형 추가

이 방법으로 하면 실제 오디오 데이터를 기반으로 한 정확한 파형을 얻을 수 있습니다!
