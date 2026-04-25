# 🎯 Задание 3. Файловые системы и LVM

## Описание задания 

На виртуальной машине с Ubuntu 24.04 и LVM.

1. Уменьшить том под / до 8G.
2. Выделить том под /home.
3. Выделить том под /var - сделать в mirror.
4. /home - сделать том для снапшотов.
5. Прописать монтирование в fstab. Попробовать с разными опциями и разными файловыми системами (на выбор).
6. Работа со снапшотами:

* сгенерить файлы в /home/;
* снять снапшот;
* удалить часть файлов;
* восстановиться со снапшота.


## Решение

### 1. Уменьшение тома под / до 8G

Имеющиеся диски

```bash
# lsblk
NAME                      MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sr0                        11:0    1 1024M  0 rom  
vda                       253:0    0   25G  0 disk 
├─vda1                    253:1    0    1M  0 part 
├─vda2                    253:2    0    2G  0 part /boot
└─vda3                    253:3    0   23G  0 part 
  └─ubuntu--vg-ubuntu--lv 252:0    0   23G  0 lvm  /
vdb                       253:16   0   10G  0 disk 
vdc                       253:32   0    2G  0 disk 
vdd                       253:48   0    1G  0 disk 
vde                       253:64   0    1G  0 disk 
```

#### 1.1 Перенос / на другой LV

Создание PV, VG, LV:

```bash
# pvcreate /dev/vdb
  Physical volume "/dev/vdb" successfully created.

# vgcreate test /dev/vdb
  Volume group "test" successfully created

# lvcreate -n lv_root -l +100%FREE /dev/test
  Logical volume "lv_root" created.
```

Создание ФС на LV, монтирование и копирование всех данных с /

```bash
# mkfs.ext4 /dev/test/lv_root
mke2fs 1.47.0 (5-Feb-2023)
Discarding device blocks: done                            
Creating filesystem with 2620416 4k blocks and 655360 inodes
Filesystem UUID: b4973ab6-19c2-4202-91a7-f417c4fdde48
Superblock backups stored on blocks: 
	32768, 98304, 163840, 229376, 294912, 819200, 884736, 1605632

Allocating group tables: done                            
Writing inode tables: done                            
Creating journal (16384 blocks): done
Writing superblocks and filesystem accounting information: done 

mount /dev/test/lv_root /mnt

# rsync -avxHAX --progress / /mnt/
...
sent 5.823.365.912 bytes  received 2.548.652 bytes  122.650.832,93 bytes/sec
total size is 5.816.983.687  speedup is 1,00
```

Имитация текущего root:

```bash
for i in /proc/ /sys/ /dev/ /run/ /boot/; do mount --rbind $i /mnt/$i; done
chroot /mnt/
```


Конфигурация grub

```bash
# grub-mkconfig -o /boot/grub/grub.cfg
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

Обновление initramfs

```bash
# update-initramfs -u
update-initramfs: Generating /boot/initrd.img-6.19.11
```

Смена в fstab монтируемого устройства в качестве корня
```bash
# blkid /dev/test/lv_root
/dev/test/lv_root: UUID="b4973ab6-19c2-4202-91a7-f417c4fdde48" BLOCK_SIZE="4096" TYPE="ext4"

# cat /etc/fstab
#/dev/disk/by-id/dm-uuid-LVM-T4d9lNkoZaOQo0Rk9YxfSd71iMjrd97q4YGCdKY0zMIfDNq0CdcNS2Ob7Wh5eLXB / ext4 defaults 0 1
UUID=b4973ab6-19c2-4202-91a7-f417c4fdde48 / ext4 defaults 0 1
```

Перезапуск системы

```bash
exit
reboot
```

Проверка, что корень на новом LV

```bash
# lsblk
NAME                      MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sr0                        11:0    1 1024M  0 rom  
vda                       253:0    0   25G  0 disk 
├─vda1                    253:1    0    1M  0 part 
├─vda2                    253:2    0    2G  0 part /boot
└─vda3                    253:3    0   23G  0 part 
  └─ubuntu--vg-ubuntu--lv 252:1    0   23G  0 lvm  
