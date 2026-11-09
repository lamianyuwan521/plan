---
name: remote-ios-ipa
description: >-
  先把本仓库（小一二减肥记，github.com/lamianyuwan521/plan）的最新源码推送到 origin，再在 GitHub Actions 上构建未签名 IPA，下载到 dist/xiaoyier-unsigned.ipa。
  每次执行都先推送再构建：main 上接住 push 触发的那一次 workflow（.github/workflows/ios-build.yml，artifact 名 xiaoyier-unsigned-ipa），禁止用本机 flutter build ios、xcodebuild 或 dist 里已有的包代替。
  用户要求生成 IPA、打 IPA、重打 IPA、云端构建、远端构建、GitHub Actions 构建、未签名 IPA、推送后构建时使用。
  只是询问安装方法、工作流内容或 Sideloadly 用法时不要触发构建。
---

# 远端构建未签名 IPA

本机是 Windows，打不出 iOS 包。IPA 只来自 GitHub Actions 的 macOS runner，而且打的是刚刚推上去的那次提交。

## 硬规则

- 每次执行都是「先推送最新源码，再接住远端构建」。工作流文件是 `.github/workflows/ios-build.yml`。`push` 到 `main` 会自动跑；其他分支要在推送后 `workflow_dispatch`。
- 远端仓库只认 `origin`：`github.com/lamianyuwan521/plan`。origin 不对就停，不要对别的仓库 push 或 dispatch。
- 产物是 artifact `xiaoyier-unsigned-ipa` 里的 `xiaoyier-unsigned.ipa`。下到仓库根目录的 `dist/xiaoyier-unsigned.ipa`。
- 工作流会先 `flutter analyze` 和 `flutter test`，失败就没有 IPA。不要为了出包去改工作流、跳过测试或分析。
- 不要把 `dist/` 里旧的 ipa、zip 当成这次的结果。成功只认本轮脚本打出的 `IPA_READY`。
- 同一次推送只保留一个远端构建。推送到 `main` 之后不要再 `workflow_dispatch`。看到 `BUSY`、`DO_NOT_DISPATCH` 或退出码 3、5 时，不要再开一轮。
- macOS runner 分钟按 10 倍计。

## 每次执行

1. 看 `git status -sb`。下面这些不要提交：`dist/**`、`.claude/**`、`.env`、`credentials.json`、`*.p12`、`*.pem`、`*.mobileprovision`、`*.keystore`。遇到密钥文件就停下来告诉用户，不要提交。
2. 其余源码有改动就提交。调用本 skill 就是用户要求把当前源码推上去再构建。提交说明沿用仓库现有风格，写清为什么改。禁止 `git push --force`，禁止跳过 hooks。
3. `git push origin HEAD`。非快进被拒绝就停，不要强推。
4. 推送结果决定脚本模式，不要两个都跑：
   - 这次 push 更新了 `main`：`-Mode push`（接住 push 触发的 run）
   - 分支不是 `main`：先得到 `NO_PUSH_RUN`，再 `-Mode dispatch`
   - 已经和 `origin` 一致、push 没有新提交：`-Mode dispatch`（这次仍要出一包）
5. 用户明确说「不要推送 / 只用远端现有提交」时，跳过提交和推送，改跑 `-Mode dispatch -AllowStale`。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".cursor/skills/remote-ios-ipa/scripts/build-remote-ipa.ps1" -Mode push
```

Shell 的 `block_until_ms` 设为 `2700000`。若命令被转到后台，只轮询这一条输出，直到出现 `IPA_READY`、`SOURCE_DIRTY`、`NO_PUSH_RUN`、`DO_NOT_DISPATCH`、`BUSY` 或 `ERROR:`。不要再启动第二个脚本。

`gh` 不在 PATH 时，脚本也会查找 `C:\Program Files\GitHub CLI\gh.exe`。两边都没有就安装一次，然后重跑同一条命令，不要改用手写 API 调用：

```powershell
winget install --id GitHub.cli -e --accept-package-agreements --accept-source-agreements
```

`gh auth status` 失败时停下来，让用户自己执行 `gh auth login`（需要能触发 Actions 并下载 artifact）。不要编造、打印或写入 token。推送用的是 git 凭据，和 `gh` 无关；`main` 上的 push 即使还没装 `gh` 也会开始构建。

## 退出码

| 码 | 标记 | 做什么 |
| --- | --- | --- |
| 0 | `IPA_READY` | 把路径、字节数、`BUILD_SHA`、`RUN_URL` 回报给用户 |
| 4 | `SOURCE_DIRTY` | 源码还没推进这次提交。提交并推送后，从第 4 步重跑。不要问用户要不要推送 |
| 2 | `NO_PUSH_RUN` | 这次 push 不会自动构建（分支不是 `main`）。立刻用 `-Mode dispatch` 补一次 |
| 3 | `DO_NOT_DISPATCH` | 远端构建已经发出或还在跑，只是还没跟到 run。禁止再 dispatch。过一分钟用 `-Mode run -RunId <id>` 继续等 |
| 5 | `BUSY` | 已有脚本在跑。只等待那个进程，不要再触发 |
| 1 | `ERROR:` | 构建或下载失败。展示 `dist/ipa-build-failure.log` 的末尾和 `RUN_URL`。停。用户没要求重试就不要再 dispatch。若标记是 `FETCH_FAILED`，构建还没开始，恢复对 github.com 的访问后从推送结果那一步重跑 |

`-Mode push` 只用于刚刚推送到 `main`、且本地 `HEAD` 已经等于 `origin/main` 的那一次。`dist/` 和 `.claude/` 可以仍是脏的，它们不进包。不要拿这个模式去下载几小时前的旧 run。

## 回报

成功时直接给这几项：

```text
远端构建完成
- 仓库: https://github.com/lamianyuwan521/plan
- 分支 / 提交: <ref> @ <BUILD_SHA>
- Run: <RUN_URL>
- IPA: dist/xiaoyier-unsigned.ipa（<IPA_MB> MB）
```

补一句：这是未签名包，用 Sideloadly 安装。不要展开安装教程，除非用户接着问。

失败时说明失败发生在分析、测试还是打包，并给出 Run 链接。不要声称已经生成 IPA。
