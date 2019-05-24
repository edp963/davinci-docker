### 环境要求

1. 安装docker后的 windows,linux,mac
2. Docker版本： 18.02.0+
3. 检查是否有docker-compose命令（安装docker后默认会有，否则请手动安装）

### 完整步骤

```
git clone https://github.com/edp963/davinci-docker.git
cd /d davinci-docker
# 修改docker-compose.yml中邮箱配置
docker-compose up -d 
```

[http://localhost:58080](http://localhost:58080)

### 注意事项

**请确认邮箱配置正确！！！否则注册不了用户，从而登录不了**


### Docker支持环境变量列表

变量|描述|默认值
-|-|-
HOST_DAVINCI|server.address，绑定域名|0.0.0.0
MYSQL_CONN|datasource.url，jdbc mysql连接串|
DB_USER|datasource.username|
DB_PWD|datasource.password|
MAIL_HOST|mail.host
MAIL_PORT|mail.port
MAIL_USER|mail.username
MAIL_PWD|mail.password
MAIL_NICKNAME|mail.nickname
SMTP_TLS|mail.properties.smtp.starttls.enable|true
SMTP_TLS_REQUIRED|mail.properties.smtp.starttls.required|true
SMTP_AUTH|mail.properties.smtp.auth|true
MAIL_STMP_SSL|mail.properties.mail.smtp.ssl.enable|false

### 原理分析

#### 制作davinci docker镜像

**1. Dockfile分析**
```
FROM java:8-jre

LABEL MAINTAINER="edp_support@groups.163.com"

# 从github上下载分发包并解压

RUN cd / \
	&& mkdir -p /opt/davinci\
	&& wget https://github.com/edp963/davinci/releases/download/v0.3.0-beta.5/davinci-assembly_3.0.1-0.3.1-SNAPSHOT-dist-beta.5.zip \
	&& unzip davinci-assembly_3.0.1-0.3.1-SNAPSHOT-dist-beta.5.zip -d /opt/davinci

# 将phantomjs打包到镜像

ADD phantomjs-2.1.1 /opt/phantomjs-2.1.1
RUN chmod +x /opt/phantomjs-2.1.1/phantomjs

# 数据库初始化脚本，等待数据库就绪后启动spring boot

ADD bin/start.sh /opt/davinci/bin/start.sh
RUN chmod +x /opt/davinci/bin/start.sh

# docker镜像是静态的，因此配置文件中的配置需要用环境变量传递，详见12factor
# https://12factor.net/zh_cn/

ADD config/application.yml /opt/davinci/config/application.yml

# 预设davinci必备的两个环境变量
ENV DAVINCI3_HOME /opt/davinci
ENV PHANTOMJS_HOME /opt/phantomjs-2.1.1

WORKDIR /opt/davinci

# 为什么使用CMD而不是ENTRYPOINT? 因为CMD可以在docker run的时候被替代
# 在使用compose或K8S时，很有可能要在启动前执行其它脚本，而不是直接运行
# start-server.sh
# 在单独docker run且不附加任何命令时，以下命令默认执行

CMD ["./bin/start-server.sh"]

EXPOSE 8080
```

start.sh

```shell
#!/bin/bash

# 将sql脚本经过mysql8兼容处理后，写入/initdb目录
# /initdb 目录是与mysql容器共享目录
# mysql容器将在启动时执行 /docker-entrypoint-initdb.d 中的所有脚本

cd /opt/davinci/bin/
mkdir /initdb
cat davinci.sql > /initdb/davinci.sql
sed -i '1i\SET GLOBAL log_bin_trust_function_creators = 1;' /initdb/davinci.sql


# 由于docker compose中启动顺序管理交给了容器自己
# 详见 https://docs.docker.com/compose/startup-order/
# 因此我们需要用curl探测mysql端口，当接受数据字节大于0时认为
# 数据库可以连通，接下来我们执行davinci spring boot主程序
set -e

host="$1"
shift
cmd="$@"

until [ $(curl -I -m 10 -o /dev/null -s -w %{size_download} $host) -gt 0 ]; do
  >&2 echo "database is unavailable - sleeping"
  sleep 1
done

source $cmd
```

**2. 构建镜像**

```
docker build -t="edp963/davinci:v0.3.0-beta.5" .
```

**3. docker compose**

```
version: '3.6'
services:
  davinci:
    environment:
      - MYSQL_CONN=jdbc:mysql://mysql:3306/davinci0.3?useUnicode=true&characterEncoding=UTF-8&zeroDateTimeBehavior=convertToNull&allowMultiQueries=true
      - DB_USER=root
      - DB_PWD=abc123123
      - MAIL_HOST=smtp.163.com
      - MAIL_PORT=465
      - MAIL_STMP_SSL=true
      - MAIL_USER=xxxxxx@163.com
      - MAIL_PWD=xxxxxxxx
      - MAIL_NICKNAME=davinci
    image: "edp963/davinci:v0.3.0-beta.5"
    ports:
      - 58080:8080
    # 等待mysql就绪后再启动spring boot主程序
    command: ["./bin/start.sh", "mysql:3306", "--", "start-server.sh"]
    restart: always
    volumes:
      - davinci_logs:/opt/davinci/logs
      - davinci_userfiles:/opt/davinci/userfiles
      - davinci_initdb:/initdb  #共享给mysql作数据初始化
  mysql:
    image: mysql:8
    restart: always
    environment:
      - MYSQL_ROOT_PASSWORD=abc123123
      - MYSQL_DATABASE=davinci0.3
    volumes:
      - mysql_data:/var/lib/mysql
      # 初始化脚本源自davinic容器的initdb目录
      - davinci_initdb:/docker-entrypoint-initdb.d:ro   

volumes:
  davinci_userfiles:
  davinci_logs:
  davinci_initdb:
  mysql_data:

    
```

*小提示：docker-compose.yml环境变量配置K=V中不能出现空格，V也不能用双引号包裹*

**4. docker compose启动**

```
docker-compose up -d 
```

**5.仅docker启动(使用外部数据库)**

```
docker run -p 58081:8080 -e MYSQL_CONN="jdbc:mysql://yourmysqlserver:3306/davinci0.3?useUnicode=true&characterEncoding=UTF-8&zeroDateTimeBehavior=convertToNull&allowMultiQueries=true" \
-e DB_USER="root" -e DB_PWD="pwd" \
-e MAIL_HOST="smtp.163.com"  -e MAIL_PORT="465" -e MAIL_STMP_SSL="true" \
-e MAIL_USER="xxxxxx@163.com"  -e MAIL_PWD="xxxxxxx" \
-e MAIL_NICKNAME="davinci_sys" \
edp963/davinci:v0.3.0-beta.5
```

**6.使用更丰富的配置**

可以在宿主中添加一些配置文件，查看[davinci配置](https://github.com/edp963/davinci/tree/master/config)

然后docker run 时将其挂载到 `/opt/davinci/config` 

```
docker run -p 58081:8080 -e MYSQL_CONN="jdbc:mysql://yourmysqlserver:3306/davinci0.3?useUnicode=true&characterEncoding=UTF-8&zeroDateTimeBehavior=convertToNull&allowMultiQueries=true" \
-e DB_USER="root" -e DB_PWD="pwd" \
-e MAIL_HOST="smtp.163.com"  -e MAIL_PORT="465" -e MAIL_STMP_SSL="true" \
-e MAIL_USER="xxxxxx@163.com"  -e MAIL_PWD="xxxxxxx" \
-e MAIL_NICKNAME="davinci_sys" \
-v /etc/davinci:/opt/davinci/config \
edp963/davinci:v0.3.0-beta.5
```
