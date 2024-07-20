import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'ViewFarmersPage.dart';
import '/firebase_options.dart';
import 'SettingsPage.dart';

class LanguagePreferences {
  static const String _keyLanguage = 'language';

  static Future<void> setLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguage, language);
  }

  static Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLanguage) ?? 'english';
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Farmer Data App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'SF Pro Display',
      ),
      home: MainPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainPage extends StatefulWidget {
  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _animationController;
  late List<Animation<double>> _animations;

  final List<Widget> _pages = [
    FarmerDataPage(),
    ViewFarmersPage(),
    ProfilePage(),
    MenuPage(),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _animations = List.generate(
      4,
          (index) => Tween<double>(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(index * 0.1, 1.0, curve: Curves.easeOutBack),
        ),
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (index != _currentIndex) {
      setState(() {
        _currentIndex = index;
      });
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFC977), Color(0xFFFF6B97)],
          ),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: _onTabTapped,
            backgroundColor: Colors.transparent,
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.white.withOpacity(0.6),
            type: BottomNavigationBarType.fixed,
            items: [
              _buildAnimatedNavBarItem(0, CupertinoIcons.home, 'Home'),
              _buildAnimatedNavBarItem(1, CupertinoIcons.person_2, 'Farmers'),
              _buildAnimatedNavBarItem(2, CupertinoIcons.settings, 'Settings'),
              _buildAnimatedNavBarItem(3, CupertinoIcons.bars, 'Menu'),
            ],
          ),
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildAnimatedNavBarItem(int index, IconData icon, String label) {
    return BottomNavigationBarItem(
      icon: ScaleTransition(
        scale: _animations[index],
        child: Icon(icon),
      ),
      label: label,
    );
  }
}

class FarmerDataPage extends StatefulWidget {
  @override
  _FarmerDataPageState createState() => _FarmerDataPageState();
}

class _FarmerDataPageState extends State<FarmerDataPage> with SingleTickerProviderStateMixin {
  String? selectedVillage;
  String? selectedFarmer;
  String currentLanguage = 'english';
  List<Map<String, dynamic>> farmers = [];
  bool isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String? currentFAName;
  bool hasKannadaNames = false;

  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();
    _loadFarmersData();
    _setupFirestoreListener();
    _loadCurrentFAName();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadLanguagePreference() async {
    String savedLanguage = await LanguagePreferences.getLanguage();
    setState(() {
      currentLanguage = savedLanguage;
    });
  }

  Future<void> _loadFarmersData() async {
    setState(() {
      isLoading = true;
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? storedFarmers = prefs.getString('farmers_data');

    if (storedFarmers != null) {
      setState(() {
        farmers = List<Map<String, dynamic>>.from(json.decode(storedFarmers)).map((farmer) {
          return farmer.map((key, value) => MapEntry(key, value ?? ''));
        }).toList();
        _checkForKannadaNames();
        isLoading = false;
      });
    } else {
      await _fetchAndStoreFarmersData();
    }
  }

  void _checkForKannadaNames() {
    hasKannadaNames = farmers.any((farmer) =>
    farmer['Farmer Name Kannada'] != null && farmer['Farmer Name Kannada'].toString().isNotEmpty);
  }

  Future<void> _fetchAndStoreFarmersData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userFSC = prefs.getString('userFSC');
      String? userCFC = prefs.getString('userCFC');
      String? userName = prefs.getString('userName');

      if (userFSC == null || userCFC == null || userName == null) {
        throw Exception('User data is incomplete');
      }

      String farmersPath = 'avt-data/fsc/$userFSC/$userCFC/fa_list/$userName/farmers';
      print('Fetching data from path: $farmersPath');

      FirebaseFirestore firestore = FirebaseFirestore.instance;
      QuerySnapshot querySnapshot = await firestore.collection(farmersPath).get();

      List<Map<String, dynamic>> fetchedFarmers = querySnapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        data['Farmer Name'] = doc.id;
        return data.map((key, value) => MapEntry(key, value ?? ''));
      }).toList();

      await prefs.setString('farmers_data', json.encode(fetchedFarmers));

