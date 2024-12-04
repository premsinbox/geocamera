import 'dart:async';
import 'package:camera/camera.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart' as loc;
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:permission_handler/permission_handler.dart';

class PermissionController extends GetxController {
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
    _initializeAll();
  }

  /// Comprehensive initialization method
  Future<void> _initializeAll() async {
    await _requestPermissions();
    await _initializeCameras();
    _initializeLocation();
  }

  /// Request all necessary permissions
  Future<void> _requestPermissions() async {
    try {
      // Request camera permission
      var cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        print("Camera permission denied");
        return;
      }

      // Request storage permission
      var storageStatus = await Permission.storage.request();
      if (!storageStatus.isGranted) {
        print("Storage permission denied");
        return;
      }

      // Request location permission
      var locationStatus = await Permission.location.request();
      if (!locationStatus.isGranted) {
        print("Location permission denied");
        return;
      }
    } catch (e) {
      print("Permission request error: $e");
    }
  }

  /// Initialize available cameras with comprehensive error handling
  Future<void> _initializeCameras() async {
    try {
      // Get available cameras
      cameras.value = await availableCameras();
      
      if (cameras.isEmpty) {
        print("No cameras found on the device");
        return;
      }

      // Select back camera or first available camera
      selectedCamera.value = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras[0],
      );

      // Initialize the selected camera
      await _initializeCamera(selectedCamera.value!);
    } catch (e) {
      print("Camera initialization error: $e");
    }
  }

  /// Initialize specific camera with robust error handling



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


Future<void> _initializeCamera(CameraDescription camera) async {
  try {
    // Dispose of existing controller if any
    if (cameraController.value != null) {
      await cameraController.value!.dispose();
    }

    // Create a new camera controller for the selected camera
    cameraController.value = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    // Initialize the camera
    await cameraController.value!.initialize().timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw TimeoutException('Camera initialization timed out');
      },
    );

    // Refresh the camera view
    cameraController.refresh();
  } catch (e) {
    print("Camera controller initialization error: $e");
  }
}

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

  @override
  void onClose() {
    cameraController.value?.dispose();
    mapController.value?.dispose();
    super.onClose();
  }

}