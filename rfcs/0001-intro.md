- date: 2022-10-19
- title: RFC-0001

## 概要

prompt 即命令行提示符，bash_prompt 是一个自定义提示符的程序。

## 背景

BASH 可以通过 `PS1` 环境变量自定义提示符，也支持通过设置 `PROMPT_COMMAND` 变量，执行指定的 CLI 程序并将期打印到 `stdout` 的输出作为提示符。因此 bash_prompt 需要设置 `PROMPT_COMMAND` 和 `PS1`。

现有的提示符 CLI 程序有 [starship]、[oh-my-posh] 等。这些都是可以配置为似乎 power-line 的效果。观察 startship 和 oh-my-posh，前者使用 rust 实现，后者使用 go 实现。一是体积比较大，二是功能多，三是配置也复杂。虽然 starship 提供了类似 preset 这种推荐配置，但是在多个系统之间都需要重复配置。

我所期望的 prompt 应该是可以非常简单地使用，而且并不需要对 prompt 本身进行配置。考虑到日常的使用场景。prompt 程序，我只需要实现两个功能：

- 显示当前目录
- 显示 GIT 仓库状态

事实上，git for windows 的 bash 就是这样设置的。我感觉非常实用。

[oh-my-posh]: https://github.com/jandedobbeleer/oh-my-posh
[starship]: https://github.com/starship/starship

## 详细设计

所谓自定义提示符，实际是一个向 `stdout` 写入一个或多行文本的 CLI 程序。理论上支持自定义提示符的 shell 都应该支持。结合平时工作的需要，我期望这个 prompt 可以实现这些功能：

- 支持 Linux/Windows 系统
- 支持 Bash
- 支持展示当前目录
- 支持展示 GIT 仓库状态——当前分支、是否有未提交的变更
- 提示符支持色彩

### 多系统支持

因为是使用 zig 实现，zig 本身就支持多系统。对于 linux 系统也可以采用静态连接到 musl libc 的方法实现对 libc 版本的无依赖。当然只需要更大的占地面积。

### 当前目录

对于当前目录，CLI 程序在启动时即可获得。zig 中可以通过 `std.process.getCwdAlloc` 实现。

### GIT 仓库状态

zig 因为没有包管理软件，libgit2 的绑定未能在 windows 平台上编译通过。因此需要使用 cli wrapper 方式调用 git 程序来获取仓库状态。这里就涉及几个问题：

1. 判断当前目录是否在 git 仓库中？可以通过向上查找 `.git` 目录来获取仓库根目录。一般情况下都比较准确。
2. 如何包装 git 程序？zig 通过 `std.ChildProcess` 对象实现，然后在代码中解析返回值来获取结果。

git 仓库状态分别对应两项数据：

1. 当前在哪个分支，通过 `git rev-parse --abbrev-ref HEAD` 命令获取。
2. 是否有变更，通过 `git status --porcelain` 命令获取。

展示时，使用如 `master*` 方式来提示。`master` 是分支名称，未创建分支时展示为 `HEAD`；`*` 表示仓库中存在未提示的变更，没有变更时，不展示。__如果不是 git 仓库，则都不展示。__

比如在普通目录：

```cmd
D:\feng\app\zig
$
```

在 git 仓库目录：

```cmd
D:\feng\projects\bash_prompt @ main*
$
```

## 内部设计

实现上分三个模块：

1. 样式控制
2. git 包装
3. 入口

### 样式控制

样式在这里主要就是颜色控制。terminal 有一个标准色体系，主要是通过控制字符要修改文字的样式。样式包括颜色、位置、字体样式等。由开始字符到结束字符来控制样式，类似于 HTML。开始为 `\x1B[??????m`，结束字符为 `\x1B[0m`。

如果要将 `Some Text` 展示为红色文字，可以设置为：`\x1B[31mSome Text\x1B0m`。[Terminal Colors] 文章有相关的介绍。

[Terminal Colors]: https://chrisyeh96.github.io/2020/03/28/terminal-colors.html

代码中通过 `comptime` 在编译期直接计算出样式：

```zig
const CSI = "\x1B[";

comptime var fg_red = fmt.comptimePrint(CSI ++ "{d}m", .{31});
```

### git 包装

参考 [git_cmd] 实现。仓库抽象为一个 `Repo` 对象，对象内部通过 `dir` 字段保存仓库的根目录路径。在调用 git 命令时，通过 `-C` 参数，让 git 总是在仓库根路径执行。在仓库根路径执行可以减少很多的路径计算问题。

获取当前分支由 `Repo#getCurrentBranch` 实现；获取当前是否有变更则通过 `Repo#getChanges` 实现，`Repo#getChanges` 方法返回一个字符串数组，包含变更的文件路径。

git 命令由 `gitInDir` 函数实现。函数签名：

```zig
gitInDir(arena: *std.heap.ArenaAllocator, dir: []const u8, argv: []const []const u8) !std.ChildProcess.ExecResult
```

zig 没有全局的内存分配器，一般是将内存分配器作为参数传入函数中。这里使用 `std.heap.ArenaAllocator` 分配器，一是 `ExecResult` 内部发生了多次内存分配，而且外部不能直接释放内存，使用 `ArenaAllocator` 可以在使用完后一次性释放相关的内存，方便管理。

对于 Repo 对象，调用栈是这样：`repo -> #getChanges -> gitInDir`。因此 `ArenaAllocator` 也作为 Repo 对象的字段。

另外 git 仓库的根路径是一个向上查找的过程。因为需要手工管理内存，尽量使用循环实现。

[git_cmd]: https://github.com/MarcoIeni/release-plz/tree/main/crates/git_cmd

### 入口

zig 程序的入口是 `fn main()` 函数。main 函数的主要功能是向 stdout 写入数据，通过使用 `bufferedWriter` 实现缓冲的写入。

## 未解决的问题

1. ~~starship 是通过在 .bashrc 执行 `eval $(starship env bash)` 来简化配置，这点目前没有实现。~~ - 通过命令行参数 `bash_prompt init` 来生成 bash 配置。
2. zig 对于部分字符的输出有 bug（似乎只在 windows 平台有问题）。比如输入 `§` 在 windows 上，显示为 `搂`。

## 其他

TBA
