import Testing
import Foundation
import JavaScriptCore
import WebEngine

@Suite("Bridge SDK 통합 테스트")
struct BridgeSDKIntegrationTests {
    // MARK: - Property

    private let sdk: String

    // MARK: - Initializer

    init() throws {
        sdk = try DefaultBridgeSDKProvider().generateSDK()
    }

    // MARK: - Helper

    /// JSContext에 SDK를 로드하고 WKWebView의 postMessage 스텁을 설정한다.
    private func makeJSContext(postMessageHandler: JSValue? = nil) -> JSContext {
        let ctx = JSContext()!

        // window 객체 설정 (JSContext에서는 globalObject가 window 역할)
        ctx.evaluateScript("var window = this;")

        // atob / btoa 폴리필 (JSContext에는 Web API가 없다)
        ctx.evaluateScript("""
            var __b64chars__ = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';
            function btoa(input) {
                var str = String(input);
                var output = '';
                for (var i = 0; i < str.length; i += 3) {
                    var a = str.charCodeAt(i);
                    var b = i + 1 < str.length ? str.charCodeAt(i + 1) : 0;
                    var c = i + 2 < str.length ? str.charCodeAt(i + 2) : 0;
                    var idx1 = a >> 2;
                    var idx2 = ((a & 3) << 4) | (b >> 4);
                    var idx3 = ((b & 15) << 2) | (c >> 6);
                    var idx4 = c & 63;
                    if (i + 1 >= str.length) { idx3 = 64; idx4 = 64; }
                    else if (i + 2 >= str.length) { idx4 = 64; }
                    output += __b64chars__[idx1] + __b64chars__[idx2] + __b64chars__[idx3] + __b64chars__[idx4];
                }
                return output;
            }
            function atob(input) {
                var str = String(input).replace(/=+$/, '');
                var output = '';
                for (var i = 0; i < str.length; i += 4) {
                    var a = __b64chars__.indexOf(str[i]);
                    var b = i + 1 < str.length ? __b64chars__.indexOf(str[i + 1]) : 0;
                    var c = i + 2 < str.length ? __b64chars__.indexOf(str[i + 2]) : 0;
                    var d = i + 3 < str.length ? __b64chars__.indexOf(str[i + 3]) : 0;
                    output += String.fromCharCode((a << 2) | (b >> 4));
                    if (c !== 64 && i + 2 < str.length) output += String.fromCharCode(((b & 15) << 4) | (c >> 2));
                    if (d !== 64 && i + 3 < str.length) output += String.fromCharCode(((c & 3) << 6) | d);
                }
                return output;
            }
        """)

        // setTimeout / clearTimeout 폴리필 (타이머 ID만 관리)
        ctx.evaluateScript("""
            var __timers__ = {};
            var __nextTimerId__ = 1;
            function setTimeout(fn, ms) {
                var id = __nextTimerId__++;
                __timers__[id] = { fn: fn, ms: ms, cleared: false };
                return id;
            }
            function clearTimeout(id) {
                if (__timers__[id]) { __timers__[id].cleared = true; }
            }
            function __fireTimer__(id) {
                if (__timers__[id] && !__timers__[id].cleared) {
                    __timers__[id].fn();
                }
            }
        """)

        // console.error 스텁
        ctx.evaluateScript("""
            var __consoleErrors__ = [];
            var console = { error: function() {
                var args = Array.prototype.slice.call(arguments);
                __consoleErrors__.push(args.map(function(a) { return String(a); }).join(' '));
            }, log: function() {} };
        """)

        // webkit.messageHandlers.loom.postMessage 스텁
        if let handler = postMessageHandler {
            ctx.setObject(handler, forKeyedSubscript: "__postMessageHandler__" as NSString)
            ctx.evaluateScript("""
                window.webkit = {
                    messageHandlers: {
                        loom: {
                            postMessage: function(msg) { __postMessageHandler__(msg); }
                        }
                    }
                };
            """)
        } else {
            // 기본: 아무 동작 없이 메시지를 기록한다
            ctx.evaluateScript("""
                var __postedMessages__ = [];
                window.webkit = {
                    messageHandlers: {
                        loom: {
                            postMessage: function(msg) { __postedMessages__.push(msg); }
                        }
                    }
                };
            """)
        }

        // SDK 로드
        ctx.evaluateScript(sdk)

        return ctx
    }

    // MARK: - 유니코드 인코딩 테스트

    @Test("유니코드 문자가 Base64 인코딩/디코딩에서 보존된다")
    func unicodeCharactersSurviveBase64RoundTrip() throws {
        let input = "안녕하세요 \u{201C}스마트 따옴표\u{201D} 테스트"

        let utf8Data = Data(input.utf8)
        let base64Encoded = utf8Data.base64EncodedString()

        let decodedData = try #require(Data(base64Encoded: base64Encoded))
        let decodedString = try #require(String(data: decodedData, encoding: .utf8))

        #expect(decodedString == input)
        #expect(decodedString.contains("안녕하세요"))
        #expect(decodedString.contains("\u{201C}"))
        #expect(decodedString.contains("\u{201D}"))
    }

    // MARK: - 타임아웃 관련 테스트

