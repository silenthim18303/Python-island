#!/bin/bash

# MacIsland 配套 App 构建脚本
# 用法: ./build.sh [ios|android|harmonyos|all]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 创建构建目录
create_build_dir() {
    mkdir -p "$BUILD_DIR"
    mkdir -p "$BUILD_DIR/ios"
    mkdir -p "$BUILD_DIR/android"
    mkdir -p "$BUILD_DIR/harmonyos"
}

# 构建 iOS App
build_ios() {
    print_info "开始构建 iOS App..."

    if ! command -v xcodebuild &> /dev/null; then
        print_error "未找到 Xcode，请先安装 Xcode"
        return 1
    fi

    cd "$SCRIPT_DIR/iOS"

    # 构建 Debug 版本
    print_info "构建 Debug 版本..."
    xcodebuild -project MacIslandCompanion.xcodeproj \
               -scheme MacIslandCompanion \
               -configuration Debug \
               -sdk iphoneos \
               -derivedDataPath "$BUILD_DIR/ios/DerivedData" \
               build

    # 查找 .app 文件
    APP_PATH=$(find "$BUILD_DIR/ios/DerivedData" -name "MacIslandCompanion.app" -type d | head -1)

    if [ -n "$APP_PATH" ]; then
        print_success "iOS App 构建成功: $APP_PATH"

        # 创建 IPA
        print_info "创建 IPA 文件..."
        mkdir -p "$BUILD_DIR/ios/Payload"
        cp -R "$APP_PATH" "$BUILD_DIR/ios/Payload/"
        cd "$BUILD_DIR/ios"
        zip -r "$BUILD_DIR/MacIslandCompanion.ipa" Payload/
        rm -rf Payload

        print_success "IPA 文件已创建: $BUILD_DIR/MacIslandCompanion.ipa"
    else
        print_error "未找到构建的 .app 文件"
        return 1
    fi

    cd "$SCRIPT_DIR"
}

# 构建 Android App
build_android() {
    print_info "开始构建 Android App..."

    if ! command -v gradle &> /dev/null && ! command -v ./gradlew &> /dev/null; then
        print_warning "未找到 Gradle，尝试使用 Android Studio 构建"
        print_info "请在 Android Studio 中打开 Android/ 目录并构建"
        return 0
    fi

    cd "$SCRIPT_DIR/Android"

    # 检查是否有 gradlew
    if [ -f "./gradlew" ]; then
        chmod +x ./gradlew
        ./gradlew assembleDebug
    else
        gradle assembleDebug
    fi

    # 查找 APK 文件
    APK_PATH=$(find . -name "*.apk" -type f | head -1)

    if [ -n "$APK_PATH" ]; then
        cp "$APK_PATH" "$BUILD_DIR/MacIslandCompanion.apk"
        print_success "APK 文件已创建: $BUILD_DIR/MacIslandCompanion.apk"
    else
        print_warning "未找到 APK 文件"
    fi

    cd "$SCRIPT_DIR"
}

# 构建鸿蒙 App
build_harmonyos() {
    print_info "开始构建鸿蒙 App..."

    if ! command -v hvigorw &> /dev/null; then
        print_warning "未找到 hvigorw，请使用 DevEco Studio 构建"
        print_info "请在 DevEco Studio 中打开 HarmonyOS/ 目录并构建"
        return 0
    fi

    cd "$SCRIPT_DIR/HarmonyOS"

    # 构建 HAP
    hvigorw assembleHap

    # 查找 HAP 文件
    HAP_PATH=$(find . -name "*.hap" -type f | head -1)

    if [ -n "$HAP_PATH" ]; then
        cp "$HAP_PATH" "$BUILD_DIR/MacIslandCompanion.hap"
        print_success "HAP 文件已创建: $BUILD_DIR/MacIslandCompanion.hap"
    else
        print_warning "未找到 HAP 文件"
    fi

    cd "$SCRIPT_DIR"
}

# 显示帮助
show_help() {
    echo "MacIsland 配套 App 构建脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  ios          构建 iOS App"
    echo "  android      构建 Android App"
    echo "  harmonyos    构建鸿蒙 App"
    echo "  all          构建所有 App"
    echo "  help         显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 ios       # 仅构建 iOS App"
    echo "  $0 all       # 构建所有 App"
}

# 主函数
main() {
    create_build_dir

    case "${1:-help}" in
        ios)
            build_ios
            ;;
        android)
            build_android
            ;;
        harmonyos)
            build_harmonyos
            ;;
        all)
            build_ios
            build_android
            build_harmonyos
            ;;
        help|*)
            show_help
            ;;
    esac

    print_success "构建完成！"
    print_info "构建产物位于: $BUILD_DIR"
}

main "$@"
