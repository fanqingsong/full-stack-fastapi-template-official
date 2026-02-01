#!/bin/bash

# 生产环境启动脚本
# 用法: ./bin/start-prod.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

ENV_FILE=".env.prod"
COMPOSE_FILE="compose.prod.yml"
ENV_NAME="生产环境"

echo "🚀 启动${ENV_NAME}..."
echo "📁 项目目录: $PROJECT_DIR"

# 检查环境文件是否存在
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ 错误: 环境配置文件不存在: $ENV_FILE"
    exit 1
fi

# 加载环境变量
export $(grep -v '^#' "$ENV_FILE" | grep -v '^$' | xargs)

# 构建 compose 文件列表（包含 Kong）
COMPOSE_FILES="-f compose.yml -f compose.kong.yml -f $COMPOSE_FILE"

# 先停止现有服务（如果存在）
echo "检查并停止现有服务..."
if docker compose $COMPOSE_FILES ps -q 2>/dev/null | grep -q .; then
    echo "停止现有服务..."
    docker compose $COMPOSE_FILES down --remove-orphans 2>/dev/null || true
fi

# 清理残留容器
echo "清理残留容器..."
docker ps -a --filter "name=${STACK_NAME}" --format "{{.ID}} {{.Status}}" | grep -E "Created|Exited" | awk '{print $1}' | xargs -r docker rm -f 2>/dev/null || true

sleep 2

# 启动服务
echo ""
echo "启动${ENV_NAME}服务..."

docker compose $COMPOSE_FILES up -d --build

# 等待服务启动
echo ""
echo "等待服务启动..."
sleep 5

# 等待 Kong 启动并初始化
echo ""
echo "等待 Kong Gateway 启动..."
if docker compose $COMPOSE_FILES ps kong 2>/dev/null | grep -q "Up"; then
    echo "等待 Kong Admin API 就绪..."
    for i in {1..60}; do
        if curl -s http://localhost:8001/status 2>/dev/null | grep -q '"database":{"reachable":true}'; then
            echo "✅ Kong 已就绪"
            break
        fi
        if [ $i -eq 60 ]; then
            echo "⚠️  警告: Kong 启动超时"
        fi
        sleep 2
    done

    # 执行 Kong 初始化脚本
    echo ""
    echo "初始化 Kong 配置..."
    if [ -f "$PROJECT_DIR/services/kong/init-kong.sh" ]; then
        export KONG_ADMIN_URL="http://localhost:8001"
        bash "$PROJECT_DIR/services/kong/init-kong.sh" || echo "⚠️  Kong 初始化脚本执行失败"
    else
        echo "⚠️  警告: Kong 初始化脚本不存在"
    fi
else
    echo "⚠️  警告: Kong 服务未启动"
fi

# 检查服务状态
echo ""
echo "✅ ${ENV_NAME}启动完成！"
echo ""
echo "📋 服务状态:"
docker compose $COMPOSE_FILES ps
echo ""

# 显示访问地址
echo "🌐 访问地址:"
echo "  - Frontend: https://dashboard.${DOMAIN}"
echo "  - Backend API: https://api.${DOMAIN}"
echo ""
echo "📝 查看日志: docker compose $COMPOSE_FILES logs -f"
echo "🛑 停止服务: ./bin/stop-prod.sh"
echo ""
