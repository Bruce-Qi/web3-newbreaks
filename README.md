# Web3 资讯（Flutter）

一个 Flutter 写的 Web3 资讯 + 行情 App，支持 **Android / iOS / macOS**。

| Tab | 内容 |
| --- | --- |
| 资讯 | 聚合主流中文 Web3 媒体的最新快讯，按时间倒序合并、跨来源去重，可按来源筛选、搜索，点开看正文 / 阅读原文 |
| 行情 | 市值前 100 的加密货币，**美元计价**：最新价、24h 涨跌、市值、7 日走势线；详情页有 24H/7D/30D/1Y 可交互走势图和数据概览，可加自选 |

## 数据来源

**资讯**（每个来源先试官方接口，失败时自动改用 RSSHub 备用通道）：

| 来源 | 官方接口 | RSSHub 备用路由 |
| --- | --- | --- |
| 律动 BlockBeats | `api.theblockbeats.news` 开放接口 (lang=cn) | `/theblockbeats/newsflash` |
| 金色财经 | `api.jinse.cn` 快讯接口 | `/jinse/lives` |
| Odaily 星球日报 | `rss.odaily.news/rss/newsflash` | `/odaily/newsflash` |
| PANews | `rss.panewslab.com/zh/tvsq/rss` | `/panewslab/newsflash` |
| 链捕手 ChainCatcher | — | `/chaincatcher/news` |
| 深潮 TechFlow | `www.techflowpost.com/rss.aspx` | `/techflowpost/express` |
| Foresight News | — | `/foresightnews/news` |

- 某个来源抓取失败不影响其他来源，界面会标出失败的来源和原因。
- 公共实例 `rsshub.app` 经常限流，建议在 **设置 → RSSHub 地址** 里换成自建实例（`docker run -d -p 1200:1200 diygod/rsshub`）。
- 增删来源：编辑 `lib/services/news_sources.dart`。普通 RSS/Atom 直接用 `parseFeed`，不用另写解析器。

**行情**：CoinGecko `/coins/markets`（vs_currency=usd）。CoinGecko 不可用或被限流时自动切换到币安公开行情（`data-api.binance.vision`，USDT 交易对，近似美元）。设置里可以填 CoinGecko 免费 Demo API Key，减少被限流。

## 项目结构

```
lib/
  main.dart                  入口、主题、底部导航（宽屏自动改为侧边栏）
  models/                    NewsItem、Coin
  services/
    news_sources.dart        资讯来源配置（官方地址 + RSSHub 备用）
    feed_parser.dart         RSS/Atom 通用解析 + 律动/金色专用解析
    news_service.dart        并发抓取、合并、去重、排序
    price_service.dart       CoinGecko + Binance 兜底、走势图
    settings.dart            本地持久化设置（来源开关、涨跌颜色、自选、主题）
  pages/                     资讯 / 资讯详情 / 行情 / 币种详情 / 设置
  widgets/                   走势线、交互图表、通用组件
test/                        解析器、格式化和布局测试
.github/workflows/build.yml  CI：一次构建出 APK / IPA / DMG
```

## 本地运行

```bash
flutter pub get
flutter test
flutter run            # 连接手机/模拟器，或在 Mac 上 flutter run -d macos
```

## 构建三个平台的安装包

> iOS 和 macOS 必须在装有 Xcode 的 Mac 上构建（这是 Apple 的限制，跟 Flutter 无关）。
> 没有 Mac 的话，用下面的 GitHub Actions 方式就能拿到三个平台的安装包。

### 方式一：GitHub Actions 自动构建（推荐）

1. 把本项目推到一个 GitHub 仓库。
2. 每次 push 到 `main` 都会自动跑测试并构建，到 **Actions → 对应运行 → Artifacts** 下载：
   - `android` → `Web3News-android-universal.apk`（还有 arm64 / armv7 分包）
   - `ios` → `Web3News-ios-unsigned.ipa`
   - `macos` → `Web3News-macos.dmg`
3. 推送 `v1.0.0` 这样的 tag 会自动创建 GitHub Release，附上三个安装包：

```bash
git tag v1.0.0
```

```bash
git push origin v1.0.0
```

### 方式二：在自己电脑上构建

```bash
flutter build apk --release                 # Android，产物 build/app/outputs/flutter-apk/app-release.apk
```

```bash
flutter build ios --release                 # iOS，需要 Mac + Xcode + Apple 开发者签名
```

```bash
flutter build macos --release               # macOS，产物 build/macos/Build/Products/Release/Web3News.app
```

## 安装说明

- **Android**：直接安装 APK（需要允许“安装未知来源应用”）。没有配置正式签名时用的是 debug 签名，可以安装使用，但不能上架应用商店。要用正式签名，在仓库 Secrets 里配置 `ANDROID_KEYSTORE_BASE64`、`ANDROID_KEYSTORE_PASSWORD`、`ANDROID_KEY_ALIAS`、`ANDROID_KEY_PASSWORD`。
- **iOS**：iOS 不允许安装未签名的应用。拿到 `unsigned.ipa` 后可以：
  - 用 [Sideloadly](https://sideloadly.io) / AltStore + 自己的 Apple ID 重签名安装（免费 Apple ID 签名 7 天有效）；或者
  - 在 Mac 上用 Xcode 打开 `ios/Runner.xcworkspace`，在 Signing & Capabilities 里选你的 Team，直接 Run 到手机；
  - 要上 TestFlight / App Store，需要 Apple 开发者账号（99 美元/年）。
- **macOS**：打开 DMG，把 Web3News 拖进“应用程序”。应用没有公证，第一次打开时右键 → 打开；如果提示“已损坏”，执行：

```bash
xattr -cr /Applications/Web3News.app
```

## 说明

资讯版权归各媒体所有，本应用仅做聚合展示；行情仅供参考，不构成投资建议。
第三方接口可能会改版或限制访问，遇到某来源长期失败时，去 `news_sources.dart` 更新地址即可。
