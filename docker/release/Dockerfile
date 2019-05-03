FROM ahsan/todobackend-base:latest
LABEL maintainer="Ahsanuzzaman Khan<ahsan.khan434@gmail.com>"

# Copy application artifacts
COPY target /wheelhouse

# Activate virtual environment and install application
RUN . /appenv/bin/activate && \
    pip install --no-index -f /wheelhouse todobackend && \
    rm -rf /wheelhouse
