/// 선택된 친구 정보를 전달하기 위한 모델
class SelectedFriendModel {
  final String uid;
  final String name;
  final String? profileImageUrl;

  const SelectedFriendModel({
    required this.uid,
    required this.name,
    this.profileImageUrl,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SelectedFriendModel &&
        other.uid == uid &&
        other.name == name &&
        other.profileImageUrl == profileImageUrl;
  }

  @override
  int get hashCode => uid.hashCode ^ name.hashCode ^ profileImageUrl.hashCode;
}
