import 'package:advero_flutter/advero_flutter.dart';
import 'package:flutter/material.dart';

void main() {
  // Replace with your account's actual Advero ad-serving endpoint — no
  // default is provided, and init() throws if this is missing/empty.
  AdveroSDK.init(baseUrl: 'https://ads-advero.domain.com');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Advero Flutter SDK example',
      home: Scaffold(
        appBar: AppBar(title: const Text('Advero Flutter SDK example')),
        body: Center(
          child: AdveroAdView(
            // Replace with your own placement's code — copied as-is from
            // the Advero dashboard, never constructed/split yourself.
            placementCode: 'ap-0123456789abcdef01234567-89abcdef',
            showPlaceholder: true,
            onAdLoaded: () => debugPrint('Ad loaded'),
            onEmpty: () => debugPrint('No ad to show'),
          ),
        ),
      ),
    );
  }
}
