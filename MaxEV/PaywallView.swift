import SwiftUI
import StoreKit

// MARK: - PaywallView

struct PaywallView: View {
    let game: PokemonGame
    @Environment(SubscriptionManager.self) private var sub
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPlan: PlanOption = .yearly
    @State private var showCancelSubPrompt = false

    enum PlanOption { case monthly, yearly, lifetime }

    // Show the card whenever the date window is open.
    // The CTA button is already disabled when selectedProduct == nil,
    // so the card appearing before StoreKit loads is safe.
    private var showLifetime: Bool {
        sub.isLifetimeAvailable
    }

    private var lifetimePrice: String {
        sub.lifetimeProduct?.displayPrice ?? "$9.99"
    }

    private var selectedProduct: Product? {
        switch selectedPlan {
        case .monthly:  return sub.monthlyProduct
        case .yearly:   return sub.yearlyProduct
        case .lifetime: return sub.lifetimeProduct
        }
    }

    /// Approximate savings of annual vs monthly (annualized).
    private var yearlySavingsPct: Int {
        guard let m = sub.monthlyProduct?.price,
              let y = sub.yearlyProduct?.price else { return 41 }
        let monthly  = NSDecimalNumber(decimal: m).doubleValue
        let yearly   = NSDecimalNumber(decimal: y).doubleValue
        guard monthly > 0 else { return 41 }
        let annualized = monthly * 12
        return Int(((annualized - yearly) / annualized * 100).rounded())
    }

    private let includedGames: [String] = [
        "Diamond", "Pearl", "Platinum",
        "HeartGold", "SoulSilver",
        "Black", "White", "Black 2", "White 2",
        "X", "Y", "Omega Ruby", "Alpha Sapphire",
        "Sun", "Moon", "Ultra Sun", "Ultra Moon",
        "Sword", "Shield",
        "Brilliant Diamond", "Shining Pearl",
        "Legends: Arceus", "Scarlet", "Violet",
        "Legends: Z-A"
    ]

