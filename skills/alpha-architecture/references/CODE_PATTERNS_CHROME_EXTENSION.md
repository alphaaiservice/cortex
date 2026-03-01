# Alpha AI — Code Patterns Reference (Chrome Extension / MV3)

> This file contains Chrome Extension-specific patterns using Manifest V3, TypeScript, React, Vite.
> For other platforms, see: [Python/FastAPI](CODE_PATTERNS_PYTHON.md) · [NestJS](CODE_PATTERNS_NESTJS.md) · [Spring Boot](CODE_PATTERNS_SPRINGBOOT.md)
>
> For frontend patterns (Next.js): [CORE](CODE_PATTERNS_FRONTEND_CORE.md) · [PAGES](CODE_PATTERNS_FRONTEND_PAGES.md) · [UX](CODE_PATTERNS_FRONTEND_UX.md)

This file is loaded on-demand when writing Chrome Extension code.

**Stack:** Manifest V3 | TypeScript 5.5+ strict | React 19 | Vite 6 | Tailwind CSS | Zustand 5 | shadcn/ui | Lucide Icons

---

## 1. Extension Architecture (MV3)

```
# ┌─────────────────────────────────────────────────────────────────┐
# │  Chrome Extension Architecture — Manifest V3                    │
# │                                                                 │
# │  ┌──────────────┐     messages     ┌──────────────────┐        │
# │  │  Side Panel   │ ◄─────────────► │ Service Worker    │        │
# │  │  (React UI)   │                 │ (Background)      │        │
# │  │  sidepanel.html│                 │ background.ts     │        │
# │  └──────────────┘                 └────────┬─────────┘        │
# │                                             │                   │
# │  ┌──────────────┐     messages     ┌───────▼──────────┐        │
# │  │  Options Page │ ◄─────────────► │ Content Scripts   │        │
# │  │  (React UI)   │                 │ (DOM access)      │        │
# │  │  options.html  │                 │ content.ts        │        │
# │  └──────────────┘                 └──────────────────┘        │
# │                                                                 │
# │  RULES:                                                         │
# │  ✅ Service worker = orchestrator (NO DOM access)              │
# │  ✅ Content scripts = DOM interaction (isolated world)         │
# │  ✅ Side panel / popup = React UI (NO direct DOM access)       │
# │  ✅ Message passing = ONLY way to communicate between contexts │
# │  ❌ NEVER access DOM from service worker                       │
# │  ❌ NEVER call chrome.tabs/chrome.storage from content scripts │
# │     without going through background first                     │
# │  ❌ NEVER use Manifest V2 patterns (persistent background)    │
# └─────────────────────────────────────────────────────────────────┘
```

### Extension Directory Structure

```
extension/
├── public/
│   ├── icons/
│   │   ├── icon16.png
│   │   ├── icon32.png
│   │   ├── icon48.png
│   │   └── icon128.png
│   └── _locales/              # i18n strings
│       └── en/
│           └── messages.json
│
├── src/
│   ├── background/            # Service worker context
│   │   ├── index.ts           # Entry: chrome.runtime listeners, initialization
│   │   ├── message-router.ts  # Central message hub — routes all messages
│   │   ├── tab-manager.ts     # Tab tracking, content script injection
│   │   ├── api-key-manager.ts # Secure API key storage
│   │   ├── ai-providers/      # AI provider abstraction
│   │   │   ├── base-provider.ts
│   │   │   ├── claude-provider.ts
│   │   │   ├── openai-provider.ts
│   │   │   ├── gemini-provider.ts
│   │   │   ├── provider-factory.ts
│   │   │   ├── prompt-builder.ts
│   │   │   ├── response-parser.ts
│   │   │   └── streaming-handler.ts
│   │   ├── workflow/          # Workflow engine
│   │   │   ├── workflow-engine.ts
│   │   │   ├── workflow-recorder.ts
│   │   │   ├── workflow-player.ts
│   │   │   └── workflow-storage.ts
│   │   └── scheduler/         # chrome.alarms scheduling
│   │       └── task-scheduler.ts
│   │
│   ├── content/               # Content script context (injected into pages)
│   │   ├── index.ts           # Entry: message listener, initialization
│   │   ├── action-executor/   # DOM action execution
│   │   │   ├── action-dispatcher.ts
│   │   │   ├── click-action.ts
│   │   │   ├── type-action.ts
│   │   │   ├── scroll-action.ts
│   │   │   ├── select-action.ts
│   │   │   ├── keyboard-action.ts
│   │   │   ├── wait-action.ts
│   │   │   ├── hover-action.ts
│   │   │   └── navigate-action.ts
│   │   ├── dom-inspector/     # Page analysis
│   │   │   ├── interactive-finder.ts
│   │   │   ├── form-detector.ts
│   │   │   ├── table-extractor.ts
│   │   │   └── accessibility-reader.ts
│   │   ├── element-selector/  # Visual element picker
│   │   │   ├── picker-overlay.ts
│   │   │   ├── highlight-renderer.ts
│   │   │   └── selector-generator.ts
│   │   ├── page-context/      # Page data extraction
│   │   │   ├── context-extractor.ts
│   │   │   ├── metadata-reader.ts
│   │   │   └── text-summarizer.ts
│   │   └── observers/         # DOM/navigation watchers
│   │       ├── mutation-observer.ts
│   │       ├── navigation-observer.ts
│   │       └── recording-observer.ts
│   │
│   ├── sidepanel/             # Side panel React app
│   │   ├── main.tsx           # React root mount
│   │   ├── App.tsx            # Root component + tab routing
│   │   ├── components/
│   │   │   ├── ui/            # shadcn/ui primitives
│   │   │   ├── layout/        # Header, Sidebar, StatusBar, TabBar
│   │   │   ├── chat/          # Chat UI components
│   │   │   ├── automation/    # Automation controls
│   │   │   ├── workflow/      # Workflow management
│   │   │   ├── settings/      # Settings panels
│   │   │   └── data-viewer/   # Data display components
│   │   ├── stores/            # Zustand stores
│   │   │   ├── chatStore.ts
│   │   │   ├── automationStore.ts
│   │   │   ├── workflowStore.ts
│   │   │   ├── settingsStore.ts
│   │   │   └── uiStore.ts
│   │   ├── hooks/             # React hooks
│   │   │   ├── useChat.ts
│   │   │   ├── useAutomation.ts
│   │   │   ├── useChromeMessage.ts
│   │   │   ├── useStorage.ts
│   │   │   └── useStreamingResponse.ts
│   │   └── styles/
│   │       ├── index.css      # Tailwind base + CSS variables
│   │       └── animations.css # Keyframe animations
│   │
│   ├── options/               # Options page React app
│   │   ├── main.tsx
│   │   └── Options.tsx
│   │
│   └── shared/                # Shared across all contexts
│       ├── types/             # TypeScript interfaces
│       │   ├── messages.ts    # MessageType enum + payload types
│       │   ├── actions.ts     # BrowserAction, ActionResult
│       │   ├── dom.ts         # PageContext, InteractiveElement
│       │   ├── workflows.ts   # Workflow, WorkflowStep
│       │   └── settings.ts    # UserSettings
│       ├── constants/
│       │   ├── action-types.ts
│       │   ├── model-configs.ts
│       │   └── default-settings.ts
│       └── utils/
│           ├── cn.ts          # Tailwind class merger
│           ├── formatters.ts  # ID gen, date format
│           ├── validators.ts  # Input validation
│           └── dom-serializer.ts # DOM → text for AI
│
├── dist/                      # Build output (git-ignored)
│   ├── manifest.json
│   ├── background.js          # IIFE bundle
│   ├── content.js             # IIFE bundle
│   ├── content.css
│   ├── sidepanel.html
│   ├── options.html
│   ├── assets/                # Hashed React bundles
│   └── icons/
│
├── manifest.json              # Source manifest (or generated)
├── package.json
├── tsconfig.json
├── vite.config.ts             # Sidepanel + options build
├── vite.background.config.ts  # Service worker build (IIFE)
├── vite.content.config.ts     # Content script build (IIFE)
├── tailwind.config.ts
└── postcss.config.js
```

---

## 2. Manifest V3 Configuration

```json
// manifest.json — CORRECT ✅
{
  "manifest_version": 3,
  "name": "__MSG_extensionName__",
  "description": "__MSG_extensionDescription__",
  "version": "1.0.0",

  "permissions": [
    "activeTab",
    "sidePanel",
    "storage",
    "tabs",
    "scripting",
    "alarms",
    "notifications",
    "unlimitedStorage"
  ],

  "host_permissions": [
    "<all_urls>"
  ],

  "background": {
    "service_worker": "background.js",
    "type": "module"
  },

  "content_scripts": [
    {
      "matches": ["<all_urls>"],
      "js": ["content.js"],
      "css": ["content.css"],
      "run_at": "document_idle"
    }
  ],

  "side_panel": {
    "default_path": "sidepanel.html"
  },

  "options_page": "options.html",

  "action": {
    "default_icon": {
      "16": "icons/icon16.png",
      "32": "icons/icon32.png",
      "48": "icons/icon48.png",
      "128": "icons/icon128.png"
    },
    "default_title": "__MSG_extensionName__"
  },

  "commands": {
    "_execute_action": {
      "suggested_key": { "default": "Alt+A" },
      "description": "Open side panel"
    },
    "toggle-element-picker": {
      "suggested_key": { "default": "Ctrl+Shift+E" },
      "description": "Toggle element picker"
    }
  },

  "icons": {
    "16": "icons/icon16.png",
    "48": "icons/icon48.png",
    "128": "icons/icon128.png"
  },

  "default_locale": "en",

  "content_security_policy": {
    "extension_pages": "script-src 'self'; object-src 'self'; style-src 'self' 'unsafe-inline'"
  }
}
```

```
# MANIFEST RULES:
# ✅ ALWAYS use manifest_version: 3 (V2 is deprecated)
# ✅ ALWAYS request minimum permissions needed
# ✅ ALWAYS add "unlimitedStorage" if storing screenshots/large data
# ✅ ALWAYS add content_security_policy for extension pages
# ✅ ALWAYS use __MSG_key__ for i18n-ready strings
# ✅ ALWAYS set "type": "module" for service worker if using ES imports
# ❌ NEVER request "webRequest" unless absolutely needed (triggers extra review)
# ❌ NEVER use "persistent": true (MV2 pattern)
# ❌ NEVER use remotely hosted code (MV3 prohibits it)
# ❌ NEVER use eval() or new Function() (CSP violation)
```

---

## 3. Build System (Vite Multi-Config)

