import SwiftUI

// MARK: - Citation Data Model

struct Citation: Identifiable {
    let id = UUID()
    let number: Int
    let authors: String
    let title: String
    let year: String
    let journal: String
    let doi: String?
    let url: String?
    let relevance: String // Brief explanation of how this citation supports the app
    let categories: [CitationCategory]
}

enum CitationCategory: String, CaseIterable, Identifiable {
    case stressDetection = "Stress Detection"
    case hrvCardiac = "HRV & Cardiac"
    case sleepRecovery = "Sleep & Recovery"
    case activityClassification = "Activity Classification"
    case digitalTwin = "Digital Twin"
    case datasets = "Datasets"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .stressDetection: return "waveform.path.ecg"
        case .hrvCardiac: return "heart.text.square"
        case .sleepRecovery: return "moon.zzz.fill"
        case .activityClassification: return "figure.run"
        case .digitalTwin: return "person.and.background.dotted"
        case .datasets: return "tablecells"
        }
    }

    var color: Color {
        switch self {
        case .stressDetection: return .ptError
        case .hrvCardiac: return .ptTeal
        case .sleepRecovery: return .ptInfo
        case .activityClassification: return .ptWarning
        case .digitalTwin: return .ptSage
        case .datasets: return .ptMuted
        }
    }
}

// MARK: - Citations Data

