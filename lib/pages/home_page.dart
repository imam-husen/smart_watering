import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import 'login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DatabaseService _dbService = DatabaseService();
  final AuthService _authService = AuthService();
  bool _isUpdatingMotor = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: const Text("Smart Watering Dashboard"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _authService.logout();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: _dbService.getStatusStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Terjadi error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data;
          if (data == null || data.isEmpty) {
            return const Center(child: Text("Tidak ada data"));
          }

          final moisture = data['moisture'] ?? '-';
          final motorStateRaw = data['motorState'];
          final updatedAt = data['updatedAt']?.toString() ?? '-';

          bool motorOn = false;
          if (motorStateRaw is bool) {
            motorOn = motorStateRaw;
          } else if (motorStateRaw is num) {
            motorOn = motorStateRaw != 0;
          } else if (motorStateRaw is String) {
            motorOn = motorStateRaw.toLowerCase() == 'true';
          }

          return RefreshIndicator(
            onRefresh: () async => await Future.delayed(const Duration(milliseconds: 500)),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.water_drop, color: Colors.blue, size: 60),
                        const SizedBox(height: 10),
                        const Text(
                          "Kelembapan Tanah",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "$moisture%",
                          style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "Kontrol Pompa Air",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        SwitchListTile(
                          title: Text(
                            motorOn ? "Pompa ON" : "Pompa OFF",
                            style: TextStyle(
                              fontSize: 20,
                              color: motorOn ? Colors.green : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          value: motorOn,
                          onChanged: _isUpdatingMotor
                              ? null
                              : (val) async {
                                  setState(() => _isUpdatingMotor = true);
                                  final success = await _dbService.setMotorState(val);
                                  setState(() => _isUpdatingMotor = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(success
                                            ? 'Pompa ${val ? 'ON' : 'OFF'}'
                                            : 'Gagal mengubah status pompa'),
                                      ),
                                    );
                                  }
                                },
                          activeColor: Colors.blue,
                        ),
                        if (_isUpdatingMotor)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.update, color: Colors.blue),
                      title: const Text("Update Terakhir"),
                      subtitle: Text(updatedAt),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
