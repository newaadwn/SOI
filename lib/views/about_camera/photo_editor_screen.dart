import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../controllers/audio_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/category_controller.dart';
import '../../controllers/photo_controller.dart';
import '../../models/selected_friend_model.dart';
import '../home_navigator_screen.dart';
import 'widgets/add_category_widget.dart';
import 'widgets/audio_recorder_widget.dart';
import 'widgets/category_list_widget.dart';
import 'widgets/loading_popup_widget.dart';
import 'widgets/photo_display_widget.dart';

class PhotoEditorScreen extends StatefulWidget {
  final String? downloadUrl;
  final String? imagePath;
  const PhotoEditorScreen({super.key, this.downloadUrl, this.imagePath});
  @override
  State<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _PhotoEditorScreenState extends State<PhotoEditorScreen>
    with WidgetsBindingObserver {
  // ========== 상태 관리 변수들 ==========
  bool _isLoading = true;
  String? _errorMessage;
  bool _useDownloadUrl = false;
  bool _useLocalImage = false;
  bool _showAddCategoryUI = false;
  String? _selectedCategoryId;
  bool _categoriesLoaded = false;
  bool _shouldAutoOpenCategorySheet = true;
  bool _isDisposing = false;
  static const double _kInitialSheetExtent = 0.0;
  static const double _kLockedSheetExtent = 0.19;
  static const double _kMaxSheetExtent = 0.8;
  double _minChildSize = _kInitialSheetExtent;
  double _initialChildSize = _kInitialSheetExtent;
  bool _hasLockedSheetExtent = false;
  // 오디오 관련 변수들
  List<double>? _recordedWaveformData;
  String? _recordedAudioPath;
  bool _isRecorderVisible = false;
  bool _shouldAutoStartRecording = false;
  bool _isCaptionEmpty = true;
  // 컨트롤러들
  final _draggableScrollController = DraggableScrollableController();
  final _categoryNameController = TextEditingController();
  final TextEditingController _captionController = TextEditingController();
  late AudioController _audioController;
  late CategoryController _categoryController;
  late AuthController _authController;
  late PhotoController _photoController;
  // ========== 생명주기 메서드들 ==========
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeScreen();
    _captionController.addListener(_handleCaptionChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeControllers();
    _loadCategoriesIfNeeded();
  }

  @override
  void didUpdateWidget(PhotoEditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _handleWidgetUpdate(oldWidget);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _handleAppStateChange(state);
  }

  // ========== 초기화 메서드들 ==========
  void _initializeScreen() {
    _loadImage();
  }

  void _initializeControllers() {
    _audioController = Provider.of<AudioController>(context, listen: false);
    _categoryController = Provider.of<CategoryController>(
      context,
      listen: false,
    );
    _authController = Provider.of<AuthController>(context, listen: false);
    _photoController = Provider.of<PhotoController>(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _audioController.initialize();
    });
  }

  void _handleCaptionChanged() {
    final isEmpty = _captionController.text.trim().isEmpty;
    if (isEmpty == _isCaptionEmpty) {
      return;
    }
    if (!mounted) {
      _isCaptionEmpty = isEmpty;
      return;
    }
    setState(() => _isCaptionEmpty = isEmpty);
  }

