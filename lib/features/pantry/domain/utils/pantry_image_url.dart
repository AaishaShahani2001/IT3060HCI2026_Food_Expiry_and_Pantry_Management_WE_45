/// Which Cloudinary delivery size to request.
enum PantryImageDelivery { card, details }

/// Returns [url] unchanged unless it is a Cloudinary delivery URL.
///
/// Card images use `f_auto,q_auto,w_640,c_limit` so the full photo is
/// available and the card can show it without a prior square crop.
/// Detail images use `f_auto,q_auto,w_900,c_limit`.
/// Firebase Storage and other hosts are never rewritten.
String pantryDisplayImageUrl(
  String url, {
  PantryImageDelivery delivery = PantryImageDelivery.card,
}) {
  final trimmed = url.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri == null || uri.scheme != 'https') return trimmed;
  if (uri.host != 'res.cloudinary.com') return trimmed;

  final segments = uri.pathSegments;
  final uploadIndex = segments.indexOf('upload');
  if (uploadIndex <= 0 || segments[uploadIndex - 1] != 'image') {
    return trimmed;
  }
  if (uploadIndex + 1 >= segments.length) return trimmed;
  if (_looksLikeTransform(segments[uploadIndex + 1])) return trimmed;

  final transform = delivery == PantryImageDelivery.card
      ? 'f_auto,q_auto,w_640,c_limit'
      : 'f_auto,q_auto,w_900,c_limit';
  return uri
      .replace(
        pathSegments: [
          ...segments.sublist(0, uploadIndex + 1),
          transform,
          ...segments.sublist(uploadIndex + 1),
        ],
      )
      .toString();
}

bool _looksLikeTransform(String segment) {
  return segment.contains(',') ||
      segment.startsWith('f_') ||
      segment.startsWith('q_') ||
      segment.startsWith('w_') ||
      segment.startsWith('h_') ||
      segment.startsWith('c_');
}
