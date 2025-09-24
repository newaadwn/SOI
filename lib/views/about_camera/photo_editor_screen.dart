import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../controllers/audio_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/category_controller.dart';
import '../../controllers/photo_controller.dart';
import '../../models/selected_friend_model.dart';
import '../../utils/memory_monitor.dart';
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

  // 프로필 위치 관리
  Offset? _profileImagePosition;

  // 컨트롤러들
  final _draggableScrollController = DraggableScrollableController();
  final _categoryNameController = TextEditingController();
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
    MemoryMonitor.startMonitoring();
    MemoryMonitor.logCurrentMemoryUsage('PhotoEditor 시작');
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

    MemoryMonitor.logCurrentMemoryUsage('카테고리 로드 시작');

    if (!forceReload) {
      setState(() {
        _isLoading = false;
      });
    }

    try {
      final currentUser = _authController.currentUser;
      if (currentUser != null) {
        Future.microtask(() async {
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

            MemoryMonitor.logCurrentMemoryUsage('카테고리 로드 완료');
            MemoryMonitor.checkMemoryWarning('카테고리 로드 완료');
            _preloadCategoryImages();

            if (mounted) {
              setState(() {});
            }
          } catch (e) {
            if (mounted) {
              setState(() {
                _errorMessage = "카테고리 로드 중 오류 발생: $e";
              });
            }
          }
        });
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = "로그인이 필요합니다.";
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _preloadCategoryImages() async {
    try {
      final categories = _categoryController.userCategoryList;
      MemoryMonitor.logCurrentMemoryUsage('카테고리 이미지 preload 시작');

      final priorityCategories =
          categories
              .where((c) => c.categoryPhotoUrl?.isNotEmpty == true)
              .take(8)
              .toList();

      for (final category in priorityCategories) {
        try {
          final imageProvider = NetworkImage(category.categoryPhotoUrl!);
          unawaited(precacheImage(imageProvider, context));

          if (MemoryMonitor.isMemoryUsageHigh()) {
            debugPrint('메모리 압박으로 preload 중단');
            break;
          }

          await Future.delayed(Duration(milliseconds: 100));
        } catch (e) {
          debugPrint('카테고리 이미지 preload 실패: ${category.name} - $e');
        }
      }

      MemoryMonitor.logCurrentMemoryUsage('카테고리 이미지 preload 완료');
    } catch (e) {
      debugPrint('카테고리 이미지 preload 전체 실패: $e');
    }
  }

  // ========== 카테고리 선택 및 UI 처리 메서드들 ==========

  void _handleCategorySelection(String categoryId) {
    if (_selectedCategoryId == categoryId) {
      _uploadThenNavigate(categoryId);
    } else {
      if (mounted) {
        setState(() {
          _selectedCategoryId = categoryId;
        });
      }
    }
  }

  void _animateSheetTo(double size, {bool lockExtent = false}) {
    if (!mounted || _isDisposing) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _isDisposing) return;

      try {
        if (_draggableScrollController.isAttached) {
          await _draggableScrollController.animateTo(
            size,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      } catch (e) {
        debugPrint('애니메이션 실행 에러: $e');
      } finally {
        if (lockExtent) {
          _lockSheetExtent(size);
        }
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
      try {
        _draggableScrollController.jumpTo(size);
      } catch (e) {
        debugPrint('시트 고정 중 jumpTo 오류: $e');
      }
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

    try {
      await _draggableScrollController.animateTo(
        targetSize,
        duration: Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    } catch (e) {
      debugPrint('바텀시트 초기화 중 애니메이션 오류: $e');
    }
  }

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
      _cleanMemoryBeforeUpload();
      await _cleanAudioSession();

      MemoryMonitor.logCurrentMemoryUsage('업로드 데이터 추출 전');
      final uploadData = _extractUploadData(categoryId);
      if (uploadData == null) {
        LoadingPopupWidget.hide(context);
        _navigateToHome();
        return;
      }

      _navigateToHome();

      unawaited(_executeUploadWithExtractedData(uploadData));
      _cleanMemoryAfterUpload();
      LoadingPopupWidget.hide(context);
    } catch (e) {
      debugPrint('업로드 오류: $e');
      LoadingPopupWidget.hide(context);
      _cleanMemoryAfterUpload();

      if (mounted) {
        _navigateToHome();
      }
    }
  }

  void _cleanMemoryBeforeUpload() {
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      MemoryMonitor.forceGarbageCollection('업로드 전 정리');
      debugPrint('업로드 전 이미지 캐시 정리 완료');
    } catch (e) {
      debugPrint('업로드 전 캐시 정리 오류: $e');
    }
  }

  Future<void> _cleanAudioSession() async {
    try {
      await _audioController.stopAudio();
      await _audioController.stopRealtimeAudio();
      _audioController.clearCurrentRecording();
      await Future.delayed(Duration(milliseconds: 500));
      debugPrint('오디오 세션 정리 완료');
    } catch (e) {
      debugPrint('오디오 세션 정리 오류: $e');
    }
  }

  void _cleanMemoryAfterUpload() {
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      MemoryMonitor.forceGarbageCollection('업로드 완료 후 정리 - 1차');

      Future.delayed(Duration(milliseconds: 200), () {
        PaintingBinding.instance.imageCache.clear();
        MemoryMonitor.forceGarbageCollection('업로드 완료 후 정리 - 2차');
      });

      debugPrint('업로드 후 강화된 메모리 정리 완료');
    } catch (e) {
      debugPrint('업로드 후 캐시 정리 오류: $e');
    }
  }

  Map<String, dynamic>? _extractUploadData(String categoryId) {
    final imagePath = widget.imagePath;
    final userId = _authController.getUserId;
    final audioPath =
        _recordedAudioPath ?? _audioController.currentRecordingPath;
    final waveformData = _recordedWaveformData;

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

  Future<void> _executeUploadWithExtractedData(
    Map<String, dynamic> data,
  ) async {
    final categoryId = data['categoryId'] as String;
    final imagePath = data['imagePath'] as String;
    final userId = data['userId'] as String;
    final audioPath = data['audioPath'] as String?;
    final waveformData = data['waveformData'] as List<double>?;

    final imageFile = File(imagePath);
    if (!await imageFile.exists()) {
      throw Exception('이미지 파일을 찾을 수 없습니다: $imagePath');
    }

    File? optimizedImageFile;
    try {
      optimizedImageFile = await _optimizeImageFile(imageFile);
    } catch (e) {
      debugPrint('이미지 최적화 실패, 원본 사용: $e');
      optimizedImageFile = imageFile;
    }

    File? audioFile;
    if (audioPath != null && audioPath.isNotEmpty) {
      audioFile = File(audioPath);
      if (!await audioFile.exists()) {
        audioFile = null;
      }
    } else {
      debugPrint('오디오 경로가 null이거나 비어있음: $audioPath');
    }

    List<double>? optimizedWaveform;
    if (waveformData != null && waveformData.isNotEmpty) {
      optimizedWaveform = _optimizeWaveformData(waveformData);
      debugPrint(
        '파형 데이터 최적화: ${waveformData.length} -> ${optimizedWaveform.length}',
      );
    }

    try {
      if (audioFile != null &&
          optimizedWaveform != null &&
          optimizedWaveform.isNotEmpty) {
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
      if (optimizedImageFile.path != imagePath) {
        try {
          await optimizedImageFile.delete();
          debugPrint('최적화된 임시 이미지 파일 삭제 완료');
        } catch (e) {
          debugPrint('임시 파일 삭제 실패: $e');
        }
      }

      audioFile = null;
      optimizedWaveform = null;
    }
  }

  void _navigateToHome() {
    if (!mounted || _isDisposing) return;

    try {
      _audioController.stopAudio();
      _audioController.clearCurrentRecording();
      debugPrint('화면 전환 전 오디오 정리 완료');
    } catch (e) {
      debugPrint('화면 전환 전 오디오 정리 오류: $e');
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => HomePageNavigationBar(currentPageIndex: 2),
        settings: RouteSettings(name: '/home_navigation_screen'),
      ),
      (route) => false,
    );

    Future.microtask(() {
      if (_draggableScrollController.isAttached) {
        _draggableScrollController.jumpTo(0.0);
      }
    });
  }

  // ========== 이미지 및 데이터 최적화 메서드들 ==========

  Future<File> _optimizeImageFile(File originalFile) async {
    try {
      final Uint8List originalBytes = await originalFile.readAsBytes();

      final ui.Codec codec = await ui.instantiateImageCodec(
        originalBytes,
        targetWidth: 1080,
      );

      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;

      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData == null) {
        throw Exception('이미지 압축 실패');
      }

      final String tempDir = Directory.systemTemp.path;
      final String fileName =
          'optimized_${DateTime.now().millisecondsSinceEpoch}.png';
      final File optimizedFile = File('$tempDir/$fileName');

      await optimizedFile.writeAsBytes(byteData.buffer.asUint8List());
      image.dispose();

      debugPrint(
        '이미지 최적화 완료: ${originalBytes.length} -> ${byteData.lengthInBytes} bytes',
      );

      return optimizedFile;
    } catch (e) {
      debugPrint('이미지 최적화 실패: $e');
      return originalFile;
    }
  }

  List<double> _optimizeWaveformData(List<double> originalWaveform) {
    if (originalWaveform.length <= 100) {
      return originalWaveform;
    }

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
                                  setState(() {
                                    _recordedWaveformData = waveformData;
                                    _recordedAudioPath = audioPath;
                                  });
                                },
                              ),
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
                                                      (
                                                        selectedFriends,
                                                      ) => _createNewCategory(
                                                        _categoryNameController
                                                            .text
                                                            .trim(),
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
                                            setState(() {
                                              _showAddCategoryUI = true;
                                            });
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

    MemoryMonitor.logCurrentMemoryUsage('PhotoEditor 종료 시작');

    try {
      _audioController.stopAudio();
      _audioController.stopRealtimeAudio();

      SchedulerBinding.instance.addPostFrameCallback((_) {
        try {
          _audioController.clearCurrentRecording();
          debugPrint('PhotoEditor: 오디오 리소스 정리 완료 (PostFrame)');
        } catch (e) {
          debugPrint('PhotoEditor: PostFrame 오디오 정리 오류: $e');
        }
      });

      _recordedWaveformData = null;
      _recordedAudioPath = null;
      debugPrint('PhotoEditor: 로컬 오디오 데이터 정리 완료');
    } catch (e) {
      debugPrint('PhotoEditor: 오디오 리소스 정리 오류: $e');
    }

    try {
      if (widget.imagePath != null) {
        final imageFile = File(widget.imagePath!);
        PaintingBinding.instance.imageCache.evict(FileImage(imageFile));
      }
      if (widget.downloadUrl != null) {
        PaintingBinding.instance.imageCache.evict(
          NetworkImage(widget.downloadUrl!),
        );
      }

      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      MemoryMonitor.logCurrentMemoryUsage('이미지 캐시 정리 후');
    } catch (e) {
      debugPrint('이미지 캐시 정리 오류: $e');
    }

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

    try {
      if (_draggableScrollController.isAttached) {
        _draggableScrollController.jumpTo(0.0);

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
        _draggableScrollController.dispose();
      }
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          _draggableScrollController.dispose();
        } catch (e) {
          debugPrint('DraggableScrollController 최종 dispose 오류: $e');
        }
      });
    }

    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      try {
        MemoryMonitor.forceGarbageCollection('PhotoEditor dispose - 1차');

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

    MemoryMonitor.logCurrentMemoryUsage('PhotoEditor 종료 완료');
    MemoryMonitor.stopMonitoring();

    super.dispose();
  }
}