```typescript
// vite.config.ts — Sidepanel + Options page build
// CORRECT ✅ — Multi-entry React build with proper asset handling
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'path';

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@shared': path.resolve(__dirname, 'src/shared'),
      '@background': path.resolve(__dirname, 'src/background'),
      '@content': path.resolve(__dirname, 'src/content'),
      '@sidepanel': path.resolve(__dirname, 'src/sidepanel'),
    },
  },
  build: {
    outDir: 'dist',
    emptyOutDir: true,  // Only true for FIRST build in sequence
    rollupOptions: {
      input: {
        sidepanel: path.resolve(__dirname, 'sidepanel.html'),
        options: path.resolve(__dirname, 'options.html'),
      },
      output: {
        // Stable chunk names for CSP compatibility
        chunkFileNames: 'assets/[name]-[hash].js',
        entryFileNames: 'assets/[name]-[hash].js',
        assetFileNames: 'assets/[name]-[hash].[ext]',
      },
    },
    sourcemap: process.env.NODE_ENV === 'development' ? 'inline' : false,
  },
});
```

```typescript
// vite.background.config.ts — Service worker build
// CORRECT ✅ — IIFE format (service workers can't use ES module imports in MV3)
import { defineConfig } from 'vite';
import path from 'path';

export default defineConfig({
  resolve: {
    alias: {
      '@shared': path.resolve(__dirname, 'src/shared'),
      '@background': path.resolve(__dirname, 'src/background'),
    },
  },
  build: {
    outDir: 'dist',
    emptyOutDir: false,  // MUST be false — don't clobber sidepanel build output
    lib: {
      entry: path.resolve(__dirname, 'src/background/index.ts'),
      name: 'background',
      formats: ['iife'],
      fileName: () => 'background.js',
    },
    rollupOptions: {
      output: { inlineDynamicImports: true },
    },
    sourcemap: process.env.NODE_ENV === 'development' ? 'inline' : false,
  },
});
```

```typescript
// vite.content.config.ts — Content script build
// CORRECT ✅ — IIFE format (content scripts run in isolated world, no module support)
import { defineConfig } from 'vite';
import path from 'path';

export default defineConfig({
  resolve: {
    alias: {
      '@shared': path.resolve(__dirname, 'src/shared'),
      '@content': path.resolve(__dirname, 'src/content'),
    },
  },
  build: {
    outDir: 'dist',
    emptyOutDir: false,  // MUST be false — don't clobber previous builds
    lib: {
      entry: path.resolve(__dirname, 'src/content/index.ts'),
      name: 'content',
      formats: ['iife'],
      fileName: () => 'content.js',
    },
    rollupOptions: {
      output: { inlineDynamicImports: true },
    },
    sourcemap: false,  // Content scripts: no sourcemaps in production
  },
});
```

```json
// package.json scripts — CORRECT ✅
{
  "scripts": {
    "dev": "concurrently \"vite build --watch\" \"vite build --watch --config vite.content.config.ts\" \"vite build --watch --config vite.background.config.ts\"",
    "build": "tsc --noEmit && vite build && vite build --config vite.content.config.ts && vite build --config vite.background.config.ts",
    "lint": "eslint src/ --ext .ts,.tsx --max-warnings 0",
    "format": "prettier --write 'src/**/*.{ts,tsx,css}'",
    "test": "vitest run",
    "test:watch": "vitest",
    "type-check": "tsc --noEmit",
    "zip": "cd dist && zip -r ../extension.zip . -x '*.map'"
  }
}
```

```
# BUILD RULES:
# ✅ ALWAYS build in sequence: sidepanel → content → background
# ✅ ALWAYS use IIFE format for background + content (no ES module support)
# ✅ ALWAYS set emptyOutDir:false for 2nd and 3rd builds
# ✅ ALWAYS run tsc --noEmit before build (type-check first)
# ✅ ALWAYS use --watch mode for development (3 concurrent watchers)
# ❌ NEVER use ES module format for service worker or content script
# ❌ NEVER set emptyOutDir:true on background/content builds (clobbers output)
# ❌ NEVER ship sourcemaps in production builds
```

---

## 4. Service Worker Lifecycle (CRITICAL for MV3)

```typescript
// CORRECT ✅ — Service worker entry point with lifecycle handling
// src/background/index.ts
import { initMessageRouter } from './message-router';
import { initTabTracking } from './tab-manager';
import { initScheduler } from './scheduler/task-scheduler';

// ┌─────────────────────────────────────────────────────────────────┐
// │  CRITICAL: Service workers are EPHEMERAL in MV3.               │
// │  They sleep after ~30s of inactivity and are KILLED after 5min.│
// │  ALL in-memory state is LOST on kill.                          │
// │                                                                 │
// │  RULES:                                                         │
// │  ✅ ALWAYS persist important state to chrome.storage            │
// │  ✅ ALWAYS re-initialize on every wake (top-level code runs)   │
// │  ✅ ALWAYS use chrome.storage.session for ephemeral state      │
// │  ✅ ALWAYS keep service worker alive during long operations    │
// │     with chrome.runtime.getContexts() or keepalive ports       │
// │  ❌ NEVER store critical state in module-level variables only  │
// │  ❌ NEVER assume service worker has been running continuously  │
// │  ❌ NEVER use setInterval for periodic tasks (use chrome.alarms)│
// │  ❌ NEVER rely on global state across wake cycles              │
// └─────────────────────────────────────────────────────────────────┘

// Initialize on every wake — this runs each time the service worker starts
async function initialize() {
  console.log('[Background] Service worker initializing...');

  // Restore state from storage
  await restoreState();

  // Set up message routing
  initMessageRouter();

  // Track tabs
  initTabTracking();

  // Restore scheduled tasks
  await initScheduler();

  // Configure side panel
  chrome.sidePanel.setPanelBehavior({ openPanelOnActionClick: true });

  console.log('[Background] Service worker ready');
}

// State persistence — survives service worker kills
async function restoreState() {
  const { sessionState } = await chrome.storage.session.get('sessionState');
  if (sessionState) {
    // Rehydrate in-memory caches from session storage
    Object.assign(stateCache, sessionState);
  }
}

async function persistState() {
  await chrome.storage.session.set({
    sessionState: {
      activeTabId: stateCache.activeTabId,
      pendingActions: Array.from(stateCache.pendingActions.entries()),
      lastActiveTime: Date.now(),
    },
  });
}

// Keep-alive for long-running operations (prevents 30s idle kill)
function keepAlive(): () => void {
  const keepAliveInterval = setInterval(() => {
    chrome.runtime.getPlatformInfo(() => {
      // This ping keeps the service worker alive
    });
  }, 25_000); // Every 25 seconds (before 30s idle timeout)

  return () => clearInterval(keepAliveInterval);
}

// Lifecycle listeners
chrome.runtime.onInstalled.addListener(async (details) => {
  if (details.reason === 'install') {
    // First install — set defaults, open onboarding
    await chrome.storage.local.set({ isFirstInstall: true });
    chrome.tabs.create({ url: chrome.runtime.getURL('options.html?onboarding=true') });
  } else if (details.reason === 'update') {
    // Extension updated — run migrations
    await runMigrations(details.previousVersion);
  }
});

chrome.runtime.onStartup.addListener(() => {
  // Browser started — re-initialize
  initialize();
});

// Service worker becomes active
initialize();
```

```typescript
// CORRECT ✅ — Keep-alive port pattern for long operations
// Use when executing multi-step automation that takes > 30 seconds

class KeepAliveManager {
  private port: chrome.runtime.Port | null = null;
  private intervalId: ReturnType<typeof setInterval> | null = null;

  start(reason: string) {
    // Create a port that keeps the service worker alive
    this.port = chrome.runtime.connect({ name: `keepalive-${reason}` });
    this.port.onDisconnect.addListener(() => {
      this.port = null;
    });

    // Also use periodic ping as backup
    this.intervalId = setInterval(() => {
      chrome.runtime.getPlatformInfo(() => {});
    }, 25_000);

    console.log(`[KeepAlive] Started: ${reason}`);
  }

  stop() {
    if (this.port) {
      this.port.disconnect();
      this.port = null;
    }
    if (this.intervalId) {
      clearInterval(this.intervalId);
      this.intervalId = null;
    }
    console.log('[KeepAlive] Stopped');
  }
}

export const keepAliveManager = new KeepAliveManager();

// Usage in automation:
async function executeMultiStepAutomation(steps: ActionStep[]) {
  keepAliveManager.start('automation');
  try {
    for (const step of steps) {
      await executeStep(step);
      // Persist progress after each step
      await chrome.storage.session.set({ automationProgress: step.index });
    }
  } finally {
    keepAliveManager.stop();
  }
}
```

```typescript
// WRONG ❌ — Module-level state without persistence (lost on service worker kill)
let activeConversations = new Map<string, Conversation>(); // LOST on kill!
let pendingActions: Action[] = [];  // LOST on kill!
let userSettings: Settings | null = null; // LOST on kill!

// WRONG ❌ — Using setInterval for periodic tasks
setInterval(async () => {
  await checkScheduledTasks(); // KILLED when service worker sleeps
}, 60_000);

// CORRECT ✅ — Use chrome.alarms for periodic tasks
chrome.alarms.create('check-scheduled-tasks', { periodInMinutes: 1 });
chrome.alarms.onAlarm.addListener(async (alarm) => {
  if (alarm.name === 'check-scheduled-tasks') {
    await checkScheduledTasks();
  }
});
```

---

## 5. Message Passing Architecture

```typescript
// CORRECT ✅ — Type-safe message system
// src/shared/types/messages.ts

export enum MessageType {
  // Chat
  CHAT_SEND = 'CHAT_SEND',
  CHAT_RESPONSE = 'CHAT_RESPONSE',
  CHAT_STREAM_CHUNK = 'CHAT_STREAM_CHUNK',
  CHAT_STREAM_DONE = 'CHAT_STREAM_DONE',
  CHAT_STREAM_ERROR = 'CHAT_STREAM_ERROR',

  // Actions
  EXECUTE_ACTION = 'EXECUTE_ACTION',
  ACTION_RESULT = 'ACTION_RESULT',

  // Page Context
  GET_PAGE_CONTEXT = 'GET_PAGE_CONTEXT',
  PAGE_CONTEXT_RESULT = 'PAGE_CONTEXT_RESULT',

  // Element Picker
  START_ELEMENT_PICKER = 'START_ELEMENT_PICKER',
  ELEMENT_SELECTED = 'ELEMENT_SELECTED',
  STOP_ELEMENT_PICKER = 'STOP_ELEMENT_PICKER',

  // Workflow
  START_RECORDING = 'START_RECORDING',
  STOP_RECORDING = 'STOP_RECORDING',
  PLAY_WORKFLOW = 'PLAY_WORKFLOW',
  WORKFLOW_STEP_RESULT = 'WORKFLOW_STEP_RESULT',
  WORKFLOW_COMPLETE = 'WORKFLOW_COMPLETE',

  // Settings
  SETTINGS_UPDATED = 'SETTINGS_UPDATED',
  API_KEY_SET = 'API_KEY_SET',

  // Status
  PING = 'PING',
  PONG = 'PONG',
}

// Type-safe payload mapping
export interface MessagePayloadMap {
  [MessageType.CHAT_SEND]: { message: string; conversationId: string };
  [MessageType.CHAT_RESPONSE]: { text: string; conversationId: string };
  [MessageType.CHAT_STREAM_CHUNK]: { chunk: string; conversationId: string };
  [MessageType.CHAT_STREAM_DONE]: { conversationId: string };
  [MessageType.CHAT_STREAM_ERROR]: { error: string; conversationId: string };
  [MessageType.EXECUTE_ACTION]: { action: BrowserAction };
  [MessageType.ACTION_RESULT]: { result: ActionResult };
  [MessageType.GET_PAGE_CONTEXT]: { includeInteractive?: boolean };
  [MessageType.PAGE_CONTEXT_RESULT]: { context: PageContext };
  [MessageType.ELEMENT_SELECTED]: { selector: string; tagName: string; text: string };
  [MessageType.PING]: undefined;
  [MessageType.PONG]: { timestamp: number };
}

export interface ExtensionMessage<T extends MessageType = MessageType> {
  type: T;
  payload: T extends keyof MessagePayloadMap ? MessagePayloadMap[T] : unknown;
  tabId?: number;
  timestamp: number;
}

// Type-safe message sender
export function createMessage<T extends MessageType>(
  type: T,
  payload: T extends keyof MessagePayloadMap ? MessagePayloadMap[T] : unknown,
): ExtensionMessage<T> {
  return { type, payload, timestamp: Date.now() };
}
```

