const jwt = require("jsonwebtoken");

const verifyToken = (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return res.status(401).json({
        message: "No token provided",
      });
    }

    const token = authHeader.split(" ")[1];
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    req.user = decoded;
    next();
  } catch (error) {
    return res.status(401).json({
      message: "Invalid or expired token",
    });
  }
};

// Middleware to allow only admin users
const adminOnly = (req, res, next) => {
  try {
    const role = req.user?.role;
    if (role && role.toString().toLowerCase() === 'admin') {
      return next();
    }
    return res.status(403).json({ message: 'Forbidden: admin only' });
  } catch (e) {
    return res.status(403).json({ message: 'Forbidden' });
  }
};

module.exports = { verifyToken, adminOnly };