    @Test("요청이 설정된 타임아웃 후 거부된다")
    func requestTimesOutAfterConfiguredPeriod() {
        let ctx = makeJSContext()

        // 타임아웃을 100ms로 설정
        ctx.evaluateScript("loom.setDefaultTimeout(100);")

        // invoke 호출 -- Promise를 생성하고 pending에 추가한다
        ctx.evaluateScript("""
            var timedOut = false;
            var timeoutError = null;
            loom.invoke('test.method').catch(function(e) {
                timedOut = true;
                timeoutError = e.message;
            });
        """)

        // 타이머가 등록되었는지 확인
        let timerCount = ctx.evaluateScript("Object.keys(__timers__).length")!.toInt32()
        #expect(timerCount >= 1)

        // 타이머를 수동으로 발화하여 타임아웃을 시뮬레이션한다
        ctx.evaluateScript("""
            var timerIds = Object.keys(__timers__);
            for (var i = 0; i < timerIds.length; i++) {
                __fireTimer__(parseInt(timerIds[i]));
            }
        """)

        let timedOut = ctx.evaluateScript("timedOut")!.toBool()
        let errorMessage = ctx.evaluateScript("timeoutError")!.toString()!

        #expect(timedOut == true)
        #expect(errorMessage.contains("Request timed out after 100ms"))
        #expect(errorMessage.contains("test.method"))
    }

    @Test("타임아웃 후 pending Map이 정리된다")
    func pendingMapCleanedAfterTimeout() {
        let ctx = makeJSContext()

        ctx.evaluateScript("loom.setDefaultTimeout(100);")

        // invoke를 호출하여 pending에 항목을 추가한다
        ctx.evaluateScript("""
            loom.invoke('test.method').catch(function() {});
        """)

        // pending에 항목이 있는지 확인
        let pendingBefore = ctx.evaluateScript("window.__loom__.pending.size")!.toInt32()
        #expect(pendingBefore == 1)

        // 타이머를 발화하여 타임아웃 시뮬레이션
        ctx.evaluateScript("""
            var timerIds = Object.keys(__timers__);
            for (var i = 0; i < timerIds.length; i++) {
                __fireTimer__(parseInt(timerIds[i]));
            }
        """)

        // pending이 비었는지 확인
        let pendingAfter = ctx.evaluateScript("window.__loom__.pending.size")!.toInt32()
        #expect(pendingAfter == 0)
    }

    @Test("postMessage 실패 시 Promise가 즉시 거부된다")
    func postMessageFailureRejectsPromiseImmediately() {
        let ctx = makeJSContext()

        // postMessage가 예외를 던지도록 설정
        ctx.evaluateScript("""
            window.webkit.messageHandlers.loom.postMessage = function() {
                throw new Error('postMessage failed: handler not available');
            };
        """)

        ctx.evaluateScript("""
            var rejected = false;
            var rejectionError = null;
            loom.invoke('test.method').catch(function(e) {
                rejected = true;
                rejectionError = e.message;
            });
        """)

        let rejected = ctx.evaluateScript("rejected")!.toBool()
        let errorMessage = ctx.evaluateScript("rejectionError")!.toString()!

        #expect(rejected == true)
        #expect(errorMessage.contains("postMessage failed"))

        // pending Map도 정리되었는지 확인
        let pendingSize = ctx.evaluateScript("window.__loom__.pending.size")!.toInt32()
        #expect(pendingSize == 0)
    }

    @Test("정상 응답 수신 시 타임아웃이 취소된다")
    func normalResponseClearsTimeout() {
        let ctx = makeJSContext()

        ctx.evaluateScript("loom.setDefaultTimeout(5000);")

        // invoke를 호출한다
        ctx.evaluateScript("""
            var result = null;
            loom.invoke('test.method').then(function(data) {
                result = data;
            });
        """)

        // pending에서 요청 ID를 가져온다
        let requestId = ctx.evaluateScript("""
            var ids = [];
            window.__loom__.pending.forEach(function(v, k) { ids.push(k); });
            ids[0];
        """)!.toString()!

        // pending 항목의 timeoutId를 가져온다
        let timeoutId = ctx.evaluateScript("""
            var entry = window.__loom__.pending.get('\(requestId)');
            entry.timeoutId;
        """)!.toInt32()

        // 정상 응답을 보낸다 (payload는 JSON 문자열, outer만 Base64)
        let responsePayload = "{\"value\":42}"

        let responseMessage: [String: Any] = [
            "id": requestId,
            "kind": "response",
            "payload": responsePayload
        ]
        let responseData = try! JSONSerialization.data(withJSONObject: responseMessage)
        let responseString = String(data: responseData, encoding: .utf8)!
        let responseBase64 = Data(responseString.utf8).base64EncodedString()

        ctx.evaluateScript("window.__loom__.receive('\(responseBase64)');")

        // 타이머가 클리어되었는지 확인
        let cleared = ctx.evaluateScript("__timers__[\(timeoutId)].cleared")!.toBool()
        #expect(cleared == true)

        // pending이 비었는지 확인
        let pendingSize = ctx.evaluateScript("window.__loom__.pending.size")!.toInt32()
        #expect(pendingSize == 0)

        // 결과가 올바르게 resolve 되었는지 확인
        let resultValue = ctx.evaluateScript("result && result.value")!.toInt32()
        #expect(resultValue == 42)
    }

