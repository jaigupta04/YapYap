import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:shared_preferences/shared_preferences.dart'; // Import SharedPreferences

class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({Key? key}) : super(key: key);

  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _searchResultName;
  String? _searchResultContact;
  String? _errorMessage;
  String? _currentUserContact; // To store the current user's contact

  @override
  void initState() {
    super.initState();
    _loadCurrentUserContact();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserContact() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserContact = prefs.getString('contact_no');
      print('Loaded current user contact: $_currentUserContact'); // Debug print
    });
  }

  Future<void> _searchUser(String contactNumber) async {
    setState(() {
      _searchResultName = null;
      _searchResultContact = null;
      _errorMessage = null;
    });

    if (contactNumber.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a contact number.';
      });
      return;
    }

    // Get current user's contact number from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final currentUserContact = prefs.getString('contact_no'); // Assuming you store this on login/signup

    if (currentUserContact == contactNumber) {
      setState(() {
        _errorMessage = 'You cannot send a friend request to yourself.';
      });
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(contactNumber)
          .get();

      if (userDoc.exists) {
        setState(() {
          _searchResultName = userDoc['name'];
          _searchResultContact = contactNumber;
        });
      } else {
        setState(() {
          _errorMessage = 'User not found.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error searching user: ${e.toString()}';
      });
    }
  }

  Future<void> _sendFriendRequest(String recipientContact) async {
    final prefs = await SharedPreferences.getInstance();
    final senderContact = prefs.getString('contact_no');
    final senderName = prefs.getString('name'); // Assuming sender's name is also stored

    if (senderContact == null || senderName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Sender information not found.')),
      );
      return;
    }

    // Check if a request already exists or if they are already friends
    final existingRequest = await FirebaseFirestore.instance
        .collection('friend_requests')
        .where('senderContact', isEqualTo: senderContact)
        .where('recipientContact', isEqualTo: recipientContact)
        .get();

    final existingReverseRequest = await FirebaseFirestore.instance
        .collection('friend_requests')
        .where('senderContact', isEqualTo: recipientContact)
        .where('recipientContact', isEqualTo: senderContact)
        .get();

    if (existingRequest.docs.isNotEmpty || existingReverseRequest.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request already sent or pending.')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('friend_requests').add({
        'senderContact': senderContact,
        'senderName': senderName,
        'recipientContact': recipientContact,
        'status': 'pending', // 'pending', 'accepted', 'rejected'
        'timestamp': Timestamp.now(),
      });

      if (mounted) {
        Navigator.of(context).pop(); // Close the dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Friend request sent to $_searchResultName!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send request: ${e.toString()}')),
      );
    }
  }

  void _showSendRequestDialog() {
    _searchController.clear();
    _searchResultName = null;
    _searchResultContact = null;
    _errorMessage = null;

    // Use ValueNotifier to manage state within the dialog more cleanly
    final ValueNotifier<String?> searchResultNameNotifier = ValueNotifier(null);
    final ValueNotifier<String?> searchResultContactNotifier = ValueNotifier(null);
    final ValueNotifier<String?> errorMessageNotifier = ValueNotifier(null);
    final ValueNotifier<bool> isLoadingNotifier = ValueNotifier(false);

    Future<void> dialogSearchUser(String contactNumber) async {
      isLoadingNotifier.value = true;
      searchResultNameNotifier.value = null;
      searchResultContactNotifier.value = null;
      errorMessageNotifier.value = null;

      if (contactNumber.isEmpty) {
        errorMessageNotifier.value = 'Please enter a contact number.';
        isLoadingNotifier.value = false;
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final currentUserContact = prefs.getString('contact_no');

      if (currentUserContact == contactNumber) {
        errorMessageNotifier.value = 'You cannot send a friend request to yourself.';
        isLoadingNotifier.value = false;
        return;
      }

      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(contactNumber)
            .get();

        if (userDoc.exists) {
          searchResultNameNotifier.value = userDoc['name'];
          searchResultContactNotifier.value = contactNumber;
        } else {
          errorMessageNotifier.value = 'User not found.';
        }
      } catch (e) {
        errorMessageNotifier.value = 'Error searching user: ${e.toString()}';
      } finally {
        isLoadingNotifier.value = false;
      }
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
          title: Row(
            children: [
              Icon(Icons.person_add, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Text(
                'Send Friend Request',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Enter Contact Number',
                    labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    prefixIcon: Icon(Icons.phone_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    suffixIcon: ValueListenableBuilder<bool>(
                      valueListenable: isLoadingNotifier,
                      builder: (context, isLoading, child) {
                        if (isLoading) {
                          return const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        }
                        return IconButton(
                          icon: Icon(Icons.search, color: Theme.of(context).colorScheme.primary),
                          onPressed: () => dialogSearchUser(_searchController.text),
                        );
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  keyboardType: TextInputType.phone,
                  onSubmitted: (value) => dialogSearchUser(value),
                ),
                const SizedBox(height: 20),
                ValueListenableBuilder<String?>(
                  valueListenable: searchResultNameNotifier,
                  builder: (context, searchResultName, child) {
                    return ValueListenableBuilder<String?>(
                      valueListenable: errorMessageNotifier,
                      builder: (context, errorMessage, child) {
                        if (isLoadingNotifier.value) {
                          return const SizedBox.shrink(); // Hide results while loading
                        } else if (searchResultName != null) {
                          return Column(
                            children: [
                              Text(
                                'Found User: $searchResultName',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton.icon(
                                onPressed: () {
                                  _sendFriendRequest(searchResultContactNotifier.value!);
                                },
                                icon: const Icon(Icons.person_add_alt_1),
                                label: const Text('Send Request'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                ),
                              ),
                            ],
                          );
                        } else if (errorMessage != null) {
                          return Text(
                            errorMessage,
                            style: TextStyle(color: Theme.of(context).colorScheme.error),
                            textAlign: TextAlign.center,
                          );
                        } else {
                          return const SizedBox.shrink();
                        }
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateFriendRequestStatus(String requestId, String status, String senderContact, String senderName) async {
    try {
      if (status == 'accepted') {
        // Get current user's name
        final prefs = await SharedPreferences.getInstance();
        final currentUserContact = prefs.getString('contact_no');
        final currentUserName = prefs.getString('name');

        if (currentUserContact == null || currentUserName == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: Current user information not found.')),
          );
          return;
        }

        // Add sender to current user's friends list
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserContact)
            .collection('friends')
            .doc(senderContact)
            .set({
          'name': senderName,
          'contact_no': senderContact,
          'addedAt': Timestamp.now(),
        });

        // Add current user to sender's friends list
        await FirebaseFirestore.instance
            .collection('users')
            .doc(senderContact)
            .collection('friends')
            .doc(currentUserContact)
            .set({
          'name': currentUserName,
          'contact_no': currentUserContact,
          'addedAt': Timestamp.now(),
        });

        // Delete the friend request
        await FirebaseFirestore.instance.collection('friend_requests').doc(requestId).delete();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Friend request from $senderName accepted!')),
        );
      } else if (status == 'rejected') {
        // Delete the friend request
        await FirebaseFirestore.instance.collection('friend_requests').doc(requestId).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Friend request from $senderName rejected.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update request: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserContact == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('friend_requests')
            .where('recipientContact', isEqualTo: _currentUserContact)
            .where('status', isEqualTo: 'pending')
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
                    Icons.people_outline,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No Friend Requests',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'When someone sends you a friend request,\nit will appear here.',
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

          final requests = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              final senderName = request['senderName'] ?? 'Unknown User';
              final requestId = request.id;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$senderName sent you a friend request.',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () => _updateFriendRequestStatus(requestId, 'accepted', request['senderContact'], request['senderName']),
                        child: const Text('Accept'),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: () => _updateFriendRequestStatus(requestId, 'rejected', request['senderContact'], request['senderName']),
                        child: const Text('Reject'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat, // Moved to bottom-right
      floatingActionButton: FloatingActionButton(
        onPressed: _showSendRequestDialog,
        child: const Icon(Icons.person_add),
      ),
    );
  }
}
