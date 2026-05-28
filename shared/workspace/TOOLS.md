# QNAP Agent Tools

本文件描述 QNAP Agent 在当前设备侧可调用的主要工具类别。

## 内置命令

- `/sbin/getcfg`
- `docker`
- `df`
- `du`
- `ip`
- `ps`
- `free`
- `uptime`

## QNAP 专有工具

- `/usr/local/cayin/bin/ffmpeg`
- `/usr/local/cayin/bin/ffprobe`

## 本地辅助目录

- `skills/`：本地技能包
- `memory/`：长期记忆与系统快照
- `state/`：状态标记

更多限制和允许项以 `config.json` 中的工具配置为准。
