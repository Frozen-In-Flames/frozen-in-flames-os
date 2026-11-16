{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # Foundation (Linux and FreeBSD are handled in default.nix and services.nix)
    systemd
    qemu
    openssl
    curl
    gcc
    llvm

    # Runtimes
    nodejs
    typescript
    ruby
    php
    go
    rustc
    cargo
    dotnet-sdk_8
    (python3.withPackages (ps: [ ps.torch ps.tensorflow ]))

    # Delivery
    git
    docker
    kubectl
    nginx
    apacheHttpd

    # Data
    postgresql
    redis

    # Web
    chromium
    firefox

    # Media
    ffmpeg
    vlc
    blender
    libreoffice

    # Editors (VSCodium is the open source build of VS Code)
    vscodium
    vim
    neovim

    # Smart home
    home-assistant
  ];
}
