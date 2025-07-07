import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import shared_preferences
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:yapyap2/screens/friend_requests_screen.dart';
import 'package:yapyap2/screens/chat_screen.dart'; // Import the new chat screen
import 'package:yapyap2/screens/profile_screen.dart'; // Import the profile screen

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController(initialPage: 0);
  int _currentPage = 0;
  String? _currentUserContact; // To store the current user's contact
  String? _currentUserName; // To store the current user's name

  @override
  void initState() {
    super.initState();
    _loadCurrentUserContact();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserContact() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserContact = prefs.getString('contact_no');
      _currentUserName = prefs.getString('name');
    });
  }

  void _logout(BuildContext context) async { // Marked as async
    // Clear the login status from local storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isLoggedIn');
    await prefs.remove('contact_no'); // Clear contact_no
    await prefs.remove('name'); // Clear name

    // TODO: Implement actual logout logic (sign out from Firebase Auth, etc.)
    print('User logged out');
    // Navigate back to login screen and remove all previous routes
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentPage == 0
              ? 'YapYap! ${_currentUserName ?? ''}'
              : 'Friend Requests',
          style: const TextStyle(fontSize: 24),
        ),
        automaticallyImplyLeading: false, // To prevent back button to login
        actions: <Widget>[
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings),
            onSelected: (String result) {
              if (result == 'logout') {
                _logout(context);
              } else if (result == 'profile') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                );
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'profile',
                child: Text('My Profile'),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Text('Log Out'),
              ),
            ],
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (int page) {
          setState(() {
            _currentPage = page;
          });
        },
        children: [
          // Home page content (Chats list)
          _currentUserContact == null
              ? const Center(child: CircularProgressIndicator())
              : StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(_currentUserContact)
                      .collection('friends')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 80,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'No Chats Yet',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Add friends to start chatting!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final friends = snapshot.data!.docs;

                    return ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: friends.length,
                      itemBuilder: (context, index) {
                        final friend = friends[index];
                        final friendContact = friend['contact_no']; // Get contact from the 'friends' subcollection

                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('users').doc(friendContact).get(),
                          builder: (context, userSnapshot) {
                            if (userSnapshot.connectionState == ConnectionState.waiting) {
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 8.0),
                                child: ListTile(
                                  leading: const CircleAvatar(child: Icon(Icons.person)),
                                  title: Text('Loading...'),
                                  subtitle: Text(friendContact),
                                ),
                              );
                            }

                            if (userSnapshot.hasError) {
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 8.0),
                                child: ListTile(
                                  leading: const CircleAvatar(child: Icon(Icons.error)),
                                  title: Text('Error loading friend'),
                                  subtitle: Text(friendContact),
                                ),
                              );
                            }

                            String friendName = 'Unknown Friend';
                            if (userSnapshot.hasData && userSnapshot.data!.exists) {
                              friendName = userSnapshot.data!['name'] ?? 'Unknown Friend';
                            }

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 8.0),
                              child: ListTile(
                                leading: const CircleAvatar(
                                  child: Icon(Icons.person),
                                ),
                                title: Text(friendName),
                                subtitle: Text(friendContact),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChatScreen(
                                        currentUserContact: _currentUserContact!,
                                        friendContact: friendContact,
                                        friendName: friendName,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
          // Friend requests page
          const FriendRequestsScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentPage,
        onTap: (int index) {
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.chat),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.people),
            label: 'Friend Requests',
          ),
        ],
      ),
    );
  }
}
