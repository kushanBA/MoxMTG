import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:path_provider/path_provider.dart';

class Objectdetectionscreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const Objectdetectionscreen({super.key, required this.cameras});

  @override
  State<Objectdetectionscreen> createState() => _ObjectdetectionscreenState();
}

class _ObjectdetectionscreenState extends State<Objectdetectionscreen> {
  late CameraController _cameraController;
  bool isCameraReady = false;
  bool isDetecting = false;
  List<DetectedObject> validCards = [];
  String results = "";

  Future<void> _initializeCamera() async {
    _cameraController = CameraController(
        widget.cameras[0], ResolutionPreset.max,
        enableAudio: false);

    await _cameraController.initialize();
    if (!mounted) return;
    setState(() {
      isCameraReady = true;
    });
    // Start capture timer

    if (!mounted || isDetecting) return;

    Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (mounted && isCameraReady && !isDetecting) {
        isDetecting = true;
        await _processImage();
      }
    });
  }

  // void _startImageStreaming() {
  //   _cameraController.startImageStream(((CameraImage image) async {
  //     if (isDetecting) return;
  //     isDetecting = true;
  //     // print('this the image frame ${image.}');
  //     Timer.periodic(Duration(seconds: 1), (timer) async {
  //       if (mounted && isCameraReady && !isDetecting) {
  //         await _processImage();
  //       }
  //     });

  //     isDetecting = false;
  //   }));
  // }

  Future<void> _processImage() async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String filePath =
          '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final File imageFile = File(filePath);

      //convert CameraImage to file
      final XFile picture = await _cameraController.takePicture();
      await picture.saveTo(imageFile.path);

      final inputImage = InputImage.fromFile(imageFile);

      await detectBox(inputImage.filePath!, 8, 10);

      // final List<ImageLabel> labels =
      //     await _imageLabeler.processImage(inputImage);

      // String detectedObjects = labels.isNotEmpty
      //     ? labels
      //         .map((label) =>
      //             '${label.label} - ${(label.confidence * 100).toStringAsFixed(2)}%')
      //         .join(" \n")
      //     : "No Card Detected";

      // setState(() {
      //   results = detectedObjects;
      // });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error Processing Card $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> detectBox(
      String imagePath, double targetWidth, double targetHeight) async {
    final options = ObjectDetectorOptions(
      mode: DetectionMode.single,
      classifyObjects: false,
      multipleObjects: true,
    );

    final objectDetector = ObjectDetector(options: options);
    final inputImage = InputImage.fromFilePath(imagePath);

    final objects = await objectDetector.processImage(inputImage);

    // Filter objects by MTG card aspect ratio
    validCards = objects.where((object) {
      double aspectRatio = object.boundingBox.width / object.boundingBox.height;
      return (aspectRatio - 0.716).abs() < 0.05;
    }).toList();
    if (validCards.isNotEmpty) {
      // Optionally: pick the largest object if multiple match
      validCards.sort((a, b) => (b.boundingBox.width * b.boundingBox.height)
          .compareTo(a.boundingBox.width * a.boundingBox.height));
      final rect = validCards.first.boundingBox;

      print("Box found with size approximately ${rect.width}x${rect.height}");
      // final RecognizedText recognizedText =
      //     await textRecognizer.processImage(inputImage);

      // String text = recognizedText.text;
      // for (TextBlock block in recognizedText.blocks) {
      //   final recText = block.text;
      //   print(recText);
      //   results = recText;
      // }

      // setState(() {
      //   results = text;
      //   // "${rect.width.toStringAsFixed(1)} x ${rect.height.toStringAsFixed(1)}";
      // });
      setState(() {
        results = "Found Mtg";
        isDetecting = false;
      });
    } else {
      print("No matching box found");
      setState(() {
        results = "No MTG card detected";
        isDetecting = false;
      });
    }

    objectDetector.close();
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _initializeCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(results),
      ),
      body: Column(
        children: [
          Center(
            child: SizedBox(
              width: MediaQuery.of(context).size.width,
              child: isCameraReady
                  ? CameraPreview(_cameraController)
                  : Center(
                      child: CircularProgressIndicator(),
                    ),
            ),
          ),
          Text(results)
        ],
      ),
    );
  }
}
