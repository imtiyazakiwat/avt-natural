import 'package:flutter/material.dart';
import 'package:sms_advanced/sms_advanced.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const SmsSenderPage(),
    );
  }
}

class SmsSenderPage extends StatefulWidget {
  const SmsSenderPage({Key? key}) : super(key: key);

  @override
  State<SmsSenderPage> createState() => _SmsSenderPageState();
}

class _SmsSenderPageState extends State<SmsSenderPage> {
  final TextEditingController _receiverController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final SmsSender _smsSender = SmsSender();

  void _sendSms() {
    String address = _receiverController.text;
    String message = _messageController.text;

    if (address.isNotEmpty && message.isNotEmpty) {
      SmsMessage smsMessage = SmsMessage(address, message);
      _smsSender.sendSms(smsMessage);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Message sent to $address')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter both receiver and message')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Send SMS"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _receiverController,
              decoration: const InputDecoration(
                labelText: "Receiver Mobile Number",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                labelText: "Message",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _sendSms,
              child: const Text("Send"),
            ),
          ],
        ),
      ),
    );
  }
}