```typescript
// CORRECT ✅ — Central message router (background)
// src/background/message-router.ts

type MessageHandler<T extends MessageType> = (
  payload: MessagePayloadMap[T],
  sender: chrome.runtime.MessageSender,
) => Promise<unknown>;

const handlers = new Map<MessageType, MessageHandler<any>>();

// Register handler
function on<T extends MessageType>(type: T, handler: MessageHandler<T>) {
  handlers.set(type, handler);
}

export function initMessageRouter() {
  chrome.runtime.onMessage.addListener(
    (message: ExtensionMessage, sender, sendResponse) => {
      const handler = handlers.get(message.type);
      if (!handler) {
        console.warn(`[Router] No handler for message type: ${message.type}`);
        sendResponse({ error: `Unknown message type: ${message.type}` });
        return false;
      }

      // Handle async responses properly
      handler(message.payload, sender)
        .then((result) => sendResponse({ success: true, data: result }))
        .catch((error) => {
          console.error(`[Router] Error handling ${message.type}:`, error);
          sendResponse({ success: false, error: error.message });
        });

      return true; // CRITICAL: return true for async sendResponse
    },
  );

  // Register all handlers
  on(MessageType.CHAT_SEND, handleChatSend);
  on(MessageType.EXECUTE_ACTION, handleExecuteAction);
  on(MessageType.GET_PAGE_CONTEXT, handleGetPageContext);
  on(MessageType.API_KEY_SET, handleApiKeySet);
  on(MessageType.PLAY_WORKFLOW, handlePlayWorkflow);
  // ... register all handlers
}
```

```typescript
// CORRECT ✅ — Send message to content script (from background)
// src/background/tab-manager.ts

export async function sendToContentScript<T extends MessageType>(
  tabId: number,
  type: T,
  payload: MessagePayloadMap[T],
): Promise<unknown> {
  try {
    // Ensure content script is injected first
    await ensureContentScript(tabId);

    const response = await chrome.tabs.sendMessage(tabId, createMessage(type, payload));
    if (!response?.success) {
      throw new Error(response?.error || 'Content script returned error');
    }
    return response.data;
  } catch (error) {
    // Content script may not be ready — retry once after injection
    if ((error as Error).message.includes('Receiving end does not exist')) {
      await injectContentScript(tabId);
      await new Promise((resolve) => setTimeout(resolve, 500));
      return chrome.tabs.sendMessage(tabId, createMessage(type, payload));
    }
    throw error;
  }
}

// CORRECT ✅ — Programmatic content script injection
async function ensureContentScript(tabId: number) {
  try {
    // Ping the content script to check if it's alive
    await chrome.tabs.sendMessage(tabId, createMessage(MessageType.PING, undefined));
  } catch {
    // Content script not present — inject it
    await injectContentScript(tabId);
  }
}

async function injectContentScript(tabId: number) {
  const tab = await chrome.tabs.get(tabId);

  // Check if URL is scriptable (not chrome://, edge://, etc.)
  if (!tab.url || !isScriptableUrl(tab.url)) {
    throw new Error(`Cannot inject content script into ${tab.url}`);
  }

  await chrome.scripting.executeScript({
    target: { tabId },
    files: ['content.js'],  // MUST reference BUILT file, not source
  });

  // Also inject CSS if needed
  await chrome.scripting.insertCSS({
    target: { tabId },
    files: ['content.css'],
  });
}

function isScriptableUrl(url: string): boolean {
  const unscriptable = [
    'chrome://', 'chrome-extension://', 'edge://',
    'about:', 'data:', 'javascript:', 'file://',
    'https://chrome.google.com/webstore',
    'https://chromewebstore.google.com',
  ];
  return !unscriptable.some((prefix) => url.startsWith(prefix));
}
```

```typescript
// CORRECT ✅ — Streaming messages via ports (for AI chat streaming)
// Background side:
function streamToSidePanel(conversationId: string, stream: ReadableStream) {
  const reader = stream.getReader();
  const decoder = new TextDecoder();

  async function pump() {
    while (true) {
      const { done, value } = await reader.read();
      if (done) {
        chrome.runtime.sendMessage(
          createMessage(MessageType.CHAT_STREAM_DONE, { conversationId }),
        );
        break;
      }
      const chunk = decoder.decode(value, { stream: true });
      chrome.runtime.sendMessage(
        createMessage(MessageType.CHAT_STREAM_CHUNK, { chunk, conversationId }),
      );
    }
  }

  pump().catch((error) => {
    chrome.runtime.sendMessage(
      createMessage(MessageType.CHAT_STREAM_ERROR, {
        error: error.message,
        conversationId,
      }),
    );
  });
}
```

```
# MESSAGE PASSING RULES:
# ✅ ALWAYS return true from onMessage listener for async responses
# ✅ ALWAYS type-check message payloads (use MessagePayloadMap)
# ✅ ALWAYS handle "Receiving end does not exist" errors gracefully
# ✅ ALWAYS use sendResponse (not return) for message responses
# ✅ ALWAYS use ports for long-lived connections (streaming, keep-alive)
# ❌ NEVER send messages without error handling (tab may be closed)
# ❌ NEVER assume content script is present (check + inject first)
# ❌ NEVER send large data (>64KB) via runtime.sendMessage (use storage)
# ❌ NEVER use postMessage for extension-internal communication
```

## 6. Content Script Patterns

```typescript
// CORRECT ✅ — Content script entry point with message listener
// src/content/index.ts

import { actionDispatcher } from './action-executor/action-dispatcher';
import { contextExtractor } from './page-context/context-extractor';
import { elementPicker } from './element-selector/picker-overlay';
import { MessageType, type ExtensionMessage } from '@shared/types/messages';

// ┌─────────────────────────────────────────────────────────────────┐
// │  Content scripts run in an ISOLATED WORLD — they share the     │
// │  page's DOM but have a separate JavaScript execution context.  │
// │                                                                 │
// │  RULES:                                                         │
// │  ✅ Content scripts CAN: read/modify DOM, listen for DOM events│
// │  ✅ Content scripts CAN: send messages to background           │
// │  ✅ Content scripts CAN: use chrome.runtime.sendMessage        │
// │  ❌ Content scripts CANNOT: access chrome.tabs, chrome.storage │
// │     (must request via message to background)                   │
// │  ❌ Content scripts CANNOT: access page's JS variables/objects │
// │  ❌ Content scripts CANNOT: use ES module imports at runtime   │
// │  ❌ Content scripts CANNOT: make cross-origin requests         │
// └─────────────────────────────────────────────────────────────────┘

let isInitialized = false;

function initialize() {
  if (isInitialized) return;
  isInitialized = true;

  // Listen for messages from background
  chrome.runtime.onMessage.addListener(
    (message: ExtensionMessage, sender, sendResponse) => {
      handleMessage(message)
        .then((result) => sendResponse({ success: true, data: result }))
        .catch((error) =>
          sendResponse({ success: false, error: error.message }),
        );
      return true; // Async response
    },
  );

  console.log('[Content] Initialized on', window.location.href);
}

async function handleMessage(message: ExtensionMessage): Promise<unknown> {
  switch (message.type) {
    case MessageType.EXECUTE_ACTION:
      return actionDispatcher.execute(message.payload.action);

    case MessageType.GET_PAGE_CONTEXT:
      return contextExtractor.extract(message.payload);

    case MessageType.START_ELEMENT_PICKER:
      return elementPicker.start();

    case MessageType.STOP_ELEMENT_PICKER:
      return elementPicker.stop();

    case MessageType.PING:
      return { pong: true, timestamp: Date.now(), url: window.location.href };

    default:
      console.warn(`[Content] Unknown message type: ${message.type}`);
      return null;
  }
}

// Initialize immediately
initialize();
```

