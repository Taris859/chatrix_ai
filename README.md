Chatrix AI

«AI companions that remember, understand, and grow with you.»

Chatrix AI is an AI companion platform focused on persistent memory, customizable personalities, voice interaction, and long-term conversations.

Unlike traditional chatbots that treat every conversation as an isolated session, Chatrix is designed to create companions that can remember meaningful interactions and build continuity over time.

---

Features

Persistent Memory

Chatrix can retain meaningful information from conversations and use it to provide more personalized interactions.

- Long-term memories
- User preferences
- Important personal details
- Shared experiences
- Previous conversations
- Relationship context

Memory Vault

A dedicated space for managing and exploring memories created during conversations.

Memory Journal

Organize meaningful moments and interactions into a personal journal.

Memory Album

Keep a collection of memorable moments and experiences shared with your AI companion.

Relationship Chapters

Track how a relationship develops over time through different chapters and milestones.

Shared Secrets & Inside Jokes

Companions can remember shared details, jokes, and conversations that make the relationship feel more personal.

Custom AI Personalities

Create and customize AI companions with unique:

- Names
- Personalities
- Backgrounds
- Interests
- Communication styles
- Behavioral traits

Voice Conversations

Interact with AI companions using natural voice through ElevenLabs-powered text-to-speech.

Creator Studio

Create and customize your own AI companions instead of being limited to predefined personalities.

---

How It Works

Chatrix combines conversational AI, persistent memory, personality context, and relationship history.

                    User
                      |
                      v
                Conversation
                      |
                      v
               AI Processing
                      |
          +-----------+-----------+
          |           |           |
          v           v           v
       Memory     Personality   Relationship
      Context       Context       Context
          |           |           |
          +-----------+-----------+
                      |
                      v
             Personalized Response
                      |
                      v
                Memory Storage

The objective is to make conversations feel continuous rather than isolated.

---

Tech Stack

Frontend

- Flutter
- Dart
- Riverpod / Provider

Backend

- Python
- FastAPI
- REST APIs

Database

- Firebase Firestore

AI

- Large Language Models
- Llama-based models
- NVIDIA AI infrastructure

Voice

- ElevenLabs

Infrastructure

- Firebase
- Netlify

---

Architecture

                    +----------------------+
                    |      Chatrix App     |
                    |       Flutter        |
                    +----------+-----------+
                               |
                               v
                    +----------------------+
                    |      FastAPI API     |
                    |       Backend        |
                    +----------+-----------+
                               |
              +----------------+----------------+
              |                |                |
              v                v                v
        +-----------+    +-----------+    +-----------+
        | AI Model  |    | Firestore |    | ElevenLabs|
        |           |    | Database  |    |   Voice   |
        +-----------+    +-----------+    +-----------+
              |                |                |
              +----------------+----------------+
                               |
                               v
                    Personalized Companion

---

Project Structure

chatrix/
│
├── lib/
│   ├── core/
│   ├── models/
│   ├── providers/
│   ├── services/
│   ├── screens/
│   ├── widgets/
│   └── main.dart
│
├── backend/
│   ├── api/
│   ├── services/
│   ├── models/
│   └── main.py
│
├── assets/
│
├── test/
│
├── .gitignore
├── pubspec.yaml
└── README.md

---

Getting Started

Prerequisites

Make sure you have:

- Flutter SDK
- Dart SDK
- Python 3.x
- Firebase project
- Required API credentials

Clone the Repository

git clone https://github.com/taris859/chatrix.git
cd chatrix

Install Flutter Dependencies

flutter pub get

Install Backend Dependencies

cd backend
pip install -r requirements.txt

Environment Configuration

Chatrix requires API credentials for certain services.

For security reasons, credentials are not included in this repository.

Create a local environment configuration containing your own credentials:

AI_API_KEY=your_api_key_here
ELEVENLABS_API_KEY=your_api_key_here
FIREBASE_PROJECT_ID=your_project_id

Never commit ".env" files, API keys, private credentials, or service-account files to GitHub.

Example ".gitignore" entries:

.env
*.env
*.key
*.pem
google-services.json
GoogleService-Info.plist

Use your own secure configuration when running the project locally.

---

Running the Backend

From the backend directory:

uvicorn main:app --reload

The API will start locally using the FastAPI development server.

---

Running the Flutter App

From the project root:

flutter run

Select your preferred emulator or connected device.

---

Security

Security is an important part of the Chatrix architecture.

Sensitive credentials and privileged operations should remain on the server rather than being exposed inside the client application.

Flutter Client
      |
      v
Authenticated API
      |
      +---- AI Services
      |
      +---- Database
      |
      +---- Voice Services
      |
      +---- Payment Services

API keys are intentionally excluded from this repository.

If a credential is accidentally exposed, it should be revoked and rotated immediately.

---

Premium & Referral System

Chatrix includes a referral-based premium system.

Example:

1 Referral  -> 7 Days Premium
3 Referrals -> 30 Days Premium

The referral system is designed to reward users for bringing new users to the platform.

---

Roadmap

Completed

- [x] AI companion conversations
- [x] Custom AI personalities
- [x] Persistent memory
- [x] Memory Vault
- [x] Memory Journal
- [x] Memory Album
- [x] Relationship Chapters
- [x] Shared secrets and inside jokes
- [x] Creator Studio
- [x] Voice integration
- [x] Referral system

In Development

- [ ] Advanced memory retrieval
- [ ] Improved long-term personality consistency
- [ ] Better relationship context
- [ ] More advanced voice conversations
- [ ] Expanded companion customization
- [ ] Improved personalization

Future

- [ ] Multimodal companions
- [ ] Real-time voice interaction
- [ ] Advanced emotional context
- [ ] Companion-generated memories
- [ ] Creator marketplace
- [ ] Companion-to-companion interactions
- [ ] Cross-platform expansion

---

Vision

Most AI chat applications focus on generating responses.

Chatrix focuses on the relationship around those conversations.

A companion should be able to remember:

- Who you are
- What matters to you
- Things you've experienced together
- Your preferences
- Important conversations
- Shared jokes and secrets
- Relationship milestones

The long-term vision is to create AI companions that become increasingly personal through memory, personality, context, and shared experiences.

«Chatrix isn't just about talking to AI.

It's about creating an AI that remembers talking to you.»

---

Contributing

Contributions, ideas, and feedback are welcome.

To contribute:

1. Fork the repository.
2. Create a feature branch.
3. Make your changes.
4. Test your changes.
5. Submit a pull request.

git checkout -b feature/your-feature
git commit -m "Add your feature"
git push origin feature/your-feature

---

License

This project is currently proprietary.

All rights reserved.

Unauthorized copying, redistribution, or commercial use of the Chatrix source code, branding, assets, or proprietary systems is not permitted without permission from the project owner.

---

Chatrix AI

Built by taris859.

GitHub: https://github.com/taris859