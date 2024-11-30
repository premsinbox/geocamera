import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geocamera/controller.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:get/get.dart';

// HomeScreen
class CameraWithLocationScreen extends StatelessWidget {


 final CameraLocationController controller = Get.put(CameraLocationController());
  @override
  Widget build(BuildContext context) {
    return GetBuilder<CameraLocationController>(
      init: CameraLocationController(),
      builder: (controller) {
        return Scaffold(
          body: Stack(
            children: [
              // Fullscreen Camera Preview
              Positioned.fill(
                child: Obx(() {
            final cameraController = controller.cameraController.value;
            if (cameraController == null || !cameraController.value.isInitialized) {
              return Center(child: CircularProgressIndicator());
            }
            return CameraPreview(cameraController);
          }),
              ),

              // Top-right camera switch button
              Positioned(
                top: 20,
                right: 20,
                child: Center(
                  child: ElevatedButton.icon(
                    onPressed: controller.switchCamera,
                    icon: const Icon(Icons.switch_camera),
                    label: const Text(""),
                    style: ElevatedButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(10),
                    ),
                  ),
                ),
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
                              controller.currentLocation.value == null
                                ? const Center(child: CircularProgressIndicator())
                                : Container(
                                    height: 100,
                                    child: GoogleMap(
                                      initialCameraPosition: CameraPosition(
                                        target: LatLng(
                                          controller.currentLocation.value!.latitude!,
                                          controller.currentLocation.value!.longitude!,
                                        ),
                                        zoom: 15,
                                      ),
                                      markers: {
                                        Marker(
                                          markerId: const MarkerId('current_location'),
                                          position: LatLng(
                                            controller.currentLocation.value!.latitude!,
                                            controller.currentLocation.value!.longitude!,
                                          ),
                                        )
                                      },
                                      zoomControlsEnabled: false,
                                      onMapCreated: (GoogleMapController mapController) {
                                        controller.mapController.value = mapController;
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
                                  'Address: ${controller.currentAddress.value}',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 14),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Lat: ${controller.currentLocation.value?.latitude?.toStringAsFixed(6) ?? "N/A"}',
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                                Text(
                                  'Lon: ${controller.currentLocation.value?.longitude?.toStringAsFixed(6) ?? "N/A"}',
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                                Text(
                                  'Date & Time: ${controller.currentDateTime.value}',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12),
                                ),
                              ],
                            )),
                          ),
                        ],
                      ),
                    ),

                    // Capture button
                    GestureDetector(
                      onTap: () => controller.captureImage(context),
                      child: Container(
                        height: 70,
                        width: 70,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.black,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}