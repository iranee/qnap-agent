# 定时心跳巡检任务

每次心跳触发时，依次执行以下检查。发现问题时通过已配置的渠道通知用户。

## 1. 磁盘空间检查

执行 `df -h /share/` 检查各卷使用率。
- 使用率 > 85%：发送警告通知
- 使用率 > 95%：发送紧急通知，提示用户立即清理
- 记录检查结果到 memory/heartbeat-disk.md

## 2. Docker 容器状态检查

执行 `docker ps -a --format "{{.Names}}\t{{.Status}}"` 检查所有容器。
- 发现 "Exited" 状态的容器：记录容器名称，查询是否正常（用户配置的永久停止容器除外）
- 发现 "Restarting" 状态：立即通知，该容器可能存在故障
- 将结果追加到 memory/heartbeat-docker.md

## 3. 系统内存检查

执行 `free -m` 查看内存使用情况。
- 可用内存 < 200MB：发送警告
- 记录到 memory/heartbeat-memory.md

## 4. 系统日志异常扫描

检查 `/var/log/messages` 或 `dmesg` 最近 100 行，查找关键字：
`error`, `fail`, `panic`, `critical`, `oom`
发现异常时摘录并通知用户。

## 5. 更新 agent 运行状态

将心跳时间戳写入 state/last_heartbeat.txt
格式：`yyyy-mm-dd HH:MM:SS`

---

*心跳间隔由 config.json heartbeat.interval 控制（默认 1800 秒 = 30 分钟）*
