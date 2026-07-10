import 'dart:io';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:image/image.dart' as img;

import '../rgb_image.dart';
import 'card_scanner.dart';

/// [CardScanner] backed by the platform's native document-scanner UI
/// (Android ML Kit Document Scanner / iOS VisionKit, bridged via
/// `cunning_document_scanner`).
///
/// This is the primary, lowest-implementation-risk perspective-correction
/// path for v1 — see the project plan's vision-pipeline notes for why a
/// native scanner is preferred over a hand-rolled OpenCV pipeline here,
/// and what to validate if it turns out not to auto-detect Ubongo cards'
/// busy printed graphics as well as it does plain documents.
class NativeScannerImpl implements CardScanner {
  @override
  Future<CorrectedCardImage?> scanCard() async {
    final paths = await CunningDocumentScanner.getPictures(noOfPages: 1);
    if (paths == null || paths.isEmpty) return null;

    final bytes = await File(paths.first).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw StateError(
        'Native scanner returned an undecodable image: ${paths.first}',
      );
    }

    final rgbaImage = decoded.numChannels == 4 ? decoded : decoded.convert(numChannels: 4);
    return CorrectedCardImage(RgbImage(
      width: rgbaImage.width,
      height: rgbaImage.height,
      rgba: rgbaImage.getBytes(order: img.ChannelOrder.rgba),
    ));
  }
}
