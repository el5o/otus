# 🎯 Задание по теме NFS

## Описание задания 

* запустить 2 виртуальных машины (сервер NFS и клиента);
* на сервере NFS должна быть подготовлена и экспортирована директория;
* в экспортированной директории должна быть поддиректория с именем upload с правами на запись в неё;
* экспортированная директория должна автоматически монтироваться на клиенте при старте виртуальной машины (systemd, autofs или fstab — любым способом);
* монтирование и работа NFS на клиенте должна быть организована с использованием NFSv3.

## Решение

### NFS-сервер

#### 1. Подготовка

Установка nfs-kernel-server:

```bash
root@ubuntu2404:~# apt install nfs-kernel-server
```

Проверка наличия слушающих портов

```bash
root@ubuntu2404:~# ss -tnplu | grep -e 111 -e 2049
udp   UNCONN 0      0                   0.0.0.0:111        0.0.0.0:*    users:(("rpcbind",pid=34469,fd=5),("systemd",pid=1,fd=209))
udp   UNCONN 0      0                      [::]:111           [::]:*    users:(("rpcbind",pid=34469,fd=7),("systemd",pid=1,fd=211))
tcp   LISTEN 0      4096                0.0.0.0:111        0.0.0.0:*    users:(("rpcbind",pid=34469,fd=4),("systemd",pid=1,fd=207))
tcp   LISTEN 0      64                  0.0.0.0:2049       0.0.0.0:*                                                               
tcp   LISTEN 0      4096                   [::]:111           [::]:*    users:(("rpcbind",pid=34469,fd=6),("systemd",pid=1,fd=210))
tcp   LISTEN 0      64                     [::]:2049          [::]:* 
```

#### 2. Настройка экспортируемой директории

Создание и назначение прав:

```bash
root@ubuntu2404:~# mkdir -p /srv/share/upload
root@ubuntu2404:~# chown -R nobody:nogroup /srv/share
root@ubuntu2404:~# chmod 0777 /srv/share/upload
```

#### 3. Экспорт каталога

Назначение каталога экспортируемым:

```bash
root@ubuntu2404:~# cat << EOF > /etc/exports
/srv/share 192.168.101.2/32(rw,sync,no_subtree_check,root_squash)
EOF
```

Обновление списка экспортируемых каталогов:

```bash
root@ubuntu2404:~# exportfs -r
```

Проверка:

```bash
root@ubuntu2404:~# exportfs -s
/srv/share  192.168.101.2/32(sync,wdelay,hide,no_subtree_check,sec=sys,rw,secure,root_squash,no_all_squash)
```

### NFS-клиент


#### 1. Подготовка

Установка nfs-common

```bash
root@ubuntu2404-2:~# apt install nfs-common
```

#### 2. Монтирование

Настройка автоматического монтирования:

```bash
root@ubuntu2404-2:~# echo "192.168.101.1:/srv/share/ /mnt nfs vers=3,noauto,x-systemd.automount 0 0" >> /etc/fstab
```

Применение и проверка:

```bash
root@ubuntu2404-2:~# systemctl daemon-reload
root@ubuntu2404-2:~# systemctl restart remote-fs.target
root@ubuntu2404-2:~# cd /mnt/
root@ubuntu2404-2:/mnt# mount | grep mnt
systemd-1 on /mnt type autofs (rw,relatime,fd=68,pgrp=1,timeout=0,minproto=5,maxproto=5,direct,pipe_ino=91594)
192.168.101.1:/srv/share/ on /mnt type nfs (rw,relatime,vers=3,rsize=524288,wsize=524288,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,mountaddr=192.168.101.1,mountvers=3,mountport=44771,mountproto=udp,local_lock=none,addr=192.168.101.1)
```

### Проверка работоспособности

Проверка прав

```bash
# Server
user@ubuntu2404:~$ cd /srv/share/upload
user@ubuntu2404:/srv/share/upload$ touch check_file

# Client
user@ubuntu2404-2:~$ cd /mnt/upload
user@ubuntu2404-2:/mnt/upload$ ls -l
total 0
-rw-rw-r-- 1 user user 0 июн 22 18:13 check_file
```

Проверка автомонтирования

