import 'package:flutter/material.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          '如果你看到这行字，说明基础框架没问题',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    ),
  ));
}
