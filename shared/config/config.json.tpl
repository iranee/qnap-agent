{
  "session": {
    "dimensions": [
      "chat"
    ]
  },
  "version": 3,
  "isolation": {},
  "agents": {
    "defaults": {
      "workspace": "__QPKG_ROOT__/workspace",
      "restrict_to_workspace": true,
      "allow_read_outside_workspace": false,
      "provider": "",
      "model_name": "",
      "max_tokens": 32768,
      "max_tool_iterations": 50,
      "summarize_message_threshold": 20,
      "summarize_token_percent": 75,
      "steering_mode": "one-at-a-time",
      "subturn": {
        "max_depth": 0,
        "max_concurrent": 0,
        "default_timeout_minutes": 0,
        "default_token_budget": 0,
        "concurrency_timeout_sec": 0
      },
      "tool_feedback": {
        "enabled": false,
        "max_args_length": 300,
        "separate_messages": false
      },
      "split_on_marker": false
    }
  },
  "channel_list": {
    "dingtalk": {
      "enabled": false,
      "type": "dingtalk",
      "reasoning_channel_id": "",
      "group_trigger": {},
      "typing": {},
      "placeholder": {
        "enabled": false
      },
      "settings": {
        "client_id": ""
      }
    },
    "discord": {
      "enabled": false,
      "type": "discord",
      "reasoning_channel_id": "",
      "group_trigger": {},
      "typing": {},
      "placeholder": {
        "enabled": false
      },
      "settings": {
        "proxy": "",
        "mention_only": false
      }
    },
    "feishu": {
      "enabled": false,
      "type": "feishu",
      "reasoning_channel_id": "",
      "group_trigger": {},
      "typing": {},
      "placeholder": {
        "enabled": false
      },
      "settings": {
        "app_id": "",
        "random_reaction_emoji": null,
        "is_lark": false
      }
    },
    "irc": {
      "enabled": false,
      "type": "irc",
      "reasoning_channel_id": "",
      "group_trigger": {},
      "typing": {},
      "placeholder": {
        "enabled": false
      },
      "settings": {
        "server": "",
        "tls": true,
        "nick": "picoclaw",
        "sasl_user": "",
        "channels": []
      }
    },
    "line": {
      "enabled": false,
      "type": "line",
      "reasoning_channel_id": "",
      "group_trigger": {
        "mention_only": true
      },
      "typing": {},
      "placeholder": {
        "enabled": false
      },
      "settings": {
        "webhook_host": "0.0.0.0",
        "webhook_port": 18791,
        "webhook_path": "/webhook/line"
      }
    },
    "maixcam": {
      "enabled": false,
      "type": "maixcam",
      "reasoning_channel_id": "",
      "group_trigger": {},
      "typing": {},
      "placeholder": {
        "enabled": false
      },
      "settings": {
        "host": "0.0.0.0",
        "port": 18780
      }
    },
    "matrix": {
      "enabled": false,
      "type": "matrix",
      "reasoning_channel_id": "",
      "group_trigger": {
        "mention_only": true
      },
      "typing": {},
      "placeholder": {
        "enabled": true,
        "text": [
          "Thinking... 💭"
        ]
      },
      "settings": {
        "homeserver": "https://matrix.org",
        "user_id": "",
        "join_on_invite": true
      }
    },
    "onebot": {
      "enabled": false,
      "type": "onebot",
      "reasoning_channel_id": "",
      "group_trigger": {},
      "typing": {},
      "placeholder": {
        "enabled": false
      },
      "settings": {
        "ws_url": "ws://127.0.0.1:3001",
        "reconnect_interval": 5,
        "group_trigger_prefix": null
      }
    },
    "pico": {
      "enabled": true,
      "type": "pico",
      "reasoning_channel_id": "",
      "group_trigger": {},
      "typing": {},
      "placeholder": {
        "enabled": false
      },
      "settings": {
        "ping_interval": 30,
        "read_timeout": 60,
        "write_timeout": 10,
        "max_connections": 100
      }
    },
    "qq": {
      "enabled": false,
      "type": "qq",
      "reasoning_channel_id": "",
      "group_trigger": {},
      "typing": {},
      "placeholder": {
        "enabled": false
      },
      "settings": {
        "app_id": "",
        "max_message_length": 2000,
        "max_base64_file_size_mib": 0,
        "send_markdown": false
      }
    },
    "slack": {
      "enabled": false,
      "type": "slack",
      "reasoning_channel_id": "",
      "group_trigger": {},
      "typing": {},
      "placeholder": {
        "enabled": false
      },
      "settings": {}
    },
    "telegram": {
      "enabled": false,
      "type": "telegram",
      "reasoning_channel_id": "",
      "group_trigger": {},
      "typing": {
        "enabled": true
      },
      "placeholder": {
        "enabled": true,
        "text": [
          "Thinking... 💭"
        ]
      },
      "settings": {
        "base_url": "",
        "proxy": "",
        "streaming": {
          "enabled": false,
          "throttle_seconds": 3,
          "min_growth_chars": 200
        },
        "use_markdown_v2": true
      }
    },
    "wecom": {
      "enabled": false,
      "type": "wecom",
      "reasoning_channel_id": "",
      "group_trigger": {},
      "typing": {},
      "placeholder": {
        "enabled": false
      },
      "settings": {
        "bot_id": "",
        "websocket_url": "wss://openws.work.weixin.qq.com",
        "send_thinking_message": true
      }
    },
    "weixin": {
      "enabled": false,
      "type": "weixin",
      "reasoning_channel_id": "",
      "group_trigger": {},
      "typing": {},
      "placeholder": {
        "enabled": false
      },
      "settings": {
        "base_url": "https://ilinkai.weixin.qq.com/",
        "cdn_base_url": "https://novac2c.cdn.weixin.qq.com/c2c",
        "proxy": ""
      }
    },
    "whatsapp": {
      "enabled": false,
      "type": "whatsapp",
      "reasoning_channel_id": "",
      "group_trigger": {},
      "typing": {},
      "placeholder": {
        "enabled": false
      },
      "settings": {
        "bridge_url": "ws://localhost:3001",
        "use_native": false,
        "session_store_path": ""
      }
    }
  },
  "model_list": [
    {
      "model_name": "glm-4.7",
      "provider": "zhipu",
      "model": "glm-4.7",
      "api_base": "https://open.bigmodel.cn/api/paas/v4"
    },
    {
      "model_name": "gpt-5.4",
      "provider": "openai",
      "model": "gpt-5.4",
      "api_base": "https://api.openai.com/v1"
    },
    {
      "model_name": "claude-sonnet-4.6",
      "provider": "anthropic",
      "model": "claude-sonnet-4.6",
      "api_base": "https://api.anthropic.com/v1"
    },
    {
      "model_name": "deepseek-chat",
      "provider": "deepseek",
      "model": "deepseek-chat",
      "api_base": "https://api.deepseek.com/v1"
    },
    {
      "model_name": "venice-uncensored",
      "provider": "venice",
      "model": "venice-uncensored",
      "api_base": "https://api.venice.ai/api/v1"
    },
    {
      "model_name": "gemini-2.0-flash",
      "provider": "gemini",
      "model": "gemini-2.0-flash-exp",
      "api_base": "https://generativelanguage.googleapis.com/v1beta"
    },
    {
      "model_name": "qwen-plus",
      "provider": "qwen",
      "model": "qwen-plus",
      "api_base": "https://dashscope.aliyuncs.com/compatible-mode/v1"
    },
    {
      "model_name": "moonshot-v1-8k",
      "provider": "moonshot",
      "model": "moonshot-v1-8k",
      "api_base": "https://api.moonshot.cn/v1"
    },
    {
      "model_name": "llama-3.3-70b",
      "provider": "groq",
      "model": "llama-3.3-70b-versatile",
      "api_base": "https://api.groq.com/openai/v1"
    },
    {
      "model_name": "openrouter-auto",
      "provider": "openrouter",
      "model": "auto",
      "api_base": "https://openrouter.ai/api/v1"
    },
    {
      "model_name": "openrouter-gpt-5.4",
      "provider": "openrouter",
      "model": "openai/gpt-5.4",
      "api_base": "https://openrouter.ai/api/v1"
    },
    {
      "model_name": "nemotron-4-340b",
      "provider": "nvidia",
      "model": "nemotron-4-340b-instruct",
      "api_base": "https://integrate.api.nvidia.com/v1"
    },
    {
      "model_name": "cerebras-llama-3.3-70b",
      "provider": "cerebras",
      "model": "llama-3.3-70b",
      "api_base": "https://api.cerebras.ai/v1"
    },
    {
      "model_name": "vivgrid-auto",
      "provider": "vivgrid",
      "model": "auto",
      "api_base": "https://api.vivgrid.com/v1"
    },
    {
      "model_name": "ark-code-latest",
      "provider": "volcengine",
      "model": "ark-code-latest",
      "api_base": "https://ark.cn-beijing.volces.com/api/v3"
    },
    {
      "model_name": "doubao-pro",
      "provider": "volcengine",
      "model": "doubao-pro-32k",
      "api_base": "https://ark.cn-beijing.volces.com/api/v3"
    },
    {
      "model_name": "deepseek-v3",
      "provider": "shengsuanyun",
      "model": "deepseek-v3",
      "api_base": "https://api.shengsuanyun.com/v1"
    },
    {
      "model_name": "gemini-flash",
      "provider": "antigravity",
      "model": "gemini-3-flash",
      "auth_method": "oauth"
    },
    {
      "model_name": "copilot-gpt-5.4",
      "provider": "github-copilot",
      "model": "gpt-5.4",
      "api_base": "http://localhost:4321",
      "auth_method": "oauth"
    },
    {
      "model_name": "llama3",
      "provider": "ollama",
      "model": "llama3",
      "api_base": "http://localhost:11434/v1"
    },
    {
      "model_name": "mistral-small",
      "provider": "mistral",
      "model": "mistral-small-latest",
      "api_base": "https://api.mistral.ai/v1"
    },
    {
      "model_name": "deepseek-v3.2",
      "provider": "avian",
      "model": "deepseek/deepseek-v3.2",
      "api_base": "https://api.avian.io/v1"
    },
    {
      "model_name": "kimi-k2.5",
      "provider": "avian",
      "model": "moonshotai/kimi-k2.5",
      "api_base": "https://api.avian.io/v1"
    },
    {
      "model_name": "MiniMax-M2.5",
      "provider": "minimax",
      "model": "MiniMax-M2.5",
      "api_base": "https://api.minimaxi.com/v1",
      "extra_body": {
        "reasoning_split": true
      }
    },
    {
      "model_name": "LongCat-Flash-Thinking",
      "provider": "longcat",
      "model": "LongCat-Flash-Thinking",
      "api_base": "https://api.longcat.chat/openai"
    },
    {
      "model_name": "modelscope-qwen",
      "provider": "modelscope",
      "model": "Qwen/Qwen3-235B-A22B-Instruct-2507",
      "api_base": "https://api-inference.modelscope.cn/v1"
    },
    {
      "model_name": "local-model",
      "provider": "vllm",
      "model": "custom-model",
      "api_base": "http://localhost:8000/v1"
    },
    {
      "model_name": "lmstudio-local",
      "provider": "lmstudio",
      "model": "openai/gpt-oss-20b",
      "api_base": "http://localhost:1234/v1"
    },
    {
      "model_name": "azure-gpt5",
      "provider": "azure",
      "model": "my-gpt5-deployment",
      "api_base": "https://your-resource.openai.azure.com"
    }
  ],
  "gateway": {
    "host": "0.0.0.0",
    "port": 18790,
    "hot_reload": true,
    "log_level": "warn"
  },
  "hooks": {
    "enabled": true,
    "defaults": {
      "observer_timeout_ms": 500,
      "interceptor_timeout_ms": 5000,
      "approval_timeout_ms": 60000
    }
  },
  "tools": {
    "allow_read_paths": null,
    "allow_write_paths": [
      "__QPKG_ROOT__/workspace"
    ],
    "filter_sensitive_data": true,
    "filter_min_length": 8,
    "web": {
      "enabled": true,
      "brave": {
        "enabled": false,
        "max_results": 5
      },
      "tavily": {
        "enabled": false,
        "base_url": "",
        "max_results": 5
      },
      "sogou": {
        "enabled": true,
        "max_results": 5
      },
      "duckduckgo": {
        "enabled": true,
        "max_results": 5
      },
      "perplexity": {
        "enabled": false,
        "max_results": 5
      },
      "searxng": {
        "enabled": false,
        "base_url": "",
        "max_results": 5
      },
      "glm_search": {
        "enabled": false,
        "base_url": "https://open.bigmodel.cn/api/paas/v4/web_search",
        "search_engine": "search_std",
        "max_results": 5
      },
      "baidu_search": {
        "enabled": false,
        "base_url": "https://qianfan.baidubce.com/v2/ai_search/web_search",
        "max_results": 5
      },
      "provider": "sogou",
      "prefer_native": true,
      "fetch_limit_bytes": 10485760,
      "format": "plaintext"
    },
    "cron": {
      "enabled": true,
      "exec_timeout_minutes": 5,
      "allow_command": true
    },
    "exec": {
      "enabled": true,
      "enable_deny_patterns": true,
      "allow_remote": true,
      "custom_deny_patterns": [
        "\\bopkg\\b",
        "\\bipkg\\b",
        "\\bentware\\b",
        "\\bapt(-get)?\\s+(install|upgrade|dist-upgrade|remove|purge|autoremove)\\b",
        "\\byum\\s+(install|update|remove|erase)\\b",
        "\\bdnf\\s+(install|update|remove)\\b",
        "\\bqpkg_fw_update\\b",
        "\\bcheck_update\\.sh\\b",
        "\\bqfirmware\\b",
        "\\bhal_app.*upgrade\\b",
        "\\bpasswd\\b",
        "\\bchpasswd\\b",
        "\\busermod\\b",
        "\\buseradd\\b",
        "\\buserdel\\b",
        "\\bgroupadd\\b",
        "\\biptables\\s+-(F|X|Z)\\b",
        "\\bip6tables\\s+-(F|X|Z)\\b",
        "\\bnft\\s+flush\\b",
        "\\bumount\\s+/share/\\b",
        "\\bmkswap\\b",
        "\\bapk\\b",
        "\\bsetcfg\\s+System\\b",
        "\\bsetcfg\\s+Network\\b",
        "\\bsetcfg\\s+Security\\b"
      ],
      "custom_allow_patterns": [
        "^docker\\s+(ps|inspect|logs|stats|images|version|info|network|volume|system)\\b",
        "^docker\\s+compose\\s+(up|down|restart|stop|start|pull|logs|ps|config|build)\\b",
        "^docker\\s+(pull|tag|rmi|rm|stop|start|restart|pause|unpause)\\s+\\S+",
        "^docker\\s+run\\s+",
        "^docker\\s+exec\\s+",
        "^/sbin/getcfg\\b",
        "^getcfg\\b",
        "^/usr/sbin/qpkg_cli\\b",
        "^qpkg_query\\b",
        "^df\\b",
        "^du\\b",
        "^ls\\b",
        "^find\\s+/share/\\b",
        "^find\\s+/home/\\b",
        "^find\\s+__QPKG_ROOT__",
        "^cat\\s+/etc/os-release\\b",
        "^cat\\s+/etc/config/",
        "^cat\\s+/proc/",
        "^grep\\b",
        "^head\\b",
        "^tail\\b",
        "^wc\\b",
        "^sort\\b",
        "^awk\\b",
        "^sed\\b",
        "^cut\\b",
        "^tr\\b",
        "^xargs\\b",
        "^rsync\\s+",
        "^cp\\s+",
        "^mv\\s+",
        "^mkdir\\s+",
        "^touch\\s+",
        "^ln\\s+",
        "^tar\\b",
        "^gzip\\b",
        "^gunzip\\b",
        "^unzip\\b",
        "^zip\\b",
        "^chmod\\s+[0-7][0-7][0-7]\\s+/share/",
        "^chmod\\s+[0-7][0-7][0-7]\\s+__QPKG_ROOT__",
        "^chown\\s+\\S+\\s+/share/",
        "^curl\\s+",
        "^wget\\s+",
        "^ping\\s+-c\\b",
        "^ip\\s+(addr|route|link)\\s+(show|list)\\b",
        "^netstat\\b",
        "^ss\\b",
        "^nslookup\\b",
        "^ps\\b",
        "^free\\b",
        "^uptime\\b",
        "^dmesg\\b",
        "^vmstat\\b",
        "^iostat\\b",
        "^smartctl\\b",
        "^lsblk\\b",
        "^blkid\\b",
        "^/etc/init\\.d/\\w+\\s+(status|restart|stop|start)\\b",
        "^systemctl\\s+(status|is-active|list-units)\\b",
        "^jq\\b",
        "^screen\\s+",
        "^/usr/local/cayin/bin/ffprobe\\b",
        "^/usr/local/cayin/bin/ffmpeg\\s+",
        "^python3?\\s+[^|;&`]+\\.py\\b",
		"^__QPKG_ROOT__/qnap-agent\.sh(\s+(start|stop|restart|status|upgrade))?$",
        "^curl\\s+.*127\\.0\\.0\\.1",
        "\\$\\{[A-Za-z_][A-Za-z0-9_]*:-[^}]*\\}"
      ],
      "timeout_seconds": 60
    },
    "skills": {
      "enabled": true,
      "registries": {
        "clawhub": {
          "base_url": "https://clawhub.ai",
          "enabled": true
        },
        "github": {
          "base_url": "https://github.com",
          "enabled": true
        }
      },
      "github": {},
      "max_concurrent_searches": 2,
      "search_cache": {
        "max_size": 50,
        "ttl_seconds": 300
      }
    },
    "media_cleanup": {
      "enabled": true,
      "max_age_minutes": 30,
      "interval_minutes": 5
    },
    "mcp": {
      "enabled": false,
      "discovery": {
        "enabled": false,
        "ttl": 5,
        "max_search_results": 5,
        "use_bm25": true,
        "use_regex": false
      },
      "max_inline_text_chars": 16384
    },
    "append_file": {
      "enabled": true
    },
    "edit_file": {
      "enabled": true
    },
    "find_skills": {
      "enabled": true
    },
    "i2c": {
      "enabled": false
    },
    "install_skill": {
      "enabled": true
    },
    "list_dir": {
      "enabled": true
    },
    "message": {
      "enabled": true
    },
    "read_file": {
      "enabled": true,
      "mode": "bytes",
      "max_read_file_size": 65536
    },
    "serial": {
      "enabled": false
    },
    "send_file": {
      "enabled": true
    },
    "send_tts": {
      "enabled": false
    },
    "spawn": {
      "enabled": true
    },
    "spawn_status": {
      "enabled": false
    },
    "spi": {
      "enabled": false
    },
    "subagent": {
      "enabled": true
    },
    "web_fetch": {
      "enabled": true
    },
    "write_file": {
      "enabled": true
    }
  },
  "heartbeat": {
    "enabled": false,
    "interval": 30
  },
  "devices": {
    "enabled": false,
    "monitor_usb": true
  },
  "voice": {
    "echo_transcription": false
  },
  "build_info": {
    "version": "0.2.8",
    "git_commit": "6e1fab80",
    "build_time": "2026-04-30T14:52:03Z",
    "go_version": "1.25.9"
  }
}