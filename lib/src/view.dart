import 'package:flutter/material.dart';
import 'package:geocamera/src/controller.dart';
import 'package:geocamera/src/permission.dart';
import 'package:geocamera/src/dashboard.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:get/get.dart';


class CameraWithLocationScreen extends StatelessWidget {
  final CameraLocationController controller = Get.put(CameraLocationController());
  final PermissionController permissionController = Get.put(PermissionController());

  @override
  Widget build(BuildContext context) {
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;

    return Scaffold(
      body: Column(
        children: [
          if (isPortrait)
            buildTopNavBar(context), // Top navigation bar for portrait
          if (!isPortrait)
            Expanded(
              child: Row(
                children: [
                  buildLeftNavBar(context), // Left navigation bar for landscape
                  Expanded(child: buildMainContent(context)),
                  buildRightNavBar(context), // Right navigation bar for landscape
                ],
              ),
            ),
          if (isPortrait)
            Expanded(child: buildMainContent(context)), // Main content for portrait
          if (isPortrait)
            buildBottomNavBar(context), // Bottom navigation bar for portrait
        ],
      ),
    );
  }

  // Top Navigation Bar for Portrait Mode
  Widget buildTopNavBar(BuildContext context) {
    return Container(
      color:  Colors.black,
      height: 80,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: (){Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => Dashboard()),
  );
            },
            child: const Padding(
              padding: EdgeInsets.all(20),
              child: Icon(Icons.arrow_back_ios, color: Colors.white, size: 30),
            ),
          ),
          GestureDetector(
            onTap: permissionController.switchCamera,
            child: const Padding(
              padding: EdgeInsets.all(20),
              child: Icon(Icons.cameraswitch, color: Colors.white, size: 30),
            ),
          ),
        ],
      ),
    );
  }

  // Left Navigation Bar for Landscape Mode
  Widget buildLeftNavBar(BuildContext context) {
    return Container(
      color:  Colors.black,
      width: 80,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: permissionController.switchCamera,
            child: const Padding(
              padding: EdgeInsets.all(20),
              child: Icon(Icons.cameraswitch, color: Colors.white, size: 30),
            ),
          ),
          GestureDetector(
            onTap: (){Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => Dashboard()),
  );
            },
            child: const Padding(
              padding: EdgeInsets.all(20),
              child: Icon(Icons.arrow_back_ios, color: Colors.white, size: 30),
            ),
          ),
        ],
      ),
    );
  }

  // Right Navigation Bar for Landscape Mode
  Widget buildRightNavBar(BuildContext context) {
    return Container(
      color:  Colors.black,
      width: 80,
      height: double.infinity,
      child: Center(
        child: GestureDetector(
          onTap: () => controller.captureImage(context),
          child: Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  // Bottom Navigation Bar for Portrait Mode
  Widget buildBottomNavBar(BuildContext context) {
    return Container(
      color:  Colors.black,
      height: 80,
      child: Center(
        child: GestureDetector(
          onTap: () => controller.captureImage(context),
          child: Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  // Main Content (Camera Preview and Location Details)
  Widget buildMainContent(BuildContext context) {
    return Stack(
      children: [
        // Fullscreen Camera Preview
           Positioned.fill(
  child: Obx(() {
    final cameraController = permissionController.cameraController.value;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return Center(child: CircularProgressIndicator());
    }
    return controller.buildCameraPreview(); // Use the buildCameraPreview method
  }),
),



              // Bottom overlay with details and capture button
              Align(
                alignment: Alignment.bottomCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Row(
                        children: [
                          // Small map view
                          Expanded(
                            flex: 1,
                            child: Obx(() => 
                              permissionController.currentLocation.value == null
                                ? const Center(child: CircularProgressIndicator())
                                : Container(
                                    height: 100,
                                    child: GoogleMap(
                                      initialCameraPosition: CameraPosition(
                                        target: LatLng(
                                          permissionController.currentLocation.value!.latitude!,
                                          permissionController.currentLocation.value!.longitude!,
                                        ),
                                        zoom: 13,
                                      ),
                                      markers: {
                                        Marker(
                                          markerId: const MarkerId('current_location'),
                                          position: LatLng(
                                            permissionController.currentLocation.value!.latitude!,
                                            permissionController.currentLocation.value!.longitude!,
                                          ),
                                        )
                                      },
                                      zoomControlsEnabled: false,
                                      onMapCreated: (GoogleMapController mapController) {
                                        permissionController.mapController.value = mapController;
                                      },
                                    ),
                                  ),
                            ),
                          ),

                          const SizedBox(width: 10),

                          // Location details
                          Expanded(
                            flex: 2,
                            child: Obx(() => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Address: ${permissionController.currentAddress.value}',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 14),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Lat: ${permissionController.currentLocation.value?.latitude?.toStringAsFixed(6) ?? "N/A"}',
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                                Text(
                                  'Lon: ${permissionController.currentLocation.value?.longitude?.toStringAsFixed(6) ?? "N/A"}',
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                                Text(
                                  'Date & Time: ${permissionController.currentDateTime.value}',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12),
                                ),
                              ],
                            )),
                          ),
                        ],
                      ),
                    ),
              
            ],
          ),
        ),
      ],
    );
  }
}