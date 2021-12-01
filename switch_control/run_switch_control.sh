#!/bin/bash
DIRECTORY=$(cd `dirname $0` && pwd)
export PATH=$SDE_INSTALL/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/lib:$SDE_INSTALL/lib:$LD_LIBRARY_PATH

sudo -E env "PATH=$PATH" "LD_LIBRARY_PATH=$LD_LIBRARY_PATH" "$DIRECTORY/build/tofino_switch_control" $1 $2 $3 $4 $5 $6 $7 $8 $9 $10 $11 $12 $13 $14 $15