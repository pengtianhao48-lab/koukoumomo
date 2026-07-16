# 抠抠摸摸 · KouKouMoMo

一款「不用看屏幕」的电子解压玩具。闭着眼、一根手指、屏幕中央、无限循环。

- **Bundle ID**: `com.pth.koukoumomo`
- **最低系统**: iOS 17
- **技术栈**: SwiftUI · Swift 5 · MVVM · 零依赖 · 无网络
- **本地化**: English (default) · 简体中文（跟随系统语言）
- **视觉**: 米白纸底 + 炭黑手绘线条 + 极轻淡彩点缀（blush / sunshine / sky / mint）

## v1 重写要点

第一版把「六个玩法」画成了组件式进度环，被否掉了。v1（本版本）从零重写，核心变化：

- 每个玩法都是一幅**会动的手绘涂鸦插画**（Canvas + Path + 抖动线条 + TimelineView 帧驱动），不再是进度环。
- 首页 6 个卡片是**同一涂鸦的静态预览**，点击后 `NavigationStack` 全屏推入。
- 全局只有两种颜色：`ink`（近黑 `#1A1917`）+ `paper`（米白 `#FAF6EE`），加 4 个淡色点缀。
- 所有描边都走 `Rough` 模块（deterministic sine-hash 噪声）→ 每条线都有轻微抖动，但每次重绘完全一致，不会闪烁。

## 六个玩法 · 关键帧动画

### ① 抠鼻孔 NoseDoodle
- **Idle**：大圆脸 · 两颗豆眼 · 两道眉毛 · 大鼻子 + 两个鼻孔（黑色小椭圆）· 小小的嘴巴。
- **Progress 0.0→0.3**：右鼻孔内出现一个小黄色团子并开始绕圈；眉毛稍微下沉。
- **Progress 0.3→0.7**：团子长大、旋转半径变大；两道眉毛内八夹紧（愁眉）。
- **Progress 0.7→1.0**：团子几乎撑满鼻孔；嘴角开始上翘。
- **Completion**：黄色团子被"啵"地弹出鼻孔外上方，周围三条小炸线；嘴巴瞬间变宽笑。
- **Reset**：团子消失，回到 Idle。

### ② 抠肚脐 NavelDoodle
- **Idle**：软软的圆润肚皮 · 中间一个圆形肚脐（黑边）· 顶部两个虚肉点（胸廓提示）。
- **Progress 递增**：肚脐内部出现越来越多的月牙形凹陷线（1 → 2 → 3 → 4 圈），线条越深；外圈同心晕线渐显；一颗小圆点持续绕肚脐轨道运动（提示"你在抠"）。
- **Completion**：黄色光晕从肚脐向外扩散一圈；八条放射短线弹出（✨ 感）。
- **Reset**：凹陷线数量回到 1 圈。

### ③ 摸耳垂 EarDoodle
- **Idle**：左侧下颌淡淡的一条侧脸线 · 中间大耳廓（外壳 + 内耳廓 + tragus 小勾）· 下面挂一个白色耳垂 + 黑色小耳钉。
- **Progress 递增**：耳垂 fill 从白色渐变到 blush 粉红（`α` 0.15 → 0.80）。
- **Axis（上下滑）**：耳垂 y 位置随 axis 上下偏移，配合正弦 bounce 得到"Q 弹晃动"。
- **Velocity 高**：耳垂两侧出现 3 条外扩短"boing"线。
- **Completion**：耳垂持续偏红 + 满级 boing。
- **Reset**：颜色渐退。

### ④ 咬手指 FingerDoodle
- **Idle**：中央大椭圆嘴 · 内里深色口腔 · 上下各 6 颗小三角牙齿 · 一根从下方伸入嘴中的圆头手指。
- **Progress 递增（axis 左右滑）**：上下牙齿以 `sin(time * 8 + axis * 2)` 的节拍咬合（gap 10~32pt 波动）；手指 x 位置随 axis 微微左右晃 + 正弦抖动。
- **Completion**：黄色糖纸样小物件（椭圆 + 两侧扭结）从嘴角右上方飞出，下方跟一段两次弯的运动曲线 → 明显的"吐出来"感。
- **Reset**：糖纸消失。