    @Test("receive가 잘못된 메시지에 대해 오류를 콘솔에 기록하고 중단하지 않는다")
    func receiveHandlesMalformedMessageGracefully() {
        let ctx = makeJSContext()

        // 잘못된 Base64 문자열로 receive를 호출한다
        ctx.evaluateScript("window.__loom__.receive('!!!invalid-base64!!!');")

        // 콘솔 에러가 기록되었는지 확인
        let errorCount = ctx.evaluateScript("__consoleErrors__.length")!.toInt32()
        #expect(errorCount >= 1)

        // receive가 여전히 동작하는지 확인 (파이프라인이 깨지지 않았다)
        ctx.evaluateScript("""
            var afterResult = null;
            loom.invoke('another.method').then(function(d) { afterResult = d; });
        """)

        let pendingSize = ctx.evaluateScript("window.__loom__.pending.size")!.toInt32()
        #expect(pendingSize == 1)
    }

    @Test("기본 타임아웃이 30000ms이다")
    func defaultTimeoutIs30Seconds() {
        let ctx = makeJSContext()
        let timeout = ctx.evaluateScript("window.__loom__._defaultTimeout")!.toInt32()
        #expect(timeout == 30000)
    }

    @Test("setDefaultTimeout이 타임아웃 값을 변경한다")
    func setDefaultTimeoutChangesValue() {
        let ctx = makeJSContext()
        ctx.evaluateScript("loom.setDefaultTimeout(5000);")
        let timeout = ctx.evaluateScript("window.__loom__._defaultTimeout")!.toInt32()
        #expect(timeout == 5000)
    }

    // MARK: - loom.ready 테스트

    @Test("loom.ready가 Promise이다")
    func loomReadyIsPromise() {
        let ctx = makeJSContext()
        let isPromise = ctx.evaluateScript("loom.ready instanceof Promise")!.toBool()
        #expect(isPromise == true)
    }

    @Test("loom.ready가 초기화 후 resolve 된다")
    func loomReadyResolvesAfterInit() {
        let ctx = makeJSContext()

        // ready Promise에 then 핸들러를 등록한다
        ctx.evaluateScript("""
            var readyResolved = false;
            loom.ready.then(function() { readyResolved = true; });
        """)

        // JSContext에서는 Promise microtask가 즉시 실행된다
        let resolved = ctx.evaluateScript("readyResolved")!.toBool()
        #expect(resolved == true)
    }

    // MARK: - loom.once() 테스트

    @Test("loom.once()가 첫 번째 이벤트 후 자동으로 구독 해제된다")
    func onceAutoUnsubscribesAfterFirstEvent() {
        let ctx = makeJSContext()

        // once로 이벤트를 구독한다
        ctx.evaluateScript("""
            var onceCallCount = 0;
            var onceData = null;
            loom.once('test.event', function(data) {
                onceCallCount++;
                onceData = data;
            });
        """)

        // 첫 번째 이벤트를 보낸다 (payload는 JSON 문자열, outer만 Base64)
        let eventPayload1 = "{\"value\":1}"

        let eventMessage1: [String: Any] = [
            "kind": "nativeEvent",
            "method": "test.event",
            "payload": eventPayload1
        ]
        let event1Data = try! JSONSerialization.data(withJSONObject: eventMessage1)
        let event1String = String(data: event1Data, encoding: .utf8)!
        let event1Base64 = Data(event1String.utf8).base64EncodedString()

        ctx.evaluateScript("window.__loom__.receive('\(event1Base64)');")

        // 첫 번째 호출이 실행되었는지 확인
        let callCount1 = ctx.evaluateScript("onceCallCount")!.toInt32()
        #expect(callCount1 == 1)
        let dataValue1 = ctx.evaluateScript("onceData && onceData.value")!.toInt32()
        #expect(dataValue1 == 1)

        // 두 번째 이벤트를 보낸다
        let eventPayload2 = "{\"value\":2}"

        let eventMessage2: [String: Any] = [
            "kind": "nativeEvent",
            "method": "test.event",
            "payload": eventPayload2
        ]
        let event2Data = try! JSONSerialization.data(withJSONObject: eventMessage2)
        let event2String = String(data: event2Data, encoding: .utf8)!
        let event2Base64 = Data(event2String.utf8).base64EncodedString()

        ctx.evaluateScript("window.__loom__.receive('\(event2Base64)');")

        // 두 번째 호출이 실행되지 않았는지 확인 (여전히 1회)
        let callCount2 = ctx.evaluateScript("onceCallCount")!.toInt32()
        #expect(callCount2 == 1)
    }

