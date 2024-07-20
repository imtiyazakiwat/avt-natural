import 'package:flutter/cupertino.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'farmer/main.dart';
import 'fa/main.dart' as fa;
import 'cfc/main.dart';
// import 'admin/main.dart';

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
    return CupertinoApp(
      title: 'AVT Login/Signup',
      theme: CupertinoThemeData(
        primaryColor: CupertinoColors.activeBlue,
        barBackgroundColor: CupertinoColors.extraLightBackgroundGray,
        scaffoldBackgroundColor: CupertinoColors.white,
      ),
      home: FutureBuilder<bool>(
        future: checkLoginState(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return CupertinoActivityIndicator();
          } else {
            if (snapshot.data == true) {
              return MainPageRouter();
            } else {
              return LoginSignupPage();
            }
          }
        },
      ),
    );
  }

  Future<bool> checkLoginState() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }
}

class MainPageRouter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: getUserRole(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CupertinoActivityIndicator();
        } else {
          switch (snapshot.data) {
            case 'Farmer':
              return fa.MyApp();
            case 'FA':
              return fa.MyApp();
            case 'CFC':
              return CFCMainPage();
            case 'Admin':
              return fa.MyApp();
            default:
              return LoginSignupPage();
          }
        }
      },
    );
  }

  Future<String> getUserRole() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('userRole') ?? '';
  }
}

class LoginSignupPage extends StatefulWidget {
  @override
  _LoginSignupPageState createState() => _LoginSignupPageState();
}