```typescript
// CORRECT ✅ — Action dispatcher with multi-strategy element finding
// src/content/action-executor/action-dispatcher.ts

import type { BrowserAction, ActionResult } from '@shared/types/actions';

export class ActionDispatcher {
  async execute(action: BrowserAction): Promise<ActionResult> {
    const startTime = Date.now();

    try {
      // Find target element with multi-strategy fallback
      const element = await this.findElement(action.selector, action.description);
      if (!element) {
        return {
          success: false,
          error: `Element not found: ${action.selector}`,
          selector: action.selector,
          duration: Date.now() - startTime,
        };
      }

      // Wait for DOM stability before acting
      await this.waitForStability();

      // Scroll element into view
      element.scrollIntoView({ behavior: 'smooth', block: 'center' });
      await this.delay(300);

      // Execute the action
      switch (action.type) {
        case 'click':
          return this.executeClick(element, action);
        case 'type':
          return this.executeType(element, action);
        case 'select':
          return this.executeSelect(element, action);
        case 'scroll':
          return this.executeScroll(action);
        case 'wait':
          return this.executeWait(action);
        case 'hover':
          return this.executeHover(element);
        case 'keyboard':
          return this.executeKeyboard(action);
        default:
          return { success: false, error: `Unknown action: ${action.type}`, duration: Date.now() - startTime };
      }
    } catch (error) {
      return {
        success: false,
        error: (error as Error).message,
        duration: Date.now() - startTime,
      };
    }
  }

  // Multi-strategy element finding with fallback chain
  private async findElement(
    selector: string,
    description?: string,
  ): Promise<Element | null> {
    // Strategy 1: Direct CSS selector
    let element = document.querySelector(selector);
    if (element && this.isVisible(element)) return element;

    // Strategy 2: Text content match (from AI description)
    if (description) {
      element = this.findByTextContent(description);
      if (element) return element;
    }

    // Strategy 3: ARIA label match
    if (description) {
      element = this.findByAriaLabel(description);
      if (element) return element;
    }

    // Strategy 4: Wait for element (may be loading)
    element = await this.waitForElement(selector, 5000);
    if (element) return element;

    return null;
  }

  private isVisible(element: Element): boolean {
    const rect = element.getBoundingClientRect();
    const style = window.getComputedStyle(element);
    return (
      rect.width > 0 &&
      rect.height > 0 &&
      style.display !== 'none' &&
      style.visibility !== 'hidden' &&
      style.opacity !== '0'
    );
  }

  private findByTextContent(text: string): Element | null {
    const normalizedText = text.toLowerCase().trim();
    const candidates = document.querySelectorAll(
      'button, a, [role="button"], input[type="submit"], label, span, div[onclick]',
    );
    for (const el of candidates) {
      const elText = el.textContent?.toLowerCase().trim() || '';
      if (elText === normalizedText || elText.includes(normalizedText)) {
        return el;
      }
    }
    return null;
  }

  private findByAriaLabel(label: string): Element | null {
    return document.querySelector(
      `[aria-label="${label}"], [aria-label*="${label}" i], [title="${label}"], [placeholder="${label}" i]`,
    );
  }

  private waitForElement(selector: string, timeout: number): Promise<Element | null> {
    return new Promise((resolve) => {
      const existing = document.querySelector(selector);
      if (existing) { resolve(existing); return; }

      const observer = new MutationObserver(() => {
        const el = document.querySelector(selector);
        if (el) { observer.disconnect(); resolve(el); }
      });

      observer.observe(document.body, { childList: true, subtree: true });
      setTimeout(() => { observer.disconnect(); resolve(null); }, timeout);
    });
  }

  private async waitForStability(): Promise<void> {
    return new Promise((resolve) => {
      let mutations = 0;
      const observer = new MutationObserver(() => { mutations++; });
      observer.observe(document.body, { childList: true, subtree: true, attributes: true });

      setTimeout(() => {
        observer.disconnect();
        if (mutations < 3) { resolve(); return; }
        // DOM still changing — wait more
        setTimeout(resolve, 500);
      }, 200);
    });
  }

  private delay(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  // ... action executors (click, type, select, etc.)
}

export const actionDispatcher = new ActionDispatcher();
```

```typescript
// CORRECT ✅ — DOM serializer for AI context (compact, token-efficient)
// src/shared/utils/dom-serializer.ts

export function serializeDOM(
  root: Element = document.body,
  maxDepth: number = 6,
  maxElements: number = 200,
): string {
  const lines: string[] = [];
  let elementCount = 0;

  function walk(el: Element, depth: number, indent: string) {
    if (depth > maxDepth || elementCount >= maxElements) return;
    elementCount++;

    const tag = el.tagName.toLowerCase();
    const attrs = getRelevantAttributes(el);
    const text = getDirectText(el);

    // Skip invisible and irrelevant elements
    if (isHidden(el) || isIrrelevant(tag)) return;

    let line = `${indent}<${tag}`;
    if (attrs) line += ` ${attrs}`;
    if (text) line += ` text="${truncate(text, 80)}"`;
    line += '>';

    lines.push(line);

    // Recurse into children
    for (const child of el.children) {
      walk(child, depth + 1, indent + '  ');
    }
  }

  walk(root, 0, '');
  return lines.join('\n');
}

function getRelevantAttributes(el: Element): string {
  const relevant = ['id', 'class', 'type', 'name', 'placeholder', 'aria-label',
    'role', 'href', 'value', 'data-testid', 'title', 'alt'];
  const parts: string[] = [];

  for (const attr of relevant) {
    const val = el.getAttribute(attr);
    if (val) {
      // Truncate long class names
      const truncatedVal = attr === 'class' ? truncate(val, 50) : truncate(val, 100);
      parts.push(`${attr}="${truncatedVal}"`);
    }
  }
  return parts.join(' ');
}

function isIrrelevant(tag: string): boolean {
  return ['script', 'style', 'noscript', 'svg', 'path', 'meta', 'link', 'br', 'hr'].includes(tag);
}

function isHidden(el: Element): boolean {
  const style = window.getComputedStyle(el);
  return style.display === 'none' || style.visibility === 'hidden' ||
    el.hasAttribute('hidden') || (el as HTMLElement).offsetHeight === 0;
}

function getDirectText(el: Element): string {
  return Array.from(el.childNodes)
    .filter((n) => n.nodeType === Node.TEXT_NODE)
    .map((n) => n.textContent?.trim())
    .filter(Boolean)
    .join(' ');
}

function truncate(str: string, maxLen: number): string {
  return str.length > maxLen ? str.slice(0, maxLen) + '...' : str;
}
```

```
# CONTENT SCRIPT RULES:
# ✅ ALWAYS check element visibility before interacting
# ✅ ALWAYS wait for DOM stability before executing actions
# ✅ ALWAYS use multi-strategy element finding (selector → text → ARIA → wait)
# ✅ ALWAYS scroll element into view before clicking/typing
# ✅ ALWAYS dispatch proper DOM events (input, change, blur) after typing
# ✅ ALWAYS clean up MutationObservers when done
# ❌ NEVER use innerHTML to inject content (XSS risk — use DOM API)
# ❌ NEVER reference page's JS variables (isolated world)
# ❌ NEVER use document.write or eval in content scripts
# ❌ NEVER leave MutationObservers running after they're done
# ❌ NEVER trust element state — always re-query before acting
```

---

## 7. Chrome Storage Patterns

```typescript
// CORRECT ✅ — Type-safe storage wrapper with quota management
// src/background/storage-manager.ts

// ┌─────────────────────────────────────────────────────────────────┐
// │  STORAGE STRATEGY:                                              │
// │  chrome.storage.local   → Persistent data (conversations,      │
// │                           workflows, API keys, settings)       │
// │  chrome.storage.session → Ephemeral state (active tab,         │
// │                           pending operations, temp cache)      │
// │  chrome.storage.sync    → Cross-device settings (< 100KB)     │
// │                                                                 │
// │  LIMITS (without unlimitedStorage):                             │
// │  local: 10 MB | session: 10 MB | sync: 100 KB (8KB/item)     │
// │  With unlimitedStorage: local = unlimited                      │
// │                                                                 │
// │  ❌ NEVER use localStorage (not available in service worker)   │
// │  ❌ NEVER store > 8KB per key in sync storage                  │
// │  ❌ NEVER store screenshots without quota checks               │
// └─────────────────────────────────────────────────────────────────┘

interface StorageSchema {
  // Persistent (chrome.storage.local)
  conversations: Record<string, Conversation>;
  workflows: Record<string, Workflow>;
  apiKeys: Record<string, string>;
  settings: UserSettings;
  analyticsData: AnalyticsData;

  // Ephemeral (chrome.storage.session)
  sessionState: {
    activeTabId: number | null;
    pendingActions: [string, Action][];
    automationRunning: boolean;
  };

  // Cross-device (chrome.storage.sync)
  syncSettings: {
    theme: 'light' | 'dark' | 'system';
    defaultModel: string;
    language: string;
  };
}

// Type-safe get/set wrappers
export async function getLocal<K extends keyof StorageSchema>(
  key: K,
): Promise<StorageSchema[K] | undefined> {
  const result = await chrome.storage.local.get(key);
  return result[key] as StorageSchema[K] | undefined;
}

export async function setLocal<K extends keyof StorageSchema>(
  key: K,
  value: StorageSchema[K],
): Promise<void> {
  await chrome.storage.local.set({ [key]: value });
}

export async function getSession<K extends keyof StorageSchema>(
  key: K,
): Promise<StorageSchema[K] | undefined> {
  const result = await chrome.storage.session.get(key);
  return result[key] as StorageSchema[K] | undefined;
}

export async function setSession<K extends keyof StorageSchema>(
  key: K,
  value: StorageSchema[K],
): Promise<void> {
  await chrome.storage.session.set({ [key]: value });
}

// Storage quota monitoring
export async function getStorageUsage(): Promise<{
  bytesInUse: number;
  quota: number;
  percentUsed: number;
}> {
  const bytesInUse = await chrome.storage.local.getBytesInUse(null);
  const quota = chrome.storage.local.QUOTA_BYTES || 10 * 1024 * 1024; // 10MB default
  return {
    bytesInUse,
    quota,
    percentUsed: Math.round((bytesInUse / quota) * 100),
  };
}

// LRU eviction for large data (screenshots, old conversations)
export async function evictOldData(targetFreeBytes: number): Promise<number> {
  const { bytesInUse, quota } = await getStorageUsage();
  const freeBytes = quota - bytesInUse;

  if (freeBytes >= targetFreeBytes) return 0;

  // Get all conversations sorted by last activity
  const conversations = await getLocal('conversations') || {};
  const sorted = Object.entries(conversations)
    .sort(([, a], [, b]) => (a.lastActivity || 0) - (b.lastActivity || 0));

  let freedBytes = 0;
  for (const [id] of sorted) {
    if (freedBytes >= targetFreeBytes - freeBytes) break;
    const size = JSON.stringify(conversations[id]).length;
    delete conversations[id];
    freedBytes += size;
  }

  await setLocal('conversations', conversations);
  return freedBytes;
}
```

```typescript
// CORRECT ✅ — React hook for chrome.storage (sidepanel)
// src/sidepanel/hooks/useStorage.ts

import { useState, useEffect, useCallback } from 'react';

export function useStorage<T>(
  key: string,
  defaultValue: T,
  area: 'local' | 'sync' | 'session' = 'local',
): [T, (value: T | ((prev: T) => T)) => Promise<void>, boolean] {
  const [value, setValue] = useState<T>(defaultValue);
  const [loading, setLoading] = useState(true);
  const storage = chrome.storage[area];

  // Load initial value
  useEffect(() => {
    storage.get(key).then((result) => {
      if (result[key] !== undefined) {
        setValue(result[key] as T);
      }
      setLoading(false);
    });
  }, [key, area]);

  // Listen for external changes
  useEffect(() => {
    const listener = (
      changes: Record<string, chrome.storage.StorageChange>,
      areaName: string,
    ) => {
      if (areaName === area && changes[key]) {
        setValue(changes[key].newValue as T);
      }
    };
    chrome.storage.onChanged.addListener(listener);
    return () => chrome.storage.onChanged.removeListener(listener);
  }, [key, area]);

  // Setter with optimistic update
  const setStoredValue = useCallback(
    async (newValue: T | ((prev: T) => T)) => {
      const resolvedValue =
        typeof newValue === 'function'
          ? (newValue as (prev: T) => T)(value)
          : newValue;
      setValue(resolvedValue); // Optimistic UI update
      await storage.set({ [key]: resolvedValue });
    },
    [key, value, area],
  );

  return [value, setStoredValue, loading];
}
```

