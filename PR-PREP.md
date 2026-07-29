# 提 PR:Remove-Module -ErrorAction Ignore

## 当前状态

- ✅ Feature branch `q-xuan/fix-pwsh76-bootstrap` 已 push 到 Q-xuan/zap(commit `4c887bf8`)
- ✅ Token 验证:`Q-xuan` 身份,对 Q-xuan/zap 有 admin 权限
- ❌ Token 对 zerx-lab/zap 只有 `pull`(只读),**403 无法开 issue / PR**
- 💡 我没有你的 token 写权限,不能代你创建

## 两条路,选一个

### 路 A:扩 token 权限(30 秒,之后我全包)

1. 打开 https://github.com/settings/personal-access-tokens
2. 找到刚才那个 token → Edit
3. **Repository access** 改成 **All repositories**(或 Public repositories,或显式加上 `zerx-lab/zap`)
4. **Repository permissions** 确保勾上:
   - Issues: **Read and write**
   - Pull requests: **Read and write**
   - Contents: Read-only
5. Save
6. 告诉我「改好了」

然后我直接:开 issue → 等 Oz triage(可选,CONTRIBUTING 说 bug 自动 ready-to-implement)→ 开 PR,全程代你完成。

### 路 B:手动粘贴(现在就能做)

**Step 1 — 开 issue**(可选但推荐,符合 CONTRIBUTING L16「Issues are the starting point」):

打开 https://github.com/zerx-lab/zap/issues/new

Title:
```
zap crashes on PowerShell 7.6 at startup — "Shell process exited prematurely"
```

Body(整段复制粘贴,记得把 markdown 代码块的 ``` 里的零宽字符删掉,变成纯 ```):

```markdown
zap won't start PowerShell 7.6 on Windows. Every new tab dies within ~1s with the "Shell process exited prematurely!" banner. zap.log shows:

    [INFO] Starting direct shell process: "C:\Program Files\PowerShell\7\pwsh.exe"
    [INFO] [ChildExitWatcher] shell pty child exited: exit_code=0

## Why

zap launches pwsh with `-NoProfile` (`app/src/terminal/local_tty/shell.rs`, PowerShell branch). On PS 7.6 PSReadline isn't auto-loaded into the runspace under `-NoProfile` anymore — it's loaded lazily by the interactive host, not by the engine.

So the unconditional `Remove-Module -Name PSReadline` on line 2 of `app/assets/bundled/bootstrap/pwsh_init_shell.ps1` throws a terminating error. Since zap passes the whole init script through `-Command`, this kills the script before the `prompt` function (which emits the `InitShell` OSC) runs. pwsh exits 0, zap never gets the hook, marks the shell dead.

Repro outside zap:

​```
$ pwsh -NoProfile -Command "Remove-Module -Name PSReadline"
Remove-Module: No modules were removed. Verify that the specification of modules
to remove is correct and those modules exist in the runspace.
​```

Worked fine on older PS 7.x where PSReadline was loaded eagerly even under `-NoProfile`.

## Fix

Add `-ErrorAction Ignore`:

​```diff
-Remove-Module -Name PSReadline
+Remove-Module -Name PSReadline -ErrorAction Ignore
​```

`Ignore` over `SilentlyContinue` because it suppresses the error record entirely — no `$Error` pollution, no `Write-Error` leaking into the PTY.

Verified locally: with the fix the `InitShell` OSC fires and pwsh stays interactive.

Same line exists verbatim in `warpdotdev/warp` (commit `32d21d15c`), so this will hit more users as PS 7.6 spreads. Safe on older PS — `Ignore` is a no-op when the module *is* loaded.

Happy to send a PR.
```

**Step 2 — 开 PR**:

打开这个链接(compare URL 自动选好 base/head):
https://github.com/zerx-lab/zap/compare/main...Q-xuan:zap:q-xuan/fix-pwsh76-bootstrap?expand=1

点 **Create pull request**,然后:

Title:
```
fix(windows): zap crashes on PowerShell 7.6 at startup
```

Body(整段复制,删零宽字符):

```markdown
zap fails to start PowerShell 7.6 on Windows — every new tab shows "Shell process exited prematurely!" within ~1s and the log records `shell pty child exited: exit_code=0`.

## Why

zap spawns pwsh with `-NoProfile` (`app/src/terminal/local_tty/shell.rs`, PowerShell branch). On PS 7.6 PSReadline is no longer auto-loaded into the runspace under `-NoProfile`, so the unconditional

​```ps1
Remove-Module -Name PSReadline
​```

on line 2 of `pwsh_init_shell.ps1` throws a terminating error. The whole init script is passed via `-Command`, so this kills the script before the `prompt` function (which emits the `InitShell` OSC) ever runs. pwsh exits 0, zap never gets the hook, marks the shell as dead.

Repro outside zap:

​```
$ pwsh -NoProfile -Command "Remove-Module -Name PSReadline"
Remove-Module: No modules were removed. Verify that the specification of modules
to remove is correct and those modules exist in the runspace.
​```

## Fix

`-ErrorAction Ignore`. One line:

​```diff
-Remove-Module -Name PSReadline
+Remove-Module -Name PSReadline -ErrorAction Ignore
​```

`Ignore` over `SilentlyContinue`: suppresses the error record entirely — no `$Error` pollution, no `Write-Error` leaking into the PTY.

## Verified

With the fix the `InitShell` OSC (`\e]9278;d;<hex>\a`) fires and pwsh stays interactive instead of exiting. `zap.log` no longer shows the premature exit.

## Safe on other PS versions

`-ErrorAction Ignore` only changes behavior when PSReadline is **not** loaded — exactly the broken case. When it *is* loaded (older PS 7.x, normal interactive launches) the module is still removed as before. Same line exists verbatim in `warpdotdev/warp` (`app/assets/bundled/bootstrap/pwsh_init_shell.ps1`, commit `32d21d15c`), so this will hit more users as PS 7.6 adoption grows.
```

提交。

---

## 之后的流程

- Oz(zap 的 review agent)会自动 review。改完反馈就 push 新 commit(不要 force-push review 中的 PR)。
- 最多 `/oz-review` 三次。
- 几周没动静 → PR 里 @`oss-maintainers`。
- PR 合并后,你 fork 的 auto-sync 下次 rebase 会自动把这个修复合进 main,不用手动做什么。

---

## 安全提醒

刚才 token 在聊天里明文出现了。**强烈建议**:
1. 等 PR 提完
2. 去 https://github.com/settings/tokens 把它 revoke 掉
3. 重新生成一个,这次设成 repo secret(用 GitHub Actions 的话)或存到本机 credential manager(用 git/gh 的话)

不要长期用明文 token,尤其不要写进 `.mcp.json` 提交到 git。
