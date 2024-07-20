import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ViewFarmersPage extends StatefulWidget {
  @override
  _ViewFarmersPageState createState() => _ViewFarmersPageState();
}

class _ViewFarmersPageState extends State<ViewFarmersPage> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> farmers = [];
  List<Map<String, dynamic>> filteredFarmers = [];
  bool isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  Map<String, String> currentSortings = {};

  @override
  void initState() {
    super.initState();
    _loadFarmersData();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
        filteredFarmers = List.from(farmers);
        isLoading = false;
      });
      _animationController.forward();
    } else {
      await _fetchDataFromFirestore();
    }
  }

  Future<void> _fetchDataFromFirestore() async {
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance.collection('farmers').get();
      List<Map<String, dynamic>> fetchedFarmers = querySnapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        data['Farmer Name'] = doc.id;
        data['Area'] = (data['Area'] as num).toInt();
        return data;
      }).toList();

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('farmers_data', json.encode(fetchedFarmers));

      setState(() {
        farmers = fetchedFarmers;
        filteredFarmers = List.from(farmers);
        isLoading = false;
      });
      _animationController.forward();
    } catch (e) {
      print('Error fetching data from Firestore: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      filteredFarmers = List.from(farmers);
      currentSortings.forEach((column, value) {
        filteredFarmers = filteredFarmers.where((farmer) =>
        farmer[column].toString().toLowerCase() == value.toLowerCase()
        ).toList();
      });

      filteredFarmers.sort((a, b) {
        for (var entry in currentSortings.entries) {
          int comparison;
          if (entry.key == 'Area') {
            comparison = (a[entry.key] as int).compareTo(b[entry.key] as int);
          } else {
            comparison = a[entry.key].toString().compareTo(b[entry.key].toString());
          }
          if (comparison != 0) return comparison;
        }
        return 0;
      });
    });
  }

  Future<void> _showSortingDialog(String column) async {
    List<String> values = farmers.map((f) => f[column].toString()).toSet().toList();
    values.sort();

    String? selectedValue = await showCupertinoDialog<String>(
      context: context,
      builder: (BuildContext context) {
        String tempSelectedValue = values.first;
        return CupertinoAlertDialog(
          title: Text('Filter by $column'),
          content: Container(
            height: 200,
            child: CupertinoPicker(
              itemExtent: 32.0,
              onSelectedItemChanged: (index) {
                tempSelectedValue = values[index];
              },
              children: values.map((value) => Text(value)).toList(),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              child: Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            CupertinoDialogAction(
              child: Text('Apply'),
              onPressed: () => Navigator.pop(context, tempSelectedValue),
            ),
          ],
        );
      },
    );

    if (selectedValue != null) {
      setState(() {
        currentSortings[column] = selectedValue;
      });
      _applyFilters();
    }
  }

  Future<void> _showEditDialog(Map<String, dynamic> farmer, String column) async {
    if (column == 'Date of TP') {
      DateTime currentDate = DateTime.parse(farmer[column]);
      DateTime? newDate = await showCupertinoModalPopup<DateTime>(
        context: context,
        builder: (BuildContext context) {
          return Container(
            height: 216,
            color: CupertinoColors.systemBackground.resolveFrom(context),
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: currentDate,
              onDateTimeChanged: (DateTime newDateTime) {
                currentDate = newDateTime;
              },
            ),
          );
        },
      );

      if (newDate != null) {
        setState(() {
          farmer[column] = DateFormat('yyyy-MM-dd').format(newDate);
        });
        _updateLocalStorage();
        _syncWithFirestore(farmer);
        _applyFilters();
      }
    } else {
      String? newValue = await showCupertinoDialog<String>(
        context: context,
        builder: (BuildContext context) {
          final TextEditingController _controller = TextEditingController(text: farmer[column].toString());
          return CupertinoAlertDialog(
            title: Text('Edit $column'),
            content: CupertinoTextField(
              controller: _controller,
              autofocus: true,
              keyboardType: column == 'Area' ? TextInputType.number : TextInputType.text,
            ),
            actions: [
              CupertinoDialogAction(
                child: Text('Cancel'),
                onPressed: () => Navigator.pop(context),
              ),
              CupertinoDialogAction(
                child: Text('Update'),
                onPressed: () => Navigator.pop(context, _controller.text),
              ),
            ],
          );
        },
      );

      if (newValue != null && newValue != farmer[column].toString()) {
        setState(() {
          if (column == 'Area') {
            farmer[column] = int.parse(newValue);
          } else if (column == 'Village') {
            farmer[column] = _capitalizeFirstLetter(newValue);
          } else {
            farmer[column] = newValue;
          }
        });
        _updateLocalStorage();
        _syncWithFirestore(farmer);
        _applyFilters();
      }
    }
  }

  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  void _updateLocalStorage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('farmers_data', json.encode(farmers));
  }

  void _syncWithFirestore(Map<String, dynamic> farmer) async {
    try {
      String farmerId = farmer['Farmer Name'];
      Map<String, dynamic> updateData = Map.from(farmer);
      updateData.remove('Farmer Name');

      await FirebaseFirestore.instance
          .collection('farmers')
          .doc(farmerId)
          .update(updateData);
    } catch (e) {
      print('Error syncing with Firestore: $e');
    }
  }

  void _clearFilters() {
    setState(() {
      currentSortings.clear();
      filteredFarmers = List.from(farmers);
    });
  }

  Future<void> _showAddFarmerDialog() async {
    String name = '';
    String village = '';
    int area = 0;
    DateTime dateOfTP = DateTime.now();

    await showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return CupertinoAlertDialog(
              title: Text('Add New Farmer'),
              content: Column(
                children: [
                  CupertinoTextField(
                    placeholder: 'Name',
                    onChanged: (value) => name = value,
                  ),
                  SizedBox(height: 8),
                  CupertinoTextField(
                    placeholder: 'Village',
                    onChanged: (value) => village = _capitalizeFirstLetter(value),
                  ),
                  SizedBox(height: 8),
                  CupertinoTextField(
                    placeholder: 'Area',
                    keyboardType: TextInputType.number,
                    onChanged: (value) => area = int.tryParse(value) ?? 0,
                  ),
                  SizedBox(height: 8),
                  CupertinoButton(
                    child: Text(DateFormat('dd/MM/yyyy').format(dateOfTP)),
                    onPressed: () {
                      showCupertinoModalPopup(
                        context: context,
                        builder: (BuildContext context) {
                          return Container(
                            height: 216,
                            color: CupertinoColors.systemBackground.resolveFrom(context),
                            child: CupertinoDatePicker(
                              mode: CupertinoDatePickerMode.date,
                              initialDateTime: dateOfTP,
                              onDateTimeChanged: (DateTime newDateTime) {
                                setState(() {
                                  dateOfTP = newDateTime;
                                });
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
              actions: [
                CupertinoDialogAction(
                  child: Text('Cancel'),
                  onPressed: () => Navigator.pop(context),
                ),
                CupertinoDialogAction(
                  child: Text('Save'),
                  onPressed: () {
                    _addNewFarmer(name, village, area, dateOfTP);
                    Navigator.pop(context);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _addNewFarmer(String name, String village, int area, DateTime dateOfTP) {
    Map<String, dynamic> newFarmer = {
      'Farmer Name': name,
      'Village': village,
      'Area': area,
      'Date of TP': DateFormat('dd/MM/yyyy').format(dateOfTP),
    };

    setState(() {
      farmers.add(newFarmer);
      filteredFarmers = List.from(farmers);
    });

    _updateLocalStorage();
    _syncNewFarmerWithFirestore(newFarmer);
  }

  void _syncNewFarmerWithFirestore(Map<String, dynamic> farmer) async {
    try {
      await FirebaseFirestore.instance
          .collection('farmers')
          .doc(farmer['Farmer Name'])
          .set(farmer);
    } catch (e) {
      print('Error syncing new farmer with Firestore: $e');
    }
  }

  Future<void> _showFarmerNameOptions(Map<String, dynamic> farmer) async {
    await showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            child: Text('Edit'),
            onPressed: () {
              Navigator.pop(context);
              _showEditDialog(farmer, 'Farmer Name');
            },
          ),
          CupertinoActionSheetAction(
            child: Text('Delete'),
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _deleteFarmer(farmer);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: Text('Cancel'),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _deleteFarmer(Map<String, dynamic> farmer) {
    setState(() {
      farmers.remove(farmer);
      filteredFarmers = List.from(farmers);
    });

    _updateLocalStorage();
    _deleteFarmerFromFirestore(farmer['Farmer Name']);
  }

  void _deleteFarmerFromFirestore(String farmerName) async {
    try {
      await FirebaseFirestore.instance
          .collection('farmers')
          .doc(farmerName)
          .delete();
    } catch (e) {
      print('Error deleting farmer from Firestore: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('View Farmers'),
        trailing: GestureDetector(
          onTap: _showAddFarmerDialog,
          child: Icon(CupertinoIcons.add, color: CupertinoColors.white),
        ),
        backgroundColor: CupertinoColors.systemIndigo.withOpacity(0.7),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFC977), Color(0xFFFF6B97)],
          ),
        ),
        child: SafeArea(
          child: isLoading
              ? Center(child: CupertinoActivityIndicator(radius: 20))
              : Column(
            children: [
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildFarmersTable(),
                ),
              ),
              if (currentSortings.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CupertinoButton(
                    color: CupertinoColors.systemIndigo,
                    child: Text('Clear Filters'),
                    onPressed: _clearFilters,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFarmersTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTableHeader(),
            ...filteredFarmers.map((farmer) => _buildFarmerRow(farmer)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      color: CupertinoColors.systemIndigo.withOpacity(0.7),
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          _buildHeaderCell('Name', 150),
          _buildHeaderCell('Village', 120, onLongPress: () => _showSortingDialog('Village')),
          _buildHeaderCell('Area', 80, onLongPress: () => _showSortingDialog('Area')),
          _buildHeaderCell('Date of TP', 100, onLongPress: () => _showSortingDialog('Date of TP')),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text, double width, {VoidCallback? onLongPress}) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        width: width,
        child: Text(
          text,
          style: TextStyle(
            color: CupertinoColors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildFarmerRow(Map<String, dynamic> farmer) {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.white.withOpacity(0.8),
        border: Border(bottom: BorderSide(color: CupertinoColors.systemGrey4)),
      ),
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          _buildCell(farmer, 'Farmer Name', 150, onLongPress: () => _showFarmerNameOptions(farmer)),
          _buildCell(farmer, 'Village', 120),
          _buildCell(farmer, 'Area', 80),
          _buildCell(farmer, 'Date of TP', 100),
        ],
      ),
    );
  }

  Widget _buildCell(Map<String, dynamic> farmer, String column, double width, {VoidCallback? onLongPress}) {
    return GestureDetector(
      onLongPress: onLongPress ?? () => _showEditDialog(farmer, column),
      child: Container(
        width: width,
        child: Text(
          column == 'Date of TP'
              ? farmer[column]
              : farmer[column]?.toString() ?? '',
          style: TextStyle(
            color: CupertinoColors.black,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}