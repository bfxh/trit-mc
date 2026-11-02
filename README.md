# trit-mc

trit-agent 的 **Minecraft 侧**：数据包、起源包、构建与诊断脚本。

Rust 状态机在另一个仓库 → **[bfxh/trit-agent](https://github.com/bfxh/trit-agent)**

```
Minecraft 侧（本仓库）              Rust 侧（trit-agent）
datapacks/  ← 数据包源码      ←→   src/perceive/  ← 传感器解析器
scripts/    ← 打包/诊断                ↑
                                    协议字段名单（唯一事实来源）
```

两个仓库通过**一条契约**咬合：传感器协议。
数据包往聊天栏打 `<TRIT hp=... food=...>`，Rust 侧从 `logs/latest.log` 读回来。

---

## 这里有什么

| 路径 | 内容 |
|---|---|
| `datapacks/squad/` | 傀儡/狼的指挥包（`/function squad:engage` 等 4 个意图） |
| `datapacks/trit_bridge/` | **传感器包**：把游戏状态写进聊天栏，供外部程序读日志 |
| `archive/origins/` | 起源包（召唤师 / NPC 能力 / 全部汉化），**已隔离**，不随状态机打包 |
| `scripts/` | 打包、装包、诊断、崩溃分析 |

---

## 快速开始

```bash
# 1. 打包（产物在 dist/）
python scripts/build_datapacks.py

# 2. 装进 Minecraft 实例（每个存档都要装）
python scripts/build_datapacks.py --install "E:/MC/MC/profiles/烦人的村民"

# 3. 一条命令自检（7 项）
python scripts/check_env.py
```

---

## 关键概念

### 两条通道

| 通道 | 前缀 | 频率 | 内容 |
|---|---|---|---|
| 慢 | `<TRIT ` | 1 秒 | 血量、饥饿、坐标、敌人数、距离档、危险档、木/矿档、时间、视角 |
| 快 | `<TRITF ` | 100ms | 墙体掩码、准星方块、脚下方块、台阶 |

快通道**不含血量**（瞄准时不需要），慢通道**必须含血量**（否则无法判断这是不是传感器行）。

### 协议是跨仓库契约

字段名单由 **Rust 代码**维护（`perceive::PROTOCOL_FIELDS`），不在本仓库手写第二份 ——
手写名单会跟代码脱节，改名时两边一起过时，检查反而变成「两边都错所以通过」。

Rust 侧有测试盯着「名单和解析器分支逐字一致」。本仓库的校验器通过
`trit-agent protocol --json` 拿名单：

```bash
trit-agent protocol --json
# ["hp","food","x","y","z","h","d","c","w","wd","o","od","t","p","wal","b1","bd","s"]
```

拼错一个字母的后果是**静默**的：Rust 侧当「这条通道没报这个量」，少一个感知量但不报错。
所以校验器必须能拿到真实名单 —— 拿不到时它会**显式报告「跳过」**，不会假装通过。

---

## 脚本

| 脚本 | 干什么 |
|---|---|
| `build_datapacks.py` | 打包 + 校验 + 装进实例。`--selftest` 只验证校验器本身 |
| `check_env.py` | 一键自检 7 项：AI 本体 / 存档数据包 / 传感器 / 模组标签 / 协议 / rrls |
| `make_trit_bridge.py` | 生成传感器包（`trit_bridge`） |
| `save_packs.py` | 查/改存档的数据包启用列表（`level.dat` 的 `DataPacks.Enabled`） |
| `fix_world.py` | 一键让数据包在**当前打开的世界**里真正生效 |
| `watch_sensor.py` | 实时盯传感器，日志里出现 `<TRIT ` 就报「活了」 |
| `diagnose_crash.py` | 崩溃一键诊断：崩溃点、mod 名单、**AI 那几秒干了什么** |
| `toggle_rrls.py` | 禁用/恢复 `rrls`（崩溃真凶，见下） |

### 「拷进去 ≠ 装上了」

这是 MC 侧最大的坑，脚本存在的理由：

1. zip 拷进 `saves/<世界>/datapacks/` **不等于**启用。MC 只加载 `level.dat` 里
   `DataPacks.Enabled` 列出的条目
2. 新建世界的 `saves/<新世界>/datapacks/` 是空目录
3. `data modify ... set` 只写**已存在**的路径 —— 新生实体的 NBT 里没有 `AngryAt`，
   命令被**静默拒绝**：不报错、不写日志、聊天栏也没提示

`fix_world.py` 一把解决这些。

---

## 崩溃真凶：rrls

整合包「The Annoying Villagers」自带的 `rrls`（Remove Reloading Screen，作者 dimadencep）
会崩游戏 —— 崩在 `Minecraft.handleKeybinds`，**NullPointerException**。

**不是渲染引擎的问题**，跟 GPU / 驱动 / 光影 / 材质无关。

原因：它用 mixin 的 `@Redirect` 劫持了 `Minecraft.overlay` 字段读取，加载界面还挂着时
返回 `null`，把原版「现在该不该处理按键」的判断**反转**了：

```
正常：  加载界面挂着 -> overlay != null -> 跳过 handleKeybinds
有 rrls：加载界面挂着 -> overlay == null -> 照样跑 handleKeybinds
                                        -> player 还是 null -> NPE
```

`config/rrls.toml` 里的 `enabled = false` **没用** —— 那是配置项，管不到 mixin 注入。
唯一可靠的办法是不让这个 jar 被 Forge 加载：

```bash
python scripts/toggle_rrls.py status    # 查看
python scripts/toggle_rrls.py disable   # 禁用（防崩溃）
python scripts/toggle_rrls.py enable    # 恢复
```

代价只是加载/资源重载时会短暂显示原版进度条界面。

---

## 和 Rust 侧的配合

| Rust 侧要什么 | 本仓库提供什么 |
|---|---|
| `logs/latest.log` 里的传感器行 | `trit_bridge` 包往聊天栏打的 `<TRIT ...>` |
| `/function squad:engage` 等指令 | `squad` 包 |
| 协议字段名单 | `trit-agent protocol --json`（Rust 自己导出） |

Rust 侧的按键注入走 `SendInput`，**不需要给游戏装任何 mod**。
本仓库的数据包是**可选**的增强（没有它就没有传感器感知，只有盲操作）。

---

## 许可

见 LICENSE。
