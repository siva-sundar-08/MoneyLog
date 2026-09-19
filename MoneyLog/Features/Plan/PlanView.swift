import SwiftUI

// The Plan tab: budgets on one side of the switch, savings goals on the other.
struct PlanView: View {
    enum Segment: String, CaseIterable, Identifiable {
        case budgets, goals
        var id: String { rawValue }
        var title: String {
            switch self {
            case .budgets: String(localized: "plan.budgets", defaultValue: "Budgets")
            case .goals: String(localized: "plan.goals", defaultValue: "Goals")
            }
        }
    }

    @Environment(AppContainer.self) private var container
    @Environment(AppRouter.self) private var router

    @State private var model: PlanViewModel?
    @State private var segment: Segment = .budgets
    @State private var editingBudget: Budget?
    @State private var isCreatingBudget = false
    @State private var editingGoal: SavingsGoal?
    @State private var isCreatingGoal = false
    @State private var contributingGoal: SavingsGoal?

    var body: some View {
        NavigationStack {
            ZStack {
                CanvasBackground()

                if let model {
                    content(model)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(Text("Plan"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.canvas, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if segment == .budgets { isCreatingBudget = true } else { isCreatingGoal = true }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(Text(segment == .budgets ? "New budget" : "New goal"))
                }
            }
        }
        .task {
            if model == nil { model = PlanViewModel(container: container) }
            model?.load()
        }
        .onChange(of: router.dataVersion) { _, _ in model?.load() }
        .sheet(isPresented: $isCreatingBudget) { budgetEditor(nil) }
        .sheet(item: $editingBudget) { budget in budgetEditor(budget) }
        .sheet(isPresented: $isCreatingGoal) { goalEditor(nil) }
        .sheet(item: $editingGoal) { goal in goalEditor(goal) }
        .sheet(item: $contributingGoal) { goal in
            if let model {
                ContributionSheet(goal: goal, currency: model.currency) { money, note in
                    guard model.contribute(money, to: goal, note: note) else { return model.errorMessage }
                    router.dataDidChange()
                    return nil
                }
            }
        }
    }

    @ViewBuilder
    private func content(_ model: PlanViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Picker("", selection: $segment.animation(Motion.select)) {
                    ForEach(Segment.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.top, Spacing.xs)

                switch segment {
                case .budgets:
                    BudgetsSection(
                        model: model,
                        onCreate: { isCreatingBudget = true },
                        onEdit: { editingBudget = $0 }
                    )
                case .goals:
                    GoalsSection(
                        model: model,
                        onCreate: { isCreatingGoal = true },
                        onEdit: { editingGoal = $0 },
                        onContribute: { contributingGoal = $0 }
                    )
                }

                if let errorMessage = model.errorMessage {
                    InlineErrorBanner(message: errorMessage)
                }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.bottom, Spacing.xxl)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private func budgetEditor(_ budget: Budget?) -> some View {
        if let model {
            BudgetEditorView(
                editing: budget,
                currency: model.currency,
                categories: model.expenseCategories,
                onSave: { draft in
                    guard model.saveBudget(draft, editing: budget) else { return model.errorMessage }
                    router.dataDidChange()
                    return nil
                },
                onDelete: budget.map { existing -> () -> Void in
                    {
                        model.deleteBudget(existing)
                        router.dataDidChange()
                    }
                }
            )
        }
    }

    @ViewBuilder
    private func goalEditor(_ goal: SavingsGoal?) -> some View {
        if let model {
            GoalEditorView(
                editing: goal,
                currency: model.currency,
                accounts: model.accounts,
                onSave: { draft in
                    guard model.saveGoal(draft, editing: goal) else { return model.errorMessage }
                    router.dataDidChange()
                    return nil
                },
                onDelete: goal.map { existing -> () -> Void in
                    {
                        model.deleteGoal(existing)
                        router.dataDidChange()
                    }
                }
            )
        }
    }
}
