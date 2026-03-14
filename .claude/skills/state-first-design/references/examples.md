# 状態・性質ファースト：実装例・テンプレート集

## 悪い例と良い例

### 混在の検出パターン

以下のパターンを発見したら、設計を見直す候補として必ず報告する。

**Bad: 引数に状態と性質が混在**
```
canConvert(file.type, file.isUploaded)
//         ^^^^^^^^   ^^^^^^^^^^^^^^
//         性質        状態（混在している）
```

**Good: 関心を分離する**
```
isConvertibleFormat(file.type)    // 性質のみ → 副作用なし・テスト容易
isReadyToConvert(file)            // 状態を別レイヤーで扱う
```

### DBクエリでの混在

**Bad: 論理削除(状態)と作成者(性質)が同じクエリ条件に混在**
```
findActiveItemsByCreator(userId, isDeleted)
//                       ^^^^^^  ^^^^^^^^^
//                       性質     状態（混在している）
```

**Good: 性質によるスコープと状態によるフィルタを分離**
```
scopeByCreator(userId)           // 性質のみ → 誰が作ったかは変わらない
filterActive(items)              // 状態のみ → 削除状態は変化する
```

### UIコンポーネントでの混在

**Bad: 表示バリアント(性質)とローディング状態(状態)が同一propsに混在**
```
<Button variant="primary" isLoading={true} disabled={!canSubmit} />
//      ^^^^^^^^^^^^^^^^  ^^^^^^^^^^^^^^^  ^^^^^^^^^^^^^^^^^^^^
//      性質               状態             操作の可否（状態+性質の合成）
```

**Good: 性質(見た目)と状態(振る舞い)を分離して管理**
```
// 性質: 変わらない見た目の定義
const buttonStyle = resolveVariant("primary")

// 状態: 変化する振る舞いの定義
const buttonState = deriveButtonState({ isLoading, canSubmit })
```

---

## フロントエンド（React/TypeScript）での状態・性質分離

### コンポーネント: props（性質） vs useState（状態）

**Bad: props と内部状態が同じレイヤーで混在**
```tsx
function UserCard({ userId, name, role }: Props) {
  const [isExpanded, setExpanded] = useState(false)
  // userId, name, role は性質（親から渡され不変）
  // isExpanded は状態（ユーザー操作で変化）
  // 混在すると「なぜ表示が変わったのか」の調査範囲が広がる
  return <div className={role === "admin" && isExpanded ? "special" : "normal"}>...</div>
}
```

**Good: 性質に基づく表示と状態に基づく振る舞いを分離**
```tsx
// 性質: 変わらない見た目のルール
const cardAppearance = resolveCardAppearance(role)  // "admin" → specific styles

// 状態: 変化する振る舞い
const [isExpanded, setExpanded] = useState(false)

// 合成: 操作の可否
const shouldShowDetails = isExpanded  // 状態のみに依存
```

### フォーム: バリデーション状態 vs フィールドスキーマ（性質）

**Bad: フィールド定義とバリデーション結果が一体化**
```tsx
const [fields, setFields] = useState({
  email: { value: "", required: true, error: null, maxLength: 255 }
  //                  ^^^^^^^^^^^^^^^^         ^^^^^^^^^^^^^^^^^^^^^
  //                  性質（スキーマ）          性質（スキーマ）
  //                               ^^^^^^^^^^^^
  //                               状態（検証結果）
})
```

**Good: スキーマ（性質）と入力状態を分離**
```tsx
// 性質: フィールドスキーマは変わらない
const FIELD_SCHEMA = {
  email: { required: true, maxLength: 255, pattern: /^.+@.+$/ }
} as const

// 状態: ユーザー入力で変化する
const [values, setValues] = useState({ email: "" })

// 派生（操作の可否）: 性質と状態の合成結果
const errors = validate(values, FIELD_SCHEMA)
const canSubmit = Object.keys(errors).length === 0
```

### 非同期状態: ローディング/エラー/成功の遷移を先に定義

**Bad: フラグの組み合わせで状態を表現**
```tsx
const [loading, setLoading] = useState(false)
const [error, setError] = useState<Error | null>(null)
const [data, setData] = useState<Data | null>(null)
// loading=true かつ error!=null は「あり得てはいけない状態」だが型で排除できない
```

