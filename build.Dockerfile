FROM debian:jessie

RUN apt-get update \
 && apt-get install -y --force-yes --no-install-recommends\
      binutils \
      bison \
      bzip2 \
      gawk \
      gcc \
      g++ \
      m4 \
      make \
      patch \
      texinfo \
      xz-utils \
      g++ \
      wget \
 && rm -rf /var/lib/apt/lists/*;

# Make sure sh points bash and not dash
RUN rm /bin/sh \
 && ln -s /bin/bash /bin/sh

# Use user 'lfs' for build, work out of /mnt/lfs, and setup env vars
ENV LFS /mnt/lfs
WORKDIR /mnt/lfs
ENV LFS_TOOLS "${LFS}/tools"
ENV LFS_HOST_TOOLS "/tools"
ENV LFS_SOURCES "${LFS}/sources"
RUN mkdir -p "${LFS}" "${LFS_TOOLS}" "${LFS_HOST_TOOLS}" "${LFS_SOURCES}" \
 && groupadd lfs \
 && useradd -s /bin/bash -g lfs -m -k /dev/null lfs \
 && chown -vR lfs:lfs "${LFS}" "${LFS_HOST_TOOLS}"
USER lfs
ENV LC_ALL POSIX
ENV LFS_DIST LFS
ENV LFS_TARGET "x86_64-${LFS_DIST}-linux-gnu"
ENV PATH "/tools/bin:/bin:/usr/bin"
RUN env

# Verify we have the necessary packages, library-check should return all no or
# all yes, a mix is a problem. Then download everything we are going to build,
# verify the download, unpack the bundles, and place them in non-versioned
# folders
ADD version-check.sh library-check.sh wget-list md5sums wget-rename.sh ./
RUN echo "====== VERSION CHECK ======" \
 && bash version-check.sh \
 && echo "====== LIBRARY CHECK ======" \
 && bash library-check.sh \
 && chmod -v a+wt "${LFS_SOURCES}" \
 && wget \
      -nv \
      --no-check-certificate \
      --input-file="./wget-list" \
      --directory-prefix="${LFS_SOURCES}" \
 && cd "${LFS_SOURCES}" \
 && md5sum -c "${LFS}/md5sums" \
 && cd "${LFS_SOURCES}" \
 && bash -x "${LFS}/wget-rename.sh"

# Build binutils
ENV MAKEFLAGS "-j 2"
RUN cd "${LFS_SOURCES}/binutils" \
 && mkdir -p build \
 && cd build \
 && ../configure \
      --prefix="${LFS_HOST_TOOLS}" \
      --with-sysroot="${LFS}" \
      --with-lib-path="${LFS_HOST_TOOLS}/lib" \
      --target="${LFS_TARGET}" \
      --disable-nls \
      --disable-werror \
 && make \
 && mkdir -v "${LFS_HOST_TOOLS}/lib" \
 && ln -sv "${LFS_HOST_TOOLS}/lib" "${LFS_HOST_TOOLS}/lib64" \
 && make install

ADD gcc-linker-config.sh ./

# TODO: have gcc-linker-config use $LFS_HOST_TOOLS
RUN cd "${LFS}/sources/gcc" \
 && bash "${LFS}/gcc-linker-config.sh" \
 && mkdir -p build \
 && cd build \
 && ../configure \
      --target="${LFS_TARGET}" \
      --prefix="${LFS_HOST_TOOLS}" \
      --with-glibc-version=2.11 \
      --with-sysroot="${LFS}" \
      --with-newlib \
      --without-headers \
      --with-local-prefix="${LFS_HOST_TOOLS}" \
      --with-native-system-header-dir="${LFS_HOST_TOOLS}/include" \
      --disable-shared \
      --disable-nls \
      --disable-multilib \
      --disable-decimal-float \
      --disable-threads \
      --disable-libatomic \
      --disable-libgomp \
      --disable-libmpx \
      --disable-libquadmath \
      --disable-libssp \
      --disable-libvtv \
      --disable-libstdcxx \
      --enable-languages=c,c++ \
 && make \
 && make install

RUN cd "${LFS}/sources/linux" \
 && make mrproper \
 && make INSTALL_HDR_PATH=dest headers_install \
 && cp -rv dest/include/* "${LFS_HOST_TOOLS}/include"

RUN cd "${LFS}/sources/glibc" \
 && mkdir -p build \
 && cd build \
 && ../configure \
      --prefix="${LFS_HOST_TOOLS}" \
      --host="${LFS_TARGET}" \
      --build="$(../scripts/config.guess)" \
      --enable-kernel=2.6.32 \
      --with-headers="${LFS_HOST_TOOLS}/include" \
      libc_cv_forced_unwind=yes \
      libc_cv_c_cleanup=yes \
 && make \
 && make install
