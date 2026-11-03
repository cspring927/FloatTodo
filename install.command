#!/bin/bash
# FloatTodo installer: builds the app on this Mac, installs it to ~/Applications, and starts it.
# FloatTodo 安装脚本：在这台 Mac 上编译，安装到 ~/Applications，然后启动。
# No admin password needed. 不需要管理员密码。

set -u
cd "$(dirname "$0")" || exit 1

NAME="FloatTodo"
HERE="$(pwd)"
LOG="$HERE/build.log"
BUILD="$HERE/build"
BUNDLE="$BUILD/$NAME.app"
DEST_DIR="$HOME/Applications"
DEST="$DEST_DIR/$NAME.app"

fail() {
  echo
  echo "Installation failed. 没有装好。"
  echo "${1}"
  if [ -s "$LOG" ]; then
    echo
    echo "---------- Error details 错误信息 ----------"
    if grep -qE "error:|fatal|No such|not found" "$LOG"; then
      grep -E "error:|fatal|No such|not found" "$LOG" | head -20
    else
      tail -20 "$LOG"
    fi
    echo "--------------------------------------------"
    echo "Full log 完整记录: ${LOG}"
  fi
  exit 1
}

if [ "$(uname)" != "Darwin" ]; then
  fail "This script only runs on a Mac. 这个脚本只能在 Mac 上运行。"
fi

if ! xcrun --sdk macosx --find swiftc >/dev/null 2>&1; then
  echo "This Mac needs Apple's Command Line Tools. An installer window will open."
  echo "Click Install, then run this script again."
  echo "这台 Mac 还缺命令行开发工具，马上会弹出一个安装窗口。"
  echo "请点「安装」，装好之后再运行一次这个脚本。"
  xcode-select --install >/dev/null 2>&1
  exit 1
fi

for file in src/main.swift src/index.html src/settings.html src/Info.plist src/AppIcon.icns; do
  [ -f "$file" ] || fail "Can't find ${file}. Download the whole folder again. 找不到 ${file}，请重新下载完整的文件夹。"
done

mkdir -p "$BUILD"
: > "$LOG"

echo "Building (about 30 seconds)... 正在编译（大约要 30 秒）..."
xcrun --sdk macosx swiftc -O -swift-version 5 \
  -target "$(uname -m)-apple-macos11.0" \
  -framework AppKit -framework WebKit -framework Carbon \
  src/main.swift -o "$BUILD/$NAME" >>"$LOG" 2>&1 \
  || fail "The build failed. 编译出错了。"

echo "Packaging... 正在打包..."
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources" || fail "Can't create the app folder. 无法创建文件夹。"
cp "$BUILD/$NAME" "$BUNDLE/Contents/MacOS/$NAME" || fail "Can't copy the program. 复制程序失败。"
cp src/Info.plist "$BUNDLE/Contents/Info.plist" || fail "Can't copy Info.plist. 复制配置失败。"
cp src/index.html "$BUNDLE/Contents/Resources/index.html" || fail "Can't copy index.html. 复制界面失败。"
cp src/settings.html "$BUNDLE/Contents/Resources/settings.html" || fail "Can't copy settings.html. 复制设置页失败。"
cp src/AppIcon.icns "$BUNDLE/Contents/Resources/AppIcon.icns" || fail "Can't copy the icon. 复制图标失败。"
xattr -cr "$BUNDLE" 2>/dev/null
codesign --force --sign - "$BUNDLE" >>"$LOG" 2>&1 || fail "Can't sign the app. 签名失败。"

echo "Installing... 正在安装..."
pkill -x "$NAME" 2>/dev/null
for _ in 1 2 3 4 5 6 7 8 9 10; do
  pgrep -x "$NAME" >/dev/null 2>&1 || break
  sleep 0.2
done
mkdir -p "$DEST_DIR" || fail "Can't create ${DEST_DIR}. 无法创建 ${DEST_DIR}。"
rm -rf "$DEST"
cp -R "$BUNDLE" "$DEST" || fail "Can't install to ${DEST}. 安装到 ${DEST} 失败。"

open -g "$DEST" || fail "Can't start the app. 启动失败。"
sleep 1.5
if ! pgrep -x "$NAME" >/dev/null 2>&1; then
  fail "The app quit right after starting. 程序启动后马上退出了。"
fi

echo
echo "Done. FloatTodo is at the top right of your screen, with an icon in the menu bar."
echo "To open Settings, hover over the window and click the gear."
echo "装好了。小窗默认在屏幕右上角，菜单栏也多了一个图标。"
echo "设置：鼠标移到小窗上，点右上角的齿轮。"
echo "App: ${DEST}"
