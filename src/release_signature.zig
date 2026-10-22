const std = @import("std");
const Ed25519 = std.crypto.sign.Ed25519;

pub fn verify(manifest: []const u8, signature: []const u8) !void {
    const encoded = std.mem.trim(u8, @embedFile("release_signing_public_key.txt"), " \r\n\t");
    var key: [32]u8 = undefined;
    if (try std.base64.standard.Decoder.calcSizeForSlice(encoded) != key.len) return error.InvalidReleasePublicKey;
    try std.base64.standard.Decoder.decode(&key, encoded);
    if (std.mem.allEqual(u8, &key, 0)) return error.ReleasePublicKeyNotConfigured;
    if (signature.len != Ed25519.Signature.encoded_length) return error.InvalidReleaseSignature;
    const public_key = try Ed25519.PublicKey.fromBytes(key);
    try Ed25519.Signature.fromBytes(signature[0..64].*).verifyStrict(manifest, public_key);
}
