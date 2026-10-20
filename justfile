default:
    @just --list

# snapshot /etc daemon configs into the repo (safe to run anytime)
sync-daemon-configs:
    mkdir -p daemon-configs/lact daemon-configs/coolercontrol
    cp /etc/lact/config.yaml daemon-configs/lact/
    cp /etc/coolercontrol/{config.toml,config-ui.json,modes.json,alerts.json,overrides.toml,calibrations.json} daemon-configs/coolercontrol/

# restore /etc daemon configs after a fresh distro install (needs sudo to write /etc)
restore-daemon-configs:
    sudo cp daemon-configs/lact/config.yaml /etc/lact/
    sudo cp daemon-configs/coolercontrol/{config.toml,config-ui.json,modes.json,alerts.json,overrides.toml,calibrations.json} /etc/coolercontrol/
    sudo systemctl restart lactd coolercontrold

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
    # NOTE: the two pi-agent-extensions exclusions (powerline-footer, cwd-history)
    # live only in ~/.pi/agent/settings.json — restore that file (or re-add the
    # "!extensions/..." entries) or those extensions will come back on reinstall.
