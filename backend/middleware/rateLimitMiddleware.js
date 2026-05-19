const rateLimit = require("express-rate-limit");


const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, 
  max: 5, 
  message: "Too many authentication attempts, please try again later",
  standardHeaders: true,
  legacyHeaders: false,
  skip: (req) => {
    // Don't rate limit in development
    return process.env.NODE_ENV === "development";
  }
});


const resetCodeLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, 
  max: process.env.NODE_ENV === "development" ? 1000 : 5,  // Very high limit in dev
  message: "Too many verification attempts, please try again later",
  standardHeaders: true,
  legacyHeaders: false,
  skip: (req) => {
    // Don't rate limit in development
    return process.env.NODE_ENV === "development";
  }
});

// General API limiter
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, 
  max: 100, 
  message: "Too many requests from this IP, please try again later",
  standardHeaders: true,
  legacyHeaders: false,
});

module.exports = {
  authLimiter,
  resetCodeLimiter,
  apiLimiter,
};