vdb                       253:16   0   10G  0 disk 
└─test-lv_root            252:0    0   10G  0 lvm  /
vdc                       253:32   0    2G  0 disk 
vdd                       253:48   0    1G  0 disk 
vde                       253:64   0    1G  0 disk
```

#### 1.2 Пересоздание ubuntu-vg/ubuntu-lv с нужным размером

Удаляем старый LV и создаём новый на 8G

```bash
# lvremove /dev/ubuntu-vg/ubuntu-lv 
Do you really want to remove and DISCARD active logical volume ubuntu-vg/ubuntu-lv? [y/n]: y
  Logical volume "ubuntu-lv" successfully removed.

# lvcreate -n ubuntu-vg/ubuntu-lv -L 8G /dev/ubuntu-vg
  Logical volume "ubuntu-lv" created.
```

#### 1.3 Возврат / на ubuntu-vg/ubuntu-lv

Создание ФС на LV, монтирование и копирование всех данных с /

```bash
# mkfs.ext4 /dev/ubuntu-vg/ubuntu-lv
mke2fs 1.47.0 (5-Feb-2023)
Discarding device blocks: done                            
Creating filesystem with 2097152 4k blocks and 524288 inodes
Filesystem UUID: 08b4c0f6-e25d-419c-b9f9-7537d7c8c04d
Superblock backups stored on blocks: 
	32768, 98304, 163840, 229376, 294912, 819200, 884736, 1605632

Allocating group tables: done                            
Writing inode tables: done                            
Creating journal (16384 blocks): done
Writing superblocks and filesystem accounting information: done

mount /dev/ubuntu-vg/ubuntu-lv /mnt

# rsync -axHAX --stats / /mnt/
...
sent 5.848.983.359 bytes  received 2.549.194 bytes  238.838.063,39 bytes/sec
total size is 5.842.589.723  speedup is 1,00
```

Имитация root, конфигурация grub и initrd:

```bash
for i in /proc/ /sys/ /dev/ /run/ /boot/; do mount --rbind $i /mnt/$i; done
chroot /mnt/

# grub-mkconfig -o /boot/grub/grub.cfg
Sourcing file '/etc/default/grub'
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

# update-initramfs -u
update-initramfs: Generating /boot/initrd.img-6.19.11
```

Смена записи в /etc/fstab, рестарт системы и проверка

```bash
# ls -l /dev/disk/by-id/
total 0
lrwxrwxrwx 1 root root  9 апр 25 11:20 ata-QEMU_DVD-ROM_QM00001 -> ../../sr0
lrwxrwxrwx 1 root root 10 апр 25 11:20 dm-name-test-lv_root -> ../../dm-0
lrwxrwxrwx 1 root root 10 апр 25 11:32 dm-name-ubuntu--vg-ubuntu--lv -> ../../dm-1
lrwxrwxrwx 1 root root 10 апр 25 11:32 dm-uuid-LVM-T4d9lNkoZaOQo0Rk9YxfSd71iMjrd97qFd7Ju8x0zG8f9q3EwZD3wSNDtHu4c7k9 -> ../../dm-1
lrwxrwxrwx 1 root root 10 апр 25 11:20 dm-uuid-LVM-wQHw5sOuoM0eGgWLGfDPjkmIBlMriQdbROvsIc3eD4IO7hIQvYm32KQLvlAAJbtU -> ../../dm-0
lrwxrwxrwx 1 root root 10 апр 25 11:20 lvm-pv-uuid-tj7Ni9-uarV-evWT-vcei-ZZeA-FceR-iwKrP1 -> ../../vda3
lrwxrwxrwx 1 root root  9 апр 25 11:20 lvm-pv-uuid-vDIP90-1mCA-NX1X-mrDv-bycZ-Qx3Y-Xv5WfZ -> ../../vdb

