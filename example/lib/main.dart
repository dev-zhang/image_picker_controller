import 'package:flutter/material.dart';
import 'package:image_picker_controller/image_picker_controller.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: FlatButton.icon(
            onPressed: () {
              ImagePickerController.pickImages(
                configuration: ImagePickerConfiguration(
                  maxImagesCount: 3,
                ),
              );
            },
            icon: Icon(Icons.add_a_photo),
            label: Text('pick image'),
          ),
        ),
      ),
    );
  }
}
