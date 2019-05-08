FROM ahsankhan/todobackend-base:latest
LABEL maintainer="Ahsanuzzaman Khan<ahsan.khan434@gmail.com>"

# Install dev/build dependencies
RUN apt-get update && \
    apt-get install -qy python-dev libmysqlclient-dev

# Activate virtual environment and install wheel support
RUN . /appenv/bin/activate && \
    pip install wheel --upgrade

# PIP environment variables (NOTE: must be set after installing wheel)
ENV WHEELHOUSE=/wheelhouse \
    PIP_WHEEL_DIR=/wheelhouse \
    PIP_FIND_LINKS=/wheelhouse \
    XDG_CACHE_HOME=/cache

# OUTPUT: Build artifacts (Wheels) are output here
VOLUME [ "/wheelhouse" ]

# OUTPUT: Build Cache
VOLUME [ "/build" ]

# OUTPUT: Test reports are output here
VOLUME [ "/reports" ]

# Add test entrypoint script
COPY scripts/test.sh /usr/local/bin/test.sh
RUN chmod +x /usr/local/bin/test.sh

# Set defaults for entrypoint and command string
ENTRYPOINT [ "test.sh" ]
CMD [ "python", "manage.py", "test", "--noinput" ]

# Add application source
COPY src /src
WORKDIR /src
