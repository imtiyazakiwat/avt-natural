import 'package:flutter/cupertino.dart';

class CFCMainPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('CFC Main Page'),
      ),
      child: Center(
        child: Text('Welcome, CFC!'),
      ),
    );
  }
}
