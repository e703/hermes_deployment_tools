#!/usr/bin/env bash
# ==============================================================================
# Hermes Agent 批量 Profile 部署与配置更新脚本
# ==============================================================================
set -euo pipefail

CSV_FILE="${1:-profiles.csv}"
TEMPLATE_FILE="${2:-config.yaml.tpl}"
HERMES_BASE_DIR="$HOME/.hermes/profiles"

# --- 1. 环境与依赖检查 ---
if [ ! -f "$CSV_FILE" ]; then
    echo "❌ 错误: 找不到数据文件 '$CSV_FILE'"
    exit 1
fi

if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "❌ 错误: 找不到模板文件 '$TEMPLATE_FILE'"
    exit 1
fi

mkdir -p "$HERMES_BASE_DIR"

echo "🚀 [1/3] 开始批量部署/更新 Hermes Profiles..."
echo "📂 目标基准目录: $HERMES_BASE_DIR"
echo "--------------------------------------------------------"

COUNT=0

# --- 2. 逐行读取 CSV 并生成配置 ---
# 使用 tail -n +2 跳过表头
tail -n +2 "$CSV_FILE" | while IFS='|' read -r profile api_key base_url model || [ -n "$profile" ]; do
    # 清理字符串前后空白
    profile=$(echo "$profile" | xargs 2>/dev/null || true)
    api_key=$(echo "$api_key" | xargs 2>/dev/null || true)
    base_url=$(echo "$base_url" | xargs 2>/dev/null || true)
    model=$(echo "$model" | xargs 2>/dev/null || true)

    # 跳过空行或注释行 (# 开头)
    [[ -z "$profile" || "$profile" =~ ^# ]] && continue

    COUNT=$((COUNT + 1))
    PROFILE_DIR="$HERMES_BASE_DIR/$profile"
    
    echo "📦 正在处理 Profile [$COUNT]: $profile"
    mkdir -p "$PROFILE_DIR"

    # A. 生成/更新 .env 文件 (追加模式防护，防止覆写已有非 API 密钥设置)
    ENV_FILE="$PROFILE_DIR/.env"
    
    if [ -f "$ENV_FILE" ]; then
        # 如果文件已存在，删除已有的 OPENAI_API_KEY 行，再追加新 Key
        sed -i '/^OPENAI_API_KEY=/d' "$ENV_FILE" 2>/dev/null || true
    else
        touch "$ENV_FILE"
    fi

    echo "OPENAI_API_KEY=${api_key}" >> "$ENV_FILE"
    chmod 600 "$ENV_FILE"
    echo "   ✓ .env 已更新 (OPENAI_API_KEY已设置，权限 600)"

    # B. 渲染模板到 config.yaml
    CONFIG_FILE="$PROFILE_DIR/config.yaml"
    
    # 导出临时环境变量供 envsubst 渲染
    export DEFAULT_MODEL="$model"
    export BASE_URL="$base_url"

    if command -v envsubst &>/dev/null; then
        envsubst < "$TEMPLATE_FILE" > "$CONFIG_FILE"
    else
        # 兜底：如果系统没有 envsubst，使用 sed 替换
        sed -e "s|\${DEFAULT_MODEL}|${model}|g" \
            -e "s|\${BASE_URL}|${base_url}|g" \
            -e 's|\$\${OPENAI_API_KEY}|\${OPENAI_API_KEY}|g' \
            "$TEMPLATE_FILE" > "$CONFIG_FILE"
    fi

    echo "   ✓ config.yaml 已成功渲染 (默认模型: $model)"

    # C. 验证生成的 YAML 语法
    if command -v python3 &>/dev/null; then
        if python3 -c "import yaml; yaml.safe_load(open('$CONFIG_FILE'))" 2>/dev/null; then
            echo "   ✓ YAML 格式校验通过"
        else
            echo "   ⚠️ 警告: $CONFIG_FILE 存在语法解析异常，请检查！"
        fi
    fi

    echo "--------------------------------------------------------"
done

echo "🎉 [2/3] 配置更新完成！"

# --- 3. 询问或自动重启常驻网关服务 ---
echo "🔄 [3/3] 检查运行中的 Hermes Gateway 服务..."
if command -v hermes &>/dev/null; then
    echo "提示: 配置更新后需要重启 Gateway 才能对后台进程生效。"
    read -p "是否立即运行 'hermes gateway restart' 刷新服务？ [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        hermes gateway restart || echo "⚠️ Gateway 重启完成或部分服务未在运行。"
    fi
else
    echo "ℹ️ 未在 PATH 中检测到 hermes CLI，跳过网关重启步骤。"
fi

echo "✨ 部署脚本执行结束！"
