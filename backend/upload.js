const multer = require('multer');
const path = require('path');
const fs = require('fs');

const uploadPath = 'uploads/';

if (!fs.existsSync(uploadPath)) {
  fs.mkdirSync(uploadPath);
}

const storage = multer.diskStorage({
destination: (req, file, cb) => {
cb(null, 'uploads/');
},

filename: (req, file, cb) => {
cb(null, Date.now() + '-' + file.originalname);
},
});


module.exports = multer({ storage });