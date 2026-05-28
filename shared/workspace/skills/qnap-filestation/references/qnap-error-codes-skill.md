# File Station API 状态码完整参考

以下是 QNAP File Station API 返回的所有 status code 及其含义。

**注意**：File Station API 和 DLNA/多媒体服务各自有独立的状态码体系，不可混用。
- File Station 主状态码（status 0-109）：用于所有文件管理操作（删除、复制、移动、搜索等）
- DLNA 专用状态码（status 1-13）：仅用于 DMC 播放控制操作（dmc_play、dmc_stop 等）

---

## File Station 主状态码（文件管理操作）

| status | 枚举名 | 中文说明 |
|--------|--------|----------|
| 0 | UNKNOW | 未知错误 |
| 1 | WFM2_SUCCESS | 成功 |
| 2 | WFM2_FILE_EXIST | 文件/文件夹已存在 |
| 3 | WFM2_AUTH_FAIL | 认证失败 |
| 4 | WFM2_PERMISSION_DENY | 权限不足，存取拒绝 |
| 5 | WFM2_FILE_NO_EXIST | 文件/文件夹不存在 |
| 6 | WFM2_EXTRACTING | 文件正在解压中 |
| 7 | WFM2_OPEN_FILE_FAIL | 文件 IO 错误，写入时发生错误 |
| 8 | WFM2_DISABLE | Web File Manager 未启用 |
| 9 | WFM2_QUOTA_ERROR | 磁盘配额已满 |
| 10 | WFM2_NEED_CHECK | 没有权限执行此操作 |
| 11 | WFM2_NEED_CHECK | 没有权限执行此操作 |
| 12 | WFM2_ILLEGAL_NAME | 名称不合法（含有非法字符： " + = / \\ : | * ? <> ; [] % , ` ' 或特殊前缀 "_sn_" 和 "_sn_bk"） |
| 13 | WFM2_EXCEED_ISO_MAX | ISO 分享数量已达最大值 256，请先卸载一个 ISO 分享 |
| 14 | WFM2_EXCEED_SHARE_MAX | 分享数目已达最大限制 |
| 15 | WFM2_DEMO_SITE | 登录失败 |
| 16 | WFM2_RECYCLE_BIN_NOT_ENABLE | 回收站未启用 |
| 17 | WFM2_CHECK_PASSWORD_FAIL | 请输入密码 |
| 18 | WFM2_DB_FAIL | 媒体库未启动 |
| 19 | WFM2_DB_QUERY_FAIL | 系统忙碌中，请再试一次 |
| 20 | WFM2_VIDEO_TCS_DISABLE | 输入有误，请再试一次 |
| 21 | WFM2_DEMO_SITE | 演示站点 |
| 22 | WFM2_TRANSCODE_ONGOING | 文件正在转档中 |
| 23 | WFM2_SRC_VOLUME_ERROR | 资料来源读取异常，请检查资料来源后再试一次 |
| 24 | WFM2_PARAMETER_ERROR | 目标目的地写入异常，请检查后再试一次 |
| 25 | WFM2_DES_FILE_NO_EXIST | 目标目的地路径不存在，请检查后再试一次 |
| 26 | WFM2_FILE_NAME_TOO_LONG | 文件名太长（最大 255 字符，英文） |
| 27 | WFM2_FOLDER_ENCRYPTION | 文件夹已加密，请先解密 |
| 28 | WFM2_PREPARE | 任务进行中，请稍等 |
| 29 | WFM2_NO_SUPPORT_MEDIA | 不支持开启这类格式 |
| 30 | WFM2_DLNA_QDMS_DISABLE | 请先启动 DLNA Media Server |
| 31 | WFM2_RENDER_NOT_FOUND | 目前找不到任何可用的播放装置 |
| 32 | WFM2_CLOUD_SERVER_ERROR | SmartLink 服务忙碌中，请再试一次 |
| 33 | WFM2_NAME_DUP | 文件夹或文件名称已存在，请使用其他名称 |
| 34 | WFM2_EXCEED_SEARCH_MAX | 搜寻结果超过 1000 笔 |
| 35 | WFM2_MEMORY_ERROR | 记忆体不足分配错误 |
| 36 | WFM2_COMPRESSING | 文件压缩中 |
| 37 | WFM2_EXCEED_DAV_MAX | （保留） |
| 38 | WFM2_UMOUNT_FAIL | 取消挂载失败 |
| 39 | WFM2_MOUNT_FAIL | 挂载失败 |
| 40 | WFM2_REMOTE_FOLDER_ACCOUNT_PASSWD_ERROR | 远端挂载帐号密码错误 |
| 41 | WFM2_REMOTE_FOLDER_SSL_ERROR | 凭证不被信任，SSL 错误 |
| 42 | WFM2_REMOTE_FOLDER_REMOUNT_ERROR | 远端资料夹重新挂载失败 |
| 43 | WFM2_REMOTE_FOLDER_HOST_ERROR | 找不到主机，远端主机连线失败 |
| 44 | WFM2_REMOTE_FOLDER_TIMEOUT_ERROR | 远端主机连线超时失败 |
| 45 | WFM2_REMOTE_FOLDER_CONF_ERROR | 远端主机连线资料不正确 |
| 46 | WFM2_REMOTE_FOLDER_QUOTA_OR_PERMISSION_ERROR | 远端连线 quota 错误或者无权限无法写入资料 |
| 47 | WFM2_QCLOUD_ALIAS_TOOL_ERROR | （保留） |
| 48 | WFM2_REMOTE_FOLDER_FTPFS_BASE_ERROR | 远端连线失败 |
| 49 | WFM2_EXCEED_TREE_NODE_MAX | （保留） |
| 50 | WFM2_EXCEED_FILE_LIST_MAX | （保留） |
| 51 | WFM2_REMOTE_FOLDER_CONF_ERROR | （保留） |
| 52 | WFM2_AT_LEAST_ONE_FILE_ACCESS_ERR | 至少有一个档案存取错误 |
| 55 | WFM2_DEST_PATH_IS_CHILD_OF_SRC | 目的端是来源端的子资料夹 |
| 56 | WFM2_REMOTE_FOLDER_MOUNT_READ_ONLY | 远端资料夹同步失败 |
| 57 | WFM2_SHARE_LINK_EXPIRED | Share link 已过期 |
| 58 | WFM2_ADD_TRANSCODE_FAIL | 影片加入转档时发生错误 |
| 59 | WFM2_DELETE_TRANSCODE_FAIL | 取消/删除影片转档时发生错误 |
| 60 | WFM2_CHARSET_CONV_FAIL | 储存文字档编码时发生错误 |
| 61 | WFM2_FILE_TOO_LARGE | 开启的文字档超过 10M |
| 62 | WFM2_TEXT_FILE_CHANGED | 文字档已被修改过 |
| 63 | WFM2_DELETE_FILE_FAIL | 删除档案失败 |
| 64 | WFM2_REMOTE_LOGIN_FAIL | 登入远端 QNAP NAS 失败 |
| 65 | WFM2_GEN_THUMBNAIL | 产生缩图中 |
| 66 | WFM2_EJECT_EXTERNAL_DEV_FAIL | 退出外接装置失败 |
| 67 | WFM2_SEARCH_RESULT_FAIL | 搜寻失败 |
| 68 | WFM2_QCLOUD_WOPI_TOOL_ERROR | Office online 编辑失败 |
| 69 | WFM2_NEED_2SV | 需要 2 次认证 |
| 70 | WFM2_NO_SHARED_FOLDER_NO_VOLUME | Volume 尚未就绪 |
| 71 | WFM2_QHAM_RETRIEVE_FAIL | QHAM 资料收复失败 |
| 72 | WFM2_QHAM_DELETE_JOB_FAIL | QHAM 取消背景工作失败 |
| 73 | WFM2_TIERING_ON_DEMAND_DISABLE_FAIL | Tiering on demand 启用失败 |
| 74 | WFM2_TIERING_ON_DEMAND_ENABLE_FAIL | Tiering on demand 取消失败 |
| 75 | WFM2_QHAM_CANCEL_JOB_FAIL | QHAM 取消工作失败 |
| 76 | WFM2_DISCOVER_DETAIL_FAIL | （保留） |
| 77 | WFM2_CACHE_MOUNT_NOT_ENABLE | 远端挂载尚未启用 |
| 78 | WFM2_CM_GET_UPLOAD_FAILED_FILES_FAIL | （保留） |
| 79 | WFM2_CM_RETRY_FAILED_FILES_FAIL | Google doc 转档失败 |
| 80 | WFM2_CM_RENAME_NOT_SUPPORT | 不支持 cached mount rename 功能 |
| 81 | WFM2_GOOGLE_DOC_TRANS_FILE_TOO_LARGE | Google doc 档案太大，无法转档 |
| 82 | WFM2_GOOGLE_DOC_TRANS_FAIL | Google doc 转档失败 |
| 83 | WFM2_NETWORK_ERROR | 网路连线异常 |
| 84 | WFM2_INFILE_EXTENSION_NOT_SUPPORT | 不支持的 Google doc 转档档案文件格式 |
| 85 | WFM2_EXCEED_QDFF_MAX | QDFF share 挂载超过最大数量 |
| 86 | WFM2_CLOUD_CONVERT_ERR | 第三方 Cloud convert 输入参数错误 |
| 87 | WFM2_CLOUD_CONVERT_ERR | 第三方 Cloud convert 失败 |
| 88 | WFM2_CLOUD_CONVERT_NOT_AVALIABLE_ERR | 第三方 Cloud convert server 尚未就绪 |
| 89 | WFM2_QDFF_MOUNT_FORMAT_ERR | QDFF mount 格式错误 |
| 90 | WFM2_CLOUD_CONVERT_API_KEY_ERR | 第三方 Cloud convert api key 错误 |
| 91 | WFM2_CLOUD_CONVERT_QUOTA_OR_TIME_LIMIT_ERR | 第三方 Cloud convert 已达使用者最大上限 |
| 92 | WFM2_SRC_IS_UNDER_THE_DEST | 移动的来源档在相同的目的地路径下 |
| 93 | WFM2_SRC_EIO_ERROR | 存取档案 EIO 错误 |
| 94 | WFM2_QHAM_ENOSPACE | 存取远端挂载档案的储存空间不足错误 |
| 95 | WFM2_TIME_INVALID | 新增档案分享的时间错误 |
| 96 | WFM2_CAYIN_MEDIA_DISABLE | CAYIN QPKG 尚未安装启用错误 |
| 97 | WFM2_CAYIN_MEDIA_LICENSE_DACTIVED | 新增档案转档时伺服器 license 尚未启用 |
| 98 | WFM2_MEDIA_THUMB_NOT_SUPPORT | 产生缩图时有错误产生或者 option 不 support |
| 99 | WFM2_MMC_NOT_INSTALL | 未安装 Multimedia console QPKG |
| 103 | WFM2_MEDIASTREAM_ADD_ON_NOT_ENABLE | Media Streaming add on 未启用 |
| 104 | WFM2_CALCULATE_SIZE_PROCESS_NOT_FOUND | 指定的后台任务计算档案大小处理未找到 |
| 105 | WFM2_SHARE_LINK_DB_CREATE_ERROR | Share link DB 建立错误 |
| 106 | WFM2_CHECK_SUM_ERROR | Check sum 错误 |
| 107 | WFM2_UPLOAD_PARTIALLY_ERROR | 部分档案上传失败 |
| 108 | WFM2_OP_NEED_2SV | 复制/移动资料完整性检查 2SV 错误 |
| 109 | WFM2_UPLOAD_FAILED | 上传失败 |

---

## DLNA 专用状态码（多媒体播放控制）

| status | 枚举名 | 说明 |
|--------|--------|------|
| 1 | SYSTEM_ERR | 系统错误 |
| 2 | IPC_FORMAT_ERR | IPC 格式错误 |
| 3 | PARAMTER_NOT_FOUND_ERR | 参数不存在 |
| 4 | RENDER_NOT_EXIST_ERR | 渲染器不存在 |
| 5 | CREATE_PLAYER_FAIL_ERR | 建立播放器失败 |
| 6 | QDMCD_NOT_EXIST_ERR | QDMCD 不存在 |
| 7 | COMMAND_NOT_FOUND_ERR | 命令不存在 |
| 8 | UNKNOW_PLAY_MODE_ERR | 未知的播放模式 |
| 9 | RETURN_FORMAT_ERR | 回传格式错误 |
| 10 | PLAYLIST_NOT_FOUND_ERR | 播放清单不存在 |
| 11 | PLAYQUEUE_DB_QUERY_ERR | 播放伫列 DB 查询错误 |
| 12 | PLAYQUEUE_DB_ACCESS_ERR | 播放伫列 DB 存取错误 |
| 13 | FILE_NOT_IN_DB_ERR | 在 DB 中找不到档案 |
