import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

class DeletedPostListScreen extends StatefulWidget {
  const DeletedPostListScreen({super.key});

  @override
  State<DeletedPostListScreen> createState() => _DeletedPostListScreenState();
}

class _DeletedPostListScreenState extends State<DeletedPostListScreen> {
  List<String> _deletedPosts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDeletedPosts();
  }

  Future<void> _loadDeletedPosts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // TODO: 실제 삭제된 게시물 데이터를 가져오는 로직 구현
      // 임시 데이터
      await Future.delayed(const Duration(seconds: 1));

      setState(() {
        _deletedPosts = [
          // 임시 이미지 URL들 (실제 구현 시 삭제된 게시물 URL로 교체)
          'https://picsum.photos/175/233?random=1',
          'https://picsum.photos/175/233?random=2',
          'https://picsum.photos/175/233?random=3',
          'https://picsum.photos/175/233?random=4',
          'https://picsum.photos/175/233?random=5',
          'https://picsum.photos/175/233?random=6',
        ];
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

  Widget _buildDeletedPostItem(String imageUrl, int index) {
    return GestureDetector(
      onTap: () {
        // 삭제된 게시물 상세보기 또는 복원 기능
        _showPostOptionsBottomSheet(imageUrl, index);
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
            imageUrl: imageUrl,
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

  void _showPostOptionsBottomSheet(String imageUrl, int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: const BoxDecoration(
              color: Color(0xFF2C2C2E),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(25.3),
                topRight: Radius.circular(25.3),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 7.h),
                Container(
                  width: 56.w,
                  height: 3.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBCBCB),
                    borderRadius: BorderRadius.circular(24.80),
                  ),
                ),
                SizedBox(height: 24.h),
                Text(
                  '게시물 옵션',
                  style: TextStyle(
                    color: const Color(0xFFF8F8F8),
                    fontSize: 19.78.sp,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 24.h),
                SizedBox(
                  width: 344.w,
                  height: 38.h,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // TODO: 게시물 복원 기능 구현
                      _restorePost(index);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(19),
                      ),
                    ),
                    child: Text(
                      '복원',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 17.78.sp,
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                SizedBox(
                  width: 344.w,
                  height: 38.h,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // TODO: 완전 삭제 기능 구현
                      _permanentlyDeletePost(index);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(19),
                      ),
                    ),
                    child: Text(
                      '완전 삭제',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17.78.sp,
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                SizedBox(
                  width: 344.w,
                  height: 38.h,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      '취소',
                      style: TextStyle(
                        color: const Color(0xFFCBCBCB),
                        fontSize: 17.78.sp,
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 24.h),
              ],
            ),
          ),
    );
  }

  void _restorePost(int index) {
    // TODO: 실제 복원 로직 구현
    setState(() {
      _deletedPosts.removeAt(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('게시물이 복원되었습니다.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _permanentlyDeletePost(int index) {
    // TODO: 실제 완전 삭제 로직 구현
    setState(() {
      _deletedPosts.removeAt(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('게시물이 완전히 삭제되었습니다.'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
