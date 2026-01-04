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

  // loading flags
  bool _isUpdatingMotor = false;
  bool _isUpdatingAuto = false;
  bool _isUpdatingThreshold = false;
  bool _isUpdatingCooldown = false;

  // Temp var while user drags sliders
  int? _editingThreshold;
  int? _editingCooldown;

  // Optimistic UI
  DateTime? _suppressStreamUntil;
  bool? _overrideMotorOn;
  bool? _overrideAutoMode;
  int? _overrideThreshold;
  int? _overrideCooldown;

  // Last auto watering info
  String _lastAutoAt = '-';
  String _lastAutoDuration = '-';

  @override
  void initState() {
    super.initState();
    _loadLastAutoWatering();
  }

  void _loadLastAutoWatering() async {
    final data = await _dbService.getLastAutoWatering();
    setState(() {
      _lastAutoAt = data['lastAutoWateredAt'];
      _lastAutoDuration = data['lastAutoDuration'];
    });
  }

  void _suppressStreamFor(Duration d) {
    setState(() => _suppressStreamUntil = DateTime.now().add(d));
  }

  bool get _isSuppressing {
    return _suppressStreamUntil != null && DateTime.now().isBefore(_suppressStreamUntil!);
  }

  void _applyLocalOverride({bool? motorOn, bool? autoMode, int? threshold, int? cooldown}) {
    if (motorOn != null) _overrideMotorOn = motorOn;
    if (autoMode != null) _overrideAutoMode = autoMode;
    if (threshold != null) _overrideThreshold = threshold;
    if (cooldown != null) _overrideCooldown = cooldown;
    _suppressStreamFor(const Duration(seconds: 2));
  }

  void _clearLocalOverrides() {
    _overrideMotorOn = null;
    _overrideAutoMode = null;
    _overrideThreshold = null;
    _overrideCooldown = null;
    _suppressStreamUntil = null;
  }

  // Map moisture -> condition
  Map<String, dynamic> _moistureCondition(int moisture) {
    if (moisture <= 20) {
      return {
        'condition': 'Sangat kering',
        'color': Colors.red.shade700,
        'icon': Icons.water_drop_outlined,
        'durationLabel': '20 detik'
      };
    } else if (moisture <= 40) {
      return {
        'condition': 'Kering',
        'color': Colors.orange.shade700,
        'icon': Icons.water_drop,
        'durationLabel': '15 detik'
      };
    } else if (moisture <= 59) {
      return {
        'condition': 'Mendekati ideal',
        'color': Colors.amber.shade700,
        'icon': Icons.water_drop,
        'durationLabel': '5–10 detik'
      };
    } else if (moisture <= 70) {
      return {
        'condition': 'Ideal (Cabai)',
        'color': Colors.green.shade700,
        'icon': Icons.check_circle,
        'durationLabel': '0 detik'
      };
    } else {
      return {
        'condition': 'Terlalu basah',
        'color': Colors.blue.shade700,
        'icon': Icons.warning_amber_rounded,
        'durationLabel': '0 detik'
      };
    }
  }

  Widget _buildCard({required Widget child, Color? borderColor}) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
        ],
        border: borderColor != null
            ? Border.all(color: borderColor, width: 2)
            : null,
      ),
      child: child,
    );
  }

  Widget _buildMoistureCard(int moisture) {
    final cond = _moistureCondition(moisture);
    return _buildCard(
      borderColor: cond['color'].withOpacity(0.3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cond['color'].withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(cond['icon'], color: cond['color'], size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Kelembapan Tanah",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  "$moisture%",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: cond['color'],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(cond['icon'], size: 14, color: cond['color']),
                    const SizedBox(width: 4),
                    Text(
                      cond['condition'],
                      style: TextStyle(
                        fontSize: 12,
                        color: cond['color'],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "• ${cond['durationLabel']}",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlCard(
      {required String title,
      required Widget content,
      required bool isActive}) {
    return _buildCard(
      borderColor: isActive ? Colors.blue.shade300 : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isActive ? Colors.blue.shade800 : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          content,
        ],
      ),
    );
  }

  Widget _buildSlider(
      {required String label,
      required int value,
      required int min,
      required int max,
      required String unit,
      required Color color,
      required bool isLoading,
      required ValueChanged<double> onChanged,
      required ValueChanged<double> onChangeEnd}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$value$unit',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        Slider(
          value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: (max - min) ~/ 5,
          label: '$value$unit',
          activeColor: color,
          inactiveColor: color.withOpacity(0.2),
          onChanged: isLoading ? null : onChanged,
          onChangeEnd: isLoading ? null : onChangeEnd,
        ),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isWide = mq.size.width > 700;
    final isPortrait = mq.size.height > mq.size.width;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, size: 48, color: Colors.red.shade300),
                    const SizedBox(height: 16),
                    Text(
                      'Terjadi error: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.blue.shade700),
                  const SizedBox(height: 16),
                  const Text("Menghubungkan ke sistem..."),
                ],
              ),
            );
          }

          final data = snapshot.data;
          if (data == null || data.isEmpty) {
            return const Center(child: Text("Tidak ada data"));
          }

          // Parse values
          final moisture = _parseInt(data['moisture'], 0);
          final motorOnStream = _parseBool(data['motorState'], false);
          final autoModeStream = _parseBool(data['autoMode'], false);
          final autoThresholdStream = _parseInt(data['autoThreshold'], 65);
          final autoCooldownStream = _parseInt(data['autoCooldownSeconds'], 300);
          final updatedAt = data['updatedAt']?.toString() ?? '-';

          // Use overrides if suppressing
          final motorOn =
              _isSuppressing && _overrideMotorOn != null ? _overrideMotorOn! : motorOnStream;
          final autoMode = _isSuppressing && _overrideAutoMode != null
              ? _overrideAutoMode!
              : autoModeStream;
          final autoThreshold = _isSuppressing && _overrideThreshold != null
              ? _overrideThreshold!
              : autoThresholdStream;
          final autoCooldown = _isSuppressing && _overrideCooldown != null
              ? _overrideCooldown!
              : autoCooldownStream;

          final displayedThreshold = _editingThreshold ?? autoThreshold;
          final displayedCooldown = _editingCooldown ?? autoCooldown;

          // Build cards
          final moistureCard = _buildMoistureCard(moisture);

          final manualControlCard = _buildControlCard(
            title: "Kontrol Manual",
            isActive: !autoMode,
            content: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    motorOn ? "POMPA MENYALA" : "POMPA MATI",
                    style: TextStyle(
                      fontSize: 15,
                      color: motorOn ? Colors.green.shade700 : Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text(
                    "Kontrol manual akan menonaktifkan mode otomatis",
                    style: TextStyle(fontSize: 12),
                  ),
                  value: motorOn,
                  onChanged: _isUpdatingMotor
                      ? null
                      : (val) async {
                          setState(() {
                            _isUpdatingMotor = true;
                            _applyLocalOverride(motorOn: val);
                          });
                          final success = await _dbService.setMotorState(val);
                          setState(() => _isUpdatingMotor = false);
                          if (!success) {
                            _clearLocalOverrides();
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(success
                                    ? 'Pompa ${val ? 'dinyalakan' : 'dimatikan'}'
                                    : 'Gagal mengubah status'),
                                backgroundColor:
                                    success ? Colors.green : Colors.red,
                              ),
                            );
                          }
                        },
                  activeColor: Colors.blue,
                ),
                if (_isUpdatingMotor)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
              ],
            ),
          );

          final autoControlCard = _buildControlCard(
            title: "Mode Otomatis",
            isActive: autoMode,
            content: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    autoMode ? "OTOMATIS AKTIF" : "OTOMATIS NON-AKTIF",
                    style: TextStyle(
                      fontSize: 15,
                      color: autoMode ? Colors.green.shade700 : Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text(
                    "Sistem akan menyiram otomatis saat kelembapan rendah",
                    style: TextStyle(fontSize: 12),
                  ),
                  value: autoMode,
                  onChanged: _isUpdatingAuto
                      ? null
                      : (val) async {
                          setState(() {
                            _isUpdatingAuto = true;
                            _applyLocalOverride(autoMode: val);
                          });
                          final success = await _dbService.setAutoMode(val);
                          setState(() => _isUpdatingAuto = false);
                          if (!success) {
                            _clearLocalOverrides();
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(success
                                    ? 'Mode otomatis ${val ? 'diaktifkan' : 'dinonaktifkan'}'
                                    : 'Gagal mengubah mode'),
                                backgroundColor:
                                    success ? Colors.blue : Colors.red,
                              ),
                            );
                          }
                        },
                  activeColor: Colors.blue,
                ),
                const SizedBox(height: 12),
                _buildSlider(
                  label: "Ambang Kelembapan",
                  value: displayedThreshold,
                  min: 0,
                  max: 100,
                  unit: "%",
                  color: Colors.blue,
                  isLoading: _isUpdatingThreshold,
                  onChanged: (v) {
                    setState(() => _editingThreshold = v.toInt());
                  },
                  onChangeEnd: (v) async {
                    final newVal = v.toInt();
                    setState(() {
                      _isUpdatingThreshold = true;
                      _applyLocalOverride(threshold: newVal);
                    });
                    final success = await _dbService.setAutoThreshold(newVal);
                    setState(() {
                      _isUpdatingThreshold = false;
                      _editingThreshold = null;
                    });
                    if (!success) {
                      _clearLocalOverrides();
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success
                              ? 'Ambang diatur ke $newVal%'
                              : 'Gagal mengatur ambang'),
                          backgroundColor: success ? Colors.blue : Colors.red,
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 16),
                _buildSlider(
                  label: "Jeda Antar Siklus",
                  value: displayedCooldown,
                  min: 10,
                  max: 3600,
                  unit: "s",
                  color: Colors.orange,
                  isLoading: _isUpdatingCooldown,
                  onChanged: (v) {
                    setState(() => _editingCooldown = v.toInt());
                  },
                  onChangeEnd: (v) async {
                    final newVal = v.toInt();
                    setState(() {
                      _isUpdatingCooldown = true;
                      _applyLocalOverride(cooldown: newVal);
                    });
                    final success = await _dbService.setAutoCooldown(newVal);
                    setState(() {
                      _isUpdatingCooldown = false;
                      _editingCooldown = null;
                    });
                    if (!success) {
                      _clearLocalOverrides();
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success
                              ? 'Jeda diatur ke $newVal detik'
                              : 'Gagal mengatur jeda'),
                          backgroundColor: success ? Colors.orange : Colors.red,
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Info Siram Otomatis Terakhir",
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Waktu: $_lastAutoAt",
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        "Durasi: $_lastAutoDuration",
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );

          final lastUpdateCard = _buildCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.update, color: Colors.blue.shade700),
              title: const Text("Update Terakhir"),
              subtitle: Text(updatedAt.length > 20
                  ? '${updatedAt.substring(0, 20)}...'
                  : updatedAt),
            ),
          );

          // Layout
          if (isWide) {
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        moistureCard,
                        const SizedBox(height: 8),
                        manualControlCard,
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        autoControlCard,
                        const SizedBox(height: 8),
                        lastUpdateCard,
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          // Mobile layout
          return Padding(
            padding: const EdgeInsets.all(12),
            child: ListView(
              children: [
                moistureCard,
                const SizedBox(height: 8),
                manualControlCard,
                const SizedBox(height: 8),
                autoControlCard,
                const SizedBox(height: 8),
                lastUpdateCard,
              ],
            ),
          );
        },
      ),
    );
  }

  int _parseInt(dynamic value, int defaultValue) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  bool _parseBool(dynamic value, bool defaultValue) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value.toLowerCase() == 'true';
    return defaultValue;
  }
}