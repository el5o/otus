# Задание 1. Обновление ядра системы

## Описание задания
1. Запустить ВМ c Ubuntu.
2. Обновить ядро ОС на новейшую стабильную версию из mainline-репозитория.
3. Оформить отчет в README-файле в GitHub-репозитории.

## Возникшие проблемы

Следуя примеру из методички при выполнении команды `sudo dpkg -i *.deb` я столкнулся с ошибкой:
```bash
dpkg: зависимости пакетов не позволяют настроить пакет linux-modules-6.19.11-061911-generic:
 linux-modules-6.19.11-061911-generic зависит от linux-main-modules-zfs-6.19.11-061911-generic, однако:
  Пакет linux-main-modules-zfs-6.19.11-061911-generic не установлен.
```

## Решение

Так как для сборки модуля zfs всё равно нужны исходники ядра, было решено собрать и ядро, и модули из исходных кодов.

### 1. Проверка текущей версии ядра:
```bash
uname -r
6.8.0-107-generic
```

### 2. Установка утилит для сборки:
```bash
sudo apt install build-essential libncurses-dev bc flex bison libssl-dev libelf-dev dwarves git fakeroot zstd libtool automake autoconf pkg-config flex bison
```

### 3. Скачивание и распаковка исходных кодов ядра
```bash
wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.19.11.tar.xz
tar -xJf linux-6.19.11.tar.xz
```

### 4. Конфигурация ядра
```bash
cd linux-6.19.11
cp /boot/config-$(uname -r) .config
make localmodconfig
```

> #### Если возникла ошибка needed by 'certs/x509_revocation_list
> Требуется либо добавить список отозванных сертификатов в debian/canonical-revoked-certs.pem, либо исключить из .config параметр CONFIG_SYSTEM_REVOCATION_LIST.
>
> Это можно сделать в псевдографическом интерфейсе:
> 1. Запустить `make menuconfig`.
> 2. Перейти в раздел "Cryptographic API" → "Certificates for signature checking".
> 3. Отключить параметр "CONFIG_SYSTEM_REVOCATION_LIST".
> 4. Сохранить конфигурацию (Save → Exit)

### 5. Сборка ядра
```bash
make -j$(nproc)
make modules_install
```

### 6. Установка ядра и вывод об успешной установке, генерации initramfs и обновлении конфигурации grub
```bash
make install
  INSTALL /boot
run-parts: executing /etc/kernel/postinst.d/dkms 6.19.11 /boot/vmlinuz-6.19.11
 * dkms: running auto installation service for kernel 6.19.11
 * dkms: autoinstall for kernel 6.19.11                                                                                                                                                                     [ OK ] 
run-parts: executing /etc/kernel/postinst.d/initramfs-tools 6.19.11 /boot/vmlinuz-6.19.11
update-initramfs: Generating /boot/initrd.img-6.19.11
run-parts: executing /etc/kernel/postinst.d/unattended-upgrades 6.19.11 /boot/vmlinuz-6.19.11
run-parts: executing /etc/kernel/postinst.d/update-notifier 6.19.11 /boot/vmlinuz-6.19.11
run-parts: executing /etc/kernel/postinst.d/xx-update-initrd-links 6.19.11 /boot/vmlinuz-6.19.11
I: /boot/initrd.img is now a symlink to initrd.img-6.19.11
run-parts: executing /etc/kernel/postinst.d/zz-update-grub 6.19.11 /boot/vmlinuz-6.19.11
Sourcing file `/etc/default/grub'
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-6.19.11
Found initrd image: /boot/initrd.img-6.19.11
Found linux image: /boot/vmlinuz-6.8.0-107-generic
Found initrd image: /boot/initrd.img-6.8.0-107-generic
Warning: os-prober will not be executed to detect other bootable partitions.
Systems on them will not be added to the GRUB boot configuration.
Check GRUB_DISABLE_OS_PROBER documentation entry.
Adding boot menu entry for UEFI Firmware Settings ...
done
```

### 7. Перезапуск системы
```bash
reboot
```

### 8. Проверка текущей версии ядра
```bash
uname -r
6.19.11
```

