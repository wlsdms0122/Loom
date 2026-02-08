import Foundation

// MARK: - ConfigurationError

/// Configuration 관련 에러.
public enum ConfigurationError: Error, Sendable, Equatable, LocalizedError {
    /// Bundle 리소스를 찾을 수 없을 때.
    case resourceNotFound(resource: String, extension: String, bundlePath: String)

    /// 리소스 이름이 유효한 URL을 생성할 수 없을 때.
    case invalidResourceName(resource: String, extension: String)

    // MARK: - LocalizedError

    public var errorDescription: String? {
        switch self {
        case let .resourceNotFound(resource, ext, bundlePath):
            return """
            리소스를 찾을 수 없음: \(resource).\(ext)
            - Bundle 경로: \(bundlePath)
            - 확인 사항:
              1. 리소스 파일이 번들에 포함되어 있는지 확인하세요.
              2. 파일 이름과 확장자가 정확한지 확인하세요.
              3. 타겟의 'Copy Bundle Resources' 빌드 페이즈를 확인하세요.
            """
        case let .invalidResourceName(resource, ext):
            return "유효한 URL을 생성할 수 없는 리소스 이름: \(resource).\(ext)"
        }
    }
}

/// 웹 콘텐츠의 진입점을 나타내는 열거형.
public enum EntryPoint: Sendable {
    /// Bundle 리소스 기반 진입점 (기본 패턴).
    case bundle(resource: String, extension: String, in: Bundle = .main)

    /// 로컬 파일 경로 진입점 (예외적 용도).
    case file(URL)

    /// 원격 URL 진입점 (개발 서버 또는 프로덕션).
    case remote(URL)
}

// MARK: - Equatable
extension EntryPoint: Equatable {
    public static func == (lhs: EntryPoint, rhs: EntryPoint) -> Bool {
        switch (lhs, rhs) {
        case let (.bundle(lResource, lExt, lBundle), .bundle(rResource, rExt, rBundle)):
            return lResource == rResource && lExt == rExt && lBundle.bundleURL == rBundle.bundleURL
        case let (.file(lURL), .file(rURL)):
            return lURL == rURL
        case let (.remote(lURL), .remote(rURL)):
            return lURL == rURL
        default:
            return false
        }
    }
}

extension EntryPoint {
    /// 로드할 최종 URL을 반환한다.
    /// - Throws: `ConfigurationError.resourceNotFound` — `.bundle` 케이스에서 리소스를 찾을 수 없을 때.
    public func resolveURL() throws -> URL {
        switch self {
        case .bundle(let resource, let ext, let bundle):
            guard let url = bundle.url(forResource: resource, withExtension: ext) else {
                throw ConfigurationError.resourceNotFound(
                    resource: resource,
                    extension: ext,
                    bundlePath: bundle.bundlePath
                )
            }
            return url
        case .file(let url):
            return url
        case .remote(let url):
            return url
        }
    }

    /// 웹 콘텐츠를 로드할 URL을 반환한다.
    /// `.bundle` 케이스는 리소스 존재를 검증한 뒤 커스텀 스킴(`loom://`) URL을 반환한다.
    /// - Throws: `ConfigurationError.resourceNotFound` — `.bundle` 리소스를 찾을 수 없을 때.
    public func resolveLoadURL() throws -> URL {
        switch self {
        case .bundle(let resource, let ext, _):
            _ = try resolveURL()
            guard let url = URL(string: "loom://app/\(resource).\(ext)") else {
                throw ConfigurationError.invalidResourceName(resource: resource, extension: ext)
            }
            return url
        case .file, .remote:
            return try resolveURL()
        }
    }

    /// localhost 개발 서버를 가리키는지 여부.
    public var isLocalhost: Bool {
        guard case .remote(let url) = self else { return false }
        return url.host == "localhost" || url.host == "127.0.0.1"
    }
}
