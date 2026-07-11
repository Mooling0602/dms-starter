#!/usr/bin/env fish

set -l expected_user mooling
set -l expected_host mooling-laptop
set -l use_askpass false

for argument in $argv
    switch $argument
        case --askpass
            set use_askpass true
        case '*'
            echo "Usage: "(status filename)" [--askpass]"
            exit 2
    end
end

if test (id -un) != $expected_user; or test (hostname) != $expected_host
    echo "Host is not matched. You should update flake inputs and rebuild the system by yourself, this script is designed for Mooling0602 (the repo maintainer) only."
    exit 1
end

set -l repo_root (cd (dirname (status filename)); and pwd)
set -l github_token (gh auth token)
or exit 1

cd $repo_root
or exit 1

env NIX_CONFIG="extra-access-tokens = github.com=$github_token" nix flake update
or exit 1

if $use_askpass
    set -l askpass_command (command -v ksshaskpass)
    set -l pkexec_command (command -v pkexec)

    if test -n "$askpass_command"
        SUDO_ASKPASS=$askpass_command sudo -A nixos-rebuild switch --flake "$repo_root#$expected_host"
    else if test -n "$pkexec_command"
        $pkexec_command nixos-rebuild switch --flake "$repo_root#$expected_host"
    else
        sudo nixos-rebuild switch --flake "$repo_root#$expected_host"
    end
else
    sudo nixos-rebuild switch --flake "$repo_root#$expected_host"
end
