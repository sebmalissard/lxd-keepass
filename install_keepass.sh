#!/bin/bash -e

LXD_CONTAINER_NAME="keepass"


debug()
{
    echo -e "DEBUG: $*"
}

info()
{
    echo -e "\e[1mINFO: $*\e[0m"
}

warning()
{
    echo -e "\e[1;93mWARNING: $*\e[0m"
}

# Replace the first argument by the second argument in a file (third argument)
substitute()
{
    if [ "$(lxc exec ${LXD_CONTAINER_NAME} -- grep -c "$1" "$3")" != "1" ]; then
        warning "'grep' command fail or invalid number of pattern match (expected only one match)."
    else
        lxc exec ${LXD_CONTAINER_NAME} -- sed "s|$1|$2|" -i "$3" \
            || warning "'sed' command fail."
    fi
}

info "Create and configure container ${LXD_CONTAINER_NAME}..."

lxc launch images:alpine/3.13 ${LXD_CONTAINER_NAME}
lxc config device add ${LXD_CONTAINER_NAME} port55002 proxy listen=tcp:0.0.0.0:55002 connect=tcp:127.0.0.1:22

# Waiting container startup
sleep 1


info "Install packages..."
lxc exec ${LXD_CONTAINER_NAME} -- apk update
lxc exec ${LXD_CONTAINER_NAME} -- apk upgrade
lxc exec ${LXD_CONTAINER_NAME} -- apk add openssh


info "Disable ssh password authentication..."
substitute "#PasswordAuthentication yes" "PasswordAuthentication no" "/etc/ssh/sshd_config"


info "Add sshd service..."
lxc exec ${LXD_CONTAINER_NAME} -- rc-update add sshd default
lxc exec ${LXD_CONTAINER_NAME} -- rc-service sshd start


info "Setup keepass user..."
lxc exec ${LXD_CONTAINER_NAME} -- adduser -D -h /home/keepass keepass
# Allow login with keepass user with other method than password (ssh keys)
substitute "keepass:!:" "keepass:*:" "/etc/shadow"


info "Setup keepass authorized_keys..."
lxc exec ${LXD_CONTAINER_NAME} -- mkdir /home/keepass/.ssh
lxc exec ${LXD_CONTAINER_NAME} -- touch /home/keepass/.ssh/authorized_keys
lxc exec ${LXD_CONTAINER_NAME} -- chown -R keepass:keepass /home/keepass/
lxc exec ${LXD_CONTAINER_NAME} -- chmod 700 /home/keepass/.ssh
lxc exec ${LXD_CONTAINER_NAME} -- chmod 600 /home/keepass/.ssh/authorized_keys


info "Reboot container ${LXD_CONTAINER_NAME}..."
lxc exec ${LXD_CONTAINER_NAME} -- reboot

info ""
info "Need to add all devices public key in /home/keepass/.ssh/authorized_keys"
info "Copy the password database in /home/keepass/Passwords.kdbx"
