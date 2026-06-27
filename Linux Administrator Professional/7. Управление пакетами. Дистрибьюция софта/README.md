# 🎯 Задание по теме "Сборка RPM-пакета и создание репозитория"

## Описание задания 

* создать свой RPM (можно взять свое приложение, либо собрать к примеру Apache с определенными опциями);
* cоздать свой репозиторий и разместить там ранее собранный RPM;
* реализовать это все либо в Vagrant, либо развернуть у себя через Nginx и дать ссылку на репозиторий.

## Решение

### Сборка RPM пакета

Установка зависимостей:

```bash
root@repo:~# dnf install -y wget rpmdevtools rpm-build createrepo \
yum-utils cmake gcc git nano
```

Скачивание SRPM пакета NGINX:

```bash
root@repo:~# mkdir nginx && cd nginx
root@repo:~/nginx# dnf download --source nginx
```

Скачивание/обновление исходного пакета и установка зависимостей:

```bash
root@repo:~/nginx# rpm -Uvh nginx*.src.rpm
root@repo:~/nginx# dnf builddep nginx
```

Сборка RPM пакета:

```bash
root@repo:~/rpmbuild/SPECS# rpmbuild -ba nginx.spec -D 'debug_package %{nil}'
```

Результат:

```bash
root@repo:~/rpmbuild/SPECS# ll ../RPMS/noarch/
итого 24
-rw-r--r--. 1 root root  9445 июн 27 11:12 nginx-all-modules-1.26.3-6.el10.4.noarch.rpm
-rw-r--r--. 1 root root 11179 июн 27 11:12 nginx-filesystem-1.26.3-6.el10.4.noarch.rpm
root@repo:~/rpmbuild/SPECS# ll ../RPMS/x86_64/
итого 2252
-rw-r--r--. 1 root root   32582 июн 27 11:12 nginx-1.26.3-6.el10.4.x86_64.rpm
-rw-r--r--. 1 root root 1146026 июн 27 11:12 nginx-core-1.26.3-6.el10.4.x86_64.rpm
-rw-r--r--. 1 root root  896808 июн 27 11:12 nginx-mod-devel-1.26.3-6.el10.4.x86_64.rpm
-rw-r--r--. 1 root root   21445 июн 27 11:12 nginx-mod-http-image-filter-1.26.3-6.el10.4.x86_64.rpm
-rw-r--r--. 1 root root   33452 июн 27 11:12 nginx-mod-http-perl-1.26.3-6.el10.4.x86_64.rpm
-rw-r--r--. 1 root root   20291 июн 27 11:12 nginx-mod-http-xslt-filter-1.26.3-6.el10.4.x86_64.rpm
-rw-r--r--. 1 root root   55192 июн 27 11:12 nginx-mod-mail-1.26.3-6.el10.4.x86_64.rpm
-rw-r--r--. 1 root root   88722 июн 27 11:12 nginx-mod-stream-1.26.3-6.el10.4.x86_64.rpm

```


Установка NGINX:

```bash
root@repo:~/rpmbuild/SPECS# cd ../RPMS/
root@repo:~/rpmbuild/RPMS# rpm -ivh noarch/*.rpm x86_64/*.rpm --nodeps
Verifying...                          ################################# [100%]
Подготовка...               ################################# [100%]
Обновление / установка...
   1:nginx-filesystem-2:1.26.3-6.el10.################################# [ 10%]
   2:nginx-core-2:1.26.3-6.el10.4     ################################# [ 20%]
   3:nginx-2:1.26.3-6.el10.4          ################################# [ 30%]
   4:nginx-mod-http-image-filter-2:1.2################################# [ 40%]
   5:nginx-mod-http-perl-2:1.26.3-6.el################################# [ 50%]
   6:nginx-mod-http-xslt-filter-2:1.26################################# [ 60%]
   7:nginx-mod-mail-2:1.26.3-6.el10.4 ################################# [ 70%]
   8:nginx-mod-stream-2:1.26.3-6.el10.################################# [ 80%]
   9:nginx-all-modules-2:1.26.3-6.el10################################# [ 90%]
  10:nginx-mod-devel-2:1.26.3-6.el10.4################################# [100%]
```

Скачивание исходного кода модуля ngx_brotli:

```bash
root@repo:~/nginx# cd ~/rpmbuild/SOURCES/
root@repo:~/rpmbuild/SOURCES# git clone --recurse-submodules -j8 https://github.com/google/ngx_brotli
root@repo:~/rpmbuild/SOURCES# tar -czf ngx_brotli.tar.gz ngx_brotli/
```

Создание nginx-mod-brotli.spec для модуля ngx_brotli:

```bash
root@repo:~/rpmbuild/SOURCES# cd ~/rpmbuild/SPECS/
root@repo:~/rpmbuild/SPECS# nano nginx-mod-brotli.spec
```

