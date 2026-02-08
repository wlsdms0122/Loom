import Foundation
import Core

/// 스크립트 주입 시점 열거형.
public enum ScriptInjectionTime: Sendable {
    /// 문서 시작 시점.
    case atDocumentStart

    /// 문서 종료 시점.
    case atDocumentEnd
}

// MARK: - NavigationPolicyHandler

/// 네비게이션 정책 판단을 위한 핸들러 타입.
/// URL과 메인 프레임 여부를 받아 허용/차단 여부를 반환한다.
public typealias NavigationPolicyHandler = @Sendable (URL, Bool) async -> Bool

/// 네이티브 웹 뷰 프로토콜.
public protocol NativeWebView: Sendable {
    /// 플랫폼 고유의 네이티브 뷰 객체에 접근한다.
    @MainActor var nativeView: Any { get }

    /// URL을 로드한다.
    func loadURL(_ url: URL) async

    /// HTML 문자열을 로드한다.
    func loadHTML(_ html: String) async

    /// JavaScript를 실행하고 결과를 반환한다.
    func evaluateJavaScript(_ script: String) async throws -> (any Sendable)?

    /// 사용자 스크립트를 주입한다.
    func addUserScript(_ script: String, injectionTime: ScriptInjectionTime) async

    /// 메시지 핸들러를 등록한다.
    func addMessageHandler(name: String, handler: @escaping @Sendable (Any) async -> Void) async

    /// 등록된 메시지 핸들러와 사용자 스크립트를 모두 제거하여 순환 참조를 해제한다.
    func cleanup() async

    /// 현재 페이지를 다시 로드한다.
    @MainActor func reload()

    /// 네비게이션 정책 핸들러를 설정한다.
    /// 핸들러가 true를 반환하면 네비게이션을 허용하고, false를 반환하면 차단한다.
    func setNavigationPolicyHandler(_ handler: @escaping NavigationPolicyHandler) async

    /// JS console 메시지를 Logger로 포워딩한다.
    @MainActor func enableConsoleForwarding(logger: any Logger)
}

// MARK: - Default Implementation
public extension NativeWebView {
    /// cleanup의 기본 구현. 아무 작업도 수행하지 않는다.
    func cleanup() async {}

    /// setNavigationPolicyHandler의 기본 구현. 아무 작업도 수행하지 않는다.
    func setNavigationPolicyHandler(_ handler: @escaping NavigationPolicyHandler) async {}

    /// enableConsoleForwarding의 기본 구현. 아무 작업도 수행하지 않는다.
    @MainActor func enableConsoleForwarding(logger: any Logger) {}
}
