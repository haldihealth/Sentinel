SENTINEL: Edge AI for Veteran Suicide Prevention
Total Duration: 3:00 minutes

I. The Clinical Gap (0:00 - 0:40)
Visual: Direct camera shot of Dr. Shehni Nadeem and Dr. Samir Haq in a clinical setting.

Audio (Nadeem): "Hi, I’m Dr. Shehni Nadeem, and this is Dr. Samir Haq. We are both Emergency Physicians at the VA."

Audio (Haq): "Two-thirds of veterans who die by suicide were seen by a healthcare provider within 30 days. Over a quarter within the week before. These patients were in our system, but the warning signs emerged in the 'grey zone' between encounters—where no provider could detect them."

Audio (Nadeem): "While AI is often associated with worsening mental health through isolation, Sentinel proves it can be a life-saving 'Battle Buddy' that bridges the gap between care—not a replacement for it."

II. The Edge-First Architecture (0:40 - 1:10)
Visual: Split Screen. Left: Sentinel UI on iPhone. Right: Xcode Dark Mode Console.

Action: App ingests va-ed-discharge-summary.json.

Console Output:

Plaintext
[Ingest] PARSING VA_ED_DISCHARGE_SUMMARY.json
[ClinicalDoc] Extracting: Prior SI ('24), firearms access, SSRI started 4d ago
[MedGemma] Risk modifiers integrated into baseline narrative
[LCSC] Longitudinal state updated. [Privacy] 0 bytes transmitted.
Audio: "Sentinel runs a 4-bit quantized MedGemma-1.5-4B entirely on-device. It parses unstructured ED discharge summaries to build a longitudinal baseline—ensuring absolute data sovereignty for veterans who refuse cloud-based tools on principle."

III. The Masking Check-In (1:10 - 1:50)
Visual: User recording a 15-second video check-in. Large Latency Timer appears.

Action (User Speech): "I mean, I'm okay I guess. Just... haven't really been sleeping since they upped my meds. Feeling kind of wired, but it's probably nothing."

Latency Timer Stops at: 2.1s.

Console Output:

Plaintext
[Telemetry] vDSP/Accelerate: Flat vocal prosody detected
[Telemetry] Vision/ANE: Blink rate -2.4 SD (Postural decline)
[Discrepancy] MASKING confirmed: Positive words + physiological storm
[Risk] SSRI Activation Syndrome triad identified
[Perf] Inference: 2.1s | Metal GPU | 48 tokens/sec
Audio: "MedGemma identifies a 'Masking' pattern—the discrepancy between minimizing words and physiological crisis. In under three seconds, it detects the Activation Syndrome pattern that standard questionnaires often miss."

IV. The Safety Floor & Comparison (1:50 - 2:20)
Visual: Graphic: Final Risk Tier = MAX(C-SSRS Tier, MedGemma Tier).

Audio: "Sentinel uses a deterministic safety floor. MedGemma can escalate risk based on subtle cues, but it can never downgrade a positive clinical screen. This mirrors our clinical practice, where we use AI to enhance reasoning, not override safety."

V. Intervention: Self-Command & SBAR (2:20 - 2:50)
Visual: UI shifts to Red Tier Crisis View (Glass material effects).

Action: 1. Self-Command Briefing auto-plays. 2. Safety Plan reranks live. 3. SBAR report streams in.

Audio: "The Red Tier triggers instantly, loading the veteran's own Self-Command Briefing and dynamically reranking the safety plan. MedGemma then uses token streaming to generate a clinician-ready SBAR report, synthesizing this multimodal 'storm' into an actionable handoff."

VI. Conclusion & Impact (2:50 - 3:00)
Visual: Both physicians back on camera. Sentinel Logo fades in.

Audio (Haq): "In our clinical benchmarks, MedGemma achieved 94% adherence to safety-critical protocols versus only 76% for generic edge models."

Audio (Nadeem): "This is Sentinel: clinician-designed, life-saving AI—running entirely on their phones. Built by VA physicians, for the veterans who trust us with their lives."

Key Technical Reminders for Recording:
Visual Quality: Ensure the Xcode console is clearly readable; it provides the "Technical Execution" proof for the Edge AI Prize.

UI Assets: The "Red Tier" view should use the Tactical Design System (Teal/Red/Dark Surface) described in your architecture.

Benchmark Reference: Ensure your Kaggle Notebook header explicitly mentions your roles as VA Emergency Physicians to reinforce the "Product Feasibility" narrative.
