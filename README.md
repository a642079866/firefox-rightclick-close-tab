# firefox-rightclick-close-tab

在 Firefox 的**标签栏上单击右键即可直接关闭该标签**，恢复 360 极速浏览器 / 傲游那类国产浏览器的习惯操作。

> Right-click a tab in Firefox's tab strip to close it instantly — no context menu, no extra click.
> Hold <kbd>Shift</kbd> to get the original tab context menu when you actually need it.

## 效果

| 操作 | 结果 |
| --- | --- |
| 标签栏上**右键单击** | 立即关闭该标签（不弹菜单） |
| **Shift + 右键** | 保留 Firefox 原生标签菜单 |
| 页面内容区域右键 | 完全不受影响 |
| 想临时关掉 | `about:config` → `tabutils.rightClickCloseTab` 设为 `false` |

## 为什么不用扩展

这不是偷懒，是 API 限制：

- Firefox WebExtensions 的 `browser.menus` 只能往右键菜单里**添加菜单项**，拿不到"标签栏被右键"这个事件本身，所以扩展最多做到"右键 → 再点一下菜单项"。
- Chrome 直到 150 才支持把 `"tab"` 作为 `contextMenus` 的上下文，同样只有"菜单项点击"，没有标签栏右键事件。
- 标签栏属于浏览器自身的 UI（XUL chrome），只有运行在 **chrome 权限**下的代码才能给它绑事件。扩展没有这个权限。

所以要"右键即关"，只能走 Firefox 的 **AutoConfig** 机制：在安装目录里放一个配置文件，让 Firefox 启动时以 chrome 权限执行一段脚本。

## 原理

```
/usr/lib/firefox/
├── defaults/pref/autoconfig.js   ← 启用 AutoConfig，指定要加载的文件名
└── tabutils.cfg                  ← 实际逻辑，chrome 权限
```

- `defaults/pref/autoconfig.js` 设置 `general.config.filename = tabutils.cfg`（路径相对于安装根目录）。
- `tabutils.cfg` 监听 `browser-delayed-startup-finished`，对每个窗口拿到 `#tabbrowser-tabs`，在捕获阶段挂一个 `contextmenu` 监听：
  - 命中 `<tab>` 元素 → `preventDefault()` + `gBrowser.removeTab()`
  - 按住 Shift → 直接 return，交还原生菜单
- 事件绑在每个 `<tabbrowser-tabs>` 上、而不是每个标签上，所以标签增删不影响，也不用反复重绑。

## 安装

### 方式一：脚本（推荐）

```bash
git clone <本仓库地址>
cd firefox-rightclick-close-tab
./install.sh              # 会自动 sudo
```

然后**完全退出 Firefox**（<kbd>Ctrl</kbd>+<kbd>Q</kbd>，确认进程已结束）再重新打开。

### 方式二：手动

```bash
sudo install -Dm644 files/autoconfig.js /usr/lib/firefox/defaults/pref/autoconfig.js
sudo install -Dm644 files/tabutils.cfg  /usr/lib/firefox/tabutils.cfg
```

> 装完第一次启动如果功能没生效，用一个全新实例验证一次：`firefox --headless --screenshot /tmp/t.png about:blank`，然后看 `/tmp/firefox-tabutils.log` 里有没有 `autoconfig loaded`。

## 验证

```bash
cat /tmp/firefox-tabutils.log
```

正常打开一个真实窗口后的输出：

```
2026-11-20T09:53:04.920Z  autoconfig loaded      ← autoconfig 被执行
2026-11-20T09:53:05.794Z  bound ok (window)      ← 标签栏事件绑定成功
2026-11-20T09:53:15.598Z  closed a tab           ← 每次右键关闭都会记一行
```

排错时注意两点：

- 只有 `autoconfig loaded`、没有 `bound ok`：说明脚本加载了但窗口绑定失败，多为 Firefox 大版本改了 `#tabbrowser-tabs` 结构。
- **一行都没有**：autoconfig 没被加载。检查 `autoconfig.js` 是否在 `defaults/pref/` 下、`tabutils.cfg` 是否在安装根目录、以及是否有另一个 `general.config.filename` 被更早的设置覆盖。
- `--headless` 启动只会有 `autoconfig loaded`（headless 不创建浏览器窗口，不触发 `browser-delayed-startup-finished`），别误判成失败。

脚本自检日志写在 `/tmp` 下，方便排查；不需要的话把 `tabutils.cfg` 里的 `LOG_PATH` 相关代码删掉即可（用 `try/catch` 包着，不写日志不影响功能）。

## 兼容性

| 环境 | 是否可用 | 说明 |
| --- | --- | --- |
| Mozilla 官方 deb（`packages.mozilla.org`） | ✅ | 本项目开发并验证的环境 |
| 发行版仓库的 `firefox-esr` / `firefox` | ✅ | 安装目录不同，`install.sh` 会自动探测 |
| 解压版（tarball） | ✅ | 需手动确认安装目录 |
| snap 版 | ❌ | `/snap` 只读，无法写入安装目录 |
| Flatpak 版 | ❌ | 应用目录不可直接改 |
| Windows / macOS | 原理相同 | 路径不同（Windows 在 `%ProgramFiles%\Mozilla Firefox\defaults\pref\`），本项目未提供脚本 |

## 已知限制

1. **升级可能覆盖 `defaults/pref/autoconfig.js`**。该目录属于包内文件，Mozilla 的 deb 更新有时会重写它（`tabutils.cfg` 在根目录，一般会保留）。升级后如果功能消失，重跑一次 `./install.sh` 即可。嫌麻烦可以观察一下，多数小版本升级不会动它。
2. **`general.config.sandbox_enabled` 被设为 `false`**。这是让 AutoConfig 能访问 chrome API 所必需的；它只影响这个本地文件，但确实降低了配置文件的隔离级别，请自行评估。如果你本来就有企业的 AutoConfig 策略，请先合并而不是覆盖。
3. AutoConfig 生效于**整个浏览器进程**，所有 profile 通用，与是否登录账号无关。

## 卸载

```bash
./uninstall.sh
```

或手动：

```bash
sudo rm -f /usr/lib/firefox/tabutils.cfg /usr/lib/firefox/defaults/pref/autoconfig.js
```

## 替代方案

如果你不想动安装目录，Firefox 原生还有两个接近的选项（`about:config`）：

- `browser.tabs.closeTabByDblclick` = `true`：双击标签关闭
- 中键单击标签：默认就能关

体感上双击和中键都比"右键即关"容易误触，所以才有这个项目。

## License

MIT
