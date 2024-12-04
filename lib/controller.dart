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

class CameraLocationController extends GetxController {
  final PermissionController permissionController = Get.put(PermissionController());

  // Function to start the camera preview
// Function to start the camera preview without mirroring
// Function to start the camera preview without any mirroring
Widget buildCameraPreview() {
  if (permissionController.cameraController.value == null ||
      !permissionController.cameraController.value!.value.isInitialized) {
    return Center(child: CircularProgressIndicator());
  }

  // Ensure that the camera preview fills the screen properly
  return Center(
    child: SizedBox.expand(
      child: CameraPreview(permissionController.cameraController.value!),
    ),
  );
}


  // Function to capture an image with the camera
  Future<void> captureImage(BuildContext context) async {
    try {
      // Validate camera is ready
      if (permissionController.cameraController.value == null ||
          !permissionController.cameraController.value!.value.isInitialized) {
        _showErrorSnackbar(context, "Camera is not ready");
        return;
      }

      // Capture camera image
      final XFile? cameraImage = await permissionController.cameraController.value!.takePicture();
      if (cameraImage == null) {
        _showErrorSnackbar(context, "Failed to capture image");
        return;
      }

      // Capture map snapshot
      Uint8List? mapSnapshot = await _captureMapSnapshot();
      if (mapSnapshot == null) {
        _showErrorSnackbar(context, "Failed to capture map snapshot");
        return;
      }

      // Get camera image bytes
      Uint8List cameraImageBytes = await cameraImage.readAsBytes();
      img.Image? processedCameraImage = img.decodeImage(cameraImageBytes);
      img.Image? processedMapImage = img.decodeImage(mapSnapshot);

      if (processedCameraImage == null || processedMapImage == null) {
        _showErrorSnackbar(context, "Image processing failed");
        return;
      }

      // Resize map image to fit into a small container
      processedMapImage = img.copyResize(processedMapImage, width: 300, height: 200);

      // Overlay map and details
      img.Image combinedImage = _addOverlay(
        processedCameraImage,
        processedMapImage,
        context,
      );

      // Save to external storage
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
      print("Image capture and save error: $e");
      _showErrorSnackbar(context, "Capture failed: ${e.toString()}");
    }
  }

  // Function to capture map snapshot (if needed for overlay)
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

  // Function to overlay the map and camera image
  img.Image _addOverlay(img.Image cameraImage, img.Image mapImage, BuildContext context) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final double screenWidth = mediaQuery.size.width;
    final double screenHeight = mediaQuery.size.height;
    final Orientation orientation = mediaQuery.orientation;

    img.Image overlayImage = img.Image(
      width: cameraImage.width,
      height: cameraImage.height,
    );

    // Copy the camera image into the overlay
    for (int y = 0; y < cameraImage.height; y++) {
      for (int x = 0; x < cameraImage.width; x++) {
        overlayImage.setPixel(x, y, cameraImage.getPixel(x, y));
      }
    }

    // Calculate dimensions based on orientation
    int containerHeight, containerY, padding, metadataX, metadataY;
    img.Image resizedMap;

    if (orientation == Orientation.portrait) {
      // Portrait-specific layout
      containerHeight = (screenHeight * 0.3).toInt();
      containerY = overlayImage.height - containerHeight;
      padding = 20;

      // Resize map for portrait
      resizedMap = img.copyResize(
        mapImage,
        width: (screenWidth * 0.4).toInt(),
        height: (containerHeight * 0.8).toInt(),
      );
    } else {
      // Landscape-specific layout
      containerHeight = (screenHeight * 0.4).toInt();
      containerY = overlayImage.height - containerHeight;
      padding = 10;

      // Resize map for landscape (wider)
      resizedMap = img.copyResize(
        mapImage,
        width: (screenWidth * 0.3).toInt(),
        height: (containerHeight * 0.9).toInt(),
      );
    }

    // Draw semi-transparent background for the bottom container
    for (int y = containerY; y < overlayImage.height; y++) {
      for (int x = 0; x < overlayImage.width; x++) {
        overlayImage.setPixel(x, y, img.ColorRgba8(50, 50, 50, 100));
      }
    }

    // Place the resized map
    for (int y = 0; y < resizedMap.height; y++) {
      for (int x = 0; x < resizedMap.width; x++) {
        overlayImage.setPixel(padding + x, containerY + padding + y, resizedMap.getPixel(x, y));
      }
    }

    // Prepare metadata details
    String details = '''
Lat: ${permissionController.currentLocation.value?.latitude?.toStringAsFixed(6) ?? 'N/A'}
Lon: ${permissionController.currentLocation.value?.longitude?.toStringAsFixed(6) ?? 'N/A'}
Address: ${permissionController.currentAddress.value ?? 'Unavailable'}
''';

    // Adjust metadata positioning based on orientation
    metadataX = resizedMap.width + (padding * 2);
    metadataY = containerY + padding;

    // Draw metadata with text wrapping
    img.drawString(
      overlayImage,
      details,
      font: img.arial24,
      x: metadataX,
      y: metadataY + ((containerHeight - padding) ~/ 4),
      color: img.ColorRgb8(255, 255, 255),
      wrap: true,
    );

    return overlayImage;
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
