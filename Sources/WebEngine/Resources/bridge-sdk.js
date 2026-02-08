(function() {
    'use strict';

    /**
     * Ready promise — resolves when the SDK is fully initialized.
     * @type {Promise<void>}
     */
    let _readyResolve;
    const _readyPromise = new Promise(resolve => { _readyResolve = resolve; });

    /**
     * Decodes a base64 string back to UTF-8 using modern APIs.
     * Uses percent-hex encoding with decodeURIComponent for modern decoding.
     * @param {string} str - The base64 string to decode.
     * @returns {string} Decoded UTF-8 string.
     */
    function b64decode(str) {
        const binary = atob(str);
        const percentEncoded = Array.prototype.map.call(binary, c =>
            '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2)
        ).join('');
        return decodeURIComponent(percentEncoded);
    }

    /**
     * Internal bridge state used by the native side to deliver messages.
     * Exposed as `window.__loom__`.
     *
     * @namespace __loom__
     * @property {Map<string, {resolve: Function, reject: Function, timeoutId: number|null}>} pending
     *   Map of in-flight request IDs to their Promise handlers and timeout IDs.
     * @property {Map<string, Set<Function>>} listeners
     *   Map of event names to sets of registered callback functions.
     * @property {number} nextId - Auto-incrementing counter for generating unique message IDs.
     * @property {number} _defaultTimeout - Default timeout in milliseconds for invoke calls (initially 30000).
     */
    const internal = {
        pending: new Map(),
        listeners: new Map(),
        nextId: 0,
        _defaultTimeout: 30000,
        dragRegions: [],

        /**
         * Receives a message from the native side and dispatches it.
         *
         * This method is called by the native bridge (Swift/WKWebView) to deliver
         * responses, errors, and events. It should not be called directly by
         * application code.
         *
         * Message kinds:
         * - `"response"` - Resolves the pending Promise for the matching request ID.
         * - `"error"` - Rejects the pending Promise with an Error for the matching request ID.
         * - `"nativeEvent"` - Dispatches the payload to all registered listeners for the event name.
         *
         * @param {string} encoded - A base64-encoded JSON string containing a message
         *   with the shape `{ kind, id?, method?, payload? }`. The `payload` field,
         *   if present, is itself a base64-encoded JSON string.
         */
        receive(encoded) {
            try {
                const message = JSON.parse(b64decode(encoded));
                if (message.kind === 'response' || message.kind === 'error') {
                    const p = this.pending.get(message.id);
                    if (p) {
                        if (p.timeoutId != null) {
                            clearTimeout(p.timeoutId);
                        }
                        if (message.kind === 'response') {
                            const data = message.payload
                                ? JSON.parse(message.payload)
                                : null;
                            p.resolve(data);
                        } else {
                            const err = message.payload
                                ? JSON.parse(message.payload)
                                : { message: 'Unknown error', code: 'UNKNOWN' };
                            const error = new Error(err.message || 'Unknown error');
                            error.code = err.code;
                            error.plugin = err.plugin;
                            error.method = err.method;
                            p.reject(error);
                        }
                        this.pending.delete(message.id);
                    }
                } else if (message.kind === 'nativeEvent') {
                    const data = message.payload
                        ? JSON.parse(message.payload)
                        : null;
                    const listeners = this.listeners.get(message.method);
                    if (listeners) {
                        listeners.forEach(cb => {
                            try { cb(data); } catch(e) { console.error('[loom] event listener error:', e); }
                        });
                    }
                }
            } catch (e) {
                console.error('[loom] receive error:', e);
            }
        }
    };
    Object.defineProperty(window, '__loom__', {
        value: internal,
        writable: false,
        configurable: false
    });

    // ── Window Drag Region helpers ──────────────────────────────────────

    /**
     * Converts a CSS-like region descriptor into an absolute rect
     * within the given viewport dimensions.
     *
     * @param {{top?: number, left?: number, right?: number, bottom?: number, width?: number, height?: number}} region
     * @param {number} viewportWidth
     * @param {number} viewportHeight
     * @returns {{left: number, top: number, right: number, bottom: number}}
     */
    function resolveRegion(region, viewportWidth, viewportHeight) {
        var left = region.left ?? 0;
        var top = region.top ?? 0;
        var right, bottom;

        if (region.width !== undefined) {
            right = left + region.width;
        } else {
            right = viewportWidth - (region.right ?? 0);
        }

        if (region.height !== undefined) {
            bottom = top + region.height;
        } else {
            bottom = viewportHeight - (region.bottom ?? 0);
        }

        return { left: left, top: top, right: right, bottom: bottom };
    }

    /**
     * Tests whether a point falls inside any of the registered drag regions.
     *
     * @param {number} x - clientX of the pointer event.
     * @param {number} y - clientY of the pointer event.
     * @returns {boolean}
     */
    function hitTestDragRegions(x, y) {
        var w = window.innerWidth;
        var h = window.innerHeight;
        return internal.dragRegions.some(function(region) {
            var rect = resolveRegion(region, w, h);
            return x >= rect.left && x < rect.right && y >= rect.top && y < rect.bottom;
        });
    }

    /** Selector for interactive elements that should NOT trigger a window drag. */
    var INTERACTIVE_SELECTOR = 'button, a, input, select, textarea, [contenteditable], [data-loom-no-drag]';

    // mousedown → start native window drag
    document.addEventListener('mousedown', function(e) {
        if (e.button !== 0) return;
        if (internal.dragRegions.length === 0) return;
        if (!hitTestDragRegions(e.clientX, e.clientY)) return;
        if (e.target.closest(INTERACTIVE_SELECTOR)) return;

        e.preventDefault();
        window.loom.invoke('window.startDrag');
    });

    // dblclick → toggle window zoom (macOS title-bar behaviour)
    document.addEventListener('dblclick', function(e) {
        if (internal.dragRegions.length === 0) return;
        if (!hitTestDragRegions(e.clientX, e.clientY)) return;
        if (e.target.closest(INTERACTIVE_SELECTOR)) return;

        e.preventDefault();
        window.loom.invoke('window.toggleZoom');
    });

    /**
     * The Loom Bridge SDK, exposed as `window.loom`.
     *
     * Provides a Promise-based interface for invoking native plugin methods
     * and subscribing to events emitted by the native side.
     *
     * @namespace loom
     */
    Object.defineProperty(window, 'loom', {
        value: {
            /**
             * A Promise that resolves when the SDK is fully initialized.
             * Usage: `await loom.ready;`
             * @type {Promise<void>}
             */
            ready: _readyPromise,

            /**
             * Invokes a plugin method and returns a Promise with the result.
             *
             * The method name should be in the format `"pluginName.methodName"`.
             * The SDK automatically prefixes it with `"plugin."` before sending to
             * the native bridge.
             *
             * Built-in plugins and their methods:
             * - `filesystem.readFile`, `filesystem.writeFile`, `filesystem.exists`,
             *   `filesystem.readDir`, `filesystem.remove`
             * - `dialog.showAlert`, `dialog.openFile`, `dialog.saveFile`
             * - `clipboard.readText`, `clipboard.writeText`
             * - `process.execute`
             * - `shell.openURL`, `shell.openPath`
             *
             * @param {string} method - The plugin method name (e.g., `"filesystem.readFile"`).
             * @param {Object} [params] - Optional JSON-serialisable parameters to pass to the method.
             * @param {Object} [options] - Optional call-level settings.
             * @param {number} [options.timeout] - Per-call timeout in milliseconds. Overrides the default timeout for this call only.
             * @returns {Promise<any>} Resolves with the parsed response payload from the plugin,
             *   or rejects with an Error if the plugin returns an error or the request times out.
             * @throws {Error} If the request times out (default 30 000 ms) or the native bridge
             *   is unavailable.
             *
             * @example
             * // Read a file
             * const result = await loom.invoke("filesystem.readFile", { path: "/tmp/file.txt" });
             * console.log(result.content); // base64-encoded content
             *
             * @example
             * // Show an alert dialog
             * const { response } = await loom.invoke("dialog.showAlert", {
             *     title: "Confirm",
             *     message: "Are you sure?",
             *     style: "warning"
             * });
             *
             * @example
             * // Copy text to clipboard
             * await loom.invoke("clipboard.writeText", { text: "Hello" });
             */
            invoke(method, params, options) {
                return new Promise((resolve, reject) => {
                    const id = `msg_${++internal.nextId}`;
                    const timeout = (options && typeof options.timeout === 'number' && options.timeout > 0)
                        ? options.timeout
                        : internal._defaultTimeout;
                    const timeoutId = setTimeout(() => {
                        if (internal.pending.has(id)) {
                            internal.pending.delete(id);
                            const error = new Error(`Request timed out after ${timeout}ms: ${method}`);
                            error.code = 'TIMEOUT';
                            error.method = method;
                            reject(error);
                        }
                    }, timeout);
                    internal.pending.set(id, { resolve, reject, timeoutId });
                    const payload = params
                        ? JSON.stringify(params)
                        : null;
                    try {
                        window.webkit.messageHandlers.loom.postMessage(
                            JSON.stringify({
                                id,
                                method: `plugin.${method}`,
                                payload,
                                kind: 'request'
                            })
                        );
                    } catch (e) {
                        clearTimeout(timeoutId);
                        internal.pending.delete(id);
                        reject(e);
                    }
                });
            },

            /**
             * Subscribes to an event emitted by the native side.
             *
             * Multiple listeners can be registered for the same event. Each listener
             * receives the parsed payload object when the event fires.
             *
             * @param {string} event - The event name to listen for.
             * @param {function(any): void} callback - Called with the event data each
             *   time the event is dispatched.
             * @returns {function(): void} An unsubscribe function. Call it to remove
             *   this specific listener.
             *
             * @example
             * const unsubscribe = loom.on("myPlugin.statusChanged", (data) => {
             *     console.log("Status:", data.status);
             * });
             *
             * // Later, stop listening:
             * unsubscribe();
             */
            on(event, callback) {
                if (!internal.listeners.has(event)) {
                    internal.listeners.set(event, new Set());
                }
                internal.listeners.get(event).add(callback);
                return () => {
                    const set = internal.listeners.get(event);
                    if (set) {
                        set.delete(callback);
                    }
                };
            },

            /**
             * Subscribes to an event for a single firing only. The listener is
             * automatically removed after it is called once.
             *
             * @param {string} event - The event name to listen for.
             * @param {function(any): void} callback - Called with the event data once.
             * @returns {function(): void} An unsubscribe function. Call it to cancel
             *   the one-shot listener before it fires.
             *
             * @example
             * loom.once("myPlugin.ready", (data) => {
             *     console.log("Plugin is ready:", data);
             * });
             */
            once(event, callback) {
                const unsubscribe = this.on(event, (data) => {
                    unsubscribe();
                    callback(data);
                });
                return unsubscribe;
            },

            /**
             * Sends a fire-and-forget event to the native side.
             *
             * Unlike `invoke()`, this method does not wait for a response.
             * The native side can listen for these events using `Bridge.onEvent(name:handler:)`.
             *
             * @param {string} event - The event name (e.g., `"myPlugin.userAction"`).
             * @param {Object} [data] - Optional JSON-serialisable payload to send with the event.
             *
             * @example
             * // Fire a simple event
             * loom.emit("ui.buttonClicked");
             *
             * @example
             * // Fire an event with data
             * loom.emit("editor.contentChanged", { length: 42 });
             */
            emit(event, data) {
                const payload = data
                    ? JSON.stringify(data)
                    : null;
                try {
                    window.webkit.messageHandlers.loom.postMessage(
                        JSON.stringify({
                            id: `emit_${++internal.nextId}`,
                            method: event,
                            payload,
                            kind: 'webEvent'
                        })
                    );
                } catch (e) {
                    console.error('[loom] emit error:', e);
                }
            },

            /**
             * Sets the default timeout for all future `invoke()` calls.
             *
             * Any call to `invoke()` that does not receive a response within this
             * duration will be automatically rejected with a timeout error.
             * The initial default is 30 000 ms (30 seconds).
             *
             * @param {number} ms - Timeout in milliseconds. Must be a positive number.
             *
             * @example
             * // Increase timeout to 60 seconds
             * loom.setDefaultTimeout(60000);
             */
            setDefaultTimeout(ms) {
                if (typeof ms !== 'number' || ms <= 0) {
                    console.warn('[loom] setDefaultTimeout: invalid value ignored, must be a positive number');
                    return;
                }
                internal._defaultTimeout = ms;
            },

            /**
             * Window management helpers.
             *
             * Provides drag-region support so that web content rendered inside a
             * `titlebarStyle == .hidden` window can act as a draggable title bar.
             *
             * @namespace loom.window
             */
            window: {
                /**
                 * Registers an array of drag regions. Each region uses CSS-like
                 * positioning relative to the viewport edges.
                 *
                 * @param {Array<{top?: number, left?: number, right?: number, bottom?: number, width?: number, height?: number}>} regions
                 *
                 * @example
                 * loom.window.setDragRegions([
                 *     { top: 0, left: 0, right: 0, height: 38 },
                 * ]);
                 */
                setDragRegions(regions) {
                    if (!Array.isArray(regions)) {
                        console.warn('[loom] setDragRegions: expected an array');
                        return;
                    }
                    internal.dragRegions = regions;
                },

                /**
                 * Removes all drag regions, effectively disabling window dragging
                 * from the web layer.
                 */
                clearDragRegions() {
                    internal.dragRegions = [];
                }
            }
        },
        writable: false,
        configurable: false
    });

    // Clean up pending Promises when the page is being unloaded
    if (typeof window.addEventListener === 'function') {
        window.addEventListener('beforeunload', () => {
            for (const [id, p] of internal.pending) {
                if (p.timeoutId) clearTimeout(p.timeoutId);
                p.reject(new Error('Page is being unloaded'));
            }
            internal.pending.clear();
        });
    }

    // SDK initialization complete
    _readyResolve();
})();
