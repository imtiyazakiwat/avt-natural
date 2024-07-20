import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';


void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Farmer Data App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'SF Pro Display', // iOS-style font
      ),
      home: UploadDataPage(),
    );
  }
}


class UploadDataPage extends StatelessWidget {
  List<Map<String, dynamic>> farmers = [
    {
      "Farmer Name": "Maiboob Mujawar",
      "Farmer Name Kannada": "ಮೈಬೂಬ್ ಮುಜಾವರ್",
      "Village": "Kodaganur",
      "Village Kannada": "ಕೊಡಗಾನೂರು",
      "Area": 0.5,
      "Date of TP": "27/06/2024",
      "Nursery": "`Dawanagere Nursery`"
    },
    {
      "Farmer Name": "Vidya Kare",
      "Farmer Name Kannada": "ವಿದ್ಯಾ ಕಾರೆ",
      "Village": "Karlatti",
      "Village Kannada": "ಕರ್ಲಟ್ಟಿ",
      "Area": 1,
      "Date of TP": "26/06/2024",
      "Nursery": "`Dawanagere Nursery`"
    },
    {
      "Farmer Name": "Housabai Murugyagol",
      "Farmer Name Kannada": "ಹೌಸಬಾಯಿ ಮುರುಗ್ಯಾಗೊಳ್",
      "Village": "Kokatnur",
      "Village Kannada": "ಕೋಕಟನೂರು",
      "Area": 0.5,
      "Date of TP": "21/06/2024"
    },
    {
      "Farmer Name": "Annasab Jagatap",
      "Farmer Name Kannada": "ಅನ್ನಾಸಾಬ್ ಜಗತಾಪ್",
      "Village": "Kodaganur",
      "Village Kannada": "ಕೊಡಗಾನೂರು",
      "Area": 1,
      "Date of TP": "10/06/2024"
    },
    {
      "Farmer Name": "Sikandar Mujawar",
      "Farmer Name Kannada": "ಸಿಕಂದರ್ ಮುಜಾವರ್",
      "Village": "Kodaganur",
      "Village Kannada": "ಕೊಡಗಾನೂರು",
      "Area": 1,
      "Date of TP": "16/06/2024"
    },
    {
      "Farmer Name": "Vinod Karande",
      "Farmer Name Kannada": "ವಿನೋದ್ ಕರಾಂಡೆ",
      "Village": "Kokatnur",
      "Village Kannada": "ಕೋಕಟನೂರು",
      "Area": 2,
      "Date of TP": "21/06/2024"
    },
    {
      "Farmer Name": "Ajit Maigur",
      "Farmer Name Kannada": "ಅಜಿತ್ ಮೈಗೂರ್",
      "Village": "Saptasagar",
      "Village Kannada": "ಸಪ್ತಸಾಗರ",
      "Area": 2,
      "Date of TP": "29/06/2024"
    },
    {
      "Farmer Name": "Mallesh Pol",
      "Farmer Name Kannada": "ಮಲ್ಲೇಶ್ ಪೊಳ್",
      "Village": "Kokatnur",
      "Village Kannada": "ಕೋಕಟನೂರು",
      "Area": 1,
      "Date of TP": "03/07/2024"
    },
    {
      "Farmer Name": "Balappa Kumbar",
      "Farmer Name Kannada": "ಬಳಪ್ಪ ಕುಂಬಾರ್",
      "Village": "Karlatti",
      "Village Kannada": "ಕರ್ಲಟ್ಟಿ",
      "Area": 2,
      "Date of TP": "17/06/2024"
    },
    {
      "Farmer Name": "Sadashiv Dhadake",
      "Farmer Name Kannada": "ಸದಾಶಿವ ಧಡಕೆ",
      "Village": "Kokatnur",
      "Village Kannada": "ಕೋಕಟನೂರು",
      "Area": 1,
      "Date of TP": "04/07/2024"
    },
    {
      "Farmer Name": "Tammanna Mishi",
      "Farmer Name Kannada": "ತಮ್ಮಣ್ಣ ಮಿಶಿ",
      "Village": "Kokatnur",
      "Village Kannada": "ಕೋಕಟನೂರು",
      "Area": 1,
      "Date of TP": "21/06/2024"
    },
    {
      "Farmer Name": "Laxmi Pujeri",
      "Farmer Name Kannada": "ಲಕ್ಷ್ಮಿ ಪೂಜೇರಿ",
      "Village": "Kodaganur",
      "Village Kannada": "ಕೊಡಗಾನೂರು",
      "Area": 1.5,
      "Date of TP": "19/06/2024"
    },
    {
      "Farmer Name": "Abhay Maigur",
      "Farmer Name Kannada": "ಅಭಯ್ ಮೈಗೂರ್",
      "Village": "Kodaganur",
      "Village Kannada": "ಕೊಡಗಾನೂರು",
      "Area": 1,
      "Date of TP": "10/07/2024"
    },
    {
      "Farmer Name": "Moulasab Rajapure",
      "Farmer Name Kannada": "ಮೌಲಾಸಾಬ್ ರಾಜಪುರೆ",
      "Village": "Saptasagar",
      "Village Kannada": "ಸಪ್ತಸಾಗರ",
      "Area": 2,
      "Date of TP": "08/07/2024"
    },
    {
      "Farmer Name": "Mangal Ghorpade",
      "Farmer Name Kannada": "ಮಂಗಳ ಘೋರ್ಪಡೆ",
      "Village": "Saptasagar",
      "Village Kannada": "ಸಪ್ತಸಾಗರ",
      "Area": 0.5,
      "Date of TP": "18/06/2024"
    },
    {
      "Farmer Name": "Muttappa Pattekar",
      "Farmer Name Kannada": "ಮುತ್ತಪ್ಪ ಪಟ್ಟೇಕಾರ್",
      "Village": "Saptasagar",
      "Village Kannada": "ಸಪ್ತಸಾಗರ",
      "Area": 1.5,
      "Date of TP": "18/06/2024"
    },
    {
      "Farmer Name": "Kasappa Jagadal",
      "Farmer Name Kannada": "ಕಾಸಪ್ಪ ಜಗದಾಳ",
      "Village": "Saptasagar",
      "Village Kannada": "ಸಪ್ತಸಾಗರ",
      "Area": 2,
      "Date of TP": "04/07/2024"
    },
    {
      "Farmer Name": "Ajit Koli",
      "Farmer Name Kannada": "ಅಜಿತ್ ಕೊಳಿ",
      "Village": "Kokatnur",
      "Village Kannada": "ಕೋಕಟನೂರು",
      "Area": 1,
      "Date of TP": "29/06/2024"
    },
    {
      "Farmer Name": "Maruti Ghorpade",
      "Farmer Name Kannada": "ಮಾರುತಿ ಘೋರ್ಪಡೆ",
      "Village": "Saptasagar",
      "Village Kannada": "ಸಪ್ತಸಾಗರ",
      "Area": 1,
      "Date of TP": "18/06/2024"
    },
    {
      "Farmer Name": "Anand Kadam",
      "Farmer Name Kannada": "ಆನಂದ್ ಕದಮ್",
      "Village": "Kokatnur",
      "Village Kannada": "ಕೋಕಟನೂರು",
      "Area": 0.5,
      "Date of TP": "08/07/2024"
    },
    {
      "Farmer Name": "Ramappa Maigur",
      "Farmer Name Kannada": "ರಾಮಪ್ಪ ಮೈಗೂರ್",
      "Village": "Saptasagar",
      "Village Kannada": "ಸಪ್ತಸಾಗರ",
      "Area": 1,
      "Date of TP": "29/06/2024"
    },
    {
      "Farmer Name": "Sanju Kadam",
      "Farmer Name Kannada": "ಸಂಜು ಕದಮ್",
      "Village": "Kodaganur",
      "Village Kannada": "ಕೊಡಗಾನೂರು",
      "Area": 0.5,
      "Date of TP": "16/06/2024"
    },
    {
      "Farmer Name": "Appanna Kabadagi",
      "Farmer Name Kannada": "ಅಪ್ಪಣ್ಣ ಕಬಡಗಿ",
      "Village": "Darur",
      "Village Kannada": "ದರೂರ",
      "Area": 2,
      "Date of TP": "27/06/2024"
    },
    {
      "Farmer Name": "Rekha Jagatap",
      "Farmer Name Kannada": "ರೇಖಾ ಜಗತಾಪ್",
      "Village": "Kodaganur",
      "Village Kannada": "ಕೊಡಗಾನೂರು",
      "Area": 0.5,
      "Date of TP": "20/06/2024"
    }
  ];

  Future<void> uploadData() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FirebaseFirestore firestore = FirebaseFirestore.instance;

    for (var farmer in farmers) {
      String farmerName = farmer['Farmer Name'];
      // Remove the 'Farmer Name' field from the data to be stored
      var farmerData = Map<String, dynamic>.from(farmer)..remove('Farmer Name');

      await firestore.collection('farmers').doc(farmerName).set(farmerData);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Upload Farmer Data'),
      ),
      body: Center(
        child: ElevatedButton(
          child: Text('Upload Data to Firestore'),
          onPressed: () async {
            try {
              await uploadData();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Data uploaded successfully!')),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error uploading data: $e')),
              );
            }
          },
        ),
      ),
    );
  }
}