# 🎯 Задание по теме ZFS

## Описание задания 

1. Определить алгоритм с наилучшим сжатием:

* определить, какие алгоритмы сжатия поддерживает zfs (gzip, zle, lzjb, lz4);
* создать 4 файловых системы, на каждой применить свой алгоритм сжатия;
* для сжатия использовать либо текстовый файл, либо группу файлов.

2. Определить настройки пула. С помощью команды zfs import собрать pool ZFS. Командами zfs определить настройки:

* размер хранилища;
* тип pool;
* значение recordsize;
* какое сжатие используется;
* какая контрольная сумма используется.

3. Работа со снапшотами:

* скопировать файл из удаленной директории;
* восстановить файл локально. zfs receive;
* найти зашифрованное сообщение в файле secret_message.

## Решение

### 0. Подготовка

Установка zfsutils-linux

```bash
root@ubuntu2404:~# apt update && apt install zfsutils-linux
```

Получение информации о доступных устройствах:

```bash
root@ubuntu2404:~# lsblk
NAME                      MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sr0                        11:0    1  3,2G  0 rom  
vda                       253:0    0   25G  0 disk 
├─vda1                    253:1    0    1M  0 part 
├─vda2                    253:2    0    2G  0 part /boot
└─vda3                    253:3    0   23G  0 part 
  └─ubuntu--vg-ubuntu--lv 252:0    0   22G  0 lvm  /
vdb                       253:16   0    1G  0 disk 
vdc                       253:32   0    1G  0 disk 
vdd                       253:48   0    1G  0 disk 
vde                       253:64   0    1G  0 disk 
vdf                       253:80   0    1G  0 disk 
vdg                       253:96   0    1G  0 disk 
vdh                       253:112  0    1G  0 disk 
vdi                       253:128  0    1G  0 disk
```

### 1. Определение алгоритма с наилучшим сжатием

#### 1.1 Определение поддерживаемых алгоритмов сжатия

