import Foundation

extension String {
    /// 將字串按段落分割（以換行符分割，過濾空行）
    func paragraphs() -> [String] {
        self.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// 使用 UTF-16 offset 範圍擷取子字串
    func substringWithUTF16Range(start: Int, end: Int) -> String? {
        let utf16 = self.utf16
        guard let startIdx = utf16.index(utf16.startIndex, offsetBy: start, limitedBy: utf16.endIndex),
              let endIdx = utf16.index(utf16.startIndex, offsetBy: end, limitedBy: utf16.endIndex) else {
            return nil
        }
        return String(utf16[startIdx..<endIdx])
    }
}
