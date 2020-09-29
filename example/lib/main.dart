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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FlatButton.icon(
                onPressed: () async {
                  final result = await ImagePickerController.pickImage(
                    ImagePickerConfiguration(
                      maxImagesCount: 3,
                      allowPickingVideo: false,
                    ),
                  );
                  print('====选择照片==$result');
                },
                icon: Icon(Icons.add_a_photo),
                label: Text('选择照片'),
              ),
              FlatButton.icon(
                onPressed: () async {
                  final models = await ImagePickerController.pickVideo(
                    maxDuration: 16,
                    allowTakeVideo: false,
                  );
                  print('pick video: $models');
                },
                icon: Icon(Icons.featured_video),
                label: Text('pick video'),
              ),
              FlatButton.icon(
                onPressed: () async {
                  final result = await ImagePickerController.takeImage();
                  print('====拍摄照片: $result');
                },
                icon: Icon(Icons.image),
                label: Text('take image'),
              ),
              FlatButton.icon(
                onPressed: () async {
                  final result = await ImagePickerController.pickImage(
                    ImagePickerConfiguration(
                      maxImagesCount: 1,
                      allowPickingVideo: false,
                      allowCrop: true,
                    ),
                  );
                  print('=====单选照片+裁剪: $result');
                },
                icon: Icon(Icons.add_a_photo),
                label: Text('pick image 单选'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
