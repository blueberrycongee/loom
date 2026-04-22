import Foundation
import ImageIO
import LoomCore

/// Reads pixel dimensions and capture date from a file without decoding the
/// whole image.
///
/// `ImageIO` parses just the container header to get `PixelWidth` /
/// `PixelHeight`, and the EXIF auxiliary dictionary for `DateTimeOriginal`.
/// For a 40-MP JPEG this takes ~1ms instead of the ~150ms a full decode
/// would cost.
enum MetadataReader {

    struct Result {
        let pixelSize: PixelSize
        let capturedAt: Date?
    }

    static func read(_ url: URL) -> Result? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        guard let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] else {
            return nil
        }

        guard
            let w = props[kCGImagePropertyPixelWidth]  as? Int,
            let h = props[kCGImagePropertyPixelHeight] as? Int,
            w > 0, h > 0
        else { return nil }

        let size = PixelSize(width: w, height: h)

        // EXIF date first; fall back to TIFF; fall back to file mtime.
        var captured: Date?
        if let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any],
           let s = exif[kCGImagePropertyExifDateTimeOriginal] as? String {
            captured = parseExifDate(s)
        }
        if captured == nil,
           let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any],
           let s = tiff[kCGImagePropertyTIFFDateTime] as? String {
            captured = parseExifDate(s)
        }
        if captured == nil,
           let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let date = attrs[.modificationDate] as? Date {
            captured = date
        }

        return Result(pixelSize: size, capturedAt: captured)
    }

    // MARK: — EXIF date parsing ("YYYY:MM:DD HH:MM:SS")

    private static let exifFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy:MM:dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .autoupdatingCurrent
        return f
    }()

    private static func parseExifDate(_ s: String) -> Date? {
        exifFormatter.date(from: s)
    }
}