    var body: some View {
        ZStack {
            game.screenBackground.opacity(0.35).ignoresSafeArea()
            Color(hex: "#F0EEE9").opacity(0.65).ignoresSafeArea()
            GamePatternBackground(game: game).opacity(0.5).ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Header ──
                ZStack(alignment: .topTrailing) {
                    VStack(spacing: 8) {
                        Text("Unlock All Games")
                            .font(.custom("PressStart2P-Regular", size: 20))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                            .padding(.top, 48)
                            .padding(.horizontal, 24)

                        Text("Every generation. Every game. Past, present, and future updates.")
                            .font(.custom("Outfit-Regular", size: 15))
                            .foregroundColor(.black.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .padding(.bottom, 16)
                    }

                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.black.opacity(0.3))
                            .padding(16)
                    }
                }

                // ── Plan cards ──
                VStack(spacing: 10) {
                    if showLifetime {
                        PlanCard(
                            title:    "Lifetime",
                            price:    lifetimePrice,
                            period:   "one-time · yours forever",
                            badge:    "LIMITED TIME",
                            badgeColor: Color(hex: "#C07810"),
                            isSelected: selectedPlan == .lifetime,
                            accentColor: game.borderColor
                        ) { selectedPlan = .lifetime }
                    }

                    PlanCard(
                        title:    "Annual",
                        price:    sub.yearlyProduct?.displayPrice ?? "$6.99",
                        period:   "per year · cancel anytime",
                        badge:    "SAVE \(yearlySavingsPct)%",
                        badgeColor: Color(hex: "#2A8050"),
                        isSelected: selectedPlan == .yearly,
                        accentColor: game.borderColor
                    ) { selectedPlan = .yearly }

                    PlanCard(
                        title:    "Monthly",
                        price:    sub.monthlyProduct?.displayPrice ?? "$0.99",
                        period:   "per month · cancel anytime",
                        badge:    nil,
                        badgeColor: .clear,
                        isSelected: selectedPlan == .monthly,
                        accentColor: game.borderColor
                    ) { selectedPlan = .monthly }
                }
                .padding(.horizontal, 24)

                // ── Included games (compact scroll) ──
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        Text("Included Games")
                            .font(.custom("Outfit-ExtraBold", size: 13))
                            .foregroundColor(.black.opacity(0.4))
                            .textCase(.uppercase)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                            .padding(.top, 20)

                        IncludedGameRow(name: game.name, color: game.borderColor, isHighlighted: true)
                            .padding(.horizontal, 24)

                        ForEach(includedGames.filter { $0 != game.name }, id: \.self) { name in
                            IncludedGameRow(name: name, color: Color(hex: "#4A7A9B"), isHighlighted: false)
                                .padding(.horizontal, 24)
                        }
                    }
                    .padding(.bottom, 16)
                }

                // ── CTA + disclosures ──
                VStack(spacing: 12) {
                    Button {
                        guard let product = selectedProduct else { return }
                        let planLabel = switch selectedPlan {
                            case .monthly:  "monthly"
                            case .yearly:   "yearly"
                            case .lifetime: "lifetime"
                        }
                        Analytics.capture(.purchaseStarted(plan: planLabel))
                        Task {
                            await sub.purchase(product)
                            if sub.isSubscribed {
                                Analytics.capture(.purchaseCompleted(plan: planLabel))
                                // If they just bought lifetime while a recurring sub is active,
                                // prompt them to cancel so they aren't double-charged.
                                if sub.shouldPromptSubscriptionCancel {
                                    showCancelSubPrompt = true
                                } else {
                                    dismiss()
                                }
                            } else if sub.errorMessage != nil {
                                Analytics.capture(.purchaseFailed(plan: planLabel))
                            }
                        }
                    } label: {
                        ZStack {
                            if sub.isPurchasing {
                                ProgressView().tint(.black)
                            } else {
                                Text(ctaLabel)
                                    .font(.custom("PressStart2P-Regular", size: 15))
                                    .foregroundColor(.black)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(game.screenBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(game.borderColor, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(sub.isPurchasing || selectedProduct == nil)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

                    Button("Restore Purchases") {
                        Task { await sub.restorePurchases() }
                    }
                    .font(.custom("Outfit-Regular", size: 13))
                    .foregroundColor(.black.opacity(0.45))

                    VStack(spacing: 6) {
                        Text(disclosureText)
                            .font(.custom("Outfit-Regular", size: 11))
                            .foregroundColor(.black.opacity(0.35))
                            .multilineTextAlignment(.center)

                        HStack(spacing: 12) {
                            Link("Privacy Policy",
                                 destination: URL(string: "https://maxev.team/privacy/")!)
                                .font(.custom("Outfit-Regular", size: 11))
                                .foregroundColor(.black.opacity(0.45))
                            Text("·").foregroundColor(.black.opacity(0.25))
                            Link("Terms of Use",
                                 destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                                .font(.custom("Outfit-Regular", size: 11))
                                .foregroundColor(.black.opacity(0.45))
                        }
                    }
                    .padding(.horizontal, 8)

                    if let error = sub.errorMessage {
                        Text(error)
                            .font(.custom("Outfit-Regular", size: 13))
                            .foregroundColor(Color(hex: "#D01C1F"))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
                .background(Color(hex: "#F0EEE9"))
            }
        }
        .onChange(of: sub.isSubscribed) { _, subscribed in
            // Only auto-dismiss for non-lifetime purchases; lifetime shows its own prompt.
            if subscribed && !sub.shouldPromptSubscriptionCancel { dismiss() }
        }
        .alert("You're all set!", isPresented: $showCancelSubPrompt) {
            Button("Cancel My Subscription") {
                if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
                    UIApplication.shared.open(url)
                }
                dismiss()
            }
            Button("I'll Do It Later", role: .cancel) { dismiss() }
        } message: {
            Text("Lifetime access is now active. You still have an active subscription that will keep charging you. Tap below to cancel it in your App Store settings — your lifetime access won't be affected.")
        }
        .onChange(of: selectedPlan) { _, plan in
            let label = switch plan {
                case .monthly:  "monthly"
                case .yearly:   "yearly"
                case .lifetime: "lifetime"
            }
            Analytics.capture(.planSelected(plan: label))
        }
        .onAppear {
            Analytics.capture(.paywallShown(triggerGame: game.name))
        }
        .task { await sub.loadProducts() }
    }

    // MARK: - Helpers

    private var ctaLabel: String {
        switch selectedPlan {
        case .lifetime: return "Buy Lifetime Access"
        case .yearly:   return "Subscribe — Annual"
        case .monthly:  return "Subscribe — Monthly"
        }
    }

    private var disclosureText: String {
        switch selectedPlan {
        case .lifetime:
            return "One-time payment. Unlocks all current and future games with no recurring charge."
        case .yearly, .monthly:
            return "Payment charged to your Apple ID at confirmation. Subscription renews automatically unless cancelled at least 24 hours before the end of the current period. Manage or cancel in your App Store account settings."
        }
    }
}

// MARK: - PlanCard

private struct PlanCard: View {
    let title:       String
    let price:       String
    let period:      String
    let badge:       String?
    let badgeColor:  Color
    let isSelected:  Bool
    let accentColor: Color
    let onTap:       () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Selection indicator
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? accentColor : Color(hex: "#D9D9D9"), lineWidth: 2)
                        .frame(width: 20, height: 20)
                    if isSelected {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 11, height: 11)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.custom("Outfit-ExtraBold", size: 17))
                            .foregroundColor(.black)
                        if let badge {
                            Text(badge)
                                .font(.custom("Outfit-ExtraBold", size: 10))
                                .foregroundColor(badgeColor)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(badgeColor.opacity(0.12))
                                .clipShape(Capsule())
                                .overlay(Capsule().strokeBorder(badgeColor.opacity(0.3), lineWidth: 1))
                        }
                    }
                    Text(period)
                        .font(.custom("Outfit-Regular", size: 13))
                        .foregroundColor(.black.opacity(0.45))
                }

                Spacer()

                Text(price)
                    .font(.custom("Outfit-ExtraBold", size: 20))
                    .foregroundColor(.black)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(isSelected ? accentColor.opacity(0.08) : Color(hex: "#F0EEE9"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        isSelected ? accentColor : Color(hex: "#D9D9D9"),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(color: .black.opacity(isSelected ? 0.1 : 0.05), radius: 3, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - IncludedGameRow

private struct IncludedGameRow: View {
    let name:          String
    let color:         Color
    let isHighlighted: Bool

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(name)
                .font(.custom(isHighlighted ? "Outfit-ExtraBold" : "Outfit-Regular", size: 15))
                .foregroundColor(.black)

            Spacer()

            if isHighlighted {
                Text("YOU TRIED TO OPEN")
                    .font(.custom("Outfit-Regular", size: 10))
                    .foregroundColor(color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(color.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(isHighlighted ? color.opacity(0.08) : Color(hex: "#F0EEE9"))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    isHighlighted ? color.opacity(0.3) : Color(hex: "#E0E0E0"),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Preview

#Preview {
    PaywallView(game: PokemonGame(
        name: "Diamond",
        background: .linear(
            [Color(hex: "#BABCC0"), Color(hex: "#3850A0"), Color(hex: "#1C2F6B")],
            startPoint: .bottomLeading, endPoint: .topTrailing
        ),
        borderColor: Color(hex: "#1E2D5E"),
        textColor: .white,
        fontName: "Silkscreen-Bold",
        fontSize: 18,
        generation: 4
    ))
    .environment(SubscriptionManager())
}
