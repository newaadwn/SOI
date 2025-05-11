import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../view_model/auth_view_model.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);

    return Drawer(
      backgroundColor: const Color(0xFF1E1E1E), // 이미지와 유사한 어두운 배경색
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // 사용자 프로필 섹션
              Consumer<AuthViewModel>(
                builder: (context, authViewModel, _) {
                  return FutureBuilder<String>(
                    future: authViewModel.getIdFromFirestore(),
                    builder: (context, snapshot) {
                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            // 프로필 이미지
                            FutureBuilder<String>(
                              // 사용자의 실제 프로필 이미지 URL을 가져옵니다
                              future: authViewModel.getUserProfileImageUrl(),
                              builder: (context, profileSnapshot) {
                                String profileImageUrl =
                                    profileSnapshot.data ?? '';

                                return Stack(
                                  children: [
                                    // 프로필 이미지 컨테이너
                                    _buildProfileImage(
                                      profileImageUrl,
                                      authViewModel,
                                    ),
                                    // 업로드 중 표시기
                                    if (authViewModel.isUploading)
                                      Positioned.fill(
                                        child: Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(
                                              0.5,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Center(
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        ),
                                      ),

                                    // 카메라 아이콘 (이미지 변경 힌트)
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: const Color(0xFF1E1E1E),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt,
                                          color: Color(0xFF1E1E1E),
                                          size: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(width: 16),

                            // 사용자 이름과 ID
                            _buildIDandName(authViewModel),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),

              const Divider(color: Colors.grey, height: 1),

              // 계정 정보 섹션
              _buildSection('계정', [
                _buildAccountItem('이름', future: authViewModel.getUserName()),
                _buildAccountItem('아이디', future: authViewModel.getUserID()),
                // 전화번호 항목 수정: FutureBuilder 직접 사용
                _buildAccountItem(
                  '전화번호',
                  future: authViewModel.getUserPhoneNumber(),
                ),
              ]),

              const Divider(color: Colors.grey, height: 1),

              // 이용 안내 섹션
              _buildSection('이용 안내', [
                _buildInformationItem('버전 정보', '0.5', null),
                _buildInformationItem('이용약관', null, () {}),
                _buildInformationItem('개인정보처리방침', null, () {
                  Navigator.pushNamed(context, '/privacy_policy');
                }),
              ]),

              const Divider(color: Colors.grey, height: 1),

              // 기타 섹션
              _buildSection('기타', [
                _buildAboutUserItem(
                  '회원 탈퇴',
                  onTap: () {
                    showCustomDialog(
                      context: context,
                      title: '회원 탈퇴',
                      content: '회원 탈퇴 시 복구가 불구하며\n계정이 영구적으로 삭제됩니다.',
                      cancelText: '취소',
                      confirmText: '탈퇴',
                      onCancel: () {},
                      onConfirm: () {
                        // 회원 탈퇴 처리
                        authViewModel.deleteUser().then((_) {
                          Navigator.pushReplacementNamed(context, '/start');
                        });
                      },
                    );
                  },
                ),
                _buildAboutUserItem(
                  '로그아웃',
                  onTap: () {
                    showCustomDialog(
                      context: context,
                      title: '로그아웃',
                      content: '로그아웃 하시겠습니까?',
                      cancelText: '취소',
                      confirmText: '확인',
                      onCancel: () {},
                      onConfirm: () {
                        // 로그아웃 처리
                        authViewModel.signOut().then((_) {
                          Navigator.pushReplacementNamed(context, '/start');
                        });
                      },
                    );
                  },
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  // 사용자 정의 다이얼로그 표시 함수
  void showCustomDialog({
    required BuildContext context,
    required String title,
    required String content,
    String? cancelText,
    String? confirmText,
    VoidCallback? onCancel,
    VoidCallback? onConfirm,
  }) {
    showDialog<String>(
      context: context,
      builder:
          (BuildContext context) => Dialog(
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14.2),
                color: const Color(0xFFfdfdfd),
              ),

              child: Column(
                mainAxisSize: MainAxisSize.min,

                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  Text(content, textAlign: TextAlign.center),
                  const SizedBox(height: 24.0),

                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onConfirm?.call();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF383838),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.2),
                      ),
                    ),
                    child: Container(
                      width: 156,
                      height: 38,
                      alignment: Alignment.center,
                      child: Text(confirmText!, textAlign: TextAlign.center),
                    ),
                  ),
                  const SizedBox(height: 13.0),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onCancel?.call();
                    },

                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFf9f9f9),
                      foregroundColor: Colors.black,
                      side: BorderSide(color: Color(0xfff2f2f2)),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.2),
                      ),
                    ),

                    child: Container(
                      width: 156,
                      height: 38,
                      alignment: Alignment.center,
                      child: Text(
                        cancelText!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xffa3a3a3)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  // 사용자 이름과 ID를 표시하는 위젯
  // FutureBuilder를 사용하여 비동기적으로 데이터를 가져옵니다.
  Widget _buildIDandName(AuthViewModel authViewModel) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<String>(
            future: authViewModel.getUserName(),
            builder: (context, snapshot) {
              return Text(
                snapshot.data ?? 'Loading Name...',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          FutureBuilder<String>(
            future: authViewModel.getUserID(),
            builder: (context, snapshot) {
              return Text(
                snapshot.data ?? 'Loading ID...',
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              );
            },
          ),
        ],
      ),
    );
  }

  // 프로필 이미지 위젯
  // 이미지 클릭 시 프로필 이미지 변경 기능을 추가합니다.
  // 이미지 업로드 중일 때는 클릭을 방지합니다.
  // 업로드 중일 때는 CircularProgressIndicator를 표시합니다.
  // 업로드가 완료되면 성공 메시지를 표시합니다.
  Widget _buildProfileImage(
    String profileImageUrl,
    AuthViewModel authViewModel,
  ) {
    return GestureDetector(
      onTap: () async {
        // 이미지 업로드 중인 경우 중복 클릭 방지
        if (authViewModel.isUploading) {
          Fluttertoast.showToast(msg: '이미지 업로드 중입니다...');
          return;
        }

        // 프로필 이미지 업데이트 실행
        final bool success = await authViewModel.updateProfileImage();

        if (success) {
          Fluttertoast.showToast(msg: '프로필 이미지가 업데이트되었습니다');
        }
      },
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child:
            profileImageUrl.isNotEmpty
                ? ClipOval(
                  child: Image.network(
                    profileImageUrl,
                    fit: BoxFit.cover,
                    width: 60,
                    height: 60,
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint('프로필 이미지 로드 오류: $error');
                      // 이미지 로드 실패 시, 유효하지 않은 URL을 초기화
                      Future.microtask(
                        () => authViewModel.cleanInvalidProfileImageUrl(),
                      );
                      return const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 40,
                      );
                    },
                  ),
                )
                : const Icon(Icons.person, color: Colors.white, size: 40),
      ),
    );
  }

  // 섹션 제목
  Widget _buildSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...items,
      ],
    );
  }

  // 계정 부분 drawer 아이템
  Widget _buildAccountItem(String title, {Future<String>? future}) {
    return ListTile(
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: FutureBuilder<String>(
        future: future,
        builder: (context, snapshot) {
          return Text(
            snapshot.data ?? 'Loading ID...',
            style: TextStyle(color: Colors.grey[400]),
          );
        },
      ),
    );
  }

  // 이용 안내 부분 drawer 아이템
  Widget _buildInformationItem(
    String title,
    String? version,
    Function()? onTap,
  ) {
    return ListTile(
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: Text(version ?? '', style: TextStyle(color: Colors.grey[400])),
      onTap: onTap,
      enabled: onTap != null,
    );
  }
}

Widget _buildAboutUserItem(String content, {required Function() onTap}) {
  return ListTile(
    title: Text(content, style: const TextStyle(color: Colors.white)),
    onTap: onTap,
  );
}
