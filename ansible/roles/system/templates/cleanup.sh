#!/usr/bin/env bash

/usr/local/bin/crictl rmi --prune
/usr/bin/docker system prune -af
/usr/bin/apt clean