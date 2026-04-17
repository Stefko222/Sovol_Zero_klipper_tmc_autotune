#!/bin/bash

KLIPPER_PATH="${HOME}/klipper"
AUTOTUNETMC_PATH="${HOME}/klipper_tmc_autotune"

if [[ -e ${KLIPPER_PATH}/klippy/plugins/ ]]; then
    KLIPPER_PLUGINS_PATH="${KLIPPER_PATH}/klippy/plugins/"
else
    KLIPPER_PLUGINS_PATH="${KLIPPER_PATH}/klippy/extras/"
fi

set -eu
export LC_ALL=C

function preflight_checks {
    if [ "$EUID" -eq 0 ]; then
        echo "[PRE-CHECK] This script must not be run as root!"
        exit 1
    fi

    if sudo systemctl list-units --full -all -t service --no-legend | grep -q 'klipper.service'; then
        echo "[PRE-CHECK] Klipper service found!"
    else
        echo "[ERROR] Klipper service not found, please install Klipper first!"
        exit 1
    fi

    # Try to determine the klippy virtual environment from the local Moonraker instance
    KLIPPY_PYTHON_PATH=$(wget -qO- http://localhost:7125/printer/info | python -c 'import sys, json; print(json.load(sys.stdin)["result"]["python_path"])' 2>/dev/null || true)
    # Fall back to the default location
    KLIPPY_PYTHON_PATH=${KLIPPY_PYTHON_PATH:-"${HOME}/klippy-env/bin/python"}
    # Get the major Python version
    KLIPPY_PYTHON_VERSION=$("${KLIPPY_PYTHON_PATH}" -c 'import sys; print(sys.version_info.major)')

    if [[ ${KLIPPY_PYTHON_VERSION} -lt 3 ]]; then
        echo "[ERROR] Klipper must be using Python 3 - detected outdated Python 2"
        exit 1
    else
        echo "[PRE-CHECK] Klipper is using Python 3!"
    fi

    printf "\n\n"
}

function check_download {
    local autotunedirname autotunebasename
    autotunedirname="$(dirname "${AUTOTUNETMC_PATH}")"
    autotunebasename="$(basename "${AUTOTUNETMC_PATH}")"

    if [ ! -d "${AUTOTUNETMC_PATH}" ]; then
        echo "[DOWNLOAD] Downloading Autotune TMC repository..."
        if git -C "${autotunedirname}" clone https://github.com/Stefko222/Sovol_Zero_klipper_tmc_autotune.git $autotunebasename; then
            chmod +x "${AUTOTUNETMC_PATH}"/install.sh
            printf "[DOWNLOAD] Download complete!\n\n"
        else
            echo "[ERROR] Download of Autotune TMC git repository failed!"
            exit 1
        fi
    else
        printf "[DOWNLOAD] Autotune TMC repository already found locally. Continuing...\n\n"
    fi
}

function link_extension {
    echo "[INSTALL] Linking extension to Klipper..."

    ln -srfn "${AUTOTUNETMC_PATH}/autotune_tmc.py" "${KLIPPER_PLUGINS_PATH}/autotune_tmc.py"
    ln -srfn "${AUTOTUNETMC_PATH}/motor_constants.py" "${KLIPPER_PLUGINS_PATH}/motor_constants.py"
    ln -srfn "${AUTOTUNETMC_PATH}/motor_database_sovol_zero.cfg" "${KLIPPER_PLUGINS_PATH}/motor_database.cfg"
}

function install_config {
    echo "[INSTALL] Checking for autotune_tmc.cfg..."
    
    # check config folder
    if [ -d "${KLIPPER_CONFIG_PATH}" ]; then
        # only copy if file does not exist allready
        if [ ! -f "${KLIPPER_CONFIG_PATH}/autotune_tmc.cfg" ]; then
            echo "[INSTALL] Creating autotune_tmc.cfg from template..."
            cp "${AUTOTUNETMC_PATH}/autotune_tmc.cfg" "${KLIPPER_CONFIG_PATH}/autotune_tmc.cfg"
        else
            echo "[INFO] autotune_tmc.cfg already exists. Skipping copy to protect your settings."
        fi
    else
        echo "[WARNING] Klipper config directory not found at ${KLIPPER_CONFIG_PATH}. Skipping config install."
    fi
}

function restart_klipper {
    echo "[POST-INSTALL] Restarting Klipper..."
    sudo systemctl restart klipper
}


printf "\n======================================\n"
echo "- Autotune TMC install script -"
printf "======================================\n\n"


# Run steps
preflight_checks
check_download
link_extension
install_config
restart_klipper
