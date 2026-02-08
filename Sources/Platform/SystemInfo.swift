/// 시스템 정보 구조체.
public struct SystemInfo: Sendable {
    // MARK: - Property
    /// 운영 체제 이름.
    public let osName: String

    /// 운영 체제 버전.
    public let osVersion: String

    /// 아키텍처.
    public let architecture: String

    // MARK: - Initializer
    public init(osName: String, osVersion: String, architecture: String) {
        self.osName = osName
        self.osVersion = osVersion
        self.architecture = architecture
    }
}