    @Test("loom.once()의 반환된 함수로 수동 구독 해제가 가능하다")
    func onceCanBeManuallyUnsubscribed() {
        let ctx = makeJSContext()

        ctx.evaluateScript("""
            var onceCalled = false;
            var unsubOnce = loom.once('test.event', function(data) {
                onceCalled = true;
            });
            // 이벤트가 발생하기 전에 수동으로 구독 해제한다
            unsubOnce();
        """)

        // 이벤트를 보낸다 (payload는 JSON 문자열, outer만 Base64)
        let eventPayload = "{\"value\":1}"

        let eventMessage: [String: Any] = [
            "kind": "nativeEvent",
            "method": "test.event",
            "payload": eventPayload
        ]
        let eventData = try! JSONSerialization.data(withJSONObject: eventMessage)
        let eventString = String(data: eventData, encoding: .utf8)!
        let eventBase64 = Data(eventString.utf8).base64EncodedString()

        ctx.evaluateScript("window.__loom__.receive('\(eventBase64)');")

        // 콜백이 호출되지 않았는지 확인
        let called = ctx.evaluateScript("onceCalled")!.toBool()
        #expect(called == false)
    }

    // MARK: - __loom__ 보호 테스트

    @Test("window.__loom__에 재할당이 불가능하다")
    func loomInternalIsNotWritable() {
        let ctx = makeJSContext()

        // __loom__을 다른 값으로 재할당 시도한다
        ctx.evaluateScript("window.__loom__ = { fake: true };")

        // 원래 객체가 유지되는지 확인한다
        let hasPending = ctx.evaluateScript("window.__loom__.pending instanceof Map")!.toBool()
        #expect(hasPending == true)

        let hasFake = ctx.evaluateScript("window.__loom__.fake === true")!.toBool()
        #expect(hasFake == false)
    }

    @Test("window.loom에 재할당이 불가능하다")
    func loomSDKIsNotWritable() {
        let ctx = makeJSContext()

        // loom을 null로 재할당 시도한다
        ctx.evaluateScript("window.loom = null;")

        // 원래 객체가 유지되는지 확인한다
        let hasInvoke = ctx.evaluateScript("typeof window.loom.invoke === 'function'")!.toBool()
        #expect(hasInvoke == true)

        let hasOn = ctx.evaluateScript("typeof window.loom.on === 'function'")!.toBool()
        #expect(hasOn == true)

        let hasOnce = ctx.evaluateScript("typeof window.loom.once === 'function'")!.toBool()
        #expect(hasOnce == true)

        // 빈 객체로 재할당 시도한다
        ctx.evaluateScript("window.loom = {};")

        // 여전히 원래 메서드가 존재하는지 확인한다
        let stillHasInvoke = ctx.evaluateScript("typeof window.loom.invoke === 'function'")!.toBool()
        #expect(stillHasInvoke == true)
    }

    // MARK: - 이벤트 리스너 에러 격리 테스트

    @Test("하나의 리스너 예외가 다른 리스너를 중단하지 않는다")
    func listenerExceptionDoesNotBreakOtherListeners() {
        let ctx = makeJSContext()

        // 세 개의 리스너를 등록한다: 첫 번째는 정상, 두 번째는 예외, 세 번째는 정상
        ctx.evaluateScript("""
            var listener1Called = false;
            var listener2Called = false;
            var listener3Called = false;

            loom.on('test.event', function(data) {
                listener1Called = true;
            });
            loom.on('test.event', function(data) {
                listener2Called = true;
                throw new Error('Listener 2 exploded!');
            });
            loom.on('test.event', function(data) {
                listener3Called = true;
            });
        """)

        // 이벤트를 보낸다 (payload는 JSON 문자열, outer만 Base64)
        let eventPayload = "{\"value\":1}"

        let eventMessage: [String: Any] = [
            "kind": "nativeEvent",
            "method": "test.event",
            "payload": eventPayload
        ]
        let eventData = try! JSONSerialization.data(withJSONObject: eventMessage)
        let eventString = String(data: eventData, encoding: .utf8)!
        let eventBase64 = Data(eventString.utf8).base64EncodedString()

        ctx.evaluateScript("window.__loom__.receive('\(eventBase64)');")

        // 모든 리스너가 호출되었는지 확인한다
        let l1 = ctx.evaluateScript("listener1Called")!.toBool()
        let l2 = ctx.evaluateScript("listener2Called")!.toBool()
        let l3 = ctx.evaluateScript("listener3Called")!.toBool()

        #expect(l1 == true)
        #expect(l2 == true)
        #expect(l3 == true)

        // 에러가 콘솔에 기록되었는지 확인한다
        let errorLogged = ctx.evaluateScript("""
            __consoleErrors__.some(function(e) { return e.indexOf('[loom] event listener error:') !== -1; })
        """)!.toBool()
        #expect(errorLogged == true)
    }

    // MARK: - ErrorPayload 필드 매핑 테스트

    @Test("에러 응답의 message 필드가 JS Error.message에 올바르게 전달된다")
    func errorMessageFieldMapsToJSErrorMessage() {
        let ctx = makeJSContext()

        // invoke를 호출하여 pending에 등록한다
        ctx.evaluateScript("""
            var errorResult = null;
            loom.invoke('test.willFail').catch(function(e) {
                errorResult = e;
            });
        """)

        // pending에서 요청 ID를 가져온다
        let requestId = ctx.evaluateScript("""
            var ids = [];
            window.__loom__.pending.forEach(function(v, k) { ids.push(k); });
            ids[0];
        """)!.toString()!

        // Swift ErrorPayload 형태의 에러 응답을 보낸다 (payload는 JSON 문자열, outer만 Base64)
        let errorPayload = "{\"code\":\"METHOD_NOT_FOUND\",\"message\":\"Method not found: test.willFail\",\"plugin\":\"test\",\"method\":\"test.willFail\"}"

        let errorMessage: [String: Any] = [
            "id": requestId,
            "kind": "error",
            "payload": errorPayload
        ]
        let errorData = try! JSONSerialization.data(withJSONObject: errorMessage)
        let errorString = String(data: errorData, encoding: .utf8)!
        let errorBase64 = Data(errorString.utf8).base64EncodedString()

        ctx.evaluateScript("window.__loom__.receive('\(errorBase64)');")

        // Error.message가 Swift의 message 필드 값과 일치하는지 확인한다
        let message = ctx.evaluateScript("errorResult && errorResult.message")!.toString()!
        #expect(message == "Method not found: test.willFail")
    }

