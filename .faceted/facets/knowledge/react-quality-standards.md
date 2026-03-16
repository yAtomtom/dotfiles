**適用条件**: React / TypeScript プロジェクトに適用する。非 React コードでは参照不要。

## 状態アーキテクチャ（State Architecture）

- 状態は最小限に保ち、重複を排除する
- 派生値（derived values）はレンダー中に計算する。別の state として保持しない
  - NG: `useState` + `useEffect` で派生値を同期
  - OK: `const wordCount = bio.trim().split(/\s+/).length`
- state のリフトアップは適切なレベルに配置する。高すぎ（不要な再レンダー）も低すぎ（prop drilling や effect 同期）も避ける
- プレビュー等の表示はソース state を直接参照する。表示用に別 state を持たない

## Effect 衛生（Effect Hygiene）

`useEffect` は真の副作用（外部システムとの同期）のみに使用する:
- localStorage / sessionStorage の読み書き
- タイマーのセットアップ（cleanup 必須）
- 外部ソースの subscription（cleanup 必須）

### 検出すべきアンチパターン

| 重要度 | ID | パターン | 正しい手段 |
|--------|----|---------|-----------|
| Critical | AP-01 | `useEffect` で派生 state を同期 | レンダー中に計算、または `useMemo` |
| Critical | AP-02 | `useEffect` で props を state に同期 | props を直接使用、または `key` でリセット |
| Critical | AP-03 | `useEffect` でイベント処理 | イベントハンドラ内で直接処理 |
| Critical | AP-07 | dependency array 未指定 | 正しい依存配列を指定 |
| Major | AP-04 | timer / listener の cleanup 漏れ | return 関数で cleanup |
| Major | AP-08 | 動的リストで `key={index}` | 一意な ID を key に |
| Minor | AP-05 | 同一データの複数 state | 単一 state から派生 |
| Minor | AP-06 | deps 配列内の不安定参照 | `useMemo` / `useCallback` で安定化 |

## モダン React API 選択（React 18+ / 19+）

| 用途 | 推奨 API | 旧パターン（機能するが非推奨） |
|------|---------|-------------------------------|
| データ取得 | `Suspense` + `use()` | `useEffect` + `useState` + `isLoading` |
| 外部ストアの購読 | `useSyncExternalStore` | `useEffect` + `useState` + `addEventListener` |
| effect 内での最新値参照 | `useEffectEvent` | `useRef` + 手動同期 |
| 高コストな再レンダーの遅延 | `useDeferredValue` / `useTransition` | `setTimeout` によるデバウンス |
| セクション別エラー分離 | Error Boundaries | `try/catch` in `useEffect` + error state |

## コンポーネント設計

- 単一責任: 1 コンポーネント = 1 つの明確な関心
- カスタムフック: 再利用可能なロジック（validation, persistence, subscription 等）は `use*` フックに抽出
- 繰り返しパターン（ラベル付きフォームフィールド等）は共通コンポーネントに抽出
- children / render props による合成を prop drilling より優先する

## TypeScript 品質

- `any` 型は使わない。`unknown` + 型ガードで安全に絞り込む
- component props は `interface` または `type` で明示的に定義する
- discriminated union は型の絞り込み（narrowing）で網羅的に処理する
- イベントハンドラは正確に型付けする（`React.ChangeEvent<HTMLInputElement>` 等）

## アクセシビリティ & セマンティクス（JSX 固有）

- セマンティック HTML: `<form>`, `<button>`, `<label>`, `<fieldset>`, `<dialog>`, `<select>` を使用
- `<div onClick>` ではなく `<button>` を使用する
- すべての input に `<label>` を関連付ける（`htmlFor` または wrapping）
- エラーメッセージは `aria-describedby` で input に関連付ける
- `<button>` には明示的な `type` 属性を指定する（`type="button"` or `type="submit"`）
- モーダルは `<dialog>` または `role="dialog"` + `aria-modal` を使用する
