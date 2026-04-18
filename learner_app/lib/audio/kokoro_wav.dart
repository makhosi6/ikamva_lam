import 'dart:typed_data';

/// Builds a mono 16-bit PCM WAV in memory for Kokoro / just_audio playback.
Uint8List pcm16MonoToWavBytes(Int16List pcm, int sampleRate) {
  final byteRate = sampleRate * 2;
  const blockAlign = 2;
  final dataLength = pcm.length * 2;
  final fileLength = 44 + dataLength;
  final bytes = BytesBuilder();
  bytes.add([0x52, 0x49, 0x46, 0x46]); // RIFF
  bytes.add(_le32(fileLength - 8));
  bytes.add([0x57, 0x41, 0x56, 0x45]); // WAVE
  bytes.add([0x66, 0x6d, 0x74, 0x20]); // fmt
  bytes.add(_le32(16));
  bytes.add(_le16(1)); // PCM
  bytes.add(_le16(1)); // mono
  bytes.add(_le32(sampleRate));
  bytes.add(_le32(byteRate));
  bytes.add(_le16(blockAlign));
  bytes.add(_le16(16)); // bits
  bytes.add([0x64, 0x61, 0x74, 0x61]); // data
  bytes.add(_le32(dataLength));
  bytes.add(pcm.buffer.asUint8List(pcm.offsetInBytes, pcm.length * 2));
  return bytes.takeBytes();
}

List<int> _le16(int v) => [v & 0xff, (v >> 8) & 0xff];

List<int> _le32(int v) => [
      v & 0xff,
      (v >> 8) & 0xff,
      (v >> 16) & 0xff,
      (v >> 24) & 0xff,
    ];
