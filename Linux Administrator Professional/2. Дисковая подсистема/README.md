# Задание 2. Дисковая подсистема

## Описание задания

* Добавьте в виртуальную машину несколько дисков
* Соберите RAID-0/1/5/10 на выбор
* Сломайте и почините RAID
* Создайте GPT таблицу, пять разделов и смонтируйте их в системе.

## Решение

### 1 Создание RAID-массива 

#### 1.1 Добавление двух дисков

```bash
# lsblk
NAME                      MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sr0                        11:0    1 1024M  0 rom  
vda                       253:0    0   25G  0 disk 
├─vda1                    253:1    0    1M  0 part 
├─vda2                    253:2    0    2G  0 part /boot
└─vda3                    253:3    0   23G  0 part 
  └─ubuntu--vg-ubuntu--lv 252:0    0   23G  0 lvm  /
vdb                       253:16   0    1G  0 disk 
vdc                       253:32   0    1G  0 disk 
```

#### 1.2 Зануление суперблоков

```bash
# mdadm --zero-superblock --force /dev/vd{b,c}
mdadm: Unrecognised md component device - /dev/vdb
mdadm: Unrecognised md component device - /dev/vdc
```

#### 1.3 Создание RAID-0 из двух дисков

```bash
# mdadm --create --verbose /dev/md0 -l 1 -n 2 /dev/vd{b,c}
mdadm: Note: this array has metadata at the start and
    may not be suitable as a boot device.  If you plan to
    store '/boot' on this device please ensure that
    your boot-loader understands md/v1.x metadata, or use
    --metadata=0.90
mdadm: size set to 1046528K
Continue creating array? y
mdadm: Defaulting to version 1.2 metadata
mdadm: array /dev/md0 started.
```

#### 1.4 Проверка RAID

```bash
# cat /proc/mdstat
Personalities : [raid0] [raid1] [raid4] [raid5] [raid6] [raid10] 
md0 : active raid1 vdc[1] vdb[0]
      1046528 blocks super 1.2 [2/2] [UU]
      
unused devices: <none>

# mdadm -D /dev/md0
/dev/md0:
           Version : 1.2
     Creation Time : Mon Apr 13 11:10:37 2026
        Raid Level : raid1
        Array Size : 1046528 (1022.00 MiB 1071.64 MB)
     Used Dev Size : 1046528 (1022.00 MiB 1071.64 MB)
      Raid Devices : 2
     Total Devices : 2
       Persistence : Superblock is persistent

       Update Time : Mon Apr 13 11:10:42 2026
             State : clean 
    Active Devices : 2
   Working Devices : 2
    Failed Devices : 0
     Spare Devices : 0

Consistency Policy : resync

              Name : ubuntu2204:0  (local to host ubuntu2204)
              UUID : 6516faab:835fba24:09cdcc14:f62c0f5c
            Events : 17

    Number   Major   Minor   RaidDevice State
       0     253       16        0      active sync   /dev/vdb
       1     253       32        1      active sync   /dev/vdc
```

### 2. Поломка и починка RAID

#### 2.1 Пометка диска /dev/vdc как неисправного

```bash
# mdadm /dev/md0 --fail /dev/vdc
mdadm: set /dev/vdc faulty in /dev/md0
```

Проверка:

```bash
# cat /proc/mdstat
Personalities : [raid0] [raid1] [raid4] [raid5] [raid6] [raid10] 
md0 : active raid1 vdc[1](F) vdb[0]
      1046528 blocks super 1.2 [2/1] [U_]
      
unused devices: <none>

# mdadm -D /dev/md0
/dev/md0:
           Version : 1.2
     Creation Time : Mon Apr 13 11:10:37 2026
        Raid Level : raid1
        Array Size : 1046528 (1022.00 MiB 1071.64 MB)
     Used Dev Size : 1046528 (1022.00 MiB 1071.64 MB)
      Raid Devices : 2
     Total Devices : 2
       Persistence : Superblock is persistent

       Update Time : Mon Apr 13 11:12:17 2026
             State : clean, degraded 
    Active Devices : 1
   Working Devices : 1
    Failed Devices : 1
     Spare Devices : 0

Consistency Policy : resync

              Name : ubuntu2204:0  (local to host ubuntu2204)
              UUID : 6516faab:835fba24:09cdcc14:f62c0f5c
            Events : 19

    Number   Major   Minor   RaidDevice State
       0     253       16        0      active sync   /dev/vdb
       -       0        0        1      removed

       1     253       32        -      faulty   /dev/vdc
```

#### 2.2 Удаление неисправного диска из массива

```bash
mdadm /dev/md0 --remove /dev/vdc
mdadm: hot removed /dev/vdc from /dev/md0
```

#### 2.3 Добавление нового диска взамен неисправного

ВМ добавлен новый диск (vdd):

