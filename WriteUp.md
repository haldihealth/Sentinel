### Project Name
Sentinel

### Your Team
**Samir M. Haq, MD** — Emergency Physician, Michael E. DeBakey VA Medical Center; Assistant Professor, Department of Internal Medicine, Baylor College of Medicine; Clinical Informaticist.  
*Role:* System architecture, MedGemma integration, and iOS development.

**Shehni Nadeem, MD** — Emergency Physician & Director of Simulation and Disaster Management, Michael E. DeBakey VA Medical Center; Assistant Professor, Department of Emergency Medicine, Baylor College of Medicine.  
*Role:* End-user research, clinical workflow design, and UI/UX.

*We are both VA physicians. This is the population we treat daily.*

---

### Problem Statement

Veteran suicide remains one of the most persistent failures in American medicine. We experience 17.6 veteran suicides per day according to the 2024 VA National Veteran Suicide Prevention Annual Report. The veteran suicide rate continues to outpace the general population despite decades of investment in evidence-based screening tools like the Columbia Suicide Severity Rating Scale (C-SSRS) and Stanley-Brown Safety Planning.

These tools work. The delivery system fails on two critical fronts. First, approximately two-thirds of veterans are seen by a healthcare provider within 30 days of a suicide event, with over a quarter seen within the week before their death (Raines et al., 2025). These patients were in the system, yet the warning signs that precede crisis — sleep fragmentation, social withdrawal, physiological dysregulation — emerged in the grey zone between clinical encounters where no provider could detect them. Second, active duty military with security clearances and those who have served in sensitive roles often refuse mental health interventions entirely due to concern for negative repercussions (Hom et al., 2017). Privacy is of utmost importance to this group.

Sentinel solves both failures. It provides monitoring between clinical visits, running entirely on-device. This architecture makes it viable for active duty service members, veterans already engaged with VA care, and the 9 million veterans outside the VA system who require absolute data sovereignty.

---

### Impact Potential

Sentinel targets the highest-leverage intervention point in suicide prevention: the window immediately following a clinical contact when risk is elevated but monitoring is absent until the next visit. Monitoring after discharge is particularly important considering nearly 70% never make it to the next visit (Suicide Prevention Resource Center, 2012; Zero Suicide Institute).

* **Lives Preserved:** Among veterans with recent psychiatric contact, the 30-day post-encounter crisis rate is 18.2% (Saulnier et al., 2025). Conservative modeling assumes a pilot deployment of 1,000 high-risk veterans, consistent with a single VA site implementation. Applying the 18.2% baseline crisis rate yields approximately 182 expected crisis events in this cohort annually. Safety planning interventions in comparable high-risk populations have demonstrated 43–45% reductions in suicidal behavior (Stanley et al., 2018; Nuij et al., 2021); applying a conservative 20% relative risk reduction translates to approximately 36 crisis events prevented per year. Applying a 1-year fatality rate of 2%, rising to 5–11% across longer follow-up studies (Owens et al., 2002), yields an estimated **1–4 lives saved annually** at pilot scale. Using the EPA's Value of Statistical Life ($11.6 million, 2024), this represents **$11–46 million** in statistical value preserved from a single cohort.
* **Acute Care Diversion:** Each suicide-related emergency department visit costs $10,000–$20,000 (Healthcare Cost and Utilization Project, 2023). The same 36 prevented crisis events represent **$360,000–$720,000** in avoided acute care utilization at pilot scale. Sentinel functions as a systemic pressure-relief valve: by detecting sub-clinical warning signs and guiding veterans to evidence-based coping strategies before the threshold of an acute emergency, it reduces demand on overburdened VA emergency departments — the same departments where, as the treating physicians on this team, we see these patients return.
* **Reach:** By removing cloud infrastructure requirements, Sentinel becomes viable for populations that reject traditional digital mental health tools: active duty service members concerned about career implications, veterans with security clearances, and the 9 million veterans disconnected from VA care. No existing tool addresses this population at scale (Stecker et al., 2013).

---

### Overall Solution: Effective Use of HAI-DEF Models

Sentinel deploys MedGemma-4B as a specialized clinical reasoning layer bounded by a deterministic safety architecture.

**Responsible AI & Clinical Guardrails (Human-in-the-Loop)** Sentinel is a screening and support tool, not an autonomous diagnostic instrument. It strictly bounds LLM generation using the rule: `Final Risk Tier = MAX(C-SSRS Tier, MedGemma Tier)`. The LLM can escalate risk based on multimodal signals but can never downgrade a positive C-SSRS screen. Furthermore, MedGemma is forbidden from generating novel therapeutic advice; it exclusively prioritizes pre-validated interventions and explicitly escalates to human care via the 988 Veterans Crisis Line when indicated.