```typescript
// CORRECT ✅ — Data migration between extension versions
// src/background/migrations.ts

interface Migration {
  version: string;
  migrate: () => Promise<void>;
}

const migrations: Migration[] = [
  {
    version: '1.1.0',
    async migrate() {
      // Rename old storage keys
      const old = await chrome.storage.local.get('user_settings');
      if (old.user_settings) {
        await chrome.storage.local.set({ settings: old.user_settings });
        await chrome.storage.local.remove('user_settings');
      }
    },
  },
  {
    version: '1.2.0',
    async migrate() {
      // Add new field to existing conversations
      const { conversations } = await chrome.storage.local.get('conversations');
      if (conversations) {
        for (const conv of Object.values(conversations)) {
          (conv as any).category = (conv as any).category || 'general';
        }
        await chrome.storage.local.set({ conversations });
      }
    },
  },
];

export async function runMigrations(previousVersion: string | undefined) {
  if (!previousVersion) return; // Fresh install — no migration needed

  const { lastMigration } = await chrome.storage.local.get('lastMigration');
  const startFrom = lastMigration || previousVersion;

  for (const migration of migrations) {
    if (compareVersions(migration.version, startFrom) > 0) {
      console.log(`[Migration] Running ${migration.version}...`);
      try {
        await migration.migrate();
        await chrome.storage.local.set({ lastMigration: migration.version });
        console.log(`[Migration] ${migration.version} complete`);
      } catch (error) {
        console.error(`[Migration] ${migration.version} failed:`, error);
        // Don't stop — try next migration
      }
    }
  }
}

function compareVersions(a: string, b: string): number {
  const pa = a.split('.').map(Number);
  const pb = b.split('.').map(Number);
  for (let i = 0; i < 3; i++) {
    if ((pa[i] || 0) > (pb[i] || 0)) return 1;
    if ((pa[i] || 0) < (pb[i] || 0)) return -1;
  }
  return 0;
}
```

---

## 8. Security Patterns

```typescript
// CORRECT ✅ — Secure API key storage
// src/background/api-key-manager.ts

// ┌─────────────────────────────────────────────────────────────────┐
// │  API KEY SECURITY:                                              │
// │  ✅ Store in chrome.storage.local (extension-scoped, encrypted │
// │     at rest on most platforms)                                  │
// │  ✅ NEVER expose keys to content scripts                       │
// │  ✅ NEVER log keys to console                                  │
// │  ✅ NEVER include keys in error reports                        │
// │  ✅ NEVER send keys in messages to content scripts             │
// │  ✅ All API calls happen in service worker (background)        │
// │  ✅ Content script sends "chat" message → background makes API │
// │     call with key → streams response back                     │
// │  ❌ NEVER store keys in chrome.storage.sync (syncs to cloud)  │
// │  ❌ NEVER put keys in manifest.json or source code             │
// │  ❌ NEVER let side panel make direct API calls with keys       │
// └─────────────────────────────────────────────────────────────────┘

const STORAGE_KEY = 'apiKeys';

export async function setApiKey(
  provider: string,
  key: string,
): Promise<void> {
  const keys = (await chrome.storage.local.get(STORAGE_KEY))[STORAGE_KEY] || {};
  keys[provider] = key;
  await chrome.storage.local.set({ [STORAGE_KEY]: keys });
  // DO NOT log: console.log('Key set:', key) — NEVER log API keys
}

export async function getApiKey(provider: string): Promise<string | null> {
  const keys = (await chrome.storage.local.get(STORAGE_KEY))[STORAGE_KEY] || {};
  return keys[provider] || null;
}

export async function deleteApiKey(provider: string): Promise<void> {
  const keys = (await chrome.storage.local.get(STORAGE_KEY))[STORAGE_KEY] || {};
  delete keys[provider];
  await chrome.storage.local.set({ [STORAGE_KEY]: keys });
}

// Validate key format before storing
export function validateApiKeyFormat(provider: string, key: string): boolean {
  const patterns: Record<string, RegExp> = {
    anthropic: /^sk-ant-[a-zA-Z0-9_-]{90,}$/,
    openai: /^sk-[a-zA-Z0-9_-]{40,}$/,
    google: /^AI[a-zA-Z0-9_-]{35,}$/,
  };
  return patterns[provider]?.test(key) ?? key.length > 20;
}
```

```typescript
// CORRECT ✅ — Input sanitization for user content displayed in UI
// src/shared/utils/sanitizer.ts

// DOMPurify for HTML sanitization (if rendering markdown/HTML)
import DOMPurify from 'dompurify';

export function sanitizeHtml(dirty: string): string {
  return DOMPurify.sanitize(dirty, {
    ALLOWED_TAGS: ['b', 'i', 'em', 'strong', 'a', 'p', 'br', 'ul', 'ol', 'li',
      'code', 'pre', 'blockquote', 'h1', 'h2', 'h3', 'h4', 'span'],
    ALLOWED_ATTR: ['href', 'target', 'rel', 'class'],
    ALLOW_DATA_ATTR: false,
  });
}

// Sanitize user input before sending to AI or injecting into DOM
export function sanitizeInput(input: string): string {
  return input
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#x27;')
    .trim();
}

// Validate URLs before navigation
export function isValidUrl(url: string): boolean {
  try {
    const parsed = new URL(url);
    return ['http:', 'https:'].includes(parsed.protocol);
  } catch {
    return false;
  }
}
```

```
# SECURITY RULES:
# ✅ ALWAYS make API calls from service worker (never content/sidepanel)
# ✅ ALWAYS validate and sanitize AI-generated actions before execution
# ✅ ALWAYS use DOMPurify when rendering HTML from AI responses
# ✅ ALWAYS validate URLs before chrome.tabs.create or navigation
# ✅ ALWAYS set CSP in manifest.json for extension pages
# ✅ ALWAYS verify message sender in onMessage handlers
# ❌ NEVER use eval(), new Function(), or innerHTML with untrusted data
# ❌ NEVER sync API keys to chrome.storage.sync
# ❌ NEVER log sensitive data (keys, passwords, personal info)
# ❌ NEVER inject untrusted scripts into pages
# ❌ NEVER use document.write in content scripts
# ❌ NEVER trust data from page context without sanitization
```

---

## 9. AI Provider Integration

```typescript
// CORRECT ✅ — Abstract AI provider base class
// src/background/ai-providers/base-provider.ts

export interface AIMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

export interface AIRequest {
  model: string;
  messages: AIMessage[];
  maxTokens?: number;
  temperature?: number;
  stream?: boolean;
}

export interface AIResponse {
  content: string;
  model: string;
  usage: {
    inputTokens: number;
    outputTokens: number;
    totalTokens: number;
  };
  finishReason: 'stop' | 'max_tokens' | 'error';
}

export abstract class BaseAIProvider {
  protected apiKey: string;

  constructor(apiKey: string) {
    this.apiKey = apiKey;
  }

  abstract sendMessage(request: AIRequest): Promise<AIResponse>;

  abstract streamMessage(
    request: AIRequest,
    onChunk: (chunk: string) => void,
    onDone: (response: AIResponse) => void,
    onError: (error: Error) => void,
  ): Promise<void>;

  abstract validateApiKey(): Promise<boolean>;

  abstract get providerId(): string;
  abstract get displayName(): string;

  // Shared rate limiting
  protected async enforceRateLimit(): Promise<void> {
    const now = Date.now();
    const key = `rateLimit:${this.providerId}`;
    const { [key]: lastCall } = await chrome.storage.session.get(key);

    if (lastCall && now - lastCall < 1000) {
      // Min 1 second between calls
      await new Promise((r) => setTimeout(r, 1000 - (now - lastCall)));
    }
    await chrome.storage.session.set({ [key]: Date.now() });
  }
}
```

```typescript
// CORRECT ✅ — Claude provider implementation (streaming)
// src/background/ai-providers/claude-provider.ts

export class ClaudeProvider extends BaseAIProvider {
  readonly providerId = 'anthropic';
  readonly displayName = 'Claude';

  async streamMessage(
    request: AIRequest,
    onChunk: (chunk: string) => void,
    onDone: (response: AIResponse) => void,
    onError: (error: Error) => void,
  ): Promise<void> {
    await this.enforceRateLimit();

    const systemMessage = request.messages.find((m) => m.role === 'system');
    const conversationMessages = request.messages
      .filter((m) => m.role !== 'system')
      .map((m) => ({ role: m.role, content: m.content }));

    try {
      const response = await fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': this.apiKey,
          'anthropic-version': '2023-06-01',
          'anthropic-dangerous-direct-browser-access': 'true',
        },
        body: JSON.stringify({
          model: request.model,
          max_tokens: request.maxTokens || 4096,
          temperature: request.temperature ?? 0.7,
          system: systemMessage?.content || '',
          messages: conversationMessages,
          stream: true,
        }),
      });

      if (!response.ok) {
        const errorBody = await response.text();
        throw new Error(`Anthropic API error ${response.status}: ${errorBody}`);
      }

      // Parse SSE stream
      const reader = response.body!.getReader();
      const decoder = new TextDecoder();
      let fullContent = '';
      let inputTokens = 0;
      let outputTokens = 0;
      let buffer = '';

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split('\n');
        buffer = lines.pop() || ''; // Keep incomplete line in buffer

        for (const line of lines) {
          if (!line.startsWith('data: ')) continue;
          const data = line.slice(6);
          if (data === '[DONE]') continue;

          try {
            const event = JSON.parse(data);
            if (event.type === 'content_block_delta') {
              const text = event.delta?.text || '';
              fullContent += text;
              onChunk(text);
            } else if (event.type === 'message_start') {
              inputTokens = event.message?.usage?.input_tokens || 0;
            } else if (event.type === 'message_delta') {
              outputTokens = event.usage?.output_tokens || 0;
            }
          } catch {
            // Skip invalid JSON lines
          }
        }
      }

      onDone({
        content: fullContent,
        model: request.model,
        usage: {
          inputTokens,
          outputTokens,
          totalTokens: inputTokens + outputTokens,
        },
        finishReason: 'stop',
      });
    } catch (error) {
      onError(error instanceof Error ? error : new Error(String(error)));
    }
  }

  async sendMessage(request: AIRequest): Promise<AIResponse> {
    return new Promise((resolve, reject) => {
      let result: AIResponse;
      this.streamMessage(
        { ...request, stream: false },
        () => {},
        (response) => { result = response; resolve(result); },
        reject,
      );
    });
  }

  async validateApiKey(): Promise<boolean> {
    try {
      const response = await fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': this.apiKey,
          'anthropic-version': '2023-06-01',
          'anthropic-dangerous-direct-browser-access': 'true',
        },
        body: JSON.stringify({
          model: 'claude-haiku-4-5-20251001',
          max_tokens: 10,
          messages: [{ role: 'user', content: 'Hi' }],
        }),
      });
      return response.ok;
    } catch {
      return false;
    }
  }
}
```

