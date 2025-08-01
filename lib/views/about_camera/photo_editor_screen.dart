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

  // 프로필 이미지 위치 관리 (피드와 동일한 방식)
  Offset? _profileImagePosition;

  // 컨트롤러
  final _draggableScrollController = DraggableScrollableController();
  final _categoryNameController = TextEditingController();
  bool _isDisposing = false; // dispose 상태 추적

  // 진행 중인 애니메이션들을 추적
  final List<Future<void>> _activeAnimations = [];

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
    LoadingPopupWidget.show(context, message: '사진을 업로드하고 있습니다\n잠시만 기다려주세요');

    try {
      // 1. 데이터 추출 (동기적)
      final uploadData = _extractUploadData(categoryId);
      if (uploadData == null) {
        debugPrint('❌ 업로드 데이터가 없어 화면 전환만 실행');
        // 로딩 팝업 닫기
        LoadingPopupWidget.hide(context);
        _navigateToHome();
        return;
      }

      debugPrint('📤 업로드 시작 - categoryId: $categoryId');

      // 2. 업로드 실행 (완료될 때까지 대기)
      await _executeUploadWithExtractedData(uploadData);

      debugPrint('✅ 업로드 완료 - 화면 전환 시작');

      // 로딩 팝업 닫기
      LoadingPopupWidget.hide(context);

      // 3. 업로드 완료 후 화면 전환
      if (mounted) {
        _navigateToHome();
      }
    } catch (e) {
      debugPrint('❌ 업로드 오류: $e');

      // 로딩 팝업 닫기
      LoadingPopupWidget.hide(context);

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
    final audioPath = _audioController.currentRecordingPath;
    final waveformData = _recordedWaveformData;

    // 필수 데이터 검증
    if (imagePath == null || userId == null) {
      debugPrint('❌ 업로드 데이터 추출 실패 - imagePath: $imagePath, userId: $userId');
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

  // 추출된 데이터로 업로드 실행
  Future<void> _executeUploadWithExtractedData(
    Map<String, dynamic> data,
  ) async {
    final categoryId = data['categoryId'] as String;
    final imagePath = data['imagePath'] as String;
    final userId = data['userId'] as String;
    final audioPath = data['audioPath'] as String?;
    final waveformData = data['waveformData'] as List<double>?;

    // 파일 존재 여부 확인
    final imageFile = File(imagePath);
    if (!await imageFile.exists()) {
      throw Exception('이미지 파일을 찾을 수 없습니다: $imagePath');
    }

    // 오디오 파일 확인
    File? audioFile;
    if (audioPath != null && audioPath.isNotEmpty) {
      audioFile = File(audioPath);
      if (!await audioFile.exists()) {
        debugPrint('⚠️ 오디오 파일 없음, 이미지만 업로드: $audioPath');
        audioFile = null;
      }
    }

    // 업로드 실행
    if (audioFile != null && waveformData != null && waveformData.isNotEmpty) {
      // 오디오와 함께 업로드
      await _photoController.uploadPhotoWithAudio(
        imageFilePath: imagePath,
        audioFilePath: audioFile.path,
        userID: userId,
        userIds: [userId],
        categoryId: categoryId,
        waveformData: waveformData,
      );
      debugPrint('📤 오디오와 함께 업로드 완료');
    } else {
      // 이미지만 업로드
      await _photoController.uploadPhoto(
        imageFile: imageFile,
        categoryId: categoryId,
        userId: userId,
        userIds: [userId],
        audioFile: null,
      );
      debugPrint('📤 이미지만 업로드 완료');
    }
  }

  // 화면 전환 메서드 (분리)
  void _navigateToHome() {
    // 기존 HomePageNavigationBar를 찾아서 돌아가기
    Navigator.of(context).popUntil((route) {
      return route.settings.name == '/home' || route.isFirst;
    });

    // 만약 HomePageNavigationBar가 스택에 없다면 새로 생성 (fallback)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final currentRoute = ModalRoute.of(context);
        if (currentRoute?.settings.name != '/home') {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => HomePageNavigationBar(currentPageIndex: 2),
              settings: RouteSettings(name: '/home'),
            ),
            (route) => false,
          );
        }
      }
    });
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
      // 카테고리 생성 - Firebase Auth UID 확인

      if (userId == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('로그인이 필요합니다. 다시 로그인해주세요.')));
        return;
      }

      // 메이트 리스트 준비 (현재 사용자만 포함)
      // 중요: mates 필드에는 Firebase Auth UID를 사용해야 함
      List<String> mates = [userId];
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

  @override
  Widget build(BuildContext context) {
    // 개선된 반응형: MediaQuery.sizeOf() 사용
    final screenSize = MediaQuery.sizeOf(context);
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    // 반응형: 기준 해상도 설정 (393 x 852 기준)
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
                          // 이미지 표시 위젯을 DragTarget으로 감싸기 (피드와 동일한 방식)
                          DragTarget<String>(
                            onAcceptWithDetails: (details) async {
                              // 드롭된 좌표를 사진 내 상대 좌표로 변환 (피드와 동일한 로직)
                              final RenderBox renderBox =
                                  context.findRenderObject() as RenderBox;
                              final localPosition = renderBox.globalToLocal(
                                details.offset,
                              );

                              // 프로필 이미지가 사진 영역에 드롭됨

                              // 사진 영역 내 좌표로 저장
                              setState(() {
                                _profileImagePosition = localPosition;
                              });

                              // 프로필 위치가 저장됨
                            },
                            builder: (context, candidateData, rejectedData) {
                              return PhotoDisplayWidget(
                                imagePath: widget.imagePath,
                                downloadUrl: widget.downloadUrl,
                                useLocalImage: _useLocalImage,
                                useDownloadUrl: _useDownloadUrl,
                                width: 354 / baseWidth * screenWidth,
                                height: 500 / baseHeight * screenHeight,
                              );
                            },
                          ),
                          SizedBox(
                            height: (screenHeight * (19 / 852)),
                          ), // 개선된 반응형
                          // 오디오 녹음 위젯
                          AudioRecorderWidget(
                            photoId:
                                widget.imagePath?.split('/').last ?? 'unknown',
                            isCommentMode:
                                false, // 사진 편집 모드: CommentRecord로 저장하지 않음
                            profileImagePosition:
                                _profileImagePosition, // 현재 저장된 위치 전달
                            getProfileImagePosition:
                                () => _profileImagePosition, // 최신 위치를 가져오는 콜백
                            onRecordingCompleted: (
                              String? audioPath,
                              List<double>? waveformData,
                            ) {
                              // 파형 데이터를 상태 변수에 저장
                              setState(() {
                                _recordedWaveformData = waveformData;
                              });
                            },
                            onProfileImageDragged: (Offset position) {
                              // 피드와 동일한 방식: 이미 DragTarget에서 처리하므로 여기서는 로깅만
                              // 드래그 이벤트 수신됨
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
                                // 시트를 0.195크기(초기 크기)로 애니메이션
                                if (mounted) {
                                  // 위젯이 아직 살아있는지 확인
                                  Future.delayed(
                                    Duration(milliseconds: 50),
                                    () {
                                      if (mounted &&
                                          !_isDisposing &&
                                          _draggableScrollController
                                              .isAttached) {
                                        try {
                                          final animation =
                                              _draggableScrollController
                                                  .animateTo(
                                                    0.195,
                                                    duration: Duration(
                                                      milliseconds: 10,
                                                    ),
                                                    curve: Curves.fastOutSlowIn,
                                                  );
                                          _activeAnimations.add(animation);
                                          animation.whenComplete(() {
                                            _activeAnimations.remove(animation);
                                          });
                                        } catch (e) {
                                          return;
                                        }
                                      }
                                    },
                                  );
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
                                  Future.delayed(
                                    Duration(milliseconds: 50),
                                    () {
                                      if (mounted &&
                                          !_isDisposing &&
                                          _draggableScrollController
                                              .isAttached) {
                                        try {
                                          final animation =
                                              _draggableScrollController
                                                  .animateTo(
                                                    0.65,
                                                    duration: Duration(
                                                      milliseconds: 10,
                                                    ),
                                                    curve: Curves.fastOutSlowIn,
                                                  );
                                          _activeAnimations.add(animation);
                                          animation.whenComplete(() {
                                            _activeAnimations.remove(animation);
                                          });
                                        } catch (e) {
                                          return;
                                        }
                                      }
                                    },
                                  );
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
    _isDisposing = true; // dispose 시작 플래그 설정

    // 진행 중인 애니메이션들을 모두 정리
    try {
      _activeAnimations.clear(); // Future는 취소할 수 없으므로 리스트만 클리어
    } catch (e) {
      // 애니메이션 정리 오류 무시
    }

    // DraggableScrollController를 dispose
    try {
      if (_draggableScrollController.isAttached) {
        _draggableScrollController.dispose();
      }
    } catch (e) {
      // DraggableScrollController dispose 오류 무시
    }

    // 다른 리소스들 정리
    try {
      _categoryNameController.dispose();
    } catch (e) {
      // CategoryNameController dispose 오류 무시
    }

    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (e) {
      // WidgetsBinding observer 제거 오류 무시
    }

    super.dispose();
  }
}
