import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FarmerDataPage extends StatefulWidget {
  @override
  _FarmerDataPageState createState() => _FarmerDataPageState();
}

class _FarmerDataPageState extends State<FarmerDataPage> {
  List<Map<String, dynamic>> farmers = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFarmersData();
  }

  Future<void> _loadFarmersData() async {
    setState(() {
      isLoading = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userRole = prefs.getString('userRole');
      String? userFSC = prefs.getString('userFSC');
      String? userCFC = prefs.getString('userCFC');
      String? userName = prefs.getString('userName');

      if (userRole != 'FA' || userFSC == null || userCFC == null || userName == null) {
        throw Exception('User data is incomplete');
      }

      String farmersPath = 'avt-data/fsc/$userFSC/$userCFC/fa_list/$userName/farmers';
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance.collection(farmersPath).get();

      setState(() {
        farmers = querySnapshot.docs.map((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          data['Farmer Name'] = doc.id;
          return data;
        }).toList();
        isLoading = false;
      });
    } catch (e) {
      print('Error loading farmers data: $e');
      setState(() {
        isLoading = false;
      });
      // Show error message to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load farmers data')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('View Farmers'),
        backgroundColor: Colors.purple,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : farmers.isEmpty
          ? Center(child: Text('No farmers data available'))
          : ListView.builder(
        itemCount: farmers.length,
        itemBuilder: (context, index) {
          final farmer = farmers[index];
          return Card(
            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: ListTile(
              title: Text(farmer['Farmer Name'] ?? 'Unknown'),
              subtitle: Text('Village: ${farmer['Village'] ?? 'Unknown'}'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Area: ${farmer['Area'] ?? 'Unknown'}'),
                  Text('Date of TP: ${_formatDate(farmer['Date of TP'])}'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown';
    try {
      if (date is Timestamp) {
        return DateFormat('dd/MM/yyyy').format(date.toDate());
      } else if (date is String) {
        return date;
      }
    } catch (e) {
      print('Error formatting date: $e');
    }
    return 'Invalid Date';
  }
}