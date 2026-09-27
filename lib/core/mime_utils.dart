const _extensionMimeTypes = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'gif': 'image/gif',
  'webp': 'image/webp',
  'heic': 'image/heic',
  'pdf': 'application/pdf',
};

String guessMimeType(String filename) {
  final ext = filename.split('.').last.toLowerCase();
  return _extensionMimeTypes[ext] ?? 'application/octet-stream';
}

bool isImageMimeType(String mimeType) => mimeType.startsWith('image/');
