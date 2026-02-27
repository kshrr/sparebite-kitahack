# SpareBite — AI Food Redistribution System

📌 Overview

SpareBite is an AI-powered food redistribution platform that connects surplus food donors with NGOs in real-time using geolocation and Gemini AI matching.

## 🛠 Tech Stack

- Flutter
- Firebase Authentication
- Cloud Firestore
- Google Maps SDK
- Gemini API

## 🔐 Setup instruction
1. Clone the repository
2. Copy `.env.example` and rename it to `.env`
3. Insert your Gemini API key inside `.env`:

  GEMINI_API_KEY=your_key_here

4. Run:
flutter pub get
flutter run

## 🔒 API Security

Google Maps API key is restricted to the app’s package name and SHA-1.
Gemini API key is stored locally via .env and not committed to the repository.