    @Test("에러 응답에 code, plugin, method 속성이 포함된다")
    func errorObjectContainsStructuredProperties() {
        let ctx = makeJSContext()

        ctx.evaluateScript("""
            var errorObj = null;
            loom.invoke('myPlugin.doSomething').catch(function(e) {
                errorObj = e;
            });
        """)

        let requestId = ctx.evaluateScript("""
            var ids = [];
            window.__loom__.pending.forEach(function(v, k) { ids.push(k); });
            ids[0];
        """)!.toString()!

        // 모든 필드가 채워진 ErrorPayload를 전송한다 (payload는 JSON 문자열, outer만 Base64)
        let errorPayload = "{\"code\":\"HANDLER_ERROR\",\"message\":\"Something went wrong\",\"plugin\":\"myPlugin\",\"method\":\"myPlugin.doSomething\"}"

        let errorMessage: [String: Any] = [
            "id": requestId,
            "kind": "error",
            "payload": errorPayload
        ]
        let errorData = try! JSONSerialization.data(withJSONObject: errorMessage)
        let errorString = String(data: errorData, encoding: .utf8)!
        let errorBase64 = Data(errorString.utf8).base64EncodedString()

        ctx.evaluateScript("window.__loom__.receive('\(errorBase64)');")

        // 구조화된 속성이 Error 객체에 존재하는지 확인한다
        let code = ctx.evaluateScript("errorObj && errorObj.code")!.toString()!
        let plugin = ctx.evaluateScript("errorObj && errorObj.plugin")!.toString()!
        let method = ctx.evaluateScript("errorObj && errorObj.method")!.toString()!
        let message = ctx.evaluateScript("errorObj && errorObj.message")!.toString()!

        #expect(code == "HANDLER_ERROR")
        #expect(plugin == "myPlugin")
        #expect(method == "myPlugin.doSomething")
        #expect(message == "Something went wrong")
    }

    @Test("payload가 없는 에러 응답은 기본 'Unknown error' 메시지를 사용한다")
    func errorWithoutPayloadUsesDefaultMessage() {
        let ctx = makeJSContext()

        ctx.evaluateScript("""
            var defaultError = null;
            loom.invoke('test.noPayload').catch(function(e) {
                defaultError = e;
            });
        """)

        let requestId = ctx.evaluateScript("""
            var ids = [];
            window.__loom__.pending.forEach(function(v, k) { ids.push(k); });
            ids[0];
        """)!.toString()!

        // payload 없이 에러 응답을 보낸다
        let errorMessage: [String: Any] = [
            "id": requestId,
            "kind": "error"
        ]
        let errorData = try! JSONSerialization.data(withJSONObject: errorMessage)
        let errorString = String(data: errorData, encoding: .utf8)!
        let errorBase64 = Data(errorString.utf8).base64EncodedString()

        ctx.evaluateScript("window.__loom__.receive('\(errorBase64)');")

        let message = ctx.evaluateScript("defaultError && defaultError.message")!.toString()!
        let code = ctx.evaluateScript("defaultError && defaultError.code")!.toString()!

        #expect(message == "Unknown error")
        #expect(code == "UNKNOWN")
    }

    @Test("plugin, method가 null인 ErrorPayload는 JS에서 undefined로 전달된다")
    func errorWithNullOptionalFieldsPassesUndefined() {
        let ctx = makeJSContext()

        ctx.evaluateScript("""
            var partialError = null;
            loom.invoke('test.partial').catch(function(e) {
                partialError = e;
            });
        """)

        let requestId = ctx.evaluateScript("""
            var ids = [];
            window.__loom__.pending.forEach(function(v, k) { ids.push(k); });
            ids[0];
        """)!.toString()!

        // plugin과 method가 없는 ErrorPayload를 전송한다 (payload는 JSON 문자열, outer만 Base64)
        let errorPayload = "{\"code\":\"GENERIC_ERROR\",\"message\":\"Something failed\"}"

        let errorMessage: [String: Any] = [
            "id": requestId,
            "kind": "error",
            "payload": errorPayload
        ]
        let errorData = try! JSONSerialization.data(withJSONObject: errorMessage)
        let errorString = String(data: errorData, encoding: .utf8)!
        let errorBase64 = Data(errorString.utf8).base64EncodedString()

        ctx.evaluateScript("window.__loom__.receive('\(errorBase64)');")

        let code = ctx.evaluateScript("partialError && partialError.code")!.toString()!
        let message = ctx.evaluateScript("partialError && partialError.message")!.toString()!
        let pluginIsUndefined = ctx.evaluateScript("partialError && partialError.plugin === undefined")!.toBool()
        let methodIsUndefined = ctx.evaluateScript("partialError && partialError.method === undefined")!.toBool()

        #expect(code == "GENERIC_ERROR")
        #expect(message == "Something failed")
        #expect(pluginIsUndefined == true)
        #expect(methodIsUndefined == true)
    }

