#!/bin/bash

# exit script if return code != 0
set -e

# build scripts
####

# download build scripts from github
curl --connect-timeout 5 --max-time 600 --retry 5 --retry-delay 0 --retry-max-time 60 -o /tmp/scripts-master.zip -L https://github.com/binhex/scripts/archive/master.zip

# unzip build scripts
unzip /tmp/scripts-master.zip -d /tmp

# move shell scripts to /root
mv /tmp/scripts-master/shell/arch/docker/*.sh /root/

# pacman packages
####

# define pacman packages
pacman_packages="jre8-openjdk-headless"

# install compiled packages using pacman
if [[ ! -z "${pacman_packages}" ]]; then
	pacman -S --needed $pacman_packages --noconfirm
fi

# aor packages
####

# define arch official repo (aor) packages
aor_packages="libepubgen libqxp libstaroffice libfreehand libreoffice-fresh"

# call aor script (arch official repo)
source /root/aor.sh

# aur packages
####

# define aur packages
aur_packages=""

# call aur install script (arch user repo)
source /root/aur.sh

# config libreoffice
####

cat <<'EOF' > /tmp/startcmd_heredoc
# run dbus as a session (terminates with app) for app libreoffice, used for this single auto start of libreoffice
dbus-run-session -- libreoffice -env:UserInstallation=file:///config/libreoffice
EOF

# replace startcmd placeholder string with contents of file (here doc)
sed -i '/# STARTCMD_PLACEHOLDER/{
    s/# STARTCMD_PLACEHOLDER//g
    r /tmp/startcmd_heredoc
}' /home/nobody/start.sh
rm /tmp/startcmd_heredoc

# config novnc
###

# overwrite novnc favicon with application favicon
cp /home/nobody/favicon.ico /usr/share/novnc/

# config openbox
####

cat <<'EOF' > /tmp/menu_heredoc
    <item label="LibreOffice Fresh">
    <action name="Execute">
      <command>libreoffice -env:UserInstallation=file:///config/libreoffice</command>
      <startupnotify>
        <enabled>yes</enabled>
      </startupnotify>
    </action>
    </item>
EOF

# replace menu placeholder string with contents of file (here doc)
sed -i '/<!-- APPLICATIONS_PLACEHOLDER -->/{
    s/<!-- APPLICATIONS_PLACEHOLDER -->//g
    r /tmp/menu_heredoc
}' /home/nobody/.config/openbox/menu.xml
rm /tmp/menu_heredoc

# container perms
####

# define comma separated list of paths 
install_paths="/tmp,/usr/share/themes,/home/nobody,/usr/share/novnc/usr/include/libreoffice,/usr/lib/libreoffice,/usr/share/libreoffice,/usr/share/idl/libreoffice,/usr/share/applications/,/etc/xdg"

# split comma separated string into list for install paths
IFS=',' read -ra install_paths_list <<< "${install_paths}"

# process install paths in the list
for i in "${install_paths_list[@]}"; do

	# confirm path(s) exist, if not then exit
	if [[ ! -d "${i}" ]]; then
		echo "[crit] Path '${i}' does not exist, exiting build process..." ; exit 1
	fi

done

# convert comma separated string of install paths to space separated, required for chmod/chown processing
install_paths=$(echo "${install_paths}" | tr ',' ' ')

# create file with contents of here doc, note EOF is NOT quoted to allow us to expand current variable 'install_paths'
# we use escaping to prevent variable expansion for PUID and PGID, as we want these expanded at runtime of init.sh
# note - do NOT double quote variable for install_paths otherwise this will wrap space separated paths as a single string
cat <<EOF > /tmp/permissions_heredoc
# set permissions inside container
chown -R "\${PUID}":"\${PGID}" ${install_paths}
chmod -R 775 ${install_paths}

EOF

# replace permissions placeholder string with contents of file (here doc)
sed -i '/# PERMISSIONS_PLACEHOLDER/{
    s/# PERMISSIONS_PLACEHOLDER//g
    r /tmp/permissions_heredoc
}' /root/init.sh
rm /tmp/permissions_heredoc

# env vars
####

# cleanup
yes|pacman -Scc
rm -rf /usr/share/locale/*
rm -rf /usr/share/man/*
rm -rf /usr/share/gtk-doc/*
rm -rf /tmp/*
