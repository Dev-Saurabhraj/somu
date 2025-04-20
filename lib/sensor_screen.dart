import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'dart:math' as math;

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Reference to the sensorData node specifically
  final DatabaseReference _databaseReference =
  FirebaseDatabase.instance.ref().child('sensorData');

  StreamSubscription? _dataSubscription;

  Map<String, dynamic> sensorData = {
    "ax": 0.0,
    "ay": 0.0,
    "az": 0.0,
    "dht_temp": 0.0,
    "humidity": 0.0,
    "ds18b20_temp": 0.0,
    "heart_rate": 0.0,
    "spo2": 0.0,
  };

  bool isLoading = true;
  String errorMessage = '';

  // Step counter variables
  int stepCount = 0;
  double stepThreshold = 500.0; // Adjust based on sensor sensitivity
  bool isPeak = false;
  double previousMagnitude = 0.0;
  double smoothedMagnitude = 0.0;
  DateTime? lastStepTime;

  // Daily goal
  int dailyStepGoal = 10000;

  // Heart rate data with timestamps
  List<FlSpot> heartRateData = [
    const FlSpot(0, 72),
    const FlSpot(1, 74),
    const FlSpot(2, 78),
    const FlSpot(3, 76),
    const FlSpot(4, 75),
    const FlSpot(5, 73),
    const FlSpot(6, 75),
  ];

  // Timestamp for heart rate entries
  List<DateTime> heartRateTimestamps = [];

  // Heart rate buffer for real-time display
  List<double> recentHeartRates = [];
  final int maxHeartRatePoints = 20; // Maximum points to show on chart

  @override
  void initState() {
    super.initState();
    _startRealtimeUpdates();

    // Initialize heart rate timestamps with dummy data
    final now = DateTime.now();
    for (int i = 0; i < 7; i++) {
      heartRateTimestamps.add(now.subtract(Duration(minutes: (6-i) * 10)));
    }
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    super.dispose();
  }

  void _startRealtimeUpdates() {
    try {
      _dataSubscription = _databaseReference.onValue.listen((event) {
        if (event.snapshot.value != null) {
          Map<dynamic, dynamic> rawSensorData =
          event.snapshot.value as Map<dynamic, dynamic>;

          // Process the data - directly from the sensorData node
          Map<String, dynamic> processedData = {
            "ax": _toDouble(rawSensorData['ax']),
            "ay": _toDouble(rawSensorData['ay']),
            "az": _toDouble(rawSensorData['az']),
            "dht_temp": _toDouble(rawSensorData['dht_temp'] ?? 0.0),
            "humidity": _toDouble(rawSensorData['humidity'] ?? 0.0),
            "ds18b20_temp": _toDouble(rawSensorData['ds18b20_temp']),
            "heart_rate": _toDouble(rawSensorData['heart_rate']),
            "spo2": _toDouble(rawSensorData['spo2']),
          };

          // Process accelerometer data for step counting


          // Process heart rate for real-time display
          _updateHeartRateRealtime(processedData["heart_rate"]);

          // Check if we have historical heart rate data
          if (rawSensorData.containsKey('heart_rate_history')) {
            _updateHeartRateChartData(rawSensorData['heart_rate_history']);
          }

          setState(() {
            sensorData = processedData;
            isLoading = false;
            errorMessage = '';
          });
        } else {
          setState(() {
            errorMessage = 'No data available';
            isLoading = false;
          });
        }
      }, onError: (error) {
        setState(() {
          errorMessage = 'Error loading data: $error';
          isLoading = false;
        });
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to connect to database: $e';
        isLoading = false;
      });
    }
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (_) {
        return 0.0;
      }
    }
    return 0.0;
  }

  void _updateHeartRateChartData(dynamic historyData) {
    try {
      List<FlSpot> newData = [];

      if (historyData is List) {
        for (int i = 0; i < historyData.length; i++) {
          double hrValue = _toDouble(historyData[i]);
          newData.add(FlSpot(i.toDouble(), hrValue));
        }
      } else if (historyData is Map) {
        int index = 0;
        historyData.forEach((key, value) {
          double hrValue = _toDouble(value);
          newData.add(FlSpot(index.toDouble(), hrValue));
          index++;
        });
      }

      if (newData.isNotEmpty) {
        setState(() {
          heartRateData = newData;
        });
      }
    } catch (e) {
      debugPrint('Error updating heart rate chart: $e');
    }
  }

  // Update heart rate data for real-time display
  void _updateHeartRateRealtime(double heartRate) {
    if (heartRate <= 0) return; // Ignore invalid readings

    // Add new heart rate to buffer
    recentHeartRates.add(heartRate);
    heartRateTimestamps.add(DateTime.now());

    // Keep buffer at fixed size
    if (recentHeartRates.length > maxHeartRatePoints) {
      recentHeartRates.removeAt(0);
      heartRateTimestamps.removeAt(0);
    }

    // Generate updated chart data
    List<FlSpot> newData = [];
    for (int i = 0; i < recentHeartRates.length; i++) {
      newData.add(FlSpot(i.toDouble(), recentHeartRates[i]));
    }

    setState(() {
      if (newData.isNotEmpty) {
        heartRateData = newData;
      }
    });
  }

  void _refreshData() {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    // Fetch the data from the sensorData node
    _databaseReference.get().then((snapshot) {
      if (snapshot.exists) {
        Map<dynamic, dynamic> rawSensorData =
        snapshot.value as Map<dynamic, dynamic>;

        Map<String, dynamic> processedData = {
          "ax": _toDouble(rawSensorData['ax']),
          "ay": _toDouble(rawSensorData['ay']),
          "az": _toDouble(rawSensorData['az']),
          "dht_temp": _toDouble(rawSensorData['dht_temp'] ?? 0.0),
          "humidity": _toDouble(rawSensorData['humidity'] ?? 0.0),
          "ds18b20_temp": _toDouble(rawSensorData['ds18b20_temp']),
          "heart_rate": _toDouble(rawSensorData['heart_rate']),
          "spo2": _toDouble(rawSensorData['spo2']),
        };

        // Check for heart rate history data
        if (rawSensorData.containsKey('heart_rate_history')) {
          _updateHeartRateChartData(rawSensorData['heart_rate_history']);
        }

        setState(() {
          sensorData = processedData;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'No data available';
          isLoading = false;
        });
      }
    }).catchError((error) {
      setState(() {
        errorMessage = 'Error refreshing data: $error';
        isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'SOMU',
          style: TextStyle(
            color: Color(0xFFFF7A00),
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Color(0xFFFF7A00)),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Color(0xFFFF7A00)),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: _buildDrawer(),
      body: isLoading
          ? const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFF7A00),
        ),
      )
          : errorMessage.isNotEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red[400],
              size: 60,
            ),
            const SizedBox(height: 16),
            Text(
              errorMessage,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF333333),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _refreshData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7A00),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: () async {
          _refreshData();
          return Future.delayed(const Duration(milliseconds: 1500));
        },
        color: const Color(0xFFFF7A00),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeCard(),
              const SizedBox(height: 24),
              _buildVitalStats(),
              const SizedBox(height: 24),
              _buildEnvironmentStats(),
              const SizedBox(height: 24),
              _buildHeartRateChart(),
              const SizedBox(height: 24),
              _buildFallDetectionCard(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFFF7A00),
        child: const Icon(Icons.refresh, color: Colors.white),
        onPressed: () {
          _refreshData();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Refreshing data...'),
              backgroundColor: Color(0xFFFF7A00),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF7A00), Color(0xFFFF9A3D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.person,
                      size: 40,
                      color: Color(0xFFFF7A00),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Saurabh Rajput',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Health ID: #35792',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            _buildDrawerItem(Icons.dashboard_outlined, 'Dashboard'),
            _buildDrawerItem(FontAwesomeIcons.heartPulse, 'Health Stats'),
            _buildDrawerItem(Icons.history, 'History'),
            _buildDrawerItem(Icons.notifications_outlined, 'Alerts'),
            _buildDrawerItem(FontAwesomeIcons.gear, 'Settings'),
             Divider(),
            _buildDrawerItem(Icons.help_outline, 'Help & Support'),
            _buildDrawerItem(Icons.logout, 'Logout'),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title) {
    return ListTile(
      leading: Icon(
        icon,
        color: const Color(0xFFFF7A00),
        size: 22,
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          color: Color(0xFF333333),
        ),
      ),
      onTap: () {
        Navigator.pop(context);
      },
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF7A00), Color(0xFFFF9A3D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF7A00).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Hello, Saurabh',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      color: Colors.white,
                      size: 16,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Live',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Your health status is looking good today',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildStatusItem(FontAwesomeIcons.heartPulse, '${sensorData["heart_rate"].toStringAsFixed(1)} bpm', 'Heart Rate'),
              _buildStatusItem(FontAwesomeIcons.droplet, '${sensorData["spo2"].toStringAsFixed(1)}%', 'SpO2'),
              _buildStatusItem(
                  FontAwesomeIcons.personFalling,
                  _isFallDetected() ? 'Fall Alert' : 'No Fall',
                  'Detection'
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isFallDetected() {
    // Adjust thresholds based on your device's accelerometer values
    return sensorData["ax"].abs() > 800 ||
        sensorData["ay"].abs() > 800 ||
        sensorData["az"].abs() > 1500;
  }

  Widget _buildStatusItem(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: const Color(0xFFFF7A00),
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vital Statistics',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                FontAwesomeIcons.heartPulse,
                'Heart Rate',
                '${sensorData["heart_rate"].toStringAsFixed(1)} bpm',
                const Color(0xFFFFECE0),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                FontAwesomeIcons.droplet,
                'SpO2',
                '${sensorData["spo2"].toStringAsFixed(1)}%',
                const Color(0xFFFFECE0),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // New widget for step counter


  Widget _buildStatCard(IconData icon, String title, String value, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: const Color(0xFFFF7A00),
              size: 20,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallDetectionCard() {
    bool fallDetected = _isFallDetected();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Fall Detection Monitor',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: fallDetected ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  fallDetected ? 'Alert' : 'Normal',
                  style: TextStyle(
                    color: fallDetected ? Colors.red : Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildAccelerometerValue('X', sensorData["ax"]),
              _buildAccelerometerValue('Y', sensorData["ay"]),
              _buildAccelerometerValue('Z', sensorData["az"]),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: fallDetected ? Colors.red.withOpacity(0.1) : const Color(0xFFFFECE0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: fallDetected ? Colors.red.withOpacity(0.5) : const Color(0xFFFF7A00).withOpacity(0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  fallDetected ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                  color: fallDetected ? Colors.red : const Color(0xFFFF7A00),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    fallDetected
                        ? 'Potential fall detected! Emergency contacts will be notified if no response in 30 seconds.'
                        : 'No falls detected. Movement patterns are normal.',
                    style: TextStyle(
                      color: fallDetected ? Colors.red : const Color(0xFF333333),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccelerometerValue(String axis, dynamic value) {
    // Handle both int and double types by converting to double
    double doubleValue = value is int ? value.toDouble() : value;
    bool isHighValue = doubleValue.abs()>800;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isHighValue ? Colors.red.withOpacity(0.1) : const Color(0xFFF9F9F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isHighValue ? Colors.red.withOpacity(0.5) : Colors.grey.withOpacity(0.2),
          ),
        ),
        child: Column(
          children: [
            Text(
              'Axis $axis',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              doubleValue.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isHighValue ? Colors.red : const Color(0xFF333333),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeartRateChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Heart Rate History',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              Text(
                'Today',
                style: TextStyle(
                  color: Color(0xFFFF7A00),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: 10,
                  verticalInterval: 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: const Color(0xFFEAEAEA),
                      strokeWidth: 1,
                    );
                  },
                  getDrawingVerticalLine: (value) {
                    return FlLine(
                      color: const Color(0xFFEAEAEA),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final hours = ["10:00", "11:00", "12:00", "13:00", "14:00", "15:00", "16:00"];
                        if (value.toInt() < 0 || value.toInt() >= hours.length) {
                          return const Text('');
                        }
                        return Text(
                          hours[value.toInt()],
                          style: const TextStyle(
                            color: Color(0xFF666666),
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 10,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}',
                          style: const TextStyle(
                            color: Color(0xFF666666),
                            fontSize: 12,
                          ),
                        );
                      },
                      reservedSize: 40,
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: false,
                ),
                minX: 0,
                maxX: heartRateData.isEmpty ? 6 : (heartRateData.length - 1).toDouble(),
                minY: 60,
                maxY: 90,
                lineBarsData: [
                  LineChartBarData(
                    spots: heartRateData,
                    isCurved: true,
                    color: const Color(0xFFFF7A00),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(
                      show: false,
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFFFF7A00).withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnvironmentStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Environment Monitoring',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildEnvironmentCard(
                Icons.thermostat,
                'Temperature',
                '${sensorData["dht_temp"].toStringAsFixed(1)}°C',
                'DHT Sensor',
                const Color(0xFFF5F5F5),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildEnvironmentCard(
                Icons.water_drop,
                'Humidity',
                '${sensorData["humidity"].toStringAsFixed(1)}%',
                'Room Level',
                const Color(0xFFF5F5F5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildEnvironmentCard(
          Icons.device_thermostat,
          'Body Temperature',
          '${sensorData["ds18b20_temp"].toStringAsFixed(1)}°C',
          'DS18B20 Sensor',
          const Color(0xFFFFECE0),
        ),
      ],
    );
  }

  Widget _buildEnvironmentCard(
      IconData icon, String title, String value, String subtitle, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: const Color(0xFFFF7A00),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}