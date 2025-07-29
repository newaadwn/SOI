import 'package:flutter/material.dart';
import 'package:flutter_swift_camera/theme/theme.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import '../../controllers/audio_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/category_controller.dart';
import '../../controllers/photo_controller.dart';
import '../home_navigator_screen.dart';
import 'widgets/photo_display_widget.dart';
import 'widgets/audio_recorder_widget.dart';
import 'widgets/category_list_widget.dart';
import 'widgets/add_category_widget.dart';

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

  // 컨트롤러
  final _draggableScrollController = DraggableScrollableController();
  final _categoryNameController = TextEditingController();

  // Controller 인스턴스
  late AudioController _audioController;
  late CategoryController _categoryController;
  late AuthController _authController;
  late PhotoController _photoController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

    // ✅ UI 로딩 상태를 별도로 관리하여 화면 전환 속도 향상
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
        debugPrint('현재 사용자 UID: ${currentUser.uid}');

        // ✅ 백그라운드에서 카테고리 로드 (UI 블로킹 없음)
        Future.microtask(() async {
          try {
            await _categoryController.loadUserCategories(
              currentUser.uid,
              forceReload: forceReload,
            );
            _categoriesLoaded = true;
            debugPrint(
              '로드된 카테고리 수: ${_categoryController.userCategories.length}',
            );

            // 카테고리 로딩 완료 후 UI 업데이트 (필요한 경우에만)
            if (mounted) {
              setState(() {});
            }
          } catch (e) {
            debugPrint('백그라운드 카테고리 로드 오류: $e');
          }
        });
      } else {
        debugPrint('현재 로그인한 사용자가 없습니다.');
      }
    } catch (e) {
      debugPrint('카테고리 로드 오류: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ✅ 완전히 독립적인 백그라운드 업로드 함수
  void _savePhotoAndAudioToCategory(String categoryId) {
    // Future를 시작하되 await하지 않음 (Fire and Forget 패턴)
    _executeBackgroundUpload(categoryId)
        .then((_) {
          debugPrint('백그라운드 업로드 완료');
        })
        .catchError((e) {
          debugPrint('백그라운드 업로드 오류: $e');
        });
  }

  // 실제 업로드 작업을 수행하는 private 메서드
  Future<void> _executeBackgroundUpload(String categoryId) async {
    try {
      debugPrint('백그라운드 업로드 실행 시작');

      // 로컬 이미지 경로나 다운로드 URL 중 하나 선택
      if (_useLocalImage && widget.imagePath != null) {
        final String imagePath = widget.imagePath!;
        debugPrint('로컬 이미지 업로드: $imagePath');

        // Firebase Auth에서 UID 먼저 확인 (가장 빠른 작업)
        final String? userId = _authController.getUserId;
        if (userId == null) {
          throw Exception('사용자 ID가 없습니다. 로그인이 필요합니다.');
        }

        debugPrint('사용자 ID: $userId');

        // 이미지 파일 존재 확인
        final imageFile = File(imagePath);
        if (!await imageFile.exists()) {
          throw Exception('이미지 파일이 존재하지 않습니다: $imagePath');
        }
        debugPrint('이미지 파일 확인 완료');

        // ✅ 오디오 처리를 더 최적화 - 조건부 처리
        String audioPath = '';
        bool hasValidAudio = false;

        debugPrint('오디오 파일 확인 시작...');
        debugPrint(
          '  - currentRecordingPath: ${_audioController.currentRecordingPath}',
        );
        debugPrint('  - 파형 데이터 길이: ${_recordedWaveformData?.length ?? 0}');

        if (_audioController.currentRecordingPath != null &&
            _audioController.currentRecordingPath!.isNotEmpty) {
          // 오디오 파일 존재 확인 - 개선된 로직
          final audioFile = File(_audioController.currentRecordingPath!);
          debugPrint('파일 경로 확인: ${audioFile.path}');

          final fileExists = await audioFile.exists();
          debugPrint('파일 존재 여부: $fileExists');

          if (fileExists) {
            final fileSize = await audioFile.length();
            debugPrint('오디오 파일 존재: 크기 $fileSize bytes');
            if (fileSize > 0) {
              try {
                audioPath = await _audioController.processAudioForUpload();
                debugPrint('processAudioForUpload 결과: "$audioPath"');

                if (audioPath.isNotEmpty) {
                  hasValidAudio = true;
                  debugPrint('오디오 파일 처리 완료');
                } else {
                  debugPrint('processAudioForUpload가 빈 문자열 반환');

                  // processAudioForUpload가 실패해도 원본 파일 경로 사용 시도
                  debugPrint('원본 파일 경로로 대체 시도');
                  audioPath = _audioController.currentRecordingPath!;

                  // 원본 파일이 여전히 존재하는지 확인
                  if (await File(audioPath).exists()) {
                    hasValidAudio = true;
                    debugPrint('원본 파일 경로 사용: $audioPath');
                  } else {
                    debugPrint('원본 파일도 접근 불가');
                  }
                }
              } catch (e) {
                debugPrint('오디오 처리 실패: $e');

                // 예외 발생해도 원본 파일 사용 시도
                debugPrint('예외 발생, 원본 파일 경로로 대체 시도');
                audioPath = _audioController.currentRecordingPath!;

                if (await File(audioPath).exists()) {
                  hasValidAudio = true;
                  debugPrint('예외 상황에서 원본 파일 경로 사용: $audioPath');
                } else {
                  debugPrint('원본 파일도 접근 불가 (예외 상황)');
                }
              }
            } else {
              debugPrint('오디오 파일 크기가 0 bytes');
            }
          } else {
            debugPrint('오디오 파일이 존재하지 않음');
            debugPrint('존재하지 않는 파일 경로: ${audioFile.path}');

            // 파일이 존재하지 않아도 경로가 있다면 혹시 다른 위치에 있을 수 있음
            debugPrint('디렉토리 및 파일명 분석 시도');
            try {
              final directory = audioFile.parent;
              final fileName = audioFile.uri.pathSegments.last;
              debugPrint('디렉토리: ${directory.path}');
              debugPrint('파일명: $fileName');

              if (await directory.exists()) {
                debugPrint('디렉토리는 존재함');
                final files = await directory.list().toList();
                debugPrint('디렉토리 내 파일 개수: ${files.length}');

                // 같은 이름으로 시작하는 파일이 있는지 확인
                for (final file in files) {
                  if (file.path.contains('audio_') &&
                      file.path.endsWith('.m4a')) {
                    debugPrint('발견된 오디오 파일: ${file.path}');
                  }
                }
              } else {
                debugPrint('디렉토리도 존재하지 않음');
              }
            } catch (e) {
              debugPrint('디렉토리 분석 실패: $e');
            }
          }
        } else {
          debugPrint('currentRecordingPath가 null이거나 비어있음');
        }

        debugPrint('최종 조건 확인:');
        debugPrint('  - hasValidAudio: $hasValidAudio');
        debugPrint('  - 파형 데이터: ${_recordedWaveformData?.length ?? 0} samples');

        // ✅ 사용자 닉네임은 마지막에 처리 (필수가 아닌 경우)
        try {
          final String userNickName =
              await _authController.getIdFromFirestore();
          debugPrint('사용자 닉네임: $userNickName');
        } catch (e) {
          debugPrint('사용자 닉네임 가져오기 실패 (무시): $e');
        }

        debugPrint('업로드 실행 준비:');
        debugPrint('  - 이미지: $imagePath');
        debugPrint('  - 오디오: ${hasValidAudio ? audioPath : '없음'}');
        debugPrint('  - 파형 데이터: ${_recordedWaveformData?.length ?? 0} samples');

        // ✅ 업로드 조건 복원 - 실제 파형 데이터가 있을 때만 오디오와 함께 업로드
        if (hasValidAudio &&
            audioPath.isNotEmpty &&
            _recordedWaveformData != null &&
            _recordedWaveformData!.isNotEmpty) {
          // 오디오 파일과 실제 파형 데이터가 모두 있는 경우
          debugPrint(
            '오디오와 함께 업로드 (실제 파형 데이터: ${_recordedWaveformData!.length} samples)',
          );
          await _photoController.uploadPhotoWithAudio(
            imageFilePath: imagePath,
            audioFilePath: audioPath,
            userID: userId,
            userIds: [userId],
            categoryId: categoryId,
            waveformData: _recordedWaveformData,
          );
        } else {
          // 이미지만 업로드
          debugPrint('이미지만 업로드 (오디오 없음 또는 파형 데이터 없음)');
          debugPrint('  - hasValidAudio: $hasValidAudio');
          debugPrint('  - audioPath.isNotEmpty: ${audioPath.isNotEmpty}');
          debugPrint(
            '  - _recordedWaveformData != null: ${_recordedWaveformData != null}',
          );
          debugPrint(
            '  - _recordedWaveformData!.isNotEmpty: ${_recordedWaveformData?.isNotEmpty ?? false}',
          );

          await _photoController.uploadPhoto(
            imageFile: File(imagePath),
            categoryId: categoryId,
            userId: userId,
            userIds: [userId],
            audioFile: null,
          );
        }
      } else if (_useDownloadUrl && widget.downloadUrl != null) {
        debugPrint('다운로드 URL 업로드는 현재 지원되지 않습니다: ${widget.downloadUrl}');
        throw Exception('다운로드 URL 업로드는 지원되지 않습니다.');
      } else {
        debugPrint('업로드할 이미지가 없습니다.');
        throw Exception('업로드할 이미지가 없습니다.');
      }

      debugPrint('백그라운드 업로드 완료');
    } catch (e) {
      debugPrint('백그라운드 업로드 실행 오류: $e');
      rethrow; // 에러를 다시 던져서 catchError에서 처리
    }
  }

  // 카테고리 선택 처리 함수
  void _handleCategorySelection(String categoryId) {
    // 이미 선택된 카테고리를 다시 클릭했을 때 (전송 실행)
    if (_selectedCategoryId == categoryId) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => HomePageNavigationBar(currentPageIndex: 2),
          settings: RouteSettings(name: '/home'),
        ),
        (route) => false,
      );
      _savePhotoAndAudioToCategory(categoryId);
    } else {
      // 새로운 카테고리 선택 (선택 모드로 변경)
      setState(() {
        _selectedCategoryId = categoryId;
      });
    }
  }

  // 카테고리 생성 처리 함수
  Future<void> _createNewCategory(String categoryName) async {
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
      debugPrint('카테고리 생성 - Firebase Auth UID: $userId');

      if (userId == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('로그인이 필요합니다. 다시 로그인해주세요.')));
        return;
      }

      final String userNickName = await _authController.getIdFromFirestore();
      debugPrint('카테고리 생성 - 사용자 닉네임: $userNickName');

      // 메이트 리스트 준비 (여기서는 예시로 현재 사용자만 포함)
      // 중요: mates 필드에는 Firebase Auth UID를 사용해야 함
      List<String> mates = [userId]; // userNickName 대신 userId 사용
      debugPrint('카테고리 생성 - mates 리스트: $mates');

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
      debugPrint('카테고리 생성 중 오류: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('카테고리 생성 중 오류가 발생했습니다')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // 📱 개선된 반응형: MediaQuery.sizeOf() 사용
    final screenSize = MediaQuery.sizeOf(context);
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    // 📱 반응형: 기준 해상도 설정 (393 x 852 기준)
    const double baseWidth = 393;
    const double baseHeight = 852;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.white),
        title: Text(
          'SOI',
          style: TextStyle(
            color: AppTheme.lightTheme.colorScheme.secondary,
            fontSize: 20,
          ),
          textAlign: TextAlign.center,
        ),
        backgroundColor: AppTheme.lightTheme.colorScheme.surface,
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
                          // 이미지 표시 위젯
                          PhotoDisplayWidget(
                            imagePath: widget.imagePath,
                            downloadUrl: widget.downloadUrl,
                            useLocalImage: _useLocalImage,
                            useDownloadUrl: _useDownloadUrl,
                            width: 354 / baseWidth * screenWidth,
                            height: 500 / baseHeight * screenHeight,
                          ),
                          SizedBox(
                            height: (screenHeight * (19 / 852)),
                          ), // 개선된 반응형
                          // 오디오 녹음 위젯
                          AudioRecorderWidget(
                            onRecordingCompleted: (
                              String? audioPath,
                              List<double>? waveformData,
                            ) {
                              debugPrint('PhotoEditorScreen - 녹음 완료 콜백 호출됨');
                              debugPrint('  - audioPath: $audioPath');
                              debugPrint(
                                '  - waveformData null 여부: ${waveformData == null}',
                              );
                              debugPrint(
                                '  - waveformData 길이: ${waveformData?.length ?? 0}',
                              );

                              if (waveformData != null &&
                                  waveformData.isNotEmpty) {
                                debugPrint('실제 파형 데이터 수신');
                                debugPrint(
                                  '첫 5개 샘플: ${waveformData.take(5).toList()}',
                                );
                                debugPrint(
                                  '마지막 5개 샘플: ${waveformData.length > 5 ? waveformData.sublist(waveformData.length - 5) : waveformData}',
                                );
                                debugPrint(
                                  '데이터 범위: ${waveformData.reduce((a, b) => a < b ? a : b)} ~ ${waveformData.reduce((a, b) => a > b ? a : b)}',
                                );
                              } else {
                                debugPrint('파형 데이터 없음 또는 빈 데이터');
                              }

                              // 파형 데이터를 상태 변수에 저장
                              setState(() {
                                _recordedWaveformData = waveformData;
                              });

                              debugPrint('PhotoEditorScreen 상태 업데이트 완료');
                              debugPrint(
                                '  - _recordedWaveformData 길이: ${_recordedWaveformData?.length ?? 0}',
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
        initialChildSize: (screenHeight * 0.195 / screenHeight).clamp(
          0.15,
          0.25,
        ), // 반응형 초기 크기
        minChildSize: (screenHeight * 0.195 / screenHeight).clamp(
          0.15,
          0.25,
        ), // 반응형 최소 크기
        maxChildSize: (screenHeight * 0.8 / screenHeight).clamp(
          0.7,
          0.9,
        ), // 반응형 최대 크기
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Color(0xff171717),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(
                  (screenWidth * 0.041).clamp(12.0, 20.0),
                ), // 개선된 반응형
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 드래그 핸들
                Center(
                  child: Container(
                    height: (screenHeight * 0.006).clamp(4.0, 8.0), // 개선된 반응형
                    width: (screenWidth * 0.277).clamp(80.0, 120.0), // 개선된 반응형
                    margin: EdgeInsets.only(
                      top: (screenHeight * 0.009).clamp(6.0, 10.0), // 개선된 반응형
                      bottom: (screenHeight * 0.019).clamp(
                        12.0,
                        20.0,
                      ), // 개선된 반응형
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(
                        (screenWidth * 0.005).clamp(2.0, 4.0),
                      ), // 개선된 반응형
                    ),
                  ),
                ),

                // 헤더 영역: 카테고리 추가 UI를 표시할 때 필요한 헤더
                // (이제 AddCategoryWidget 내부에서 처리됨)

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
                                // 시트를 0.2 크기로 애니메이션
                                if (mounted) {
                                  // 위젯이 아직 살아있는지 확인
                                  Future.delayed(Duration(milliseconds: 50), () {
                                    if (mounted &&
                                        _draggableScrollController.isAttached) {
                                      try {
                                        _draggableScrollController.animateTo(
                                          0.25,
                                          duration: Duration(milliseconds: 10),
                                          curve: Curves.fastOutSlowIn,
                                        );
                                      } catch (e) {
                                        debugPrint(
                                          'DraggableScrollController animateTo 오류 (무시): $e',
                                        );
                                      }
                                    }
                                  });
                                }
                              },
                              onSavePressed:
                                  () => _createNewCategory(
                                    _categoryNameController.text.trim(),
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
                                // 시트를 0.7 크기로 애니메이션
                                if (mounted) {
                                  // 위젯이 아직 살아있는지 확인
                                  Future.delayed(Duration(milliseconds: 50), () {
                                    if (mounted &&
                                        _draggableScrollController.isAttached) {
                                      try {
                                        _draggableScrollController.animateTo(
                                          0.65,
                                          duration: Duration(milliseconds: 10),
                                          curve: Curves.fastOutSlowIn,
                                        );
                                      } catch (e) {
                                        debugPrint(
                                          'DraggableScrollController animateTo 오류 (무시): $e',
                                        );
                                      }
                                    }
                                  });
                                }
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
    );
  }

  @override
  void dispose() {
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (e) {
      debugPrint('WidgetsBinding observer 제거 오류 (무시): $e');
    }

    try {
      _categoryNameController.dispose();
    } catch (e) {
      debugPrint('CategoryNameController dispose 오류 (무시): $e');
    }

    try {
      if (_draggableScrollController.isAttached) {
        _draggableScrollController.dispose();
      }
    } catch (e) {
      debugPrint('DraggableScrollController dispose 오류 (무시): $e');
    }

    super.dispose();
  }
}
