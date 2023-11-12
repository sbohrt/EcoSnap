import 'dart:io';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:googleapis/transcoder/v1.dart';
import 'package:path/path.dart';
import 'package:flutter/services.dart'; // Add this import for rootBundle
import 'package:path_provider/path_provider.dart'; // Add this import for path_provider
import 'package:image/image.dart' as img;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_vision/google_vision.dart';
import 'package:googleapis/vision/v1.dart' as vision_api; // Prefixed import
import 'package:googleapis/vision/v1.dart' as vision;
import 'package:googleapis_auth/auth_io.dart';
import 'dart:io';
import 'package:google_vision/google_vision.dart' as vision;

void main() async {
  // Ensure that plugin services are initialized so that `availableCameras()`
  // can be called before `runApp()`
  WidgetsFlutterBinding.ensureInitialized();

  // Obtain a list of the available cameras on the device.
  final cameras = await availableCameras();

  // Get a specific camera from the list of available cameras.
  final firstCamera = cameras.first;

  // Calls function to run app
  runApp(
    MaterialApp(
      title: 'EcoSnap',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.white),
        useMaterial3: true,
      ),
      // upon opening app, directly opens camera and shows picture preview
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
  String _resultText = 'Waiting for image processing...';
  bool isButtonEnabled = true;


  // initialize state variables
  @override
  void initState() {
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.ultraHigh,
    );

    _initializedControllerFuture = _controller.initialize();

    super.initState();
  }

  // eliminate state instances when closing app
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }


  // function to take the picture and move to desired path
  Future<void> _takePicture() async {
    Future<Directory?>? _tempDirectory;
    try {
      await _initializedControllerFuture;

      String fileName = 'image.png';

      // Get the temporary directory

      Directory _tempDirectory = await getTemporaryDirectory();
      String filePath = join(_tempDirectory.path, fileName);

      // Take a picture
      XFile picture = await _controller.takePicture();

      // Move the picture to the desired location
      await File(picture.path).copy(filePath);

      await _processImage(filePath);
    } catch (e) {
      print('Error taking picture: $e');
    }
  }

  // when moving on to output screen, stop showing the take picture button
  void _navigateToNextScreen(BuildContext context) async {
    setState(() {
      isButtonEnabled = false; // Disable the button when navigating away
    });

    await _takePicture();

    // go to the next screen
    if (mounted) {
      Navigator.push(
        context, 
        MaterialPageRoute(
          builder: (context) => OutputScreen(
            textResult: _resultText,
            // call back function to update state variables
            onResultSelected: (updatedResult) {
              setState(() {
               _resultText = updatedResult;
               isButtonEnabled = true;
              }
            );
          }
        )
      ),
    );
  }
  }
  // construction of camera preview
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
                        // if connection doesn't fail, show the preview
                        if (snapshot.connectionState == ConnectionState.done) {
                          return CameraPreview(_controller);
                        } else {
                          return const Center(
                            child: CircularProgressIndicator(), // add loading icon
                          );
                        }
                      }),
                ),
              ),
              Positioned.fill(
                child: Align(
                    alignment: Alignment.bottomCenter, // alligning button to take picture 
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 0),
                      child: OutlinedButton(
                        onPressed: isButtonEnabled ? () => _navigateToNextScreen(context) : null, // once picture is taken, go to next screen
                        child: null,
                        style: OutlinedButton.styleFrom(
                            shape: const CircleBorder(),
                            backgroundColor: Colors.transparent,
                            side: const BorderSide(
                                color: Colors.white, width: 1),
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
  // Modifications start here
  Future<void> _processImage(String pathName) async {
    String result = await processImage(pathName); // Wait for the result
    updateState(result); // Pass the result to update the state
  }

  // Callback function to update the state
  void updateState(String result) {
    setState(() {
      _resultText = result;
    });
  }
}

class OutputScreen extends StatefulWidget {
  const OutputScreen({
    super.key,
    required this.textResult,
    required this.onResultSelected,
  });

  final String textResult;
  final Function(String) onResultSelected;

  @override
  State<OutputScreen> createState() => _OutputScreenState();
}

class _OutputScreenState extends State<OutputScreen> {
  String outputText = "";
  
  @override
  void initState() {
    super.initState();
    outputText = widget.textResult; // Initialize with the passed textResult
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          BigCard(output: widget.textResult), // calls class that adds second screen
          Align(
            alignment: Alignment.bottomCenter,
            child: ElevatedButton(
            onPressed: (){
              widget.onResultSelected(outputText); // Use the callback to pass data
              Navigator.pop(context);
            },
            child: const Text('Take a New Picture'),
          ),
          )
        ],
      )
    );
  }
}

