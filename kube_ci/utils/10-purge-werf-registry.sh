#!/bin/bash
# Очистка: полный сброс werf-кеша хоста и docker-образов werf.

source "$(~/bin/trdl use werf 2 stable)"

werf host cleanup
werf host purge

for pattern in 'werf-images' 'werf-stages' 'werf-managed'; do
    for image in $(docker images | grep "$pattern" | awk '{print $3}'); do
        docker image rm "$image"
    done
done
