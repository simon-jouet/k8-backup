FROM alpine:3.9

RUN apk add --no-cache curl gnupg && \
    curl https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl -o /usr/bin/kubectl && \
    chmod +x /usr/bin/kubectl && \
    curl -O https://downloads.rclone.org/rclone-current-linux-amd64.zip && \
    unzip rclone-current-linux-amd64.zip && \
    cd rclone-*-linux-amd64 && \
    cp rclone /usr/bin/ && \
    chmod +x /usr/bin/rclone && \
    cd .. && \
    rm -rf rclone-current-linux-amd64.zip rclone-*-linux-amd64