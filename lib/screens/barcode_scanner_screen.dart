import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Full-screen barcode scanner. Pops with the scanned barcode string when a barcode is detected.
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  bool _alreadyPopped = false;

  void _onDetect(BarcodeCapture capture) {
    if (_alreadyPopped) return;
    final barcode = capture.barcodes.firstOrNull;
    final value = barcode?.rawValue ?? barcode?.displayValue;
    if (value != null && value.trim().isNotEmpty && mounted) {
      _alreadyPopped = true;
      Navigator.of(context).pop(value.trim());
    }
  }

  static const double _frameWidth = 260;
  static const double _frameHeight = 160;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сканировать штрихкод'),
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final scanWindow = Rect.fromCenter(
            center: Offset(w / 2, h / 2),
            width: _frameWidth,
            height: _frameHeight,
          );
          return Stack(
            children: [
              MobileScanner(
                onDetect: _onDetect,
                scanWindow: scanWindow,
              ),
              Center(
                child: Container(
                  width: _frameWidth,
                  height: _frameHeight,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              Positioned(
                bottom: 32,
                left: 0,
                right: 0,
                child: Text(
                  'Наведите штрихкод в рамку',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    shadows: [
                      Shadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 4),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
