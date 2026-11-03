#!/bin/bash
# Removes FloatTodo. Your tasks are kept until you delete the folder named below.
# 卸载 FloatTodo。任务数据默认保留，如果也不要了，手动删除下面提示的文件夹。

pkill -x FloatTodo 2>/dev/null
rm -f "$HOME/Library/LaunchAgents/local.floattodo.plist"
rm -rf "$HOME/Applications/FloatTodo.app"
defaults delete local.floattodo 2>/dev/null

echo "FloatTodo is uninstalled. FloatTodo 已卸载。"
echo "Your tasks are still in 任务数据还留在: ${HOME}/Library/Application Support/FloatTodo"
echo "Delete that folder if you don't want them. 如果也不要了，手动删掉这个文件夹就行。"
