# Prowl-example

Demonstrates **every public `Prowl` API** from the ProwlKit facade.

## Open

```bash
open Example/Prowl-example/Prowl-example.xcodeproj
```

Select the **Prowl-example** scheme, run on **iOS Simulator** or **My Mac**.

## Tabs

| Tab | What it shows |
| --- | --- |
| **Network** | Live `URLSession` traffic — mock, rewrite, ignore, rate alert, body snapshot |
| **API** | Buttons for each public `Prowl` method and property |
| **Inspector** | Embedded `ProwlInspectorView()` |

## APIs exercised

- `configure`, `start`, `stop`, `show`, `hide`, `toggle`
- `storage`, `ignoredURLs`, `ignoredURLRegexes`, `ignoreURL`, `ignoreURL(regex:)`
- `isLoggingEnabled`, `isSensitiveDataMaskingEnabled`, `isSessionPersistenceEnabled`
- `customSessionDelegate`, `responseBodyLoggingTransformer`
- `endpointRateAlertRules`, `resetEndpointRateAlertCounters`
- Mock rules: `mockRules`, `addMockRule`, `updateMockRule`, `saveMockRule`, `moveMockRuleUp/Down`, `setMockRuleEnabled`, `removeMockRule`, `removeAllMockRules`
- Rewrite rules: full CRUD + `setRequestRewriteRuleEnabled`
- `logWebSocketEvent`, `logGrpcCall`
- `ProwlLogFormatter.export`, `ProwlSearchParser`
- `setProwlHTTPBodyStream` (stream upload with body snapshot)
