# MoneyLog

A personal expense tracker for iPhone. Everything is stored on the device — there
is no account to create, no server to talk to, and no analytics.

Built with SwiftUI and SwiftData, for iOS 18 and later.

---

## Running it

Open `MoneyLog.xcodeproj` in Xcode, pick an iPhone simulator, press ⌘R.
Tests are ⌘U.

There is nothing to configure and no dependencies to install.

---

## Five ideas that explain most of the code

If you read nothing else, read this section. The rest of the project follows from
these five decisions.

**1. Money is stored as whole paise, never as a decimal.**
₹250.75 is saved as the number `25075`. Computers can't store 0.1 exactly in a
decimal type, so adding decimals up slowly drifts — a paisa here, a paisa there,
and eventually the totals disagree with each other. Whole numbers can't drift.
See `Core/Money/Money.swift`.

**2. Balances are worked out, never saved.**
There is no `balance` column anywhere. An account's balance is its opening amount
plus every transaction since. A saved balance is a number that can silently go
wrong; a calculated one can't. See `Core/Services/BalanceCalculator.swift`.

**3. Only repositories touch the database.**
Screens never read or write SwiftData directly. They ask a repository — "give me
recent transactions", "save this" — and the repository does the work. That keeps
the rules about valid data in one place, and lets tests run without a database.
See `Core/Repositories/`.

**4. Each screen has a view model.**
The view describes what things look like; the view model does the thinking. So
`TodayView` reads like a layout, and `TodayViewModel` holds the arithmetic. The
maths can then be tested on its own, without launching the app.

**5. Every colour, font, size and animation comes from the design system.**
No view invents its own. Change `Palette.swift` and the whole app changes.
See `DesignSystem/`.

---

## What happens when you add an expense

Following one action end to end is the fastest way to learn a codebase:

1. You tap **+** on the Today screen. `AppRouter` flips a flag and the add sheet
   appears.
2. You tap digits. `AmountEntry` collects them and turns them into a `Money`
   value — rupees first, paise only after you tap the decimal point.
3. You tap the category row. `CategoryPickerSheet` slides up; picking one closes it.
4. You press **Save**. `AddTransactionViewModel` checks what's filled in. If
   something's missing it says so rather than sitting there greyed out.
5. `TransactionRepository` validates the rest — does the account exist, does the
   category match the type, is the currency right — then writes the row.
6. The sheet closes and bumps `AppRouter.dataVersion`. Every screen watching that
   number reloads, so Today, Activity and Insights all catch up at once.

---

## The folders

```
MoneyLog/
├── App/            Launch: opening the database, seeding, top-level view
├── Core/
│   ├── Models/     The things we store: transactions, accounts, categories, budgets, goals
│   ├── Money/      Amounts and currency formatting
│   ├── Persistence/ Opening the database, sample data, erase-and-reset
│   ├── Repositories/ The only code that reads and writes the database
│   └── Services/   Pure calculations: balances, budget pace, repeating dates
├── DesignSystem/
│   ├── Tokens/     Colours, fonts, spacing, animation timings, haptics
│   └── Components/ Reusable pieces: cards, amounts, rows, rings, charts frames
└── Features/       One folder per screen
    ├── Today/      Home: balance, this month, accounts, recent
    ├── Activity/   Full history with search and filters
    ├── Insights/   Charts for the selected month
    ├── Plan/       Budgets and savings goals
    ├── AddTransaction/  The add and edit sheet
    ├── Settings/   Appearance, currency, privacy, erase data
    └── Shell/      The tab bar and navigation state
```

---

## Where to change common things

| You want to… | Open |
|---|---|
| Change a colour | `DesignSystem/Tokens/Palette.swift` |
| Change a font or text size | `DesignSystem/Tokens/Typography.swift` |
| Change spacing or corner radius | `DesignSystem/Tokens/Layout.swift` |
| Change how fast things animate | `DesignSystem/Tokens/Motion.swift` |
| Change the starter categories | `Core/Persistence/SeedDataService.swift` |
| Change the wording of an error | `Core/Services/AppError.swift` |
| Add a field to a saved record | `Core/Models/` — then read the note in `SchemaV1.swift` first |

---

## Tests

`MoneyLogTests` covers the parts where being wrong would be expensive: money
arithmetic and formatting, balance maths, budget pace, repeating-date rules, and
the repositories. They run against a throwaway in-memory database, so they never
touch real data and they don't need a simulator warmed up.

`MoneyLogUITests` has one test that launches the app and checks the first screen
appears — enough to catch a launch crash before it reaches anyone.