struct CitationsData {
    static let all: [Citation] = [
        Citation(
            number: 1,
            authors: "Schlink, B. & Amft, O.",
            title: "WISE: Wearable Stress and Exercise Dataset",
            year: "2020",
            journal: "Scientific Reports, 10(1), 23010",
            doi: nil,
            url: "https://physionet.org/content/wearable-device-dataset/1.0.1/",
            relevance: "Primary training dataset for the activity classifier and stress detection models. Provides multimodal physiological recordings (HR, HRV, EDA, accelerometry) during cognitive stress and physical exercise.",
            categories: [.datasets, .stressDetection, .activityClassification]
        ),
        Citation(
            number: 2,
            authors: "Thambawita, V., Hicks, S. A., Borgli, H., et al.",
            title: "PMData: A Sports Logging Dataset",
            year: "2020",
            journal: "Proc. 11th ACM Multimedia Systems Conference (MMSys '20), pp. 231–236",
            doi: "10.1145/3339825.3394926",
            url: "https://dl.acm.org/doi/10.1145/3339825.3394926",
            relevance: "Combines lifelogging data with sports activity logging (Fitbit Versa 2). Higher average heart rates correlate with higher reported stress; lower sleep quality corresponds to higher stress and fatigue.",
            categories: [.datasets, .sleepRecovery]
        ),
        Citation(
            number: 3,
            authors: "Schmidt, P., Reiss, A., Duerichen, R., Marberger, C. & Van Laerhoven, K.",
            title: "Introducing WESAD, a Multimodal Dataset for Wearable Stress and Affect Detection",
            year: "2018",
            journal: "Proc. 20th ACM ICMI '18, pp. 400–408",
            doi: "10.1145/3242969.3242985",
            url: "https://dl.acm.org/doi/10.1145/3242969.3242985",
            relevance: "Achieved 80% stress detection accuracy using chest-worn ECG. Demonstrates the signal quality gap between research-grade and consumer wrist-worn devices for stress detection.",
            categories: [.datasets, .stressDetection]
        ),
        Citation(
            number: 4,
            authors: "Hickey, B. A., Chalmers, T., Newton, P., Lin, C.-T., et al.",
            title: "Smart Devices and Wearable Technologies to Detect and Monitor Mental Health Conditions and Stress: A Systematic Review",
            year: "2021",
            journal: "Sensors, 21(10), 3461",
            doi: "10.3390/s21103461",
            url: "https://doi.org/10.3390/s21103461",
            relevance: "Reviewed 21 studies establishing HRV as the predominant stress biomarker (used in 10/15 studies). Stress detection accuracy ranges 65–85%. Multi-parametric devices provide the most robust detection.",
            categories: [.stressDetection, .hrvCardiac]
        ),
        Citation(
            number: 5,
            authors: "Velmovitsky, P. E., Alencar, P., Cowan, D. & Morita, P. P.",
            title: "Using Apple Watch ECG Data for Heart Rate Variability Monitoring and Stress Prediction: A Pilot Study",
            year: "2022",
            journal: "Sensors, 22(17), 6712",
            doi: "10.3390/s22176712",
            url: "https://doi.org/10.3390/s22176712",
            relevance: "Identified DC/AC (Deceleration/Acceleration Capacity) as the #1 and #2 most important stress features on Apple Watch data. Achieved 55–64% accuracy for stress detection with 33 subjects.",
            categories: [.stressDetection, .hrvCardiac]
        ),
        Citation(
            number: 6,
            authors: "Bonneval, T., et al.",
            title: "Reliability of Heart Rate Variability from Consumer-Grade Wearable Devices During Rest and Movement",
            year: "2025",
            journal: "Sensors",
            doi: nil,
            url: nil,
            relevance: "Apple Watch HRV measurements had only 1.15% error at rest but 93% error during movement. Validates the need for activity-gating before stress scoring — HRV-based stress detection during exercise is unreliable.",
            categories: [.hrvCardiac, .stressDetection]
        ),
        Citation(
            number: 7,
            authors: "Bahameish, M. & Stockman, T.",
            title: "Towards a Model for Automatic Stress Detection Using Physiological Signals",
            year: "2022",
            journal: "PLOS ONE",
            doi: "10.1371/journal.pone.0281031",
            url: "https://doi.org/10.1371/journal.pone.0281031",
            relevance: "Reported F₁ = 0.56 for binary stress classification (Stress vs. Neutral), confirming the difficulty of single-snapshot stress classification from physiological signals.",
            categories: [.stressDetection]
        ),
        Citation(
            number: 8,
            authors: "Bauer, A., Kantelhardt, J. W., Barthel, P., Schneider, R., et al.",
            title: "Deceleration Capacity of Heart Rate as a Predictor of Mortality after Myocardial Infarction: Cohort Study",
            year: "2006",
            journal: "The Lancet, 367(9523), pp. 1674–1681",
            doi: "10.1016/S0140-6736(06)68735-7",
            url: "https://doi.org/10.1016/S0140-6736(06)68735-7",
            relevance: "Introduced Phase-Rectified Signal Averaging (PRSA) for computing Deceleration Capacity (DC) and Acceleration Capacity (AC). DC reflects parasympathetic (vagal) activity; AC reflects sympathetic activation. PRSA is more robust to noise than traditional HRV metrics.",
            categories: [.hrvCardiac, .stressDetection]
        ),
        Citation(
            number: 9,
            authors: "Hernando, D., Roca, S., Sancho, J., Alesanco, Á. & Bailón, R.",
            title: "Validation of the Apple Watch for Heart Rate Variability Measurements during Relax and Mental Stress in Healthy Subjects",
            year: "2018",
            journal: "Sensors, 18(8), 2619",
            doi: "10.3390/s18082619",
            url: "https://doi.org/10.3390/s18082619",
            relevance: "Validated Apple Watch for HRV measurement. SDNN is robust to Apple Watch data gaps. Both SDNN and RMSSD decrease under stress due to sympathetic dominance.",
            categories: [.hrvCardiac, .stressDetection]
        ),
        Citation(
            number: 10,
            authors: "Barricelli, B. R., Casiraghi, E. & Fogli, D.",
            title: "A Survey on Digital Twin: Definitions, Characteristics, Applications, and Design Implications",
            year: "2019",
            journal: "IEEE Access, 7, pp. 167653–167671",
            doi: "10.1109/ACCESS.2019.2953499",
            url: "https://doi.org/10.1109/ACCESS.2019.2953499",
            relevance: "Defines the digital twin concept: a virtual representation of a physical entity continuously updated with real-world data. In health applications, it can model physiological state and recommend interventions.",
            categories: [.digitalTwin]
        ),
        Citation(
            number: 11,
            authors: "Garmin Ltd.",
            title: "Body Battery Energy Monitor",
            year: "2024",
            journal: "Garmin Technology — Health Science",
            doi: nil,
            url: "https://www.garmin.com/en-US/garmin-technology/health-science/body-battery/",
            relevance: "Proprietary energy metric (0–100) combining HRV, stress, activity, and sleep. PhysioTwin's Body Battery is inspired by but independently developed using transparent, published methods (PRSA-based DC/AC, evidence-based sleep rules).",
            categories: [.digitalTwin, .sleepRecovery]
        ),
        Citation(
            number: 12,
            authors: "Breiman, L.",
            title: "Random Forests",
            year: "2001",
            journal: "Machine Learning, 45(1), pp. 5–32",
            doi: "10.1023/A:1010933404324",
            url: "https://doi.org/10.1023/A:1010933404324",
            relevance: "Random Forest algorithm used for the Stage 1 activity classifier (PHYSICAL vs. COGNITIVE), achieving 93.6% leave-one-subject-out accuracy.",
            categories: [.activityClassification]
        ),
        Citation(
            number: 13,
            authors: "Pedregosa, F., Varoquaux, G., Gramfort, A., et al.",
            title: "Scikit-learn: Machine Learning in Python",
            year: "2011",
            journal: "Journal of Machine Learning Research, 12, pp. 2825–2830",
            doi: nil,
            url: "https://jmlr.org/papers/v12/pedregosa11a.html",
            relevance: "Machine learning framework used for the complete preprocessing and classification pipeline.",
            categories: [.activityClassification]
        ),
        Citation(
            number: 14,
            authors: "Apple Inc.",
            title: "Core ML Framework",
            year: "2023",
            journal: "Apple Developer Documentation",
            doi: nil,
            url: "https://developer.apple.com/documentation/coreml",
            relevance: "On-device machine learning inference for iOS. Stage 1 activity classifier model exported to CoreML format (528 KB) for real-time on-device inference.",
            categories: [.activityClassification]
        ),
        Citation(
            number: 15,
            authors: "Apple Inc.",
            title: "Using Behavioral Data for Health Predictions",
            year: "2024",
            journal: "Apple Developer Documentation",
            doi: nil,
            url: "https://developer.apple.com/documentation/healthkit",
            relevance: "Behavioral context (especially sleep and activity patterns) significantly improves the accuracy of wearable health predictions. Supports the sleep-based stress threshold adjustment design.",
            categories: [.sleepRecovery, .stressDetection]
        ),
    ]

