# 小一二减肥记

> 把「今天吃了什么、喝了多少、体重有没有降」收进一张不用动脑子的日历。

一个本地优先的个人减重记录 App。Flutter 开发，iPhone 为主，可在 Chrome 预览；通过 GitHub Actions 在 macOS 上构建未签名 IPA，再用 Sideloadly 侧载到 iPhone。

## 功能（V1.0）

### 今日
- 今日体重速记，显示与上次的差值
- 热量环：已吃 / 每日预算 / 今日计划 / 剩余
- 今日餐单打卡，勾选即计入已吃热量
- 喝水进度与快捷记录
- 连续打卡天数与温和的鼓励语

### 食谱
- **日历**：月历同时显示每日体重、早 / 中 / 晚完成圆点、喝水达标水滴
- **日详情**：点日期查看当天体重、早 / 午 / 晚 / 加餐、每餐热量与合计、打卡
- **食谱库**：搜索、按餐次筛选、只看收藏；内置 22 道中式家常食谱
- **自定义食谱**：名称、餐次、热量、食材（可自动汇总热量）、做法、标签、收藏
- **长期食谱**：内置 5 套多日方案（7天极速掉秤 / 5+2掉秤 / 一只白+郭敬明 / 5天12斤 / 110-100）；查看每天的三餐与参考体重，选好起止日期后一键铺进日历，支持整批撤销
- **自定义长期食谱**：新建自己的方案并起任意名字，逐天编辑三餐、参考体重和备注；支持改名、复制内置方案后修改，自定义方案可删除
- **食谱计划**：按周查看与安排每天每餐，支持打卡

### 运动
- 7 个训练方向：哑铃、有氧、肩颈、手臂、瘦腰、小腿、拉伸
- 42 个 B 站热门跟练视频，按播放量挑选并逐条校验标题、UP 主、时长与 BV 号
- 点视频卡片或「在 B 站打开」直接跳到对应的 B 站视频
- 收藏常练的视频；把视频加入某一天的运动计划，在运动页或今日页打勾完成
- 封面图已打包进应用，离线也能正常显示

### 体重
- 记录 / 编辑 / 删除；同一天可记录多次，代表体重取最后一条
- 当前体重、累计变化、距目标、BMI（中国成人标准）
- 趋势图：7 天 / 30 天 / 90 天 / 全部，7 日移动平均线，目标线
- 记录列表按月份分组，显示与上一条的差值

### 喝水
- 快捷 +200 / +300 / +500 ml，自定义日期与时间
- 每日目标（按体重自动计算或手动设置）、达标状态、连续达标天数
- 今日记录、近 7 天柱状图

### AI 助手
- 自带 API Key 的对话式减重助手，默认使用免费的智谱 GLM-4.5-Flash
- 内置智谱 GLM、硅基流动、阿里云百炼三家预设，也可填任意 OpenAI 兼容接口
- 每次对话自动带上今天的体重、热量、饮食与喝水摘要，回答「今天还能吃什么」这类问题
- API Key 只保存在本机，不会写进导出的 JSON 备份
- 浏览器预览可能被服务商拒绝跨域（CORS），装到 iPhone 后不受影响

### 设置
- 个人资料、目标与预算、喝水目标
- 体重单位（公斤 / 斤）、主题（系统 / 浅色 / 深色）、每周起始、启动页
- 导出完整 JSON 备份，或体重 / 饮食 / 喝水 CSV
- 清空业务数据

## 技术栈

- Flutter 3.35 / Dart 3.9，Material 3
- `provider` 状态管理
- `shared_preferences` 本地存储（Web 端落在 localStorage）
- `fl_chart` 体重趋势图；日历、进度环、柱状图为自绘
- `flutter_localizations` 中文界面
- `file_saver` 导出文件（iOS 使用系统保存面板，Web 触发下载）
- `url_launcher` 打开 B 站视频链接
- `http` 调用 OpenAI 兼容的 AI 接口
- `uuid` 生成记录 ID

