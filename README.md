# envoy-grpc-keycloak-jwt

**Envoy gRPC Integration with Keycloak for JWT Authentication**

## Overview

The **envoy-grpc-keycloak-jwt** project demonstrates how to configure Envoy Proxy to integrate with gRPC services using JWT authentication via Keycloak. Envoy acts as a gateway, enabling HTTP/JSON clients to communicate with gRPC services seamlessly through JSON transcoding, while securing access with JWT tokens issued by Keycloak.

## Table of Contents

- [Requirements](#requirements)
- [Installation and Build](#installation-and-build)
- [Project Structure](#project-structure)
- [Envoy Configuration](#envoy-configuration)
  - [Clusters](#clusters)
  - [Routes](#routes)
  - [Filters](#filters)
    - [JWT Authentication Filter](#jwt-authentication-filter)
    - [gRPC-JSON Transcoder Filter](#grpc-json-transcoder-filter)
    - [Lua Authorization Filter](#lua-authorization-filter)
- [Adding Proto Files and Routes](#adding-proto-files-and-routes)
- [Example Requests](#example-requests)
- [Authorization Enhancements](#authorization-enhancements)
  - [Implementing Authorization with Lua](#implementing-authorization-with-lua)
- [Debugging](#debugging)
- [License](#license)

## Requirements

- **Docker**: For building and running the Envoy container.
- **Protobuf Compiler (`protoc`)**: For compiling `.proto` files.
- **Git**: For cloning necessary repositories.
- **Keycloak**: As the Identity Provider for JWT authentication.

## Installation and Build

1. **Clone the Repository:**

   ```bash
   git clone https://github.com/your-username/envoy-grpc-keycloak-jwt.git
   cd envoy-grpc-keycloak-jwt
  ```

## Project Structure:

```bash
/envoy-grpc-keycloak-jwt
├── Dockerfile
├── envoy.yaml
├── protos
│   ├── service1/v1/service1.proto
│   ├── service2/v1/service2.proto
│   └── service3/v1/service3.proto
└── README.md


	•	Dockerfile: Defines the build process for the Envoy Docker image, including compiling proto files.
	•	envoy.yaml: Envoy configuration file specifying listeners, clusters, routes, and filters.
	•	protos/: Directory containing all .proto files for the gRPC services. - not included
	•	README.md: This documentation file.

```

### Envoy Configuration

1. Clusters

Clusters define the upstream gRPC services that Envoy will communicate with. Each cluster corresponds to a specific gRPC service.

```bash
clusters:
  - name: service1_grpc_cluster
    connect_timeout: 0.25s
    type: STRICT_DNS
    lb_policy: ROUND_ROBIN
    http2_protocol_options: {}
    load_assignment:
      cluster_name: service1_grpc_cluster
      endpoints:
        - lb_endpoints:
            - endpoint:
                address:
                  socket_address:
                    address: service1.namespace.svc.cluster.local
                    port_value: 50051

  - name: service2_grpc_cluster
    connect_timeout: 0.25s
    type: STRICT_DNS
    lb_policy: ROUND_ROBIN
    http2_protocol_options: {}
    load_assignment:
      cluster_name: service2_grpc_cluster
      endpoints:
        - lb_endpoints:
            - endpoint:
                address:
                  socket_address:
                    address: service2.namespace.svc.cluster.local
                    port_value: 50052

  - name: service3_grpc_cluster
    connect_timeout: 0.25s
    type: STRICT_DNS
    lb_policy: ROUND_ROBIN
    http2_protocol_options: {}
    load_assignment:
      cluster_name: service3_grpc_cluster
      endpoints:
        - lb_endpoints:
            - endpoint:
                address:
                  socket_address:
                    address: service3.namespace.svc.cluster.local
                    port_value: 50053

  - name: keycloak_cluster
    connect_timeout: 5s
    type: LOGICAL_DNS
    lb_policy: ROUND_ROBIN
    load_assignment:
      cluster_name: keycloak_cluster
      endpoints:
        - lb_endpoints:
            - endpoint:
                address:
                  socket_address:
                    address: keycloak.yourdomain.com
                    port_value: 8080
```


2. Routes

Routes map incoming HTTP requests to the appropriate gRPC services based on the request path. By using prefix matching and path rewriting, you can simplify external URLs without modifying proto file annotations.

```bash
route_config:
  name: local_route
  virtual_hosts:
    - name: backend
      domains: ["*"]
      routes:
        # Service1 Routes
        - match:
            prefix: "/api/service1/v1/"
          route:
            cluster: service1_grpc_cluster
            prefix_rewrite: "/api/service1/v1/"

        # Service2 Routes
        - match:
            prefix: "/api/service2/v1/"
          route:
            cluster: service2_grpc_cluster
            prefix_rewrite: "/api/service2/v1/"

        # Service3 Routes
        - match:
            prefix: "/api/service3/v1/"
          route:
            cluster: service3_grpc_cluster
            prefix_rewrite: "/api/service3/v1/"
```

3. Filters

Filters process HTTP requests and responses. This configuration includes JWT authentication and gRPC-JSON transcoding.


```bash
http_filters:
  - name: envoy.filters.http.jwt_authn
    typed_config:
      "@type": type.googleapis.com/envoy.extensions.filters.http.jwt_authn.v3.JwtAuthentication
      providers:
        keycloak_provider:
          issuer: "http://keycloak.yourdomain.com/realms/YourRealm"
          remote_jwks:
            http_uri:
              uri: "http://keycloak.yourdomain.com/realms/YourRealm/protocol/openid-connect/certs"
              cluster: keycloak_cluster
              timeout: 5s
          from_headers:
            - name: "Authorization"
              value_prefix: "Bearer "
          forward: true
      rules:
        - match:
            prefix: "/"
          requires:
            provider_name: "keycloak_provider"

  - name: envoy.filters.http.grpc_json_transcoder
    typed_config:
      "@type": type.googleapis.com/envoy.extensions.filters.http.grpc_json_transcoder.v3.GrpcJsonTranscoder
      proto_descriptor: "/etc/envoy/proto_descriptor.pb"
      services: 
        - "service1.v1.Service1"
        - "service2.v1.Service2"
        - "service3.v1.Service3"
      print_options:
        add_whitespace: true
        always_print_primitive_fields: true
        always_print_enums_as_ints: false
        preserve_proto_field_names: false

  - name: envoy.filters.http.router
```


### Adding Proto Files and Routes

1. Adding New Proto Files

Add your new .proto files to the protos/ directory, maintaining the directory structure that reflects the package names.

```bash
/protos
  /service1/v1/service1.proto
  /service2/v1/service2.proto
  /service3/v1/service3.proto
  /newservice/v1/newservice.proto
```

2. Update the Dockerfile to Compile All Proto Files:

```Dockerfile
# Copy all proto files into the container
COPY protos /tmp/protos

# Compile all proto files into a single descriptor set
RUN protoc \
  -I /tmp/protos \
  -I /usr/local/include \
  -I /usr/local/include/googleapis \
  --include_imports \
  --include_source_info \
  --descriptor_set_out=/etc/envoy/proto_descriptor.pb \
  $(find /tmp/protos -name "*.proto")
```


## Build the Docker Image:

docker build -t envoy-grpc-keycloak-jwt .


## Adding New Routes

1. efine a New Route in envoy.yaml:

Add a new route under the routes section to map the external path to the internal gRPC service.

```bash
- match:
    prefix: "/api/newservice/v1/"
  route:
    cluster: new_service_grpc_cluster
    prefix_rewrite: "/api/newservice/v1/"
```

## Add the Corresponding Cluster:

1. Define a new cluster for the new gRPC service.

```bash
- name: new_service_grpc_cluster
  connect_timeout: 0.25s
  type: STRICT_DNS
  lb_policy: ROUND_ROBIN
  http2_protocol_options: {}
  load_assignment:
    cluster_name: new_service_grpc_cluster
    endpoints:
      - lb_endpoints:
          - endpoint:
              address:
                socket_address:
                  address: new-service.namespace.svc.cluster.local
                  port_value: 50054
```


## Update grpc_json_transcoder Services:

Include the new service in the grpc_json_transcoder filter.

```bash
grpc_json_transcoder:
  services: 
    - "service1.v1.Service1"
    - "service2.v1.Service2"
    - "service3.v1.Service3"
    - "newservice.v1.NewService"
```


## Rebuild and Deploy Envoy:

```bash
docker build -t envoy-grpc-keycloak-jwt .
docker run -p 8080:8080 envoy-grpc-keycloak-jwt
```

## Example Requests

1. Example Request to GetBalance of AccountService:

```bash
curl -X POST http://localhost:8080/api/billing/v1/GetBalance \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer <YOUR_JWT_TOKEN>" \
     -d '{
       "accountIdentity": {
         "accountId": "12345"
       }
     }'
```

2. Example Request to GetCustomerInfo of OperationsService:

```bash
curl -X POST http://localhost:8080/api/operations/v1/GetCustomerInfo \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer <YOUR_JWT_TOKEN>" \
     -d '{
       "email": "user@example.com"
     }'
```

3. Example Request to CreateUser of TokenService:

```bash
curl -X POST http://localhost:8080/api/token/v1/CreateUser \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer <YOUR_JWT_TOKEN>" \
     -d '{
       "username": "newuser",
       "password": "securepassword"
     }'
```


### Debugging


1.	View Envoy Logs:

If running Envoy in Docker, use the following command to view logs:

```bash
docker logs -f <envoy_container_id>
```


2. Validate Envoy Configuration:

```bash
envoy --mode validate -c /etc/envoy/envoy.yaml
```

3. Check Proto Descriptor Contents:

Ensure that the proto_descriptor.pb includes all necessary services and messages.

```bash
protoc --decode_raw < /etc/envoy/proto_descriptor.pb
```

4. Test gRPC Services Directly:

```bash
grpcurl -plaintext \
  -d '{"accountIdentity": {"accountId": "12345"}}' \
  service1.namespace.svc.cluster.local:50051 \
  service1.v1.Service1/GetBalance
```

5. Verify JWT Tokens

6.	Monitor Network Connectivity

## Authorization Enhancements

While JWT authentication ensures that requests are made by authenticated users, it does not enforce authorization policies that restrict access to specific resources or actions based on user roles or permissions. To implement fine-grained authorization, you can integrate additional logic using Envoy’s Lua filter.