    // MARK: - loom.emit() 테스트

    @Test("loom.emit()이 kind 'webEvent' 메시지를 전송한다")
    func emitSendsEmitKindMessage() {
        let ctx = makeJSContext()

        ctx.evaluateScript("""
            loom.emit('user.action', { key: 'value' });
        """)

        // postMessage로 전송된 메시지를 확인한다
        let rawMessage = ctx.evaluateScript("__postedMessages__[0]")!.toString()!
        let messageData = rawMessage.data(using: .utf8)!
        let parsed = try! JSONSerialization.jsonObject(with: messageData) as! [String: Any]

        #expect(parsed["kind"] as? String == "webEvent")
        #expect(parsed["method"] as? String == "user.action")
        #expect(parsed["payload"] != nil)
    }

    @Test("loom.emit()이 데이터 없이 호출될 수 있다")
    func emitWithoutData() {
        let ctx = makeJSContext()

        ctx.evaluateScript("""
            loom.emit('simple.event');
        """)

        let rawMessage = ctx.evaluateScript("__postedMessages__[0]")!.toString()!
        let messageData = rawMessage.data(using: .utf8)!
        let parsed = try! JSONSerialization.jsonObject(with: messageData) as! [String: Any]

        #expect(parsed["kind"] as? String == "webEvent")
        #expect(parsed["method"] as? String == "simple.event")
    }

    @Test("loom.emit()이 Promise를 반환하지 않는다 (fire-and-forget)")
    func emitDoesNotReturnPromise() {
        let ctx = makeJSContext()

        ctx.evaluateScript("""
            var emitResult = loom.emit('test.event', { data: 1 });
            var isUndefined = (emitResult === undefined);
        """)

        let isUndefined = ctx.evaluateScript("isUndefined")!.toBool()
        #expect(isUndefined == true)

        // pending Map에 추가되지 않았는지 확인
        let pendingSize = ctx.evaluateScript("window.__loom__.pending.size")!.toInt32()
        #expect(pendingSize == 0)
    }

    @Test("loom.emit()이 postMessage 실패 시 예외를 삼킨다")
    func emitSwallowsPostMessageError() {
        let ctx = makeJSContext()

        // postMessage가 예외를 던지도록 설정
        ctx.evaluateScript("""
            window.webkit.messageHandlers.loom.postMessage = function() {
                throw new Error('postMessage failed');
            };
        """)

        // emit 호출이 예외를 던지지 않는다
        ctx.evaluateScript("""
            var emitThrew = false;
            try {
                loom.emit('test.event', { data: 1 });
            } catch(e) {
                emitThrew = true;
            }
        """)

        let threw = ctx.evaluateScript("emitThrew")!.toBool()
        #expect(threw == false)

        // console.error가 호출되었는지 확인
        let errorLogged = ctx.evaluateScript("""
            __consoleErrors__.some(function(e) { return e.indexOf('[loom] emit error:') !== -1; })
        """)!.toBool()
        #expect(errorLogged == true)
    }

    // MARK: - beforeunload pending 정리 테스트