      setState(() {
        farmers = fetchedFarmers;
        _checkForKannadaNames();
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching farmers data: $e');
      setState(() {
        isLoading = false;
      });
      showCupertinoDialog(
        context: context,
        builder: (BuildContext context) => CupertinoAlertDialog(
          title: Text('Error'),
          content: Text('Failed to load farmers data: $e'),
          actions: <CupertinoDialogAction>[
            CupertinoDialogAction(
              child: Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    }
  }

  void _setupFirestoreListener() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userFSC = prefs.getString('userFSC');
    String? userCFC = prefs.getString('userCFC');
    String? userName = prefs.getString('userName');

    if (userFSC == null || userCFC == null || userName == null) {
      print('User data is incomplete. Cannot setup Firestore listener.');
      return;
    }

    String farmersPath = 'avt-data/fsc/$userFSC/$userCFC/fa_list/$userName/farmers';
    FirebaseFirestore.instance.collection(farmersPath).snapshots().listen((snapshot) {
      _fetchAndStoreFarmersData();
    });
  }

  Future<void> _loadCurrentFAName() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userFSC = prefs.getString('userFSC');
      String? userCFC = prefs.getString('userCFC');
      String? userName = prefs.getString('userName');

      if (userFSC == null || userCFC == null || userName == null) {
        throw Exception('User data is incomplete');
      }

      String faPath = 'avt-data/fsc/$userFSC/$userCFC/fa_list/$userName';
      DocumentSnapshot docSnapshot = await FirebaseFirestore.instance.doc(faPath).get();

      if (docSnapshot.exists) {
        var data = docSnapshot.data() as Map<String, dynamic>;
        setState(() {
          currentFAName = data['name'] ?? 'Unknown FA';
        });
      } else {
        setState(() {
          currentFAName = 'Unknown FA';
        });
      }
    } catch (e) {
      print('Error fetching FA name: $e');
      setState(() {
        currentFAName = 'Unknown FA';
      });
    }
  }

  void _toggleLanguage() {
    if (hasKannadaNames) {
      setState(() {
        currentLanguage = currentLanguage == 'english' ? 'kannada' : 'english';
        LanguagePreferences.setLanguage(currentLanguage);
        selectedVillage = null;
        selectedFarmer = null;
      });
      _animationController.reset();
      _animationController.forward();
    }
  }

  String _getLocalizedText(String englishText, String kannadaText) {
    return currentLanguage == 'english' ? englishText : kannadaText;
  }

  List<String> get villages =>
      farmers.map((f) => _getLocalizedText(f['Village'] ?? '', f['Village Kannada'] ?? '') as String)
          .where((v) => v.isNotEmpty)
          .toSet()
          .toList();

  List<String> get filteredFarmers {
    if (selectedVillage == null) return [];
    return farmers
        .where((f) => _getLocalizedText(f['Village'] ?? '', f['Village Kannada'] ?? '') == selectedVillage)
        .map((f) => _getLocalizedText(f['Farmer Name'] ?? '', f['Farmer Name Kannada'] ?? '') as String)
        .where((name) => name.isNotEmpty)
        .toList();
  }

  String get formattedData {
    if (selectedFarmer == null) return '';
    var farmer = farmers.firstWhere(
          (f) => _getLocalizedText(f['Farmer Name'] ?? '', f['Farmer Name Kannada'] ?? '') == selectedFarmer,
      orElse: () => {},
    );
    if (farmer.isEmpty) return '';

    var tpDate = farmer['Date of TP'] != null ? DateFormat('dd/MM/yyyy').parse(farmer['Date of TP']) : DateTime.now();
    var currentDate = DateTime.now();
    var daysSinceTP = currentDate.difference(tpDate).inDays;

    String additionalInfo = '';
    if (farmer.containsKey('Nursery') && farmer['Nursery'] != null) {
      additionalInfo = '${farmer['Nursery']}';
    } else {
      var lotNo = (int.tryParse(farmer['Area'].toString()) ?? 0) >= 1 ? '1115' : '6500-1';
      additionalInfo = 'Lot no: $lotNo';
    }

    return '''
FSC : harugari
village: ${farmer['Village'] ?? ''}
variety : L 3
crop Age - tp : $daysSinceTP days
$additionalInfo
Acre  : ${farmer['Area'] ?? ''}
Farmar name : ${farmer['Farmer Name'] ?? ''}
FA : $currentFAName
'''.trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getLocalizedText('Farmer Data', 'ರೈತರ ಮಾಹಿತಿ'),
            style: TextStyle(color: Colors.white)
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          if (hasKannadaNames)
            Row(
              children: [
                Text('English', style: TextStyle(color: Colors.white, fontSize: 14)),
                SizedBox(width: 8),
                CupertinoSwitch(
                  value: currentLanguage == 'kannada',
                  onChanged: (bool value) {
                    _toggleLanguage();
                  },
                  activeColor: Colors.orange,
                ),
                SizedBox(width: 8),
                Text('ಕನ್ನಡ', style: TextStyle(color: Colors.white, fontSize: 14)),
              ],
            ),
          SizedBox(width: 16),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFC977), Color(0xFFFF6B97)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: isLoading
                ? CupertinoActivityIndicator(radius: 20)
                : FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildSelectionCard(),
                    SizedBox(height: 20),
                    if (selectedFarmer != null)
                      _buildFarmerDetailsCard(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      color: Colors.white.withOpacity(0.9),
      child: Padding(
        padding: EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(
              _getLocalizedText('Select Village', 'ಗ್ರಾಮವನ್ನು ಆಯ್ಕೆಮಾಡಿ'),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            SizedBox(height: 15),
            _buildIOSStyleDropdown(
              value: selectedVillage,
              items: villages,
              onChanged: (value) {
                setState(() {
                  selectedVillage = value;
                  selectedFarmer = null;
                });
              },
              placeholder: _getLocalizedText('Select Village', 'ಗ್ರಾಮವನ್ನು ಆಯ್ಕೆಮಾಡಿ'),
            ),
            SizedBox(height: 25),
            Text(
              _getLocalizedText('Select Farmer', 'ರೈತರನ್ನು ಆಯ್ಕೆಮಾಡಿ'),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            SizedBox(height: 15),
            _buildIOSStyleDropdown(
              value: selectedFarmer,
              items: filteredFarmers,
              onChanged: (value) {
                setState(() {
                  selectedFarmer = value;
                });
              },
              placeholder: _getLocalizedText('Select Farmer', 'ರೈತರನ್ನು ಆಯ್ಕೆಮಾಡಿ'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIOSStyleDropdown({
    String? value,
    required List<String> items,
    required Function(String?) onChanged,
    required String placeholder,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          value ?? placeholder,
          style: TextStyle(
              color: value != null ? Colors.black87 : Colors.grey[600]),
        ),
      ),
      onPressed: () {
        showCupertinoModalPopup(
          context: context,
          builder: (BuildContext context) =>
              CupertinoActionSheet(
                actions: items.map((item) =>
                    CupertinoActionSheetAction(
                      child: Text(item),
                      onPressed: () {
                        onChanged(item);
                        Navigator.pop(context);
                      },
                    )).toList(),
                cancelButton: CupertinoActionSheetAction(
                  child: Text(_getLocalizedText('Cancel', 'ರದ್ದುಮಾಡು')),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ),
        );
      },
    );
  }

  Widget _buildFarmerDetailsCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      color: Colors.white.withOpacity(0.9),
      child: Padding(
        padding: EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(
              _getLocalizedText('Farmer Details', 'ರೈತರ ವಿವರಗಳು'),
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            SizedBox(height: 15),
            Text(
              formattedData,
              style: TextStyle(fontSize: 16, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 25),
            CupertinoButton(
              color: CupertinoColors.activeBlue,
              borderRadius: BorderRadius.circular(10),
              child: Text(_getLocalizedText('Copy to Clipboard', 'ಕ್ಲಿಪ್‌ಬೋರ್ಡ್‌ಗೆ ನಕಲಿಸಿ')),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: formattedData));
                showCupertinoDialog(
                  context: context,
                  builder: (BuildContext context) => CupertinoAlertDialog(
                    title: Text(_getLocalizedText('Success', 'ಯಶಸ್ಸು')),
                    content: Text(_getLocalizedText('Copied to clipboard', 'ಕ್ಲಿಪ್‌ಬೋರ್ಡ್‌ಗೆ ನಕಲಿಸಲಾಗಿದೆ')),
                    actions: [
                      CupertinoDialogAction(
                        child: Text(_getLocalizedText('OK', 'ಸರಿ')),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}


class MenuPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Menu'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFC977), Color(0xFFFF6B97)],
          ),
        ),
        child: Center(
          child: Text(
            'Menu Page Content',
            style: TextStyle(color: Colors.white, fontSize: 24),
          ),
        ),
      ),
    );
  }
}