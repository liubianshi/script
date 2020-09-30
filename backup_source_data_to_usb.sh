#!/usr/bin/env bash
set -e

func() {
    echo "Usage:"
    echo "  $(basename $0) [-u] [-f S_DIR] [-t D_DIR]"
    echo "  Description:"
    echo "    -u        update S_DIR form D_DIR, default backup S_DIR to D_DIR"
    echo "    S_DIR     the path of source"
    echo "    D_DIR     the path of destination."
    exit -1
}

while getopts 'f:t:uh' OPT; do
    case $OPT in
        f) S_DIR="$OPTARG";;
        t) D_DIR="$OPTARG";;
        u) upload="true";;
        h) func;;
        *) func;;
    esac
done
shift $(($OPTIND - 1))

S_DIR="${S_DIR:-$HOME/Data/source_data}"
D_DIR="${D_DIR:-/run/media/liubianshi/Samsung_T3}"

dir "$S_DIR" >/dev/null || exit 2
dir "$D_DIR" >/dev/null || exit 2


if [[ -z $upload ]]; then
    rsync -avP $S_DIR/[0-9]* $D_DIR
else
    rsync -avP $D_DIR/[0-9]* $S_DIR
fi