    static func filtered(by category: CitationCategory?) -> [Citation] {
        guard let category = category else { return all }
        return all.filter { $0.categories.contains(category) }
    }
}

// MARK: - Citations View

struct CitationsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedCategory: CitationCategory? = nil
    @State private var searchText: String = ""

    private var filteredCitations: [Citation] {
        var results = CitationsData.filtered(by: selectedCategory)
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            results = results.filter {
                $0.title.lowercased().contains(query) ||
                $0.authors.lowercased().contains(query) ||
                $0.relevance.lowercased().contains(query) ||
                $0.journal.lowercased().contains(query)
            }
        }
        return results
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header disclaimer
                    DisclaimerBanner()
                        .padding(.horizontal)

                    // Category filter chips
                    CategoryFilterBar(selectedCategory: $selectedCategory)

                    // Search
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.ptMuted)
                        TextField("Search citations...", text: $searchText)
                            .font(.subheadline)
                    }
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)

                    // Citations list
                    LazyVStack(spacing: 12) {
                        ForEach(filteredCitations) { citation in
                            CitationCard(citation: citation)
                                .padding(.horizontal)
                        }
                    }

                    if filteredCitations.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundColor(.ptMuted)
                            Text("No matching citations")
                                .font(.subheadline)
                                .foregroundColor(.ptMuted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(40)
                    }

                    // Methodology note
                    MethodologyNote()
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                }
                .padding(.top)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Sources & Citations")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundColor(.ptTeal)
                }
            }
        }
    }
}

// MARK: - Disclaimer Banner

private struct DisclaimerBanner: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .font(.title3)
                    .foregroundColor(.ptInfo)
                Text("Important Notice")
                    .font(.headline)
            }

            Text("PhysioTwin provides wellness insights based on published research and your Apple Health data. It is **not** a medical device and does not provide medical diagnoses. Always consult a healthcare professional for medical advice.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.ptInfo.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.ptInfo.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Category Filter Bar

private struct CategoryFilterBar: View {
    @Binding var selectedCategory: CitationCategory?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" chip
                FilterChip(
                    label: "All",
                    icon: "books.vertical",
                    isSelected: selectedCategory == nil,
                    color: .ptTeal
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategory = nil
                    }
                }

                ForEach(CitationCategory.allCases) { category in
                    FilterChip(
                        label: category.rawValue,
                        icon: category.icon,
                        isSelected: selectedCategory == category,
                        color: category.color
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = (selectedCategory == category) ? nil : category
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

private struct FilterChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? color : Color(.systemGray5))
            )
            .foregroundColor(isSelected ? .white : .secondary)
        }
    }
}

