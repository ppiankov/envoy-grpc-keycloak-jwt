FROM envoyproxy/envoy:v1.18.3

COPY envoy.yaml /etc/envoy/envoy.yaml

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install the latest protoc compiler
RUN curl -OL https://github.com/protocolbuffers/protobuf/releases/download/v3.19.1/protoc-3.19.1-linux-x86_64.zip && \
    unzip protoc-3.19.1-linux-x86_64.zip -d /usr/local && \
    rm protoc-3.19.1-linux-x86_64.zip

# Clone googleapis repository
RUN git clone https://github.com/googleapis/googleapis.git /usr/local/include/googleapis

# Verify protoc version
RUN protoc --version

# Copy proto files into the container
COPY protos /tmp/protos

RUN protoc \
  -I /tmp/protos \
  -I /usr/local/include \
  -I /usr/local/include/googleapis \
  --include_imports \
  --include_source_info \
  --descriptor_set_out=/etc/envoy/proto_descriptor.pb \
  /tmp/protos/service1/v1/service1.proto \
  /tmp/protos/service2/v1/service2.proto \
  /tmp/protos/service3/v1/service3.proto

# Expose the envoy port
EXPOSE 8080

# # Run envoy with the specified configuration
# CMD ["envoy", "-c", "/etc/envoy/envoy.yaml"]

# Run envoy with the specified configuration and log level
CMD ["envoy", "-c", "/etc/envoy/envoy.yaml", "-l", "debug"]