class BigCard extends StatelessWidget {
  const BigCard({
    super.key,
    required this.output,
  });
  
  final String output;

  
  @override
  Widget build(BuildContext context){

    final theme = Theme.of(context);
    final style = theme.textTheme.displayMedium!.copyWith(
      color: Colors.black,
      fontSize: 20.0,
    );

    return Card(
      color: theme.colorScheme.onPrimary,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          output,
          style: style,
        )
      )
    );
  }
}

Future<String> processImage(String pathName) async {
  try {
    // Initialize Google Vision API client
    final visionApi = await getVisionApiClient();

    // Load the image file from the assets
    final ByteData imageData = await rootBundle.load(pathName);
    final List<int> imageBytes = imageData.buffer.asUint8List();

    // Prepare the image for the Vision API
    final vision_api.Image visionImage = vision_api.Image();
    visionImage.contentAsBytes = imageBytes; // Updated line

    // Create an annotate image request for object detection
    final vision_api.AnnotateImageRequest request =
        vision_api.AnnotateImageRequest(
      image: visionImage,
      features: [
        vision_api.Feature(type: 'OBJECT_LOCALIZATION')
      ], // Object detection
    );

    // Call the Vision API
    final vision_api.BatchAnnotateImagesResponse response =
        await visionApi.images.annotate(
      vision_api.BatchAnnotateImagesRequest(requests: [request]),
    );

    // Process the response for object detection
    if (response.responses != null && response.responses!.isNotEmpty) {
      final objects = response.responses!.first.localizedObjectAnnotations;

      if (objects != null && objects.isNotEmpty) {
        // Concatenating names of detected objects
        String detectedObjects = objects.map((o) => o.name).join(', ');

        // Return or display the detected objects

        return displayResults(objects);
      } else {
        return 'No objects found';
      }
    } else {
      return 'Error processing image';
    }
  } catch (error) {
    print('Error processing image: $error');
    return 'Error processing image';
  }
}

Future<String> displayResults(
    List<vision_api.LocalizedObjectAnnotation> objects) async {
  if (objects.isEmpty) {
    return "No objects found";
  }

  StringBuffer results = StringBuffer('Detected Objects:\n\n');
  
  for (var object in objects) {
    double confidence = object.score ?? 0.0;
    // Await the asynchronous call to determineWasteBin
    String wasteBin = await determineWasteBin(object.name ?? 'Unknown');

    results.writeln('Object: ${object.name}');
    results.writeln('Confidence: ${(confidence * 100).toStringAsFixed(2)}%');
    results.writeln('Recommended Bin: $wasteBin');
    results.writeln('---');
    break;
  }
  print(results.toString());
  return results.toString();
}

// Define the waste bin based on the waste type
Future<String> determineWasteBin(String wasteType) async {
  // Formulate a prompt for the API
  String prompt = '''
Given environmental and recycling guidelines, should a(n) '$wasteType' be disposed of in recyclable, organic, or general waste bins? 
Please consider the most environmentally friendly option. 
Provide your answer in a two-word format, for example, "Answer: Recyclable".
''';

  // Call the ChatGPT API
  String apiResponse = await fetchResponseFromOpenAI(prompt);


  // Process the API response to categorize the waste
  // This is a simple string matching; you might need a more sophisticated approach based on the API response
  if (apiResponse.toLowerCase().contains('recyclable')) {
    return 'Recyclables Bin';
  } else if (apiResponse.toLowerCase().contains('organic')) {
    return 'Organic Waste Bin';
  } else {
    return 'General Waste Bin';
  }
}

Future<String> fetchResponseFromOpenAI(String prompt) async {
  const String apiKey =
      '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'; // Replace with your actual API key
  const String url =
      'https://api.openai.com/v1/engines/text-davinci-003/completions';

  try {
    var response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'prompt': prompt,
        'max_tokens': 50, // Adjust as needed
      }),
    );

    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      return data['choices'][0]['text']; // Extracting the text response
    } else {
      // Handle error
      print('Failed to fetch response: ${response.statusCode}');
      return 'Error: Failed to fetch response';
    }
  } catch (e) {
    // Handle error
    print('Error: $e');
    return 'Error: Exception during API call';
  }
}
Future<vision.VisionApi> getVisionApiClient() async {
  final credentialsJson =
      await rootBundle.loadString('assets/my-credentials.json');
  final credentials = ServiceAccountCredentials.fromJson(credentialsJson);
  final client = await clientViaServiceAccount(
      credentials, [vision.VisionApi.cloudVisionScope]);
  return vision.VisionApi(client);
}