# Autodetect script's home directory
SCRIPT_DIR=`dirname "$(readlink -f "${BASH_SOURCE[0]}")"`
BASE_DIR="$(cd $SCRIPT_DIR/../ && pwd)"

export PATH=$BASE_DIR/bin:$BASE_DIR/scripts:$PATH
