#!/bin/bash
# 部署所有 Edge Functions
# 用法: bash scripts/deploy-backend.sh [function_name]
# 示例: bash scripts/deploy-backend.sh note-generate
#       bash scripts/deploy-backend.sh  # 部署所有函数

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== Edge Function 部署 ==="

# 切换到后端项目目录
cd "$PROJECT_DIR"

if [ -n "$1" ]; then
  # 部署指定函数
  FUNCTION_NAME="$1"
  echo "部署函数: $FUNCTION_NAME"
  supabase functions deploy "$FUNCTION_NAME" --no-verify-jwt
else
  # 部署所有函数
  echo "部署所有 Edge Functions..."

  # 获取所有函数目录
  FUNCTIONS_DIR="$PROJECT_DIR/supabase/functions"

  for func_dir in "$FUNCTIONS_DIR"/*/; do
    if [ -d "$func_dir" ]; then
      func_name=$(basename "$func_dir")
      if [ -f "$func_dir/index.ts" ]; then
        echo "部署: $func_name"
        supabase functions deploy "$func_name" --no-verify-jwt || {
          echo "⚠️  $func_name 部署失败，继续..."
        }
      fi
    fi
  done
fi

echo ""
echo "=== 验证部署状态 ==="
supabase functions list

echo ""
echo "✅ Edge Function 部署完成"
