# iOS Demo（Flutter）

一个用于验证「Windows 上开发 → GitHub Actions 云端 macOS 构建 → Sideloadly 免费签名 → 安装到 iPhone」这条链路的最小 Flutter demo。

## demo 内容

- 运行环境卡片（平台、屏幕尺寸、渲染方式）
- 计数器（加一 / 归零）
- 输入名字并打招呼
- SnackBar 提示

## 本地预览（Windows）

本机已装 Flutter（鸿蒙分支），可以正常开发和在 Chrome 里预览，但**无法在本机编译 iOS**。

```bash
flutter pub get
flutter run -d chrome
```

也可以只构建网页产物：

```bash
flutter build web
```

## 云端构建未签名 IPA

### 1. 推到 GitHub

在项目根目录执行（把地址换成你自己的仓库）：

```bash
git init
git add .
git commit -m "Add Flutter iOS demo and cloud build workflow"
git branch -M main
git remote add origin https://github.com/<你的用户名>/<仓库名>.git
git push -u origin main
```

仓库建议选 **private**：代码不公开，GitHub Free 每月 2000 分钟额度，macOS runner 按 10 倍折算，约合 200 分钟 macOS 构建时间，小 demo 够用几十次。选 public 则构建分钟数不受限。

### 2. 等待 Actions 完成

推送后 `.github/workflows/ios-build.yml` 会自动触发；也可以在仓库的 **Actions → Build unsigned iOS IPA → Run workflow** 手动触发。

工作流做的事：

1. 在 `macos-latest` 上安装官方 Flutter stable
2. 跑 `flutter test`
3. `flutter build ios --release --no-codesign`（不签名，避免需要开发者证书）
4. 把 `Runner.app` 打成 `Payload/` 再压缩成 `ios_demo-unsigned.ipa`
5. 上传为 artifact，保留 30 天

首次构建大约 5–10 分钟，之后有缓存会快一些。

### 3. 下载 IPA

打开这次 run 的页面，在页面底部 **Artifacts** 里下载 `ios-demo-unsigned-ipa`，解压得到 `ios_demo-unsigned.ipa`。

## 安装到 iPhone（Sideloadly + 免费 Apple ID）

本机已经有 Apple Mobile Device 驱动（服务正在运行），直接装 Sideloadly 即可。

1. 从 <https://sideloadly.io> 下载并安装 Sideloadly。
2. 数据线连接 iPhone，解锁手机，在弹窗里点「信任此电脑」。
3. 打开 Sideloadly，把 `ios_demo-unsigned.ipa` 拖进窗口。
4. **Apple account** 填你的 Apple ID；如果提示 Bundle ID 冲突，在高级选项里把 Bundle ID 改成唯一的，例如 `com.<你的名字>.iosdemo`。
5. 点 **Start**，按提示输入 Apple ID 密码和双重认证验证码，等待安装完成。
6. iPhone 上打开 **设置 → 隐私与安全性 → 开发者模式**，打开开关并按提示重启（iOS 16 及以上必须）。
7. 重启后打开 **设置 → 通用 → VPN 与设备管理**，在「开发者 App」下信任你的 Apple ID。
8. 回到桌面，打开 App。

## 免费账号的限制

- **签名 7 天过期**，过期后 App 点开即闪退，需要重新签名安装。
- **同时最多 3 个**自签 App。
- 不支持推送、iCloud 等需要付费开发者账号的能力。
- 想自动续签：改用 **AltStore**（Windows 上运行 AltServer，手机和电脑在同一 Wi-Fi 下会每 7 天自动重签）。免费账号的限制依然存在。

## 常见问题

| 现象 | 处理 |
| --- | --- |
| 安装时提示 bundle id 已存在 / 冲突 | Sideloadly 里改一个唯一的 Bundle ID 再签 |
| 打开 App 立即闪退 | 多半是签名过期或证书未信任；重新签名并信任证书 |
| 提示 Unable to install | 确认已开启开发者模式、数据线连接正常、手机上点了「信任」 |
| Sideloadly 找不到设备 | 安装 Microsoft Store 的 **Apple Devices** 应用（或 Apple 官网版 iTunes），确认 `Apple Mobile Device Service` 服务在运行 |
| Apple ID 登录反复失败 | 在 <https://appleid.apple.com> 生成 App 专用密码，Sideloadly 里用它代替账号密码 |
| GitHub Actions 构建失败 | 打开 run 日志看具体步骤；workflow 用的是官方 Flutter `stable` |
| 不想用 GitHub Actions | Codemagic 每月约 500 分钟免费额度，Flutter 项目配置更简单 |

## 后续升级

如果以后要长期使用或发给别人测试，可以考虑 $99/年的 Apple Developer Program：

- **ad-hoc 分发**：注册设备 UDID，签名一年有效，不用每 7 天续签。
- **TestFlight**：上传 App Store Connect，手机装 TestFlight 安装，有效期 90 天；内部测试（最多 100 人）不需要审核。

## 目录

- `lib/main.dart`：demo 全部界面与逻辑
- `test/widget_test.dart`：计数器与打招呼的 widget 测试
- `.github/workflows/ios-build.yml`：云构建未签名 IPA
