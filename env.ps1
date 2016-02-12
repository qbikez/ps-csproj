$env:PSModulePath="$psscriptroot\src;$env:PSModulePath"

"SET PSModulePath=$env:PSModulePath" | out-file "env.cmd" -encoding ascii