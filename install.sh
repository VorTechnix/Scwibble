#!/usr/bin/bash

SRC="$(dirname $0)/scwibble.sh"
TARG="/usr/local/bin/scwibble"

function install {
    cat <<EOF
Now installing Scwibble to
$TARG

Run 'install.sh -u' to uninstall
EOF

    cd "$(dirname $0)"

    # sudo cp $SRC $TARG && sudo chmod +x $TARG
}

function uninstall {
    cat <<EOF
Now uninstalling Scwibble from
${TARG%/*}
EOF

    # sudo rm "$TARG"
}

if [[ $1 = '-u' ]] then
    uninstall
else
    install
fi