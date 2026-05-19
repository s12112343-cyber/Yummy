import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/app_config.dart';

class ChefSocketService {
  static late IO.Socket socket;

  static void connect(String chefId) {
    final base = AppConfig.baseUrl.replaceFirst('/api', '');
    socket = IO.io(
      base,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    socket.connect();

    socket.onConnect((_) {
      print("✅ Socket Connected");

      socket.emit("joinChefRoom", chefId);
    });

    socket.onDisconnect((_) {
      print("❌ Socket Disconnected");
    });
  }

  static void disconnect() {
    socket.disconnect();
  }
}