```typescript
// CORRECT ✅ — Provider factory with model → provider mapping
// src/background/ai-providers/provider-factory.ts

import { ClaudeProvider } from './claude-provider';
import { OpenAIProvider } from './openai-provider';
import { GeminiProvider } from './gemini-provider';
import { getApiKey } from '../api-key-manager';

const MODEL_TO_PROVIDER: Record<string, string> = {
  'claude-opus-4-6': 'anthropic',
  'claude-sonnet-4-6': 'anthropic',
  'claude-haiku-4-5-20251001': 'anthropic',
  'gpt-4o': 'openai',
  'gpt-4o-mini': 'openai',
  'o1': 'openai',
  'gemini-2.0-flash': 'google',
  'gemini-2.5-pro': 'google',
};

export async function getProviderForModel(modelId: string): Promise<BaseAIProvider> {
  const providerId = MODEL_TO_PROVIDER[modelId];
  if (!providerId) throw new Error(`Unknown model: ${modelId}`);

  const apiKey = await getApiKey(providerId);
  if (!apiKey) throw new Error(`No API key configured for ${providerId}`);

  switch (providerId) {
    case 'anthropic': return new ClaudeProvider(apiKey);
    case 'openai': return new OpenAIProvider(apiKey);
    case 'google': return new GeminiProvider(apiKey);
    default: throw new Error(`Unknown provider: ${providerId}`);
  }
}
```

## 10. Side Panel UI Patterns (React + Zustand)

```typescript
// CORRECT ✅ — Side panel root with ErrorBoundary
// src/sidepanel/main.tsx

import React from 'react';
import { createRoot } from 'react-dom/client';
import { ErrorBoundary } from './components/ErrorBoundary';
import App from './App';
import './styles/index.css';

const container = document.getElementById('root')!;
const root = createRoot(container);
root.render(
  <React.StrictMode>
    <ErrorBoundary>
      <App />
    </ErrorBoundary>
  </React.StrictMode>,
);
```

```tsx
// CORRECT ✅ — ErrorBoundary (REQUIRED — prevents white screen of death)
// src/sidepanel/components/ErrorBoundary.tsx

import React, { Component, type ReactNode } from 'react';

interface ErrorBoundaryState {
  hasError: boolean;
  error: Error | null;
}

export class ErrorBoundary extends Component<
  { children: ReactNode; fallback?: ReactNode },
  ErrorBoundaryState
> {
  state: ErrorBoundaryState = { hasError: false, error: null };

  static getDerivedStateFromError(error: Error): ErrorBoundaryState {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
    console.error('[ErrorBoundary] Caught error:', error, errorInfo);
    // Report to error tracking service if configured
  }

  handleReset = () => {
    this.setState({ hasError: false, error: null });
  };

  render() {
    if (this.state.hasError) {
      return (
        this.props.fallback || (
          <div className="flex flex-col items-center justify-center h-full p-6 text-center">
            <div className="text-4xl mb-4">⚠️</div>
            <h2 className="text-lg font-semibold mb-2">Something went wrong</h2>
            <p className="text-sm text-muted-foreground mb-4 max-w-sm">
              {this.state.error?.message || 'An unexpected error occurred'}
            </p>
            <button
              onClick={this.handleReset}
              className="px-4 py-2 bg-primary text-primary-foreground rounded-md text-sm hover:bg-primary/90"
            >
              Try Again
            </button>
          </div>
        )
      );
    }
    return this.props.children;
  }
}
```

```typescript
// CORRECT ✅ — Zustand store with chrome.storage persistence
// src/sidepanel/stores/chatStore.ts

import { create } from 'zustand';

interface ChatMessage {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  timestamp: number;
  actions?: BrowserAction[];
}

interface Conversation {
  id: string;
  title: string;
  messages: ChatMessage[];
  createdAt: number;
  lastActivity: number;
}

interface ChatState {
  conversations: Record<string, Conversation>;
  activeConversationId: string | null;
  isStreaming: boolean;
  streamingContent: string;

  // Actions
  createConversation: () => string;
  addMessage: (convId: string, message: ChatMessage) => void;
  setActiveConversation: (id: string | null) => void;
  setStreaming: (streaming: boolean) => void;
  appendStreamChunk: (chunk: string) => void;
  deleteConversation: (id: string) => void;
  loadFromStorage: () => Promise<void>;
}

export const useChatStore = create<ChatState>((set, get) => ({
  conversations: {},
  activeConversationId: null,
  isStreaming: false,
  streamingContent: '',

  createConversation: () => {
    const id = crypto.randomUUID();
    const conv: Conversation = {
      id,
      title: 'New Conversation',
      messages: [],
      createdAt: Date.now(),
      lastActivity: Date.now(),
    };
    set((state) => ({
      conversations: { ...state.conversations, [id]: conv },
      activeConversationId: id,
    }));
    // Persist to chrome.storage
    persistConversations(get().conversations);
    return id;
  },

  addMessage: (convId, message) => {
    set((state) => {
      const conv = state.conversations[convId];
      if (!conv) return state;
      const updated = {
        ...conv,
        messages: [...conv.messages, message],
        lastActivity: Date.now(),
        title: conv.messages.length === 0 ? message.content.slice(0, 50) : conv.title,
      };
      const conversations = { ...state.conversations, [convId]: updated };
      persistConversations(conversations);
      return { conversations };
    });
  },

  setStreaming: (streaming) => set({ isStreaming: streaming, streamingContent: streaming ? '' : '' }),

  appendStreamChunk: (chunk) =>
    set((state) => ({ streamingContent: state.streamingContent + chunk })),

  setActiveConversation: (id) => set({ activeConversationId: id }),

  deleteConversation: (id) => {
    set((state) => {
      const { [id]: _, ...remaining } = state.conversations;
      persistConversations(remaining);
      return {
        conversations: remaining,
        activeConversationId: state.activeConversationId === id ? null : state.activeConversationId,
      };
    });
  },

  loadFromStorage: async () => {
    const result = await chrome.storage.local.get('conversations');
    if (result.conversations) {
      set({ conversations: result.conversations });
    }
  },
}));

// Debounced persistence to avoid excessive writes
let persistTimer: ReturnType<typeof setTimeout>;
function persistConversations(conversations: Record<string, Conversation>) {
  clearTimeout(persistTimer);
  persistTimer = setTimeout(() => {
    chrome.storage.local.set({ conversations });
  }, 500);
}
```

```tsx
// CORRECT ✅ — Chrome message listener hook
// src/sidepanel/hooks/useChromeMessage.ts

import { useEffect } from 'react';
import type { MessageType, ExtensionMessage } from '@shared/types/messages';

export function useChromeMessage(
  type: MessageType,
  handler: (payload: unknown) => void,
) {
  useEffect(() => {
    const listener = (message: ExtensionMessage) => {
      if (message.type === type) {
        handler(message.payload);
      }
    };
    chrome.runtime.onMessage.addListener(listener);
    return () => chrome.runtime.onMessage.removeListener(listener);
  }, [type, handler]);
}

// Usage in component:
function ChatContainer() {
  const { appendStreamChunk, setStreaming } = useChatStore();

  useChromeMessage(MessageType.CHAT_STREAM_CHUNK, (payload: any) => {
    appendStreamChunk(payload.chunk);
  });

  useChromeMessage(MessageType.CHAT_STREAM_DONE, () => {
    setStreaming(false);
  });

  useChromeMessage(MessageType.CHAT_STREAM_ERROR, (payload: any) => {
    setStreaming(false);
    toast.error(payload.error);
  });

  // ... render messages
}
```

```
# SIDE PANEL UI RULES:
# ✅ ALWAYS wrap App in ErrorBoundary (prevents white screen)
# ✅ ALWAYS persist Zustand state to chrome.storage (debounced)
# ✅ ALWAYS clean up chrome.runtime listeners in useEffect cleanup
# ✅ ALWAYS use React.lazy + Suspense for tab content (code splitting)
# ✅ ALWAYS show loading skeleton while storage data loads
# ❌ NEVER use localStorage (not available in extension context)
# ❌ NEVER make direct API calls from sidepanel (go through background)
# ❌ NEVER store large blobs in Zustand (persist to chrome.storage)
# ❌ NEVER forget cleanup in useEffect for message listeners
```

---

## 11. Error Handling Patterns

```typescript
// CORRECT ✅ — Structured error handling for extensions
// src/shared/utils/errors.ts

export class ExtensionError extends Error {
  constructor(
    message: string,
    public readonly code: string,
    public readonly context?: Record<string, unknown>,
  ) {
    super(message);
    this.name = 'ExtensionError';
  }
}

export class ContentScriptError extends ExtensionError {
  constructor(message: string, context?: Record<string, unknown>) {
    super(message, 'CONTENT_SCRIPT_ERROR', context);
    this.name = 'ContentScriptError';
  }
}

export class AIProviderError extends ExtensionError {
  constructor(
    message: string,
    public readonly provider: string,
    public readonly statusCode?: number,
    context?: Record<string, unknown>,
  ) {
    super(message, 'AI_PROVIDER_ERROR', { ...context, provider, statusCode });
    this.name = 'AIProviderError';
  }

  get isRateLimit(): boolean { return this.statusCode === 429; }
  get isAuthError(): boolean { return this.statusCode === 401 || this.statusCode === 403; }
  get isServerError(): boolean { return (this.statusCode || 0) >= 500; }
}

export class StorageQuotaError extends ExtensionError {
  constructor(bytesNeeded: number, bytesAvailable: number) {
    super(
      `Storage quota exceeded: need ${bytesNeeded} bytes, have ${bytesAvailable}`,
      'STORAGE_QUOTA_ERROR',
      { bytesNeeded, bytesAvailable },
    );
    this.name = 'StorageQuotaError';
  }
}

export class ElementNotFoundError extends ContentScriptError {
  constructor(selector: string, strategies: string[]) {
    super(`Element not found: ${selector}`, { selector, strategiesTried: strategies });
    this.name = 'ElementNotFoundError';
  }
}
```

