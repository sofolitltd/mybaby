const _extensionMimeTypes = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'gif': 'image/gif',
  'webp': 'image/webp',
  'heic': 'image/heic',
  'pdf': 'application/pdf',
  'mp4': 'video/mp4',
  'mov': 'video/quicktime',
  'm4v': 'video/x-m4v',
  'doc': 'application/msword',
  'docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'txt': 'text/plain',
};

String guessMimeType(String filename) {
  final ext = filename.split('.').last.toLowerCase();
  return _extensionMimeTypes[ext] ?? 'application/octet-stream';
}

bool isImageMimeType(String mimeType) => mimeType.startsWith('image/');

bool isVideoMimeType(String mimeType) => mimeType.startsWith('video/');