class _LoginSignupPageState extends State<LoginSignupPage> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLogin = true;
  String _selectedRole = '';
  String _name = '';
  String _fsc = '';
  String _cfc = '';
  String _village = '';
  String _totalAcres = '';
  String _email = '';
  String _password = '';
  String _phoneNumber = '';

  List<String> _fscList = [];
  List<String> _cfcList = [];
  List<String> _faList = [];

  String? _selectedFSC;
  String? _selectedCFC;
  String? _selectedFA;
  String _fa = '';

  late AnimationController _animationController;
  late Animation<double> _animation;

  bool _isProcessing = false;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
    _loadFSCList();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _loadFSCList() async {
    try {
      QuerySnapshot fscSnapshot = await _firestore
          .collection('avt-data')
          .doc('fsc')
          .collection('fsc_list')
          .get();
      setState(() {
        _fscList = fscSnapshot.docs.map((doc) => doc.id).toList();
        if (_fscList.isNotEmpty) {
          _selectedFSC = _fscList[0];
          _loadCFCList(_selectedFSC!);
        }
      });
    } catch (e) {
      print('Error loading FSC list: $e');
    }
  }

  void _loadCFCList(String fsc) async {
    try {
      QuerySnapshot cfcSnapshot = await _firestore
          .collection('avt-data')
          .doc('fsc')
          .collection(fsc)
          .get();
      setState(() {
        _cfcList = cfcSnapshot.docs.map((doc) => doc.id).toList();
        if (_cfcList.isNotEmpty) {
          _selectedCFC = _cfcList[0];
          if (_selectedRole == 'Farmer') {
            _loadFAList(_selectedFSC!, _selectedCFC!);
          }
        } else {
          _selectedCFC = null;
        }
      });
    } catch (e) {
      print('Error loading CFC list: $e');
    }
  }

  void _loadFAList(String fsc, String cfc) async {
    try {
      QuerySnapshot faSnapshot = await _firestore
          .collection('avt-data')
          .doc('fsc')
          .collection(fsc)
          .doc(cfc)
          .collection('fa_list')
          .get();
      setState(() {
        _faList = faSnapshot.docs.map((doc) => doc.id).toList();
        if (_faList.isNotEmpty) {
          _selectedFA = _faList[0];
        } else {
          _selectedFA = null;
        }
      });
    } catch (e) {
      print('Error loading FA list: $e');
    }
  }

  Future<void> _handleSignUp() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isProcessing = true;
      });
      try {
        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: _email,
          password: _password,
        );
        await _register(userCredential.user!);
      } catch (e) {
        _showErrorDialog(_getErrorMessage(e));
      } finally {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isProcessing = true;
      });
      try {
        UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: _email,
          password: _password,
        );
        await _login(userCredential.user!);
      } catch (e) {
        _showErrorDialog(_getErrorMessage(e));
      } finally {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _register(User user) async {
    try {
      String uid = user.uid;
      Map<String, dynamic> userData = {
        'name': _name,
        'role': _selectedRole,
        'email': _email,
        'phoneNumber': _phoneNumber,
      };

      switch (_selectedRole) {
        case 'CFC':
          userData['fsc'] = _fsc;
          userData['totalAcres'] = _totalAcres;
          await _firestore.collection('avt-data').doc('fsc').collection('fsc_list').doc(_fsc).set({});
          await _firestore.collection('avt-data').doc('fsc').collection(_fsc).doc(_name).set(userData);
          break;
        case 'FA':
          userData['fsc'] = _selectedFSC;
          userData['cfc'] = _selectedCFC;
          userData['village'] = _village;
          userData['totalAcres'] = _totalAcres;
          await _firestore.collection('avt-data').doc('fsc').collection(_selectedFSC!).doc(_selectedCFC!).collection('fa_list').doc(_name).set(userData);
          break;
        case 'Farmer':
          userData['fsc'] = _selectedFSC;
          userData['cfc'] = _selectedCFC;
          userData['fa'] = _selectedFA;
          await _firestore
              .collection('avt-data')
              .doc('fsc')
              .collection(_selectedFSC!)
              .doc(_selectedCFC!)
              .collection('fa_list')
              .doc(_selectedFA!)
              .collection('farmers')
              .doc(_name)
              .set(userData);
          break;
      }

      await _firestore.collection('users').doc(uid).set(userData);

      await _saveLoginState(userData);
      _navigateToMainPage(userData['role']);
    } catch (e) {
      _showErrorDialog(_getErrorMessage(e));
    }
  }

  Future<void> _login(User user) async {
    try {
      String uid = user.uid;
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        if (userData['role'] == _selectedRole) {
          await _saveLoginState(userData);
          _navigateToMainPage(userData['role']);
        } else {
          _showErrorDialog('Invalid role for this user');
        }
      } else {
        _showErrorDialog('User not found');
      }
    } catch (e) {
      _showErrorDialog(_getErrorMessage(e));
    }
  }

  Future<void> _saveLoginState(Map<String, dynamic> userData) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('userRole', userData['role']);
    await prefs.setString('userName', userData['name']);
    await prefs.setString('userEmail', userData['email']);

    // Add these lines to save FSC and CFC for FA users
    if (userData['role'] == 'FA') {
      await prefs.setString('userFSC', userData['fsc']);
      await prefs.setString('userCFC', userData['cfc']);
    }
  }
  void _navigateToMainPage(String role) {
    Widget page;
    switch (role) {
      case 'Farmer':
        page = fa.MyApp();
        break;
      case 'FA':
        page = fa.MyApp();
        break;
      case 'CFC':
        page = CFCMainPage();
        break;
      case 'Admin':
        page = fa.MyApp();
        break;
      default:
        _showErrorDialog('Invalid role');
        return;
    }
    Navigator.of(context).pushReplacement(CupertinoPageRoute(builder: (context) => page));
  }

  String _getErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'No user found with this email.';
        case 'wrong-password':
          return 'Wrong password provided.';
        case 'email-already-in-use':
          return 'An account already exists for this email.';
        case 'weak-password':
          return 'The password provided is too weak.';
        case 'invalid-email':
          return 'The email address is not valid.';
        default:
          return 'An error occurred. Please try again.';
      }
    }
    return 'An unexpected error occurred. Please try again.';
  }

  void _showErrorDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: Text('Error'),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: AnimatedTextKit(
          animatedTexts: [
            WavyAnimatedText(
              _isLogin ? 'Login' : 'Sign Up',
              textStyle: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: CupertinoColors.activeBlue,
              ),
            ),
          ],
          isRepeatingAnimation: true,
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 20),
                  _buildRoleSelection(),
                  SizedBox(height: 20),
                  _buildEmailField(),
                  SizedBox(height: 10),
                  _buildPasswordField(),
                  SizedBox(height: 10),
                  _buildPhoneNumberField(),
                  SizedBox(height: 20),
                  if (!_isLogin) ..._buildSignupFields(),
                  SizedBox(height: 20),
                  _buildSubmitButton(),
                  SizedBox(height: 20),
                  _buildToggleButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Role',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildRoleIcon('Farmer', FontAwesomeIcons.leaf),
            _buildRoleIcon('FA', FontAwesomeIcons.user),
            _buildRoleIcon('CFC', FontAwesomeIcons.users),
            if (_isLogin) _buildRoleIcon('Admin', FontAwesomeIcons.userShield),
          ],
        ),
      ],
    );
  }

  Widget _buildRoleIcon(String role, IconData icon) {
    bool isSelected = _selectedRole == role;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRole = role;
          if (role == 'Farmer' && _selectedFSC != null && _selectedCFC != null) {
            _loadFAList(_selectedFSC!, _selectedCFC!);
          }
        });
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? CupertinoColors.activeBlue : CupertinoColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 40,
              color: isSelected ? CupertinoColors.white : CupertinoColors.activeBlue,
            ),
            SizedBox(height: 8),
            Text(
              role,
              style: TextStyle(
                color: isSelected ? CupertinoColors.white : CupertinoColors.activeBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return CupertinoTextFormFieldRow(
      prefix: Icon(CupertinoIcons.mail),
      placeholder: 'Email',
      keyboardType: TextInputType.emailAddress,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your email';
        }
        return null;
      },
      onChanged: (value) => _email = value,
    );
  }

  Widget _buildPasswordField() {
    return CupertinoTextFormFieldRow(
      prefix: Icon(CupertinoIcons.lock),
      placeholder: 'Password',
      obscureText: true,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your password';
        }
        return null;
      },
      onChanged: (value) => _password = value,
    );
  }

  Widget _buildPhoneNumberField() {
    return CupertinoTextFormFieldRow(
      prefix: Icon(CupertinoIcons.phone),
      placeholder: 'Phone Number',
      keyboardType: TextInputType.phone,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your phone number';
        }
        return null;
      },
      onChanged: (value) => _phoneNumber = value,
    );
  }

  Widget _buildDropdown(String label, List<String> items, String? selectedValue, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: CupertinoColors.systemGrey),
          ),
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(selectedValue ?? 'Select $label'),
                Icon(CupertinoIcons.chevron_down),
              ],
            ),
            onPressed: () {
              showCupertinoModalPopup(
                context: context,
                builder: (BuildContext context) {
                  return Container(
                    height: 200,
                    child: CupertinoPicker(
                      backgroundColor: CupertinoColors.systemBackground,
                      itemExtent: 32,
                      onSelectedItemChanged: (int index) {
                        onChanged(items[index]);
                      },
                      children: items.map((String value) {
                        return Text(value);
                      }).toList(),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  List<Widget> _buildSignupFields() {
    List<Widget> fields = [
      CupertinoTextFormFieldRow(
        prefix: Icon(CupertinoIcons.person),
        placeholder: 'Name',
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter your name';
          }
          return null;
        },
        onChanged: (value) => _name = value,
      ),
      SizedBox(height: 10),
    ];

    switch (_selectedRole) {
      case 'CFC':
        fields.addAll([
          CupertinoTextFormFieldRow(
            prefix: Icon(CupertinoIcons.building_2_fill),
            placeholder: 'FSC Name',
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter FSC name';
              }
              return null;
            },
            onChanged: (value) => _fsc = value,
          ),
          SizedBox(height: 10),
          CupertinoTextFormFieldRow(
            prefix: Icon(CupertinoIcons.resize),
            placeholder: 'Total Acres',
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter total acres';
              }
              return null;
            },
            onChanged: (value) => _totalAcres = value,
          ),
        ]);
        break;
      case 'FA':
        fields.addAll([
          _buildDropdown('FSC', _fscList, _selectedFSC, (value) {
            setState(() {
              _selectedFSC = value;
              _fsc = value!;
              _loadCFCList(_fsc);
            });
          }),
          SizedBox(height: 10),
          _buildDropdown('CFC', _cfcList, _selectedCFC, (value) {
            setState(() {
              _selectedCFC = value;
              _cfc = value!;
            });
          }),
          SizedBox(height: 10),
          CupertinoTextFormFieldRow(
            prefix: Icon(CupertinoIcons.house),
            placeholder: 'Village',
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter village';
              }
              return null;
            },
            onChanged: (value) => _village = value,
          ),
          SizedBox(height: 10),
          CupertinoTextFormFieldRow(
            prefix: Icon(CupertinoIcons.resize),
            placeholder: 'Total Acres',
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter total acres';
              }
              return null;
            },
            onChanged: (value) => _totalAcres = value,
          ),
        ]);
        break;
      case 'Farmer':
        fields.addAll([
          _buildDropdown('FSC', _fscList, _selectedFSC, (value) {
            setState(() {
              _selectedFSC = value;
              _fsc = value!;
              _loadCFCList(_fsc);
            });
          }),
          SizedBox(height: 10),
          _buildDropdown('CFC', _cfcList, _selectedCFC, (value) {
            setState(() {
              _selectedCFC = value;
              _cfc = value!;
              _loadFAList(_fsc, _cfc);
            });
          }),
          SizedBox(height: 10),
          _buildDropdown('FA', _faList, _selectedFA, (value) {
            setState(() {
              _selectedFA = value;
              _fa = value!;
            });
          }),
        ]);
        break;
    }

    return fields;
  }

  Widget _buildSubmitButton() {
    return CupertinoButton(
      child: _isProcessing
          ? CupertinoActivityIndicator()
          : Text(_isLogin ? 'Login' : 'Sign Up'),
      color: CupertinoColors.activeBlue,
      onPressed: _isProcessing ? null : (_isLogin ? _handleLogin : _handleSignUp),
    );
  }

  Widget _buildToggleButton() {
    return CupertinoButton(
      child: Text(_isLogin ? 'New user? Sign up' : 'Already have an account? Login'),
      onPressed: () {
        setState(() {
          _isLogin = !_isLogin;
          _animationController.reset();
          _animationController.forward();
        });
      },
    );
  }
}

class SpinningIcon extends StatefulWidget {
  final IconData icon;
  final Color color;

  SpinningIcon({required this.icon, required this.color});

  @override
  _SpinningIconState createState() => _SpinningIconState();
}

class _SpinningIconState extends State<SpinningIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: Icon(widget.icon, color: widget.color),
      builder: (BuildContext context, Widget? child) {
        return Transform.rotate(
          angle: _controller.value * 2.0 * math.pi,
          child: child!,
        );
      },
    );
  }
}