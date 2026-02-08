// Loom Bridge SDK Type Definitions
// Generated from Swift plugin sources

declare namespace Loom {
    // ── FileSystem plugin types ──────────────────────────────────────────

    /** Parameters for `filesystem.readFile`. */
    interface ReadFileParams {
        /** Absolute or tilde-prefixed path to the file. */
        path: string;
    }

    /** Result of `filesystem.readFile`. */
    interface ReadFileResult {
        /** Base64-encoded file content. */
        content: string;
    }

    /** Parameters for `filesystem.writeFile`. */
    interface WriteFileParams {
        /** Absolute or tilde-prefixed path to write to. */
        path: string;
        /** File content. If base64-encoded data is provided it will be decoded; otherwise written as UTF-8. */
        content: string;
    }

    /** Parameters for `filesystem.exists`. */
    interface ExistsParams {
        /** Path to check. */
        path: string;
    }

    /** Result of `filesystem.exists`. */
    interface ExistsResult {
        /** Whether the file or directory exists. */
        exists: boolean;
    }

    /** Parameters for `filesystem.readDir`. */
    interface ReadDirParams {
        /** Path to the directory. */
        path: string;
    }

    /** Result of `filesystem.readDir`. */
    interface ReadDirResult {
        /** Names of the entries in the directory. */
        entries: string[];
    }

    /** Parameters for `filesystem.remove`. */
    interface RemoveParams {
        /** Path to the file or directory to remove. */
        path: string;
    }

    // ── Dialog plugin types ──────────────────────────────────────────────

    /** Parameters for `dialog.showAlert`. */
    interface ShowAlertParams {
        /** The alert title (message text). */
        title: string;
        /** Optional informative text displayed below the title. */
        message?: string;
        /** Alert style. Defaults to `"informational"`. */
        style?: 'informational' | 'warning' | 'critical';
    }

    /** Result of `dialog.showAlert`. */
    interface ShowAlertResult {
        /** `"ok"` if the user clicked OK, `"cancel"` otherwise. */
        response: 'ok' | 'cancel';
    }

    /** Parameters for `dialog.openFile`. */
    interface OpenFileParams {
        /** Panel title. Defaults to `"Open"`. */
        title?: string;
        /** Allowed file extensions (e.g. `["png", "jpg"]`). */
        allowedTypes?: string[];
        /** Whether multiple files can be selected. Defaults to `false`. */
        multiple?: boolean;
        /** Whether directories can be selected. Defaults to `false`. */
        directories?: boolean;
    }

    /** Result of `dialog.openFile`. */
    interface OpenFileResult {
        /** Selected file paths, or an empty array if cancelled. */
        paths: string[];
    }

    /** Parameters for `dialog.saveFile`. */
    interface SaveFileParams {
        /** Panel title. Defaults to `"Save"`. */
        title?: string;
        /** Pre-filled file name in the save panel. */
        defaultName?: string;
    }

    /** Result of `dialog.saveFile`. */
    interface SaveFileResult {
        /** Chosen file path, or an empty string if cancelled. */
        path: string;
    }

    // ── Clipboard plugin types ───────────────────────────────────────────

    /** Result of `clipboard.readText`. */
    interface ReadTextResult {
        /** The current clipboard text, or an empty string if none. */
        text: string;
    }

    /** Parameters for `clipboard.writeText`. */
    interface WriteTextParams {
        /** Text to write to the clipboard. */
        text: string;
    }

    // ── Process plugin types ───────────────────────────────────────────────

    /** Parameters for `process.execute`. */
    interface ExecuteParams {
        /** Absolute path to the executable. */
        command: string;
        /** Optional command-line arguments. */
        arguments?: string[];
        /** Optional working directory for the process. */
        cwd?: string;
    }

    /** Result of `process.execute`. */
    interface ExecuteResult {
        /** Process exit code. */
        exitCode: number;
        /** Standard output content. */
        stdout: string;
        /** Standard error content. */
        stderr: string;
    }

    // ── Shell plugin types ───────────────────────────────────────────────

    /** Parameters for `shell.openURL`. */
    interface OpenURLParams {
        /** The URL to open in the default browser or handler. Must use an allowed scheme. */
        url: string;
    }

    /** Parameters for `shell.openPath`. */
    interface OpenPathParams {
        /** The file-system path to reveal in Finder. */
        path: string;
    }

    // ── Invoke options ────────────────────────────────────────────────

    /** Optional settings for a single `invoke()` call. */
    interface InvokeOptions {
        /** Per-call timeout in milliseconds. Overrides the default timeout. */
        timeout?: number;
    }

    // ── Error types ──────────────────────────────────────────────────

    /** Error codes used by the Bridge SDK. */
    type ErrorCode = 'TIMEOUT' | 'HANDLER_ERROR' | 'METHOD_NOT_FOUND' | 'UNKNOWN' | (string & {});

    /** Structured error object returned by `invoke()` on failure. */
    interface BridgeError extends Error {
        /** Machine-readable error code. */
        code: ErrorCode;
        /** The plugin name, if the error originated from a plugin. */
        plugin?: string;
        /** The method name that caused the error. */
        method?: string;
    }
}

/** The Loom Bridge SDK interface exposed as `window.loom`. */
interface LoomSDK {
    // ── FileSystem plugin ────────────────────────────────────────────────

    /**
     * Reads the contents of a file.
     * @returns Base64-encoded file content.
     */
    invoke(method: 'filesystem.readFile', params: Loom.ReadFileParams, options?: Loom.InvokeOptions): Promise<Loom.ReadFileResult>;

    /**
     * Writes content to a file, creating it if necessary.
     */
    invoke(method: 'filesystem.writeFile', params: Loom.WriteFileParams, options?: Loom.InvokeOptions): Promise<void>;

