import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;

class SensorScreen extends StatefulWidget {
  @override
  _SensorScreenState createState() => _SensorScreenState();
}

class _SensorScreenState extends State<SensorScreen> with SingleTickerProviderStateMixin {
  final dbRef = FirebaseDatabase.instance.ref();
  Map sensorData = {};
  List<FlSpot> accelXSpots = [];
  List<FlSpot> accelYSpots = [];
  List<FlSpot> accelZSpots = [];
  List<FlSpot> gyroXSpots = [];
  List<FlSpot> gyroYSpots = [];
  List<FlSpot> gyroZSpots = [];
  List<Widget> logsWidgets = [];
  int counter = 0;
  bool isLoading = true;
  late AnimationController _animationController;

  // Chart display settings
  int selectedChartIndex = 0;
  List<String> chartOptions = ['Accelerometer X', 'Accelerometer Y', 'Accelerometer Z',
    'Gyroscope X', 'Gyroscope Y', 'Gyroscope Z'];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat();
    listenToLiveData();
    fetchLogs();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void listenToLiveData() {
    dbRef.child('sensorData').onValue.listen((event) {
      if (!mounted) return;

      final data = event.snapshot.value as Map? ?? {};
      if (data.isEmpty) return;

      double accelX = double.tryParse(data['ax']?.toString() ?? '0') ?? 0;
      double accelY = double.tryParse(data['ay']?.toString() ?? '0') ?? 0;
      double accelZ = double.tryParse(data['az']?.toString() ?? '0') ?? 0;

      setState(() {
        sensorData = data;

        // Add points to line chart
        accelXSpots.add(FlSpot(counter.toDouble(), accelX));
        accelYSpots.add(FlSpot(counter.toDouble(), accelY));
        accelZSpots.add(FlSpot(counter.toDouble(), accelZ));

        // Keep last 50 points only
        if (accelXSpots.length > 50) {
          accelXSpots.removeAt(0);
          accelYSpots.removeAt(0);
          accelZSpots.removeAt(0);
        }

        counter++;
        isLoading = false;
      });
    }, onError: (error) {
      print('Error listening to sensor data: $error');
    });
  }


