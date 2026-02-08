// 앱 개발자가 직접 사용하는 API만 재수출한다.
// - Core: AppConfiguration, EntryPoint, WindowConfiguration 등 앱 설정 타입
// - Plugin: Plugin 프로토콜 등 커스텀 플러그인 작성에 필요한 타입
// Bridge, Platform, WebEngine은 프레임워크 내부 조합용이므로 재수출하지 않는다.
@_exported import Core
@_exported import Plugin

import Platform

/// 앱 개발자가 메뉴를 구성할 때 사용하는 타입. `LoomApplication.menus`에서 참조된다.
public typealias MenuItem = Platform.MenuItem
