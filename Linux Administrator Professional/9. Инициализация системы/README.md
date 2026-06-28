# 🎯 Задание по теме "Инициализация системы"

## Описание задания 

1. Написать service, который будет раз в 30 секунд мониторить лог на предмет наличия ключевого слова (файл лога и ключевое слово должны задаваться в /etc/default).
2. Установить spawn-fcgi и создать unit-файл (spawn-fcgi.sevice) с помощью переделки init-скрипта (https://gist.github.com/cea2k/1318020).
3. Доработать unit-файл Nginx (nginx.service) для запуска нескольких инстансов сервера с разными конфигурационными файлами одновременно.

## Решение

### 1. Создание service

Создание файла с конфигурацией:

```bash
root@systemd:~# cat << EOF > /etc/default/watchlog
# Configuration file for my watchlog service
# Place it to /etc/default

# File and word in that file that we will be monit
WORD="ALERT"
LOG=/var/log/watchlog.log
EOF
```

Генерация `/var/log/watchlog.log` с добавлением "ALERT" в конце каждой пятой строки:

```bash
root@systemd:~# tail -n 15 /var/log/syslog | awk 'NR % 5 == 0 {print $0 " ALERT"} NR % 5 != 0 {print}' > /var/log/watchlog.log
root@systemd:~# cat /var/log/watchlog.log
2026-06-28T20:29:07.279508+00:00 ubuntu2604-template systemd[1]: Started systemd-hostnamed.service - Hostname Service.
2026-06-28T20:29:07.280675+00:00 ubuntu2604-template systemd-resolved[884]: System hostname changed to 'systemd'.
2026-06-28T20:29:07.281001+00:00 ubuntu2604-template systemd-hostnamed[1680]: Hostname set to <systemd> (static)
2026-06-28T20:29:18.127145+00:00 ubuntu2604-template systemd[1]: session-1.scope: Deactivated successfully.
2026-06-28T20:29:18.127664+00:00 ubuntu2604-template systemd[1]: session-1.scope: Consumed 1.134s CPU time over 1min 53.203s wall clock time, 43.4M memory peak. ALERT
2026-06-28T20:29:19.077443+00:00 ubuntu2604-template systemd[1]: Started session-3.scope - Session 3 of User user.
2026-06-28T20:29:19.346372+00:00 ubuntu2604-template kernel: audit: type=1400 audit(1782678559.345:190): apparmor="DENIED" operation="open" class="file" profile="who" name="/usr/share/coreutils/locales/uucore/en-US.ftl" pid=1724 comm="who" requested_mask="r" denied_mask="r" fsuid=0 ouid=0
2026-06-28T20:29:37.314409+00:00 ubuntu2604-template systemd[1]: systemd-hostnamed.service: Deactivated successfully.
2026-06-28T20:30:00.758613+00:00 ubuntu2604-template systemd[1]: Starting sysstat-collect.service - system activity accounting tool...
2026-06-28T20:30:00.803556+00:00 ubuntu2604-template systemd[1]: sysstat-collect.service: Deactivated successfully. ALERT
2026-06-28T20:30:00.803796+00:00 ubuntu2604-template systemd[1]: Finished sysstat-collect.service - system activity accounting tool.
2026-06-28T20:32:48.449842+00:00 ubuntu2604-template systemd[1498]: launchpadlib-cache-clean.service - Clean up old files in the Launchpadlib cache skipped, unmet condition check ConditionPathExists=/home/user/.launchpadlib/api.launchpad.net/cache
2026-06-28T20:32:48.468899+00:00 ubuntu2604-template systemd[1]: Starting update-notifier-download.service - Download data for packages that failed at package install time...
2026-06-28T20:32:48.608456+00:00 ubuntu2604-template systemd[1]: update-notifier-download.service: Deactivated successfully.
2026-06-28T20:32:48.608576+00:00 ubuntu2604-template systemd[1]: Finished update-notifier-download.service - Download data for packages that failed at package install time. ALERT
```

Создание скрипта `watchlog.sh` и предоставление права на запуск:

```bash
root@systemd:~# cat << EOF > /opt/watchlog.sh
#!/bin/bash

if [[ -z "\${WORD}" || -z "\${LOG}" ]]; then
    logger "\$(date): ERROR: WORD or LOG variable is not set"
    exit 1
fi

if [[ ! -f "\${LOG}" ]]; then
    logger "\$(date): ERROR: Log file '\${LOG}' does not exist"
    exit 1
fi

DATE=\$(date)
if grep -q -- "\$WORD" "\$LOG"; then
    logger "\$DATE: I found word '\$WORD', Master!"
fi

exit 0
EOF

root@systemd:~# chmod +x /opt/watchlog.sh
root@systemd:~# ls -l !:2
ls -l /opt/watchlog.sh
-rwxr-xr-x 1 root root 130 Jun 28 20:44 /opt/watchlog.sh
```

Создание юнита для `watchlog.service`:

```bash
root@systemd:~# cat << EOF > /etc/systemd/system/watchlog.service
[Unit]
Description=My watchlog service

[Service]
Type=oneshot
EnvironmentFile=/etc/default/watchlog
ExecStart=/opt/watchlog.sh \$WORD \$LOG
EOF
```

Создание юнита для `watchlog.timer`:

```bash
root@systemd:~# cat << EOF > /etc/systemd/system/watchlog.timer
[Unit]
Description=Run watchlog script every 30 second

[Timer]
OnBootSec=30s
OnUnitActiveSec=30s
Unit=watchlog.service

[Install]
WantedBy=multi-user.target
EOF
```

Запуск таймера:

```bash
root@systemd:~# systemctl start watchlog.timer
```

Результат:

```bash
root@systemd:~# journalctl -n 20 -u watchlog.service | grep "I found word"
июн 28 21:34:19 systemd root[3919]: вс 28 июнь 2026 21:34:19 UTC: I found word 'ALERT', Master!
июн 28 21:34:56 systemd root[3968]: вс 28 июнь 2026 21:34:56 UTC: I found word 'ALERT', Master!
июн 28 21:35:48 systemd root[3995]: вс 28 июнь 2026 21:35:48 UTC: I found word 'ALERT', Master!
июн 28 21:36:18 systemd root[4011]: вс 28 июнь 2026 21:36:18 UTC: I found word 'ALERT', Master!
```

### 2. Установка spawn-fcgi и создание юнит-файла

Установка пакетов:

```bash
apt install spawn-fcgi php php-cgi php-cli \
 apache2 libapache2-mod-fcgid -y
```

Создание конфига:

```bash
root@systemd:~# mkdir /etc/spawn-fcgi
root@systemd:~# cat << EOF > /etc/spawn-fcgi/fcgi.conf
# You must set some working options before the "spawn-fcgi" service will work.
# If SOCKET points to a file, then this file is cleaned up by the init script.
#
# See spawn-fcgi(1) for all possible options.
#
# Example :
SOCKET=/var/run/php-fcgi.sock
OPTIONS="-u www-data -g www-data -s \$SOCKET -S -M 0600 -C 32 -F 1 -- /usr/bin/php-cgi"
EOF
```

Создание юнит-файла:

```bash
root@systemd:~# cat << EOF > /etc/systemd/system/spawn-fcgi.service
> [Unit]
Description=Spawn-fcgi startup service by Otus
After=network.target

[Service]
Type=simple
PIDFile=/var/run/spawn-fcgi.pid
EnvironmentFile=/etc/spawn-fcgi/fcgi.conf
ExecStart=/usr/bin/spawn-fcgi -n \$OPTIONS
KillMode=process

[Install]
WantedBy=multi-user.target
EOF
```

Проверка работы:

```bash
root@systemd:~# systemctl start spawn-fcgi
root@systemd:~# systemctl status spawn-fcgi
● spawn-fcgi.service - Spawn-fcgi startup service by Otus
     Loaded: loaded (/etc/systemd/system/spawn-fcgi.service; disabled; preset: enabled)
     Active: active (running) since Sun 2026-06-28 21:48:33 UTC; 5s ago
 Invocation: 81efaa9b4a7b4c48ae70ff31ecd6783a
   Main PID: 11067 (php-cgi)
      Tasks: 33 (limit: 3992)
     Memory: 16M (peak: 16M)
        CPU: 35ms
     CGroup: /system.slice/spawn-fcgi.service
             ├─11067 /usr/bin/php-cgi
             ├─11072 /usr/bin/php-cgi
             ├─11073 /usr/bin/php-cgi
             ├─11074 /usr/bin/php-cgi
             ├─11075 /usr/bin/php-cgi
             ├─11076 /usr/bin/php-cgi
             ├─11077 /usr/bin/php-cgi
             ├─11078 /usr/bin/php-cgi
             ├─11079 /usr/bin/php-cgi
             ├─11080 /usr/bin/php-cgi
             ├─11081 /usr/bin/php-cgi
             ├─11082 /usr/bin/php-cgi
             ├─11083 /usr/bin/php-cgi
             ├─11084 /usr/bin/php-cgi
             ├─11085 /usr/bin/php-cgi
             ├─11086 /usr/bin/php-cgi
             ├─11087 /usr/bin/php-cgi
             ├─11088 /usr/bin/php-cgi
             ├─11089 /usr/bin/php-cgi
             ├─11090 /usr/bin/php-cgi
             ├─11091 /usr/bin/php-cgi
             ├─11092 /usr/bin/php-cgi
             ├─11093 /usr/bin/php-cgi
             ├─11094 /usr/bin/php-cgi
             ├─11095 /usr/bin/php-cgi
             ├─11096 /usr/bin/php-cgi
             ├─11097 /usr/bin/php-cgi
             ├─11098 /usr/bin/php-cgi
             ├─11099 /usr/bin/php-cgi
             ├─11100 /usr/bin/php-cgi
             ├─11101 /usr/bin/php-cgi
             ├─11102 /usr/bin/php-cgi
             └─11103 /usr/bin/php-cgi

июн 28 21:48:33 systemd systemd[1]: Started spawn-fcgi.service - Spawn-fcgi startup service by Otus.
```

### 3. Доработка юнит-файла Nginx

Установка Nginx:

```bash
root@systemd:~# apt install nginx -y
```

Создание юнита для работы с шаблонами на основе дефолтного юнита:

```bash
root@systemd:~# mv /usr/lib/systemd/system/nginx.service /usr/lib/systemd/system/nginx@.service

# Итоговое содержимое nginx@.service
root@systemd:~# cat /usr/lib/systemd/system/nginx@.service
# Stop dance for nginx
# =======================
#
# ExecStop sends SIGQUIT (graceful stop) to the nginx process.
# If, after 5s (--retry QUIT/5) nginx is still running, systemd takes control
# and sends SIGTERM (fast shutdown) to the main process.
# After another 5s (TimeoutStopSec=5), and if nginx is alive, systemd sends
# SIGKILL to all the remaining processes in the process group (KillMode=mixed).
#
# nginx signals reference doc:
# http://nginx.org/en/docs/control.html
#
[Unit]
Description=A high performance web server and a reverse proxy server
Documentation=man:nginx(8)
After=network-online.target remote-fs.target nss-lookup.target
Wants=network-online.target
ConditionFileIsExecutable=/usr/sbin/nginx

[Service]
Type=forking
PIDFile=/run/nginx-%I.pid
ExecStartPre=/usr/sbin/nginx -t -c /etc/nginx/nginx-%I.conf -q -g 'daemon on; master_process on;'
ExecStart=/usr/sbin/nginx -c /etc/nginx/nginx-%I.conf -g 'daemon on; master_process on;'
ExecReload=/usr/sbin/nginx -c /etc/nginx/nginx-%I.conf -g 'daemon on; master_process on;' -s reload
ExecStop=-/sbin/start-stop-daemon --quiet --stop --retry QUIT/5 --pidfile /run/nginx-%I.pid
TimeoutStopSec=5
KillMode=mixed

[Install]
WantedBy=multi-user.target
```

Создание файлов конфигурации Nginx:

```bash
root@systemd:~# cp /etc/nginx/nginx.conf /etc/nginx/nginx-first.conf
root@systemd:~# cp /etc/nginx/nginx.conf /etc/nginx/nginx-second.conf

# Заданы уникальные PID и port в каждом конфиге
root@systemd:~# grep -v '^#' /etc/nginx/nginx-*.conf | grep -e "pid" -e "listen"
/etc/nginx/nginx-first.conf:pid /run/nginx-first.pid;
/etc/nginx/nginx-first.conf:		listen 9001;
/etc/nginx/nginx-second.conf:pid /run/nginx-second.pid;
/etc/nginx/nginx-second.conf:                listen 9002;
```

Проверка nginx@first:

```bash
root@systemd:~# systemctl start nginx@first

root@systemd:~# systemctl status nginx@first
● nginx@first.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx@.service; disabled; preset: enabled)
     Active: active (running) since Sun 2026-06-28 22:10:58 UTC; 34s ago
 Invocation: 1a585610ae5544e4be1b48ecb960db9a
       Docs: man:nginx(8)
    Process: 11885 ExecStartPre=/usr/sbin/nginx -t -c /etc/nginx/nginx-first.conf -q -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
    Process: 11886 ExecStart=/usr/sbin/nginx -c /etc/nginx/nginx-first.conf -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
   Main PID: 11888 (nginx)
      Tasks: 3 (limit: 3992)
     Memory: 3.3M (peak: 3.3M)
        CPU: 26ms
     CGroup: /system.slice/system-nginx.slice/nginx@first.service
             ├─11888 "nginx: master process /usr/sbin/nginx -c /etc/nginx/nginx-first.conf -g daemon on; master_process on;"
             ├─11889 "nginx: worker process"
             └─11890 "nginx: worker process"

июн 28 22:10:58 systemd systemd[1]: Starting nginx@first.service - A high performance web server and a reverse proxy server...
июн 28 22:10:58 systemd systemd[1]: Started nginx@first.service - A high performance web server and a reverse proxy server.

root@systemd:~# ss -tunlp | grep nginx
tcp   LISTEN 0      511                  0.0.0.0:9001      0.0.0.0:*    users:(("nginx",pid=12033,fd=5),("nginx",pid=12032,fd=5),("nginx",pid=12031,fd=5))
```

Проверка nginx@second:


```bash
root@systemd:~# systemctl start nginx@second

root@systemd:~# systemctl status nginx@second
● nginx@second.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx@.service; disabled; preset: enabled)
     Active: active (running) since Sun 2026-06-28 22:13:26 UTC; 1s ago
 Invocation: 84cc3c81e946414b8a0086a23d05bb5f
       Docs: man:nginx(8)
    Process: 11966 ExecStartPre=/usr/sbin/nginx -t -c /etc/nginx/nginx-second.conf -q -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
    Process: 11970 ExecStart=/usr/sbin/nginx -c /etc/nginx/nginx-second.conf -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
   Main PID: 11973 (nginx)
      Tasks: 3 (limit: 3992)
     Memory: 3.3M (peak: 3.3M)
        CPU: 25ms
     CGroup: /system.slice/system-nginx.slice/nginx@second.service
             ├─11973 "nginx: master process /usr/sbin/nginx -c /etc/nginx/nginx-second.conf -g daemon on; master_process on;"
             ├─11974 "nginx: worker process"
             └─11975 "nginx: worker process"

июн 28 22:13:26 systemd systemd[1]: Starting nginx@second.service - A high performance web server and a reverse proxy server...
июн 28 22:13:26 systemd systemd[1]: Started nginx@second.service - A high performance web server and a reverse proxy server.

root@systemd:~# ss -tunlp | grep nginx
tcp   LISTEN 0      511                  0.0.0.0:9001      0.0.0.0:*    users:(("nginx",pid=12033,fd=5),("nginx",pid=12032,fd=5),("nginx",pid=12031,fd=5))
tcp   LISTEN 0      511                  0.0.0.0:9002      0.0.0.0:*    users:(("nginx",pid=11975,fd=5),("nginx",pid=11974,fd=5),("nginx",pid=11973,fd=5))
```
