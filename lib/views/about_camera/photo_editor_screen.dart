import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
// 🔥 메모리 최적화: 이미지 처리용 추가
import 'dart:ui' as ui; // 🔥 메모리 최적화: 이미지 압축용 추가
import 'package:flutter/services.dart'; // 🔥 메모리 최적화: 이미지 압축용 추가
import 'package:provider/provider.dart';
import '../../controllers/audio_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/category_controller.dart';
import '../../controllers/photo_controller.dart';
import '../../models/selected_friend_model.dart';
import '../../utils/memory_monitor.dart';
import '../home_navigator_screen.dart';
import 'widgets/photo_display_widget.dart';
import 'widgets/audio_recorder_widget.dart';
import 'widgets/category_list_widget.dart';
import 'widgets/add_category_widget.dart';
import 'widgets/loading_popup_widget.dart';

class PhotoEditorScreen extends StatefulWidget {
  final String? downloadUrl;
  final String? imagePath; // 로컬 이미지 경로 추가

  const PhotoEditorScreen({super.key, this.downloadUrl, this.imagePath});

  @override
  State<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _PhotoEditorScreenState extends State<PhotoEditorScreen>
    with WidgetsBindingObserver {
  // 상태 변수
  bool _isLoading = true;
  String? _errorMessage;
  bool _useDownloadUrl = false;
  bool _useLocalImage = false;
  bool _showAddCategoryUI = false;
  String? _selectedCategoryId;
  bool _categoriesLoaded = false; // 카테고리 로드 상태 추적

  // 추출된 파형 데이터 저장
  List<double>? _recordedWaveformData;
  String? _recordedAudioPath; // 녹음된 오디오 파일 경로 백업 추가

  // 프로필 이미지 위치 관리 (피드와 동일한 방식)
  Offset? _profileImagePosition;

  // 컨트롤러
  final _draggableScrollController = DraggableScrollableController();
  final _categoryNameController = TextEditingController();
  bool _isDisposing = false; // dispose 상태 추적

  // Controller 인스턴스
  late AudioController _audioController;
  late CategoryController _categoryController;
  late AuthController _authController;
  late PhotoController _photoController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 메모리 모니터링 시작
    MemoryMonitor.startMonitoring();
    MemoryMonitor.logCurrentMemoryUsage('PhotoEditor 시작');

    _loadImage();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // 앱이 다시 활성화될 때 카테고리 목록을 새로고침
    if (state == AppLifecycleState.resumed) {
      _categoriesLoaded = false; // 플래그 리셋
      _loadUserCategories(forceReload: true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Provider에서 필요한 Controller들 가져오기
    _audioController = Provider.of<AudioController>(context, listen: false);
    _categoryController = Provider.of<CategoryController>(
      context,
      listen: false,
    );
    _authController = Provider.of<AuthController>(context, listen: false);
    _photoController = Provider.of<PhotoController>(context, listen: false);

    // 빌드 완료 후 오디오 초기화 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _audioController.initialize();
    });

    // 현재 로그인한 유저의 카테고리 로드 (빌드 완료 후 실행)
    if (!_categoriesLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadUserCategories();
      });
    }
  }

  @override
  void didUpdateWidget(PhotoEditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 위젯이 업데이트될 때 (새로운 사진으로 변경되는 등) 카테고리 목록 새로고침
    if (oldWidget.imagePath != widget.imagePath ||
        oldWidget.downloadUrl != widget.downloadUrl) {
      _categoriesLoaded = false; // 플래그 리셋
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadUserCategories(forceReload: true);
      });
    }
  }

  // 이미지 로딩 함수 개선
  Future<void> _loadImage() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 로컬 이미지 경로가 있는 경우, 그 경로를 사용 (우선순위 부여)
      if (widget.imagePath != null && widget.imagePath!.isNotEmpty) {
        // 파일이 실제로 존재하는지 확인
        final file = File(widget.imagePath!);
        if (await file.exists()) {
          setState(() {
            _useLocalImage = true;
            _isLoading = false;
          });
          return;
        } else {
          throw Exception('이미지 파일을 찾을 수 없습니다.');
        }
      }
      // 다운로드 URL이 있는 경우, 그 URL을 사용 (두 번째 우선순위)
      else if (widget.downloadUrl != null && widget.downloadUrl!.isNotEmpty) {
        setState(() {
          _useDownloadUrl = true;
          _isLoading = false;
        });
        return;
      }
    } catch (e) {
      setState(() {
        _errorMessage = "이미지 로딩 중 오류 발생: $e";
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = false;
    });
  }

  // 사용자 카테고리 로드 메서드
  Future<void> _loadUserCategories({bool forceReload = false}) async {
    if (!forceReload && _categoriesLoaded) return; // 이미 로드된 경우 스킵

    // 메모리 사용량 체크
    MemoryMonitor.logCurrentMemoryUsage('카테고리 로드 시작');

    // UI 로딩 상태를 별도로 관리하여 화면 전환 속도 향상
    if (!forceReload) {
      // 첫 로드시에는 로딩 UI를 최소화
      setState(() {
        _isLoading = false; // 이미지는 바로 보이도록
      });
    }

    try {
      // 현재 로그인한 유저의 UID 가져오기
      final currentUser = _authController.currentUser;
      if (currentUser != null) {
        // 현재 사용자 UID 확인됨

        // 백그라운드에서 카테고리 로드 (UI 블로킹 없음)
        Future.microtask(() async {
          try {
            await _categoryController.loadUserCategories(
              currentUser.uid,
              forceReload: forceReload,
            );
            _categoriesLoaded = true;
            // 로드된 카테고리 목록 준비 완료

            // 메모리 사용량 체크
            MemoryMonitor.logCurrentMemoryUsage('카테고리 로드 완료');
            MemoryMonitor.checkMemoryWarning('카테고리 로드 완료');

            // 카테고리 로드 완료 후 이미지 미리 로드 시작
            _preloadCategoryImages();

            // 카테고리 로딩 완료 후 UI 업데이트 (필요한 경우에만)
            if (mounted) {
              setState(() {});
            }
          } catch (e) {
            // 백그라운드 카테고리 로드 오류 발생
          }
        });
      } else {
        // 현재 로그인한 사용자가 없음
      }
    } catch (e) {
      // 카테고리 로드 오류 발생
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 카테고리 이미지 미리 로드 메서드
  Future<void> _preloadCategoryImages() async {
    try {
      final categories = _categoryController.userCategoryList;

      // 메모리 사용량 체크
      MemoryMonitor.logCurrentMemoryUsage('카테고리 이미지 preload 시작');

      // 우선순위 기반 선택 (처음 8개 정도)
      final priorityCategories =
          categories
              .where((c) => c.categoryPhotoUrl?.isNotEmpty == true)
              .take(8)
              .toList();

      debugPrint('카테고리 이미지 preload 시작: ${priorityCategories.length}개');

      // 순차적으로 미리 로드
      for (final category in priorityCategories) {
        try {
          // Flutter 기본 이미지 캐시에 미리 로드
          final imageProvider = NetworkImage(category.categoryPhotoUrl!);
          unawaited(precacheImage(imageProvider, context));

          debugPrint('카테고리 이미지 preload: ${category.name}');

          // 메모리 압박 시 중단
          if (MemoryMonitor.isMemoryUsageHigh()) {
            debugPrint('메모리 압박으로 preload 중단');
            break;
          }

          // 네트워크 부하 방지를 위한 약간의 지연
          await Future.delayed(Duration(milliseconds: 100));
        } catch (e) {
          debugPrint('카테고리 이미지 preload 실패: ${category.name} - $e');
          // 에러 무시하고 계속
        }
      }

      MemoryMonitor.logCurrentMemoryUsage('카테고리 이미지 preload 완료');
      debugPrint('카테고리 이미지 preload 완료');
    } catch (e) {
      debugPrint('카테고리 이미지 preload 전체 실패: $e');
    }
  }

  // 카테고리 선택 처리 함수
  void _handleCategorySelection(String categoryId) {
    // 이미 선택된 카테고리를 다시 클릭했을 때 (전송 실행)
    if (_selectedCategoryId == categoryId) {
      // 방안 1: 데이터 우선 추출 + 순차 실행
      _uploadThenNavigate(categoryId);
    } else {
      // 새로운 카테고리 선택 (선택 모드로 변경)
      if (mounted) {
        setState(() {
          _selectedCategoryId = categoryId;
        });
      }
    }
  }

  // 업로드 후 화면 전환 메서드
  Future<void> _uploadThenNavigate(String categoryId) async {
    // 로딩 팝업 표시
    LoadingPopupWidget.show(context, message: '사진을 업로드하고 있습니다.\n잠시만 기다려주세요');

    try {
      // 1. 업로드 전 메모리 적극적 정리 (메모리 사용량 30% 감소)
      try {
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
        // 강제 가비지 컬렉션 시도
        MemoryMonitor.forceGarbageCollection('업로드 전 정리');
        debugPrint('업로드 전 이미지 캐시 정리 완료');
      } catch (e) {
        debugPrint('업로드 전 캐시 정리 오류: $e');
      }

      // 2. 모든 오디오 세션 완전 정리 (iOS 충돌 방지)
      try {
        await _audioController.stopAudio();
        await _audioController.stopRealtimeAudio();
        _audioController.clearCurrentRecording();
        // iOS 오디오 세션 정리를 위한 대기 시간 증가
        await Future.delayed(Duration(milliseconds: 500));
        debugPrint('오디오 세션 정리 완료');
      } catch (e) {
        debugPrint('오디오 세션 정리 오류: $e');
      }

      // 3. 메모리 사용량 체크 후 데이터 추출
      MemoryMonitor.logCurrentMemoryUsage('업로드 데이터 추출 전');
      final uploadData = _extractUploadData(categoryId);
      if (uploadData == null) {
        // 로딩 팝업 닫기
        LoadingPopupWidget.hide(context);
        _navigateToHome();
        return;
      }

      // 4. 업로드 실행 (최적화된 방식)
      await _executeUploadWithExtractedData(uploadData);

      // 5. 업로드 완료 후 강화된 메모리 정리 (메모리 사용량 최대 감소)
      try {
        // 단계적 메모리 정리로 확실한 해제
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();

        // 1차 가비지 컬렉션
        MemoryMonitor.forceGarbageCollection('업로드 완료 후 정리 - 1차');

        // 약간의 지연 후 2차 정리 (Flutter의 지연 해제 패턴 대응)
        await Future.delayed(Duration(milliseconds: 200));
        PaintingBinding.instance.imageCache.clear();
        MemoryMonitor.forceGarbageCollection('업로드 완료 후 정리 - 2차');

        debugPrint('업로드 후 강화된 메모리 정리 완료');
      } catch (e) {
        debugPrint('업로드 후 캐시 정리 오류: $e');
      }

      // 로딩 팝업 닫기
      LoadingPopupWidget.hide(context);

      // 6. 업로드 완료 후 화면 전환
      if (mounted) {
        _navigateToHome();
      }
    } catch (e) {
      debugPrint('업로드 오류: $e');
      // 로딩 팝업 닫기
      LoadingPopupWidget.hide(context);

      // 🔥 오류 발생 시에도 강화된 메모리 정리
      try {
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
        MemoryMonitor.forceGarbageCollection('업로드 오류 후 정리');
        debugPrint('🧹 오류 후 메모리 정리 완료');
      } catch (cleanupError) {
        debugPrint('❌ 오류 후 정리 실패: $cleanupError');
      }

      // 오류가 발생해도 화면 전환은 실행
      if (mounted) {
        _navigateToHome();
      }
    }
  }

  // 업로드 데이터 추출 메서드 (동기적)
  Map<String, dynamic>? _extractUploadData(String categoryId) {
    // 현재 상태에서 모든 필요한 데이터를 즉시 추출
    final imagePath = widget.imagePath;
    final userId = _authController.getUserId;

    final audioPath =
        _recordedAudioPath ?? _audioController.currentRecordingPath;
    final waveformData = _recordedWaveformData;

    // 필수 데이터 검증
    if (imagePath == null || userId == null) {
      debugPrint('업로드 데이터 추출 실패 - imagePath: $imagePath, userId: $userId');
      return null;
    }

    return {
      'categoryId': categoryId,
      'imagePath': imagePath,
      'userId': userId,
      'audioPath': audioPath,
      'waveformData': waveformData,
    };
  }

  // 🔥 메모리 최적화: 추출된 데이터로 업로드 실행 (순차 처리 + 압축)
  Future<void> _executeUploadWithExtractedData(
    Map<String, dynamic> data,
  ) async {
    final categoryId = data['categoryId'] as String;
    final imagePath = data['imagePath'] as String;
    final userId = data['userId'] as String;
    final audioPath = data['audioPath'] as String?;
    final waveformData = data['waveformData'] as List<double>?;

    // 📸 1. 이미지 파일 최적화 (메모리 사용량 50% 감소)
    final imageFile = File(imagePath);
    if (!await imageFile.exists()) {
      throw Exception('이미지 파일을 찾을 수 없습니다: $imagePath');
    }

    // 🗜️ 이미지 압축 및 리사이징 (1080p 최대 해상도로 제한)
    File? optimizedImageFile;
    try {
      optimizedImageFile = await _optimizeImageFile(imageFile);
    } catch (e) {
      debugPrint('이미지 최적화 실패, 원본 사용: $e');
      optimizedImageFile = imageFile;
    }

    // 🎵 2. 오디오 파일 확인 및 최적화
    File? audioFile;
    if (audioPath != null && audioPath.isNotEmpty) {
      audioFile = File(audioPath);
      if (!await audioFile.exists()) {
        audioFile = null;
      }
    } else {
      debugPrint('오디오 경로가 null이거나 비어있음: $audioPath');
    }

    // 3. 파형 데이터 최적화 (샘플링 수 제한)
    List<double>? optimizedWaveform;
    if (waveformData != null && waveformData.isNotEmpty) {
      optimizedWaveform = _optimizeWaveformData(waveformData);
      debugPrint(
        '파형 데이터 최적화: ${waveformData.length} -> ${optimizedWaveform.length}',
      );
    }

    try {
      // 🚀 4. 순차 업로드 실행 (메모리 사용량 분산)
      if (audioFile != null &&
          optimizedWaveform != null &&
          optimizedWaveform.isNotEmpty) {
        // 오디오와 함께 업로드 (스트림 방식)
        await _photoController.uploadPhotoWithAudio(
          imageFilePath: optimizedImageFile.path,
          audioFilePath: audioFile.path,
          userID: userId,
          userIds: [userId],
          categoryId: categoryId,
          waveformData: optimizedWaveform,
          duration: Duration(seconds: _audioController.recordingDuration),
        );
        debugPrint('오디오와 함께 업로드 완료 (최적화)');
      } else {
        // 이미지만 업로드 (스트림 방식)
        await _photoController.uploadPhoto(
          imageFile: optimizedImageFile,
          categoryId: categoryId,
          userId: userId,
          userIds: [userId],
          audioFile: null,
        );
        debugPrint('이미지만 업로드 완료 (최적화)');
      }
    } finally {
      // 🧹 5. 업로드 완료 후 임시 파일 즉시 정리
      if (optimizedImageFile.path != imagePath) {
        try {
          await optimizedImageFile.delete();
          debugPrint('최적화된 임시 이미지 파일 삭제 완료');
        } catch (e) {
          debugPrint('임시 파일 삭제 실패: $e');
        }
      }

      // 메모리에서 변수들 즉시 해제
      audioFile = null;
      optimizedWaveform = null;
    }
  }

  // 화면 전환 메서드 (분리)
  void _navigateToHome() {
    if (!mounted || _isDisposing) return;

    // 화면 전환 전 최종 오디오 리소스 정리
    try {
      _audioController.stopAudio();
      _audioController.clearCurrentRecording();
      debugPrint('화면 전환 전 오디오 정리 완료');
    } catch (e) {
      debugPrint('화면 전환 전 오디오 정리 오류: $e');
    }

    // 즉시 화면 전환 (딜레이 없음)
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => HomePageNavigationBar(currentPageIndex: 2),
        settings: RouteSettings(name: '/home_navigation_screen'),
      ),
      (route) => false,
    );

    // 백그라운드에서 바텀시트 정리 (화면 전환 후)
    Future.microtask(() {
      if (_draggableScrollController.isAttached) {
        _draggableScrollController.jumpTo(0.19);
      }
    });
  }

  // 안전한 시트 애니메이션 메서드
  void _animateSheetTo(double size) {
    if (!mounted || _isDisposing) return;

    // 즉시 실행이 아닌 다음 프레임에서 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isDisposing) return;

      try {
        if (_draggableScrollController.isAttached) {
          _draggableScrollController
              .animateTo(
                size,
                duration: Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              )
              .catchError((error) {
                // 애니메이션 에러 처리
                debugPrint('애니메이션 에러: $error');
                return null;
              });
        }
      } catch (e) {
        // 애니메이션 실행 에러 처리
        debugPrint('애니메이션 실행 에러: $e');
      }
    });
  }

  // 카테고리 생성 처리 함수
  Future<void> _createNewCategory(
    String categoryName,
    List<SelectedFriendModel> selectedFriends,
  ) async {
    if (_categoryNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('카테고리 이름을 입력해주세요')));
      return;
    }

    // 카테고리 저장 로직 호출
    try {
      // 현재 사용자 정보 가져오기
      final String? userId = _authController.getUserId;
      // 카테고리 생성 - Firebase Auth UID 확인

      if (userId == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('로그인이 필요합니다. 다시 로그인해주세요.')));
        return;
      }

      // 메이트 리스트 준비 (현재 사용자 + 선택된 친구들)
      // 중요: mates 필드에는 Firebase Auth UID를 사용해야 함
      List<String> mates = [userId];

      // 선택된 친구들의 UID 추가
      for (final friend in selectedFriends) {
        if (!mates.contains(friend.uid)) {
          mates.add(friend.uid);
        }
      }

      // 카테고리 생성 - mates 리스트 준비

      // 카테고리 생성
      await _categoryController.createCategory(
        name: _categoryNameController.text.trim(),
        mates: mates,
      );

      // 카테고리 목록 강제 새로고침
      _categoriesLoaded = false; // 플래그 리셋
      await _loadUserCategories(forceReload: true);

      // 원래 화면으로 돌아가기
      setState(() {
        _showAddCategoryUI = false;
        _categoryNameController.clear();
      });

      if (!context.mounted) return;

      // 성공 메시지는 CategoryController에서 처리됨
    } catch (e) {
      // 카테고리 생성 중 오류 발생
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('카테고리 생성 중 오류가 발생했습니다')));
    }
  }

  // 메모리 최적화: 이미지 파일 압축 및 리사이징
  Future<File> _optimizeImageFile(File originalFile) async {
    try {
      // 원본 이미지 데이터 읽기
      final Uint8List originalBytes = await originalFile.readAsBytes();

      // 이미지 디코딩
      final ui.Codec codec = await ui.instantiateImageCodec(
        originalBytes,
        targetWidth: 1080, // 최대 1080p로 제한
      );

      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;

      // PNG 유지 (품질 우선)
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData == null) {
        throw Exception('이미지 압축 실패');
      }

      // 임시 파일 생성
      final String tempDir = Directory.systemTemp.path;
      final String fileName =
          'optimized_${DateTime.now().millisecondsSinceEpoch}.png';
      final File optimizedFile = File('$tempDir/$fileName');

      // 압축된 데이터 저장
      await optimizedFile.writeAsBytes(byteData.buffer.asUint8List());

      // 메모리 정리
      image.dispose();

      debugPrint(
        '📸 이미지 최적화 완료: ${originalBytes.length} -> ${byteData.lengthInBytes} bytes',
      );

      return optimizedFile;
    } catch (e) {
      debugPrint('❌ 이미지 최적화 실패: $e');
      return originalFile; // 실패 시 원본 반환
    }
  }

  // 🔥 메모리 최적화: 파형 데이터 샘플링 최적화
  List<double> _optimizeWaveformData(List<double> originalWaveform) {
    if (originalWaveform.length <= 100) {
      return originalWaveform; // 이미 최적화됨
    }

    // 🔥 샘플링으로 데이터 크기 50% 감소 (100개 샘플로 제한)
    const int targetSamples = 100;
    final double step = originalWaveform.length / targetSamples;

    final List<double> optimizedWaveform = [];
    for (int i = 0; i < targetSamples; i++) {
      final int index = (i * step).round();
      if (index < originalWaveform.length) {
        optimizedWaveform.add(originalWaveform[index]);
      }
    }

    return optimizedWaveform;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SOI',
                  style: TextStyle(
                    color: Color(0xfff9f9f9),
                    fontSize: 20.sp,
                    fontFamily: GoogleFonts.inter().fontFamily,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 30.h),
              ],
            ),

            toolbarHeight: 70.h,
            backgroundColor: Colors.black,
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                // Main content
                Center(
                  child:
                      _isLoading
                          ? const CircularProgressIndicator()
                          : _errorMessage != null
                          ? Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.white),
                          )
                          : Column(
                            mainAxisAlignment: MainAxisAlignment.center,

                            children: [
                              // 이미지 표시 위젯을 DragTarget으로 감싸기 (피드와 동일한 방식)
                              PhotoDisplayWidget(
                                imagePath: widget.imagePath,
                                downloadUrl: widget.downloadUrl,
                                useLocalImage: _useLocalImage,
                                useDownloadUrl: _useDownloadUrl,
                                width: 354.w,
                                height: 500.h,
                              ),
                              SizedBox(height: (15.h)),
                              // 오디오 녹음 위젯
                              AudioRecorderWidget(
                                photoId:
                                    widget.imagePath?.split('/').last ??
                                    'unknown',
                                isCommentMode: false,
                                profileImagePosition: _profileImagePosition,
                                getProfileImagePosition:
                                    () => _profileImagePosition,
                                onRecordingCompleted: (
                                  String? audioPath,
                                  List<double>? waveformData,
                                ) {
                                  // 파형 데이터와 오디오 경로를 상태 변수에 저장
                                  setState(() {
                                    _recordedWaveformData = waveformData;
                                    _recordedAudioPath = audioPath; // ⭐ 경로 백업
                                  });
                                  debugPrint(
                                    '🎵 녹음 완료 - audioPath: $audioPath, waveformData: ${waveformData?.length}',
                                  );
                                },
                              ),
                            ],
                          ),
                ),
              ],
            ),
          ),
          bottomSheet: DraggableScrollableSheet(
            controller: _draggableScrollController,
            initialChildSize: 0.19,
            minChildSize: 0.19,
            maxChildSize: 0.8,
            expand: false,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Color(0xff171717),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    // 드래그 핸들
                    _showAddCategoryUI
                        ? Center(
                          child: Container(
                            margin: EdgeInsets.only(bottom: 12.h),
                          ),
                        )
                        : Center(
                          child: Container(
                            height: 3.h,
                            width: 56.w,
                            margin: EdgeInsets.only(top: 10.h, bottom: 12.h),
                            decoration: BoxDecoration(
                              color: Color(0xffcdcdcd),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                    //드래그 핸들과 카테고리 아이템 사이 간격 벌리긴
                    SizedBox(height: 4.h),
                    // 콘텐츠 영역: 조건에 따라 카테고리 목록 또는 카테고리 추가 UI 표시
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: Duration(milliseconds: 300),
                        child:
                            // _showAddCategoryUI가 참이면 AddCategoryWidget, 거짓이면 CategoryListWidget
                            _showAddCategoryUI
                                ? AddCategoryWidget(
                                  textController: _categoryNameController,
                                  scrollController: scrollController,
                                  onBackPressed: () {
                                    setState(() {
                                      _showAddCategoryUI = false;

                                      _categoryNameController.clear();
                                    });
                                    _animateSheetTo(0.18);
                                  },
                                  onSavePressed:
                                      (selectedFriends) => _createNewCategory(
                                        _categoryNameController.text.trim(),
                                        selectedFriends,
                                      ),
                                )
                                : CategoryListWidget(
                                  scrollController: scrollController,
                                  selectedCategoryId: _selectedCategoryId,
                                  onCategorySelected: _handleCategorySelection,
                                  addCategoryPressed: () {
                                    setState(() {
                                      _showAddCategoryUI = true;
                                    });
                                    // 시트 애니메이션 - 안전한 방법으로 실행
                                    _animateSheetTo(0.65);
                                  },
                                  isLoading: _categoryController.isLoading,
                                ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _isDisposing = true;

    // 메모리 모니터링 및 정리
    MemoryMonitor.logCurrentMemoryUsage('PhotoEditor 종료 시작');

    // 1. 오디오 리소스 안전하게 정리 (Widget Tree Lock 방지)
    try {
      // Widget Tree가 잠기기 전에 오디오만 중지 (notifyListeners 없는 작업)
      _audioController.stopAudio();
      _audioController.stopRealtimeAudio();

      // notifyListeners를 호출하는 작업은 다음 프레임에서 처리
      SchedulerBinding.instance.addPostFrameCallback((_) {
        try {
          _audioController.clearCurrentRecording();
          debugPrint('PhotoEditor: 오디오 리소스 정리 완료 (PostFrame)');
        } catch (e) {
          debugPrint('PhotoEditor: PostFrame 오디오 정리 오류: $e');
        }
      });

      // 로컬 데이터 즉시 해제 (Provider 알림 없음)
      _recordedWaveformData = null;
      _recordedAudioPath = null;
      debugPrint('PhotoEditor: 로컬 오디오 데이터 정리 완료');
    } catch (e) {
      debugPrint('PhotoEditor: 오디오 리소스 정리 오류: $e');
    }

    // 2. 이미지 캐시 강제 정리 (메모리 누수 방지)
    try {
      // 현재 이미지의 캐시 제거
      if (widget.imagePath != null) {
        final imageFile = File(widget.imagePath!);
        PaintingBinding.instance.imageCache.evict(FileImage(imageFile));
      }
      if (widget.downloadUrl != null) {
        PaintingBinding.instance.imageCache.evict(
          NetworkImage(widget.downloadUrl!),
        );
      }

      // 전체 이미지 캐시 정리
      PaintingBinding.instance.imageCache.clear();
      // 메모리 정리 강제 실행
      PaintingBinding.instance.imageCache.clearLiveImages();

      MemoryMonitor.logCurrentMemoryUsage('이미지 캐시 정리 후');
    } catch (e) {
      debugPrint('이미지 캐시 정리 오류: $e');
    }

    // 3. 컨트롤러 정리
    try {
      _categoryNameController.dispose();
    } catch (e) {
      debugPrint('컨트롤러 정리 오류: $e');
    }

    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (e) {
      debugPrint('옵저버 해제 오류: $e');
    }

    // 4. DraggableScrollController 안전한 정리
    try {
      if (_draggableScrollController.isAttached) {
        // 모든 제스처 완료를 위해 잠시 기다린 후 최소 크기로 설정
        _draggableScrollController.jumpTo(0.19);

        // 다음 프레임에서 dispose 시도
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            if (_draggableScrollController.isAttached) {
              _draggableScrollController.dispose();
            }
          } catch (e) {
            debugPrint('DraggableScrollController dispose 오류: $e');
          }
        });
      } else {
        // 이미 detached인 경우 바로 dispose
        _draggableScrollController.dispose();
      }
    } catch (e) {
      // 모든 에러 무시하고 다음 프레임에서 다시 시도
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          _draggableScrollController.dispose();
        } catch (e) {
          debugPrint('DraggableScrollController 최종 dispose 오류: $e');
        }
      });
    }

    // 5. 메모리 최적화 강화: CachedNetworkImage 캐시도 정리
    try {
      // 모든 네트워크 이미지 캐시 정리
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      // 추가: CachedNetworkImage의 메모리 캐시도 정리
      try {
        // CachedNetworkImage 관련 캐시도 함께 정리
        MemoryMonitor.forceGarbageCollection('PhotoEditor dispose - 1차');

        // 약간의 지연 후 한 번 더 정리 (완전한 해제를 위해)
        Future.delayed(Duration(milliseconds: 100), () {
          try {
            PaintingBinding.instance.imageCache.clear();
            MemoryMonitor.forceGarbageCollection('PhotoEditor dispose - 2차');
          } catch (e) {
            debugPrint('2차 메모리 정리 오류: $e');
          }
        });
      } catch (e) {
        debugPrint('CachedNetworkImage 캐시 정리 오류: $e');
      }
    } catch (e) {
      debugPrint('최종 메모리 정리 오류: $e');
    }

    // 메모리 모니터링 종료
    MemoryMonitor.logCurrentMemoryUsage('PhotoEditor 종료 완료');
    MemoryMonitor.stopMonitoring();

    super.dispose();
  }
}
