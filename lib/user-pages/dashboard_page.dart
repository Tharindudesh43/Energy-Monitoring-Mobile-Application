import 'dart:async';

import 'package:energy_application/auth-pages/signin.dart';
import 'package:energy_application/components/GaugePainter.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardPage extends StatefulWidget {
  final String deviceId;
  const DashboardPage({super.key, required this.deviceId});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with TickerProviderStateMixin {
  late DatabaseReference latestRef;
  late DatabaseReference historyRef;
  late AnimationController _pulseController;
  late AnimationController _tabController;

  List<DailyUsage> _dailyHistory = [];
  bool _historyLoading = true;

  double _dailyLimit = 10.0;
  double _weeklyLimit = 100.0;
  double _monthlyLimit = 500.0;
  double _peakRate = 0.0;
  double _normalRate = 0.0;
  TimeOfDay _peakStart = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _peakEnd = const TimeOfDay(hour: 22, minute: 0);

  int _chartTab = 0;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const Signin()),
        );
      });
      return;
    }

    latestRef = FirebaseDatabase.instance.ref(
      "users/${user.uid}/devices/${widget.deviceId}/latest",
    );
    historyRef = FirebaseDatabase.instance.ref(
      "users/${user.uid}/devices/${widget.deviceId}/history",
    );

    _loadFirestoreSettings(user.uid);
    _loadHistory();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _historySub.cancel();
    _settingsSub.cancel();
    super.dispose();
  }

  String formatTo12Hour(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';

    return "$hour:$minute $period";
  }

  late StreamSubscription<DocumentSnapshot> _settingsSub;

  void _loadFirestoreSettings(String uid) {
    _settingsSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((doc) {
          if (!mounted) return;

          if (!doc.exists) return;
          final d = doc.data()!;

          TimeOfDay parseTOD(dynamic value, TimeOfDay fallback) {
            if (value == null) return fallback;

            try {
              if (value is int) {
                return TimeOfDay(hour: value ~/ 60, minute: value % 60);
              }
            } catch (_) {}

            return fallback;
          }

          setState(() {
            _dailyLimit = (d['dailylimit'] ?? 10.0).toDouble();
            _weeklyLimit = (d['weeklylimit'] ?? 100.0).toDouble();
            _monthlyLimit = (d['monthlylimit'] ?? 500.0).toDouble();
            _peakRate = (d['PeakRate'] ?? 0.0).toDouble();
            _normalRate = (d['NormalRate'] ?? 0.0).toDouble();

            _peakStart = parseTOD(
              d['peakStart'],
              const TimeOfDay(hour: 20, minute: 0),
            );

            _peakEnd = parseTOD(
              d['peakEnd'],
              const TimeOfDay(hour: 22, minute: 0),
            );

            print(
              "Loaded settings: PeakStart=${_peakStart.format(context)}, PeakEnd=${_peakEnd.format(context)}",
            );
          });
        });
  }

  late StreamSubscription<DatabaseEvent> _historySub;

  void _loadHistory() {
    _historySub = historyRef
        .orderByChild("timestamp")
        .limitToLast(2016)
        .onValue
        .listen((event) {
          final raw = event.snapshot.value;
          if (!mounted) return;

          if (raw == null) {
            setState(() {
              _dailyHistory = [];
              _historyLoading = false;
            });
            return;
          }

          final records = Map<String, dynamic>.from(raw as Map);

          final Map<String, List<_EnergyRecord>> byDay = {};

          for (final entry in records.values) {
            final map = Map<String, dynamic>.from(entry as Map);
            final int ts = (map["timestamp"] ?? 0).toInt();
            final double energy = (map["energy"] ?? 0).toDouble();
            if (ts == 0) continue;

            final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
            final dayKey =
                "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}";

            byDay.putIfAbsent(dayKey, () => []);
            byDay[dayKey]!.add(_EnergyRecord(energy: energy, dt: dt));
          }

          final List<DailyUsage> result = [];

          byDay.forEach((day, recs) {
            recs.sort((a, b) => a.dt.compareTo(b.dt));

            double used = 0;
            for (int i = 1; i < recs.length; i++) {
              final delta = recs[i].energy - recs[i - 1].energy;
              if (delta > 0) used += delta;
            }

            double peakKwh = 0;
            double normalKwh = 0;

            for (int i = 1; i < recs.length; i++) {
              final delta = recs[i].energy - recs[i - 1].energy;
              if (delta <= 0) continue;

              final midpoint = recs[i - 1].dt.add(
                Duration(
                  milliseconds:
                      (recs[i].dt.millisecondsSinceEpoch -
                          recs[i - 1].dt.millisecondsSinceEpoch) ~/
                      2,
                ),
              );

              if (_isDuringPeak(midpoint)) {
                peakKwh += delta;
              } else {
                normalKwh += delta;
              }
            }

            final bill = peakKwh * _peakRate + normalKwh * _normalRate;

            result.add(
              DailyUsage(
                label: day,
                kwh: used.clamp(0, double.infinity),
                bill: bill,
                peakKwh: peakKwh,
                normalKwh: normalKwh,
                date: DateFormat.parse(day),
              ),
            );
          });

          result.sort((a, b) => a.date.compareTo(b.date));

          final last30 = result.length > 30
              ? result.sublist(result.length - 30)
              : result;

          if (!mounted) return;

          setState(() {
            _dailyHistory = last30;
            _historyLoading = false;
          });
        });
  }

  bool _isDuringPeak(DateTime dt) {
    final tod = TimeOfDay.fromDateTime(dt);
    final mins = tod.hour * 60 + tod.minute;
    final peakS = _peakStart.hour * 60 + _peakStart.minute;
    final peakE = _peakEnd.hour * 60 + _peakEnd.minute;
    return mins >= peakS && mins < peakE;
  }

  List<DailyUsage> get _last7Days {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return _dailyHistory.where((d) => d.date.isAfter(cutoff)).toList();
  }

  List<WeeklyUsage> get _weeklyData {
    final Map<String, WeeklyUsage> byWeek = {};
    for (final d in _dailyHistory) {
      final weekNum = _isoWeek(d.date);
      final key = "${d.date.year}-${weekNum.toString().padLeft(2, '0')}";
      byWeek.putIfAbsent(
        key,
        () => WeeklyUsage(label: "W$weekNum", kwh: 0, bill: 0),
      );
      byWeek[key] = WeeklyUsage(
        label: byWeek[key]!.label,
        kwh: byWeek[key]!.kwh + d.kwh,
        bill: byWeek[key]!.bill + d.bill,
      );
    }
    final weeks = byWeek.values.toList();
    return weeks.length > 8 ? weeks.sublist(weeks.length - 8) : weeks;
  }

  List<MonthlyUsage> get _monthlyData {
    final Map<String, MonthlyUsage> byMonth = {};
    const monthNames = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    for (final d in _dailyHistory) {
      final key = "${d.date.year}-${d.date.month.toString().padLeft(2, '0')}";
      byMonth.putIfAbsent(
        key,
        () => MonthlyUsage(label: monthNames[d.date.month], kwh: 0, bill: 0),
      );
      byMonth[key] = MonthlyUsage(
        label: byMonth[key]!.label,
        kwh: byMonth[key]!.kwh + d.kwh,
        bill: byMonth[key]!.bill + d.bill,
      );
    }
    final months = byMonth.values.toList();
    return months.length > 6 ? months.sublist(months.length - 6) : months;
  }

  int _isoWeek(DateTime dt) {
    final startOfYear = DateTime(dt.year, 1, 1);
    final dayOfYear = dt.difference(startOfYear).inDays + 1;
    return ((dayOfYear - dt.weekday + 10) / 7).floor();
  }

  double get _todayKwh {
    final today = _dailyHistory.where((d) {
      final now = DateTime.now();
      return d.date.day == now.day && d.date.month == now.month;
    });
    return today.isEmpty ? 0 : today.first.kwh;
  }

  double get _todayBill => _dailyHistory
      .where((d) {
        final n = DateTime.now();
        return d.date.day == n.day && d.date.month == n.month;
      })
      .fold(0.0, (s, d) => s + d.bill);

  double get _weekBill => _last7Days.fold(0.0, (s, d) => s + d.bill);
  double get _monthBill => _monthlyData.isEmpty ? 0 : _monthlyData.last.bill;
  double get _weekKwh => _last7Days.fold(0.0, (s, d) => s + d.kwh);
  double get _monthKwh => _monthlyData.isEmpty ? 0 : _monthlyData.last.kwh;

  String _formatTimestamp(int ts) {
    if (ts == 0) return "No data";
    final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}  ${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year.toString().substring(2)}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<DatabaseEvent>(
        stream: latestRef.onValue,
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(child: Text("Error: ${snapshot.error}"));
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          final data = snapshot.data!.snapshot.value;
          if (data == null) return const Center(child: Text("No data yet..."));

          final map = Map<String, dynamic>.from(data as Map);

          final double voltage = (map["voltage"] ?? 0).toDouble();
          final double current = (map["current"] ?? 0).toDouble();
          final double power = (map["power"] ?? 0).toDouble();
          final double energy = (map["energy"] ?? 0).toDouble();
          final double frequency = (map["frequency"] ?? 0).toDouble();
          final double pf = (map["powerFactor"] ?? 0).toDouble();
          final double temperature = (map["temperature"] ?? 0).toDouble();
          final double humidity = (map["humidity"] ?? 0).toDouble();
          final bool pzemOK = map["pzemOK"] == true;
          final bool dhtOK = map["dhtOK"] == true;
          final int timestamp = (map["timestamp"] ?? 0).toInt();

          return SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Column(
                  children: [
                    _buildRealTimeHeader(lastSeen: _formatTimestamp(timestamp)),
                    const SizedBox(height: 16),

                    if (!pzemOK || !dhtOK) ...[
                      _buildSensorWarningBanner(pzemOK: pzemOK, dhtOK: dhtOK),
                      const SizedBox(height: 12),
                    ],

                    _buildMainPowerCard(power: power, pzemOK: pzemOK),
                    const SizedBox(height: 12),

                    _buildStatsGrid(
                      voltage: voltage,
                      current: current,
                      power: power,
                      frequency: frequency,
                      pf: pf,
                      pzemOK: pzemOK,
                    ),
                    const SizedBox(height: 20),

                    _buildEnvRow(
                      temperature: temperature,
                      humidity: humidity,
                      dhtOK: dhtOK,
                    ),
                    const SizedBox(height: 32),

                    _buildUsageGauge(energy: energy),
                    const SizedBox(height: 32),

                    _buildBillSummaryRow(),
                    const SizedBox(height: 24),

                    _buildChartSection(),
                    const SizedBox(height: 32),

                    _buildBudgetCard(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBillSummaryRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "ESTIMATED BILL",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildBillCard(
                period: "Today",
                kwh: _todayKwh,
                bill: _todayBill,
                limit: _dailyLimit,
                color: _todayKwh > _dailyLimit
                    ? Colors.red
                    : const Color(0xFF13EC92),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildBillCard(
                period: "This Week",
                kwh: _weekKwh,
                bill: _weekBill,
                limit: _weeklyLimit,
                color: _weekKwh > _weeklyLimit
                    ? Colors.red
                    : const Color(0xFF13EC92),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildBillCard(
                period: "This Month",
                kwh: _monthKwh,
                bill: _monthBill,
                limit: _monthlyLimit,
                color: _monthKwh > _monthlyLimit
                    ? Colors.red
                    : const Color(0xFF13EC92),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBillCard({
    required String period,
    required double kwh,
    required double bill,
    required double limit,
    required Color color,
  }) {
    final double progress = (kwh / (limit > 0 ? limit : 1)).clamp(0.0, 1.0);
    final bool over = kwh > limit;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF193328),
        borderRadius: BorderRadius.circular(16),
        border: over ? Border.all(color: Colors.red.withOpacity(0.5)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            period,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          Text(
            "Rs ${bill.toStringAsFixed(2)}",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            "${kwh.toStringAsFixed(2)} kWh",
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(
                over ? Colors.red : color,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            over
                ? "Exceeded ${(kwh - limit).toStringAsFixed(1)} kWh"
                : "${(limit - kwh).toStringAsFixed(1)} kWh left",
            style: TextStyle(
              fontSize: 9,
              color: over ? Colors.red : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tab row
        Row(
          children: [
            const Expanded(
              child: Text(
                "USAGE HISTORY",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            _buildTabBtn("Daily", 0),
            const SizedBox(width: 6),
            _buildTabBtn("Weekly", 1),
            const SizedBox(width: 6),
            _buildTabBtn("Monthly", 2),
          ],
        ),
        const SizedBox(height: 16),

        if (_historyLoading)
          const Center(child: CircularProgressIndicator())
        else
          _buildActiveChart(),
      ],
    );
  }

  Widget _buildTabBtn(String label, int index) {
    final bool active = _chartTab == index;
    return GestureDetector(
      onTap: () => setState(() => _chartTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF13EC92) : const Color(0xFF193328),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: active ? Colors.black : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildActiveChart() {
    switch (_chartTab) {
      case 0:
        return _buildBarChart(
          bars: _last7Days
              .map(
                (d) => _BarData(
                  label: d.label,
                  kwh: d.kwh,
                  bill: d.bill,
                  limit: _dailyLimit,
                  isToday: () {
                    final now = DateTime.now();
                    return d.date.day == now.day && d.date.month == now.month;
                  }(),
                ),
              )
              .toList(),
          limitLabel: "Daily limit: ${_dailyLimit.toStringAsFixed(0)} kWh",
        );
      case 1:
        return _buildBarChart(
          bars: _weeklyData
              .map(
                (w) => _BarData(
                  label: w.label,
                  kwh: w.kwh,
                  bill: w.bill,
                  limit: _weeklyLimit,
                  isToday: false,
                ),
              )
              .toList(),
          limitLabel: "Weekly limit: ${_weeklyLimit.toStringAsFixed(0)} kWh",
        );
      case 2:
      default:
        return _buildBarChart(
          bars: _monthlyData
              .map(
                (m) => _BarData(
                  label: m.label,
                  kwh: m.kwh,
                  bill: m.bill,
                  limit: _monthlyLimit,
                  isToday: false,
                ),
              )
              .toList(),
          limitLabel: "Monthly limit: ${_monthlyLimit.toStringAsFixed(0)} kWh",
        );
    }
  }

  Widget _buildBarChart({
    required List<_BarData> bars,
    required String limitLabel,
  }) {
    if (bars.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF193328),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: Text(
            "No data yet for this period.",
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
      );
    }

    final double maxKwh = bars
        .map((b) => b.kwh)
        .reduce((a, b) => a > b ? a : b);
    final double safeMax = maxKwh < 0.001 ? 1.0 : maxKwh;
    final double total = bars.fold(0.0, (s, b) => s + b.kwh);
    final double totalBill = bars.fold(0.0, (s, b) => s + b.bill);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildHistorySummaryChip(
                label: "Total",
                value: "${total.toStringAsFixed(2)} kWh",
                icon: Icons.bolt,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildHistorySummaryChip(
                label: "Est. Bill",
                value: "Rs ${totalBill.toStringAsFixed(2)}",
                icon: Icons.receipt_long,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          decoration: BoxDecoration(
            color: const Color(0xFF193328),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              // Limit label
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  limitLabel,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 150,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: bars.map((bar) {
                    final ratio = (bar.kwh / safeMax).clamp(0.0, 1.0);
                    final over = bar.kwh > bar.limit;
                    final color = over
                        ? Colors.red
                        : bar.isToday
                        ? const Color(0xFF13EC92)
                        : const Color(0xFF13EC92).withOpacity(0.4);

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (bar.bill > 0)
                          Text(
                            "Rs${bar.bill.toStringAsFixed(0)}",
                            style: TextStyle(
                              fontSize: 8,
                              color: over ? Colors.red : Colors.grey,
                            ),
                          ),
                        const SizedBox(height: 2),
                        Text(
                          bar.kwh < 0.01 ? "0" : bar.kwh.toStringAsFixed(1),
                          style: TextStyle(fontSize: 9, color: color),
                        ),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOut,
                          width: 26,
                          height: (ratio * 100).clamp(4.0, 100.0),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          bar.isToday ? "Today" : bar.label,
                          style: TextStyle(
                            fontSize: 6,
                            fontWeight: bar.isToday
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: color,
                          ),
                        ),
                        if (over)
                          const Icon(
                            Icons.arrow_upward,
                            size: 10,
                            color: Colors.red,
                          ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRealTimeHeader({required String lastSeen}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("REAL-TIME"),
        Text(
          lastSeen,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        Row(
          children: [
            FadeTransition(
              opacity: _pulseController,
              child: const CircleAvatar(
                radius: 4,
                backgroundColor: Colors.green,
              ),
            ),
            const SizedBox(width: 6),
            const Text("LIVE"),
          ],
        ),
      ],
    );
  }

  Widget _buildSensorWarningBanner({
    required bool pzemOK,
    required bool dhtOK,
  }) {
    final warnings = [
      if (!pzemOK) "PZEM offline — power values are 0",
      if (!dhtOK) "DHT offline  — temp/humidity are 0",
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withOpacity(0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: warnings
                  .map(
                    (w) => Text(
                      w,
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainPowerCard({required double power, required bool pzemOK}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF193328),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Current Power"),
              if (!pzemOK) ...[
                const SizedBox(width: 8),
                const Icon(Icons.sensors_off, color: Colors.orange, size: 15),
              ],
            ],
          ),
          Text(
            pzemOK ? "${power.toStringAsFixed(2)} W" : "-- W",
            style: const TextStyle(fontSize: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid({
    required double voltage,
    required double current,
    required double power,
    required double frequency,
    required double pf,
    required bool pzemOK,
  }) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2,
      children: [
        _buildStatItem(
          'Voltage',
          pzemOK ? voltage : null,
          'V',
          Icons.electrical_services,
        ),
        _buildStatItem('Current', pzemOK ? current : null, 'A', Icons.input),
        _buildStatItem('Freq', pzemOK ? frequency : null, 'Hz', Icons.waves),
        _buildStatItem('PF', pzemOK ? pf : null, '', Icons.percent),
      ],
    );
  }

  Widget _buildStatItem(
    String label,
    double? value,
    String unit,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF193328),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 5),
          Text(
            value != null ? "${value.toStringAsFixed(2)} $unit" : "--",
            style: TextStyle(color: value != null ? null : Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildEnvRow({
    required double temperature,
    required double humidity,
    required bool dhtOK,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildEnvCard(
            label: "Temperature",
            value: dhtOK ? "${temperature.toStringAsFixed(1)} °C" : "--",
            icon: Icons.thermostat,
            iconColor: temperature > 35
                ? Colors.red
                : temperature < 10
                ? Colors.blue
                : const Color(0xFF13EC92),
            dhtOK: dhtOK,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildEnvCard(
            label: "Humidity",
            value: dhtOK ? "${humidity.toStringAsFixed(1)} %" : "--",
            icon: Icons.water_drop,
            iconColor: const Color(0xFF13EC92),
            dhtOK: dhtOK,
          ),
        ),
      ],
    );
  }

  Widget _buildEnvCard({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
    required bool dhtOK,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF193328),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: dhtOK ? iconColor : Colors.grey, size: 28),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: dhtOK ? null : Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUsageGauge({required double energy}) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 220,
            height: 220,
            child: CustomPaint(
              painter: GaugePainter(
                progress: (energy / 20).clamp(0, 1),
                color: const Color(0xFF13EC92),
                backgroundColor: const Color(0xFF234839),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "TODAY'S USAGE",
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
              ),
              Text(
                energy.toStringAsFixed(2),
                style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text("kWh"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySummaryChip({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF193328),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF13EC92), size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetCard() {
    return const SizedBox.shrink();
  }
}

class _EnergyRecord {
  final double energy;
  final DateTime dt;
  const _EnergyRecord({required this.energy, required this.dt});
}

class _BarData {
  final String label;
  final double kwh;
  final double bill;
  final double limit;
  final bool isToday;
  const _BarData({
    required this.label,
    required this.kwh,
    required this.bill,
    required this.limit,
    required this.isToday,
  });
}

class DailyUsage {
  final String label;
  final double kwh;
  final double bill;
  final double peakKwh;
  final double normalKwh;
  final DateTime date;
  const DailyUsage({
    required this.label,
    required this.kwh,
    required this.bill,
    required this.peakKwh,
    required this.normalKwh,
    required this.date,
  });
}

class WeeklyUsage {
  final String label;
  final double kwh;
  final double bill;
  const WeeklyUsage({
    required this.label,
    required this.kwh,
    required this.bill,
  });
}

class MonthlyUsage {
  final String label;
  final double kwh;
  final double bill;
  const MonthlyUsage({
    required this.label,
    required this.kwh,
    required this.bill,
  });
}

extension DateFormat on DateTime {
  static DateTime parse(String ddmm) {
    final parts = ddmm.split('/');
    return DateTime(
      DateTime.now().year,
      int.parse(parts[1]),
      int.parse(parts[0]),
    );
  }
}
