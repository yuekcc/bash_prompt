# bash_prompt

一个简单的 Bash pormpt 程序。支持特性：

- 显示当前目录
- 如果当前目录是 git 仓库，则显示当前的分支及是否有未 commit 的变更。

效果：

```sh
D:\demo_project @ master*
$ 
```
## 构建

需要 zig 0.10+。构建过程：

```sh
zig build -Drelease-safe
```

在 `zig-out/bin` 可以找到相应的 bin 文件。

## 使用

首先将 `bash_prompt.exe` 放入系统 PATH 目录中。然后在 `.bashrc` 中增加这些配置：

```sh
PROMPT_COMMAND="bash_prompt.exe"
export PROMPT_COMMAND
PS1="\$ "
```

`bash_prompt.exe` 可以在 release 页面中找到。

## License

MIT
