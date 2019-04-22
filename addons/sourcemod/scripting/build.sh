#!/bin/bash -e
cd "$(dirname "$0")"

test -e compiled || mkdir compiled

if [[ $# -ne 0 ]]; then
    for sourcefile in "$@"
    do
        smxfile="`echo $sourcefile | sed -e 's/\.sp$/\.smx/'`"
        echo -e "\nCompiling $sourcefile..."
        ./spcomp $sourcefile -o compiled/$smxfile
    done
else
    for sourcefile in *.sp
    do
        smxfile="`echo $sourcefile | sed -e 's/\.sp$/\.smx/'`"
        echo -e "\nCompiling $sourcefile ..."
        ./spcomp $sourcefile -o compiled/$smxfile
    done
fi
