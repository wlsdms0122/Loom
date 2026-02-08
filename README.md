# Loom

**A lightweight native-web hybrid desktop framework for macOS**

[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-macOS%2014+-blue.svg)](https://www.apple.com/macos/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

Build fast, native macOS apps with web technologies. Loom leverages WKWebView for rendering and Swift 6.0 for backend logic, delivering app sizes of 3-10MB without bundling Chromium.

---

## Highlights

- **Tiny footprint** - 3-10MB apps vs. Electron's 150MB+, using OS-native WKWebView (no Chromium)
- **Swift-native** - First-class Swift 6.0 concurrency with actor-based state isolation
- **Zero dependencies** - Pure SPM project with no external dependencies
- **Type-safe bridge** - Codable-based async communication between Swift and JavaScript
- **Plugin system** - Modular architecture with 5 built-in plugins (filesystem, dialog, clipboard, shell, process)
- **Security-first** - Path sandboxing and URL scheme whitelisting built-in
- **Developer-friendly** - Hot reload, Vite/Webpack HMR integration, WebKit Inspector
- **Production-ready** - ~3,666 lines of battle-tested Swift code

---

## Requirements

- **macOS** 14.0+
- **Swift** 6.0+
- **Xcode** 16.0+ (for development)

---

## Installation

Add Loom to your Swift package dependencies in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/Loom.git", from: "1.0.0")
]
```

Then add the product to your target:

```swift
targets: [
    .executableTarget(
        name: "YourApp",
        dependencies: [
            .product(name: "Loom", package: "Loom")
        ]
    )
]
```

---

## Quick Start

Create a minimal Loom app in 10 lines:

```swift
import Loom

@main
struct MyApp: LoomApplication {
    var configuration: AppConfiguration {
        AppConfiguration(
            name: "Hello Loom",
            entry: .bundle(resource: "index", extension: "html"),
            window: WindowConfiguration(width: 1000, height: 700)
        )
    }

    var plugins: [any Plugin] {
        [FileSystemPlugin(), DialogPlugin(), ClipboardPlugin()]
    }
}
```

Create `Resources/index.html`:

```html
<!DOCTYPE html>
<html>
<head>
    <title>Hello Loom</title>
    <script type="module">
        await loom.ready;

        // Call Swift from JavaScript
        const result = await loom.invoke('dialog.showMessage', {
            message: 'Hello from Loom!',
            informativeText: 'This is a native macOS dialog.',
            alertStyle: 'informational'
        });

        console.log('User clicked:', result.response);
    </script>
</head>
<body>
    <h1>Hello Loom</h1>
</body>
</html>
```

Run with `swift run` and see your app launch.

For a complete walkthrough, see [Getting Started Guide](docs/guide/01-getting-started.md).

---

## Architecture

Loom is organized into 7 modular packages:

| Module | Purpose |
|--------|---------|
| **Core** | App lifecycle, DI container, EventBus, Logger, SecurityPolicy |
| **Bridge** | Bidirectional async JS ↔ Swift communication with Promise support |
| **Platform** | Cross-platform abstraction protocols (WindowManager, FileSystem, etc.) |
| **PlatformMacOS** | macOS-specific implementations (WKWebView, NSWindow, etc.) |
| **Plugin** | Plugin system with type-safe JSON handlers + 5 built-in plugins |
| **WebEngine** | Web rendering engine abstraction and JS SDK injection |
| **Loom** | Integration entry point and `LoomApplication` protocol |

**Dependency Flow:**
```
Loom (integration layer)
  ├─ Core (independent)
  ├─ Bridge → Core
  ├─ Platform → Core
  ├─ PlatformMacOS → Core, Platform
  ├─ Plugin → Core, Bridge, Platform
  └─ WebEngine → Core, Platform
```

Each module is independently importable for fine-grained control. See the [Architecture Guide](docs/guide/03-architecture.md) for details.

---

## Built-in Plugins

Loom ships with 5 production-ready plugins:

| Plugin | Methods | Security |
|--------|---------|----------|
| **FileSystemPlugin** | `read`, `write`, `exists`, `list`, `delete` | Requires `PathSandbox` |
| **DialogPlugin** | `showMessage`, `showOpenPanel`, `showSavePanel` | None |
| **ClipboardPlugin** | `read`, `write` | None |
| **ShellPlugin** | `open` (URLs/paths) | Requires `URLSchemeWhitelist` |
| **ProcessPlugin** | `execute` (external processes) | Requires `PathSandbox` |

Usage example:

```javascript
// Read a file (Swift side must configure PathSandbox)
const content = await loom.invoke('fs.read', {
    path: '/path/to/file.txt'
});

// Show native save dialog
const result = await loom.invoke('dialog.showSavePanel', {
    title: 'Export Data',
    nameFieldStringValue: 'data.json',
    allowedContentTypes: ['json']
});
```

See [Built-in Plugins Guide](docs/guide/05-builtin-plugins.md) for full API reference.

---

## JavaScript SDK

The Loom bridge provides a Promise-based SDK injected into every page:

```javascript
// Wait for bridge to be ready
await loom.ready;

// Invoke Swift methods
const result = await loom.invoke('plugin.method', {
    param: 'value'
}, { timeout: 5000 });