```bash
user@ubuntu2404-2:~$ w
 18:17:03 up 0 min,  1 user,  load average: 0,07, 0,02, 0,00
USER     TTY      FROM             LOGIN@   IDLE   JCPU   PCPU  WHAT
user              192.168.101.254  18:17    8.00s  0.00s  0.01s sshd: user [priv]
user@ubuntu2404-2:~$ uptime
 18:17:08 up 0 min,  1 user,  load average: 0,07, 0,02, 0,00
user@ubuntu2404-2:~$ ls -l /mnt/upload/
total 0
-rw-rw-r-- 1 user user 0 июн 22 18:13 check_file
```

Проверка устойчивости сервера к рестарту

```bash
# Server

user@ubuntu2404:~$ uptime
 18:19:55 up 0 min,  1 user,  load average: 0,84, 0,21, 0,07
user@ubuntu2404:~$ ls -l /srv/share/upload/
total 0
-rw-rw-r-- 1 user user 0 июн 22 18:13 check_file
user@ubuntu2404:~$ sudo exportfs -s
/srv/share  192.168.101.2/32(sync,wdelay,hide,no_subtree_check,sec=sys,rw,secure,root_squash,no_all_squash)
user@ubuntu2404:~$ showmount -a 192.168.101.1
All mount points on 192.168.101.1:
192.168.101.2:/srv/share

# Client

user@ubuntu2404-2:~$ uptime
 18:22:27 up 0 min,  1 user,  load average: 0,13, 0,03, 0,01
user@ubuntu2404-2:~$ showmount -a 192.168.101.1
All mount points on 192.168.101.1:
192.168.101.2:/srv/share
user@ubuntu2404-2:~$ cd /mnt/upload
user@ubuntu2404-2:/mnt/upload$ mount | grep mnt
systemd-1 on /mnt type autofs (rw,relatime,fd=56,pgrp=1,timeout=0,minproto=5,maxproto=5,direct,pipe_ino=3978)
192.168.101.1:/srv/share/ on /mnt type nfs (rw,relatime,vers=3,rsize=524288,wsize=524288,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,mountaddr=192.168.101.1,mountvers=3,mountport=58929,mountproto=udp,local_lock=none,addr=192.168.101.1)
user@ubuntu2404-2:/mnt/upload$ ls -l
total 0
-rw-rw-r-- 1 user user 0 июн 22 18:13 check_file
user@ubuntu2404-2:/mnt/upload$ touch final_check
user@ubuntu2404-2:/mnt/upload$  ls -l
total 0
-rw-rw-r-- 1 user user 0 июн 22 18:13 check_file
-rw-rw-r-- 1 user user 0 июн 22 18:23 final_check

# Server

user@ubuntu2404:~$ ls -l /srv/share/upload/
total 0
-rw-rw-r-- 1 user user 0 июн 22 18:13 check_file
-rw-rw-r-- 1 user user 0 июн 22 18:23 final_check
```

# ⭐️ Задание со звездочкой

## Описание задания 

Настроить аутентификацию через KERBEROS с использованием NFSv4

## Решение

### Сервер Kerberos

Установка и конфигурация:

```bash
root@kdc:~# apt install krb5-kdc krb5-admin-server

# Область по умолчанию для Kerberos версии 5: OTUS.EXAMPLE
# Серверы Kerberos для вашей области: KDC.OTUS.EXAMPLE
# Управляющий сервер вашей области Kerberos: KDC.OTUS.EXAMPLE
```

Инициализация и настройка административного доступа:

```bash
root@kdc:~# echo '*/admin@OTUS.EXAMPLE     *' >> /etc/krb5kdc/kadm5.acl

root@kdc:~# krb5_newrealm

root@kdc:~# kadmin.local -q "addprinc admin/admin"
```

Создание принципалов для пользователя, NFS-клиента и NFS-сервера:

```bash
root@kdc:~# kadmin.local -q "addprinc user"
root@kdc:~# kadmin.local -q "addprinc host/nfsc.otus.example@OTUS.EXAMPLE"
root@kdc:~# kadmin.local -q "addprinc -randkey nfs/nfss.otus.example@OTUS.EXAMPLE"
```

### NFS-сервер

Установка и конфигурация:

