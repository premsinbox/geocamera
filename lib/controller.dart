import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geocamera/captureimage.dart';
import 'package:geocamera/permission.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;


// WidgetsBindingObserver for Orientation Handling
class CameraLocationController extends GetxController with WidgetsBindingObserver {
  Rx<Orientation> currentOrientation = Orientation.portrait.obs;
  final PermissionController permissionController = Get.put(PermissionController());

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this); // Start listening for orientation changes
    _updateOrientation(); // Set initial orientation
  }

  void _updateOrientation() {
    final newOrientation = MediaQueryData.fromWindow(WidgetsBinding.instance.window).orientation;
    currentOrientation.value = newOrientation;
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    _updateOrientation(); // Update orientation on metrics change
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this); // Clean up observer
    super.onClose();
  }


// Function to start the camera preview without any mirroring
Widget buildCameraPreview() {
  if (permissionController.cameraController.value == null ||
      !permissionController.cameraController.value!.value.isInitialized) {
    return Center(child: CircularProgressIndicator());
  }

  // Determine if the current camera is the front camera
  final CameraLensDirection lensDirection =
      permissionController.cameraController.value!.description.lensDirection;

  // Front camera requires horizontal flip
  bool isFrontCamera = lensDirection == CameraLensDirection.front;

  return Center(
    child: SizedBox.expand(
      child: Transform(
        alignment: Alignment.center,
        transform: isFrontCamera
            ? Matrix4.diagonal3Values(-1.0, 1.0, 1.0) // Flip horizontally for front camera
            : Matrix4.identity(), // No transformation for other cameras
        child: CameraPreview(permissionController.cameraController.value!),
      ),
    ),
  );
}

Future<void> captureImage(BuildContext context) async {
  try {
    if (permissionController.cameraController.value == null ||
        !permissionController.cameraController.value!.value.isInitialized) {
      _showErrorSnackbar(context, "Camera is not ready");
      return;
    }

    final XFile? cameraImage = await permissionController.cameraController.value!.takePicture();
    if (cameraImage == null) {
      _showErrorSnackbar(context, "Failed to capture image");
      return;
    }


    Uint8List cameraImageBytes = await cameraImage.readAsBytes();
    img.Image? processedCameraImage = img.decodeImage(cameraImageBytes);
    if (processedCameraImage == null) {
      _showErrorSnackbar(context, "Image processing failed");
      return;
    }

    // Detect if the current camera is front-facing
    final CameraLensDirection lensDirection =
        permissionController.cameraController.value!.description.lensDirection;

    if (lensDirection == CameraLensDirection.front) {
      // Flip the image horizontally for the front camera
      processedCameraImage = img.flipHorizontal(processedCameraImage);
    }

    // Adjust rotation for left rotation and landscape
    switch (currentOrientation.value) {
      case Orientation.landscape:
        processedCameraImage = img.copyRotate(processedCameraImage, angle: -90); // Correct for landscape
        break;
      case Orientation.portrait:
        // Already handled; no rotation needed
        break;
      default:
        break;
    }

    Uint8List? mapSnapshot = await _captureMapSnapshot();
    if (mapSnapshot == null) {
      _showErrorSnackbar(context, "Failed to capture map snapshot");
      return;
    }

    img.Image? processedMapImage = img.decodeImage(mapSnapshot);
    if (processedMapImage == null) {
      _showErrorSnackbar(context, "Map image processing failed");
      return;
    }

    img.Image combinedImage = _addOverlay(
      processedCameraImage,
      processedMapImage,
      context,
    );

    final Directory? externalDir = await getExternalStorageDirectory();
    if (externalDir == null) {
      _showErrorSnackbar(context, "Could not access storage");
      return;
    }

    final Directory geoImageDir = Directory('${externalDir.path}/GeoCamera');
    await geoImageDir.create(recursive: true);

    String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    String filename = 'geocamera_$timestamp.jpg';
    File savedImage = File('${geoImageDir.path}/$filename');

    await savedImage.writeAsBytes(img.encodeJpg(combinedImage, quality: 85));

    _showSuccessSnackbar(context, 'Image saved: ${savedImage.path}');
    Get.to(() => ImagePreviewScreen(imagePath: savedImage.path));
  } catch (e) {
    print("Image capture error: $e");
    _showErrorSnackbar(context, "Capture failed: ${e.toString()}");
  }
}

// Adjusted captureImage with fixed rotation logic for left rotation
// Future<void> captureImage(BuildContext context) async {
//   try {
//     if (permissionController.cameraController.value == null ||
//         !permissionController.cameraController.value!.value.isInitialized) {
//       _showErrorSnackbar(context, "Camera is not ready");
//       return;
//     }

//     final XFile? cameraImage = await permissionController.cameraController.value!.takePicture();
//     if (cameraImage == null) {
//       _showErrorSnackbar(context, "Failed to capture image");
//       return;
//     }

//     final Orientation deviceOrientation = MediaQuery.of(context).orientation;

//     Uint8List cameraImageBytes = await cameraImage.readAsBytes();
//     img.Image? processedCameraImage = img.decodeImage(cameraImageBytes);
//     if (processedCameraImage == null) {
//       _showErrorSnackbar(context, "Image processing failed");
//       return;
//     }

