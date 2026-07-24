#!/usr/bin/env bash
# ==============================================================================
# Hermes Agent 批量 Profile 自动化部署脚本 (支持多 Key 扩展)
# ==============================================================================
set -euo pipefail

CSV_FILE="${1:-profiles.csv}"
TEMPLATE_FILE="${2:-config.yaml.tpl}"
HERMES_BASE_DIR="$HOME/.hermes/profiles"

# --- 1. 依赖与基础检查 ---
if [ ! -f "$CSV_FILE" ]; then
    echo "❌ 错误: 找不到数据文件 '$CSV_FILE'"
    exit 1
fi

if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "❌ 错误: 找不到模板文件 '$TEMPLATE_FILE'"
    exit 1
fi

mkdir -p "$HERMES_BASE_DIR"

echo "🚀 开始批量部署/更新 Hermes Profiles..."
echo "--------------------------------------------------------"

COUNT=0

# --- 2. 解析 CSV (在此处增加读取的变量名) ---
tail -n +2 "$CSV_FILE" | while IFS='|' read -r profile api_key base_url model tavily_key || [ -n "$profile" ]; do
    # 清理两端空格
    profile=$(echo "$profile" | xargs 2>/dev/null || true)
    api_key=$(echo "$api_key" | xargs 2>/dev/null || true)
    base_url=$(echo "$base_url" | xargs 2>/dev/null || true)
    model=$(echo "$model" | xargs 2>/dev/null || true)
    tavily_key=$(echo "$tavily_key" | xargs 2>/dev/null || true)

    # 忽略空行与 # 注释行
    [[ -z "$profile" || "$profile" =~ ^# ]] && continue

    COUNT=$((COUNT + 1))
    PROFILE_DIR="$HERMES_BASE_DIR/$profile"
    
    echo "📦 [$COUNT] 正在配置 Profile: [$profile]"
    mkdir -p "$PROFILE_DIR"

    # A. 生成 .env (根据需要追加/写入多个 Key)
    ENV_FILE="$PROFILE_DIR/.env"
    cat <<EOF > "$ENV_FILE"
# Auto-generated secrets for profile [$profile]
BJLAB_API_KEY=${api_key}
EOF

    # 判断如果 CSV 里填了 Tavily Key，则写入 .env
    if [ -n "$tavily_key" ]; then
        echo "TAVILY_API_KEY=${tavily_key}" >> "$ENV_FILE"
    fi

    chmod 600 "$ENV_FILE"
    echo "   ✓ .env 已更新 (密钥写入完成，权限 600)"

    # B. 渲染 config.yaml
    CONFIG_FILE="$PROFILE_DIR/config.yaml"
    sed -e "s|\${DEFAULT_MODEL}|${model}|g" \
        -e "s|\${BASE_URL}|${base_url}|g" \
        "$TEMPLATE_FILE" > "$CONFIG_FILE"

    echo "   ✓ config.yaml 已成功渲染 (默认模型: $model)"

    # C. 验证生成的 YAML 语法
    if command -v python3 &>/dev/null; then
        if python3 -c "import yaml; yaml.safe_load(open('$CONFIG_FILE'))" 2>/dev/null; then
            echo "   ✓ YAML 语法校验通过"
        else
            echo "   ⚠️ 警告: $CONFIG_FILE 语法可能有误！"
        fi
    fi

    echo "--------------------------------------------------------"
done

echo "🎉 批量部署完成！"
