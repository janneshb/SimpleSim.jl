FROM julia:latest

# Default to using the Julia project in the mounted workspace
WORKDIR /workspace

# Copy package installation script
COPY .devcontainer/dependencies.jl /tmp/dependencies.jl

# Pre-compile common packages
RUN julia /tmp/dependencies.jl 