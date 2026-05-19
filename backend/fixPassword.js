const bcrypt = require('bcryptjs');

const mongoose = require('mongoose');

const User = require('./models/User');

require('dotenv').config();

async function fixPassword() {

  try {

    // ✅ connect mongo
    await mongoose.connect(
      process.env.MONGO_URI,
    );

    console.log(
      'Mongo Connected ✅',
    );

    // ✅ hash password
    const hashed =
        await bcrypt.hash(

      '123456',

      10,
    );

    console.log(
      'NEW HASH =>',
      hashed,
    );

    // ✅ update user password
    const result =
        await User.updateOne(

      {
        email:
            'halajomaa22@gmail.com',
      },

      {
        $set: {
          password: hashed,
        },
      }
    );

    console.log(
      'UPDATE RESULT =>',
      result,
    );

    console.log(
      'PASSWORD FIXED ✅',
    );

    process.exit();

  } catch (e) {

    console.log(
      'ERROR =>',
      e,
    );

    process.exit();
  }
}

fixPassword();