```typescript
// CORRECT ✅ — Structured logger for extensions
// src/shared/utils/logger.ts

type LogLevel = 'debug' | 'info' | 'warn' | 'error';

const LOG_COLORS: Record<LogLevel, string> = {
  debug: '#9CA3AF',
  info: '#3B82F6',
  warn: '#F59E0B',
  error: '#EF4444',
};

class Logger {
  private context: string;
  private enabled: boolean;

  constructor(context: string) {
    this.context = context;
    this.enabled = process.env.NODE_ENV !== 'production';
  }

  debug(message: string, data?: unknown) { this.log('debug', message, data); }
  info(message: string, data?: unknown) { this.log('info', message, data); }
  warn(message: string, data?: unknown) { this.log('warn', message, data); }
  error(message: string, error?: unknown) {
    this.log('error', message, error);
    // Store error for later debugging
    this.persistError(message, error);
  }

  private log(level: LogLevel, message: string, data?: unknown) {
    if (!this.enabled && level === 'debug') return;

    const color = LOG_COLORS[level];
    const prefix = `%c[${this.context}]`;

    if (data !== undefined) {
      console[level === 'debug' ? 'log' : level](prefix, `color: ${color}`, message, data);
    } else {
      console[level === 'debug' ? 'log' : level](prefix, `color: ${color}`, message);
    }
  }

  private async persistError(message: string, error?: unknown) {
    try {
      const { errorLog = [] } = await chrome.storage.local.get('errorLog');
      errorLog.push({
        context: this.context,
        message,
        error: error instanceof Error ? error.message : String(error),
        stack: error instanceof Error ? error.stack : undefined,
        timestamp: Date.now(),
      });
      // Keep only last 100 errors
      if (errorLog.length > 100) errorLog.splice(0, errorLog.length - 100);
      await chrome.storage.local.set({ errorLog });
    } catch {
      // Can't log storage errors — just swallow
    }
  }
}

// Usage:
// const log = createLogger('Background');
// log.info('Service worker started');
// log.error('API call failed', error);
export function createLogger(context: string): Logger {
  return new Logger(context);
}
```

---

## 12. Performance Patterns

```typescript
// CORRECT ✅ — Lazy loading for content script modules
// src/content/action-executor/action-dispatcher.ts

// Heavy modules loaded on-demand only when needed
type LazyModule = { default: { extract: (doc: Document) => unknown } };

async function loadExtractor(domain: string): Promise<LazyModule | null> {
  const hostname = new URL(domain).hostname;

  // Only load platform-specific extractors when on that platform
  if (hostname.includes('gmail.com') || hostname.includes('outlook.com')) {
    return import('../page-context/email-extractor');
  }
  if (hostname.includes('amazon') || hostname.includes('flipkart')) {
    return import('../page-context/shopping-extractor');
  }
  if (hostname.includes('makemytrip') || hostname.includes('booking.com')) {
    return import('../page-context/travel-extractor');
  }

  return null; // No platform-specific extractor needed
}
```

```tsx
// CORRECT ✅ — Lazy loading for UI tabs (sidepanel)
// src/sidepanel/App.tsx

import React, { Suspense, lazy } from 'react';
import { Skeleton } from './components/ui/skeleton';

// Lazy-load heavy tab content
const ChatContainer = lazy(() => import('./components/chat/ChatContainer'));
const WorkflowPanel = lazy(() => import('./components/workflow/WorkflowPanel'));
const SettingsPanel = lazy(() => import('./components/settings/SettingsPanel'));
const AnalyticsDashboard = lazy(() => import('./components/analytics/AnalyticsDashboard'));

function TabContent({ activeTab }: { activeTab: string }) {
  return (
    <Suspense fallback={<TabSkeleton />}>
      {activeTab === 'chat' && <ChatContainer />}
      {activeTab === 'workflows' && <WorkflowPanel />}
      {activeTab === 'settings' && <SettingsPanel />}
      {activeTab === 'analytics' && <AnalyticsDashboard />}
    </Suspense>
  );
}

function TabSkeleton() {
  return (
    <div className="p-4 space-y-3">
      <Skeleton className="h-8 w-3/4" />
      <Skeleton className="h-4 w-full" />
      <Skeleton className="h-4 w-5/6" />
      <Skeleton className="h-32 w-full" />
    </div>
  );
}
```

```typescript
// CORRECT ✅ — Debounced DOM serialization for AI context
// src/content/page-context/context-extractor.ts

let cachedContext: PageContext | null = null;
let cacheTimestamp = 0;
const CACHE_TTL = 5000; // 5 second cache

export async function extractPageContext(
  options?: { includeInteractive?: boolean },
): Promise<PageContext> {
  const now = Date.now();

  // Return cached if fresh
  if (cachedContext && now - cacheTimestamp < CACHE_TTL) {
    return cachedContext;
  }

  // Extract fresh context
  const context: PageContext = {
    url: window.location.href,
    title: document.title,
    metadata: readMetadata(),
    textContent: summarizeText(document.body, 2000), // Max 2000 chars
    interactiveElements: options?.includeInteractive
      ? findInteractiveElements(50) // Max 50 elements
      : [],
    domTree: serializeDOM(document.body, 4, 100), // Depth 4, max 100 nodes
  };

  cachedContext = context;
  cacheTimestamp = now;
  return context;
}
```

```
# PERFORMANCE RULES:
# ✅ ALWAYS lazy-load platform-specific extractors (don't bundle all on every page)
# ✅ ALWAYS use React.lazy + Suspense for tab content in sidepanel
# ✅ ALWAYS cache page context extraction (5-10s TTL)
# ✅ ALWAYS limit DOM serialization depth (max 4-6 levels, max 100-200 nodes)
# ✅ ALWAYS truncate text content for AI (max 2000-4000 chars per field)
# ✅ ALWAYS debounce chrome.storage writes (500ms minimum)
# ✅ ALWAYS use requestIdleCallback for non-urgent DOM analysis
# ❌ NEVER serialize entire DOM tree (exponential cost on complex pages)
# ❌ NEVER run heavy computation on main thread without requestIdleCallback
# ❌ NEVER cache indefinitely in content script (pages change)
# ❌ NEVER load all AI provider modules upfront (tree-shake via factory)
# ❌ NEVER send full page HTML as AI context (serialize relevant parts only)
```

---

## 13. Testing Patterns

```typescript
// CORRECT ✅ — Vitest configuration for Chrome extension
// vitest.config.ts

import { defineConfig } from 'vitest/config';
import path from 'path';

export default defineConfig({
  resolve: {
    alias: {
      '@shared': path.resolve(__dirname, 'src/shared'),
      '@background': path.resolve(__dirname, 'src/background'),
      '@content': path.resolve(__dirname, 'src/content'),
      '@sidepanel': path.resolve(__dirname, 'src/sidepanel'),
    },
  },
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./src/__tests__/setup.ts'],
    include: ['src/**/*.test.ts', 'src/**/*.test.tsx'],
    coverage: {
      reporter: ['text', 'html'],
      include: ['src/**/*.ts', 'src/**/*.tsx'],
      exclude: ['src/**/*.test.*', 'src/__tests__/**'],
    },
  },
});
```

```typescript
// CORRECT ✅ — Chrome API mock setup
// src/__tests__/setup.ts

import { vi } from 'vitest';

// Mock chrome.* APIs for unit tests
const mockStorage: Record<string, unknown> = {};

globalThis.chrome = {
  runtime: {
    sendMessage: vi.fn().mockResolvedValue({ success: true }),
    onMessage: {
      addListener: vi.fn(),
      removeListener: vi.fn(),
    },
    getURL: vi.fn((path: string) => `chrome-extension://mock-id/${path}`),
    id: 'mock-extension-id',
    connect: vi.fn(() => ({
      onDisconnect: { addListener: vi.fn() },
      disconnect: vi.fn(),
      postMessage: vi.fn(),
    })),
    getPlatformInfo: vi.fn((cb: Function) => cb({ os: 'mac' })),
  },
  storage: {
    local: {
      get: vi.fn(async (keys: string | string[]) => {
        if (typeof keys === 'string') {
          return { [keys]: mockStorage[keys] };
        }
        const result: Record<string, unknown> = {};
        for (const key of keys) {
          result[key] = mockStorage[key];
        }
        return result;
      }),
      set: vi.fn(async (items: Record<string, unknown>) => {
        Object.assign(mockStorage, items);
      }),
      remove: vi.fn(async (keys: string | string[]) => {
        const keyArr = typeof keys === 'string' ? [keys] : keys;
        for (const key of keyArr) delete mockStorage[key];
      }),
      getBytesInUse: vi.fn(async () => 0),
      QUOTA_BYTES: 10 * 1024 * 1024,
    },
    session: {
      get: vi.fn(async () => ({})),
      set: vi.fn(async () => {}),
    },
    sync: {
      get: vi.fn(async () => ({})),
      set: vi.fn(async () => {}),
    },
    onChanged: {
      addListener: vi.fn(),
      removeListener: vi.fn(),
    },
  },
  tabs: {
    query: vi.fn(async () => []),
    sendMessage: vi.fn(async () => ({ success: true })),
    get: vi.fn(async (tabId: number) => ({ id: tabId, url: 'https://example.com' })),
    onActivated: { addListener: vi.fn() },
    onRemoved: { addListener: vi.fn() },
    onUpdated: { addListener: vi.fn() },
  },
  scripting: {
    executeScript: vi.fn(async () => []),
    insertCSS: vi.fn(async () => {}),
  },
  sidePanel: {
    setPanelBehavior: vi.fn(),
  },
  alarms: {
    create: vi.fn(),
    clear: vi.fn(),
    onAlarm: { addListener: vi.fn() },
  },
  notifications: {
    create: vi.fn(),
  },
} as unknown as typeof chrome;
```

```typescript
// CORRECT ✅ — Unit test for message router
// src/background/__tests__/message-router.test.ts

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { MessageType, createMessage } from '@shared/types/messages';

describe('Message Router', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('should route CHAT_SEND to chat handler', async () => {
    const mockHandler = vi.fn().mockResolvedValue({ text: 'response' });
    // Register handler...

    const message = createMessage(MessageType.CHAT_SEND, {
      message: 'Hello',
      conversationId: 'conv-1',
    });

    const result = await handleMessage(message, {} as chrome.runtime.MessageSender);
    expect(result).toEqual({ text: 'response' });
    expect(mockHandler).toHaveBeenCalledWith({
      message: 'Hello',
      conversationId: 'conv-1',
    });
  });

  it('should return error for unknown message type', async () => {
    const message = { type: 'UNKNOWN_TYPE', payload: {}, timestamp: Date.now() };
    const result = await handleMessage(
      message as any,
      {} as chrome.runtime.MessageSender,
    );
    expect(result).toEqual({ error: expect.stringContaining('Unknown') });
  });
});
```

```typescript
// CORRECT ✅ — Unit test for DOM serializer
// src/shared/utils/__tests__/dom-serializer.test.ts

import { describe, it, expect } from 'vitest';
import { serializeDOM } from '../dom-serializer';

