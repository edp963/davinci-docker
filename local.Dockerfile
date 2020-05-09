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
&&  chmod +x /opt/phantomjs-2.1.1

FROM  openjdk:8u242-jdk AS base

LABEL MAINTAINER="edp_support@groups.163.com"

WORKDIR /opt/davinci

COPY --from=build /opt /opt

ENV DAVINCI3_HOME  /opt/davinci
ENV PHANTOMJS_HOME /opt/phantomjs-2.1.1
ENV OPENSSL_CONF=/etc/ssl/
#ENV JAVA_OPTS "-agentlib:jdwp=transport=dt_socket,server=y,address=53733,suspend=y"

CMD ["./bin/start-server.sh"]

EXPOSE 8080
#EXPOSE 53733