  void _loadCategoriesIfNeeded() {
    if (!_categoriesLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadUserCategories();
      });
    }
  }

  void _handleWidgetUpdate(PhotoEditorScreen oldWidget) {
    if (oldWidget.imagePath != widget.imagePath ||
        oldWidget.downloadUrl != widget.downloadUrl) {
      _categoriesLoaded = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadUserCategories(forceReload: true);
      });
    }
  }

  void _handleAppStateChange(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _categoriesLoaded = false;
      _loadUserCategories(forceReload: true);
    }
  }

  // ========== 이미지 및 카테고리 로딩 메서드들 ==========
  Future<void> _loadImage() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      if (widget.imagePath != null && widget.imagePath!.isNotEmpty) {
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
      } else if (widget.downloadUrl != null && widget.downloadUrl!.isNotEmpty) {
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

  Future<void> _loadUserCategories({bool forceReload = false}) async {
    if (!forceReload && _categoriesLoaded) return;
    if (!forceReload) {
      setState(() {
        _isLoading = false;
      });
    }
    final currentUser = _authController.currentUser;
    if (currentUser == null) {
      if (mounted)
        setState(() {
          _errorMessage = "로그인이 필요합니다.";
          _isLoading = false;
        });
      return;
    }
    try {
      await _categoryController.loadUserCategories(
        currentUser.uid,
        forceReload: forceReload,
      );
      _categoriesLoaded = true;
      if (_shouldAutoOpenCategorySheet) {
        _shouldAutoOpenCategorySheet = false;
        _animateSheetTo(_kLockedSheetExtent, lockExtent: true);
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted)
        setState(() {
          _errorMessage = "카테고리 로드 중 오류 발생: $e";
        });
    }
  }

  void _handleCategorySelection(String categoryId) {
    if (_selectedCategoryId == categoryId) {
      _uploadThenNavigate(categoryId);
    } else if (mounted) {
      setState(() => _selectedCategoryId = categoryId);
    }
  }

  void _animateSheetTo(double size, {bool lockExtent = false}) {
    if (!mounted || _isDisposing) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _isDisposing) return;
      if (_draggableScrollController.isAttached) {
        await _draggableScrollController.animateTo(
          size,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
      if (lockExtent) {
        _lockSheetExtent(size);
      }
    });
  }

  void _lockSheetExtent(double size) {
    if (!mounted || _isDisposing || _hasLockedSheetExtent) return;
    setState(() {
      _minChildSize = size;
      _initialChildSize = size;
      _hasLockedSheetExtent = true;
    });
    if (_draggableScrollController.isAttached) {
      _draggableScrollController.jumpTo(size);
    }
  }

  Future<void> _resetBottomSheetIfNeeded() async {
    if (_isDisposing || !_draggableScrollController.isAttached) {
      return;
    }
    final double targetSize =
        _hasLockedSheetExtent ? _kLockedSheetExtent : _initialChildSize;
    final double currentSize = _draggableScrollController.size;
    const double tolerance = 0.001;
    if ((currentSize - targetSize).abs() <= tolerance) {
      return;
    }
    await _draggableScrollController.animateTo(
      targetSize,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildCaptionInputBar() {
    final hasRecording =
        _recordedAudioPath != null && _recordedAudioPath!.isNotEmpty;
    final Color backgroundColor = const Color(0xFF383838).withOpacity(0.66);
    final Color micBackground =
        hasRecording ? const Color(0xFF3F3F40) : const Color(0xFF27272A);
    final bool showRecorder = _isRecorderVisible;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder:
          (child, animation) =>
              FadeTransition(opacity: animation, child: child),
      child:
          showRecorder
              ? SizedBox(
                key: const ValueKey('recorder_view'),
                width: 354.w,
                child: AudioRecorderWidget(
                  key: ValueKey(
                    'recorder_${_recordedAudioPath ?? 'new'}_${_shouldAutoStartRecording ? 'auto' : 'manual'}',
                  ),
                  photoId: widget.imagePath?.split('/').last ?? 'unknown',
                  isCommentMode: false,
                  autoStart: _shouldAutoStartRecording,
                  initialRecordingPath: _recordedAudioPath,
                  initialWaveformData: _recordedWaveformData,
                  onRecordingCompleted: (
                    String? audioPath,
                    List<double>? waveformData,
                  ) {
                    if (!mounted) return;
                    setState(() {
                      _recordedWaveformData = waveformData;
                      _recordedAudioPath = audioPath;
                      _shouldAutoStartRecording = false;
                      _isRecorderVisible = true;
                    });
                  },
                  onRecordingCleared: () {
                    if (!mounted) return;
                    setState(() {
                      _recordedWaveformData = null;
                      _recordedAudioPath = null;
                      _shouldAutoStartRecording = false;
                      _isRecorderVisible = false;
                    });
                  },
                ),
              )
              : Column(
                key: const ValueKey('caption_view'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 353.w,
                    height: 46.h,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(21.5),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 19.w),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _captionController,
                                maxLines: 1,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontFamily: 'Pretendard',
                                  fontWeight: FontWeight.w200,
                                  letterSpacing: -0.5,
                                  height: 1.18,
                                ),
                                cursorColor: Colors.white,
                                textInputAction: TextInputAction.done,
                                decoration: InputDecoration(
                                  isCollapsed: true,
                                  border: InputBorder.none,
                                  hintText: '게시글 추가하기....',
                                  hintStyle: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 16,
                                    fontFamily: 'Pretendard',
                                    fontWeight: FontWeight.w200,
                                    letterSpacing: -0.5,
                                    height: 1.18,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 12.w),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              transitionBuilder:
                                  (child, animation) => FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  ),
                              child:
                                  _isCaptionEmpty
                                      ? Material(
                                        key: const ValueKey('mic_button'),
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () {
                                            setState(() {
                                              _recordedAudioPath = null;
                                              _recordedWaveformData = null;
                                              _shouldAutoStartRecording = true;
                                              _isRecorderVisible = true;
                                            });
                                          },
                                          borderRadius: BorderRadius.circular(
                                            18.r,
                                          ),
                                          child: Ink(
                                            width: 36.w,
                                            height: 36.h,
                                            decoration: BoxDecoration(
                                              color: micBackground,
                                              borderRadius:
                                                  BorderRadius.circular(18.r),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.31),
                                                  offset: const Offset(
                                                    -0.84,
                                                    -1.97,
                                                  ),
                                                  blurRadius: 2.25,
                                                ),
                                                BoxShadow(
                                                  color: Colors.white
                                                      .withOpacity(0.06),
                                                  offset: const Offset(
                                                    0.28,
                                                    1.13,
                                                  ),
                                                  blurRadius: 2.25,
                                                ),
                                              ],
                                            ),
                                            child: Icon(
                                              hasRecording
                                                  ? Icons.mic
                                                  : Icons.mic_none,
                                              color:
                                                  hasRecording
                                                      ? Colors.white
                                                      : const Color(0xFFD9D9D9),
                                              size: 20.sp,
                                            ),
                                          ),
                                        ),
                                      )
                                      : SizedBox(
                                        key: const ValueKey('mic_placeholder'),
                                        width: 36.w,
                                        height: 36.h,
                                      ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (hasRecording)
                    Padding(
                      padding: EdgeInsets.only(top: 8.h, left: 4.w),
                      child: Text(
                        '녹음된 음성 메모가 저장되었습니다.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12.sp,
                          fontFamily: 'Pretendard',
                        ),
                      ),
                    ),
                ],
              ),
    );
  }

  Future<void> _createNewCategory(
    List<SelectedFriendModel> selectedFriends,
  ) async {
    if (_categoryNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('카테고리 이름을 입력해주세요')));
      return;
    }
    try {
      final String? userId = _authController.getUserId;
      if (userId == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('로그인이 필요합니다. 다시 로그인해주세요.')));
        return;
      }
      List<String> mates = [userId];
      for (final friend in selectedFriends) {
        if (!mates.contains(friend.uid)) {
          mates.add(friend.uid);
        }
      }
      await _categoryController.createCategory(
        name: _categoryNameController.text.trim(),
        mates: mates,
      );
      _categoriesLoaded = false;
      await _loadUserCategories(forceReload: true);
      setState(() {
        _showAddCategoryUI = false;
        _categoryNameController.clear();
      });
      if (!context.mounted) return;
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('카테고리 생성 중 오류가 발생했습니다')));
    }
  }

  // ========== 업로드 및 화면 전환 관련 메서드들 ==========
  Future<void> _uploadThenNavigate(String categoryId) async {
    LoadingPopupWidget.show(context, message: '사진을 업로드하고 있습니다.\n잠시만 기다려주세요');
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      await _audioController.stopAudio();
      await _audioController.stopRealtimeAudio();
      _audioController.clearCurrentRecording();
      await Future.delayed(const Duration(milliseconds: 500));
      final uploadData = _extractUploadData(categoryId);
      if (uploadData == null && mounted) {
        LoadingPopupWidget.hide(context);
        _navigateToHome();
        return;
      }
      _navigateToHome();
      unawaited(_executeUploadWithExtractedData(uploadData!));
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      LoadingPopupWidget.hide(context);
    } catch (e) {
      LoadingPopupWidget.hide(context);
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      if (mounted) {
        _navigateToHome();
      }
    }
  }

  Map<String, dynamic>? _extractUploadData(String categoryId) {
    final imagePath = widget.imagePath;
    final userId = _authController.getUserId;
    final audioPath =
        _recordedAudioPath ?? _audioController.currentRecordingPath;
    final waveformData = _recordedWaveformData;
    if (imagePath == null || userId == null) return null;
    return {
      'categoryId': categoryId,
      'imagePath': imagePath,
      'userId': userId,
      'audioPath': audioPath,
      'waveformData': waveformData,
      'caption':
          _captionController.text.trim().isNotEmpty
              ? _captionController.text.trim()
              : null,
    };
  }

  Future<void> _executeUploadWithExtractedData(
    Map<String, dynamic> data,
  ) async {
    final categoryId = data['categoryId'] as String;
    final imagePath = data['imagePath'] as String;
    final userId = data['userId'] as String;
    final audioPath = data['audioPath'] as String?;
    final waveformData = data['waveformData'] as List<double>? ?? const [];
    final imageFile = File(imagePath);
    if (!await imageFile.exists()) {
      throw Exception('이미지 파일을 찾을 수 없습니다: $imagePath');
    }
    File? audioFile;
    if (audioPath != null && audioPath.isNotEmpty) {
      audioFile = File(audioPath);
      if (!await audioFile.exists()) {
        audioFile = null;
      }
    }
    if (audioFile != null && waveformData.isNotEmpty) {
      await _photoController.uploadPhotoWithAudio(
        imageFilePath: imageFile.path,
        audioFilePath: audioFile.path,
        userID: userId,
        userIds: [userId],
        categoryId: categoryId,
        waveformData: waveformData,
        duration: Duration(seconds: _audioController.recordingDuration),
      );
    } else {
      await _photoController.uploadPhoto(
        imageFile: imageFile,
        categoryId: categoryId,
        userId: userId,
        userIds: [userId],
        audioFile: null,
      );
    }
  }

  void _navigateToHome() {
    if (!mounted || _isDisposing) return;
    _audioController.stopAudio();
    _audioController.clearCurrentRecording();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => HomePageNavigationBar(currentPageIndex: 2),
        settings: RouteSettings(name: '/home_navigation_screen'),
      ),
      (route) => false,
    );
    if (_draggableScrollController.isAttached) {
      _draggableScrollController.jumpTo(0.0);
    }
  }

  // ========== 이미지 및 데이터 최적화 메서드들 ==========
  // ========== UI 빌드 메서드 ==========
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
                              PhotoDisplayWidget(
                                imagePath: widget.imagePath,
                                downloadUrl: widget.downloadUrl,
                                useLocalImage: _useLocalImage,
                                useDownloadUrl: _useDownloadUrl,
                                width: 354.w,
                                height: 500.h,
                                onCancel: _resetBottomSheetIfNeeded,
                              ),
                              SizedBox(height: (15.h)),
                              _buildCaptionInputBar(),
                            ],
                          ),
                ),
              ],
            ),
          ),
          bottomSheet: NotificationListener<DraggableScrollableNotification>(
            onNotification: (notification) {
              if (!_hasLockedSheetExtent && notification.extent < 0.01) {
                if (mounted && !_isDisposing && !_hasLockedSheetExtent) {
                  _animateSheetTo(_kLockedSheetExtent, lockExtent: true);
                }
              }
              return true;
            },
            child: DraggableScrollableSheet(
              controller: _draggableScrollController,
              initialChildSize: _initialChildSize,
              minChildSize: _minChildSize,
              maxChildSize: _kMaxSheetExtent,
              expand: false,
              builder: (context, scrollController) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final double maxHeight = constraints.maxHeight;
                    final double desiredHandleHeight =
                        _showAddCategoryUI ? 12.h : (3.h + 10.h + 12.h);
                    final double effectiveHandleHeight = math.min(
                      maxHeight,
                      desiredHandleHeight,
                    );
                    final double desiredSpacing = 4.h;
                    final double effectiveSpacing =
                        maxHeight > effectiveHandleHeight
                            ? desiredSpacing
                            : 0.0;
                    final double contentHeight = math.max(
                      0.0,
                      maxHeight - effectiveHandleHeight - effectiveSpacing,
                    );
                    return Container(
                      decoration: BoxDecoration(
                        color: Color(0xff171717),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            SizedBox(
                              height: effectiveHandleHeight,
                              child:
                                  _showAddCategoryUI
                                      ? Center(
                                        child: Container(
                                          margin: EdgeInsets.only(bottom: 12.h),
                                        ),
                                      )
                                      : Center(
                                        child: Container(
                                          height: math.min(
                                            3.h,
                                            effectiveHandleHeight,
                                          ),
                                          width: 56.w,
                                          margin: EdgeInsets.only(
                                            top: math.min(
                                              10.h,
                                              effectiveHandleHeight / 2,
                                            ),
                                            bottom: math.min(
                                              12.h,
                                              effectiveHandleHeight / 2,
                                            ),
                                          ),
                                          decoration: BoxDecoration(
                                            color: Color(0xffcdcdcd),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                        ),
                                      ),
                            ),
                            SizedBox(height: effectiveSpacing),
                            SizedBox(
                              height: contentHeight,
                              child: AnimatedSwitcher(
                                duration: Duration(milliseconds: 300),
                                child:
                                    _showAddCategoryUI
                                        ? ClipRect(
                                          child: LayoutBuilder(
                                            builder: (context, addConstraints) {
                                              return ConstrainedBox(
                                                constraints: BoxConstraints(
                                                  maxHeight:
                                                      addConstraints.maxHeight,
                                                  maxWidth:
                                                      addConstraints.maxWidth,
                                                ),
                                                child: AddCategoryWidget(
                                                  textController:
                                                      _categoryNameController,
                                                  scrollController:
                                                      scrollController,
                                                  onBackPressed: () {
                                                    setState(() {
                                                      _showAddCategoryUI =
                                                          false;
                                                      _categoryNameController
                                                          .clear();
                                                    });
                                                    _animateSheetTo(
                                                      _kLockedSheetExtent,
                                                    );
                                                  },
                                                  onSavePressed:
                                                      (selectedFriends) =>
                                                          _createNewCategory(
                                                            selectedFriends,
                                                          ),
                                                ),
                                              );
                                            },
                                          ),
                                        )
                                        : CategoryListWidget(
                                          scrollController: scrollController,
                                          selectedCategoryId:
                                              _selectedCategoryId,
                                          onCategorySelected:
                                              _handleCategorySelection,
                                          addCategoryPressed: () {
                                            setState(
                                              () => _showAddCategoryUI = true,
                                            );
                                            _animateSheetTo(0.65);
                                          },
                                          isLoading:
                                              _categoryController.isLoading,
                                        ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ========== 리소스 정리 메서드 ==========
  @override
  void dispose() {
    _isDisposing = true;
    _audioController.stopAudio();
    _audioController.stopRealtimeAudio();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _audioController.clearCurrentRecording();
    });
    _recordedWaveformData = null;
    _recordedAudioPath = null;
    if (widget.imagePath != null) {
      PaintingBinding.instance.imageCache.evict(
        FileImage(File(widget.imagePath!)),
      );
    }
    if (widget.downloadUrl != null) {
      PaintingBinding.instance.imageCache.evict(
        NetworkImage(widget.downloadUrl!),
      );
    }
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    _categoryNameController.dispose();
    _captionController.removeListener(_handleCaptionChanged);
    _captionController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    if (_draggableScrollController.isAttached) {
      _draggableScrollController.jumpTo(0.0);
    }
    _draggableScrollController.dispose();
    super.dispose();
  }
}