describe('DOM Serializer', () => {
  it('should serialize interactive elements with attributes', () => {
    document.body.innerHTML = `
      <div>
        <button id="submit" class="btn">Submit</button>
        <input type="text" placeholder="Enter name" />
        <a href="/about">About</a>
      </div>
    `;

    const result = serializeDOM(document.body, 3, 50);
    expect(result).toContain('<button');
    expect(result).toContain('id="submit"');
    expect(result).toContain('text="Submit"');
    expect(result).toContain('<input');
    expect(result).toContain('placeholder="Enter name"');
    expect(result).toContain('<a');
    expect(result).toContain('href="/about"');
  });

  it('should skip hidden elements', () => {
    document.body.innerHTML = `
      <div>
        <span style="display:none">Hidden</span>
        <span>Visible</span>
      </div>
    `;

    const result = serializeDOM(document.body, 3, 50);
    expect(result).not.toContain('Hidden');
    expect(result).toContain('Visible');
  });

  it('should respect maxDepth', () => {
    document.body.innerHTML = `
      <div><div><div><div><div>Deep</div></div></div></div></div>
    `;

    const result = serializeDOM(document.body, 2, 50);
    expect(result).not.toContain('Deep');
  });

  it('should respect maxElements', () => {
    document.body.innerHTML = Array.from({ length: 50 }, (_, i) =>
      `<span>Item ${i}</span>`
    ).join('');

    const result = serializeDOM(document.body, 3, 10);
    const elementCount = (result.match(/<span/g) || []).length;
    expect(elementCount).toBeLessThanOrEqual(10);
  });
});
```

```typescript
// CORRECT ✅ — Unit test for API key validation
// src/background/__tests__/api-key-manager.test.ts

import { describe, it, expect } from 'vitest';
import { validateApiKeyFormat } from '../api-key-manager';

describe('API Key Validation', () => {
  it('should validate Anthropic key format', () => {
    expect(validateApiKeyFormat('anthropic', 'sk-ant-' + 'a'.repeat(95))).toBe(true);
    expect(validateApiKeyFormat('anthropic', 'sk-invalid')).toBe(false);
    expect(validateApiKeyFormat('anthropic', '')).toBe(false);
  });

  it('should validate OpenAI key format', () => {
    expect(validateApiKeyFormat('openai', 'sk-' + 'a'.repeat(45))).toBe(true);
    expect(validateApiKeyFormat('openai', 'invalid-key')).toBe(false);
  });

  it('should validate Google key format', () => {
    expect(validateApiKeyFormat('google', 'AI' + 'a'.repeat(37))).toBe(true);
    expect(validateApiKeyFormat('google', 'short')).toBe(false);
  });
});
```

---

## 14. i18n (Internationalization)

```json
// CORRECT ✅ — Chrome extension i18n via _locales
// public/_locales/en/messages.json
{
  "extensionName": {
    "message": "AI Browser Automation",
    "description": "Extension display name"
  },
  "extensionDescription": {
    "message": "AI-powered browser automation with multi-model support",
    "description": "Extension description for Chrome Web Store"
  },
  "settingsTitle": {
    "message": "Settings",
    "description": "Settings page title"
  },
  "chatPlaceholder": {
    "message": "Type a message or describe an action...",
    "description": "Chat input placeholder text"
  },
  "errorApiKeyMissing": {
    "message": "Please configure your API key in Settings",
    "description": "Error when no API key is set"
  }
}
```

```typescript
// CORRECT ✅ — i18n helper for React components
// src/shared/utils/i18n.ts

export function t(messageName: string, substitutions?: string | string[]): string {
  return chrome.i18n.getMessage(messageName, substitutions) || messageName;
}

// Usage in React:
// <h1>{t('settingsTitle')}</h1>
// <input placeholder={t('chatPlaceholder')} />
```

---

## 15. Chrome Web Store Readiness Checklist

```
# ┌─────────────────────────────────────────────────────────────────┐
# │  CHROME WEB STORE SUBMISSION CHECKLIST                          │
# ├─────────────────────────────────────────────────────────────────┤
# │                                                                 │
# │  REQUIRED FILES:                                                │
# │  ✅ manifest.json with all required fields                     │
# │  ✅ Icons: 16x16, 32x32, 48x48, 128x128 PNG                  │
# │  ✅ Screenshots: 1280x800 or 640x400 (min 1, max 5)          │
# │  ✅ Promo images: 440x280 (small), 920x680 (large — optional) │
# │  ✅ Privacy policy URL (REQUIRED for host_permissions)         │
# │                                                                 │
# │  STORE LISTING:                                                 │
# │  ✅ Title (max 45 chars)                                       │
# │  ✅ Summary (max 132 chars)                                    │
# │  ✅ Detailed description (max 16,384 chars)                    │
# │  ✅ Category selection                                         │
# │  ✅ Language / region targeting                                │
# │                                                                 │
# │  PERMISSION JUSTIFICATION (required for each permission):      │
# │  ✅ activeTab — "Access current tab to read page content       │
# │     and execute user-requested browser automation actions"     │
# │  ✅ sidePanel — "Side panel is the primary UI for chat and     │
# │     automation controls"                                       │
# │  ✅ storage — "Store user conversations, workflows, settings,  │
# │     and API keys locally"                                      │
# │  ✅ tabs — "Track active tab for automation context and        │
# │     programmatic content script injection"                     │
# │  ✅ scripting — "Inject content scripts for DOM interaction    │
# │     and browser automation on user-selected pages"             │
# │  ✅ alarms — "Schedule recurring automation workflows"        │
# │  ✅ notifications — "Notify user of completed automations     │
# │     and scheduled task results"                                │
# │  ✅ <all_urls> — "Read page content and execute user-directed │
# │     actions on any website the user chooses to automate"       │
# │                                                                 │
# │  SINGLE PURPOSE:                                                │
# │  ✅ "AI-powered browser automation assistant that helps users  │
# │     interact with web pages through natural language commands" │
# │                                                                 │
# │  DATA HANDLING DISCLOSURE:                                      │
# │  ✅ "Page content is processed locally and optionally sent to  │
# │     AI providers (Anthropic, OpenAI, Google) as configured by │
# │     the user. API keys are stored locally, never transmitted  │
# │     to any server besides the configured AI provider."        │
# │                                                                 │
# │  COMPLIANCE:                                                    │
# │  ✅ No remotely hosted code (MV3 requirement)                 │
# │  ✅ No obfuscated code                                        │
# │  ✅ No hidden functionality                                   │
# │  ✅ Clear data collection disclosure                          │
# │  ✅ GDPR/CCPA compliance if storing personal data             │
# │                                                                 │
# │  REVIEW TRIGGERS (expect extra scrutiny):                      │
# │  ⚠️  <all_urls> host permission                              │
# │  ⚠️  storage + scripting combination                         │
# │  ⚠️  AI/ML functionality                                     │
# │  ⚠️  Data sent to external APIs                              │
# └─────────────────────────────────────────────────────────────────┘
```

---

## 16. Observer Cleanup Pattern

```typescript
// CORRECT ✅ — MutationObserver with proper cleanup
// src/content/observers/mutation-observer.ts

class DOMObserverManager {
  private observers: MutationObserver[] = [];
  private eventListeners: Array<{
    target: EventTarget;
    type: string;
    handler: EventListener;
  }> = [];

  // Track all observers for cleanup
  observe(
    target: Element,
    config: MutationObserverInit,
    callback: MutationCallback,
  ): MutationObserver {
    const observer = new MutationObserver(callback);
    observer.observe(target, config);
    this.observers.push(observer);
    return observer;
  }

  // Track all event listeners for cleanup
  addEventListener(
    target: EventTarget,
    type: string,
    handler: EventListener,
    options?: AddEventListenerOptions,
  ) {
    target.addEventListener(type, handler, options);
    this.eventListeners.push({ target, type, handler });
  }

  // Clean up EVERYTHING — call on page unload or content script detach
  cleanup() {
    for (const observer of this.observers) {
      observer.disconnect();
    }
    this.observers = [];

    for (const { target, type, handler } of this.eventListeners) {
      target.removeEventListener(type, handler);
    }
    this.eventListeners = [];
  }
}

export const domObserverManager = new DOMObserverManager();

// Register cleanup on page unload
window.addEventListener('beforeunload', () => {
  domObserverManager.cleanup();
});
```

---

## 17. Quality Checklist — ENFORCED PER FILE

```
╔═══════════════════════════════════════════════════════════════════╗
║  Chrome Extension Quality Checklist (VERIFY EVERY FILE)          ║
╠═══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  SERVICE WORKER (background/):                                    ║
║  ✅ State persisted to chrome.storage.session on every change    ║
║  ✅ State rehydrated from storage on every wake                  ║
║  ✅ chrome.alarms used instead of setInterval                    ║
║  ✅ Keep-alive mechanism for long operations (>30s)              ║
║  ✅ onInstalled handles install + update separately              ║
║  ✅ All API keys accessed from secure storage only               ║
║  ✅ Structured logging with createLogger()                       ║
║                                                                   ║
║  CONTENT SCRIPTS (content/):                                      ║
║  ✅ Multi-strategy element finding (selector → text → ARIA → wait)║
║  ✅ DOM stability check before actions                           ║
║  ✅ MutationObserver cleanup on disconnect/unload                ║
║  ✅ Element visibility check before interaction                  ║
║  ✅ No chrome.tabs/chrome.storage direct access                  ║
║  ✅ Platform extractors lazy-loaded per domain                   ║
║  ✅ DOM serialization capped (depth + element count)             ║
║                                                                   ║
║  SIDE PANEL (sidepanel/):                                         ║
║  ✅ ErrorBoundary at App level + per major section               ║
║  ✅ React.lazy + Suspense for tab content                        ║
║  ✅ Zustand stores persist to chrome.storage (debounced)         ║
║  ✅ chrome.runtime listener cleanup in useEffect                 ║
║  ✅ Loading skeletons while storage loads                        ║
║  ✅ All API calls go through background (never direct)           ║
║  ✅ All user inputs sanitized before display                     ║
║                                                                   ║
║  MESSAGES:                                                        ║
║  ✅ Type-safe with MessageType enum + MessagePayloadMap          ║
║  ✅ return true in onMessage for async sendResponse              ║
║  ✅ "Receiving end does not exist" handled gracefully            ║
║  ✅ Large data (>64KB) sent via chrome.storage, not messages     ║
║                                                                   ║
║  SECURITY:                                                        ║
║  ✅ API calls from service worker ONLY                           ║
║  ✅ CSP in manifest.json                                         ║
║  ✅ DOMPurify for HTML rendering                                 ║
║  ✅ URL validation before navigation                             ║
║  ✅ No eval(), new Function(), or innerHTML with untrusted data  ║
║  ✅ API keys NEVER in chrome.storage.sync                        ║
║                                                                   ║
║  TESTING:                                                         ║
║  ✅ Chrome API mocked in test setup                              ║
║  ✅ Unit tests for message router, parsers, validators           ║
║  ✅ Component tests for UI interactions                          ║
║                                                                   ║
║  STORE READINESS:                                                 ║
║  ✅ Permission justifications documented                         ║
║  ✅ Privacy policy URL in manifest                               ║
║  ✅ i18n strings via chrome.i18n.getMessage()                    ║
║  ✅ Icons at all required sizes (16, 32, 48, 128)               ║
║  ✅ No remotely hosted code                                      ║
╚═══════════════════════════════════════════════════════════════════╝
```
