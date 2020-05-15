FROM  alpine:3.9.5 AS build

ARG DAVINCI_ZIP

ADD $DAVINCI_ZIP /

RUN mkdir -p /opt/davinci && unzip $DAVINCI_ZIP -d /opt/davinci \
&& rm -rf $DAVINCI_ZIP \
&& cp -v /opt/davinci/config/application.yml.example /opt/davinci/config/application.yml

# 此dockerfile 用于在本地构建，提前把程序包及phantomjs下载到本地
ADD phantomjs /opt/phantomjs-2.1.1
ADD bin/docker-entrypoint.sh /opt/davinci/bin/docker-entrypoint.sh

RUN chmod +x /opt/davinci/bin/docker-entrypoint.sh \
&&  chmod +x /opt/phantomjs-2.1.1/phantomjs

#FROM  openjdk:8u242-jdk AS base
FROM selenium/standalone-chrome

LABEL MAINTAINER="edp_support@groups.163.com"

WORKDIR /opt/davinci

COPY --from=build /opt /opt

ENV OPENSSL_CONF=/etc/ssl/
ENV DAVINCI3_HOME  /opt/davinci
ENV PHANTOMJS_HOME /opt/phantomjs-2.1.1
ENV SCREENSHOT_PHANTOMJS_PATH=/opt/phantomjs-2.1.1/phantomjs
#ENV SCREENSHOT_DEFAULT_BROWSER=CHROME
ENV SCREENSHOT_TIMEOUT_SECOND=30

#ENV JAVA_OPTS "-agentlib:jdwp=transport=dt_socket,server=y,address=53733,suspend=y"

CMD ["./bin/start-server.sh"]

EXPOSE 8080
#EXPOSE 53733