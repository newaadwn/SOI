import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/photo_data_model.dart';
import 'photo_detail_screen.dart';

class PhotoGridItem extends StatefulWidget {
  final PhotoDataModel photo;
  final List<PhotoDataModel> allPhotos;
  final int currentIndex;
  final String categoryName;
  final String categoryId;

  const PhotoGridItem({
    super.key,
    required this.photo,
    required this.allPhotos,
    required this.currentIndex,
    required this.categoryName,
    required this.categoryId,
  });

  @override
  _PhotoGridItemState createState() => _PhotoGridItemState();
}

class _PhotoGridItemState extends State<PhotoGridItem>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin을 위해 호출
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => PhotoDetailScreen(
                  photos: widget.allPhotos,
                  initialIndex: widget.currentIndex,
                  categoryName: widget.categoryName,
                  categoryId: widget.categoryId,
                ),
          ),
        );
      },
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          SizedBox(
            width: 175,
            height: 232,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(widget.photo.imageUrl, fit: BoxFit.cover),
            ),
          ),
          Container(
            width: double.infinity,
            color: Colors.black.withOpacity(0.3),
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              DateFormat('yyyy.MM.dd').format(widget.photo.createdAt),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
