# 編集前の再読ルール（Edit/Write 失敗の予防）

1. **Read してから編集**: 対象ファイルを直近で Read していない場合（コンテキスト圧縮後・subagent 実行後を含む）は編集前に必ず Read する
2. **old_string は Read 出力から正確にコピー**: 記憶から再構成しない。直近の Read 以降に formatter / linter / hook / subagent がファイルに触れた可能性がある場合は該当範囲を Read し直す
3. **失敗したら再試行前に Read**: 「String not found」「modified since read」で失敗した際、同じ old_string の微修正で再試行しない。まず対象範囲を Read し直し、より小さい一意な old_string に分割して編集する。Write での全体書き換えは新規作成か、再 Read 直後で最新全文を保持している場合に限る
