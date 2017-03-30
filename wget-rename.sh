set +x
xz -d *.xz
gunzip *.gz
bzip2 -d *.bz2

mkdir -v tz
mv -v tzdata* tz/

cat *.tar | tar -xf - -i
rm -v *.tar
cd tz
cat *.tar | tar -xf - -i
rm -v *.tar
cd ..

mkdir -v ./tmp_patch_dir

# Prevent name collision
mv -v man-db* mandb
mv -v man-pages* manpages

for file in *.patch; do
  mv -v "${file}" "$(echo "${file}" | sed 's/-/ /g' | awk '{ print "./tmp_patch_dir/" $1 ".patch" }')"
done

for file in *; do
  mv -v "${file}" "$(echo "${file}" | sed 's/-\|[0-9]/ /g' | awk '{ print $1 }')";
done

mv -v ./tmp_patch_dir/* .
rm -rv ./tmp_patch_dir

# Fix renames
mv -v XML XML-Parser
mv -v bzip bzip2
mv -v e e2fsprogs
mv -v iana iana-etc
mv -v iproute iproute2
mv -v lfs lfs-bootscripts
mv -v pkg pkg-config
mv -v procps procps-ng
mv -v m m4
mv -v tcl tcl-core
mv -v mandb man-db
mv -v manpages man-pages

ls -alh .
