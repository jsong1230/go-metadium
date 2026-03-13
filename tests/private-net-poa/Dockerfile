# Use the locally built rocksdb-test image which already has librocksdb6.11 installed
# (avoids pulling new images from Docker Hub)
FROM go-metadium-rocksdb-test:latest

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY gmet /usr/local/bin/gmet
RUN chmod +x /usr/local/bin/gmet

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8545 8546 30303 30303/udp

ENTRYPOINT ["/entrypoint.sh"]
