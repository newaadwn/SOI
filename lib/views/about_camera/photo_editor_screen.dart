import 'package:flutter/material.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import '../../controllers/audio_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/category_controller.dart';
import '../../controllers/photo_controller.dart';

// 분리된 위젯들을 임포트
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

    setState(() {
      _isLoading = true; // 로딩 시작
    });

    try {
      // 현재 로그인한 유저의 UID 가져오기
      final currentUser = _authController.currentUser;
      if (currentUser != null) {
        debugPrint('현재 사용자 UID: ${currentUser.uid}');
        debugPrint('현재 사용자 전화번호: ${currentUser.phoneNumber}');

        // 사용자 닉네임도 확인
        try {
          final userNickName = await _authController.getIdFromFirestore();
          debugPrint('현재 사용자 닉네임: $userNickName');
        } catch (e) {
          debugPrint('사용자 닉네임 가져오기 실패: $e');
        }

        // CategoryController의 메서드 호출하여 카테고리 로드
        await _categoryController.loadUserCategories(
          currentUser.uid,
          forceReload: forceReload,
        );
        _categoriesLoaded = true; // 로드 완료 표시
        debugPrint('로드된 카테고리 수: ${_categoryController.userCategories.length}');

        // 카테고리 목록 상세 정보 출력
        for (int i = 0; i < _categoryController.userCategories.length; i++) {
          final category = _categoryController.userCategories[i];
          debugPrint(
            '카테고리 $i: ID=${category.id}, 이름=${category.name}, 멤버=${category.mates}',
          );
        }
      } else {
        debugPrint('현재 로그인한 사용자가 없습니다.');
      }
    } catch (e) {
      debugPrint('카테고리 로드 오류: $e');
    } finally {
      // 로딩 완료 처리 (성공 여부와 상관없이)
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 카테고리에 사진과 음성 업로드 함수
  Future<void> _savePhotoAndAudioToCategory(String categoryId) async {
    debugPrint('사진 업로드 시작: categoryId=$categoryId');

    setState(() {
      _isLoading = true;
    });

    try {
      // 현재 사용자 닉네임 가져오기
      final userNickName = await _authController.getIdFromFirestore();
      debugPrint('사용자 닉네임: $userNickName');

      String imagePath = '';
      bool uploadSuccess = false;

      // 로컬 이미지 경로나 다운로드 URL 중 하나 선택
      if (_useLocalImage && widget.imagePath != null) {
        debugPrint('로컬 이미지 업로드 시도: ${widget.imagePath}');
        imagePath = widget.imagePath!;

        // AudioController를 사용하여 오디오 처리
        final String audioPath = await _audioController.processAudioForUpload();
        debugPrint('오디오 경로: $audioPath');

        // Firebase Auth에서 UID 가져오기
        final String? userId = _authController.getUserId;

        if (userId == null) {
          debugPrint('사용자 ID가 없습니다.');
          throw Exception('사용자 ID가 없습니다. 로그인이 필요합니다.');
        }

        debugPrint('사용자 UID: $userId');

        // PhotoController를 사용하여 사진 업로드 (Firebase UID 사용)
        uploadSuccess = await _photoController.uploadPhoto(
          imageFile: File(imagePath),
          categoryId: categoryId,
          userId: userId, // userNickName 대신 Firebase Auth UID 사용
          userIds: [userId], // userNickName 대신 Firebase Auth UID 사용
          audioFile: audioPath.isNotEmpty ? File(audioPath) : null,
        );

        debugPrint('로컬 이미지 업로드 결과: $uploadSuccess');
      } else if (_useDownloadUrl && widget.downloadUrl != null) {
        debugPrint('다운로드 URL 업로드는 현재 지원되지 않습니다: ${widget.downloadUrl}');
        // TODO: downloadUrl의 경우 URL에서 이미지를 다운로드한 후 업로드해야 함
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('URL 이미지는 현재 지원되지 않습니다.')));
        return;
      } else {
        debugPrint('업로드할 이미지가 없습니다.');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('업로드할 이미지가 없습니다.')));
        return;
      }

      // 업로드 성공 시 처리
      if (uploadSuccess) {
        debugPrint('업로드 성공!');

        // 성공 메시지 표시
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('사진이 업로드되었습니다'),
              backgroundColor: Colors.green,
            ),
          );
        }

        // 잠시 대기 후 화면 이동
        await Future.delayed(Duration(milliseconds: 500));

        // 홈 화면으로 이동
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => HomePageNavigationBar(currentPageIndex: 2),
            ),
          );
        }
      } else {
        debugPrint('업로드 실패');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('업로드에 실패했습니다.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('사진 및 음성 업로드 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('업로드 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // 상태 초기화
      if (mounted) {
        setState(() {
          _isLoading = false;
          _selectedCategoryId = null;
        });
      }
    }
  }

  // 카테고리 선택 처리 함수
  void _handleCategorySelection(String categoryId) {
    // 이미 선택된 카테고리를 다시 클릭했을 때 (전송 실행)
    if (_selectedCategoryId == categoryId) {
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
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false, // 키보드가 올라올 때 UI가 밀리지 않도록 설정
      /* appBar: AppBar(
        title: Text(
          'SOI',
          style: TextStyle(color: AppTheme.lightTheme.colorScheme.secondary),
        ),
        backgroundColor: AppTheme.lightTheme.colorScheme.surface,
        toolbarHeight: 70 / 852 * screenHeight,
      ),*/
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Main content
            SizedBox(height: 70 / 852 * screenHeight), // 상단 여백
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
                            width: 354 / 393 * screenWidth,
                            height: 471 / 852 * screenHeight,
                          ),
                          SizedBox(height: 20 / 852 * screenHeight),
                          // 오디오 녹음 위젯
                          AudioRecorderWidget(
                            onRecordingCompleted: null, // AudioController에서 처리
                          ),
                        ],
                      ),
            ),
          ],
        ),
      ),
      bottomSheet: DraggableScrollableSheet(
        controller: _draggableScrollController,
        initialChildSize: 0.2,
        minChildSize: 0.2,
        // maxChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Color(0xff171717),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 드래그 핸들
                Center(
                  child: Container(
                    height: 5 / 852 * screenHeight,
                    width: 109 / 393 * screenWidth,
                    margin: const EdgeInsets.only(top: 8, bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // 헤더 영역: 카테고리 추가 UI를 표시할 때 필요한 헤더
                if (_showAddCategoryUI)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back_ios, color: Colors.white),
                          onPressed: () {
                            // 뒤로가기 기능
                            setState(() {
                              _showAddCategoryUI = false;
                              _categoryNameController.clear();
                            });
                          },
                        ),
                        Text(
                          '새 카테고리 만들기',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        ElevatedButton(
                          onPressed:
                              () => _createNewCategory(
                                _categoryNameController.text.trim(),
                              ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xff323232),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.5),
                            ),
                            elevation: 0,
                            padding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ), // 패딩 조정
                          ),
                          child: Text(
                            '저장',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_showAddCategoryUI) Divider(color: Color(0xff3d3d3d)),
                SizedBox(height: 12),

                // 콘텐츠 영역: 조건에 따라 카테고리 목록 또는 카테고리 추가 UI 표시
                Expanded(
                  child: AnimatedSwitcher(
                    duration: Duration(milliseconds: 300),
                    child:
                        _showAddCategoryUI
                            ? Padding(
                              // AddCategoryWidget을 Padding으로 감싸서 정렬
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                              child: AddCategoryWidget(
                                textController: _categoryNameController,
                                scrollController: scrollController,
                              ),
                            )
                            : CategoryListWidget(
                              scrollController: scrollController,
                              selectedCategoryId: _selectedCategoryId,
                              onCategorySelected: _handleCategorySelection,
                              onAddCategoryPressed: () {
                                setState(() {
                                  _showAddCategoryUI = true;
                                });
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
    WidgetsBinding.instance.removeObserver(this);
    _categoryNameController.dispose();
    _draggableScrollController.dispose();
    super.dispose();
  }
}
