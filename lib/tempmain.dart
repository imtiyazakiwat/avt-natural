import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'firebase_options.dart';

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
      home: FarmerDataPage(),
    );
  }
}

class FarmerDataPage extends StatefulWidget {
  @override
  _FarmerDataPageState createState() => _FarmerDataPageState();
}

class _FarmerDataPageState extends State<FarmerDataPage> {
  String? selectedVillage;
  String? selectedFarmer;
  String currentLanguage = 'english';
  List<Map<String, dynamic>> farmers = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();
    _loadFarmersData();
    _setupFirestoreListener();
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
        farmers = List<Map<String, dynamic>>.from(json.decode(storedFarmers));
        isLoading = false;
      });
    } else {
      await _fetchAndStoreFarmersData();
    }
  }

  Future<void> _fetchAndStoreFarmersData() async {
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    QuerySnapshot querySnapshot = await firestore.collection('farmers').get();

    List<Map<String, dynamic>> fetchedFarmers = querySnapshot.docs.map((doc) {
      var data = doc.data() as Map<String, dynamic>;
      data['Farmer Name'] = doc.id;
      return data;
    }).toList();

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('farmers_data', json.encode(fetchedFarmers));

    setState(() {
      farmers = fetchedFarmers;
      isLoading = false;
    });
  }

  void _setupFirestoreListener() {
    FirebaseFirestore.instance.collection('farmers').snapshots().listen((snapshot) {
      _fetchAndStoreFarmersData();
    });
  }

  void _toggleLanguage() {
    setState(() {
      currentLanguage = currentLanguage == 'english' ? 'kannada' : 'english';
      LanguagePreferences.setLanguage(currentLanguage);
      selectedVillage = null;
      selectedFarmer = null;
    });
  }

  String _getLocalizedText(String englishText, String kannadaText) {
    return currentLanguage == 'english' ? englishText : kannadaText;
  }

  List<String> get villages =>
      farmers.map((f) => _getLocalizedText(f['Village'], f['Village Kannada']) as String).toSet().toList();

  List<String> get filteredFarmers {
    if (selectedVillage == null) return [];
    return farmers
        .where((f) => _getLocalizedText(f['Village'], f['Village Kannada']) == selectedVillage)
        .map((f) => _getLocalizedText(f['Farmer Name'], f['Farmer Name Kannada']) as String)
        .toList();
  }

  String get formattedData {
    if (selectedFarmer == null) return '';
    var farmer = farmers.firstWhere((f) => _getLocalizedText(f['Farmer Name'], f['Farmer Name Kannada']) == selectedFarmer);
    var tpDate = DateFormat('dd/MM/yyyy').parse(farmer['Date of TP']);
    var currentDate = DateTime.now();
    var daysSinceTP = currentDate.difference(tpDate).inDays;

    String additionalInfo = '';
    if (farmer.containsKey('Nursery') && farmer['Nursery'] != null) {
      additionalInfo = '${farmer['Nursery']}';
    } else {
      var lotNo = farmer['Area'] >= 1 ? '1115' : '6500-1';
      additionalInfo = 'Lot no: $lotNo';
    }

    return '''
FSC : Harugari
village: ${farmer['Village']}
variety : L 3
crop Age - tp : $daysSinceTP days
$additionalInfo
Acre  : ${farmer['Area']}
Farmar name : ${farmer['Farmer Name']}
FA : Ilayi Akiwat
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
                ? CircularProgressIndicator()
                : SingleChildScrollView(
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