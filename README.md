**Medora AI**

Empowering doctors with offline clinical transcription and intelligent SOAP & summary generation — all on-device.


---

🧠 What is Medora AI?

Medora AI is an on-device mobile assistant that transcribes doctor–patient interactions in real time and generates structured SOAP (Subjective, Objective, Assessment, Plan) clinical notes, along with patient-friendly summaries. The system runs entirely offline on Android devices using Whisper ASR and the Gemma 3n LLM via MediaPipe — no cloud, no compromise on privacy.


---

🚀 Key Features

🎤 Real-Time Transcription (ASR)
Powered by whisper.cpp and whisper_new Flutter plugin, chunked every 30 seconds for low-latency streaming.

🧾 Intelligent SOAP Generation
Uses Gemma-3n-e2b-it-q4 model (downloaded directly from Hugging Face) to structure transcribed data into SOAP format.

✏️ Editable UI Sections
Doctors can manually edit Subjective, Objective, Assessment, and Plan fields post-generation.

📋 Patient Summary
Outputs a detailed summary including symptoms, diagnosis, and plan, plus patient & clinic headers — with roadmap for 4–5 sentence natural-language versions.

📱 100% On-Device
No cloud APIs. All models run locally using MediaPipe Tasks and Flutter-native bindings.

📤 PDF Export & WhatsApp Sharing
SOAP notes and summaries can be exported as PDFs and shared instantly.



---

🏗️ Architecture Overview

Frontend: Flutter

ASR: whisper.cpp via whisper_new plugin

LLM: Gemma-3n-e2b-it-q4 (quantized), downloaded locally

Runtime: MediaPipe (tflite-compatible execution)

Native Bridge: Flutter Platform Channels to C++/Java


🧬 Inference Flow:

1. Doctor registers patient via form.


2. Conversation is recorded and streamed to Whisper.


3. Whisper outputs transcriptions in 30s chunks.


4. Full transcript is passed to Gemma 3n.


5. Gemma outputs structured SOAP JSON.


6. Summary and PDF generation follow.




---

🧠 Model Details

Gemma-3n-e2b-it-q4

Quantized for on-device performance

Downloaded from Hugging Face using access token

Runs via MediaPipe — no GGUF or llama.cpp involved


Whisper ASR

whisper.cpp compiled with multithreaded support

Integrated using whisper_new Flutter plugin




---

🛠️ Engineering Highlights

📦 Model Locality
All models are bundled or downloaded once, no repeated fetching.

⚡ Performance
Streaming transcription, quantized inference, and efficient PDF generation.

🔒 Privacy
All medical data stays on-device. Ideal for clinics without internet.



---

🧪 Prompt Format

System Prompt Output (Simplified JSON):

{
  "Reported_Symptoms": ["Headache", "Fatigue"],
  "HPI": "Mild fever for two days...",
  "Vitals_Exam": "BP: 120/80, Pulse: 78",
  "Primary_Diagnosis": "Viral fever",
  "Differentials": ["Malaria", "Typhoid"],
  "Therapeutics": ["Paracetamol", "ORS"],
  "Education": ["Stay hydrated", "Rest 2 days"],
  "FollowUp": "Review after 3 days"
}

Summary generation includes structured clinical fields and patient/clinic metadata. Natural-language summarization (4–5 sentence version) is on our roadmap.


---

🧭 Future Roadmap

✅ Editable SOAP sections [DONE]

✅ PDF Export & WhatsApp Share [DONE]

⏳ Natural-language summary (4–5 sentences)

⏳ Multilingual support (e.g. Hindi, Marathi)

⏳ EHR Sync & Android Health Connect integration

⏳ Jetson-powered offline hub deployment

⏳ On-device LoRA-based fine-tuning



---

👨‍⚕️ Use Case

Ideal for:

Rural clinics with no cloud access

Doctors needing quick SOAP draft generation

Field workers needing offline medical documentation

Privacy-conscious medical apps

