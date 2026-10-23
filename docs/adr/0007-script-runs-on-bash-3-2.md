# The script runs on the Mac's own bash 3.2

`script/fuego` and its tests run on macOS `/bin/bash` (3.2), the shell the owner's Mac has, so using the script needs nothing installed beyond `adb` (spec, user story 2). That rules out bash 4 features such as associative arrays, `mapfile` and `${x,,}`. Every shell file also passes shellcheck.
