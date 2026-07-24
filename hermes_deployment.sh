#!/usr/bin/env bash
set -euo pipefail

CSV_FILE="${1:-profiles.csv}"
TEMPLATE_FILE="${2:-config.yaml.tpl}"
HERMES_BASE_DIR="$HOME/.hermes/profiles"

# 基础文件检查
if [ ! -f "$CSV_FILE" ]; then
    echo "❌ 错误: 找不到数据文件 $CSV_FILE"
    exit 1
fi

if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "❌ 错误: 找不到模板文件 $TEMPLATE_FILE"
    exit 1
fi

echo "🚀 开始批量部署/更新 Hermes Profiles..."

# 跳过 CSV 首行表头，逐行解析
tail -n +2 "$CSV_FILE" | while IFS='|' read -r profile api_key base_url model || [ -n "$profile" ]; do
    # 去除多余空格和换行
    profile=$(echo "$profile" | xargs)
    api_key=$(echo "$api_key" | xargs)
    base_url=$(echo "$base_url" | xargs)
    model=$(echo "$model" | xargs)

    # 忽略空行
    [ -z "$profile" ] && continue

    echo "----------------------------------------"
    echo "📦 [1/3] 正在配置 Profile: [$profile]"

    PROFILE_DIR="$HERMES_BASE_DIR/$profile"
    mkdir -p "$PROFILE_DIR"

    # 1. 写入密钥到 .env (严格设置 600 权限)
    cat <<EOF > "$PROFILE_DIR/.env"
# Auto-generated secrets for profile [$profile]
OPENAI_API_KEY=${api_key}
EOF
    chmod 600 "$PROFILE_DIR/.env"
    echo "   ✓ .env 已安全生成"

    # 2. 渲染模板到 config.yaml
    # 使用 sed 将模板中的变量替换，同时保留 Literal '${OPENAI_API_KEY}'
    sed -e "s|\${DEFAULT_MODEL}|${model}|g" \
        -e "s|\${BASE_URL}|${base_url}|g" \
        "$TEMPLATE_FILE" > "$PROFILE_DIR/config.yaml"
    echo "   ✓ config.yaml 已成功渲染"

    # 3. 校验语法 (如果环境安装了 yq/python，可进行语法二次确认)
    if command -v python3 &>/dev/null; then
        python3 -c "import yaml; yaml.safe_load(open('$PROFILE_DIR/config.yaml'))" 2>/dev/null \
            && echo "   ✓ YAML 语法验证通过" \
            || echo "   ⚠️ 警告: $PROFILE_DIR/config.yaml 语法可能有误，请检查"
    fi

    echo "✅ [$profile] 部署完成！"
done

echo "----------------------------------------"
echo "🎉 所有 Profile 批量部署完毕！"
