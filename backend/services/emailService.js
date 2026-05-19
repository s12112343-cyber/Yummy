const nodemailer = require("nodemailer");

// Validate required environment variables
const requiredEnvVars = ["EMAIL_USER", "EMAIL_PASS"];
const missingVars = requiredEnvVars.filter((env) => !process.env[env]);

if (missingVars.length > 0) {
  console.warn(`⚠️ Warning: Missing email service variables: ${missingVars.join(", ")}`);
}

const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS,
  },
});

const sendResetCodeEmail = async (to, code) => {
  try {
    await transporter.sendMail({
      from: `"Yummy Support" <${process.env.EMAIL_USER}>`,
      to,
      subject: "Your Yummy password reset code",
      html: `
        <div style="font-family: Arial, sans-serif; padding: 20px;">
          <h2>Password Reset Request</h2>
          <p>Your verification code is:</p>
          <h1 style="letter-spacing: 6px; font-weight: bold;">${code}</h1>
          <p style="color: #666;">This code will expire in 10 minutes.</p>
          <p style="font-size: 12px; color: #999;">If you didn't request this, please ignore this email.</p>
        </div>
      `,
    });
  } catch (error) {
    console.error("❌ Failed to send email:", error.message);
    throw new Error("Failed to send verification code email");
  }
};

// Verify transporter connection on startup
if (process.env.EMAIL_USER && process.env.EMAIL_PASS) {
  transporter.verify((error, success) => {
    if (error) {
      console.error("❌ Email service error:", error.message);
    } else {
      console.log("✅ Email service ready:", success);
    }
  });
} else {
  console.warn("⚠️ Email service credentials not configured - email sending will fail");
}

module.exports = { sendResetCodeEmail };
