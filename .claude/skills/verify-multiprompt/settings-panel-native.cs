using System;
using System.Drawing;
using System.Collections.Generic;

public static class SettingsPanelPixels {
    static bool Fill(Bitmap image, int x, int y) {
        Color pixel = image.GetPixel(x, y);
        return pixel.R == 0x18 && pixel.G == 0x18 && pixel.B == 0x18;
    }
    static bool Band(Bitmap image, int center, int y) {
        for (int x = center - 12; x <= center + 12; x += 6) if (!Fill(image, x, y)) return false;
        return true;
    }
    public static Dictionary<string, object> Check(string panelFile, string beforeFile, int clientLeft, int clientTop, int clientWidth, int clientHeight) {
        using (Bitmap image = new Bitmap(panelFile))
        using (Bitmap before = new Bitmap(beforeFile)) {
            if (image.Size != before.Size) throw new InvalidOperationException("Settings changed screenshot dimensions");
            int center = clientLeft + clientWidth / 2;
            int top = -1, bottom = -1;
            for (int y = clientTop; y < clientTop + clientHeight; y++) {
                if (!Band(image, center, y)) continue;
                if (top < 0) top = y;
                bottom = y;
            }
            if (top < 0 || bottom - top < 300) throw new InvalidOperationException("No painted Settings panel fill");
            int header = top + Math.Min(70, (bottom - top) / 4);
            int left = -1, right = -1;
            for (int x = clientLeft; x < clientLeft + clientWidth; x++) {
                if (!Fill(image, x, header) || !Fill(image, x, header + 3)) continue;
                if (left < 0) left = x;
                right = x;
            }
            if (left < 0 || right - left < 300) throw new InvalidOperationException("No painted Settings panel width");
            if (Math.Abs(left + right - (clientLeft * 2 + clientWidth - 1)) > 4 ||
                Math.Abs(top + bottom - (clientTop * 2 + clientHeight - 1)) > 4) throw new InvalidOperationException("Settings panel is not centred in its owner client");
            if (left <= clientLeft || right >= clientLeft + clientWidth || top <= clientTop || bottom >= clientTop + clientHeight) throw new InvalidOperationException("Settings panel is clipped");
            if (Fill(image, left + 2, top + 2) || Fill(image, right - 2, top + 2)) throw new InvalidOperationException("Settings panel is missing rounded corners");
            double original = 0, dimmed = 0;
            int samples = 0;
            for (int x = clientLeft + 12; x < left - 12; x += 8) {
                for (int y = clientTop + clientHeight / 3; y < clientTop + clientHeight * 2 / 3; y += 8) {
                    original += before.GetPixel(x, y).R;
                    dimmed += image.GetPixel(x, y).R;
                    samples++;
                }
            }
            if (samples == 0 || original == 0 || dimmed >= original * 0.7) throw new InvalidOperationException("Chat behind Settings is not visibly dimmed");
            return new Dictionary<string, object> {
                { "bounds", new int[] { left, top, right + 1, bottom + 1 } },
                { "fill", "#181818" }, { "centred", true }, { "rounded", true },
                { "backdropRatio", dimmed / original }, { "backdropSamples", samples }
            };
        }
    }
}