# cat /etc/fstab
#UUID=b4973ab6-19c2-4202-91a7-f417c4fdde48 / ext4 defaults 0 1
/dev/disk/by-id/dm-uuid-LVM-T4d9lNkoZaOQo0Rk9YxfSd71iMjrd97qFd7Ju8x0zG8f9q3EwZD3wSNDtHu4c7k9 / ext4 defaults 0 1

exit
reboot

# lsblk
NAME                      MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sr0                        11:0    1 1024M  0 rom  
vda                       253:0    0   25G  0 disk 
├─vda1                    253:1    0    1M  0 part 
├─vda2                    253:2    0    2G  0 part /boot
└─vda3                    253:3    0   23G  0 part 
  └─ubuntu--vg-ubuntu--lv 252:1    0    8G  0 lvm  /
vdb                       253:16   0   10G  0 disk 
└─test-lv_root            252:0    0   10G  0 lvm  
vdc                       253:32   0    2G  0 disk 
vdd                       253:48   0    1G  0 disk 
vde                       253:64   0    1G  0 disk
```

#### 1.4 Удаление временных LV, VG, PV

```bash
# lvremove /dev/test/lv_root 
Do you really want to remove and DISCARD active logical volume test/lv_root? [y/n]: y
  Logical volume "lv_root" successfully removed

# vgremove /dev/test
  Volume group "test" successfully removed

# pvremove /dev/vdb
  Labels on physical volume "/dev/vdb" successfully wiped.

# lsblk
NAME                      MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sr0                        11:0    1 1024M  0 rom  
vda                       253:0    0   25G  0 disk 
├─vda1                    253:1    0    1M  0 part 
├─vda2                    253:2    0    2G  0 part /boot
└─vda3                    253:3    0   23G  0 part 
  └─ubuntu--vg-ubuntu--lv 252:1    0    8G  0 lvm  /
vdb                       253:16   0   10G  0 disk 
vdc                       253:32   0    2G  0 disk 
vdd                       253:48   0    1G  0 disk 
vde                       253:64   0    1G  0 disk
```

### 2. Выделение тома под /home

#### 2.1 Создание LV и ФС

```bash
# lvcreate -n home -L 2G /dev/ubuntu-vg
  Logical volume "home" created.

# mkfs.ext4 /dev/ubuntu-vg/home
mke2fs 1.47.0 (5-Feb-2023)
Discarding device blocks: done                            
Creating filesystem with 524288 4k blocks and 131072 inodes
Filesystem UUID: 3a77dbb1-16bc-497a-859c-3f2728194500
Superblock backups stored on blocks: 
	32768, 98304, 163840, 229376, 294912

Allocating group tables: done                            
Writing inode tables: done                            
Creating journal (16384 blocks): done
Writing superblocks and filesystem accounting information: done
```

#### 2.2 Перемещение /home на /dev/ubuntu-vg/home

```bash
mount /dev/ubuntu-vg/home /mnt

# rsync -aHAXxSP --stats /home/ /mnt/
...
sent 26.025 bytes  received 279 bytes  17.536,00 bytes/sec
total size is 24.767  speedup is 0,94

