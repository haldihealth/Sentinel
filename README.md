# Sentinel
**On-device AI for continuous suicide risk monitoring in veterans between clinical encounters.**

[📹 Demo Video](LINK_TO_VIDEO) | [📄 Full Write-Up](WriteUp.md) | [📊 Benchmark Notebook](https://www.kaggle.com/code/sammydman/sentinel) ---

## 🚨 The Problem
Two-thirds of veterans who die by suicide were seen by a healthcare provider within the last 30 days. The warning signs emerge in the "grey zone" between clinical encounters where no provider can detect them.

## 🛡️ Our Approach
**Sentinel** bridges this gap using **MedGemma-4B** running entirely on-device. It provides continuous symptom analysis and safety plan activation without cloud connectivity—critical for the 9 million veterans who refuse cloud-based tools due to privacy concerns.

**Dual-Layer Safety:** Sentinel uses a hybrid architecture where validated C-SSRS screening provides the hard floor for risk assessment (**Final Tier = MAX(C-SSRS, MedGemma)**).

> **Benchmark Results:** MedGemma correctly classified **10/10** clinical test cases vs **8/10** for Phi-3.5-mini (a leading open edge model). [View full analysis →](https://www.kaggle.com/code/sammydman/sentinel)

---

## 🏆 Key Technical Features
* **Local Inference:** Runs MedGemma 1.5-4b-it directly on-device using Metal Performance Shaders (GPU).
* **Optimized Latency:** Custom GPU-accelerated LLM engine (inference time < 1s on iPhone 15 Pro).
* **Privacy by Design:** Zero data egress; all health processing happens strictly on the phone.

---

## 🛠️ Build & Setup Instructions

### 1. Prerequisites
* **Xcode 16+** & **iOS 17+**
* **Hardware:** A physical device with an A17 Pro (iPhone 15 Pro) or M-series chip is strongly recommended for GPU acceleration.
    * *Note: The app will run on simulators, but inference will be extremely slow (CPU only).*

### 2. Download Model Weights
Due to GitHub file size limits, the model weights are not included in this repository.

1.  **Download Link:** [Hugging Face: medgemma-1.5-4b-it-GGUF](https://huggingface.co/mradermacher/medgemma-1.5-4b-it-GGUF/tree/main)
2.  **File to Download:** `medgemma-1.5-4b-it.Q4_K_M.gguf`
    * *Critical:* You must use the `Q4_K_M` quantization. Other versions may fail to load.
3.  **Install:** Place the downloaded file into `Sentinel/Resources/Models/` in Finder, keeping the exact filename `medgemma-1.5-4b-it.Q4_K_M.gguf`.
    * **Add to Xcode:** Open `Sentinel.xcodeproj`, drag the file into the `Resources/Models` group in the Project Navigator, and when prompted check **"Add to targets: Sentinel"**.

### 3. Dependencies (Custom GPU Fork)
This project uses a custom fork of `LLM.swift` to enable Metal acceleration. Swift Package Manager should fetch this automatically from:
`https://github.com/haldihealth/LLM.swift`

### 4. Compile
Open `Sentinel.xcodeproj` and press **Run (Cmd+R)** on your physical device.

---

## 📱 How to Test (For Judges)

### Step 1: Simulated Onboarding
Complete the initial setup. No real personal data is required; you can enter dummy information.

### Step 2: Load Clinical Context (Demo Only)
*Note: In production, this data comes from actual VA discharge summaries. The synthetic loader is for judge demonstration purposes only.*

1.  Go to the **Profile** tab.
2.  Tap **"Load Kaggle Impact Competition demo scenario"**.

### Step 3: Run a Check-In
1.  Go to the **Check-In** tab.
2.  Speak or type a high-risk statement (e.g., *"I'm feeling trapped and I've been drinking a lot today"*).
3.  **Observe:**
    * **Risk Assessment:** MedGemma will analyze the input against the discharge summary and trigger the appropriate Safety Plan intervention (Green/Yellow/Red tier).

---

## 👥 Team
**Samir M. Haq, MD** – Emergency Physician, VA Medical Center  
**Shehni Nadeem, MD** – Physician & Clinical Co-Investigator

*Built by VA emergency physicians who represent Sentinel's end-users.*

---

## 📄 Submission Materials
* **Write-Up:** [WriteUp.md](WriteUp.md)
* **References:** [REFERENCES.md](REFERENCES.md)
* **Architecture Guide:** [ARCHITECTURE.md](ARCHITECTURE.md)
* **Benchmark Notebook:** [Kaggle Notebook](https://www.kaggle.com/code/sammydman/sentinel)
* **Demo Video:** [YouTube/Vimeo Link](LINK_TO_VIDEO)
* **Custom LLM Fork:** [GitHub](https://github.com/haldihealth/LLM.swift)

## 📄 License
This project is open-sourced under the **Apache 2.0 License**.

MedGemma model weights are subject to the **Gemma Terms of Use**.
