import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocamera/view.dart';
import 'package:get/get.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      home: Dashboard(),
    );
  }
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: GestureDetector(
          onTap: () {
             Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => CameraWithLocationScreen()),
  );
          },
          child:Center(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.all( Radius.circular(25),) 
              
              ),
                height: 150,
                width: 150,
                child: Icon(
                  Icons.add_a_photo
                )
            ),
          )
        )
      );
  }
}

