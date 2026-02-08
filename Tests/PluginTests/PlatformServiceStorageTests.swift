import Testing
@testable import Plugin

/// PlatformServiceStorage의 저장, 갱신, 기본값, 스레드 안전성을 검증한다.
@Suite("PlatformServiceStorage")
struct PlatformServiceStorageTests {
    // MARK: - 기본 동작

    @Test("초기 상태에서 current가 nil을 반환한다")
    func initialStateReturnsNil() {
        let storage = PlatformServiceStorage<String>()
        #expect(storage.current == nil)
    }

    @Test("초기값을 지정하면 current가 해당 값을 반환한다")
    func initialValueReturnsCurrent() {
        let storage = PlatformServiceStorage<String>(service: "initial")
        #expect(storage.current == "initial")
    }

    @Test("update 후 current가 새 값을 반환한다")
    func updateChangesCurrent() {
        let storage = PlatformServiceStorage<String>()
        storage.update("updated")
        #expect(storage.current == "updated")
    }

    @Test("update를 여러 번 호출하면 마지막 값이 반환된다")
    func multipleUpdatesReturnLatest() {
        let storage = PlatformServiceStorage<Int>()
        storage.update(1)
        storage.update(2)
        storage.update(3)
        #expect(storage.current == 3)
    }

    // MARK: - 기본값 (defaultValue)

    @Test("defaultValue가 설정되면 update 전에 기본값을 반환한다")
    func defaultValueBeforeUpdate() {
        let storage = PlatformServiceStorage<String>(defaultValue: "fallback")
        #expect(storage.current == "fallback")
    }

    @Test("defaultValue가 설정되어도 update 후에는 새 값을 반환한다")
    func updateOverridesDefaultValue() {
        let storage = PlatformServiceStorage<String>(defaultValue: "fallback")
        storage.update("override")
        #expect(storage.current == "override")
    }

    @Test("service 없이 defaultValue도 없으면 nil을 반환한다")
    func noServiceNoDefaultReturnsNil() {
        let storage = PlatformServiceStorage<Int>()
        #expect(storage.current == nil)
    }

    // MARK: - 스레드 안전성

    @Test("동시 읽기/쓰기에서 크래시 없이 동작한다")
    func concurrentAccessIsSafe() async {
        let storage = PlatformServiceStorage<Int>()

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    storage.update(i)
                }
                group.addTask {
                    _ = storage.current
                }
            }
        }

        // 크래시 없이 완료되면 성공. 최종 값은 경쟁 조건에 따라 다를 수 있다.
        #expect(storage.current != nil)
    }

    // MARK: - 프로토콜 타입

    @Test("프로토콜 타입을 저장할 수 있다")
    func storesProtocolType() {
        let storage = PlatformServiceStorage<any Sendable>()
        storage.update("string value" as any Sendable)
        #expect(storage.current != nil)
    }
}