## 本地预览

```bash
flutter pub get
flutter run -d chrome
```

只构建 Web 产物：

```bash
flutter build web
```

构建后可用任意静态服务器预览：

```bash
python -m http.server 8099 --directory build/web
```

然后打开 <http://localhost:8099>。

## 测试

```bash
flutter analyze
flutter test
```

当前包含 48 个测试：计算规则（BMI / BMR / 预算 / 水量 / 均线 / 日期）、数据仓库（代表体重、打卡联动、连续打卡、导出、清空）、内置长期方案（数据完整性、批量加入与撤销、详情页与加入面板、宽屏布局）、自定义长期食谱（新建、改名、删除与持久化）、运动（内置视频与封面完整性、收藏与运动计划持久化、分类页展示）、引导完整流程、新增自定义食谱、AI 配置与接口调用（请求格式、错误映射、提示词摘要、页面状态），以及首次启动与进入今日页的 Widget 测试。

## 云端构建未签名 IPA

### 1. 推到 GitHub

在项目根目录执行（把地址换成你自己的仓库）：

```bash
git init
git add .
git commit -m "Build 小一二减肥记 V1.0"
git branch -M main
git remote add origin https://github.com/<你的用户名>/<仓库名>.git
git push -u origin main
```

仓库建议选 **private**：GitHub Free 每月 2000 分钟额度，macOS runner 按 10 倍折算，约合 200 分钟 macOS 构建时间；选 public 则构建分钟数不受限。

### 2. 等待 Actions 完成

推送后 `.github/workflows/ios-build.yml` 会自动触发；也可以在仓库的 **Actions → Build unsigned iOS IPA → Run workflow** 手动触发。

工作流会：

1. 在 `macos-latest` 上安装官方 Flutter stable
2. 跑 `flutter analyze`
3. 跑 `flutter test`
4. `flutter build ios --release --no-codesign`
5. 把 `Runner.app` 打成 `Payload/` 再压缩成 `xiaoyier-unsigned.ipa`
6. 上传为 artifact，保留 30 天

首次构建大约 5–10 分钟，之后有缓存会快一些。

### 3. 下载 IPA

打开这次 run 的页面，在底部 **Artifacts** 下载 `xiaoyier-unsigned-ipa`，解压得到 `xiaoyier-unsigned.ipa`。

## 安装到 iPhone（Sideloadly + 免费 Apple ID）

1. 从 <https://sideloadly.io> 下载并安装 Sideloadly。
2. 数据线连接 iPhone，解锁手机，在弹窗里点「信任此电脑」。
3. 打开 Sideloadly，把 `xiaoyier-unsigned.ipa` 拖进窗口。
4. **Apple account** 填你的 Apple ID；如果提示 Bundle ID 冲突，在高级选项里把 Bundle ID 改成唯一的，例如 `com.<你的名字>.xiaoyier`。
5. 点 **Start**，按提示输入 Apple ID 密码和双重认证验证码，等待安装完成。
6. iPhone 上打开 **设置 → 隐私与安全性 → 开发者模式**，打开开关并按提示重启（iOS 16 及以上必须）。
7. 重启后打开 **设置 → 通用 → VPN 与设备管理**，在「开发者 App」下信任你的 Apple ID。
8. 回到桌面，打开「小一二减肥记」。

### 免费账号的限制

- **签名 7 天过期**，过期后 App 点开即闪退，需要重新签名安装。
- **同时最多 3 个**自签 App。
- 不支持推送、iCloud 等需要付费开发者账号的能力。
- 想自动续签：改用 **AltStore**（Windows 上运行 AltServer，手机和电脑在同一 Wi-Fi 下每 7 天自动重签）。

## 数据与备份

