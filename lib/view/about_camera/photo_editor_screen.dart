import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io'; // File 클래스를 사용하기 위한 import 추가
import 'package:path_provider/path_provider.dart'; // getTemporaryDirectory 사용을 위한 import 추가
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Firebase Auth 추가
import '../../theme/theme.dart';
import '../../view_model/audio_view_model.dart'; // AudioViewModel import
import '../../view_model/category_view_model.dart'; // CategoryViewModel import 추가
import '../../view_model/auth_view_model.dart'; // AuthViewModel 추가
import 'dart:async'; // StreamSubscription을 사용하기 위한 import 추가
import 'package:audio_waveforms/audio_waveforms.dart'; // audio_waveforms 패키지 추가

class PhotoEditorScreen extends StatefulWidget {
  final String? downloadUrl;
  final String? imagePath; // 로컬 이미지 경로 추가

  const PhotoEditorScreen({super.key, this.downloadUrl, this.imagePath});

  @override
  State<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _PhotoEditorScreenState extends State<PhotoEditorScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  bool _useDownloadUrl = false;
  bool _useLocalImage = false; // 로컬 이미지 사용 여부 추가

  // 오디오 녹음 관련 변수
  late AudioViewModel _audioViewModel;
  late CategoryViewModel _categoryViewModel; // CategoryViewModel 추가
  late AuthViewModel _authViewModel; // AuthViewModel 추가
  bool _isRecording = false;
  // RecorderController for audio_waveforms
  late RecorderController recorderController;
  String? recordedFilePath; // 녹음된 파일 경로 저장

  // 커스텀 파형을 위한 변수
  // (파형은 AudioWaveforms 위젯이 관리합니다)
  //late DateTime _lastUpdateTime;

  // 카테고리 로딩 상태
  bool _loadingCategories = true;

  final controller = DraggableScrollableController();

  // PhotoEditorScreen 클래스에 상태 변수 추가
  bool _showAddCategoryUI = false; // 카테고리 추가 UI 표시 여부
  TextEditingController _categoryNameController =
      TextEditingController(); // 카테고리 이름 입력용

  // 선택된 카테고리 ID와 전송 모드 상태 추적 변수 추가
  String? _selectedCategoryId;
  bool _isSendMode = false;

  @override
  void initState() {
    super.initState();
    // audio_waveforms 설정
    recorderController =
        RecorderController()
          ..androidEncoder = AndroidEncoder.aac
          ..androidOutputFormat = AndroidOutputFormat.mpeg4
          ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC
          ..sampleRate = 44100;
    recorderController.checkPermission();
    _loadImage();
    // _lastUpdateTime = DateTime.now();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Provider에서 필요한 ViewModel들 가져오기
    _audioViewModel = Provider.of<AudioViewModel>(context, listen: false);
    _categoryViewModel = Provider.of<CategoryViewModel>(context, listen: false);
    _authViewModel = Provider.of<AuthViewModel>(context, listen: false);

    // 현재 로그인한 유저의 카테고리 로드 - 추가된 부분
    _loadUserCategories();
  }

  // 사용자 카테고리 로드 메서드 - 개선
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

        // 디버그: 로드된 카테고리 확인
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

  // 녹음 시작 함수
  Future<void> _startRecording() async {
    try {
      // audio_waveforms 플러그인 녹음 시작 (파형 캡처)
      await recorderController.record();
      // AudioViewModel의 녹음 시작 함수 사용
      await _audioViewModel.startRecording();
      setState(() => _isRecording = true);
    } catch (e) {
      debugPrint('녹음 시작 오류: $e');
    }
  }

  // 녹음 중지 함수
  Future<void> _stopRecording() async {
    try {
      // audio_waveforms 플러그인 녹음 중지
      await recorderController.stop();
      // AudioViewModel의 녹음 중지 함수 사용
      await _audioViewModel.stopRecording();
      setState(() => _isRecording = false);
      // AudioViewModel에서 가져온 파일 경로 저장
      recordedFilePath = _audioViewModel.audioFilePath;
      // AudioViewModel을 사용해 업로드 (선택적)
      if (recordedFilePath != null) {
        await _audioViewModel.uploadAudioToFirestorage();
      }
    } catch (e) {
      debugPrint('녹음 중지 오류: $e');
    }
  }

