# 🍽️ Yummy

Yummy is a smart nutrition and meal planning platform designed to help users achieve healthier lifestyles through personalized nutrition management, AI-powered recommendations, calorie tracking, meal planning, and a social food community.

Built using **Flutter**, **Node.js**, **Express.js**, and **MongoDB**, the system supports mobile and web platforms through a unified architecture.

---

## 🚀 Key Features

### 👤 User Management

* User registration and authentication
* Personalized nutrition profile
* Health goals and activity tracking
* Allergies and medical conditions management

### 🥗 Nutrition & Meal Planning

* Daily calorie calculation
* Macro-nutrient tracking
* Personalized nutrition plans
* Weekly meal schedules
* Meal history tracking
* Water intake tracking

### 🤖 AI Features

* AI meal image analysis
* AI nutrition assistant
* Personalized daily meal plans
* Personalized weekly meal plans
* Nutrition recommendations based on:

  * Health goals
  * Allergies
  * Medical conditions
  * Calorie requirements
  * Macro targets

### 🔔 Smart Notifications

* Meal reminders
* Water reminders
* Push notifications using Firebase Cloud Messaging

### 📚 Recipes & Community

* Healthy recipes
* Cooking tutorials and educational content
* Community posts
* Likes and comments
* Favorite recipes

### 👨‍🍳 Home Cooks Marketplace

* Home chef profiles
* Product listings
* Shopping cart
* Order management
* Customer-chef interaction

### 🛠️ Admin Dashboard

* User management
* Chef management
* Order management
* Post moderation
* Statistics and reports
* Platform monitoring

---

## 🏗️ Technology Stack

### Frontend

* Flutter
* Provider
* Firebase Messaging
* Flutter Local Notifications
* PDF & Printing Packages

### Backend

* Node.js
* Express.js
* MongoDB
* Mongoose
* JWT Authentication
* Firebase Admin SDK
* Gemini AI API
* Socket.IO

---

## 📂 Project Structure

```txt
yummy/
├── backend/
│   ├── controllers/
│   ├── models/
│   ├── routes/
│   ├── services/
│   ├── middleware/
│   ├── ai/
│   └── server.js
│
├── frontend/
│   ├── lib/
│   ├── assets/
│   ├── android/
│   ├── ios/
│   ├── web/
│   └── pubspec.yaml
```

## ⚙️ Backend Setup

```bash
cd backend
npm install
npm run dev
```

Create a `.env` file:

```env
PORT=5000
MONGO_URI=your_mongodb_connection_string
JWT_SECRET=your_jwt_secret
GEMINI_API_KEY=your_gemini_api_key

FIREBASE_PROJECT_ID=your_project_id
FIREBASE_CLIENT_EMAIL=your_client_email
FIREBASE_PRIVATE_KEY=your_private_key
```

---

## 📱 Frontend Setup

```bash
cd frontend
flutter pub get
flutter run
```

Custom backend URL:

```bash
flutter run --dart-define=BASE_URL=http://your-ip:5000/api
```

---

## 🎯 Project Goal

Yummy aims to promote nutritional awareness and healthy living by combining nutrition planning, calorie tracking, artificial intelligence, social interaction, and home-based commerce into a single user-friendly platform.

---

## 👩‍💻 Team Members

* Tasneem Ratrout
* Nareman Joma
