#!/bin/bash

# Remoção de arquivos de compilaçoes anteriores
sudo rm -rfv $HOME/tigerOS;mkdir -pv $HOME/tigerOS

# Criação do sistema base
sudo debootstrap \
    --arch=amd64 \
    --variant=minbase \
    --components=main,multiverse,universe \
    focal \
    $HOME/tigerOS/chroot
#    --include=fish \

# Primeira etapa da montagem do enjaulamento do sistema base
sudo mount --bind /dev $HOME/tigerOS/chroot/dev
sudo mount --bind /run $HOME/tigerOS/chroot/run
sudo chroot $HOME/tigerOS/chroot mount none -t proc /proc
sudo chroot $HOME/tigerOS/chroot mount none -t devpts /dev/pts
sudo chroot $HOME/tigerOS/chroot sh -c "export HOME=/root"
echo "tigerOS" | sudo tee $HOME/tigerOS/chroot/etc/hostname

# Adição dos repositórios principais do Ubuntu
cat <<EOF | sudo tee $HOME/tigerOS/chroot/etc/apt/sources.list
deb http://br.archive.ubuntu.com/ubuntu/ focal main restricted universe multiverse
deb http://br.archive.ubuntu.com/ubuntu/ focal-security main restricted universe multiverse
deb http://br.archive.ubuntu.com/ubuntu/ focal-updates main restricted universe multiverse
EOF

# Repositórios adicionais
#sudo chroot $HOME/tigerOS/chroot apt update
#sudo chroot $HOME/tigerOS/chroot apt install -y software-properties-common
# PPA 1
#sudo chroot $HOME/tigerOS/chroot add-apt-repository -yn ppa:usuário/programa
# PPA 2
#sudo chroot $HOME/tigerOS/chroot add-apt-repository -y ppa:usuário/programa
# Apt repo
#echo 'deb https://domínio.com/programa ./ main' | sudo tee $HOME/tigerOS/chroot/etc/apt/sources.list.d/programa.list
#wget -O- https://domínio.com/program/programa.key | gpg --dearmor | sudo tee $HOME/tigerOS/chroot/etc/apt/trusted.gpg.d/programa.gpg

# Segunda etapa da montagem do enjaulamento
sudo chroot $HOME/tigerOS/chroot apt update
sudo chroot $HOME/tigerOS/chroot apt install -y systemd-sysv
sudo chroot $HOME/tigerOS/chroot sh -c "dbus-uuidgen > /etc/machine-id"
sudo chroot $HOME/tigerOS/chroot ln -fs /etc/machine-id /var/lib/dbus/machine-id
sudo chroot $HOME/tigerOS/chroot dpkg-divert --local --rename --add /sbin/initctl
sudo chroot $HOME/tigerOS/chroot ln -s /bin/true /sbin/initctl

# Variáveis de ambiente para execução automatizada do script
sudo chroot $HOME/tigerOS/chroot sh -c "echo 'grub-pc grub-pc/install_devices_empty   boolean true' | debconf-set-selections"
sudo chroot $HOME/tigerOS/chroot sh -c "echo 'locales locales/locales_to_be_generated multiselect pt_BR.UTF-8 UTF-8' | debconf-set-selections"
sudo chroot $HOME/tigerOS/chroot sh -c "echo 'locales locales/default_environment_locale select pt_BR.UTF-8' | debconf-set-selections"
sudo chroot $HOME/tigerOS/chroot sh -c "echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections"
sudo chroot $HOME/tigerOS/chroot sh -c "echo 'resolvconf resolvconf/linkify-resolvconf boolean false' | debconf-set-selections"

# Ferramentas base do Ubuntu
sudo chroot $HOME/tigerOS/chroot apt install -y --fix-missing \
    casper \
    discover \
    laptop-detect \
    linux-generic \
    locales \
    lupin-casper \
    net-tools \
    network-manager \
    os-prober \
    resolvconf \
    xubuntu-core \
    wireless-tools

# Ambiente de desktop
sudo chroot $HOME/tigerOS/chroot apt install -y xubuntu-core

