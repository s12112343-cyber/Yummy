import 'package:socket_io_client/socket_io_client.dart' as IO;

class ChefSocketService {
  static late IO.Socket socket;

  static void connect(String userId) {
    socket = IO.io(
      'http://10.0.2.2:5000',

      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    socket.connect();

    //
    // ✅ CONNECT
    //
    socket.onConnect((_) {
      print("✅ SOCKET CONNECTED");

      //
      // ✅ JOIN ROOM
      //
      socket.emit("joinChefRoom", userId);

      print("🔥 JOINED ROOM => $userId");

      //
      // ✅ LISTEN NOTIFICATIONS
      //
      socket.on("newNotification", (data) {
        print("🔥 NEW NOTIFICATION => $data");
      });
    });

    //
    // ❌ DISCONNECT
    //
    socket.onDisconnect((_) {
      print("❌ SOCKET DISCONNECTED");
    });
  }

  static void disconnect() {
    socket.disconnect();
  }
}