    /**
     * Checks whether a file or directory exists at the given path.
     */
    invoke(method: 'filesystem.exists', params: Loom.ExistsParams, options?: Loom.InvokeOptions): Promise<Loom.ExistsResult>;

    /**
     * Lists the entries in a directory.
     */
    invoke(method: 'filesystem.readDir', params: Loom.ReadDirParams, options?: Loom.InvokeOptions): Promise<Loom.ReadDirResult>;

    /**
     * Removes a file or directory at the given path.
     */
    invoke(method: 'filesystem.remove', params: Loom.RemoveParams, options?: Loom.InvokeOptions): Promise<void>;

    // ── Dialog plugin ────────────────────────────────────────────────────

    /**
     * Displays a modal alert dialog with OK and Cancel buttons.
     */
    invoke(method: 'dialog.showAlert', params: Loom.ShowAlertParams, options?: Loom.InvokeOptions): Promise<Loom.ShowAlertResult>;

    /**
     * Opens a file-selection dialog.
     */
    invoke(method: 'dialog.openFile', params?: Loom.OpenFileParams, options?: Loom.InvokeOptions): Promise<Loom.OpenFileResult>;

    /**
     * Opens a save-file dialog.
     */
    invoke(method: 'dialog.saveFile', params?: Loom.SaveFileParams, options?: Loom.InvokeOptions): Promise<Loom.SaveFileResult>;

    // ── Clipboard plugin ─────────────────────────────────────────────────

    /**
     * Reads the current text content of the system clipboard.
     */
    invoke(method: 'clipboard.readText', params?: Record<string, never>, options?: Loom.InvokeOptions): Promise<Loom.ReadTextResult>;

    /**
     * Writes text to the system clipboard.
     */
    invoke(method: 'clipboard.writeText', params: Loom.WriteTextParams, options?: Loom.InvokeOptions): Promise<void>;

    // ── Process plugin ─────────────────────────────────────────────────────

    /**
     * Executes an external process and returns its output.
     * The executable path must pass the security policy validation.
     */
    invoke(method: 'process.execute', params: Loom.ExecuteParams, options?: Loom.InvokeOptions): Promise<Loom.ExecuteResult>;

    // ── Shell plugin ─────────────────────────────────────────────────────

    /**
     * Opens a URL in the default browser or registered handler.
     * The URL scheme must be in the allowed whitelist.
     */
    invoke(method: 'shell.openURL', params: Loom.OpenURLParams, options?: Loom.InvokeOptions): Promise<void>;

    /**
     * Reveals a file-system path in Finder.
     */
    invoke(method: 'shell.openPath', params: Loom.OpenPathParams, options?: Loom.InvokeOptions): Promise<void>;

    // ── Generic ──────────────────────────────────────────────────────────

    /**
     * Invokes any plugin method by its fully-qualified name.
     * @param method - Plugin method name in the format `"pluginName.methodName"`.
     * @param params - Optional JSON-serialisable parameters.
     * @returns A Promise that resolves with the plugin's response payload.
     */
    invoke(method: string, params?: any, options?: Loom.InvokeOptions): Promise<any>;

    // ── Web-to-Native Events ────────────────────────────────────────────

    /**
     * Sends a fire-and-forget event to the native side.
     * Unlike `invoke()`, this method does not wait for a response.
     * @param event - The event name (e.g., `"myPlugin.userAction"`).
     * @param data - Optional JSON-serialisable payload to send with the event.
     */
    emit(event: string, data?: any): void;

    // ── Events ───────────────────────────────────────────────────────────

    /**
     * Subscribes to an event emitted by the native side.
     * @param event - The event name to listen for.
     * @param callback - Called with the event payload each time the event fires.
     * @returns An unsubscribe function. Call it to remove the listener.
     */
    on(event: string, callback: (data: any) => void): () => void;

    /**
     * Subscribes to an event for a single firing only.
     * The listener is automatically removed after it is called once.
     * @param event - The event name to listen for.
     * @param callback - Called with the event data once.
     * @returns An unsubscribe function. Call it to cancel the one-shot listener before it fires.
     */
    once(event: string, callback: (data: any) => void): () => void;

    // ── Readiness ─────────────────────────────────────────────────────────

    /**
     * A Promise that resolves when the SDK is fully initialized.
     * Usage: `await loom.ready;`
     */
    readonly ready: Promise<void>;

    // ── Configuration ────────────────────────────────────────────────────

    /**
     * Sets the default timeout (in milliseconds) for all future `invoke()` calls.
     * The initial default is 30 000 ms.
     * @param ms - Timeout in milliseconds.
     */
    setDefaultTimeout(ms: number): void;
}

/** Internal bridge object used by the native side to deliver messages. */
interface LoomInternal {
    /** Map of pending request IDs to their Promise resolve/reject handlers. */
    readonly pending: Map<string, { resolve: (value: any) => void; reject: (reason: any) => void; timeoutId: number | null }>;
    /** Map of event names to sets of listener callbacks. */
    readonly listeners: Map<string, Set<(data: any) => void>>;
    /** Counter used to generate unique message IDs. */
    nextId: number;
    /** Default timeout in milliseconds for invoke calls. */
    _defaultTimeout: number;
    /**
     * Called by the native side to deliver a response, error, or event.
     * Messages are base64-encoded JSON strings.
     * @param encoded - A base64-encoded JSON message from the native bridge.
     */
    receive(encoded: string): void;
}

declare const loom: LoomSDK;
declare const __loom__: LoomInternal;

interface Window {
    loom: LoomSDK;
    __loom__: LoomInternal;
}