Содержимое nginx-mod-brotli.spec:

```spec
%global nginx_version 1.26.3

Name:           nginx-mod-brotli
Version:        %{nginx_version}
Release:        1%{?dist}
Summary:        Brotli compression dynamic module for nginx
License:        BSD
URL:            https://github.com/google/ngx_brotli
Source0:        ngx_brotli.tar.gz
Source1:        nginx-%{nginx_version}.tar.gz

BuildRequires:  gcc, make, cmake, git
BuildRequires:  pcre2-devel, zlib-ng-compat-devel, openssl-devel

Requires:       nginx-core >= 2:%{nginx_version}

%description
Dynamic Brotli compression module for nginx.
Provides brotli compression support as a loadable module.

%prep
%setup -q -n ngx_brotli

# Собираем brotli библиотеку
cd deps/brotli
mkdir -p out
cd out
cmake -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_SHARED_LIBS=OFF \
      -DCMAKE_INSTALL_PREFIX=%{_builddir}/brotli-install \
      ..
%make_build
cd ../../..

%build
# Распаковываем исходники nginx
tar -xzf %{SOURCE1} -C %{_builddir}

# Переходим в директорию nginx
cd %{_builddir}/nginx-%{nginx_version}

export CFLAGS="-I%{_builddir}/brotli-install/include -O2 -g -pipe -Wall -Wp,-D_FORTIFY_SOURCE=2 -fexceptions -fstack-protector-strong"
export LDFLAGS="-L%{_builddir}/brotli-install/lib64 -L%{_builddir}/brotli-install/lib"

./configure \
    --with-compat \
    --add-dynamic-module=%{_builddir}/ngx_brotli \
    --with-cc-opt="$CFLAGS $(pcre2-config --cflags)" \
    --with-ld-opt="$LDFLAGS"

%make_build modules

%install
# Переходим в директорию с собранными модулями
cd %{_builddir}/nginx-%{nginx_version}

mkdir -p %{buildroot}%{_libdir}/nginx/modules
mkdir -p %{buildroot}%{_datadir}/nginx/modules

# Проверяем наличие собранных модулей
ls -la objs/*.so || echo "No .so files found in objs/"

# Копируем модули
install -m 755 objs/ngx_http_brotli_filter_module.so \
    %{buildroot}%{_libdir}/nginx/modules/ 2>/dev/null || echo "Filter module not found"
install -m 755 objs/ngx_http_brotli_static_module.so \
    %{buildroot}%{_libdir}/nginx/modules/ 2>/dev/null || echo "Static module not found"

# Проверяем, что файлы скопировались
ls -la %{buildroot}%{_libdir}/nginx/modules/

# Создаем конфиг для загрузки модуля
cat > %{buildroot}%{_datadir}/nginx/modules/mod-brotli.conf << EOF
load_module "%{_libdir}/nginx/modules/ngx_http_brotli_filter_module.so";
load_module "%{_libdir}/nginx/modules/ngx_http_brotli_static_module.so";
EOF

%files
%{_libdir}/nginx/modules/ngx_http_brotli_filter_module.so
%{_libdir}/nginx/modules/ngx_http_brotli_static_module.so
%{_datadir}/nginx/modules/mod-brotli.conf

%post
if [ $1 -eq 1 ]; then
    /usr/bin/systemctl reload nginx.service >/dev/null 2>&1 || :
fi

%changelog
* Sat Jun 27 2026 Vyacheslav Maksimov <slavaamaksimov@gmail.com> - 1.26.3-1
- Initial build of nginx-mod-brotli
```

Сборка модуля ngx_brotli:

```bash
root@repo:~/rpmbuild/SPECS# rpmbuild -ba nginx-mod-brotli.spec
```

Результат:

```bash
root@repo:~/rpmbuild/SPECS# ll ../RPMS/x86_64/ | grep brotli
-rw-r--r--. 1 root root  362248 июн 27 12:48 nginx-mod-brotli-1.26.3-1.el10.x86_64.rpm
-rw-r--r--. 1 root root   65334 июн 27 12:48 nginx-mod-brotli-debuginfo-1.26.3-1.el10.x86_64.rpm
-rw-r--r--. 1 root root   21929 июн 27 12:48 nginx-mod-brotli-debugsource-1.26.3-1.el10.x86_64.rpm

```

Установка модуля ngx_brotli:

```bash
root@repo:~/rpmbuild/SPECS# cd ../RPMS/x86_64/
root@repo:~/rpmbuild/RPMS/x86_64# rpm -ivh nginx-mod-brotli-1.26.3-1.el10.x86_64.rpm
Verifying...                          ################################# [100%]
Подготовка...               ################################# [100%]
Обновление / установка...
   1:nginx-mod-brotli-1.26.3-1.el10   ################################# [100%]
```