### ⑤ 压泡泡纸 BubblesDoodle
- **Idle**：全屏 5×6 = 30 个手绘泡泡网格，每颗都是抖动椭圆边线。
- **Center 活跃泡**：加粗边线 + 内部 sky 蓝色 fill + 一颗白色高光点，明显区别于其他。
- **每次 Tap**：活跃泡沿一个曲线做「捏扁 → 消失 → 从零重新长回」的循环（0.42s）：
  - 0 → 0.35s：scale 1 → 0，opacity 1 → 0（压瘪）
  - 0.35 → 0.42s：新的泡泡以 g * (1 + 0.15·sin(2πg)) 弹性生长回到全尺寸
  - 同时六条外扩短线以「pop!」效果散开
- **其他泡泡**：以 `sin(time * 1.4 + seed * 0.7) * 0.03` 微微呼吸，画面永远在动。
- **无限循环**，用户永远只点屏幕中央。

### ⑥ 转笔 PenDoodle
- **Idle**：一支水平躺着的手绘钢笔，笔身是圆角矩形（paper 底 + 黑边），右侧黑色笔帽 + 金属笔夹小折线；左端三角笔尖；中段一节 mint 绿色装饰环。
- **Angular integration**：`PenSpinState` 存储 `angle` 与 `flourishRemaining`，通过 TimelineView 每帧 `tick(dt, axis, progress, velocity, completionTick)` 累积角度：
  - `axisDeg = axis * 40`（拖拽方向瞬时冲力）
  - `ambientDeg = progress * 260`（进度越高越持续旋转）
  - `angle += (axisDeg + ambientDeg) * dt * 3`
- **Trail arcs**：velocity > 0.05 时后方出现 4 条抖动弧线残影，越 velocity 越浓。
- **Completion**：`flourishRemaining = 720`，之后以 1400°/s 消耗 → 快速两周花式旋转，然后回到常态。
- 中心黑色小 pivot 点始终标记轴心。

## 工程结构

```
KouKouMoMo/
├── App/KouKouMoMoApp.swift            @main · 直接 HomeView
├── Home/
│   ├── HomeView.swift                 首页 2×3 卡片网格
│   └── PlayMode.swift                 玩法枚举 + gesture / accent / completion 文案
├── Game/
│   ├── GameContainerView.swift        全屏 · 涂鸦居中 · 关闭按钮 · 提示文字 · CompletionBanner
│   ├── GamePhase.swift                统一 6 态状态机
│   ├── ToyViewModel.swift             MVVM VM · 消费 GestureProgressEvent
│   └── Doodles/                       6 个 Canvas 涂鸦（都含 Thumbnail 静态预览）
│       ├── NoseDoodle.swift
│       ├── NavelDoodle.swift
│       ├── EarDoodle.swift
│       ├── FingerDoodle.swift
│       ├── BubblesDoodle.swift
│       └── PenDoodle.swift
├── GestureEngine/
│   ├── GestureEngine.swift            5 kind → Progress(0~1) + velocity + axis
│   └── GestureSurface.swift           Drag + Tap 覆盖全屏
├── Haptics/HapticManager.swift        UIImpact / UINotification · 节流
├── Components/
│   ├── DoodleCloseButton.swift        手绘 × 按钮
│   └── CompletionBanner.swift         手绘"pop!" / "舒服～" 徽标
├── Utils/
│   ├── DoodleStyle.swift              颜色 / 字体 / stroke 预设
│   ├── Rough.swift                    handdrawn Path 工具（line/ellipse/arc/roundedRect + noise）
│   └── Extensions.swift               clamped
└── Assets/
    ├── Assets.xcassets                (AppIcon + AccentColor · 无插画 PNG)
    ├── Localizable.xcstrings          en + zh-Hans（27 条）
    └── InfoPlist.xcstrings            CFBundleDisplayName（en/zh-Hans）
```

## 核心设计约束（严格遵守）

- ✅ 一根手指 · 屏幕中央 · 不寻找目标 · 不看屏幕 · 无限循环
- ✅ 每次反馈循环 2~5s
- ✅ 所有动画 200~400ms Spring
- ✅ 手绘线条 stroke 1.6~2.8pt · `.round` 端点
- ✅ 全屏只有一个 × 按钮

- ❌ 广告 / 内购 / 排行榜 / 分数 / 账户 / 网络 / 教程 / 设置页
- ❌ 长按 / 多指 / 缩放 / 拖动物体 / 瞄准 / 快速反应 / 计时挑战
- ❌ 二次元 / 游戏感 / 儿童卡通 / 粒子炫技

## 运行

Xcode 15.4+ → 打开 `KouKouMoMo.xcodeproj` → Run。Signing = Automatic，无第三方依赖。

—— 抠抠摸摸 v1 · 2026