  void fetchLogs() {
    dbRef.child('logs').limitToLast(20).onValue.listen((event) {
      if (!mounted) return;

      final logsMap = event.snapshot.value as Map? ?? {};
      if (logsMap.isNotEmpty) {
        final sortedKeys = logsMap.keys.toList()..sort();
        final logList = sortedKeys.map((key) {
          final data = logsMap[key];
          final timestamp = DateTime.tryParse(key) ?? DateTime.now();
          final formattedTime = "${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}";

          return Card(
            elevation: 2,
            margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: ExpansionTile(
              title: Text(
                "Log: $formattedTime",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Accelerometer", style: TextStyle(fontWeight: FontWeight.bold)),
                      Padding(
                        padding: const EdgeInsets.only(left: 12.0, top: 4),
                        child: Text(
                            "X: ${data['accel']?['x'] ?? 'N/A'}\nY: ${data['accel']?['y'] ?? 'N/A'}\nZ: ${data['accel']?['z'] ?? 'N/A'}"
                        ),
                      ),
                      SizedBox(height: 8),
                      Text("Gyroscope", style: TextStyle(fontWeight: FontWeight.bold)),
                      Padding(
                        padding: const EdgeInsets.only(left: 12.0, top: 4),
                        child: Text(
                            "X: ${data['gyro']?['x'] ?? 'N/A'}\nY: ${data['gyro']?['y'] ?? 'N/A'}\nZ: ${data['gyro']?['z'] ?? 'N/A'}"
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList();

        setState(() {
          logsWidgets = logList;
        });
      }
    }, onError: (error) {
      print('Error fetching logs: $error');
    });
  }

  List<FlSpot> getSelectedChartData() {
    switch (selectedChartIndex) {
      case 0: return accelXSpots;
      case 1: return accelYSpots;
      case 2: return accelZSpots;
      case 3: return gyroXSpots;
      case 4: return gyroYSpots;
      case 5: return gyroZSpots;
      default: return accelXSpots;
    }
  }

  Color getChartColor() {
    List<Color> colors = [
      Colors.blue,
      Colors.green,
      Colors.red,
      Colors.purple,
      Colors.orange,
      Colors.teal,
    ];
    return colors[selectedChartIndex % colors.length];
  }

  double getChartMinY() {
    return selectedChartIndex < 3 ? -20000 : -2000;
  }

  double getChartMaxY() {
    return selectedChartIndex < 3 ? 20000 : 2000;
  }

  Widget buildChart() {
    final spots = getSelectedChartData();

    if (spots.isEmpty) {
      return Center(child: Text('Waiting for data...'));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: DropdownButton<int>(
            isExpanded: true,
            value: selectedChartIndex,
            onChanged: (newIndex) {
              setState(() {
                selectedChartIndex = newIndex!;
              });
            },
            items: List.generate(chartOptions.length, (index) {
              return DropdownMenuItem(
                value: index,
                child: Text(chartOptions[index]),
              );
            }),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8.0, 0, 16.0, 16.0),
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  drawHorizontalLine: true,
                  horizontalInterval: selectedChartIndex < 3 ? 5000 : 500,
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        if (value % 10 == 0) {
                          return Text('${value.toInt()}');
                        }
                        return Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 60,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return Text('0');

                        String text = '';
                        int interval = selectedChartIndex < 3 ? 10000 : 1000;

                        if (value % interval == 0) {
                          text = '${value.toInt()}';
                        }
                        return Text(text, style: TextStyle(fontSize: 10));
                      },
                    ),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: true),
                minX: spots.isNotEmpty ? spots.first.x : 0,
                maxX: spots.isNotEmpty ? spots.last.x : 10,
                minY: getChartMinY(),
                maxY: getChartMaxY(),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: getChartColor(),
                    barWidth: 3,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: getChartColor().withOpacity(0.2),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildAccelCard() {
    if (sensorData.isEmpty || sensorData['accel'] == null) {
      return SizedBox.shrink();
    }

    double accelX = double.tryParse(sensorData['accel']['x'].toString()) ?? 0;
    double accelY = double.tryParse(sensorData['accel']['y'].toString()) ?? 0;
    double accelZ = double.tryParse(sensorData['accel']['z'].toString()) ?? 0;

    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.speed, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                    "Accelerometer",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                ),
              ],
            ),
            Divider(),
            SizedBox(height: 8),
            buildSensorBar("X", accelX, Colors.red, -16000, 16000),
            SizedBox(height: 12),
            buildSensorBar("Y", accelY, Colors.green, -16000, 16000),
            SizedBox(height: 12),
            buildSensorBar("Z", accelZ, Colors.blue, -16000, 16000),
          ],
        ),
      ),
    );
  }

  Widget buildGyroCard() {
    if (sensorData.isEmpty || sensorData['gyro'] == null) {
      return SizedBox.shrink();
    }

    double gyroX = double.tryParse(sensorData['gyro']['x'].toString()) ?? 0;
    double gyroY = double.tryParse(sensorData['gyro']['y'].toString()) ?? 0;
    double gyroZ = double.tryParse(sensorData['gyro']['z'].toString()) ?? 0;

    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.rotate_right, color: Colors.purple),
                SizedBox(width: 8),
                Text(
                    "Gyroscope",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                ),
              ],
            ),
            Divider(),
            SizedBox(height: 8),
            buildSensorBar("X", gyroX, Colors.orange, -1500, 1500),
            SizedBox(height: 12),
            buildSensorBar("Y", gyroY, Colors.teal, -1500, 1500),
            SizedBox(height: 12),
            buildSensorBar("Z", gyroZ, Colors.purple, -1500, 1500),
          ],
        ),
      ),
    );
  }

  Widget buildSensorBar(String axis, double value, Color color, double min, double max) {
    // Normalize value between 0 and 1
    double normalized = (value - min) / (max - min);
    normalized = normalized.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 20,
              child: Text(axis, style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: normalized,
                  backgroundColor: Colors.grey[200],
                  color: color,
                  minHeight: 15,
                ),
              ),
            ),
            SizedBox(width: 12),
            Text(
              value.toStringAsFixed(0),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget build3DOrientation() {
    if (sensorData.isEmpty) {
      return SizedBox.shrink();
    }

    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.view_in_ar, color: Colors.indigo),
                SizedBox(width: 8),
                Text(
                    "3D Orientation",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                ),
              ],
            ),
            Divider(),
            SizedBox(height: 8),
            Center(
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  // Calculate rotation angles based on sensor data
                  // Simple visualization - not accurate physics model
                  double accelX = double.tryParse(sensorData['accel']?['x']?.toString() ?? '0') ?? 0;
                  double accelY = double.tryParse(sensorData['accel']?['y']?.toString() ?? '0') ?? 0;

                  // Normalize values
                  double rotX = accelY / 16000 * math.pi / 4; // max 45 degrees
                  double rotY = accelX / 16000 * math.pi / 4; // max 45 degrees

                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateX(rotX)
                      ..rotateY(rotY),
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 5.0,
                            offset: Offset(2, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.smartphone,
                          size: 50,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget buildLiveData() {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Connecting to sensor...')
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          isLoading = true;
        });
        await Future.delayed(Duration(milliseconds: 500));
        setState(() {
          isLoading = false;
        });
      },
      child: ListView(
        padding: EdgeInsets.symmetric(vertical: 16),
        children: [
          buildAccelCard(),
          buildGyroCard(),
          build3DOrientation(),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text("MPU6050 Monitor"),
          elevation: 4,
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.dashboard), text: "Dashboard"),
              Tab(icon: Icon(Icons.show_chart), text: "Charts"),
              Tab(icon: Icon(Icons.history), text: "History"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            buildLiveData(),
            buildChart(),
            logsWidgets.isEmpty
                ? Center(child: Text('No history data available'))
                : ListView(children: logsWidgets),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            // Refresh data
            setState(() {
              isLoading = true;
            });
            await Future.delayed(Duration(milliseconds: 500));
            setState(() {
              isLoading = false;
            });
          },
          child: Icon(Icons.refresh),
          tooltip: 'Refresh Data',
        ),
      ),
    );
  }
}