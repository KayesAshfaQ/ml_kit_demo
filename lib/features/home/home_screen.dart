import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ML Kit Studio')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            for (final feature in const [
              (
                title: 'Text Recognition',
                subtitle: 'Read Latin text, blocks, and lines',
                route: '/text',
                icon: Icons.text_snippet_outlined,
              ),
              (
                title: 'Barcode Scanning',
                subtitle: 'Explore barcode formats, types, and values',
                route: '/barcode',
                icon: Icons.qr_code_scanner,
              ),
              (
                title: 'Face Detection',
                subtitle: 'Find faces, expressions, and head angles',
                route: '/face',
                icon: Icons.face_outlined,
              ),
            ])
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Icon(feature.icon),
                  title: Text(feature.title),
                  subtitle: Text(feature.subtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await context.push<void>(feature.route);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
