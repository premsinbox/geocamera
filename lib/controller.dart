import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geocamera/captureimage.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart' as loc;
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:path_provider/path_provider.dart';

class CameraLocationController extends GetxController {
  Rx<CameraController?> cameraController = Rx<CameraController?>(null);
  RxList<CameraDescription> cameras = <CameraDescription>[].obs;
  Rx<CameraDescription?> selectedCamera = Rx<CameraDescription?>(null);

  loc.Location location = loc.Location();
  Rx<loc.LocationData?> currentLocation = Rx<loc.LocationData?>(null);
  RxString currentAddress = "Loading address...".obs;
  RxString currentDateTime = "".obs;
  Rx<GoogleMapController?> mapController = Rx<GoogleMapController?>(null);

  @override
  void onInit() {
    super.onInit();
    _initializeCameras();
    _initializeLocation();
  }

  /// Initialize available cameras
  Future<void> _initializeCameras() async {
    try {
      cameras.value = await availableCameras();
      if (cameras.isNotEmpty) {
        selectedCamera.value = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
          orElse: () => cameras[0],
        );
        _initializeCamera(selectedCamera.value!);
      }
    } catch (e) {
      print("Camera initialization error: $e");
    }
  }

  /// Initialize specific camera
  Future<void> _initializeCamera(CameraDescription camera) async {
    cameraController.value = CameraController(
      camera,
      ResolutionPreset.high,
    );
    try {
      await cameraController.value?.initialize();
      cameraController.refresh();
    } catch (e) {
      print("Camera controller initialization error: $e");
    }
  }

  /// Switch camera between front and back
  void switchCamera() {
    if (cameras.isEmpty) return;

    CameraDescription newCamera;
    if (selectedCamera.value?.lensDirection == CameraLensDirection.back) {
      newCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => selectedCamera.value!,
      );
    } else {
      newCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => selectedCamera.value!,
      );
    }

    _initializeCamera(newCamera);
    selectedCamera.value = newCamera;
  }

  /// Initialize location updates
  Future<void> _initializeLocation() async {
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) return;
    }

    loc.PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == loc.PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != loc.PermissionStatus.granted) return;
    }

    location.onLocationChanged.listen((loc.LocationData currentLocationData) async {
      currentLocation.value = currentLocationData;
      currentDateTime.value = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      if (currentLocationData.latitude != null && currentLocationData.longitude != null) {
        try {
          List<geocoding.Placemark> placemarks = await geocoding.placemarkFromCoordinates(
            currentLocationData.latitude!,
            currentLocationData.longitude!,
          );

          if (placemarks.isNotEmpty) {
            geocoding.Placemark place = placemarks[0];
            currentAddress.value = 
              "${place.street}, ${place.locality}, ${place.administrativeArea}, ${place.country}";
          }
        } catch (e) {
          print("Address fetch error: $e");
        }
      }
    });
  }

Future<void> captureImage(BuildContext context) async {
    if (cameraController.value == null || !cameraController.value!.value.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Camera is not ready")),
      );
      return;
    }

    try {
      // Capture the image
      final XFile image = await cameraController.value!.takePicture();

      // Load the image as bytes
      final ui.Image originalImage = await decodeImageFromList(await image.readAsBytes());

      // Create a new image with the overlay
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      final Paint paint = Paint();

      // Draw the original image onto the canvas
      canvas.drawImage(originalImage, Offset.zero, paint);

      // Add the details as text
      final double textPadding = 10.0;
      final String details = '''
Address: ${currentAddress.value ?? 'Unavailable'}
Latitude: ${currentLocation.value?.latitude?.toStringAsFixed(6) ?? 'Unavailable'}
Longitude: ${currentLocation.value?.longitude?.toStringAsFixed(6) ?? 'Unavailable'}
Date & Time: ${currentDateTime.value ?? 'Unavailable'}
''';

      // Create a TextPainter directly with TextDirection
      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: details,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            backgroundColor: Colors.black54,
          ),
        ),
        textDirection: TextDirection.ltr, // Explicitly set text direction
      );

      // Layout the text before painting
      textPainter.layout(
        minWidth: 0,
        maxWidth: originalImage.width.toDouble() - textPadding * 2,
      );

      // Draw the text onto the image
      textPainter.paint(canvas, Offset(textPadding, originalImage.height - textPainter.height - textPadding));

      // Finish recording the canvas
      final ui.Image finalImage = await recorder.endRecording().toImage(
            originalImage.width,
            originalImage.height,
          );

      // Convert the final image to bytes
      final ByteData? byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) throw Exception("Failed to process image");

      // Save the image
      final Directory directory = await getApplicationDocumentsDirectory();
      final File savedImage = File('${directory.path}/${DateTime.now().millisecondsSinceEpoch}.png');
      await savedImage.writeAsBytes(byteData.buffer.asUint8List());

      // Show a preview of the captured image
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image saved at ${savedImage.path}')),
      );

      // Navigate to preview screen
      Get.to(() => ImagePreviewScreen(imagePath: savedImage.path));
    } catch (e) {
      print("Error capturing image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to capture image: $e")),
      );
    }
  }

  @override
  void onClose() {
    cameraController.value?.dispose();
    mapController.value?.dispose();
    super.onClose();
  }
}