# Programas inclusos no sistema sem os extras recomendados
#sudo chroot $HOME/tigerOS/chroot apt install -y --no-install-recommends \
#    programa1 \
#    programa2 \
#    programa3

# Programas inclusos no sistema
#sudo chroot $HOME/tigerOS/chroot apt install -y \

leafpad
gnome-software
gdebi
tilix
timeshift
galculator
hplip
catfish
flatpack
gparted
synaptic
evince
xviewer
cups
rar
zip
p7zip

# Programas que não estão nos repositórios do Ubuntu
# Programa
#sudo wget -O $HOME/tigerOS/chroot/programa.deb https://domínio.com/programa.deb
#sudo chroot $HOME/tigerOS/chroot sh -c "apt install -y ./programa.deb";sudo rm -rfv $HOME/tigerOS/chroot/programa*.deb

# Ubiquity(instalador do sistema)
sudo chroot $HOME/tigerOS/chroot apt install -y \
    gparted \
    ubiquity \
    ubiquity-casper \
    ubiquity-frontend-gtk \
    ubiquity-slideshow-xubuntu

# Remoção de pacotes desnecessários
#sudo chroot $HOME/tigerOS/chroot apt autoremove --purge -y \
#    programa1 \
#    programa2 \
#    programa3

# Atualização do sistema
sudo chroot $HOME/tigerOS/chroot apt dist-upgrade -y

# Reconfiguração da rede
sudo chroot $HOME/tigerOS/chroot apt install --reinstall resolvconf
cat <<EOF | sudo tee $HOME/tigerOS/chroot/etc/NetworkManager/NetworkManager.conf
[main]
rc-manager=resolvconf
plugins=ifupdown,keyfile
dns=dnsmasq
[ifupdown]
managed=false
EOF
sudo chroot $HOME/tigerOS/chroot dpkg-reconfigure network-manager

