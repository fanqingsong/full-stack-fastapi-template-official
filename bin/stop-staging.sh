#!/bin/bash

# 预发布环境停止脚本
# 用法: ./bin/stop-staging.sh [--clean]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

ENV_FILE=".env.staging"
COMPOSE_FILE="compose.staging.yml"
ENV_NAME="预发布环境"
CLEAN_VOLUMES=false

# 检查参数是否是 --clean
if [[ "$1" == "--clean" ]] || [[ "$1" == "-c" ]]; then
    CLEAN_VOLUMES=true
fi

echo "🛑 停止${ENV_NAME}服务..."

# 加载环境变量以获取 STACK_NAME
if [ -f "$ENV_FILE" ]; then
    export $(grep -v '^#' "$ENV_FILE" | grep -v '^$' | xargs)
fi

# 构建 compose 文件列表（包含 Kong）
COMPOSE_FILES="-f compose.yml -f compose.kong.yml -f $COMPOSE_FILE"

# 停止服务
echo "停止服务..."

if [ "$CLEAN_VOLUMES" = "true" ]; then
    docker compose $COMPOSE_FILES down -v
else
    docker compose $COMPOSE_FILES down
fi

echo "✅ ${ENV_NAME}服务已停止！"

if [ "$CLEAN_VOLUMES" = "true" ]; then
    echo ""
    echo "💡 提示: 已清理所有数据卷（包括 Kong 数据）"
else
    echo ""
    echo "💡 提示: 要清理所有数据（包括 Kong），请使用: ./bin/stop-staging.sh --clean"
fi
