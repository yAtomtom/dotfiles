# JDK 差し替えによるビルド daemon 破損のルール

## 症状の署名

ビルド出力に次のいずれかが出た場合、**コードの失敗ではない**。

- `Failed to exec spawn helper: pid: <N>, exit code: 1`
- `Could not connect to Kotlin compile daemon`
- `Cannot run program ".../bin/java": error=0`

原因は、長命な JVM（Gradle daemon / Kotlin compile daemon）が動いている足元で JDK ファイルが差し替わったこと。JDK 20 以降 `jspawnhelper` は親 JVM との版数一致を検査するため、更新を跨いだ daemon はプロセス生成に失敗する。Ubuntu では unattended-upgrades が `openjdk-*` を自動更新するので、日常的に起こり得る。

## 対応

```bash
jdk-daemon-doctor        # 診断（stale な daemon を列挙。無ければ exit 0）
jdk-daemon-doctor --fix  # 停止（次のビルドが新 JDK で作り直す）
```

その後ビルドを再実行する。`apt` 経由の更新は `/etc/apt/apt.conf.d/99-jdk-daemon-reset` が同じ処理を自動で行うため、通常はここへ到達しない（未設定の環境では `sudo jdk-daemon-doctor --install-apt-hook`）。

## 禁止事項

- **この失敗をコードやテストの失敗として報告しない**。ビルドの成否を判定する前に上記の署名を確認する。
- **同じコマンドをそのまま再試行しない**。daemon が生きている限り再現する。
- **`gradle.properties` に回避フラグを足さない**（`-Djdk.lang.Process.launchMechanism=vfork` 等）。症状を隠すだけで、共有ファイルに残り、以後この障害を検知できなくなる。原因は環境であってリポジトリの設定ではない。
- **`--no-daemon` 常用や `org.gradle.daemon.idletimeout` の短縮で誤魔化さない**。露出時間が減るだけで条件は消えず、ビルド時間だけが悪化する。

## 判定の根拠

`jdk-daemon-doctor` は版数の stamp ではなく、プロセスが**既に存在しないファイルの上で動いているか**を直接見る（`/proc/<pid>/exe` の `(deleted)`、および自身の JDK 配下の deleted マッピング）。障害条件そのものなので、apt 以外の経路で JDK が入れ替わった場合も検知できる。
