import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../LoginPage.dart' as login;

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic> userInfo = {};
  bool isLoading = true;
  bool _mounted = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  @override
  void dispose() {
    _mounted = false;
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    if (!_mounted) return;

    setState(() {
      isLoading = true;
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userFSC = prefs.getString('userFSC');
    String? userCFC = prefs.getString('userCFC');
    String? userName = prefs.getString('userName');

    print('Debug: Loading user info for FSC: $userFSC, CFC: $userCFC, Name: $userName');

    if (userFSC == null || userCFC == null || userName == null) {
      print('Debug: User data not found in SharedPreferences');
      if (_mounted) {
        setState(() {
          isLoading = false;
        });
      }
      return;
    }

    try {
      DocumentSnapshot docSnapshot = await FirebaseFirestore.instance
          .collection('avt-data')
          .doc('fsc')
          .collection(userFSC)
          .doc(userCFC)
          .collection('fa_list')
          .doc(userName)
          .get();

      if (docSnapshot.exists) {
        print('Debug: Document found in Firestore');
        if (_mounted) {
          setState(() {
            userInfo = docSnapshot.data() as Map<String, dynamic>;
            isLoading = false;
          });
        }
      } else {
        print('Debug: Document not found in Firestore. Attempting to find correct document.');
        QuerySnapshot querySnapshot = await FirebaseFirestore.instance
            .collection('avt-data')
            .doc('fsc')
            .collection(userFSC)
            .doc(userCFC)
            .collection('fa_list')
            .where('name', isEqualTo: userName)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          DocumentSnapshot correctDoc = querySnapshot.docs.first;
          print('Debug: Correct document found. Updating SharedPreferences.');
          await prefs.setString('userName', correctDoc.id);
          if (_mounted) {
            setState(() {
              userInfo = correctDoc.data() as Map<String, dynamic>;
              isLoading = false;
            });
          }
        } else {
          print('Debug: No matching document found in Firestore');
          if (_mounted) {
            setState(() {
              isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      print('Error loading user info: $e');
      if (_mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _editUserInfo(String key) async {
    if (key == 'fsc' || key == 'cfc') {
      print('Debug: Attempt to edit unchangeable field $key');
      return;
    }

    print('Debug: Editing $key');
    String initialValue = userInfo[key]?.toString() ?? '';
    TextEditingController _controller = TextEditingController(text: initialValue);

    String? result = await showCupertinoDialog<String>(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text('Edit $key'),
        content: CupertinoTextField(
          controller: _controller,
          autofocus: true,
        ),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(context, null),
          ),
          CupertinoDialogAction(
            child: Text('Save'),
            onPressed: () => Navigator.pop(context, _controller.text),
          ),
        ],
      ),
    );

    print('Debug: Dialog result for $key: $result');

    if (result != null) {
      print('Debug: Attempting to update $key to $result');
      bool updated = await _updateFirestore(key, result);
      print('Debug: Firestore update result: $updated');
      if (updated && _mounted) {
        setState(() {
          userInfo[key] = result;
        });
        print('Debug: Updated userInfo[$key] to $result');
      } else {
        print('Debug: Failed to update userInfo[$key]');
      }
    } else {
      print('Debug: Update canceled for $key');
    }
  }

  Future<bool> _updateFirestore(String key, String value) async {
    print('Debug: _updateFirestore called with key: $key, value: $value');
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userFSC = prefs.getString('userFSC');
    String? userCFC = prefs.getString('userCFC');
    String? userName = prefs.getString('userName');

    print('Debug: User data for Firestore update - FSC: $userFSC, CFC: $userCFC, Name: $userName');

    if (userFSC == null || userCFC == null || userName == null) {
      print('Debug: User data not found for Firestore update');
      return false;
    }

    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();

      // Reference to the FA document
      DocumentReference faDocRef = FirebaseFirestore.instance
          .collection('avt-data')
          .doc('fsc')
          .collection(userFSC)
          .doc(userCFC)
          .collection('fa_list')
          .doc(userName);

      // Update the FA document
      batch.update(faDocRef, {key: value});

      // If the key is 'name', update the fa_list entry and create a new document
      if (key == 'name') {
        DocumentReference cfcDocRef = FirebaseFirestore.instance
            .collection('avt-data')
            .doc('fsc')
            .collection(userFSC)
            .doc(userCFC);

        // Update the fa_list map
        batch.update(cfcDocRef, {
          'fa_list.$userName': FieldValue.delete(),
          'fa_list.$value': value
        });

        // Create a new document with the new name
        DocumentReference newFaDocRef = cfcDocRef
            .collection('fa_list')
            .doc(value);

        // Copy data from old document to new document
        DocumentSnapshot oldDoc = await faDocRef.get();
        if (oldDoc.exists) {
          batch.set(newFaDocRef, oldDoc.data() as Map<String, dynamic>);
          batch.delete(faDocRef);
        }

        // Update the farmers data path
        CollectionReference oldFarmersRef = cfcDocRef.collection('fa_list').doc(userName).collection('farmers');
        CollectionReference newFarmersRef = cfcDocRef.collection('fa_list').doc(value).collection('farmers');

        QuerySnapshot farmersSnapshot = await oldFarmersRef.get();
        for (var doc in farmersSnapshot.docs) {
          await newFarmersRef.doc(doc.id).set(doc.data());
          await doc.reference.delete();
        }

        // Update SharedPreferences with the new name
        await prefs.setString('userName', value);

        // Notify ViewFarmersPage of the change
        await prefs.setBool('userNameChanged', true);
      }

      await batch.commit();

      print('Debug: Updated $key to $value in Firestore');
      return true;
    } catch (e) {
      print('Error updating Firestore: $e');
      print('Error stack trace: ${StackTrace.current}');
      return false;
    }
  }

  void _logout() async {
    print('Debug: Logging out');
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.of(context).pushAndRemoveUntil(
      CupertinoPageRoute(builder: (context) => login.MyApp()),
          (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Profile'),
        backgroundColor: CupertinoColors.systemIndigo.withOpacity(0.7),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [CupertinoColors.systemIndigo, CupertinoColors.systemPink],
          ),
        ),
        child: SafeArea(
          child: isLoading
              ? Center(child: CupertinoActivityIndicator())
              : ListView(
            padding: EdgeInsets.all(16.0),
            children: [
              SizedBox(height: 20),
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: CupertinoColors.systemGrey5,
                ),
                child: Icon(CupertinoIcons.person_fill,
                    size: 80, color: CupertinoColors.systemGrey),
              ),
              SizedBox(height: 30),
              ...userInfo.entries
                  .where((entry) => entry.key != 'role')
                  .map((entry) => _buildInfoTile(entry.key, entry.value.toString())),
              SizedBox(height: 30),
              CupertinoButton(
                color: CupertinoColors.destructiveRed,
                child: Text('Logout'),
                onPressed: _logout,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: GestureDetector(
        onTap: title != 'fsc' && title != 'cfc' ? () => _editUserInfo(title) : null,
        child: Container(
          decoration: BoxDecoration(
            color: CupertinoColors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: CupertinoColors.systemGrey5,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}