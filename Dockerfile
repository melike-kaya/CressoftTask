# Dockerfile placeholder
# build
FROM golang:1.24 AS build
WORKDIR /src
RUN git clone --depth=1 https://github.com/stefanprodan/podinfo .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /podinfo ./cmd/podinfo

# minimal runtime
FROM gcr.io/distroless/static:nonroot
USER nonroot:nonroot
COPY --from=build /podinfo /podinfo
EXPOSE 9898
ENTRYPOINT ["/podinfo"]