Проверка, что модуль загружен:

```bash
root@repo:~/rpmbuild/RPMS/x86_64# nginx -T 2>&1 | grep -i brotli
# configuration file /usr/share/nginx/modules/mod-brotli.conf:
load_module "/usr/lib64/nginx/modules/ngx_http_brotli_filter_module.so";
load_module "/usr/lib64/nginx/modules/ngx_http_brotli_static_module.so";
```


### Создание репозитория

Подготовка:

```bash
root@repo:~/rpmbuild/RPMS# mkdir /usr/share/nginx/html/repo
root@repo:~/rpmbuild/RPMS# cp -r ./ /usr/share/nginx/html/repo
```

Инициализация:

```bash
root@repo:~/rpmbuild/RPMS# createrepo /usr/share/nginx/html/repo/
Directory walk started
Directory walk done - 13 packages
Temporary output repo path: /usr/share/nginx/html/repo/.repodata/
Pool started (with 5 workers)
Pool finished
```

В основной конфиг nginx `/etc/nginx/nginx.conf` в блок server добавить:

```
	index index.html index.htm;
	autoindex on;
```

Применение:

```bash
root@repo:~/rpmbuild/RPMS# nginx -t
root@repo:~/rpmbuild/RPMS# nginx -s reload
```

Проверка:

```bash
root@repo:~/rpmbuild/RPMS# curl -a http://localhost/repo/
<html>
<head><title>Index of /repo/</title></head>
<body>
<h1>Index of /repo/</h1><hr><pre><a href="../">../</a>
<a href="noarch/">noarch/</a>                                            27-Jun-2026 11:42                   -
<a href="repodata/">repodata/</a>                                          27-Jun-2026 11:43                   -
<a href="x86_64/">x86_64/</a>                                            27-Jun-2026 11:42                   -
</pre><hr></body>
</html>
```

Добавление репозитория:

```bash
root@repo:~/rpmbuild/RPMS# dnf config-manager --add-repo=http://localhost/repo/
Добавление репозитория из: http://localhost/repo/

root@repo:~/rpmbuild/RPMS# dnf makecache
AlmaLinux 10 - AppStream      5.8 kB/s | 3.8 kB     00:00    
AlmaLinux 10 - BaseOS         8.2 kB/s | 3.8 kB     00:00    
AlmaLinux 10 - CRB            8.2 kB/s | 3.8 kB     00:00    
AlmaLinux 10 - Extras         7.4 kB/s | 3.5 kB     00:00    
created by dnf config-manager from http://localhost/repo/           140 kB/s | 3.3 kB     00:00    
Создан кэш метаданных.
```

Проверка, что репозиторий активен:

```bash
root@repo:~/rpmbuild/RPMS# dnf repolist
идентификатор репозитория           имя репозитория
appstream                           AlmaLinux 10 - AppStream
baseos                              AlmaLinux 10 - BaseOS
crb                                 AlmaLinux 10 - CRB
extras                              AlmaLinux 10 - Extras
localhost_repo_                     created by dnf config-manager from http://localhost/repo/
```

Добавление пакета percona в репозиторий:

```bash
root@repo:~/rpmbuild/RPMS# cd /usr/share/nginx/html/repo/
root@repo:/usr/share/nginx/html/repo# wget https://repo.percona.com/yum/percona-release-latest.noarch.rpm
root@repo:/usr/share/nginx/html/repo# createrepo /usr/share/nginx/html/repo/
Directory walk started
Directory walk done - 14 packages
Temporary output repo path: /usr/share/nginx/html/repo/.repodata/
Pool started (with 5 workers)
Pool finished
```

Обновление кеша пакетов и поиск percona:

```bash
root@repo:/usr/share/nginx/html/repo# dnf makecache
root@repo:/usr/share/nginx/html/repo# dnf search percona
Последняя проверка окончания срока действия метаданных: 0:00:35 назад, Сб 27 июн 2026 15:01:52.
============================== Имя и Краткое описание совпадение: percona ==============================
percona-release.noarch : Package to install Percona GPG key and YUM repo
```

Проверка, что пакет найден в нашем репозитории:

```bash
root@repo:/usr/share/nginx/html/repo# dnf repoquery --location percona-release
Последняя проверка окончания срока действия метаданных: 0:02:18 назад, Сб 27 июн 2026 15:01:52.
http://localhost/repo/percona-release-latest.noarch.rpm
```

Установка и проверка:

```bash
root@repo:/usr/share/nginx/html/repo# dnf install --nogpgcheck percona-release.noarch
root@repo:/usr/share/nginx/html/repo# dnf list installed percona-release
Установленные пакеты
percona-release.noarch   1.0-33   @localhost_repo_
```