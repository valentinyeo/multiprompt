set -euo pipefail
source_dir=$1
destination=$2
arch=$3
test -s "$source_dir/multiprompt.exe"
test -s "$source_dir/multiprompt.pdb"
mkdir -p "$destination"
destination=$(cd "$destination" && pwd)
cp "$source_dir/multiprompt.exe" "$destination/multiprompt-$arch-symbols.exe"
cp "$source_dir/multiprompt.pdb" "$destination/multiprompt-$arch-symbols.pdb"
(cd "$source_dir" && zip -q "$destination/multiprompt-$arch-symbols.zip" multiprompt.exe multiprompt.pdb)