//     // Adjust rotation for left rotation and landscape
//     switch (currentOrientation.value) {
//       case Orientation.landscape:
//         processedCameraImage = img.copyRotate(processedCameraImage, angle: -90); // Correct for landscape
//         break;
//       case Orientation.portrait:
//         // Already handled; no rotation needed
//         break;
//       default:
//         break;
//     }

//     Uint8List? mapSnapshot = await _captureMapSnapshot();
//     if (mapSnapshot == null) {
//       _showErrorSnackbar(context, "Failed to capture map snapshot");
//       return;
//     }

//     img.Image? processedMapImage = img.decodeImage(mapSnapshot);
//     if (processedMapImage == null) {
//       _showErrorSnackbar(context, "Map image processing failed");
//       return;
//     }

//     img.Image combinedImage = _addOverlay(
//       processedCameraImage,
//       processedMapImage,
//       context,
//     );

//     final Directory? externalDir = await getExternalStorageDirectory();
//     if (externalDir == null) {
//       _showErrorSnackbar(context, "Could not access storage");
//       return;
//     }

//     final Directory geoImageDir = Directory('${externalDir.path}/GeoCamera');
//     await geoImageDir.create(recursive: true);

//     String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
//     String filename = 'geocamera_$timestamp.jpg';
//     File savedImage = File('${geoImageDir.path}/$filename');

//     await savedImage.writeAsBytes(img.encodeJpg(combinedImage, quality: 85));

//     _showSuccessSnackbar(context, 'Image saved: ${savedImage.path}');
//     Get.to(() => ImagePreviewScreen(imagePath: savedImage.path));
//   } catch (e) {
//     print("Image capture error: $e");
//     _showErrorSnackbar(context, "Capture failed: ${e.toString()}");
//   }
// }

// Updated _addOverlay Method
img.Image _addOverlay(img.Image cameraImage, img.Image mapImage, BuildContext context) {
  final MediaQueryData mediaQuery = MediaQuery.of(context);
  final Orientation orientation = mediaQuery.orientation;

  // Fixed dimensions for map and metadata
  const int containerHeightPortrait = 300; // Fixed height for portrait
  const int containerHeightLandscape = 150; // Fixed height for landscape
  const double transparency = 0.6; // Transparency level for the background

  img.Image overlayImage = img.Image(
    width: cameraImage.width,
    height: cameraImage.height,
  );

  for (int y = 0; y < cameraImage.height; y++) {
    for (int x = 0; x < cameraImage.width; x++) {
      overlayImage.setPixel(x, y, cameraImage.getPixel(x, y));
    }
  }

  int containerHeight, containerY, padding = 20;
  img.Image resizedMap;

  if (orientation == Orientation.portrait) {
    containerHeight = containerHeightPortrait;
    containerY = overlayImage.height - containerHeight;

    resizedMap = img.copyResize(
      mapImage,
      width: 250, // Fixed width for map
      height: containerHeight - 50, // Slight adjustment for padding
    );
  } else {
    containerHeight = containerHeightLandscape;
    containerY = overlayImage.height - containerHeight;

    resizedMap = img.copyResize(
      mapImage,
      width: 200, // Fixed width for map in landscape
      height: containerHeight - 30,
    );
  }

  // Draw semi-transparent background
  for (int y = containerY; y < overlayImage.height; y++) {
    for (int x = 0; x < overlayImage.width; x++) {
      overlayImage.setPixel(x, y, img.ColorRgba8(50, 50, 50, (transparency * 255).toInt()));
    }
  }

  // Place resized map
  for (int y = 0; y < resizedMap.height; y++) {
    for (int x = 0; x < resizedMap.width; x++) {
      overlayImage.setPixel(padding + x, containerY + padding + y, resizedMap.getPixel(x, y));
    }
  }

  String details = '''
Lat: ${permissionController.currentLocation.value?.latitude?.toStringAsFixed(6) ?? 'N/A'}
Lon: ${permissionController.currentLocation.value?.longitude?.toStringAsFixed(6) ?? 'N/A'}
Address: ${permissionController.currentAddress.value ?? 'Unavailable'}
''';

  int metadataX = resizedMap.width + (padding * 2);
  int metadataY = containerY + padding;
  List<String> detailLines = details.split('\n');
  int lineHeight = 24;

  for (int i = 0; i < detailLines.length; i++) {
    img.drawString(
      overlayImage,
      detailLines[i],
      font: img.arial24,
      x: metadataX,
      y: metadataY + (i * lineHeight),
      color: img.ColorRgb8(255, 255, 255),
    );
  }

  return overlayImage;
}


  Future<Uint8List?> _captureMapSnapshot() async {
    try {
      if (permissionController.currentLocation.value == null) return null;
      if (permissionController.mapController.value == null) return null;
      return await permissionController.mapController.value!.takeSnapshot();
    } catch (e) {
      print("Map snapshot error: $e");
      return null;
    }
  }

  // Show error snackbar
  void _showErrorSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
    ));
  }

  // Show success snackbar
  void _showSuccessSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.green,
    ));
  }
}