    @Test("beforeunload 이벤트 시 pending Promise가 reject된다")
    func pendingPromisesRejectedOnBeforeUnload() {
        let ctx = makeJSContext()

        // 여러 invoke를 호출하여 pending에 등록한다
        ctx.evaluateScript("""
            var rejectErrors = [];
            loom.invoke('test.method1').catch(function(e) { rejectErrors.push(e.message); });
            loom.invoke('test.method2').catch(function(e) { rejectErrors.push(e.message); });
            loom.invoke('test.method3').catch(function(e) { rejectErrors.push(e.message); });
        """)

        // pending에 3개의 항목이 있는지 확인
        let pendingBefore = ctx.evaluateScript("window.__loom__.pending.size")!.toInt32()
        #expect(pendingBefore == 3)

        // beforeunload 이벤트를 시뮬레이션한다
        ctx.evaluateScript("""
            var beforeUnloadEvent = { type: 'beforeunload' };
            // SDK가 등록한 beforeunload 핸들러를 직접 호출하기 위해
            // window에서 이벤트를 디스패치하는 대신, 핸들러를 실행한다
            // JSContext에는 실제 이벤트 시스템이 없으므로 등록된 핸들러를 추적하여 호출한다
        """)

        // JSContext에는 addEventListener/dispatchEvent가 없으므로
        // SDK 로드 전에 addEventListener를 폴리필해야 한다
        // 하지만 SDK는 이미 로드되었으므로, 다른 접근법을 사용한다:
        // pending을 직접 순회하며 reject하는 것과 동일한 로직을 검증한다

        // 대안: makeJSContext에서 addEventListener 폴리필을 포함한 새 컨텍스트를 만든다
        let ctx2 = JSContext()!
        ctx2.evaluateScript("var window = this;")

        // atob/btoa 폴리필
        ctx2.evaluateScript("""
            var __b64chars__ = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';
            function btoa(input) {
                var str = String(input);
                var output = '';
                for (var i = 0; i < str.length; i += 3) {
                    var a = str.charCodeAt(i);
                    var b = i + 1 < str.length ? str.charCodeAt(i + 1) : 0;
                    var c = i + 2 < str.length ? str.charCodeAt(i + 2) : 0;
                    var idx1 = a >> 2;
                    var idx2 = ((a & 3) << 4) | (b >> 4);
                    var idx3 = ((b & 15) << 2) | (c >> 6);
                    var idx4 = c & 63;
                    if (i + 1 >= str.length) { idx3 = 64; idx4 = 64; }
                    else if (i + 2 >= str.length) { idx4 = 64; }
                    output += __b64chars__[idx1] + __b64chars__[idx2] + __b64chars__[idx3] + __b64chars__[idx4];
                }
                return output;
            }
            function atob(input) {
                var str = String(input).replace(/=+$/, '');
                var output = '';
                for (var i = 0; i < str.length; i += 4) {
                    var a = __b64chars__.indexOf(str[i]);
                    var b = i + 1 < str.length ? __b64chars__.indexOf(str[i + 1]) : 0;
                    var c = i + 2 < str.length ? __b64chars__.indexOf(str[i + 2]) : 0;
                    var d = i + 3 < str.length ? __b64chars__.indexOf(str[i + 3]) : 0;
                    output += String.fromCharCode((a << 2) | (b >> 4));
                    if (c !== 64 && i + 2 < str.length) output += String.fromCharCode(((b & 15) << 4) | (c >> 2));
                    if (d !== 64 && i + 3 < str.length) output += String.fromCharCode(((c & 3) << 6) | d);
                }
                return output;
            }
        """)

        // setTimeout/clearTimeout 폴리필
        ctx2.evaluateScript("""
            var __timers__ = {};
            var __nextTimerId__ = 1;
            function setTimeout(fn, ms) {
                var id = __nextTimerId__++;
                __timers__[id] = { fn: fn, ms: ms, cleared: false };
                return id;
            }
            function clearTimeout(id) {
                if (__timers__[id]) { __timers__[id].cleared = true; }
            }
        """)

        // console 폴리필
        ctx2.evaluateScript("""
            var console = { error: function() {}, log: function() {} };
        """)

        // addEventListener 폴리필 (beforeunload 핸들러를 캡처)
        ctx2.evaluateScript("""
            var __eventListeners__ = {};
            window.addEventListener = function(type, handler) {
                if (!__eventListeners__[type]) __eventListeners__[type] = [];
                __eventListeners__[type].push(handler);
            };
            window.dispatchEvent = function(evt) {
                var handlers = __eventListeners__[evt.type] || [];
                for (var i = 0; i < handlers.length; i++) {
                    handlers[i](evt);
                }
            };
        """)

        // postMessage 스텁
        ctx2.evaluateScript("""
            var __postedMessages__ = [];
            window.webkit = {
                messageHandlers: {
                    loom: {
                        postMessage: function(msg) { __postedMessages__.push(msg); }
                    }
                }
            };
        """)

        // SDK 로드
        ctx2.evaluateScript(sdk)

        // invoke를 호출하여 pending에 등록
        ctx2.evaluateScript("""
            var unloadErrors = [];
            loom.invoke('test.method1').catch(function(e) { unloadErrors.push(e.message); });
            loom.invoke('test.method2').catch(function(e) { unloadErrors.push(e.message); });
        """)

        let pendingBeforeUnload = ctx2.evaluateScript("window.__loom__.pending.size")!.toInt32()
        #expect(pendingBeforeUnload == 2)

        // beforeunload 이벤트를 디스패치
        ctx2.evaluateScript("""
            window.dispatchEvent({ type: 'beforeunload' });
        """)

        // pending이 비었는지 확인
        let pendingAfterUnload = ctx2.evaluateScript("window.__loom__.pending.size")!.toInt32()
        #expect(pendingAfterUnload == 0)

        // 에러 메시지가 올바른지 확인
        let errorCount = ctx2.evaluateScript("unloadErrors.length")!.toInt32()
        #expect(errorCount == 2)

        let firstError = ctx2.evaluateScript("unloadErrors[0]")!.toString()!
        #expect(firstError == "Page is being unloaded")
    }

