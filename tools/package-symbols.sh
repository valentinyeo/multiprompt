set -euo pipefail
source_dir=$1
destination=$2
arch=$3
test -s "$source_dir/multibot.exe"
test -s "$source_dir/multibot.pdb"
mkdir -p "$destination"
cp "$source_dir/multibot.exe" "$destination/multiprompt-$arch-symbols.exe"
cp "$source_dir/multibot.pdb" "$destination/multiprompt-$arch-symbols.pdb"
