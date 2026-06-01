const express = require("express");
const cors = require("cors");
const dotenv = require("dotenv");
const helmet = require("helmet");
const http = require("http");
const path = require("path");

const connectDB = require("./config/db");
const externalRecipeRoutes = require("./routes/external_recipe_routes");
const ingredientRoutes = require("./routes/ingredientRoutes");

dotenv.config();
connectDB();

const app = express();
const server = http.createServer(app);

// Socket.IO
const socket = require("./socket");
socket.init(server);
app.set("io", socket.getIO());

// Request logger
app.use((req, res, next) => {
  console.log("🔥 REQUEST:", req.method, req.originalUrl);
  next();
});

app.use(helmet());

// Redirect to HTTPS in production
app.use((req, res, next) => {
  if (
    process.env.NODE_ENV === "production" &&
    req.header("x-forwarded-proto") !== "https"
  ) {
    return res.redirect(`https://${req.header("host")}${req.url}`);
  }

  next();
});

// Allow Flutter mobile app + Flutter Web from laptop/iPhone
const allowedOrigins = [
  "http://localhost:3000",
  "http://localhost:8080",
  "http://127.0.0.1:8080",
  "http://192.168.1.50:8080",

  // Firebase Hosting Web App
  "https://yummy-d1eb2.web.app",
  "https://yummy-d1eb2.firebaseapp.com",
];

app.use(
  cors({
    origin: function (origin, callback) {
      // Mobile app / Postman sometimes send no origin, so allow them
      if (!origin || allowedOrigins.includes(origin)) {
        return callback(null, true);
      }

      console.log("❌ CORS blocked origin:", origin);
      return callback(new Error(`CORS blocked this origin: ${origin}`));
    },
    credentials: true,
    optionsSuccessStatus: 200,
    methods: ["GET", "POST", "PATCH", "PUT", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization"],
  })
);

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Serve uploaded images/files
app.use("/uploads", express.static(path.join(__dirname, "uploads")));

app.get("/", (req, res) => {
  res.send("Yummy backend is running");
});

app.get("/test", (req, res) => {
  res.json({ message: "Test route working!" });
});

// Main routes
app.use("/api/auth", require("./routes/authRoutes"));
app.use("/api/user-profile", require("./routes/userProfileRoutes"));
app.use("/api/follow", require("./routes/followRoutes"));
app.use("/api/notifications", require("./routes/notificationRoutes"));
app.use("/api/cart", require("./routes/cartRoutes"));
app.use("/api/external-recipes", externalRecipeRoutes);
app.use("/api/ingredients", ingredientRoutes);
app.use("/api/favorites", require("./routes/favoriteRoutes"));

// Old project routes
app.use("/api/users", require("./routes/userRoutes"));
app.use("/api/chefs", require("./routes/chefRoutes"));
app.use("/api/banners", require("./routes/bannerRoutes"));
app.use("/api/reviews", require("./routes/reviewRoutes"));
app.use("/api/recipes", require("./routes/recipeRoutes"));
app.use("/api/orders", require("./routes/orderRoutes"));
app.use("/api/review-recipe", require("./routes/reviewRecipeRoutes"));

// Admin routes
app.use("/api/admin", require("./routes/adminRoutes"));

// Banner request routes
app.use("/api/banner-requests", require("./routes/bannerRequestRoutes"));

// App settings routes
app.use("/api/app-settings", require("./routes/appSettingsRoutes"));

// Notification request routes
app.use(
  "/api/notification-requests",
  require("./routes/notificationRequestRoutes")
);

// Meals routes
app.use("/api/meals", (req, res, next) => {
  console.log(`MEALS ${req.method} ${req.originalUrl}`);
  next();
});
app.use("/api/meals", require("./routes/mealRoutes"));

// Posts routes
app.use("/api/posts", (req, res, next) => {
  console.log(`📮 POSTS ${req.method} ${req.originalUrl}`);
  next();
});
app.use("/api/posts", require("./routes/postRoutes"));

// Feedback route
app.use("/api/feedback", require("./routes/feedbackRoutes"));

// Chat routes
app.use("/api/chat", require("./routes/chatRoutes"));

// 404 Handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: "Route not found",
  });
});

// Global Error Handler
app.use((err, req, res, next) => {
  console.error("Error:", err.stack || err.message);

  const message =
    process.env.NODE_ENV === "production"
      ? "An error occurred. Please try again later."
      : err.message || "Something went wrong on the server!";

  res.status(err.status || 500).json({
    success: false,
    message,
  });
});

const PORT = process.env.PORT || 5000;

server.listen(PORT, "0.0.0.0", () => {
  console.log(`🔥 Server running on port ${PORT}`);
});