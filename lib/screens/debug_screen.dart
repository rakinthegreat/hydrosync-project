import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import '../services/ai_service.dart';
import '../services/notification_service.dart';
import '../providers/water_provider.dart';
import '../widgets/scale_button.dart';
import 'package:provider/provider.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  List<PendingNotificationRequest> _pendingNotifications = [];

  @override
  void initState() {
    super.initState();
    _loadPendingNotifications();
  }

  Future<void> _loadPendingNotifications() async {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();
    final List<PendingNotificationRequest> pendingNotificationRequests =
        await flutterLocalNotificationsPlugin.pendingNotificationRequests();
    setState(() {
      _pendingNotifications = pendingNotificationRequests;
    });
  }

  void _showNotificationDialog({PendingNotificationRequest? request}) {
    final isEditing = request != null;
    final idController = TextEditingController(text: isEditing ? request.id.toString() : '');
    final titleController = TextEditingController(text: isEditing ? (request.title ?? '') : 'Debug Notification');
    final bodyController = TextEditingController(text: isEditing ? (request.body ?? '') : 'This is a test notification.');
    DateTime selectedTime = DateTime.now().add(const Duration(minutes: 1));
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF242E38),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(isEditing ? 'Edit Notification' : 'Add Notification', style: const TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(idController, 'ID (Integer)', isEnabled: !isEditing),
                const SizedBox(height: 12),
                _buildTextField(titleController, 'Title'),
                const SizedBox(height: 12),
                _buildTextField(bodyController, 'Body'),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Time:', style: TextStyle(color: Colors.white.withOpacity(0.7))),
                    TextButton(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedTime,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(selectedTime),
                          );
                          if (time != null) {
                            setDialogState(() {
                              selectedTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                            });
                          }
                        }
                      },
                      child: Text(DateFormat('MMM dd, HH:mm').format(selectedTime), style: const TextStyle(color: Color(0xFF4FC3F7))),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5))),
            ),
            ElevatedButton(
              onPressed: () async {
                final id = int.tryParse(idController.text);
                if (id == null) return;

                await NotificationService().scheduleNotification(
                  id,
                  titleController.text,
                  bodyController.text,
                  selectedTime,
                  {"amount": 250, "note": "Manual Debug"},
                );
                
                Navigator.pop(context);
                _loadPendingNotifications();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Notification ${isEditing ? 'updated' : 'added'}!')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4FC3F7)),
              child: Text(isEditing ? 'Update' : 'Schedule'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {bool isEnabled = true}) {
    return TextField(
      controller: controller,
      enabled: isEnabled,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF242E38) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A3A4A);
    final textSecondary = isDark ? Colors.white54 : const Color(0xFF6B8A9E);
    final highlightColor = const Color(0xFF4FC3F7);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1B232A) : const Color(0xFFF0F7FA),
      appBar: AppBar(
        title: const Text('DEBUG CONSOLE', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_alert),
            onPressed: () => _showNotificationDialog(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionHeader('ACTIONS', highlightColor),
          Consumer<WaterProvider>(
            builder: (context, waterProvider, _) => ScaleButton(
              onTap: () async {
                await waterProvider.notificationService.testNotification();
                _loadPendingNotifications();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text(
                      'Alarm scheduled! Locking your phone now is recommended for testing.'),
                  backgroundColor: highlightColor,
                  behavior: SnackBarBehavior.floating,
                ));
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange.withOpacity(0.3))),
                child: Row(
                  children: [
                    const Icon(Icons.bug_report, color: Colors.orange, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Trigger Immersive Alarm',
                              style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold)),
                          const Text('Tests full-screen intent in 10 seconds',
                              style: TextStyle(
                                  color: Colors.orange, fontSize: 10)),
                        ],
                      ),
                    ),
                    const Icon(Icons.timer_outlined,
                        color: Colors.orange, size: 16),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 25),
          _buildSectionHeader('RAW AI OUTPUT', highlightColor),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: highlightColor.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Last Response Body', style: TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: Icon(Icons.copy, size: 16, color: highlightColor),
                      onPressed: () {
                        if (AiService.lastRawResponse != null) {
                          Clipboard.setData(ClipboardData(text: AiService.lastRawResponse!));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
                        }
                      },
                    ),
                  ],
                ),
                const Divider(),
                Text(
                  AiService.lastRawResponse ?? "No AI response captured yet.",
                  style: TextStyle(color: textPrimary, fontSize: 10, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader('SCHEDULED NOTIFICATIONS (${_pendingNotifications.length})', highlightColor),
              IconButton(
                icon: Icon(Icons.refresh, size: 16, color: highlightColor),
                onPressed: _loadPendingNotifications,
              ),
            ],
          ),
          if (_pendingNotifications.isEmpty)
            Text('No pending notifications.', style: TextStyle(color: textSecondary))
          else
            ..._pendingNotifications.map((n) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text('ID: ${n.id}',
                              style: TextStyle(
                                  color: highlightColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                          if (n.payload != null) ...[
                            const SizedBox(width: 10),
                            Builder(builder: (context) {
                              try {
                                final data = jsonDecode(n.payload!);
                                if (data['scheduledAt'] != null) {
                                  final date =
                                      DateTime.parse(data['scheduledAt']);
                                  return Text(
                                    DateFormat('MMM dd, HH:mm').format(date),
                                    style: TextStyle(
                                        color: textSecondary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold),
                                  );
                                }
                              } catch (_) {}
                              return const SizedBox.shrink();
                            }),
                          ],
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit, size: 16, color: highlightColor),
                            onPressed: () => _showNotificationDialog(request: n),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                            onPressed: () async {
                              await NotificationService().cancelNotification(n.id);
                              _loadPendingNotifications();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  Text(n.title ?? 'No Title', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
                  Text(n.body ?? 'No Body', style: TextStyle(color: textSecondary, fontSize: 11)),
                  if (n.payload != null) ...[
                    const SizedBox(height: 4),
                    Text('Payload: ${n.payload}', style: TextStyle(color: textSecondary, fontSize: 9, fontFamily: 'monospace')),
                  ],
                ],
              ),
            )),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
    );
  }
}
