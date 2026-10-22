# 本地交付包

源码包由 `python scripts/package_release.py source` 生成；v74附件由 `python scripts/package_release.py v74` 生成。
生成的ZIP、网表、位流和本地重建目录被Git忽略，适合作为GitHub Release附件单独上传。
本目录的README是源码仓库内容；生成物不会随 `git add .` 自动进入源码历史。