**Good: 状態遷移を先に定義し、不正な組み合わせを型で排除**
```tsx
// 操作前の取り得る状態を列挙（網羅）
type AsyncState<T> =
  | { status: "idle" }
  | { status: "loading" }
  | { status: "success"; data: T }
  | { status: "error"; error: Error }

// 不変条件: loading中にdataやerrorは存在しない（型で強制）
const [state, dispatch] = useReducer(asyncReducer, { status: "idle" })
```

### 非同期キャンセル/競合: stale応答の状態遷移

**Bad: 最新リクエストかどうかを状態で管理しない**
```tsx
async function fetchData(query: string) {
  setLoading(true)
  const result = await api.search(query)
  setData(result)  // 前のリクエストの応答が後から到着する可能性
}
```

**Good: リクエストの「有効性」を性質として扱い、アンマウント時にキャンセルする**
```tsx
// 性質: 各リクエストの一意な識別子
const requestIdRef = useRef(0)

async function fetchData(query: string, signal?: AbortSignal) {
  const thisRequestId = ++requestIdRef.current  // 性質: このリクエスト固有
  dispatch({ status: "loading" })
  const result = await api.search(query, { signal })
  // 不変条件: 最新のリクエストIDと一致する場合のみ状態を更新
  if (thisRequestId === requestIdRef.current) {
    dispatch({ status: "success", data: result })
  }
  // 不一致 = stale応答 → 無視（状態を変更しない）
}

// アンマウント時のクリーンアップ: AbortControllerで進行中リクエストをキャンセル
useEffect(() => {
  const controller = new AbortController()
  fetchData(query, controller.signal)
  return () => controller.abort()  // 不変条件: アンマウント後に状態を更新しない
}, [query])
```

### ルーティング遷移中: 未保存データの状態設計

**Bad: 遷移ブロックの条件が散在**
```tsx
// ページAの保存状態、ページBのフォーム状態、モーダルの状態が混在
const shouldBlock = hasUnsavedChanges || isFormDirty || isModalOpen
```

**Good: 「遷移可能かどうか」を操作の可否として明示**
```tsx
// 状態: 各ページの編集状態
const [formState, setFormState] = useState<"pristine" | "dirty" | "submitting">("pristine")

// 性質: 遷移ブロックのルール（変わらない）
const NAVIGATION_RULES = {
  pristine: { canNavigate: true },
  dirty: { canNavigate: false, confirmMessage: "未保存の変更があります" },
  submitting: { canNavigate: false, confirmMessage: "送信中です" },
} as const

// 操作の可否: 状態と性質の合成
const navigationPermission = NAVIGATION_RULES[formState]
```

### 派生状態: useMemo を「操作の可否」として扱う

**Bad: 計算結果を独立した状態として保持**
```tsx
const [items, setItems] = useState<Item[]>([])
const [filteredItems, setFilteredItems] = useState<Item[]>([])  // items から派生すべき
const [totalPrice, setTotalPrice] = useState(0)  // items から計算すべき
```

**Good: 派生値は状態ではなく、状態と性質の合成結果**
```tsx
const [items, setItems] = useState<Item[]>([])          // 状態: 変化する
const [filter, setFilter] = useState<Filter>(DEFAULT)    // 状態: 変化する
const TAX_RATE = 0.1                                     // 性質: 不変

// 操作の可否 / 派生値: 状態と性質の合成（useStateにしない）
const filteredItems = useMemo(() => applyFilter(items, filter), [items, filter])
const totalPrice = useMemo(() => calcTotal(items, TAX_RATE), [items])
```

---

## 設計提案・変更提案のフォーマット

機能追加・変更を提案するときは、以下の形式で出力する。
```
## 提案：〇〇機能の変更

### 現状の問題
（状態・性質の観点から何が問題か）

### 状態・性質定義（変更後）
- 性質：〜〜
- 操作前の状態：〜〜
- 操作後の状態（成功時）：〜〜（これ以外はエラー）
- 不変条件：〜〜

### 実装方針
（上記の定義を満たすための実装アプローチ）

### 懸念・トレードオフ
（状態・性質の観点で妥協している点があれば明記）
```

---
