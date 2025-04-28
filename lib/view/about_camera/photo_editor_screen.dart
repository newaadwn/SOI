import 'package:flutter/material.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import '../../theme/theme.dart';
import '../../view_model/audio_view_model.dart';
import '../../view_model/category_view_model.dart';
import '../../view_model/auth_view_model.dart';

// 분리된 위젯들을 임포트
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

class _PhotoEditorScreenState extends State<PhotoEditorScreen> {
  // 상태 변수
  bool _isLoading = true;
  String? _errorMessage;
  bool _useDownloadUrl = false;
  bool _useLocalImage = false;
  bool _loadingCategories = true;
  bool _showAddCategoryUI = false;
  String? _selectedCategoryId;
  bool _isSendMode = false;

  // 컨트롤러
  final _draggableScrollController = DraggableScrollableController();
  final _categoryNameController = TextEditingController();

  // ViewModel 인스턴스
  late AudioViewModel _audioViewModel;
  late CategoryViewModel _categoryViewModel;
  late AuthViewModel _authViewModel;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Provider에서 필요한 ViewModel들 가져오기
    _audioViewModel = Provider.of<AudioViewModel>(context, listen: false);
    _categoryViewModel = Provider.of<CategoryViewModel>(context, listen: false);
    _authViewModel = Provider.of<AuthViewModel>(context, listen: false);

    // 현재 로그인한 유저의 카테고리 로드
    _loadUserCategories();
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
  Future<void> _loadUserCategories() async {
    setState(() {
      _loadingCategories = true;
    });

    try {
      // 현재 로그인한 유저의 UID 가져오기
      final currentUser = _authViewModel.currentUser;
      if (currentUser != null) {
        // CategoryViewModel의 메서드 호출하여 카테고리 로드
        await _categoryViewModel.loadUserCategories(currentUser.uid);
        debugPrint('로드된 카테고리 수: ${_categoryViewModel.userCategories.length}');
      }
    } catch (e) {
      debugPrint('카테고리 로드 오류: $e');
    } finally {
      // 로딩 상태 업데이트 (위젯 다시 그리기)
      if (mounted) {
        setState(() {
          _loadingCategories = false;
        });
      }
    }
  }

  // 카테고리에 사진과 음성 업로드 함수
  Future<void> _savePhotoAndAudioToCategory(String categoryId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 현재 사용자 닉네임 가져오기
      final userNickName = await _authViewModel.getNickNameFromFirestore();
      String imagePath = '';

      // 로컬 이미지 경로나 다운로드 URL 중 하나 선택
      if (_useLocalImage && widget.imagePath != null) {
        imagePath = widget.imagePath!;
      } else if (_useDownloadUrl && widget.downloadUrl != null) {
        // 다운로드 URL을 사용하는 경우 그 URL을 사용
        // AudioViewModel을 사용하여 오디오 처리
        final String audioUrl = await _audioViewModel.processAudioForUpload();

        await _categoryViewModel.uploadPhoto(
          categoryId,
          userNickName,
          "", // 로컬 파일 경로는 없음
          audioUrl, // 오디오가 있을 때만 업로드
          imageUrl: widget.downloadUrl, // 이미 있는 URL 사용
        );

        // 성공 메시지 표시
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${audioUrl.isNotEmpty ? "사진과 음성이" : "사진이"} 업로드되었습니다',
              ),
            ),
          );
        }

        // 상태 초기화하고 함수 종료
        setState(() {
          _isLoading = false;
          _isSendMode = false;
          _selectedCategoryId = null;
        });
        return;
      }

      // 로컬 이미지가 있는 경우에만 계속 진행
      if (imagePath.isNotEmpty) {
        // AudioViewModel을 사용하여 오디오 처리
        final String audioUrl = await _audioViewModel.processAudioForUpload();

        // 카테고리에 업로드
        await _categoryViewModel.uploadPhoto(
          categoryId,
          userNickName,
          imagePath,
          audioUrl,
        );

        // 성공 메시지 표시
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${audioUrl.isNotEmpty ? "사진과 음성이" : "사진이"} 업로드되었습니다',
              ),
            ),
          );
        }
      } else {
        // 이미지 경로가 비어있는 경우
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('업로드할 이미지가 없습니다')));
        }
      }
    } catch (e) {
      debugPrint('사진 및 음성 업로드 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('업로드 중 오류가 발생했습니다: $e')));
      }
    } finally {
      // 상태 초기화
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSendMode = false;
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
        _isSendMode = true;
      });
    }
  }

  // 카테고리 생성 처리 함수
  Future<void> _createNewCategory() async {
    // 카테고리 이름 검증
    if (_categoryNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('카테고리 이름을 입력해주세요')));
      return;
    }

    // 카테고리 저장 로직 호출
    try {
      // 현재 사용자 정보 가져오기
      final String? userId = _authViewModel.getUserId;
      final String userNickName =
          await _authViewModel.getNickNameFromFirestore();

      // 메이트 리스트 준비 (여기서는 예시로 현재 사용자만 포함)
      List<String> mates = [userNickName];

      // 카테고리 생성
      await _categoryViewModel.createCategory(
        _categoryNameController.text.trim(),
        mates,
        userId!,
      );

      // 화면 갱신
      _loadUserCategories();

      // 원래 화면으로 돌아가기
      setState(() {
        _showAddCategoryUI = false;
        _categoryNameController.clear();
      });

      // 성공 메시지
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('카테고리가 생성되었습니다')));
    } catch (e) {
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
      appBar: AppBar(
        title: Text(
          'SOI',
          style: TextStyle(color: AppTheme.lightTheme.colorScheme.secondary),
        ),
        backgroundColor: AppTheme.lightTheme.colorScheme.surface,
        toolbarHeight: 70 / 852 * screenHeight,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: 20 / 852 * screenHeight),
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
                        mainAxisSize: MainAxisSize.min,
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
                            onRecordingCompleted: null, // AudioViewModel에서 처리
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
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Color(0xff4f4f4f),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black26)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 드래그 핸들
                Center(
                  child: Container(
                    height: 4,
                    width: 40,
                    margin: const EdgeInsets.only(top: 8, bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // 헤더 영역: 카테고리 추가 UI를 표시할 때 필요한 헤더
                if (_showAddCategoryUI)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                      // 확인 버튼
                      ElevatedButton(
                        onPressed: _createNewCategory,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xff323232),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: SizedBox(
                          child: Text(
                            '저장',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                SizedBox(height: 12),

                // 콘텐츠 영역: 조건에 따라 카테고리 목록 또는 카테고리 추가 UI 표시
                Expanded(
                  child: AnimatedSwitcher(
                    duration: Duration(milliseconds: 300),
                    child:
                        _showAddCategoryUI
                            ? AddCategoryWidget(
                              textController: _categoryNameController,
                              scrollController: scrollController,
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
                              isLoading: _loadingCategories,
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
    _categoryNameController.dispose();
    super.dispose();
  }
}
