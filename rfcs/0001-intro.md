- date: 2022-10-19
- title: RFC-0001

## 概要

prompt 即命令行提示符。bash_prompt 即提示符的自定义程序。

## 背景

BASH 支持通过 `PS1` 环境变更实现自定义提示符。但在本实现中，先通过 `PROMPT_COMMAND` 环境指定提示符程序，再配合 `PS1` 最终得到自定义的提示符。

现有的提示符实现，如 starship。starship 支持非常多的自定义功能，也支持展示 git 仓库状态。但是 starship 程序体积比较大，而且配置也比较复杂。多主机之间同步配置需要进行多个文件的复制。如果配置发生变更，则只能逐个主机进行配置。因此希望通过自定义的软件来实现多主机共享的提示符。

## 详细设计

所谓自定义提示符，实际是一处向 stdout 写入一个或多行文本的程序。因此支持自定义提示符的 shell 也应该支持。考虑到实际使用场景和展示需求。列出如下功能点：

- 支持 Linux/Windows 系统
- 支持 Bash
- 支持展示当前目录
- 支持展示 GIT 仓库状态——当前分支、是否有未提交的变更
- 提示符支持色彩

### 当前目录

对于当前目录，CLI 程序在启动时即可获得。zig 中可以通过 `process.getCwdAlloc`。

### GIT 仓库状态

zig 因为没有包管理软件，libgit2 的绑定未能在 windows 平台上编译通过。因此需要只能使用 cli wrapper 方式，调用 git 程序来获取仓库状态。这些涉及几个问题：

1. 判断当前目录是否在 git 仓库中？可以通过向上查找 `.git` 目录来获取仓库根目录。一般情况下都比较准确。
2. 包装 git 程序？zig 通过 `std.ChildProcess` 对象实现，然后在代码中解析返回值来获取结果。

git 仓库状态对应两项数据：

1. 当前在哪个分支，对应 `git rev-parse --abbrev-ref HEAD` 命令。
2. 是否有变更，对应 `git status --porcelain` 命令。

展示时，使用如 `master*` 方式来提示。`master` 是分支名称，未创建分支时展示为 `HEAD`；`*` 表示仓库中存在未提示的变更，没有变更时，不展示。__如果不是 git 仓库，都不展示。__

### 内部设计

zig 需要人工设置内存分配器。使用 `std.heap.GeneralPurposeAllocator` 作为基本内存分配器。

Git 操作包装为一个 Repo 对象。Repo 对象在 init 传入基本内存分配，然后在内部创建一个 `std.heap.ArenaAllocator` 分配器用于内部各方法分配内存使用。ArenaAllocator 的好处是通过 Repo.deinit 来统一回收内存。git 命令最终是通过 `gitInDir` 函数来执行，gitInDir 也需要传入一个 `std.heap.ArenaAllocator` 用于内存管理。

TBD