**The Headline Capability: Detecting "Masking"** General-purpose models and static questionnaires cannot detect discordance between what a patient says and their actual physiological state. MedGemma is utilized here for its specific ability to identify "Masking" behavior—for example, synthesizing a transcript with positive words ("I'm fine") alongside contradictory flat vocal affect and autonomic arousal, correctly escalating the risk profile where a simple text-based LLM would offer false reassurance.

**Why MedGemma Specifically (Core Tasks):**
1. **Risk Triage:** Real-time multimodal synthesis producing a color-coded risk tier. MedGemma's instruction tuning ensures strict adherence to structured output, eliminating the hallucination surface area common in generic models.
2. **Longitudinal Compression (LCSC):** Standard models fail at long-context medical summarization. MedGemma recursively compresses prior check-ins into a rolling clinical narrative, providing accurate long-term memory across sessions.
3. **SBAR Reporting:** Generates clinician-ready handoff reports streaming in real-time, natively understanding standard medical formatting (Situation, Background, Assessment, Recommendation).
4. **Safety Plan Reranking:** Dynamically reorders Stanley-Brown interventions based on the detected clinical driver (e.g., prioritizing sleep hygiene vs. social contacts), requiring nuanced medical context.

**Clinical Validation Status:** While individual monitored signals are supported by peer-reviewed literature—sleep fragmentation (Bernert et al., 2015), voice prosody changes (Mundt et al., 2012), and C-SSRS (Posner et al., 2011)—Sentinel's multimodal synthesis is a novel fusion architecture that will require prospective clinical validation before diagnostic deployment.

**Structured Internal Evaluation:** In a structured 10-case internal evaluation, MedGemma correctly classified 10/10 cases according to predefined clinical criteria, achieving a 100% safety score (zero unsafe downgrades of risk). The strongest competing edge model, Phi-3.5-mini, achieved 8/10 (90% safety score), failing specifically on stability recognition and subsyndromal presentations—areas requiring precise medical domain reasoning. *(Note: Latency benchmarks of ~0.57s in our Kaggle notebook utilize a T4 GPU for judge reproducibility; actual on-device Metal inference runs at 1-4s).*

---

### Technical Details

Sentinel proves that high-fidelity clinical AI can run on consumer mobile hardware without compromising safety, performance, or battery life.

**Inference Engine (llama.cpp Optimization):** We deliberately selected a custom `llama.cpp` pipeline over standard LiteRT/MediaPipe ecosystems. This architectural choice was mandatory to achieve granular Metal GPU memory management and mixed-precision quantization control. MedGemma-4B is quantized to Q4_K_M, fitting the model within the 6GB RAM envelope of standard iPhones while retaining high precision on attention heads. Full GPU offload reduces latency from ~25s (CPU) to 1-4s (Metal), making real-time crisis interaction viable. Our Kaggle benchmark uses the identical model repository (`mradermacher/medgemma-1.5-4b-it-GGUF`), quantization format, and inference engine as the iOS app, ensuring benchmark results directly extrapolate to on-device performance.

**Edge-Constrained Signal Processing:** Rather than stacking heavy neural networks, Sentinel uses lightweight feature extraction. Visual telemetry uses iOS's native Vision Framework. Crucially, sampling is aggressively throttled to 2 FPS—an edge-engineering necessity to preserve thermal headroom and battery life during critical moments. Voice prosody is extracted via Apple Accelerate on the CPU's AMX units, bypassing the need for an audio transformer.

**Deployment Architecture:** Constrained generation (temperature 0.1, aggressive `top_k` filtering) ensures deterministic outputs. Inference is wrapped in a strict concurrency timeout—if MedGemma fails to respond in 10 seconds, the system safely falls back to deterministic C-SSRS scoring. All data is stored via `NSFileProtectionComplete` with zero internet permissions requested.

**Application Stack:** Swift 6, SwiftUI, SwiftData for local persistence. A "Tactical" design system supports a high-contrast mode for veterans with visual impairments.

---

### Conclusion

Suicide should be a never event in healthcare. We built Sentinel because as clinicians we keep discharging veterans with paper safety plans and follow-up appointments weeks out, knowing the highest-risk window is the gap in between. That gap has claimed too many that we’ve cared for both in our personal and professional lives.

Sentinel is our answer: a privacy-preserving, edge-native clinical partner that brings medical AI reasoning to the moments that matter most. As our benchmarks demonstrate, MedGemma's medical domain tuning is not incidental. General-purpose models fail at precisely the clinical reasoning tasks that distinguish a missed crisis from a prevented one. In this application, that difference is measured in lives.

We are submitting this as physicians who will use this tool in our own practice. That is the standard we built it to. We cannot afford to lose any more of our nation's heroes.
