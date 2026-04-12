import Foundation

struct EncodingDetector {
    /// 偵測 Data 的文字編碼，使用前 16KB 樣本避免對整個檔案重複解碼
    static func detectEncoding(data: Data) -> String.Encoding {
        let sampleSize = min(data.count, 16_384)
        let sample = data.prefix(sampleSize)

        // 優先嘗試 UTF-8
        if String(data: sample, encoding: .utf8) != nil {
            return .utf8
        }

        // 嘗試 Big5（繁體中文常見）
        let big5 = CFStringEncoding(CFStringEncodings.big5.rawValue)
        let nsBig5 = CFStringConvertEncodingToNSStringEncoding(big5)
        let big5Encoding = String.Encoding(rawValue: nsBig5)
        if String(data: sample, encoding: big5Encoding) != nil {
            return big5Encoding
        }

        // 嘗試 GBK / GB18030（簡體中文常見）
        let gbk = CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
        let nsGBK = CFStringConvertEncodingToNSStringEncoding(gbk)
        let gbkEncoding = String.Encoding(rawValue: nsGBK)
        if String(data: sample, encoding: gbkEncoding) != nil {
            return gbkEncoding
        }

        // 最後 fallback 回 UTF-8
        return .utf8
    }

    /// 使用偵測到的編碼將 Data 解碼為 String（僅對完整資料解碼一次）
    static func decodeString(from data: Data) -> String? {
        let encoding = detectEncoding(data: data)
        return String(data: data, encoding: encoding)
    }
}