// Listen to Swift events
const unsubscribe = loom.on('window.resized', (data) => {
    console.log('New size:', data.width, data.height);
});

// Send events to Swift
loom.emit('user.action', { action: 'clicked', target: 'button' });

// One-time listeners
loom.once('app.ready', () => console.log('App initialized'));

// Configure global timeout
loom.setDefaultTimeout(10000); // 10 seconds
```

**TypeScript Support:** Loom includes `loom.d.ts` for full type safety. See [Bridge SDK Guide](docs/guide/06-bridge-sdk.md).

---

## Security

Loom implements a multi-layer security model:

- **PathSandbox** - Whitelist allowed file system paths for plugins
- **URLSchemeWhitelist** - Restrict external URL schemes (http, https, mailto, etc.)
- **CSP Support** - Content Security Policy headers for web resources
- **Secure Bridge** - All messages validated and type-checked via Codable

Example configuration:

```swift
var configuration: AppConfiguration {
    AppConfiguration(
        name: "SecureApp",
        entry: .bundle(resource: "index", extension: "html"),
        window: WindowConfiguration(width: 800, height: 600),
        security: SecurityPolicy(
            pathSandbox: ["/Users/username/Documents/"],
            urlSchemeWhitelist: ["https"]
        )
    )
}
```

Plugins that violate the security policy will throw errors at runtime. See [Security Guide](docs/guide/08-security.md) for best practices.

---

## Development

**Hot Reload:** Loom supports file watching for instant UI updates during development.

```swift
var configuration: AppConfiguration {
    #if DEBUG
    AppConfiguration(
        entry: .url("http://localhost:5173"), // Vite dev server
        enableHotReload: true,
        hotReloadPaths: ["/path/to/project/src"]
    )
    #else
    AppConfiguration(
        entry: .bundle(resource: "index", extension: "html")
    )
    #endif
}
```

**WebKit Inspector:** Automatically enabled in DEBUG builds (right-click → Inspect Element).

**Vite/Webpack HMR:** Works seamlessly with modern bundlers.

See [Development Guide](docs/guide/09-development.md) for debugging tips and workflows.

---

## Documentation

Comprehensive guides are available in `docs/guide/`:

1. [Overview](docs/guide/00-overview.md) - Framework overview and comparisons
2. [Getting Started](docs/guide/01-getting-started.md) - Your first Loom app
3. [Configuration](docs/guide/02-configuration.md) - Entry points, window settings, app config
4. [Architecture](docs/guide/03-architecture.md) - Module structure, data flow, concurrency
5. [Plugin System](docs/guide/04-plugin-system.md) - Creating custom plugins
6. [Built-in Plugins](docs/guide/05-builtin-plugins.md) - API reference for 5 built-in plugins
7. [Bridge SDK](docs/guide/06-bridge-sdk.md) - JavaScript SDK reference
8. [Platform Layer](docs/guide/07-platform-layer.md) - Cross-platform abstractions
9. [Security](docs/guide/08-security.md) - Security model and policies
10. [Development](docs/guide/09-development.md) - DevTools, hot reload, debugging
11. [Testing](docs/guide/10-testing.md) - Testing strategies with LoomTestKit
12. [Build & Commands](docs/guide/11-build-and-commands.md) - Build, test, run commands

---

## Comparison with Alternatives

| Feature | Electron | Tauri | Loom |
|---------|----------|-------|------|
| **Backend** | Node.js | Rust | Swift |
| **Rendering** | Chromium (bundled) | OS WebView | WKWebView (OS-native) |
| **Typical App Size** | 150MB+ | 3-10MB | 3-10MB |
| **Memory Usage** | High | Low | Low |
| **macOS Integration** | Medium | Medium | **High** (native Swift) |
| **Build System** | npm/webpack | Cargo | Swift Package Manager |
| **Concurrency Model** | Event Loop | Tokio | Swift Concurrency (async/await) |
| **Cross-Platform** | Windows/Linux/macOS | Windows/Linux/macOS | macOS (Windows/Linux planned) |
| **Hot Reload** | Yes | Yes | Yes |
| **TypeScript Support** | Yes | Yes | Yes |

**When to choose Loom:**
- Building macOS-first apps with deep system integration
- Want Swift's memory safety and modern concurrency
- Need minimal app size and memory footprint
- Prefer native tooling (Xcode, SPM) over JavaScript ecosystem

---

## Roadmap

### Phase 2 (In Progress)
- Multi-window support
- Global keyboard shortcuts
- System notifications
- npm package for easier web tooling integration

### Phase 3 (Planned)
- CLI tools for project scaffolding
- App bundling and code signing automation
- Notarization helpers
- Auto-update system

### Phase 4 (Future)
- Windows support (WinUI WebView2)
- Linux support (WebKitGTK)
- Cross-platform plugin APIs

---

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

**Development setup:**

```bash
git clone https://github.com/yourusername/Loom.git
cd Loom
swift build
swift test
```

Please ensure all tests pass and follow Swift 6.0 strict concurrency guidelines.

---

## License

Loom is released under the MIT License. See [LICENSE](LICENSE) for details.

**Copyright (c) 2025 Jeong Jineun**

---

## Acknowledgments

Built with love for the macOS developer community. Inspired by Electron and Tauri, designed for Swift-first development.

**Questions?** Open an issue or start a discussion on GitHub.