  // 카테고리에 사진과 음성 업로드 함수 추가
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
        // Firebase Storage에서 이미 사용 가능한 URL이므로 다시 저장하지 않고 그대로 사용
        await _categoryViewModel.uploadPhoto(
          categoryId,
          userNickName,
          "", // 로컬 파일 경로는 없음
          recordedFilePath != null
              ? await _audioViewModel.uploadAudioToFirestorage()
              : "", // 오디오가 있을 때만 업로드
          '', // 캡션 문자열
          imageUrl: widget.downloadUrl, // 이미 있는 URL 사용
        );

        // 성공 메시지 표시
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${recordedFilePath != null ? "사진과 음성이" : "사진이"} 업로드되었습니다',
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
        // 오디오 URL 가져오기
        String audioUrl = '';

        // 녹음된 오디오가 있을 경우에만 업로드 시도
        if (recordedFilePath != null) {
          try {
            audioUrl = await _audioViewModel.uploadAudioToFirestorage();
          } catch (e) {
            debugPrint('오디오 업로드 오류: $e');
            // 오디오 업로드 실패해도 사진은 계속 업로드
          }
        }

        // 카테고리에 업로드
        await _categoryViewModel.uploadPhoto(
          categoryId,
          userNickName,
          imagePath,
          audioUrl,
          '', // 캡션 문자열 (필요시 추가)
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
                          Container(
                            width: 354 / 393 * screenWidth,
                            height: 471 / 852 * screenHeight,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: _buildImageWidget(),
                            ),
                          ),
                          SizedBox(height: 40 / 852 * screenHeight),
                          // Record UI
                          GestureDetector(
                            onTap: _isRecording ? null : _startRecording,
                            child: Container(
                              height: 64,
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade900,
                                borderRadius: BorderRadius.circular(32),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_isRecording)
                                    GestureDetector(
                                      onTap: _stopRecording,
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade800,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.delete,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  if (_isRecording)
                                    SizedBox(width: 12 / 393 * screenWidth),
                                  _isRecording
                                      ? AudioWaveforms(
                                        size: Size(
                                          160 / 393 * screenWidth,
                                          50 / 852 * screenHeight,
                                        ),
                                        recorderController: recorderController,
                                        waveStyle: const WaveStyle(
                                          waveColor: Colors.white,
                                          extendWaveform: true,
                                          showMiddleLine: false,
                                        ),
                                      )
                                      : Icon(
                                        Icons.mic,
                                        color: Colors.white,
                                        size: 32 / 393 * screenWidth,
                                      ),
                                  if (_isRecording)
                                    SizedBox(width: 12 / 393 * screenWidth),
                                  if (_isRecording)
                                    Consumer<AudioViewModel>(
                                      builder:
                                          (context, vm, child) => Text(
                                            vm.formattedRecordingDuration,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14 / 393 * screenWidth,
                                            ),
                                          ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
            ),
          ],
        ),
      ),
      bottomSheet: DraggableScrollableSheet(
        controller: controller,
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

                // 헤더 영역: 제목과 닫기/뒤로가기 버튼
                if (_showAddCategoryUI)
                  // 뒤로가기 버튼을 더 크고 눈에 띄게 만들기
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios, color: Colors.white),
                        onPressed: () {
                          // 뒤로가기 기능
                          debugPrint("뒤로가기 클릭됨");
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
                        onPressed: () async {
                          // 카테고리 이름 검증
                          if (_categoryNameController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('카테고리 이름을 입력해주세요')),
                            );
                            return;
                          }

                          // 카테고리 저장 로직 호출
                          try {
                            final authViewModel = Provider.of<AuthViewModel>(
                              context,
                              listen: false,
                            );
                            final categoryViewModel =
                                Provider.of<CategoryViewModel>(
                                  context,
                                  listen: false,
                                );

                            // 현재 사용자 정보 가져오기
                            final String? userId = authViewModel.getUserId;
                            final String userNickName =
                                await authViewModel.getNickNameFromFirestore();

                            // 메이트 리스트 준비 (여기서는 예시로 현재 사용자만 포함)
                            List<String> mates = [userNickName];

                            // 카테고리 생성
                            await categoryViewModel.createCategory(
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
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('카테고리가 생성되었습니다')),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('카테고리 생성 중 오류가 발생했습니다')),
                            );
                          }
                        },
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
                            ? _buildAddCategoryUI(scrollController)
                            : _buildCategoryListUI(scrollController),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 이미지 위젯을 결정하는 메소드 추가
  Widget _buildImageWidget() {
    // 로컬 이미지를 우선적으로 사용
    if (_useLocalImage) {
      return Image.file(
        File(widget.imagePath!),
        width: 354,
        height: 471,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(Icons.error, color: Colors.white);
        },
      );
    }
    // Firebase 다운로드 URL 사용
    else if (_useDownloadUrl) {
      return CachedNetworkImage(
        imageUrl: widget.downloadUrl!,
        width: 354,
        height: 471,
        fit: BoxFit.cover,
        placeholder:
            (context, url) => const Center(child: CircularProgressIndicator()),
        errorWidget:
            (context, url, error) =>
                const Icon(Icons.error, color: Colors.white),
      );
    }
    // 둘 다 없는 경우 에러 메시지 표시
    else {
      return const Center(
        child: Text("이미지를 불러올 수 없습니다.", style: TextStyle(color: Colors.white)),
      );
    }
  }

  // 카테고리 아이템 위젯
  Widget _buildCategoryItem({
    String? imageUrl,
    IconData? icon,
    required String label,
    required VoidCallback onTap,
    String? categoryId, // 카테고리 ID 파라미터 추가
  }) {
    // 선택된 카테고리인지 확인 (전송 모드)
    final bool isSelected =
        categoryId != null && categoryId == _selectedCategoryId;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 이미지 또는 아이콘 원형 컨테이너
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: icon != null ? Colors.grey.shade200 : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.blue : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: ClipOval(
                child:
                    isSelected
                        ? Icon(Icons.send, size: 30, color: Colors.blue)
                        : icon != null
                        ? Icon(icon, size: 30, color: Colors.grey.shade700)
                        : (imageUrl != null && imageUrl.isNotEmpty)
                        ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder:
                              (context, url) => Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                          errorWidget:
                              (context, url, error) => Icon(
                                Icons.image,
                                size: 30,
                                color: Colors.grey.shade400,
                              ),
                        )
                        : Icon(
                          Icons.image,
                          size: 30,
                          color: Colors.grey.shade400,
                        ),
              ),
            ),
            const SizedBox(height: 8),
            // 카테고리 이름
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.blue : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 카테고리 목록 UI 위젯
  Widget _buildCategoryListUI(ScrollController scrollController) {
    return _loadingCategories
        ? Center(child: CircularProgressIndicator())
        : Consumer<CategoryViewModel>(
          builder: (context, viewModel, child) {
            final categories = viewModel.userCategories;

            return GridView.builder(
              key: ValueKey('category_list'),
              controller: scrollController,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 0.8,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              padding: const EdgeInsets.all(16),
              itemCount: categories.isEmpty ? 1 : categories.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildCategoryItem(
                    icon: Icons.add,
                    label: '추가하기',
                    onTap: () {
                      // 상태 변경으로 카테고리 추가 UI 표시
                      setState(() {
                        _showAddCategoryUI = true;
                      });
                    },
                  );
                } else if (categories.isEmpty) {
                  return Center(
                    child: Text(
                      '카테고리가 없습니다.\n추가해 보세요!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  );
                } else {
                  final category = categories[index - 1];
                  final categoryId = category['id'];

                  return StreamBuilder<String?>(
                    stream: viewModel.getFirstPhotoUrlStream(categoryId),
                    builder: (context, asyncSnapshot) {
                      return _buildCategoryItem(
                        imageUrl: asyncSnapshot.data,
                        label: category['name'],
                        categoryId: categoryId, // 카테고리 ID 전달
                        onTap: () {
                          // 카테고리 클릭 처리
                          if (_selectedCategoryId == categoryId) {
                            // 이미 선택된 카테고리를 다시 클릭했을 때 (전송 실행)
                            _savePhotoAndAudioToCategory(categoryId);
                          } else {
                            // 새로운 카테고리 선택 (선택 모드로 변경)
                            setState(() {
                              _selectedCategoryId = categoryId;
                              _isSendMode = true;
                            });
                            debugPrint('선택된 카테고리: ${category['name']} (전송 모드)');
                          }
                        },
                      );
                    },
                  );
                }
              },
            );
          },
        );
  }

  // 카테고리 추가 UI 위젯
  Widget _buildAddCategoryUI(ScrollController scrollController) {
    return SingleChildScrollView(
      key: ValueKey('add_category'),
      controller: scrollController,
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 카테고리 이름 입력 필드
          TextField(
            controller: _categoryNameController,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey.shade100,
              hintText: '카테고리 이름 입력',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          SizedBox(height: 20),

          // 선택된 메이트 보여주기 영역 (필요시 구현)
        ],
      ),
    );
  }

  @override
  void dispose() {
    _categoryNameController.dispose();
    recorderController.dispose();
    super.dispose();
  }
}
