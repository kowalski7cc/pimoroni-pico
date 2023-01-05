FROM ubuntu:20.04 as builder
RUN apt update &&\
    DEBIAN_FRONTEND=noninteractive apt install -y ccache gcc-arm-none-eabi git python3 python3-pip build-essential cmake
RUN python3 -m pip install pillow
ENV MICROPYTHON_VERSION=9dfabcd6d3d080aced888e8474e921f11dc979bb
ENV BOARD_TYPE=PIMORONI_BADGER2040
ENV RELEASE_FILE=pimoroni-badger2040-micropython
# Check out MicroPython
RUN git clone https://github.com/micropython/micropython.git /micropython
# Fetch base MicroPython submodules
WORKDIR /micropython
RUN git checkout $MICROPYTHON_VERSION;\
    git submodule update --init
# Fetch Pico SDK submodules
RUN cd /micropython/lib/pico-sdk;\
    git submodule update --init
# Build mpy-cross
RUN cd /micropython/mpy-cross;\
    make
WORKDIR /pimoroni-pico
ADD . .
# HACK: MicroPython Board Fixups
RUN BUILD=$(pwd);\
    cd /micropython/ports/rp2;\
    bash /pimoroni-pico/micropython/_board/board-fixup.sh badger2040 $BOARD_TYPE /pimoroni-pico/micropython/_board
# Configure MicroPython with BadgerOS
RUN cd /micropython/ports/rp2;\
    cmake -S . -B build-${BOARD_TYPE} -DPICO_BUILD_DOCS=0 -DUSER_C_MODULES=/pimoroni-pico/micropython/modules/badger2040-micropython.cmake -DMICROPY_BOARD=${BOARD_TYPE} -DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache
# Build MicroPython
RUN cd /micropython/ports/rp2/;\
    ccache --zero-stats || true;\
    cmake --build build-$BOARD_TYPE -j 2;\
    ccache --show-stats || true
RUN mkdir -p /build && cp /micropython/ports/rp2/build-$BOARD_TYPE/firmware.uf2 /build/$RELEASE_FILE.uf2