Полный список поддерживаемых  алгоритмов сжатия доступен в [документации FreeBSD](https://docs.freebsd.org/ru/books/handbook/zfs/):

>Каждый набор данных имеет свойство сжатия (compression), которое по умолчанию отключено. Установите это свойство в один из доступных алгоритмов сжатия. Это приведёт к сжатию всех новых данных, записываемых в набор данных. Помимо уменьшения используемого пространства, пропускная способность при чтении и записи часто увеличивается, поскольку требуется читать или записывать меньше блоков.
>* LZJB — алгоритм сжатия по умолчанию. Создан Джеффом Бонвиком (одним из оригинальных создателей ZFS). LZJB обеспечивает хорошее сжатие с меньшей нагрузкой на CPU по сравнению с GZIP. В будущем алгоритм сжатия по умолчанию изменится на LZ4.
>* LZ4 — добавлен в версии 5000 (флаги функций) пула ZFS и теперь является рекомендуемым алгоритмом сжатия. LZ4 работает примерно на 50% быстрее, чем LZJB, при работе с сжимаемыми данными и более чем в три раза быстрее при работе с несжимаемыми данными. LZ4 также распаковывает данные примерно на 80% быстрее, чем LZJB. На современных процессорах LZ4 часто может сжимать данные со скоростью более 500 МБ/с и распаковывать со скоростью более 1,5 ГБ/с (на одно ядро CPU).
>* GZIP — популярный алгоритм потокового сжатия, доступный в ZFS. Одним из основных преимуществ использования GZIP является настраиваемый уровень сжатия. При установке свойства compress администратор может выбрать уровень сжатия от gzip1 (минимальный уровень сжатия) до gzip9 (максимальный уровень сжатия). Это позволяет администратору контролировать баланс между использованием CPU и экономией дискового пространства.
>* ZLE — Zero Length Encoding (кодирование нулевой длины) — это специальный алгоритм сжатия, который сжимает только непрерывные последовательности нулей. Этот алгоритм полезен, когда набор данных содержит большие блоки нулей.

#### 1.2 Создание файловых систем и применение сжатия

Создание 4 пулов в режиме зеркала:

```bash
root@ubuntu2404:~# zpool create test1 mirror /dev/vdb /dev/vdc
root@ubuntu2404:~# zpool create test2 mirror /dev/vdd /dev/vde
root@ubuntu2404:~# zpool create test3 mirror /dev/vdf /dev/vdg
root@ubuntu2404:~# zpool create test4 mirror /dev/vdh /dev/vdi
```

Список пулов:

```bash
root@ubuntu2404:~# zpool list
NAME    SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP    HEALTH  ALTROOT
test1   960M   110K   960M        -         -     0%     0%  1.00x    ONLINE  -
test2   960M   116K   960M        -         -     0%     0%  1.00x    ONLINE  -
test3   960M   110K   960M        -         -     0%     0%  1.00x    ONLINE  -
test4   960M   102K   960M        -         -     0%     0%  1.00x    ONLINE  -
```

Включение сжатия:

```bash
root@ubuntu2404:~# zfs set compression=lzjb test1
root@ubuntu2404:~# zfs set compression=lz4 test2
root@ubuntu2404:~# zfs set compression=gzip-9 test3
root@ubuntu2404:~# zfs set compression=zle test4
```

Проверка:

```bash
root@ubuntu2404:~# zfs get -o name,value compression
NAME   VALUE
test1  lzjb
test2  lz4
test3  gzip-9
test4  zle
```

#### 1.3 Определение лучшего алгоритма сжатия 

Скачивание файла во все пулы:

```bash
root@ubuntu2404:~# for i in {1..4}; do wget -P /test$i https://gutenberg.org/cache/epub/2600/pg2600.converter.log; done

root@ubuntu2404:~# ls -l /test*
/test1:
total 22123
-rw-r--r-- 1 root root 41227642 апр  2 07:31 pg2600.converter.log

/test2:
total 18019
-rw-r--r-- 1 root root 41227642 апр  2 07:31 pg2600.converter.log

/test3:
total 10972
-rw-r--r-- 1 root root 41227642 апр  2 07:31 pg2600.converter.log

/test4:
total 40290
-rw-r--r-- 1 root root 41227642 апр  2 07:31 pg2600.converter.log
```

Проверка занимаемого места и степени сжатия:

```bash
root@ubuntu2404:~# zfs list -o name,compressratio,used,available,referenced
NAME   RATIO   USED  AVAIL  REFER
test1  1.82x  21.8M   810M  21.6M
test2  2.23x  17.8M   814M  17.6M
test3  3.66x  10.9M   821M  10.7M
test4  1.00x  39.5M   793M  39.4M
```

**Алгоритм gzip-9 оказался самым эффективным при сжатии тектового файла**

### 2. Определение настроек пула

#### 2.1 Импорт пула ZFS

Скачивание архива, распаковка, проверка и импорт:

```bash
root@ubuntu2404:~# wget -O archive.tar.gz --no-check-certificate 'https://drive.usercontent.google.com/download?id=1MvrcEp-WgAQe57aDEzxSRalPAwbNN1Bb&export=download'

root@ubuntu2404:~# tar -xzvf archive.tar.gz
zpoolexport/
zpoolexport/filea
zpoolexport/fileb

root@ubuntu2404:~# zpool import -d zpoolexport/
   pool: otus
     id: 6554193320433390805
  state: ONLINE
status: Some supported features are not enabled on the pool.
	(Note that they may be intentionally disabled if the
	'compatibility' property is set.)
 action: The pool can be imported using its name or numeric identifier, though
	some features will not be available without an explicit 'zpool upgrade'.
 config:

	otus                         ONLINE
	  mirror-0                   ONLINE
	    /root/zpoolexport/filea  ONLINE
	    /root/zpoolexport/fileb  ONLINE

root@ubuntu2404:~# zpool import -d zpoolexport/ otus
```

Статус импортированного пула:

```bash
root@ubuntu2404:~# zpool status otus
  pool: otus
 state: ONLINE
status: Some supported and requested features are not enabled on the pool.
	The pool can still be used, but some features are unavailable.
action: Enable all features using 'zpool upgrade'. Once this is done,
	the pool may no longer be accessible by software that does not support
	the features. See zpool-features(7) for details.
config:

	NAME                         STATE     READ WRITE CKSUM
	otus                         ONLINE       0     0     0
	  mirror-0                   ONLINE       0     0     0
	    /root/zpoolexport/filea  ONLINE       0     0     0
	    /root/zpoolexport/fileb  ONLINE       0     0     0

errors: No known data errors
```

#### 2.2 Определение настроек пула otus

Размер (used+available+referenced), тип, сжатие, размер блока (записи), контрольная сумма:

```bash
root@ubuntu2404:~# zfs list -o name,used,available,referenced,type,compression,recordsize,checksum otus
NAME   USED  AVAIL  REFER  TYPE        COMPRESS        RECSIZE  CHECKSUM
otus  2.04M   350M    24K  filesystem  zle                128K  sha256
```

### 3. Работа со снапшотами

Восстановление снапшота:

```bash
root@ubuntu2404:~# wget -O otus_task2.file --no-check-certificate 'https://drive.usercontent.google.com/download?id=1wgxjih8YZ-cqLqaZVa0lA3h3Y029c3oI&export=download'

root@ubuntu2404:~# zfs receive otus/test@today < otus_task2.file
```

Поиск зашифрованного сообщения:

```bash
root@ubuntu2404:~# find /otus/test -name "secret_message" -exec cat {} +
https://otus.ru/lessons/linux-hl/
```

В файле ссылка на курс ["Инфраструктура высоконагруженных систем"](https://otus.ru/lessons/linux-hl/)