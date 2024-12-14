#!/usr/bin/env bash

crictl rmi --prune
docker system prune -af
apt clean