    @Test("beforeunload 시 타임아웃 타이머가 정리된다")
    func beforeUnloadClearsTimeoutTimers() {
        let ctx2 = JSContext()!
        ctx2.evaluateScript("var window = this;")

        // 폴리필 설정
        ctx2.evaluateScript("""
            var __b64chars__ = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';
            function btoa(input) {
                var str = String(input);
                var output = '';
                for (var i = 0; i < str.length; i += 3) {
                    var a = str.charCodeAt(i);
                    var b = i + 1 < str.length ? str.charCodeAt(i + 1) : 0;
                    var c = i + 2 < str.length ? str.charCodeAt(i + 2) : 0;
                    var idx1 = a >> 2;
                    var idx2 = ((a & 3) << 4) | (b >> 4);
                    var idx3 = ((b & 15) << 2) | (c >> 6);
                    var idx4 = c & 63;
                    if (i + 1 >= str.length) { idx3 = 64; idx4 = 64; }
                    else if (i + 2 >= str.length) { idx4 = 64; }
                    output += __b64chars__[idx1] + __b64chars__[idx2] + __b64chars__[idx3] + __b64chars__[idx4];
                }
                return output;
            }
            function atob(input) {
                var str = String(input).replace(/=+$/, '');
                var output = '';
                for (var i = 0; i < str.length; i += 4) {
                    var a = __b64chars__.indexOf(str[i]);
                    var b = i + 1 < str.length ? __b64chars__.indexOf(str[i + 1]) : 0;
                    var c = i + 2 < str.length ? __b64chars__.indexOf(str[i + 2]) : 0;
                    var d = i + 3 < str.length ? __b64chars__.indexOf(str[i + 3]) : 0;
                    output += String.fromCharCode((a << 2) | (b >> 4));
                    if (c !== 64 && i + 2 < str.length) output += String.fromCharCode(((b & 15) << 4) | (c >> 2));
                    if (d !== 64 && i + 3 < str.length) output += String.fromCharCode(((c & 3) << 6) | d);
                }
                return output;
            }
        """)

        ctx2.evaluateScript("""
            var __timers__ = {};
            var __nextTimerId__ = 1;
            var __clearedTimerIds__ = [];
            function setTimeout(fn, ms) {
                var id = __nextTimerId__++;
                __timers__[id] = { fn: fn, ms: ms, cleared: false };
                return id;
            }
            function clearTimeout(id) {
                if (__timers__[id]) { __timers__[id].cleared = true; }
                __clearedTimerIds__.push(id);
            }
        """)

        ctx2.evaluateScript("""
            var console = { error: function() {}, log: function() {} };
        """)

        ctx2.evaluateScript("""
            var __eventListeners__ = {};
            window.addEventListener = function(type, handler) {
                if (!__eventListeners__[type]) __eventListeners__[type] = [];
                __eventListeners__[type].push(handler);
            };
            window.dispatchEvent = function(evt) {
                var handlers = __eventListeners__[evt.type] || [];
                for (var i = 0; i < handlers.length; i++) {
                    handlers[i](evt);
                }
            };
        """)

        ctx2.evaluateScript("""
            var __postedMessages__ = [];
            window.webkit = {
                messageHandlers: {
                    loom: {
                        postMessage: function(msg) { __postedMessages__.push(msg); }
                    }
                }
            };
        """)

        ctx2.evaluateScript(sdk)

        // invoke를 호출하여 타이머가 등록된 pending 항목을 만든다
        ctx2.evaluateScript("""
            loom.invoke('test.method1').catch(function() {});
        """)

        // clearTimeout이 호출되기 전의 상태를 확인
        let clearedBefore = ctx2.evaluateScript("__clearedTimerIds__.length")!.toInt32()

        // beforeunload 이벤트를 디스패치
        ctx2.evaluateScript("window.dispatchEvent({ type: 'beforeunload' });")

        // clearTimeout이 호출되었는지 확인
        let clearedAfter = ctx2.evaluateScript("__clearedTimerIds__.length")!.toInt32()
        #expect(clearedAfter > clearedBefore)
    }

    // MARK: - 현대적 인코딩 테스트

    @Test("유니코드 문자가 현대적 b64encode/b64decode에서 보존된다")
    func unicodeRoundTripWithModernEncoding() {
        let ctx = makeJSContext()

        // SDK의 b64encode/b64decode를 테스트할 수 없으므로 (IIFE 내부 함수)
        // invoke + receive 왕복을 통해 유니코드 보존을 검증한다
        ctx.evaluateScript("""
            var roundTripResult = null;
            loom.invoke('test.unicode', { text: '안녕하세요 \u{201C}스마트 따옴표\u{201D}' })
                .then(function(data) { roundTripResult = data; });
        """)

        // 전송된 메시지를 가져온다
        _ = ctx.evaluateScript("__postedMessages__[0]")!.toString()!

        // 요청 ID를 추출한다
        let requestId = ctx.evaluateScript("""
            var ids = [];
            window.__loom__.pending.forEach(function(v, k) { ids.push(k); });
            ids[0];
        """)!.toString()!

        // 유니코드가 포함된 응답을 보낸다 (payload는 JSON 문자열, outer만 Base64)
        let responsePayload = "{\"echo\":\"안녕하세요 \\u201C스마트 따옴표\\u201D\"}"

        let responseMessage: [String: Any] = [
            "id": requestId,
            "kind": "response",
            "payload": responsePayload
        ]
        let responseData = try! JSONSerialization.data(withJSONObject: responseMessage)
        let responseString = String(data: responseData, encoding: .utf8)!
        let responseBase64 = Data(responseString.utf8).base64EncodedString()

        ctx.evaluateScript("window.__loom__.receive('\(responseBase64)');")

        let echoValue = ctx.evaluateScript("roundTripResult && roundTripResult.echo")!.toString()!
        #expect(echoValue.contains("\u{201C}"))
        #expect(echoValue.contains("\u{201D}"))
    }
}
