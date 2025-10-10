#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

log_info "Starting clean of System..."

# Miniforge 安装路径
# export MINIFORGE_DIR=/opt/Miniforge

# 清理 APT 缓存
clean_apt() {
  log_info "清理 init_system.sh 所产生的 APT 缓存..."
  apt autoremove -y && apt clean && apt autoclean && rm -fr /var/lib/apt/lists/* || true
  #apt-get autoremove -y && apt-get clean -y && apt-get autoclean -y && rm -frv /var/lib/apt/lists/* || true
}

# 清理系统日志
clean_logs() {
  log_info "清理系统日志..."
  find /var/log -type f -name "*.log" -delete
  rm -f /var/log/*.gz /var/log/*.1 /var/log/*.old
}

# 清理临时文件
clean_temp() {
  log_info "清理临时文件..."
  rm -fr /tmp/* /var/tmp/*
}

# 清理用户缓存
clean_user_cache() {
  log_info "清理所有用户的缓存..."
  log_info "清理 root 的缓存"
  [ -d "/root/.cache" ] && rm -fr "/root/.cache"/* 2>/dev/null || true
  for user_home in /home/*; do
    [ -d "${user_home}/.cache" ] || continue
    log_info "清理 ${user_home} 的缓存"
    rm -fr "${user_home}/.cache"/* 2>/dev/null || true
  done
}

# 清理历史记录
clean_history() {
  log_info "清理命令历史记录..."
  # 清理当前用户的历史
  bash -c 'history -c' || true
  [ -f /root/.bash_history ] && shred -u /root/.bash_history 2>/dev/null || true
  [ -f /root/.zsh_history ] && shred -u /root/.zsh_history 2>/dev/null || true
  # 清理所有用户的历史
  for user_home in /home/*; do
    [ -d "${user_home}" ] && su - $(basename ${user_home}) bash -c 'history -c' 2>/dev/null || true
    [ -f "${user_home}/.bash_history" ] && shred -u "${user_home}/.bash_history" 2>/dev/null || true
    [ -f "${user_home}/.zsh_history" ] && shred -u "${user_home}/.zsh_history" 2>/dev/null || true
  done
}

# 清理资源文件
clean_src() {
  log_info "清理资源文件..."
  # 清理多架构预编译包
  rm -frv /usr/local/src/llvm-clang-cling-build-*.tar.gz 2>/dev/null || true
  # 清理依赖源码压缩包
  rm -frv /usr/local/src/llvm-project.tar.gz 2>/dev/null || true
  # 清理 .gitkeep 占位文件
  rm -frv /usr/local/src/.gitkeep 2>/dev/null || true
}

# 执行清理操作
perform_cleanup() {
  log_info "执行系统清理..."
  clean_apt
  clean_logs
  clean_temp
  clean_user_cache
  clean_history
  clean_src
}

# 主逻辑
perform_cleanup

exit 0