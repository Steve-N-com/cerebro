# Build with the project's pinned sbt version on Java 11.
FROM eclipse-temurin:11-jdk AS build
WORKDIR /src

RUN apt-get update \
    && apt-get install -y --no-install-recommends bash curl ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL https://raw.githubusercontent.com/paulp/sbt-extras/master/sbt -o /usr/local/bin/sbt \
    && chmod +x /usr/local/bin/sbt

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
