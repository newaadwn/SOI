import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../../controllers/contacts_controller.dart';

/// 연락처 목록을 표시하고 연락처를 친구로 추가하는 화면
class AddcontactsPage extends StatefulWidget {
  const AddcontactsPage({super.key});

  @override
  State<AddcontactsPage> createState() => _AddcontactsPageState();
}

class _AddcontactsPageState extends State<AddcontactsPage>
    with WidgetsBindingObserver {
  // 검색어 입력을 위한 컨트롤러
  final TextEditingController _searchController = TextEditingController();
  late ContactsController _contactsController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 컨트롤러 초기화 및 이벤트 연결
    _contactsController = Provider.of<ContactsController>(
      context,
      listen: false,
    );

    // 검색어 변경 시 이벤트 처리
    _searchController.addListener(_onSearchChanged);

    // 다음 프레임에서 권한 요청 (화면이 그려진 후 요청 다이얼로그 표시)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isInitialized) {
        _contactsController.requestContactPermission();
        _contactsController.loadAddedContacts();
        _isInitialized = true;
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱이 다시 화면에 표시될 때 (설정에서 돌아올 때) 권한을 다시 확인
    if (state == AppLifecycleState.resumed &&
        _contactsController.permissionDenied) {
      _contactsController.requestContactPermission();
    }
    super.didChangeAppLifecycleState(state);
  }

  @override
  void dispose() {
    // 컨트롤러 해제
    WidgetsBinding.instance.removeObserver(this);
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  // 검색어 변경 시 호출되는 함수
  void _onSearchChanged() {
    _contactsController.searchContacts(_searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    // 연락처 컨트롤러의 상태 변화 감지
    return Consumer<ContactsController>(
      builder: (context, controller, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('연락처'),
            actions: [
              // 새로고침 버튼
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: controller.loadContacts,
              ),
            ],
          ),
          body: Column(
            children: [
              // 검색창
              _buildSearchBar(),
              // 연락처 목록
              Expanded(child: _buildContactsList(controller)),
            ],
          ),
        );
      },
    );
  }

  // 검색창 위젯
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '이름 또는 전화번호로 검색',
          prefixIcon: const Icon(Icons.search),
          suffixIcon:
              _searchController.text.isNotEmpty
                  ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _contactsController.searchContacts('');
                    },
                  )
                  : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey.shade200,
        ),
      ),
    );
  }

  // 연락처 목록 위젯
  Widget _buildContactsList(ContactsController controller) {
    // 로딩 중인 경우
    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 연락처가 없는 경우
    if (!controller.hasContacts) {
      return const Center(child: Text('연락처가 없습니다'));
    }

    // 검색 결과가 없는 경우
    if (!controller.hasFilteredContacts) {
      return const Center(child: Text('검색 결과가 없습니다'));
    }

    // 연락처 목록 표시
    return RefreshIndicator(
      onRefresh: controller.loadContacts,
      child: ListView.builder(
        itemCount: controller.filteredContacts.length,
        itemBuilder: (context, index) {
          Contact contact = controller.filteredContacts[index];
          String phoneNumber =
              contact.phones.isNotEmpty ? contact.phones.first.number : '';
          bool isAdded = controller.isContactAdded(phoneNumber);

          return ListTile(
            // 연락처 아바타
            leading: controller.buildContactAvatar(contact),
            // 연락처 이름
            title: Text(
              contact.displayName.isNotEmpty ? contact.displayName : '이름 없음',
            ),
            // 연락처 전화번호
            subtitle: Text(controller.formatPhoneNumber(phoneNumber)),
            // 추가 버튼 또는 이미 추가됨 아이콘
            trailing:
                isAdded
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => _addContact(contact),
                    ),
            onTap: () => _showContactDetails(contact),
          );
        },
      ),
    );
  }

  // 연락처 추가 함수
  Future<void> _addContact(Contact contact) async {
    // 로딩 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // 연락처 추가 시도
    final bool success = await _contactsController.addContact(contact);

    // 로딩 닫기
    Navigator.pop(context);

    // 결과 메시지 표시
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '${contact.displayName.isNotEmpty ? contact.displayName : "연락처"}가 추가되었습니다'
              : '연락처를 추가할 수 없습니다',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // 연락처 상세 정보 표시
  void _showContactDetails(Contact contact) {
    final String phoneNumber =
        contact.phones.isNotEmpty ? contact.phones.first.number : '';
    final bool isAdded = _contactsController.isContactAdded(phoneNumber);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              // 프로필 이미지 또는 이니셜
              _contactsController.buildContactAvatar(contact, radius: 40),
              const SizedBox(height: 16),
              // 이름
              Text(
                contact.displayName.isNotEmpty ? contact.displayName : '이름 없음',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              // 전화번호 목록
              if (contact.phones.isNotEmpty)
                ...contact.phones.map((phone) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _contactsController.formatPhoneNumber(phone.number),
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          phone.label.name,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              // 이메일 목록
              if (contact.emails.isNotEmpty)
                ...contact.emails.map((email) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          email.address,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          email.label.name,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              const SizedBox(height: 24),
              // 친구 추가 버튼
              isAdded
                  ? ElevatedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.check),
                    label: const Text('이미 추가된 연락처'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      disabledBackgroundColor: Colors.grey.shade300,
                    ),
                  )
                  : ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _addContact(contact);
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: const Text('친구 추가하기'),
                  ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
