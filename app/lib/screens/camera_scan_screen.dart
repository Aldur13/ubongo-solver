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
        _error = _friendlyError(e);
        _scanning = false;
      });
    }
  }

  String _friendlyError(Object e) {
    final raw = e.toString();
    if (raw.toLowerCase().contains('permission')) {
      return "Camera permission is needed to scan a card. Allow it in your "
          "phone's Settings > Apps > Ubongo Solver > Permissions, then try again.";
    }
    return "Couldn't open the scanner. Details: $raw";
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Card')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.document_scanner, size: 40, color: colorScheme.onPrimaryContainer),
              ),
              const SizedBox(height: 24),
              const Text(
                'Point your camera at the puzzle card. The scanner detects '
                'its edges and corrects perspective automatically.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (_error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: colorScheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              FilledButton.icon(
                onPressed: _scanning ? null : _startScan,
                icon: _scanning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.camera_alt),
                label: Text(_scanning ? 'Scanning…' : 'Open Scanner'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
