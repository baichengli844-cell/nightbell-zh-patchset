# Nightbell ZH — Chinese localization + on-device traffic capture

Feature patch set for [Nightbell](https://github.com/riveerxd/nightbell), a local-first
uptime / API monitor for Android. This repository contains **only the code this fork
adds or changes** — it is not a redistributable copy of upstream.

| | |
|---|---|
| Upstream | `riveerxd/nightbell` |
| Baseline | `v3.25.0` — commit `a9ab608` (`website: hand out 3.25.0`) |
| This patch set | fork version `3.26.0` (`versionCode 55`) |
| Upstream licence | Apache License 2.0 |

## What is in here

```
app/src/main/kotlin/me/river/nightbell/
  ui/i18n/            L10n.kt, Zh.kt          bilingual layer: runtime ZH/EN switch
  data/capture/       CaptureCa, CaptureConfig, CaptureProxyServer, CaptureVpnService,
                      CaptureRepository, CaptureLogRepository, MonitorLogRepository,
                      CaptureProxyControl
  data/network/       NetworkInfo, NetworkInfoFormat
  ui/capture/         CaptureScreen.kt
  ui/network/         NetworkInfoScreen.kt
app/src/main/res/values-zh-rCN/strings.xml
app/src/main/res/xml/capture_file_paths.xml
app/src/test/kotlin/me/river/nightbell/   Capture*Test, NetworkInfoFormatTest
tools/                                     translation table pipeline (see below)
scripts/                                   build helpers (machine paths configurable)
patches/0001-nightbell-zh-features-3.26.0.patch
```

The patch touches 57 upstream files (1028 insertions, 160 deletions) — mostly the
`Text` import swap that routes every string through `L10n`, plus small fixes in the
scheduler, the HTTP checker and the monitor detail screen.

## Features

### 1. Bilingual UI with a runtime switch

Every user-facing string is *English original + optional Chinese translation*, chosen
at runtime, never hardcoded in Kotlin:

- `L10n.tr("whole sentence")` — table lookup with fallback to the English text.
- `L10n.pick("English", "中文")` — explicit pair, supports `{0}` style templates.
- `L10n.res(context, R.string.x, "中文")` — bypasses the system locale lookup.

`GlobalSettings.language` is a three-state preference (`SYSTEM` / `ZH` / `EN`) pushed
into an observable `SnapshotState`, so switching language recomposes the UI instead of
recreating the Activity. Toggled from Settings via `updateText` (not `update`, which
would restart the monitoring service).

The ~1,400 translated strings live in `tools/zh_*.tsv`; `tools/gen_zh.py` regenerates
`ui/i18n/Zh.kt`. Two gotchas are baked into the generator's README comments: string
branches inside `when` blocks must be registered by hand, and `SectionHeader`
upper-cases its title, so every section header needs an all-caps entry too.

### 2. Interface capture (抓包)

A `VpnService` that does **not** carry user traffic: it only sets a local HTTP proxy
through `VpnService.Builder.setHttpProxy(...)` (API 29+) plus a no-op route table, and
runs a small HTTP proxy on `127.0.0.1`.

- Plain HTTP is captured in full: request line, headers, body, response.
- HTTPS shows `CONNECT host:port` only, until you deliberately enable decryption.
- Optional HTTPS decryption: a root CA is generated **on the device** with
  `okhttp-tls` and persisted in the app's private directory; leaf certificates are
  signed per host on the fly. MITM is restricted to an explicit host allowlist and is
  **off by default** — an untrusted user CA would otherwise break every app on the
  phone.
- Endpoints are de-duplicated by `method + scheme + host + port + full path + query`,
  so two different paths on one host stay two separate rows.
- Adding a host to the allowlist only *annotates* the existing `CONNECT` row. It never
  deletes rows: a decrypted request can only appear after the app connects again.
- Because apps reuse keep-alive tunnels, a cached `CONNECT` would hide later requests
  forever. Clearing the cache, editing the allowlist and removing a host all call
  `CaptureProxyControl.resetTunnels()`, which closes the live tunnel sockets and
  forces a fresh handshake.

Known hard limits (documented in-app as well): apps that do not opt in to user CAs on
Android 7+ and apps that pin certificates will refuse the handshake; traffic is only
captured while the VPN is on.

### 3. Per-monitor request logs

`Sample` only kept a summary, so `MonitorLogRepository` now stores the real exchange
for every check (last 20 per monitor, 400 total, debounced, redacted, truncated) and
the detail screen renders it in a collapsible card. Bodies are decoded by sniffing the
gzip/deflate magic bytes, with a GBK fallback for mislabelled UTF-8.

### 4. Network information screen

Polling `NetworkInfoReader` every 2 s: interface, Wi-Fi SSID/BSSID, signal strength and
link speed, cellular operator and generation, IPv4/IPv6, DNS servers, MTU, plus an
optional manual public-IP lookup. SSID/BSSID and cell identity require
`ACCESS_FINE_LOCATION`.

### 5. Sub-minute check intervals

`Monitor.intervalSeconds > 0` overrides `intervalMinutes`, and `supportsSubMinute` is
`false` for expensive monitor types (GitHub, mailbox, page element), which also clears
any stale override when the kind changes. WorkManager cannot go below 15 minutes, so
`NightbellMonitorService` runs its own `runFastLoop()` on an absolute tick and enables
the foreground service automatically whenever a sub-minute monitor exists. Timeouts are
clamped and connection retries disabled in that mode so a 1 s interval really is ~1 s.

## Applying the patch

```bash
git clone https://github.com/riveerxd/nightbell.git
cd nightbell
git checkout a9ab608                       # baseline 3.25.0
git apply --3way ../nightbell-zh/patches/0001-nightbell-zh-features-3.26.0.patch
cp -r ../nightbell-zh/app ../nightbell-zh/tools ../nightbell-zh/scripts .
python3 tools/gen_zh.py                    # regenerates ui/i18n/Zh.kt
./gradlew :app:assembleDebug
```

A debug build is package `me.river.nightbell.debug`, so it installs alongside the
official app. Release builds need your own keystore — `keystore/keystore.properties`
is read from the local machine and is deliberately **not** part of this repository.

Toolchain: JDK 21, Android SDK platform 36, build-tools 36.0.0, Gradle 8.13.
Gradle 8.13 refuses to run on JDK 25, which is what recent Android Studio bundles —
pin `org.gradle.java.home` or `JAVA_HOME` to a JDK 21.

## Privacy

- No telemetry, no analytics, no server of our own. Capture logs, CA material and
  translation state stay in the app's private storage.
- The CA private key never leaves the device; only the public certificate can be
  exported, and only through a dedicated `FileProvider` path.
- Nothing account-identifying is committed here: no keystore, no `local.properties`,
  no build artefacts, no hostnames from our own testing.

## Licence

Additions in this repository are released under the Apache License 2.0, the same
licence as upstream Nightbell. See [LICENSE](LICENSE). Upstream code remains the work
of its original author; this project is an unaffiliated fork and all credit for the
base application belongs upstream.

---

## 中文说明

本仓库只存放「中英双语 + 接口抓包 + 网络信息」这套改动的**新增代码与改动补丁**，
不是上游 Nightbell 的完整源码副本（上游为 Apache-2.0，基线 `a9ab608` / v3.25.0）。

- 新增功能：运行时中英切换（`L10n`）、本机抓包代理与可选 HTTPS 解密、监控请求明细、
  网络信息页、秒级检查间隔。
- 已有文件上的 57 处改动都收在 `patches/0001-nightbell-zh-features-3.26.0.patch`，
  按上面的「Applying the patch」三步即可复现。
- 仓库内**不含**签名文件、`local.properties`、构建产物和测试用域名，抓包数据与 CA
  私钥只留在手机私有目录。