```bash
# lsblk
NAME                      MAJ:MIN RM  SIZE RO TYPE  MOUNTPOINTS
sr0                        11:0    1 1024M  0 rom   
vda                       253:0    0   25G  0 disk  
├─vda1                    253:1    0    1M  0 part  
├─vda2                    253:2    0    2G  0 part  /boot
└─vda3                    253:3    0   23G  0 part  
  └─ubuntu--vg-ubuntu--lv 252:0    0   23G  0 lvm   /
vdb                       253:16   0    1G  0 disk  
└─md0                       9:0    0 1022M  0 raid1 
vdc                       253:32   0    1G  0 disk  
vdd                       253:48   0    1G  0 disk  
```

Добавление vdd в RAID-массив:

```bash
# mdadm /dev/md0 --add /dev/vdd
mdadm: added /dev/vdd
```

Проверка:

```bash
# cat /proc/mdstat
Personalities : [raid0] [raid1] [raid4] [raid5] [raid6] [raid10] 
md0 : active raid1 vdd[2] vdb[0]
      1046528 blocks super 1.2 [2/2] [UU]
      
unused devices: <none>

# mdadm -D /dev/md0
/dev/md0:
           Version : 1.2
     Creation Time : Mon Apr 13 11:10:37 2026
        Raid Level : raid1
        Array Size : 1046528 (1022.00 MiB 1071.64 MB)
     Used Dev Size : 1046528 (1022.00 MiB 1071.64 MB)
      Raid Devices : 2
     Total Devices : 2
       Persistence : Superblock is persistent

       Update Time : Mon Apr 13 13:17:53 2026
             State : clean 
    Active Devices : 2
   Working Devices : 2
    Failed Devices : 0
     Spare Devices : 0

Consistency Policy : resync

              Name : ubuntu2204:0  (local to host ubuntu2204)
              UUID : 6516faab:835fba24:09cdcc14:f62c0f5c
            Events : 39

    Number   Major   Minor   RaidDevice State
       0     253       16        0      active sync   /dev/vdb
       2     253       48        1      active sync   /dev/vdd

```

### 3. Создание и монтирование разделов

#### 3.1 Создание таблицы GPT

```bash
parted -s /dev/md0 mklabel gpt

# Проверка
# parted /dev/md0 print
Model: Linux Software RAID Array (md)
Disk /dev/md0: 1072MB
Sector size (logical/physical): 512B/512B
Partition Table: gpt
Disk Flags: 

Number  Start  End  Size  File system  Name  Flags
```

#### 3.2 Создание разделов

```bash
for i in $(seq 1 5); do start_percent=$(( (i - 1) * 20 )); end_percent=$(( i * 20 )); parted /dev/md0 mkpart primary ext4 ${start_percent}% ${end_percent}%; done

Information: You may need to update /etc/fstab.

Information: You may need to update /etc/fstab.                           

Information: You may need to update /etc/fstab.                           

Information: You may need to update /etc/fstab.                           

Information: You may need to update /etc/fstab.
```

Проверка:
```bash
# parted /dev/md0 print                      
Model: Linux Software RAID Array (md)
Disk /dev/md0: 1072MB
Sector size (logical/physical): 512B/512B
Partition Table: gpt
Disk Flags: 

Number  Start   End     Size   File system  Name     Flags
 1      1049kB  214MB   213MB               primary
 2      214MB   429MB   215MB               primary
 3      429MB   643MB   214MB               primary
 4      643MB   858MB   215MB               primary
 5      858MB   1071MB  213MB               primary
```

#### 3.3 Форматирование и монтирование разделов

Форматирование:

```bash
for i in $(seq 1 5); do sudo mkfs.ext4 /dev/md0p$i; done
```

Монтирование по каталогам:

```bash
mkdir -p /raid/part{1,2,3,4,5}

for i in $(seq 1 5); do mount /dev/md0p$i /raid/part$i; done
```

Проверка:

```bash
# df -h
Filesystem                         Size  Used Avail Use% Mounted on
tmpfs                              393M  1,2M  392M   1% /run
/dev/mapper/ubuntu--vg-ubuntu--lv   23G  5,7G   16G  27% /
tmpfs                              2,0G     0  2,0G   0% /dev/shm
tmpfs                              5,0M     0  5,0M   0% /run/lock
/dev/vda2                          2,0G  176M  1,7G  10% /boot
tmpfs                              393M   12K  393M   1% /run/user/1000
/dev/md0p1                         175M   24K  160M   1% /raid/part1
/dev/md0p2                         176M   24K  162M   1% /raid/part2
/dev/md0p3                         176M   24K  161M   1% /raid/part3
/dev/md0p4                         176M   24K  162M   1% /raid/part4
/dev/md0p5                         175M   24K  160M   1% /raid/part5
```