# ubuntu 滚动版，追求新颖，不稳定
FROM docker.io/library/ubuntu:rolling

# 构建参数，只有构建阶段有效，构建完成后消失
# init_system.sh 所需临时环境变量
ARG DEBIAN_FRONTEND=noninteractive
ARG TZ='Asia/Shanghai'
# install_pyenv.sh install_jupyter.sh 所需临时环境变量
# pip 软件源
ARG PIP_CHANNELS='https://pypi.org/simple'
# 获取pyenv版本
# 为空则返回最新稳定版，如 3.13.3
# --latest-alpha 返回最新 alpha，如 3.14.0a7t
# --latest-dev 返回最新 dev，如 3.14t-dev
# --latest-t 返回最新 t，如 3.13.3t
# 3.13.2t 如果存在就返回它，不存在则返回最新稳定版
# 3.99.9 不存在，返回 fallback 稳定版
ARG PY_VERSION=3.12.10
ARG PY_ENV=py${PY_VERSION}
# install_cling 所需临时环境变量
# 构建模式：online | local | prebuilt
# 由于互联网限制 llvm-project 在国内是无法完整 clone 的，所以我做了环境开关控制
# online 在线 clone 原始代码，自带跨平台
# local 本地资源解压编译，这个模式需要你提前准备好官方源码的 sources/llvm-project.tar.gz 压缩包文件，自带跨平台
#    我压缩的路径是在 /tmp 内的 llvm-project 所以，解压的时候我会直接解压到 /tmp 并将 llvm-project 改名为 llvm 形成 /tmp/llvm 路径，如果你想自定义需要修改 install_cling.sh 脚本中的这一部分
# prebuilt 本地资源预编译包直接安装，这个模式需要你提前准备好
#    预编译包需要依赖官方源码的 sources/llvm-project.tar.gz 压缩包文件
#    编译好的 llvm clang cling 预编译包 sources/llvm-clang-cling-build-<arch>.tar.gz ，其中 <arch> 是为了适配跨平台的系统架构：aarch64 或 x86_64（可由 uname -m 获取）
#    我编译的路径是 /tmp/llvm/llvm /tmp/cling /usr/local/share/cling/build 这三个路径，所以安装解压方式也是直接解压到 /tmp 和 /usr/local/share/cling/build 如果你想自定义需要修改 install_cling.sh 脚本中的这一部分
ARG CLING_BUILD_MODE=prebuilt
# 编译时控制占用线程数，防止 docker 环境崩溃后系统大哭小大闹
ARG CORENUM=2
# install_jdk.sh 所需临时环境变量
ARG JDK_VERSION=25
# ENV 需要固化的临时环境
ARG BUILD_HOME=/root
ARG PYENV_ROOT="${BUILD_HOME}/.pyenv"
ARG JAVA_HOME="${BUILD_HOME}/.jbang/currentjdk"
ARG CLASSPATH=".:${JAVA_HOME}/lib"
ARG PATH="${PYENV_ROOT}/bin:${BUILD_HOME}/.jbang/bin:${JAVA_HOME}/bin:${PATH}"

# 固化运行环境变量，全局构建和容器运行都可用，字符支持，安装目录，以及启动路径
# init_system.sh 所需固化环境 LANG=zh_CN.UTF-8 LC_ALL=zh_CN.UTF-8 LANGUAGE=zh_CN.UTF-8 LC_CTYPE=zh_CN.UTF-8
ENV LANG=zh_CN.UTF-8 \
    LC_ALL=zh_CN.UTF-8 \
    LANGUAGE=zh_CN.UTF-8 \
    LC_CTYPE=zh_CN.UTF-8 \
    CLASSPATH=${CLASSPATH} \
    PY_ENV=${PY_ENV} \
    PATH=${PATH}

# 添加常用LABEL（根据需要修改）添加标题 版本 作者 代码仓库 镜像说明，方便优化
LABEL org.opencontainers.image.description="pyenv 安装 jupyter notebook 封装特殊需求自用 python 测试容器." \
      org.opencontainers.image.title="Pyenv Jupyter" \
      org.opencontainers.image.version="1.0.0" \
      org.opencontainers.image.authors="469138946ba5fa <af5ab649831964@gmail.com>" \
      org.opencontainers.image.source="https://github.com/469138946ba5fa/docker-arch-pyenv-jupyter" \
      org.opencontainers.image.licenses="MIT"

# 设置工作目录 /notebook 仅用于 Notebook 数据挂载（保持干净）
WORKDIR /notebook

# 复制所有脚本到 /usr/local/bin（保持工作目录干净）
# 执行安装与配置脚本（全部以 root 执行）
COPY scripts/ /usr/local/bin/
# 复制离线资源如果存在的话
COPY sources/ /usr/local/src/

# 执行 初始化 安装 清理 三大流程
# 移除残留脚本 init_system.sh install_pyenv.sh install_jupyter.sh install_cling.sh install_jbang.sh install_jdk.sh clean.sh
# 保留日志脚本 common.sh
# 启动脚本 start_jupyter.sh
# analyze_size.sh 检查安装前、后与清理后的镜像大小记录变化，不过镜像似乎无法优化了，😮‍💨
# 总结：似乎镜像无法优化了，已到绝处，无法逢生，在绝对的力量面前任何优化手段都毫无意义😮‍💨
# analyze_size.sh after-install before-install
# analyze_size.sh after-clean after-install
RUN cd /usr/local/bin/ && \
    chmod -v a+x *.sh && \
    analyze_size.sh before-install && \
    init_system.sh && \
    install_pyenv.sh && \
    install_jupyter.sh && \
    install_cling.sh && \
    install_jbang.sh && \
    install_jdk.sh && \
    analyze_size.sh after-install && \
    clean.sh && \
    rm -fv init_system.sh install_pyenv.sh install_jupyter.sh install_cling.sh install_jbang.sh install_jdk.sh clean.sh && \
    analyze_size.sh after-clean

# 固化端口
EXPOSE 8888
# 健康检查
HEALTHCHECK CMD curl -f http://localhost:8888 || exit 1

# 使用 tini 作为入口，调用 entrypoint 脚本或者直接启动 /usr/local/bin/start_jupyter.sh
ENTRYPOINT ["tini", "--"]
# 脚本执行
CMD [ "/usr/local/bin/start_jupyter.sh" ]
