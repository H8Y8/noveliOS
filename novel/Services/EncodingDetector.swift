import Foundation

struct EncodingDetector {
    /// 偵測 Data 的文字編碼，優先嘗試 UTF-8，fallback 至 Big5、GBK
    static func detectEncoding(data: Data) -> String.Encoding {
        // 優先嘗試 UTF-8
        if let _ = String(data: data, encoding: .utf8) {
            return .utf8
        }

        // 嘗試 Big5（繁體中文常見）
        let big5 = CFStringEncoding(CFStringEncodings.big5.rawValue)
        let nsBig5 = CFStringConvertEncodingToNSStringEncoding(big5)
        let big5Encoding = String.Encoding(rawValue: nsBig5)
        if let _ = String(data: data, encoding: big5Encoding) {
            return big5Encoding
        }

        // 嘗試 GBK / GB18030（簡體中文常見）
        let gbk = CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
        let nsGBK = CFStringConvertEncodingToNSStringEncoding(gbk)
        let gbkEncoding = String.Encoding(rawValue: nsGBK)
        if let _ = String(data: data, encoding: gbkEncoding) {
            return gbkEncoding
        }

        // 最後 fallback 回 UTF-8
        return .utf8
    }

    /// 使用偵測到的編碼將 Data 解碼為 String
    static func decodeString(from data: Data) -> String? {
        let encoding = detectEncoding(data: data)
        return String(data: data, encoding: encoding)
    }
}
