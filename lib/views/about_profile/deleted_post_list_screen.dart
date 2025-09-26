import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:soi/controllers/auth_controller.dart';
import '../../controllers/photo_controller.dart';
import '../../models/photo_data_model.dart';

class DeletedPostListScreen extends StatefulWidget {
  const DeletedPostListScreen({super.key});

  @override
  State<DeletedPostListScreen> createState() => _DeletedPostListScreenState();
}

class _DeletedPostListScreenState extends State<DeletedPostListScreen> {
  List<PhotoDataModel> _deletedPosts = [];
  bool _isLoading = true;
  String? _error;
  PhotoController? _photoController;
  AuthController? _authController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _photoController = Provider.of<PhotoController>(context, listen: false);
      _authController = Provider.of<AuthController>(context, listen: false);
      _loadDeletedPosts();
    });
  }

  @override
  void dispose() {
    _photoController?.dispose();
    _authController?.dispose();
    super.dispose();
  }

  Future<void> _loadDeletedPosts() async {
    if (_photoController == null) return;

    final user = _authController?.currentUser;
    if (user == null) {
      setState(() {
        _error = '로그인이 필요합니다.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // PhotoController를 통해 삭제된 사진 로드
      await _photoController!.loadDeletedPhotosByUser(user.uid);

      setState(() {
        _deletedPosts = _photoController!.deletedPhotos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '게시물 복구',
              textAlign: TextAlign.start,
              style: TextStyle(
                color: const Color(0xFFF8F8F8),
                fontSize: 20.sp,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '오류가 발생했습니다',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              _error!,
              style: TextStyle(
                color: const Color(0xFFB0B0B0),
                fontSize: 14.sp,
                fontFamily: 'Pretendard',
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: _loadDeletedPosts,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_deletedPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64.sp,
              color: const Color(0xFF666666),
            ),
            SizedBox(height: 16.h),
            Text(
              '삭제한 게시물이 없습니다',
              style: TextStyle(
                color: const Color(0xFFB0B0B0),
                fontSize: 16.sp,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.all(16.w),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12.w,
          mainAxisSpacing: 13.h,
          childAspectRatio: 175 / 233, // 175:233 비율
        ),
        itemCount: _deletedPosts.length,
        itemBuilder: (context, index) {
          return _buildDeletedPostItem(_deletedPosts[index], index);
        },
      ),
    );
  }

  Widget _buildDeletedPostItem(PhotoDataModel photo, int index) {
    return GestureDetector(
      onTap: () {
        // 삭제된 게시물 상세보기 또는 복원 기능
      },
      child: Container(
        width: 175,
        height: 233,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: const Color(0xFF1C1C1C),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: photo.imageUrl,
            fit: BoxFit.cover,
            placeholder:
                (context, url) => Shimmer.fromColors(
                  baseColor: const Color(0xFF333333),
                  highlightColor: const Color(0xFF555555),
                  child: Container(
                    width: 175,
                    height: 233,
                    decoration: BoxDecoration(
                      color: const Color(0xFF333333),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                ),
            errorWidget:
                (context, url, error) => Container(
                  color: const Color(0xFF333333),
                  child: Icon(
                    Icons.broken_image,
                    color: Colors.white54,
                    size: 48.sp,
                  ),
                ),
          ),
        ),
      ),
    );
  }

  /*void _restorePost(int index) {
    // TODO: 실제 복원 로직 구현
    setState(() {
      _deletedPosts.removeAt(index);
    });
  }

  void _permanentlyDeletePost(int index) {
    // TODO: 실제 완전 삭제 로직 구현
    setState(() {
      _deletedPosts.removeAt(index);
    });
  }*/
}
