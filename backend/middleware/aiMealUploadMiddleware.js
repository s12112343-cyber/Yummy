const fs = require("fs");
const path = require("path");
const multer = require("multer");

const uploadDir = path.join(__dirname, "..", "uploads", "ai-meals");

if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => {
    cb(null, uploadDir);
  },
  filename: (_req, file, cb) => {
    const safeName = path.basename(file.originalname).replace(/[^a-zA-Z0-9._-]/g, "_");
    cb(null, `${Date.now()}-${safeName}`);
  },
});

const allowedExtensions = new Set([
  ".jpg",
  ".jpeg",
  ".png",
  ".webp",
  ".gif",
  ".bmp",
  ".heic",
  ".heif",
  ".tif",
  ".tiff",
]);

const fileFilter = (_req, file, cb) => {
  const mimeType = (file.mimetype || "").toLowerCase();
  const extension = path.extname(file.originalname || "").toLowerCase();
  const hasImageMime = mimeType.startsWith("image/");
  const hasImageExtension = allowedExtensions.has(extension);

  if (hasImageMime || hasImageExtension) {
    cb(null, true);
    return;
  }

  console.error(
    "[AI upload] rejected file:",
    JSON.stringify({
      originalname: file.originalname,
      mimetype: file.mimetype,
      extension,
    })
  );

  cb(new Error("Only image uploads are allowed"), false);
};

module.exports = multer({
  storage,
  fileFilter,
  limits: {
    fileSize: 12 * 1024 * 1024,
  },
});
