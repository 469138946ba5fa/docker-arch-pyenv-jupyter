#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

log_info "Starting pyenv environment setup..."

# 初始化 pyenv 环境
#export PYENV_ROOT="${HOME}/.pyenv"
#[[ -d ${PYENV_ROOT}/bin ]] && export PATH="${PYENV_ROOT}/bin:${PATH}"

# 安装 pyenv
curl https://pyenv.run | bash

# 更新 pyenv
cd ${PYENV_ROOT}/ && git pull && cd /tmp

# 将激活环境写入配置文件中，保留长期有效
# 在 docker 非交互式容器中毫无意义，可以没有，但是我希望，这能帮助我理解
cat << '469138946ba5fa' | tee -a /etc/environment "${HOME}/.profile"
export PYENV_ROOT="${HOME}/.pyenv"
[[ -d ${PYENV_ROOT}/bin ]] && export PATH="${PYENV_ROOT}/bin:${PATH}"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
469138946ba5fa

# 获取当前 shell 名称
CURRENT_SHELL=$(basename "${SHELL}")

log_info "Detected shell: ${CURRENT_SHELL}"

case "${CURRENT_SHELL}" in
  bash)
    if ! grep -qEi 'PYENV_ROOT' "${HOME}/.bashrc"; then
      log_info "Initializing PYENV_ROOT for bash..."
      # 固化 PYENV_ROOT 环境
      # 在 docker 非交互式容器中毫无意义，可以没有，但是我希望，这能帮助我理解
      cat << '469138946ba5fa' | tee -a /etc/skel/.bashrc "${HOME}/.bashrc"
export PYENV_ROOT="${HOME}/.pyenv"
[[ -d ${PYENV_ROOT}/bin ]] && export PATH="${PYENV_ROOT}/bin:${PATH}"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
469138946ba5fa
    fi
    ;;
  zsh)
    if ! grep -qEi 'PYENV_ROOT' "${HOME}/.zshrc"; then
      log_info "Initializing PYENV_ROOT for zsh..."
      # 固化 PYENV_ROOT 环境
      # 在 docker 非交互式容器中毫无意义，可以没有，但是我希望，这能帮助我理解
      cat << '469138946ba5fa' | tee -a /etc/skel/.zshrc "${HOME}/.zshrc"
export PYENV_ROOT="${HOME}/.pyenv"
[[ -d ${PYENV_ROOT}/bin ]] && export PATH="${PYENV_ROOT}/bin:${PATH}"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
469138946ba5fa
    fi
    ;;
  *)
    log_error "Unsupported shell: ${CURRENT_SHELL}"
    exit 1
    ;;
esac

log_info "pyenv setup is complete."
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
pyenv --version