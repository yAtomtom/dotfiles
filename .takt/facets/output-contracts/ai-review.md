```markdown
# AIレビュー

{{include:output-contracts/base-review-result}}

{{include:output-contracts/base-review-summary}}

## 確認した観点
| 観点 | 結果 | 備考 |
|------|------|------|
| 要求との整合 | ✅ | - |
| 設計原則の遵守 | ✅ | - |
| 契約（事前条件・事後条件・不変条件） | ✅ | - |
| 変更の影響範囲 | ✅ | - |

## 指摘
| # | 重大度 | 場所 | 問題 | 影響 | 修正案 |
|---|--------|------|------|------|--------|
| 1 | High / Medium / Low | `src/file.ts:42` | {問題} | {影響} | {修正案} |

{{include:output-contracts/base-review-non-finding-concerns}}
```

**認知負荷軽減ルール:**
- APPROVE → サマリーと確認した観点のみ（指摘の表は省略可）
- REJECT → 確認済みの指摘をすべて表に記載し、同じ原因の場所は集約する
- 根拠を伴わない指摘（`file:line` の提示がないもの）は記載しない
