### 环境要求

1. 安装docker后的 windows,linux,mac
2. Docker版本： 18.02.0+
3. 检查是否有docker-compose命令（安装docker后默认会有，否则请手动[安装](https://docs.docker.com/compose/install/)）

### 极速启动

在任意目录 (建议找个空目录)执行以下命令  

```
curl https://raw.githubusercontent.com/edp963/davinci-docker/master/docker-compose.yml > docker-compose.yml
vim docker-compose.yml
# 修改邮箱配置,否则无法登录

#docker老手使用以下命令
docker-compose up -d 

#docker新手用以下命令
docker-compose --verbose up
```
等待一分钟左右,用浏览器打开以下链接: 

[http://localhost:58080](http://localhost:58080)

### 注意事项

**请确认邮箱配置正确！！！否则注册不了用户，从而登录不了**

### Docker Compose基本操作

```
docker-compose [-f docker-compose.yml] down   # 停止当前配置文件中所有容器
docker exec -it xxxxx /bin/bash   # xxx代表容器ID或者Name,用这个命令可以进入容器内执行命令
docker tag <oldtag> <newtag>   # 给镜像贴新标签
```

### 本地构建davinci镜像

1. 将phantomjs下载到当前目录phantomjs文件夹中， `./phantomjs/phantomjs`
2. 若使用chrome驱动，则使用`selenium/standalone-chrome`镜像,docker-compose中已配置好
3. 将mvn package命令产生的zip包拷贝到当前目录,原包路径为`davinci项目\assembly\target\davinci-assembly_3.0.1-0.3.1-SNAPSHOT-dist-beta.xxxxxx.zip`

```
docker build -f local.Dockerfile -t="local/davinci:v0.3.0-beta.9" --build-arg DAVINCI_ZIP=你的davincizip包文件名 .
```

### Docker支持环境变量列表

*以下环境变量将直接覆盖spring boot配置文件*

[spring boot应用配置文档-环境变量](https://docs.spring.io/spring-boot/docs/current/reference/html/spring-boot-features.html#boot-features-external-config-application-property-files)

变量|描述
-|-
SERVER_ADDRESS|davinci域名
SPRING_DATASOURCE_URL|
SPRING_DATASOURCE_USERNAME|
SPRING_DATASOURCE_PASSWORD|
SPRING_DATASOURCE_TEST_ON_BORROW|
SPRING_DATASOURCE_TIME_BETWEEN_EVICTION_RUNS_MILLIS|
SPRING_MAIL_HOST|
SPRING_MAIL_PORT|
SPRING_MAIL_USERNAME|
SPRING_MAIL_PASSWORD|
SPRING_MAIL_NICKNAME|
SPRING_MAIL_PROPERTIES_MAIL_SMTP_SSL_ENABLE|
SCREENSHOT_PHANTOMJS_PATH|

### 原理分析

#### 制作davinci docker镜像

**1. Dockfile分析**
```
FROM java:8-jre

LABEL MAINTAINER="edp_support@groups.163.com"

# 从github上下载分发包并解压

RUN cd / \
	&& mkdir -p /opt/davinci \
	&& wget https://github.com/edp963/davinci/releases/download/v0.3.0-beta.9/davinci-assembly_3.0.1-0.3.1-SNAPSHOT-dist-beta.9.zip \
	&& unzip davinci-assembly_3.0.1-0.3.1-SNAPSHOT-dist-beta.9.zip -d /opt/davinci\
	&& rm -rf davinci-assembly_3.0.1-0.3.1-SNAPSHOT-dist-beta.9.zip

# 将phantomjs打包到镜像

RUN mkdir -p /opt/phantomjs-2.1.1 \
    && wget https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-2.1.1-linux-x86_64.tar.bz2 \
	&& unzip phantomjs-2.1.1-linux-x86_64.tar.bz2 \
	&& rm -rf phantomjs-2.1.1-linux-x86_64.tar.bz2 \
	&& mv phantomjs-2.1.1-linux-x86_64/bin/phantomjs /opt/phantomjs-2.1.1/phantomjs \
	&& rm -rf phantomjs-2.1.1-linux-x86_64

# 数据库初始化脚本，等待数据库就绪后启动spring boot

ADD bin/docker-entrypoint.sh /opt/davinci/bin/docker-entrypoint.sh

# 预设davinci必备的环境变量
ENV DAVINCI3_HOME /opt/davinci

WORKDIR /opt/davinci

# 为什么使用CMD而不是ENTRYPOINT? 因为CMD可以在docker run的时候被替代
# 在使用compose或K8S时，很有可能要在启动前执行其它脚本，而不是直接运行
# start-server.sh
# 在单独docker run且不附加任何命令时，以下命令默认执行

CMD ["./bin/start-server.sh"]

EXPOSE 8080
```

docker-entrypoint.sh

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
docker build -t="edp963/davinci:v0.3.0-beta.9" .
```

**3. docker compose**

```
version: '3.6'
services:
  davinci:
    environment:
      - SERVER_ADDRESS=0.0.0.0
      - SPRING_DATASOURCE_URL=jdbc:mysql://mysql:3306/davinci0.3?useUnicode=true&characterEncoding=UTF-8&zeroDateTimeBehavior=convertToNull&allowMultiQueries=true
      - SPRING_DATASOURCE_USERNAME=root
      - SPRING_DATASOURCE_PASSWORD=abc123123
      - SPRING_DATASOURCE_TEST_ON_BORROW=true
      - SPRING_DATASOURCE_TIME_BETWEEN_EVICTION_RUNS_MILLIS=6000
      - SPRING_MAIL_HOST=smtp.163.com
      - SPRING_MAIL_PORT=465
      - SPRING_MAIL_USERNAME=xxxxxx@163.com
      - SPRING_MAIL_PASSWORD=xxxxxxxx
      - SPRING_MAIL_NICKNAME=davinci
      - SPRING_MAIL_PROPERTIES_MAIL_SMTP_SSL_ENABLE=true
      - SCREENSHOT_PHANTOMJS_PATH=/opt/phantomjs-2.1.1/phantomjs
    image: "edp963/davinci:v0.3.0-beta.9"
    ports:
      - 58080:8080
    # 等待mysql就绪后再启动spring boot主程序
    command: ["./bin/docker-entrypoint.sh", "mysql:3306", "--", "start-server.sh"]
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
docker run -p 58081:8080 -e SPRING_DATASOURCE_URL="jdbc:mysql://yourmysqlserver:3306/davinci0.3?useUnicode=true&characterEncoding=UTF-8&zeroDateTimeBehavior=convertToNull&allowMultiQueries=true" \
-e SPRING_DATASOURCE_USERNAME="root" -e SPRING_DATASOURCE_PASSWORD="pwd" \
-e SPRING_MAIL_HOST="smtp.163.com"  -e SPRING_MAIL_PORT="465" -e SPRING_MAIL_PROPERTIES_MAIL_SMTP_SSL_ENABLE="true" \
-e SPRING_MAIL_USERNAME="xxxxxx@163.com"  -e SPRING_MAIL_PASSWORD="xxxxxxx" \
-e SPRING_MAIL_NICKNAME="davinci_sys" \
edp963/davinci:v0.3.0-beta.9
```

**6.使用更丰富的配置**

可以在宿主中添加一些配置文件，查看[davinci配置](https://github.com/edp963/davinci/tree/master/config)

然后docker run 时将其挂载到 `/opt/davinci/config` 

```
docker run -p 58081:8080 -e SPRING_DATASOURCE_URL="jdbc:mysql://yourmysqlserver:3306/davinci0.3?useUnicode=true&characterEncoding=UTF-8&zeroDateTimeBehavior=convertToNull&allowMultiQueries=true" \
-e SPRING_DATASOURCE_USERNAME="root" -e SPRING_DATASOURCE_PASSWORD="pwd" \
-e SPRING_MAIL_HOST="smtp.163.com"  -e SPRING_MAIL_PORT="465" -e SPRING_MAIL_PROPERTIES_MAIL_SMTP_SSL_ENABLE="true" \
-e SPRING_MAIL_USERNAME="xxxxxx@163.com"  -e SPRING_MAIL_PASSWORD="xxxxxxx" \
-e SPRING_MAIL_NICKNAME="davinci_sys" \
-v /etc/davinci:/opt/davinci/config \
edp963/davinci:v0.3.0-beta.9
```

**7.挂载其它驱动包**

在docker-compose.yaml中添加以下
```
volumes:
  -xxx.jar:/opt/davinci/lib/xxxx.jar
```