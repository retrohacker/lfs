FROM ddf73f48a05d97e4f473d0b4ccb53383cbb0647d10e34b62d68bfc859cc6bcf9

ENV WORKING /usr/src/deps
WORKDIR ${WORKING}

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

ADD version-check.sh library-check.sh ./

# Verify we have the necessary packages, library-check should return all no or
# all yes, a mix is a problem
RUN bash version-check.sh \
 && bash library-check.sh

ENV LFS /usr/src/lfs

ADD wget-list md5sums ./

# Download and verify all packages
RUN mkdir -p "${LFS}/sources" \
 && wget \
      -nv \
      --no-check-certificate \
      --input-file="./wget-list" \
      --directory-prefix="${LFS}/sources" \
 && cd "${LFS}/sources" \
 && md5sum -c "${WORKING}/md5sums"

ADD wget-rename.sh ./
RUN cd "${LFS}/sources" \
 && bash -x "${WORKING}/wget-rename.sh"

ENV LC_ALL POSIX
ENV LFS_DIST LFS
ENV LFS_TARGET "x86_64-${LFS_DIST}-linux-gnu"

ENV LFS_TOOLS "${LFS}/tools"
ENV LFS_HOST_TOOLS "/tools"
RUN mkdir -p "${LFS_TOOLS}" \
 && ln -s "${LFS_TOOLS}" "${LFS_HOST_TOOLS}"
ENV PATH "${LFS_HOST_TOOLS}/bin:/bin:/usr/bin"
ENV MAKEFLAGS "-j 2"

RUN cd "${LFS}/sources/binutils" \
 && mkdir -p build \
 && cd build \
 && ../configure \
      --prefix="${LFS_HOST_TOOLS}" \
      --with-sysroot="${LFS}" \
      --with-lib-path="${LFS_HOST_TOOLS}/lib" \
      --target="${LFS_TARGET}" \
 && make \
 && mkdir -p "${LFS}/lib" \
 && ln -s "${LFS}/lib" "${LFS}/lib64" \
 && make install \
 && cd ../ \
 && rm -rf build

ADD gcc-linker-config.sh ./

# TODO: have gcc-linker-config use $LFS_HOST_TOOLS
RUN cd "${LFS}/sources/gcc" \
 && bash "${WORKING}/gcc-linker-config.sh" \
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
