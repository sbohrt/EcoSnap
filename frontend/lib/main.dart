import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

void main() async {
  // Ensure that plugin services are initialized so that `availableCameras()`
  // can be called before `runApp()`
  WidgetsFlutterBinding.ensureInitialized();

  // Obtain a list of the available cameras on the device.
  final cameras = await availableCameras();

  // Get a specific camera from the list of available cameras.
  final firstCamera = cameras.first;

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

  @override
  void initState() {
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.ultraHigh,
    );

    _initializedControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<void>(
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
    );
  }
}
