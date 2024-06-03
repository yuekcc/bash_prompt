# bash_prompt

一个简单的 Bash pormpt 程序。支持特性：

- 显示当前目录
  - 支持缩略显示方式（_开头正常显示，中间目录只取首字，最后目录完整显示_）
- 如果当前目录是 git 仓库，则显示当前的分支及是否有未 commit 的变更

效果：

![screenshot](screen.png)

## 构建

构建需要 [0.13.0-dev.351+64ef45eb0](https://machengine.org/about/nominated-zig/)。

构建过程：

```sh
rm -rf zig-cache zig-out
zig build --release=fast
```

在 `zig-out/bin` 可以找到相应的 bin 文件。

## 使用

首先将 `bash_prompt` 放入系统 PATH 目录中。然后在命令行中执行：

命令行开关：

- `bash_prompt init`: 生成 bash 配置。可以使用 `bash_prompt init >> ~/.bashrc` 增加到 `~/.bashrc`
- `bash_prompt short`: 使用缩略路径

## License

MIT
