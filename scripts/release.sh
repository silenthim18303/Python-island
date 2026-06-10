#!/bin/bash
# MacIsland Release Script
# 用法: ./scripts/release.sh <version>
# 示例: ./scripts/release.sh 2.3.0

set -e

VERSION=$1
if [ -z "$VERSION" ]; then
    echo "用法: $0 <version>"
    echo "示例: $0 2.3.0"
    exit 1
fi

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DMG_PATH="$PROJECT_DIR/MacIsland_v${VERSION}.dmg"
APP_PATH="$PROJECT_DIR/build/Release/MacIsland.app"

echo "=== MacIsland v${VERSION} 发布脚本 ==="

# 1. 检查 DMG 是否存在
if [ ! -f "$DMG_PATH" ]; then
    echo "❌ DMG 不存在: $DMG_PATH"
    echo "请先构建 Release 并创建 DMG"
    exit 1
fi

# 2. 计算 SHA256
echo "📦 计算 SHA256..."
SHA256=$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')
echo "   SHA256: $SHA256"

# 3. 获取文件大小
SIZE=$(stat -f%z "$DMG_PATH")
echo "   大小: $SIZE bytes"

# 4. 生成 release notes 模板
cat << EOF
## v${VERSION} 更新内容

### 新增
-

### 修复
-

### 优化
-

---
**校验信息**
\`\`\`
sha256: ${SHA256}
\`\`\`
文件: MacIsland_v${VERSION}.dmg ($(($SIZE / 1024 / 1024)) MB)
EOF

echo ""
echo "✅ Release notes 已生成（包含 SHA256）"
echo ""
echo "下一步:"
echo "1. 将上面的 release notes 复制到 GitHub Release"
echo "2. 上传 MacIsland_v${VERSION}.dmg"
echo "3. 发布 Release"
