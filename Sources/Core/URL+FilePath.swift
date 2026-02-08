import Foundation

// MARK: - URL + filePath

extension URL {
    /// `path(percentEncoded: false)`에서 디렉터리 URL의 후행 슬래시를 제거한 경로를 반환한다.
    /// `URL.path`(percent-encoded 기본값)와 달리 디코딩된 경로를 반환하며 후행 슬래시를 정규화한다.
    public var filePath: String {
        let p = self.path(percentEncoded: false)
        if p.count > 1 && p.hasSuffix("/") {
            return String(p.dropLast())
        }
        return p
    }
}
