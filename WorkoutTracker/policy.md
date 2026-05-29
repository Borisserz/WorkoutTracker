# Privacy Policy — WorkoutTracker

**Last updated: May 29, 2026**

This Privacy Policy explains how WorkoutTracker ("the App", "we", "us") handles
your information. WorkoutTracker is designed as a privacy-first application: the
large majority of your data stays on your device and in your personal iCloud
account, which we cannot access.

By using the App, you agree to the practices described below.

## 1. Summary

- Your workout history, body measurements, weight history and progress photos are
  stored **on your device** and synced only to **your private iCloud account**.
- Health and fitness metrics are read from and written to **Apple Health** on your
  device.
- When you use the **AI Coach**, a limited workout context is sent to our secure
  Google Cloud proxy, which forwards it to Google's Vertex AI (Gemini) to generate
  a response.
- The App does **not** include behavioral tracking, advertising SDKs, or
  third-party usage analytics, and does **not** track you across apps or websites.

## 2. Data We Collect and How We Use It

### 2.1 Health & Fitness Data (Apple HealthKit)
With your explicit permission, the App reads metrics such as heart rate (including
during workouts), heart rate variability (HRV), resting heart rate, sleep
duration, steps, water intake and body weight. It writes completed workouts,
active energy (calories) and updated body weight back to Apple Health.

- **Purpose:** to track your training, and to let the AI Coach estimate recovery
  and fatigue.
- **Where it goes:** Apple Health on your device. This data is **not** sent to our
  servers and is **not** used for advertising or marketing.

### 2.2 Workout Data, History & Body Measurements
Your sets, weights, programs, weight history and manual body measurements (e.g.
biceps, waist) are stored in an on-device database (SwiftData).

- **Purpose:** core app functionality.
- **Where it goes:** stored locally and synced to your **private iCloud container**
  (`iCloud.com.borisdev.WorkoutTracker`). We have no access to your iCloud data.

### 2.3 AI Coach Data
When you interact with the AI Coach, the App sends a limited context to our
backend: your chat prompts, current body weight, experience level, personal
records, current streak, fatigued muscle groups and available equipment.

- **Purpose:** to generate personalized coaching responses and training programs.
- **Where it goes:** to our secure proxy hosted on Google Cloud Run, which forwards
  the request to **Google Vertex AI (Gemini)**. Requests are authenticated with
  Firebase App Check. We do not use this data to build advertising profiles.

### 2.4 Account & Onboarding Information
During onboarding you may provide a name and body weight. This information is
stored locally on your device. The App does not require you to create an account
to use its core features.

### 2.5 Cloud Program Library (Firebase Firestore)
The App downloads curated public training programs and lets you share your own
workouts via a link. Shared workout data you choose to publish is stored in
Firebase Firestore.

- **Purpose:** to provide a library of programs and optional workout sharing.
- **Where it goes:** Google Firebase Firestore, protected by Firebase App Check.

### 2.6 Progress Photos
You can take "before/after" photos or import them from your library.

- **Purpose:** to track visual progress.
- **Where it goes:** photos are stored **only** in the App's local storage on your
  device. They are **not** uploaded to our servers.

### 2.7 Support & Feedback
If you contact support, the App can pre-fill an email containing your message and
basic technical details (app version, iOS version, device model) using your Mail
app. Nothing is sent unless you tap "Send" in Mail.

### 2.8 On-Device Statistics
The App computes usage statistics (e.g. total volume, trends) **locally** on your
device. This is not telemetry and is not transmitted anywhere.

## 3. Third-Party Services

We use the following service providers strictly to deliver app functionality:

- **Google Firebase** (App Check, Remote Config, Firestore) — app integrity and
  cloud content.
- **Google Cloud / Vertex AI (Gemini)** — AI Coach responses, via our proxy.
- **Apple iCloud / HealthKit** — your private data sync and health metrics.

These providers process data under their own privacy terms. We do not sell your
personal data.

## 4. Data Storage & Security

Your personal training data is stored on-device and in your private iCloud
account. Server requests to our AI proxy are authenticated with Firebase App
Check so that only legitimate instances of the App can access the service. We do
not store your AI Coach conversations on our own servers.

## 5. Data Retention & Deletion

- On-device and iCloud data is retained until you delete it or remove the App.
- To delete local data, delete the App or use the in-app reset options.
- To delete iCloud data, remove it via iOS Settings → iCloud, or delete the App's
  iCloud data.
- Workouts you explicitly shared can be removed on request (see Contact).

## 6. Your Rights

Depending on your jurisdiction (including GDPR/CCPA), you may have rights to
access, correct, or delete your data. Because most data is stored only on your
device and in your iCloud, you remain in direct control of it. For shared or
server-side data, contact us using the details below.

## 7. HealthKit Disclosure

Data obtained through HealthKit is used only to provide app functionality (tracking
and recovery estimation). We will **never** use HealthKit data for advertising,
marketing, or sale to third parties, and we will not share it with any third party
without your explicit consent.

## 8. Children's Privacy

WorkoutTracker is not directed to children under 13 (or the minimum age required
in your country). We do not knowingly collect personal data from children.

## 9. International Data Transfers

Cloud processing (Firebase, Vertex AI) may occur on servers located in the United
States or other countries. By using the App you consent to such processing.

## 10. Changes to This Policy

We may update this Privacy Policy from time to time. Material changes will be
reflected by updating the "Last updated" date above.

## 11. Contact Us

If you have questions about this Privacy Policy or your data, contact us at:
**support@workouttracker.app**
