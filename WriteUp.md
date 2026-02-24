### Project Name
Sentinel

### Your Team
**Samir M. Haq, MD** — Emergency Physician, Michael E. Debakey VA Medical Center. 

**Shehni Nadeem, MD** — Emergency Physician, Michael E. Debakey VA Medical Center.

*We are VA emergency physicians who represent Sentinel's end-users. We built this to solve a problem we encounter every shift.*

---

### Problem Statement

Veteran suicide remains one of the most persistent failures in American medicine. According to the 2024 VA National Veteran Suicide Prevention Annual Report, 6,407 veterans died by suicide in 2022 — 17.6 deaths per day. The veteran suicide rate continues to outpace the general population despite decades of investment in evidence-based screening tools like the Columbia Suicide Severity Rating Scale (C-SSRS) and Stanley-Brown Safety Planning.

The tools work. The delivery system fails on two critical fronts. First, approximately two-thirds of veterans are seen by a healthcare provider within 30 days of a suicide event, with over a quarter seen within the week before their death (Raines et al., 2025). These patients were in the system, yet the warning signs that precede crisis — sleep fragmentation, social withdrawal, physiological dysregulation — emerged in the grey zone between clinical encounters where no provider could detect them. Second, veterans with security clearances and those who have served in sensitive roles often refuse cloud-based mental health tools on principle, excluding themselves from digital interventions entirely.

Sentinel addresses both failures. It provides continuous monitoring between clinical visits, running entirely on-device. This architecture makes it viable for active duty service members, veterans already engaged with VA care, and the 9 million veterans outside the VA system who require absolute data sovereignty.

---

### Impact Potential

Sentinel targets the highest-leverage intervention point in suicide prevention: the window immediately following clinical contact when risk is elevated but monitoring is absent.

**Lives Preserved:** Conservative modeling assumes deployment to 1,000 high-risk veterans (pilot scale). Literature establishes a 30-day post-encounter crisis rate of approximately 15% in this population. A 20% relative risk reduction — achievable through enhanced monitoring and real-time safety plan access — translates to 30 crisis events prevented annually. Applying a 5% crisis-to-completion rate yields an estimated 1-2 lives saved per year at pilot scale. Using the EPA's Value of Statistical Life ($11.1 million, 2023), this represents $11-22 million in statistical value preserved annually from a single cohort.

**Acute Care Diversion:** Each suicide-related emergency department visit costs $10,000-$20,000. The same 30 prevented crisis events represent $300,000-$600,000 in avoided acute care utilization at pilot scale.

**Reach:** By removing cloud infrastructure requirements, Sentinel becomes viable for populations that reject traditional digital mental health tools: active duty service members concerned about career implications, veterans with security clearances, and the 9 million veterans disconnected from VA care. No existing tool addresses this population at scale.

---

### Overall Solution: Effective Use of HAI-DEF Models

Sentinel deploys MedGemma-4B as a specialized clinical reasoning layer bounded by deterministic safety architecture. The system uses a dual-layer approach: the C-SSRS (Columbia Suicide Severity Rating Scale) — a structured, validated clinical interview assessing suicidal ideation, intent, plan, and prior attempts — provides the hard floor for risk assessment with the safety rule `Final Risk Tier = MAX(C-SSRS Tier, MedGemma Tier)`. MedGemma handles tasks where rigid logic fails — identifying patterns like "Masking" (positive words paired with flat affect and physiological agitation) and adapting safety plans to dynamic clinical contexts.

**Clinical Grounding:** All monitored signals are supported by peer-reviewed literature: sleep fragmentation (Bernert et al., 2015), reduced heart rate variability (Carvalho et al., 2016), voice prosody changes (Mundt et al., 2012), facial expressivity (Girard et al., 2014), and C-SSRS (Posner et al., 2011).

**MedGemma Integration:** We utilize MedGemma across six defined tasks:
1. **Risk Triage:** Real-time multimodal synthesis producing color-coded risk tier (green/yellow/orange/red) with single-sentence rationale. Constrained output eliminates hallucination surface area.
2. **Longitudinal Compression (LCSC):** Recursively compresses prior check-ins into rolling clinical narrative, providing long-term memory across sessions.
3. **SBAR Reporting:** Generates clinician-ready handoff reports (Situation, Background, Assessment, Recommendation) streamed in real-time.
4. **Risk Explainer:** Translates risk factors into 2-sentence plain-language explanation for veterans.
5. **Document Ingestion:** Parses discharge summaries and clinical notes to inform risk profile.
6. **Safety Plan Reranking:** Dynamically reorders interventions based on detected clinical driver.

**Benchmark Results:** MedGemma correctly classified all 10/10 test cases versus 8/10 for Phi-3.5-mini (strongest competing edge model) according to predefined clinical criteria, achieving 100% safety score versus 90%. Phi-3.5 failed on stability recognition and subsyndromal presentation — both requiring nuanced medical domain reasoning. Latency: 0.57s versus 0.56s (T4 GPU). Judges can verify via our Kaggle notebook (`LIVE_MODE = True`).

---

### Technical Details

Sentinel proves that high-fidelity clinical AI can run on consumer mobile hardware without compromising performance.

**Inference Engine:** We use llama.cpp optimized for Apple Silicon (Metal GPU). MedGemma-4B is quantized to Q4_K_M, fitting within the 6GB RAM envelope of standard iPhones while retaining high precision on attention heads. Full GPU offload reduces latency from ~25s (CPU) to 1-4s (Metal), making real-time crisis interaction viable. Context window is constrained to 1024 tokens, with LCSC providing longitudinal continuity. Critically, our Kaggle benchmark uses the identical model repository (`mradermacher/medgemma-4b-it-GGUF`), quantization format, and inference engine as the iOS app, ensuring benchmark results directly extrapolate to on-device performance.

**Signal Processing:** Rather than stacking heavy neural networks, Sentinel uses lightweight feature extraction. Visual telemetry uses iOS's native Vision Framework on the Neural Engine (2 FPS sampling). Voice prosody is extracted via Apple Accelerate on CPU's AMX units. HealthKit integration provides HRV and sleep data compared against personal baseline rather than population norms.

**Deployment Architecture:** Constrained generation (temperature 0.1, aggressive top_k filtering) ensures deterministic outputs. Multi-strategy parsing provides fallback resilience. Inference is wrapped in timeout — if MedGemma fails to respond in 10s, the system falls back to deterministic C-SSRS scoring. The app detects RAM at launch, selecting full GPU offload for Pro devices or partial offload for older models. All data is stored via NSFileProtectionComplete with no internet permissions.

**Application Stack:** Swift 6, SwiftUI, SwiftData for local persistence. "Tactical" design system supports high-contrast mode for veterans with visual impairments.

---

### Conclusion

We built Sentinel because we kept discharging veterans from our emergency department with paper safety plans and follow-up appointments two weeks out, knowing the highest-risk window was the gap in between. That gap has claimed too many patients we've cared for.

Sentinel is our answer: a privacy-preserving, edge-native clinical partner that brings medical AI reasoning to the moments that matter most. As our benchmarks demonstrate, MedGemma's medical domain tuning is not incidental. General-purpose models fail at precisely the clinical reasoning tasks that distinguish a missed crisis from a prevented one. In this application, that difference is measured in lives.

We are submitting this as physicians who will use this tool in our own practice. That is the standard we built it to.
