import Foundation

/// 허용된 디렉터리로 파일 시스템 접근을 제한하는 경로 샌드박스.
public struct PathSandbox: SecurityPolicy, Sendable {
    // MARK: - Property

    /// 샌드박스 위반 에러 타입.
    public enum SandboxError: Error, Sendable, Equatable, LocalizedError {
        /// 경로가 모든 허용된 디렉터리 바깥에 있을 때.
        case pathNotAllowed(String)

        /// 경로를 해석할 수 없을 때.
        case invalidPath(String)

        // MARK: - LocalizedError

        public var errorDescription: String? {
            switch self {
            case .pathNotAllowed(let path):
                return "허용되지 않은 경로입니다: \(path)"
            case .invalidPath(let path):
                return "경로를 해석할 수 없습니다: \(path)"
            }
        }
    }

    private let allowedDirectories: [String]

    // MARK: - Initializer

    /// 허용된 디렉터리로 경로 샌드박스를 생성한다.
    /// - Parameter allowedDirectories: 파일 접근이 허용되는 디렉터리 목록.
    public init(allowedDirectories: [String]) {
        self.allowedDirectories = allowedDirectories.map { directory in
            let url = URL(fileURLWithPath: (directory as NSString).expandingTildeInPath)
            return url.standardized.filePath
        }
    }

    // MARK: - Public

    public func validatePath(_ path: String) throws -> URL {
        let expanded = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded).standardized
        let standardizedPath = url.filePath

        // realpath를 사용하여 심볼릭 링크를 해석한다.
        let resolvedPath: String
        if let resolved = realpath(standardizedPath, nil) {
            resolvedPath = String(cString: resolved)
            free(resolved)
        } else {
            // 파일이 아직 존재하지 않으면 상위 디렉터리를 해석하고
            // 마지막 경로 컴포넌트를 추가한다.
            let parentPath = (standardizedPath as NSString).deletingLastPathComponent
            if let resolvedParent = realpath(parentPath, nil) {
                let parent = String(cString: resolvedParent)
                free(resolvedParent)
                let lastComponent = (standardizedPath as NSString).lastPathComponent
                resolvedPath = (parent as NSString).appendingPathComponent(lastComponent)
            } else {
                throw SandboxError.invalidPath(path)
            }
        }

        // 해석된 경로가 허용된 디렉터리 중 하나로 시작하는지 검증한다.
        let isAllowed = allowedDirectories.contains { allowedDir in
            let dirWithSlash = allowedDir.hasSuffix("/") ? allowedDir : allowedDir + "/"
            return resolvedPath == allowedDir || resolvedPath.hasPrefix(dirWithSlash)
        }

        guard isAllowed else {
            throw SandboxError.pathNotAllowed(path)
        }

        return URL(fileURLWithPath: resolvedPath)
    }
}
