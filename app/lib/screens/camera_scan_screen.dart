import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ubongo_vision/ubongo_vision.dart';

class CameraScanScreen extends StatefulWidget {
  const CameraScanScreen({super.key});

  @override
  State<CameraScanScreen> createState() => _CameraScanScreenState();
}

class _CameraScanScreenState extends State<CameraScanScreen> {
  bool _scanning = false;
  String? _error;

  Future<void> _startScan() async {
    setState(() {
      _scanning = true;
      _error = null;
    });
    try {
      final CardScanner scanner = NativeScannerImpl();
      final corrected = await scanner.scanCard();
      if (!mounted) return;
      if (corrected == null) {
        setState(() => _scanning = false);
        return;
      }
      context.push('/pieces', extra: corrected);
      setState(() => _scanning = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _scanning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Card')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Point your camera at the puzzle card. The scanner detects '
                'its edges and corrects perspective automatically.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              FilledButton.icon(
                onPressed: _scanning ? null : _startScan,
                icon: const Icon(Icons.camera_alt),
                label: Text(_scanning ? 'Scanning…' : 'Open Scanner'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