- 不注册，全部记录保存在本机应用沙盒（Web 端为 localStorage）。只有你使用 AI 助手并发送消息时，才会把资料摘要和对话内容发送给你自己配置的 AI 服务；API Key 也只保存在本机。
- 在 **设置 → 导出数据** 中可导出：
  - 完整 JSON 备份（包含全部记录与设置）
  - 体重 / 饮食 / 喝水 CSV（便于用表格分析）
- 卸载 App 会删除本机数据；免费签名过期重新签名通常不会，但建议养成定期导出的习惯。
- iOS 端已开启文件共享（`UIFileSharingEnabled`），导出的文件也可以从「文件」App 的「我的 iPhone → 小一二减肥记」中找到。

## 项目结构

```
lib/
├── main.dart                 # 初始化仓库并启动
├── app.dart                  # MaterialApp、主题、本地化、引导/主界面切换
├── core/
│   ├── app_date.dart         # 本地日期、周起始、月历网格
│   ├── app_theme.dart        # 颜色与 Material 3 主题
│   ├── calculators.dart      # BMI / BMR / TDEE / 预算 / 水量 / 均线
│   ├── formatters.dart       # 体重单位、餐次、百分比格式化
│   └── widgets.dart          # 卡片、进度环、空状态、图表等通用组件
├── data/
│   ├── app_repository.dart   # 全部业务数据、持久化、聚合、导出
│   ├── seed_exercises.dart   # 42 个 B 站热门跟练视频
│   ├── seed_plans.dart       # 5 套内置长期食谱方案
│   └── seed_recipes.dart     # 22 道内置食谱
├── models/
│   ├── ai.dart               # AI 配置、消息与服务商预设
│   ├── exercise.dart         # 运动视频、分类与运动计划
│   └── models.dart           # Profile / WeightRecord / Recipe / MealEntry / WaterLog / DietPlan
├── services/                 # 跨平台文件导出（IO / Web）与 AI 接口调用
└── features/
    ├── onboarding/           # 首次使用引导
    ├── shell/                # 可收起侧边栏、响应式布局
    ├── today/                # 今日聚合首页
    ├── recipes/              # 日历、日详情、食谱库、详情、编辑、计划、长期方案与方案编辑
    ├── exercise/             # 运动分类、B 站跳转、收藏与运动计划
    ├── weight/               # 体重记录、趋势图、记录列表
    ├── water/                # 喝水
    ├── ai/                   # AI 对话页
    └── settings/             # 设置、个人资料、目标预算、AI 接入
assets/
└── exercises/                # 内置跟练视频封面（按 BV 号命名）
test/
├── calculators_test.dart
├── repository_test.dart
├── plans_test.dart
├── exercise_test.dart
└── widget_test.dart
docs/
└── PRD-小一二减肥记.md        # 产品设计文档（含 P0/P1/P2 规划与验收清单）
```

## 版本规划

V1.0（当前）覆盖产品设计文档中的全部 P0：侧边栏、今日、食谱日历 / 食谱库 / 计划 / 打卡、长期食谱方案、体重、喝水、引导、设置、导出、本地存储与内置食谱。另外新增了 PRD 之外的 AI 助手（默认免费模型，用户自带 API Key）、自定义长期食谱，以及聚合 B 站热门跟练的运动板块（分类、收藏、运动计划）。

P1 计划：回顾页、本地提醒、成就徽章、导入备份、体脂与备注、食谱照片、复制上周 / 拖拽排计划。详见 [产品设计文档](docs/PRD-小一二减肥记.md) 第 12 章。

## 已知限制

- 未做账号与云同步；换手机需要通过 JSON 备份迁移（导入功能在 P1，当前可保留备份文件以备后续版本使用）。
- 食谱热量为估算值，可在自定义食谱中修改。
- Web 预览依赖系统 CJK 字体，个别生僻字在部分环境下可能回退显示；iOS 系统字体不受影响。
- 未签名 IPA 依赖免费 Apple ID，7 天需重新签名。

## 产品文档

- [产品设计文档（PRD）](docs/PRD-小一二减肥记.md)
