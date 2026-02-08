import Foundation

/// 파일 시스템 접근 프로토콜.
public protocol FileSystem: Sendable {
    /// 파일이 존재하는지 확인한다.
    func exists(at path: String) -> Bool

    /// 파일 데이터를 읽는다.
    func readData(at path: String) throws -> Data

    /// 파일에 데이터를 쓴다.
    func writeData(_ data: Data, to path: String) throws

    /// 파일을 삭제한다.
    func delete(at path: String) throws

    /// 디렉터리를 생성한다.
    func createDirectory(at path: String) throws

    /// 디렉터리 내 항목을 나열한다.
    func listContents(at path: String) throws -> [String]
}