rm -rf /home/*

umount /mnt
mount /dev/ubuntu-vg/home  /home/
```

#### 2.3 Настройка монтирования

```bash
ls -l /dev/disk/by-id/
...
lrwxrwxrwx 1 root root 10 апр 25 18:55 dm-name-ubuntu--vg-home -> ../../dm-0
lrwxrwxrwx 1 root root 10 апр 25 18:55 dm-uuid-LVM-T4d9lNkoZaOQo0Rk9YxfSd71iMjrd97qYs5l9kDbSR1QoOsYyFL2FfkIsiDNaieO -> ../../dm-0
...

echo '/dev/disk/by-id/dm-uuid-LVM-T4d9lNkoZaOQo0Rk9YxfSd71iMjrd97qYs5l9kDbSR1QoOsYyFL2FfkIsiDNaieO /home ext4 defaults 0 0' >> /etc/fstab
```

#### 2.4 Проверка

```bash
reboot

# lsblk
NAME                      MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sr0                        11:0    1 1024M  0 rom  
vda                       253:0    0   25G  0 disk 
├─vda1                    253:1    0    1M  0 part 
├─vda2                    253:2    0    2G  0 part /boot
└─vda3                    253:3    0   23G  0 part 
  ├─ubuntu--vg-ubuntu--lv 252:1    0    8G  0 lvm  /
  └─ubuntu--vg-home       252:3    0    2G  0 lvm  /home
vdb                       253:16   0   10G  0 disk 
vdc                       253:32   0    2G  0 disk 
├─vg_var-lv_var_rmeta_0   252:2    0    4M  0 lvm  
│ └─vg_var-lv_var         252:7    0  952M  0 lvm  /var
└─vg_var-lv_var_rimage_0  252:4    0  952M  0 lvm  
  └─vg_var-lv_var         252:7    0  952M  0 lvm  /var
vdd                       253:48   0    1G  0 disk 
├─vg_var-lv_var_rmeta_1   252:5    0    4M  0 lvm  
│ └─vg_var-lv_var         252:7    0  952M  0 lvm  /var
└─vg_var-lv_var_rimage_1  252:6    0  952M  0 lvm  
  └─vg_var-lv_var         252:7    0  952M  0 lvm  /var
vde                       253:64   0    1G  0 disk
```

### 3. Выделение тома под /var (mirror)

#### 3.1 Создание зеркала

```bash
# pvcreate /dev/vdc /dev/vdd
  Physical volume "/dev/vdc" successfully created.
  Physical volume "/dev/vdd" successfully created.

# vgcreate vg_var /dev/vdc /dev/vdd
  Volume group "vg_var" successfully created

# lvcreate -L 950M -m1 -n lv_var vg_var
  Rounding up size to full physical extent 952,00 MiB
  Logical volume "lv_var" created.
```

#### 3.2 Перемещение /var на lv_var

```bash
# mkfs.ext4 /dev/vg_var/lv_var
mke2fs 1.47.0 (5-Feb-2023)
Discarding device blocks: done                            
Creating filesystem with 243712 4k blocks and 60928 inodes
Filesystem UUID: 5c4f1545-3909-42e2-95ab-9b541cb498e8
Superblock backups stored on blocks: 
	32768, 98304, 163840, 229376

Allocating group tables: done                            
Writing inode tables: done                            
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done

mount /dev/vg_var/lv_var /mnt

# rsync -aHAXxSP --stats /var/ /mnt/
...
total size is 761.923.527  speedup is 4.858,34

rm -rf /var/*
```

#### 3.3 Изменение параметров монтирования

```bash
mount /dev/vg_var/lv_var /var

# ls -l /dev/disk/by-id/
...
lrwxrwxrwx 1 root root 10 апр 25 18:18 dm-name-vg_var-lv_var -> ../../dm-7
lrwxrwxrwx 1 root root 10 апр 25 18:18 dm-uuid-LVM-dGiF8OtfKTMBeoyR6ctBJBVfNik8HdsOY6Xfx3nCImE4FSIeSBbTLkPYC7sakhhQ -> ../../dm-7
...

echo '/dev/disk/by-id/dm-uuid-LVM-dGiF8OtfKTMBeoyR6ctBJBVfNik8HdsOY6Xfx3nCImE4FSIeSBbTLkPYC7sakhhQ /var ext4 defaults 0 0' >> /etc/fstab

reboot
```

#### 3.4 Проверка

```bash
# lsblk
NAME                      MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sr0                        11:0    1 1024M  0 rom  
vda                       253:0    0   25G  0 disk 
├─vda1                    253:1    0    1M  0 part 
├─vda2                    253:2    0    2G  0 part /boot
└─vda3                    253:3    0   23G  0 part 
  └─ubuntu--vg-ubuntu--lv 252:7    0    8G  0 lvm  /
vdb                       253:16   0   10G  0 disk 
vdc                       253:32   0    2G  0 disk 
├─vg_var-lv_var_rmeta_0   252:1    0    4M  0 lvm  
│ └─vg_var-lv_var         252:5    0  952M  0 lvm  /var
└─vg_var-lv_var_rimage_0  252:2    0  952M  0 lvm  
  └─vg_var-lv_var         252:5    0  952M  0 lvm  /var
vdd                       253:48   0    1G  0 disk 
├─vg_var-lv_var_rmeta_1   252:3    0    4M  0 lvm  
│ └─vg_var-lv_var         252:5    0  952M  0 lvm  /var
└─vg_var-lv_var_rimage_1  252:4    0  952M  0 lvm  
  └─vg_var-lv_var         252:5    0  952M  0 lvm  /var
vde                       253:64   0    1G  0 disk 
```

### 4. Подготовка логического тома для /home

Подготовка выполнена в пункте 2 ["Выделение тома под /home"](#2-выделение-тома-под-home), в VG достаточно места для снапшота:

```bash
# df -h /home/
Filesystem                   Size  Used Avail Use% Mounted on
/dev/mapper/ubuntu--vg-home  2,0G  104K  1,8G   1% /home

# vgs
  VG        #PV #LV #SN Attr   VSize   VFree  
  ubuntu-vg   1   2   0 wz--n- <23,00g <13,00g
  vg_tmp      1   1   0 wz--n- <20,00g      0 
  vg_var      2   1   0 wz--n-   2,99g   1,12g
```

### 5. Монтирование btrfs в /etc/fstab для /opt (часть задания со звёздочкой ⭐️)

Текущие устройства:

```bash
# lsblk
NAME                      MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sr0                        11:0    1 1024M  0 rom  
vda                       253:0    0   25G  0 disk 
├─vda1                    253:1    0    1M  0 part 
├─vda2                    253:2    0    2G  0 part /boot
└─vda3                    253:3    0   23G  0 part 
  ├─ubuntu--vg-ubuntu--lv 252:1    0    8G  0 lvm  /
  └─ubuntu--vg-home       252:3    0    2G  0 lvm  /home
vdb                       253:16   0   10G  0 disk  <-- основной «медленный» том для данных
vdc                       253:32   0    2G  0 disk 
├─vg_var-lv_var_rmeta_0   252:2    0    4M  0 lvm  
│ └─vg_var-lv_var         252:7    0  952M  0 lvm  /var
└─vg_var-lv_var_rimage_0  252:4    0  952M  0 lvm  
  └─vg_var-lv_var         252:7    0  952M  0 lvm  /var
vdd                       253:48   0    1G  0 disk 
├─vg_var-lv_var_rmeta_1   252:5    0    4M  0 lvm  
│ └─vg_var-lv_var         252:7    0  952M  0 lvm  /var
└─vg_var-lv_var_rimage_1  252:6    0  952M  0 lvm  
  └─vg_var-lv_var         252:7    0  952M  0 lvm  /var
vde                       253:64   0    1G  0 disk  <-- «быстрый» том для кэша
```

#### 5.1 Подготовка

Создание PV, VG и LV для данных и кэша

```bash
# pvcreate /dev/vdb /dev/vde
  Physical volume "/dev/vdb" successfully created.
  Physical volume "/dev/vde" successfully created.

# vgcreate vg_opt /dev/vdb /dev/vde
  Volume group "vg_opt" successfully created

# lvcreate -l +100%FREE -n lv_data vg_opt /dev/vdb
  Logical volume "lv_data" created

# lvcreate -L 900M -n lv_cache vg_opt /dev/vde
  Logical volume "lv_cache" created.

# lvconvert --type cache-pool vg_opt/lv_cache
  WARNING: Converting vg_opt/lv_cache to cache pool's data volume with metadata wiping.
  THIS WILL DESTROY CONTENT OF LOGICAL VOLUME (filesystem etc.)
Do you really want to convert vg_opt/lv_cache? [y/n]: y
  Converted vg_opt/lv_cache to cache pool.

# lvconvert --type cache --cachepool vg_opt/lv_cache vg_opt/lv_data
Do you want wipe existing metadata of cache pool vg_opt/lv_cache? [y/n]: y
  Logical volume vg_opt/lv_data is now cached.

```

Создание файловой системы Btrfs и монтирование

```bash
# mkfs.btrfs /dev/vg_opt/lv_data 
btrfs-progs v6.6.3
See https://btrfs.readthedocs.io for more information.

Performing full device TRIM /dev/vg_opt/lv_data (10.00GiB) ...
NOTE: several default settings have changed in version 5.15, please make sure
      this does not affect your deployments:
      - DUP for metadata (-m dup)
      - enabled no-holes (-O no-holes)
      - enabled free-space-tree (-R free-space-tree)

Label:              (null)
UUID:               5876ede7-dd58-4ec9-b232-a0f8a07e4dc2
Node size:          16384
Sector size:        4096
Filesystem size:    10.00GiB
Block group profiles:
  Data:             single            8.00MiB
  Metadata:         DUP             256.00MiB
  System:           DUP               8.00MiB
SSD detected:       no
Zoned device:       no
Incompat features:  extref, skinny-metadata, no-holes, free-space-tree
Runtime features:   free-space-tree
Checksum:           crc32c
Number of devices:  1
Devices:
   ID        SIZE  PATH               
    1    10.00GiB  /dev/vg_opt/lv_data

mount -o noatime,compress=zstd:3,space_cache=v2 /dev/vg_opt/lv_data /mnt/
```

#### 5.2 Перемещение /opt на /dev/vg_opt/lv_data

```bash
# rsync -aHAXxSP --stats /opt/ /mnt/
...
total size is 0  speedup is 0,00
```

#### 5.3 Изменение параметров монтирования

```bash
# ls -l /dev/disk/by-id/
...
lrwxrwxrwx 1 root root 10 апр 25 22:09 dm-name-vg_opt-lv_data -> ../../dm-7
lrwxrwxrwx 1 root root 10 апр 25 22:09 dm-uuid-LVM-cFDYWRqYFxiBaEHXfx5q4JZN71e2WoSUXytEKRV9XbuifV8tFlGniOGfrOgWLhUI -> ../../dm-7
...

echo '/dev/disk/by-id/dm-uuid-LVM-cFDYWRqYFxiBaEHXfx5q4JZN71e2WoSUXytEKRV9XbuifV8tFlGniOGfrOgWLhUI /opt btrfs noatime,compress=zstd:3,space_cache=v2 0 2' >> /etc/fstab

reboot
```

#### 5.4 Проверка

```bash
# lsblk
NAME                          MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sr0                            11:0    1 1024M  0 rom  
vda                           253:0    0   25G  0 disk 
├─vda1                        253:1    0    1M  0 part 
├─vda2                        253:2    0    2G  0 part /boot
└─vda3                        253:3    0   23G  0 part 
  ├─ubuntu--vg-ubuntu--lv     252:5    0    8G  0 lvm  /
  └─ubuntu--vg-home           252:6    0    2G  0 lvm  /home
vdb                           253:16   0   10G  0 disk 
└─vg_opt-lv_data_corig        252:9    0   10G  0 lvm  
  └─vg_opt-lv_data            252:10   0   10G  0 lvm  /opt
vdc                           253:32   0    5G  0 disk 
├─vg_var-lv_var_rmeta_0       252:0    0    4M  0 lvm  
│ └─vg_var-lv_var             252:4    0    5G  0 lvm  /var
└─vg_var-lv_var_rimage_0      252:1    0    5G  0 lvm  
  └─vg_var-lv_var             252:4    0    5G  0 lvm  /var
vdd                           253:48   0    5G  0 disk 
├─vg_var-lv_var_rmeta_1       252:2    0    4M  0 lvm  
│ └─vg_var-lv_var             252:4    0    5G  0 lvm  /var
└─vg_var-lv_var_rimage_1      252:3    0    5G  0 lvm  
  └─vg_var-lv_var             252:4    0    5G  0 lvm  /var
vde                           253:64   0    1G  0 disk 
├─vg_opt-lv_cache_cpool_cdata 252:7    0  900M  0 lvm  
│ └─vg_opt-lv_data            252:10   0   10G  0 lvm  /opt
└─vg_opt-lv_cache_cpool_cmeta 252:8    0    8M  0 lvm  
  └─vg_opt-lv_data            252:10   0   10G  0 lvm  /opt
```

### 6. Работа со снапшотами

Генерация файлов в /home/

```bash
touch /home/file{1..20}
```

Создание снапшота

```bash
# lvcreate -L 100MB -s -n home_snap /dev/ubuntu-vg/home
  Logical volume "home_snap" created.
```

Имитация сбоя:

```bash
rm -f /home/file{11..20}
```

Восстановление из снапшота

```bash
rm -f /home/file{11..20}

# lvconvert --merge /dev/ubuntu-vg/home_snap
  Delaying merge since origin is open.
  Merging of snapshot ubuntu-vg/home_snap will occur on next activation of ubuntu-vg/home.

reboot

# ls
file1  file10  file11  file12  file13  file14  file15  file16  file17 ...
```

# ⭐️ Задание со звёздочкой

## Описание задания 

На дисках поставить btrfs/zfs — с кэшем, снапшотами и разметить там каталог /opt.

## Решение

Файловая система btrfs с кэшем для /opt была создана в пункте  ["5. Монтирование btrfs в /etc/fstab для /opt (часть задания со звёздочкой ⭐️)"](#5-монтирование-btrfs-в-etcfstab-для-opt-часть-задания-со-звёздочкой-️).

### Работа со снапшотами Btrfs

Создание подтома

```bash
cd /opt
btrfs subvolume create documents
```

Генерация тестовых файлов

```bash
echo "Это важный финансовый отчет за 1 квартал." > documents/report_q1.txt
echo "Список контактов ключевых клиентов." > documents/contacts.txt
echo "Черновик договора с новым партнером." > documents/contract_draft.doc

# ls -l documents/
total 12
-rw-r--r-- 1 root root 67 апр 25 22:54 contacts.txt
-rw-r--r-- 1 root root 68 апр 25 22:54 contract_draft.doc
-rw-r--r-- 1 root root 75 апр 25 22:54 report_q1.txt

```

Создание снапшота btrfs

```bash
# btrfs subvolume snapshot documents documents_snapshot_$(date +%F_%H-%M-%S)
Create a snapshot of 'documents' in './documents_snapshot_2026-04-25_22-55-01'

# btrfs subvolume list /opt 
ID 257 gen 14 top level 5 path documents
ID 258 gen 14 top level 5 path documents_snapshot_2026-04-25_22-55-01
```

Имитация сбоя:

```bash
rm documents/contacts.txt
echo "Это важный финансовый отчет за 1 квартал. ОШИБКА: перепутаны выручка и прибыль!" > documents/report_q1.txt

#ls -l documents/
total 8
-rw-r--r-- 1 root root  68 апр 25 22:54 contract_draft.doc
-rw-r--r-- 1 root root 144 апр 25 22:57 report_q1.txt

#cat documents/report_q1.txt
Это важный финансовый отчет за 1 квартал. ОШИБКА: перепутаны выручка и прибыль!
```

Восстановление проблемных файлов и проверка

```bash
cp documents_snapshot_2026-04-25_22-55-01/{contacts,report_q1}.txt documents

# ls -l documents/
total 12
-rw-r--r-- 1 root root 67 апр 25 23:00 contacts.txt
-rw-r--r-- 1 root root 68 апр 25 22:54 contract_draft.doc
-rw-r--r-- 1 root root 75 апр 25 23:00 report_q1.txt

# cat documents/report_q1.txt
Это важный финансовый отчет за 1 квартал.
```

Удаление снапшота

```bash
# btrfs subvolume delete documents_snapshot_2026-04-25_22-55-01
Delete subvolume 258 (no-commit): '/opt/documents_snapshot_2026-04-25_22-55-01'

# btrfs subvolume list /opt 
ID 257 gen 16 top level 5 path documents
```