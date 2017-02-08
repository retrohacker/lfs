PATCH_DIR=tmp_patch_dir
xz -d *.xz
gunzip *.gz
bzip2 -d *.bz2

mkdir tz
mv tzdata* tz/

cat *.tar | tar -xf - -i
rm -v *.tar
cd tz
cat *.tar | tar -xf - -i
rm -v *.tar
cd ..

mkdir "$PATCH_DIR"

for file in *.patch; do
  mv -v $file $(echo $file | sed 's/-/ /g' | awk '{ print "PATCH_DIR/" $1 ".patch" }')
done

for file in *; do
  mv -v $file $(echo $file | sed 's/-/ /g' | awk '{ print $1 }');
done

mv "$PATCH_DIR/*" .
rm -rf "$PATCH_DIR"