// MARK: - Citation Card

private struct CitationCard: View {
    let citation: Citation
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header — always visible
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    // Citation number badge
                    Text("\(citation.number)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.ptTeal))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(citation.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)

                        Text("\(citation.authors) (\(citation.year))")
                            .font(.caption)
                            .foregroundColor(.ptMuted)

                        // Category tags
                        HStack(spacing: 4) {
                            ForEach(citation.categories) { cat in
                                Text(cat.rawValue)
                                    .font(.system(size: 9, weight: .medium))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(cat.color.opacity(0.15))
                                    .foregroundColor(cat.color)
                                    .cornerRadius(4)
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.ptMuted)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }
            .padding(14)

            // Expanded details
            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Divider()

                    // Journal
                    DetailRow(icon: "book.closed", label: "Published in", value: citation.journal)

                    // Relevance to app
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "app.connected.to.app.below.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.ptSage)
                            Text("How we use this")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.ptSage)
                        }
                        Text(citation.relevance)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // DOI / URL link
                    if let doi = citation.doi {
                        LinkButton(label: "DOI: \(doi)", url: "https://doi.org/\(doi)")
                    } else if let url = citation.url {
                        LinkButton(label: "View Source", url: url)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.ptBorder.opacity(0.5), lineWidth: 1)
        )
    }
}

private struct DetailRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(.ptMuted)
                Text(label)
                    .font(.caption)
                    .foregroundColor(.ptMuted)
            }
            Text(value)
                .font(.caption)
                .foregroundColor(.primary)
        }
    }
}

private struct LinkButton: View {
    let label: String
    let url: String

    var body: some View {
        if let link = URL(string: url) {
            Link(destination: link) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 12))
                    Text(label)
                        .font(.caption)
                        .lineLimit(1)
                }
                .foregroundColor(.ptTeal)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Color.ptTeal.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
}

// MARK: - Methodology Note

private struct MethodologyNote: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "flask")
                    .font(.title3)
                    .foregroundColor(.ptSage)
                Text("Our Methodology")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 10) {
                MethodologyItem(
                    stage: "Stage 1",
                    title: "Activity Classification",
                    detail: "A Random Forest model [12] is trained on the WISE dataset [1] to classify whether you are engaged in physical or cognitive activity. This determines which stress pipeline to apply.",
                    icon: "1.circle.fill"
                )

                MethodologyItem(
                    stage: "Stage 2",
                    title: "Sleep-Based Adjustment",
                    detail: "Your sleep duration and quality from Apple Health [15] adjust the baseline stress threshold. Poor sleep lowers the threshold, making the system more sensitive to stress indicators [2].",
                    icon: "2.circle.fill"
                )

                MethodologyItem(
                    stage: "Stage 3",
                    title: "Stress Scoring (DC/AC)",
                    detail: "Deceleration Capacity (DC) and Acceleration Capacity (AC) [8] are computed from heart rate data via Phase-Rectified Signal Averaging. Combined with SDNN [9] and RMSSD, these produce a 0–100 stress score.",
                    icon: "3.circle.fill"
                )

                MethodologyItem(
                    stage: "Battery",
                    title: "Body Battery",
                    detail: "Inspired by Garmin's Body Battery concept [11] and the digital twin paradigm [10], your battery level integrates stress drain, activity impact, and sleep recharge into a single 0–100 energy metric.",
                    icon: "battery.100.bolt"
                )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.ptSage.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.ptSage.opacity(0.2), lineWidth: 1)
        )
    }
}

private struct MethodologyItem: View {
    let stage: String
    let title: String
    let detail: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.ptTeal)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(stage): \(title)")
                    .font(.caption)
                    .fontWeight(.semibold)
                Text(detail)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    CitationsView()
}
