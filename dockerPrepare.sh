#!/bin/sh

docker build --build-arg USERNAME=$(whoami) --build-arg  CUSTOM_PATH=$(pwd) --build-arg UID=$(id -u) -t wizard-$(whoami) .

docker run --rm --privileged --memory="16g" --memory-swap="16g" --user $(id -u):$(id -g)  -it --name container-$(whoami) -v $(pwd):$(pwd) --hostname WIZARD-DOCKER wizard-$(whoami)
