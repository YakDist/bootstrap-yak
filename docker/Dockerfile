FROM debian:trixie AS base

RUN apt-get update \
	&& apt-get -y install \
		# Don't install recommended stuff
		--no-install-recommends \
		build-essential \
		flex \
		bison \
		gawk \
		git \
		ninja-build \
		python3 \
		python3-pip \
		python3-setuptools \
		python3-wheel \
		rsync \
		sed \
		curl \
		wget \
		mtools \
		make \
		cmake \
		llvm \
		llvm-dev \
		clang \
		lld \
		diffutils \
		m4 \
		pkg-config \
		texinfo \
		perl \
		which \
		file \
	&& apt-get clean 

RUN pip3 install --break-system-packages meson==1.9.2 \
	&& pip3 install --break-system-packages xbstrap 

# Add a user account
FROM base AS user
ARG USER=1000
RUN useradd -ms /bin/bash yak-buildenv -u $USER
USER yak-buildenv
WORKDIR /home/yak-buildenv

# Set a git profile for patches
RUN git config --global user.email "yak-buildenv@localhost" \
	&& git config --global user.name "yak-buildenv"

CMD ["bash"]
