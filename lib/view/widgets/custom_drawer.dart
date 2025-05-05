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
                      final userName = snapshot.data ?? 'Loading...';

                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            // 프로필 이미지
                            FutureBuilder<String>(
                              // 사용자의 실제 프로필 이미지 URL을 가져옵니다
                              future: authViewModel.getUserProfileImageUrl(),
                              builder: (context, profileSnapshot) {
                                String profileImageUrl = profileSnapshot.data ?? '';
                                
                                return Stack(
                                  children: [
                                    // 프로필 이미지 컨테이너
                                    GestureDetector(
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
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                          image: profileImageUrl.isNotEmpty
                                              ? DecorationImage(
                                                  image: NetworkImage(profileImageUrl),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                        ),
                                        child: profileImageUrl.isEmpty
                                            ? const Icon(
                                                Icons.person,
                                                color: Colors.white,
                                                size: 40,
                                              )
                                            : null,
                                      ),
                                    ),
                                    
                                    // 업로드 중 표시기
                                    if (authViewModel.isUploading)
                                      Positioned.fill(
                                        child: Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.5),
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
                            Expanded(
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
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 14,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
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
                _buildMenuItem('이름', content: 'Junhwan Lee', onTap: () {}),
                _buildMenuItem('아이디', content: 'junhwanx9', onTap: () {}),
                // 전화번호 항목 수정: FutureBuilder 직접 사용
                ListTile(
                  title: Text(
                    '전화번호',
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: FutureBuilder<String>(
                    future: authViewModel.getUserPhoneNumber(),
                    builder: (context, snapshot) {
                      return Text(
                        snapshot.data ?? 'Loading ID...',
                        style: TextStyle(color: Colors.grey[400]),
                      );
                    },
                  ),
                  onTap: () {},
                ),
              ]),

              const Divider(color: Colors.grey, height: 1),

              // 이용 안내 섹션
              _buildSection('이용 안내', [
                _buildVersionItem('앱 버전', version: '0.5'),
                _buildMenuItem('서비스 이용 약관', onTap: () {}),
                _buildMenuItem('개인정보 처리방침', onTap: () {}),
              ]),

              const Divider(color: Colors.grey, height: 1),

              // 기타 섹션
              _buildSection('기타', [
                _buildMenuItem('회원 탈퇴', onTap: () {}),
                _buildMenuItem(
                  '로그아웃',
                  onTap: () {
                    // 로그아웃 처리
                    authViewModel.signOut().then((_) {
                      Navigator.pushReplacementNamed(context, '/start');
                    });
                  },
                ),
              ]),
            ],
          ),
        ),
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

  // 일반 메뉴 아이템
  Widget _buildMenuItem(
    String title, {
    String? content,
    required VoidCallback onTap,
  }) {
    return ListTile(
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: Text(content ?? '', style: TextStyle(color: Colors.grey[400])),
      onTap: onTap,
    );
  }

  // 버전 정보 아이템
  Widget _buildVersionItem(String title, {required String version}) {
    return ListTile(
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: Text(version, style: TextStyle(color: Colors.grey[400])),
    );
  }
}
