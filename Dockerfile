# Build the Play application and its distribution.
FROM sbtscala/scala-sbt:1.4.5 AS build
WORKDIR /src

COPY . .
RUN sbt clean stage

# Keep the runtime image small and run the service without root privileges.
FROM eclipse-temurin:11-jre
ENV CEREBRO_PORT=9000
WORKDIR /var/lib/cerebro

RUN groupadd --system --gid 10001 cerebro \
    && useradd --system --uid 10001 --gid cerebro --home-dir /var/lib/cerebro cerebro \
    && mkdir -p /opt/cerebro /var/lib/cerebro \
    && chown -R cerebro:cerebro /opt/cerebro /var/lib/cerebro

COPY --from=build --chown=cerebro:cerebro /src/target/universal/stage/ /opt/cerebro/

USER cerebro
EXPOSE 9000
VOLUME ["/var/lib/cerebro"]

ENTRYPOINT ["/opt/cerebro/bin/cerebro"]
CMD ["-Dhttp.address=0.0.0.0"]
