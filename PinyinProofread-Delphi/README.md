# PinyinProofread-Delphi（HTML 拼音校对工具 · Delphi 12.2 移植版）

本目录是 `PinyinProofread-java` 的完整 Delphi 12.2 / VCL 移植版本，功能与原 Java（Swing）版一一对应，采用 MIT 授权协议。

## 功能（与原版一致）

- 校对 HTML 中形如 `<ruby>南<rt>ná</rt></ruby>` 的拼音注音。
- 将注音解析、分页，排成「上拼音、下汉字」的交错表格，便于逐字校对修改。
- 表格单元格可直接编辑；汉字单元格限制为 1 个字符。
- 「突出字符集」：输入若干字符后，含这些字的单元格以红色显示，方便重点复核。
- 内置 2042 个汉语拼音音节 MP3，「播放（Ctrl+P）」按当前选中位置顺序朗读，可暂停、自动翻页。
- 翻页：Alt+← 上一页、Alt+→ 下一页；保存：Ctrl+S。
- 每个文件的上次阅读页码记录到 `records.txt`，下次打开自动定位。
- 内置标准注音字体（PMingLiU 显示汉字、GB Pinyinok-C 显示拼音）。
- 窗口固定占据屏幕右半边，与原版布局一致。

## 目录结构

```
PinyinProofread-Delphi/
├─ PinyinProofread.dpr        # 工程主文件
├─ PinyinProofread.dproj      # Delphi 12.2 工程文件（IDE 可直接打开）
├─ PinyinProofread.rc/.res    # 图标资源
├─ src/
│  ├─ uState.pas              # 共享状态（对应 Main 的静态字段、contents、alerts）
│  ├─ uRecord.pas             # 页码记录（对应 Record.java）
│  ├─ uFileProcessor.pas      # HTML 解析/分页/保存（对应 FileProcessor.java）
│  ├─ uAudio.pas              # 朗读线程与 MCI 播放（对应 Audio.java）
│  ├─ uMain.pas / uMain.dfm   # 主窗体 UI（对应 Main.java）
├─ res/
│  ├─ fonts/                  # PMingLiU.ttf、GB Pinyinok-C.ttf
│  ├─ yinjies/                # 2042 个拼音音节 MP3
│  ├─ icon-proofread.png      # 原 PNG 图标
│  └─ app-icon.ico            # 程序 ICO 图标
└─ samples/                   # 原项目自带的示例 HTML
```

## 编译与运行

1. 用 Delphi 12.2（RAD Studio 12.2 Athens）打开 `PinyinProofread.dproj`，按 F9 编译运行。
2. 或命令行编译（Win32）：

```
dcc32 -B -U"src" PinyinProofread.dpr
```

编译产物 `PinyinProofread.exe` 需与 `res\` 目录放在同一目录（工程默认输出已设为根目录），运行时按相对路径加载字体与音频。

## 键位对照

| 功能 | 快捷键 |
|------|--------|
| 保存 | Ctrl+S |
| 播放/暂停 | Ctrl+P |
| 上一页 | Alt+← |
| 下一页 | Alt+→ |
| 编辑单元格 | 双击或直接键入 |

## 与原 Java 版的对应关系

| Java | Delphi |
|------|--------|
| `Main.java` | `uMain.pas` + `uState.pas` |
| `FileProcessor.java` | `uFileProcessor.pas` |
| `Audio.java`（jaco MP3 Player） | `uAudio.pas`（Windows MCI，功能等价） |
| `Record.java` | `uRecord.pas` |
| `FontDesignMetrics` | VCL `TCanvas.TextHeight/TextWidth` |
| `Font.createFont` (TTF) | Windows GDI `AddFontResourceEx(FR_PRIVATE)` |
| `JTable` 自定义单元格渲染/编辑 | `TStringGrid.OnDrawCell` + 覆盖式 `TEdit` |

说明：Java 版用第三方 jaco-mp3-player 解码 MP3，Delphi 版改用 Windows 自带的 MCI（`mciSendString`）播放，均为逐音节同步朗读 + 25ms 轮询，行为一致，且不引入外部 DLL 依赖。
