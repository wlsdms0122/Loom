import Foundation

/// 경로를 검증하는 보안 정책 프로토콜.
public protocol SecurityPolicy: Sendable {
    /// 파일 경로를 검증하고 해석된 URL을 반환한다.
    /// 보안 정책을 위반하면 에러를 던진다.
    func validatePath(_ path: String) throws -> URL
}