```bash
root@nfss:~# apt install nfs-kernel-server krb5-user rpcbind

# Область по умолчанию для Kerberos версии 5: OTUS.EXAMPLE
# Серверы Kerberos для вашей области: KDC.OTUS.EXAMPLE
# Управляющий сервер вашей области Kerberos: KDC.OTUS.EXAMPLE

root@nfss:~# sudo systemctl enable --now rpcbind
root@nfss:~# sudo systemctl enable --now nfs-server
```

Добавление ключа:

```bash
root@nfss:~# kadmin -p admin/admin -q "ktadd nfs/nfss.otus.example@OTUS.EXAMPLE"
Authenticating as principal admin/admin with password.
Password for admin/admin@OTUS.EXAMPLE: 
Entry for principal nfs/nfss.otus.example@OTUS.EXAMPLE with kvno 3, encryption type aes256-cts-hmac-sha1-96 added to keytab FILE:/etc/krb5.keytab.
Entry for principal nfs/nfss.otus.example@OTUS.EXAMPLE with kvno 3, encryption type aes128-cts-hmac-sha1-96 added to keytab FILE:/etc/krb5.keytab.
```

Создание каталога для общего доступа:

```bash
root@nfss:~# mkdir -p /srv/nfs/kerbshare
root@nfss:~# chown -R nobody:nogroup /srv/nfs/kerbshare
root@nfss:~# chmod 0777 /srv/nfs/kerbshare
```

Настройка экспорта и проверка:

```bash
root@nfss:~# echo "/srv/nfs/kerbshare *(rw,sync,sec=krb5,no_subtree_check)" >> /etc/exports
root@nfss:~# exportfs -ra
root@nfss:~# exportfs -s
/srv/nfs/kerbshare  *(sync,wdelay,hide,no_subtree_check,fsid=0,sec=krb5,rw,secure,root_squash,no_all_squash)
```

### NFS-клиент

Установка и конфигурация:

```bash
root@nfsc:~# apt install -y nfs-common krb5-user cifs-utils

# Область по умолчанию для Kerberos версии 5: OTUS.EXAMPLE
# Серверы Kerberos для вашей области: KDC.OTUS.EXAMPLE
# Управляющий сервер вашей области Kerberos: KDC.OTUS.EXAMPLE

systemctl enable --now rpc-gssd.service
```

Получение ключа:

```bash
root@nfsc:~# kadmin -p admin/admin -q "ktadd host/nfsc.otus.example@OTUS.EXAMPLE"
Authenticating as principal admin/admin with password.
Password for admin/admin@OTUS.EXAMPLE: 
Entry for principal user/nfsc.otus.example@OTUS.EXAMPLE with kvno 2, encryption type aes256-cts-hmac-sha1-96 added to keytab FILE:/etc/krb5.keytab.
Entry for principal user/nfsc.otus.example@OTUS.EXAMPLE with kvno 2, encryption type aes128-cts-hmac-sha1-96 added to keytab FILE:/etc/krb5.keytab.
```

Монтирование:

```bash
echo 'nfss.otus.example:/srv/nfs/kerbshare /mnt/nfs/kerbshare nfs vers=4,rw,hard,intr,sec=krb5,_netdev 0 0' >> /etc/fstab
mount -a
```

Получение тикета:

```bash
user@nfsc:/mnt/nfs$ kinit user

user@nfsc:/mnt/nfs$ klist
Ticket cache: FILE:/tmp/krb5cc_1000
Default principal: user@OTUS.EXAMPLE

Valid starting       Expires              Service principal
23.06.2026 22:24:29  24.06.2026 08:24:29  krbtgt/OTUS.EXAMPLE@OTUS.EXAMPLE
	renew until 24.06.2026 22:24:24
23.06.2026 22:24:32  24.06.2026 08:24:29  nfs/nfss.otus.example@
	renew until 24.06.2026 22:24:24
	Ticket server: nfs/nfss.otus.example@OTUS.EXAMPLE

```

### Проверка работоспособности

```bash
user@nfsc:/mnt/nfs$ cd /mnt/nfs/kerbshare/
user@nfsc:/mnt/nfs/kerbshare$ touch test_file
user@nfsc:/mnt/nfs/kerbshare$ ls -l
total 0
-rw-rw-r-- 1 user user 0 июн 23 22:24 test_file
```