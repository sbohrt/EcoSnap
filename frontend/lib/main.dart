import 'dart:io';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_foundation/path_provider_foundation.dart';

void main() async {
  // Ensure that plugin services are initialized so that `availableCameras()`
  // can be called before `runApp()`
  WidgetsFlutterBinding.ensureInitialized();

  // Obtain a list of the available cameras on the device.
  final cameras = await availableCameras();

  // Get a specific camera from the list of available cameras.
  final firstCamera = cameras.first;

  PathProviderFoundation.registerWith();

  runApp(
    MaterialApp(
      home: EcoSnap(
        camera: firstCamera,
      ),
    ),
  );
}

class EcoSnap extends StatefulWidget {
  const EcoSnap({
    super.key,
    required this.camera,
  });

  final CameraDescription camera;

  @override
  State<EcoSnap> createState() => _EcoSnapState();
}

class _EcoSnapState extends State<EcoSnap> {
  late CameraController _controller;
  late Future<void> _initializedControllerFuture;
  late String imagePath;

  @override
  void initState() {
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.ultraHigh,
    );

    _initializedControllerFuture = _controller.initialize();

    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    try {
      await _initializedControllerFuture;

      String fileName = 'image.png';

      // Get the temporary directory

      Directory tempDir = await getApplicationDocumentsDirectory();
      String filePath = join(tempDir.path, fileName);

      // Take a picture
      XFile picture = await _controller.takePicture();

      // Move the picture to the desired location
      await File(picture.path).copy(filePath);

      // Save the file path to the state
      setState(() {
        imagePath = filePath;
      });

      // You can now use 'imagePath' to pass it to another API or perform other actions
      print('Image Path: $imagePath');
    } catch (e) {
      print('Error taking picture: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: SizedBox(
        width: size.width,
        height: size.height,
        child: FittedBox(
          fit: BoxFit.cover,
          child: Stack(
            children: [
              SizedBox(
                child: SizedBox(
                  width: 100,
                  child: FutureBuilder<void>(
                      future: _initializedControllerFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done) {
                          return CameraPreview(_controller);
                        } else {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                      }),
                ),
              ),
              Positioned.fill(
                child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 2.5),
                      child: OutlinedButton(
                        onPressed: _takePicture,
                        child: null,
                        style: OutlinedButton.styleFrom(
                            shape: const CircleBorder(),
                            backgroundColor: Colors.transparent,
                            side: const BorderSide(
                                color: Colors.black, width: 0.3),
                            minimumSize: const Size.fromRadius(7)),
                      ),
                    )),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
