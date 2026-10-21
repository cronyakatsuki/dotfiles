default:
    @just --list

# snapshot /etc daemon configs into the repo (safe to run anytime)
sync-daemon-configs:
    mkdir -p daemon-configs/lact daemon-configs/coolercontrol daemon-configs/nix daemon-configs/udev daemon-configs/sbin
    cp /etc/lact/config.yaml daemon-configs/lact/
    cp /etc/coolercontrol/{config.toml,config-ui.json,modes.json,alerts.json,overrides.toml,calibrations.json} daemon-configs/coolercontrol/
    cp /etc/nix/nix.conf daemon-configs/nix/
    cp /etc/udev/rules.d/90-c922-preset.rules /etc/udev/rules.d/99-intel-rapl.rules /etc/udev/rules.d/99-silakka54-no-joystick.rules daemon-configs/udev/
    cp /usr/local/sbin/c922-preset-apply daemon-configs/sbin/

# restore /etc daemon configs after a fresh distro install (needs sudo to write /etc)
# NOTE: daemons are stopped first — coolercontrold/lactd overwrite these files with
# their in-memory state on exit/restart, so restoring while running gets clobbered
restore-daemon-configs:
    sudo systemctl stop coolercontrold lactd || true
    sudo mkdir -p /etc/lact /etc/coolercontrol
    sudo cp daemon-configs/lact/config.yaml /etc/lact/
    sudo cp daemon-configs/coolercontrol/{config.toml,config-ui.json,modes.json,alerts.json,overrides.toml,calibrations.json} /etc/coolercontrol/
    sudo mkdir -p /etc/nix
    sudo cp daemon-configs/nix/nix.conf /etc/nix/
    sudo cp daemon-configs/udev/90-c922-preset.rules /etc/udev/rules.d/
    sudo cp daemon-configs/udev/99-intel-rapl.rules /etc/udev/rules.d/
    sudo cp daemon-configs/udev/99-silakka54-no-joystick.rules /etc/udev/rules.d/
    sudo cp daemon-configs/sbin/c922-preset-apply /usr/local/sbin/
    sudo chmod +x /usr/local/sbin/c922-preset-apply
    sudo udevadm control --reload
    sudo systemctl start coolercontrold lactd

# reinstall all pi agent extensions (package list lives in ~/.pi/agent/settings.json)
pi-extensions:
    pi install npm:@zhushanwen/pi-model-switch
    pi install npm:pi-shift-router
    pi install npm:pi-subagents
    pi install npm:pi-web-research
    pi install npm:@mjakl/pi-kagi-api
    pi install npm:pi-memory
    pi install npm:checkpoint-pi
    pi install npm:pi-agent-extensions
    pi install npm:pi-catppuccin
    pi install npm:pi-lens
    pi install npm:@0xkahi/pi-vim-keys
