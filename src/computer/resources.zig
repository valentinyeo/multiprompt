const std = @import("std");

pub const discovery = @embedFile("discover.py");

pub fn asset(name: []const u8, size: *usize) ?[*]const u8 {
    const resources = .{
        "index.html", "computer.css", "adapter.js",
        "vendor/novnc/LICENSE.txt", "vendor/novnc/AUTHORS", "vendor/novnc/docs/LICENSE.MPL-2.0", "vendor/novnc/docs/LICENSE.BSD-3-Clause", "vendor/novnc/docs/LICENSE.BSD-2-Clause", "vendor/novnc/vendor/pako/LICENSE",
        "vendor/novnc/core/base64.js",
        "vendor/novnc/core/crypto/aes.js", "vendor/novnc/core/crypto/bigint.js", "vendor/novnc/core/crypto/crypto.js", "vendor/novnc/core/crypto/des.js", "vendor/novnc/core/crypto/dh.js", "vendor/novnc/core/crypto/md5.js", "vendor/novnc/core/crypto/rsa.js",
        "vendor/novnc/core/decoders/copyrect.js", "vendor/novnc/core/decoders/h264.js", "vendor/novnc/core/decoders/hextile.js", "vendor/novnc/core/decoders/jpeg.js", "vendor/novnc/core/decoders/raw.js", "vendor/novnc/core/decoders/rre.js", "vendor/novnc/core/decoders/tight.js", "vendor/novnc/core/decoders/tightpng.js", "vendor/novnc/core/decoders/zlib.js", "vendor/novnc/core/decoders/zrle.js",
        "vendor/novnc/core/deflator.js", "vendor/novnc/core/display.js", "vendor/novnc/core/encodings.js", "vendor/novnc/core/inflator.js",
        "vendor/novnc/core/input/domkeytable.js", "vendor/novnc/core/input/fixedkeys.js", "vendor/novnc/core/input/gesturehandler.js", "vendor/novnc/core/input/keyboard.js", "vendor/novnc/core/input/keysym.js", "vendor/novnc/core/input/keysymdef.js", "vendor/novnc/core/input/util.js", "vendor/novnc/core/input/vkeys.js", "vendor/novnc/core/input/xtscancodes.js",
        "vendor/novnc/core/ra2.js", "vendor/novnc/core/rfb.js", "vendor/novnc/core/util/browser.js", "vendor/novnc/core/util/cursor.js", "vendor/novnc/core/util/element.js", "vendor/novnc/core/util/events.js", "vendor/novnc/core/util/eventtarget.js", "vendor/novnc/core/util/int.js", "vendor/novnc/core/util/logging.js", "vendor/novnc/core/util/strings.js", "vendor/novnc/core/websock.js",
        "vendor/novnc/vendor/pako/lib/utils/common.js", "vendor/novnc/vendor/pako/lib/zlib/deflate.js", "vendor/novnc/vendor/pako/lib/zlib/trees.js", "vendor/novnc/vendor/pako/lib/zlib/inflate.js", "vendor/novnc/vendor/pako/lib/zlib/inffast.js", "vendor/novnc/vendor/pako/lib/zlib/constants.js", "vendor/novnc/vendor/pako/lib/zlib/gzheader.js", "vendor/novnc/vendor/pako/lib/zlib/crc32.js", "vendor/novnc/vendor/pako/lib/zlib/messages.js", "vendor/novnc/vendor/pako/lib/zlib/adler32.js", "vendor/novnc/vendor/pako/lib/zlib/inftrees.js", "vendor/novnc/vendor/pako/lib/zlib/zstream.js",
    };
    inline for (resources) |path| {
        if (std.mem.eql(u8, name, path)) {
            const data = @embedFile(path);
            size.* = data.len;
            return data.ptr;
        }
    }
    size.* = 0;
    return null;
}