# Desmontagem do enjaulamento
sudo chroot $HOME/tigerOS/chroot truncate -s 0 /etc/machine-id
sudo chroot $HOME/tigerOS/chroot rm /sbin/initctl
sudo chroot $HOME/tigerOS/chroot dpkg-divert --rename --remove /sbin/initctl
sudo chroot $HOME/tigerOS/chroot apt clean
sudo chroot $HOME/tigerOS/chroot rm -rfv /tmp/* ~/.bash_history
sudo chroot $HOME/tigerOS/chroot umount /proc
sudo chroot $HOME/tigerOS/chroot umount /dev/pts
sudo chroot $HOME/tigerOS/chroot sh -c "export HISTSIZE=0"
sudo umount $HOME/tigerOS/chroot/dev
sudo umount $HOME/tigerOS/chroot/run

# Configuração do GRUB
echo "RESUME=none" | sudo tee $HOME/tigerOS/chroot/etc/initramfs-tools/conf.d/resume
echo "FRAMEBUFFER=y" | sudo tee $HOME/tigerOS/chroot/etc/initramfs-tools/conf.d/splash

# Layout português brasileiro para o teclado
sudo sed -i 's/us/br/g' $HOME/tigerOS/chroot/etc/default/keyboard

# Criação dos arquivos de inicialização da imagem de instalação
cd $HOME/tigerOS
mkdir -pv image/{boot/grub,casper,isolinux,preseed}
# Kernel
sudo cp chroot/boot/vmlinuz image/casper/vmlinuz
sudo cp chroot/boot/`ls -t1 chroot/boot/ |  head -n 1` image/casper/initrd
touch image/Ubuntu
# GRUB
cat <<EOF > image/isolinux/grub.cfg
search --set=root --file /tigerOS
insmod all_video
set default="0"
set timeout=15

if loadfont /boot/grub/unicode.pf2 ; then
    insmod gfxmenu
	insmod jpeg
	insmod png
	set gfxmode=auto
	insmod efi_gop
	insmod efi_uga
	insmod gfxterm
	terminal_output gfxterm
fi

menuentry "tigerOS(live-mode)" {
   linux /casper/vmlinuz file=/cdrom/preseed/tigerOS.seed boot=casper quiet splash locale=pt_BR ---
   initrd /casper/initrd
}
EOF
# Loopback
cat <<EOF > image/boot/grub/loopback.cfg
menuentry "tigerOS(live-mode)" {
   linux /casper/vmlinuz file=/cdrom/preseed/tigerOS.seed boot=casper quiet splash iso-scan/filename=\${iso_path} locale=pt_BR ---
   initrd /casper/initrd
}
EOF
# Preesed
cat <<EOF > image/preseed/tigerOS.seed
# Success command
#d-i ubiquity/success_command string \
sed -i 's/quiet splash/quiet splash loglevel=0 logo.nologo vt.global_cursor_default=0/g' /target/etc/default/grub ; \
chroot /target update-grub
EOF
# Arquivos de manifesto
sudo chroot chroot dpkg-query -W --showformat='${Package} ${Version}\n' | sudo tee image/casper/filesystem.manifest
sudo cp -v image/casper/filesystem.manifest image/casper/filesystem.manifest-desktop
sudo sed -i '/ubiquity/d' image/casper/filesystem.manifest-desktop
sudo sed -i '/casper/d' image/casper/filesystem.manifest-desktop
sudo sed -i '/discover/d' image/casper/filesystem.manifest-desktop
sudo sed -i '/laptop-detect/d' image/casper/filesystem.manifest-desktop
sudo sed -i '/os-prober/d' image/casper/filesystem.manifest-desktop
#echo "\
#programa1 \
#programa2 \
#programa3" | sudo tee image/casper/filesystem.manifest-remove
# SquashFS
sudo mksquashfs chroot image/casper/filesystem.squashfs -comp xz
printf $(sudo du -sx --block-size=1 chroot | cut -f1) > image/casper/filesystem.size
# Definições de disco
cat <<EOF > image/README.diskdefines
#define DISKNAME  tigerOS
#define TYPE  binary
#define TYPEbinary  1
#define ARCH  amd64
#define ARCHamd64  1
#define DISKNUM  1
#define DISKNUM1  1
#define TOTALNUM  0
#define TOTALNUM0  1
EOF

# Geração do GRUB para imagem de instalação
cd $HOME/tigerOS/image
grub-mkstandalone \
   --format=x86_64-efi \
   --output=isolinux/bootx64.efi \
   --locales="" \
   --fonts="" \
   "boot/grub/grub.cfg=isolinux/grub.cfg"
(
   cd isolinux && \
   dd if=/dev/zero of=efiboot.img bs=1M count=10 && \
   sudo mkfs.vfat efiboot.img && \
   mmd -i efiboot.img efi efi/boot && \
   mcopy -i efiboot.img ./bootx64.efi ::efi/boot/
)
grub-mkstandalone \
   --format=i386-pc \
   --output=isolinux/core.img \
   --install-modules="linux16 linux normal iso9660 biosdisk memdisk search tar ls" \
   --modules="linux16 linux normal iso9660 biosdisk search" \
   --locales="" \
   --fonts="" \
   "boot/grub/grub.cfg=isolinux/grub.cfg"
cat /usr/lib/grub/i386-pc/cdboot.img isolinux/core.img > isolinux/bios.img

# Geração do MD5 interno da imagem de instalação
sudo /bin/bash -c '(find . -type f -print0 | xargs -0 md5sum | grep -v "\./md5sum.txt" > md5sum.txt)'

# Compilação da imagem de instalação
mkdir -pv ../iso
sudo xorriso \
   -as mkisofs \
   -iso-level 3 \
   -full-iso9660-filenames \
   -volid "tigerOS" \
   -eltorito-boot boot/grub/bios.img \
   -no-emul-boot \
   -boot-load-size 4 \
   -boot-info-table \
   --eltorito-catalog boot/grub/boot.cat \
   --grub2-boot-info \
   --grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img \
   -eltorito-alt-boot \
   -e EFI/efiboot.img \
   -no-emul-boot \
   -append_partition 2 0xef isolinux/efiboot.img \
   -output "../iso/tigerOS.iso" \
   -graft-points \
      "." \
      /boot/grub/bios.img=isolinux/bios.img \
      /EFI/efiboot.img=isolinux/efiboot.img

# Geração do MD5 externo da imagem de instalação.
md5sum ../iso/tigerOS.iso > ../iso/tigerOS.md5
