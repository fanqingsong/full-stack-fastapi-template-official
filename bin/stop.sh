#!/bin/bash

# 多环境停止脚本
# 用法: ./bin/stop.sh [dev|staging|prod] [--clean]
# 默认: dev

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

# 解析参数
ENVIRONMENT=${1:-dev}
CLEAN_VOLUMES=false

# 检查第二个参数是否是 --clean
if [[ "$ENVIRONMENT" == "--clean" ]] || [[ "$ENVIRONMENT" == "-c" ]]; then
    ENVIRONMENT="dev"
    CLEAN_VOLUMES=true
elif [[ "$2" == "--clean" ]] || [[ "$2" == "-c" ]]; then
    CLEAN_VOLUMES=true
fi

# 验证环境参数
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    echo "❌ 错误: 无效的环境 '$ENVIRONMENT'"
    echo ""
    echo "用法:"
    echo "  ./bin/stop.sh [dev|staging|prod] [--clean]"
    echo ""
    echo "示例:"
    echo "  ./bin/stop.sh dev           # 停止开发环境（默认）"
    echo "  ./bin/stop.sh staging       # 停止预发布环境"
    echo "  ./bin/stop.sh prod          # 停止生产环境"
    echo "  ./bin/stop.sh dev --clean   # 停止并清理数据卷"
    exit 1
fi

# 环境配置
case $ENVIRONMENT in
    dev)
        ENV_FILE=".env.dev"
        COMPOSE_FILE="compose.dev.yml"
        ENV_NAME="开发环境"
        ;;
    staging)
        ENV_FILE=".env.staging"
        COMPOSE_FILE="compose.staging.yml"
        ENV_NAME="预发布环境"
        ;;
    prod)
        ENV_FILE=".env.prod"
        COMPOSE_FILE="compose.prod.yml"
        ENV_NAME="生产环境"
        ;;
esac

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
    echo "💡 提示: 要清理所有数据（包括 Kong），请使用: ./bin/stop.sh $ENVIRONMENT --clean"
fi
