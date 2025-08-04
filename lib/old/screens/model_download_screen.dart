import 'package:flutter/material.dart';

class ModelDownloadScreen extends StatelessWidget {
  final String modelName;
  final int downloadedBytes;
  final int totalBytes;
  final double speedMBps;
  final Duration eta;

  const ModelDownloadScreen({
    Key? key,
    required this.modelName,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.speedMBps,
    required this.eta,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final percent = totalBytes > 0 ? downloadedBytes / totalBytes : 0.0;
    final mbDownloaded = downloadedBytes / (1024 * 1024);
    final mbTotal = totalBytes / (1024 * 1024);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ask Image'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 18),
                      const SizedBox(width: 6),
                      Text(modelName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down, size: 18),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            // Google-style loading animation (use a placeholder for now)
            SizedBox(
              height: 80,
              child: Center(
                child: Image.asset('assets/google_spinner.png', height: 60), // Replace with your spinner asset
              ),
            ),
            const SizedBox(height: 32),
            LinearProgressIndicator(
              value: percent,
              minHeight: 6,
              backgroundColor: Colors.grey[300],
              color: Colors.green,
            ),
            const SizedBox(height: 12),
            Text(
              '${mbDownloaded.toStringAsFixed(1)} MB of ${mbTotal.toStringAsFixed(1)} GB • ${speedMBps.toStringAsFixed(1)} MB/s • ${eta.inMinutes} min ${eta.inSeconds % 60} sec left',
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 24),
            Text(
              'Feel free to switch apps or lock your device.\nThe download will continue in the background.\nWe’ll send a notification when it’s done.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
