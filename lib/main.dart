import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();
  await Hive.openBox('reminderBox'); // Open a Hive box to store reminders

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Reminder App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: ReminderPage(),
    );
  }
}

class ReminderPage extends StatefulWidget {
  @override
  _ReminderPageState createState() => _ReminderPageState();
}

class _ReminderPageState extends State<ReminderPage> {
  String _selectedDay = 'Monday';
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _selectedActivity = 'Wake up';
  List<String> _reminders = [];

  final List<String> _daysOfWeek = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];
  final List<String> _activities = [
    'Wake up', 'Go to gym', 'Breakfast', 'Meetings', 'Lunch', 'Quick nap', 'Go to library', 'Dinner', 'Go to sleep'
  ];

  late AudioPlayer _audioPlayer;
  Timer? _reminderTimer;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _loadReminders(); // Load saved reminders on startup
    _startReminderLoop(); // Start the reminder loop
  }

  Future<void> _loadReminders() async {
    final box = Hive.box('reminderBox');
    setState(() {
      _reminders = box.get('reminders', defaultValue: <String>[])!.cast<String>();
    });
  }

  Future<void> _saveReminder() async {
    final box = Hive.box('reminderBox');
    String reminder = '$_selectedDay at ${_selectedTime.format(context)}: $_selectedActivity';
    _reminders.add(reminder);
    await box.put('reminders', _reminders);
    print('Saved reminder: $reminder'); // Debug print
    setState(() {}); // Update the UI after saving
  }

  Future<void> _deleteReminder(int index) async {
    final box = Hive.box('reminderBox');
    _reminders.removeAt(index);
    await box.put('reminders', _reminders);
    print('Deleted reminder at index $index'); // Debug print
    setState(() {}); // Update the UI after deleting
  }

  void _startReminderLoop() {
    _reminderTimer = Timer.periodic(Duration(minutes: 1), (timer) {
      _checkReminders();
    });
  }

  void _checkReminders() {
    final now = DateTime.now();
    final currentDay = _daysOfWeek[now.weekday - 1];
    final currentTime = TimeOfDay(hour: now.hour, minute: now.minute);

    // Check each stored reminder
    for (String reminder in _reminders) {
      final reminderParts = reminder.split(': ');
      final reminderTimeParts = reminderParts[0].split(' at ');

      final reminderDay = reminderTimeParts[0];
      final reminderTime = reminderTimeParts[1];
      final reminderActivity = reminderParts[1];

      // Check if the reminder matches the current day and time
      if (reminderDay == currentDay && reminderTime == currentTime.format(context)) {
        _triggerReminder(reminderActivity);
      }
    }
  }


  void _triggerReminder(String activity) {
    print("Alarm triggered!");
    _showSnackbar('It\'s time for $activity!'); // Show snackbar notification
    _playSound();
  }

  Future<void> _playSound() async {
    try {
      await _audioPlayer.play(AssetSource('ringtone.mp3'));
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

  Future<void> _setReminder() async {
    await _saveReminder(); // Save the reminder
    _showSnackbar('Reminder set successfully!'); // Show snackbar confirmation
    await Future.delayed(const Duration(seconds: 5)); // Simulated delay
    await _loadReminders(); // Refresh the list of reminders
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _reminderTimer?.cancel(); // Cancel the timer when the widget is disposed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reminder App'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue, Colors.purple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildDropdown('Select Day', _daysOfWeek, _selectedDay, (String? newValue) {
              setState(() {
                _selectedDay = newValue!;
              });
            }),
            SizedBox(height: 16.0),
            ListTile(
              title: Text("Select Time"),
              trailing: Text("${_selectedTime.format(context)}"),
              onTap: () async {
                TimeOfDay? newTime = await showTimePicker(
                  context: context,
                  initialTime: _selectedTime,
                );
                if (newTime != null) {
                  setState(() {
                    _selectedTime = newTime;
                  });
                }
              },
            ),
            SizedBox(height: 16.0),
            _buildDropdown('Select Activity', _activities, _selectedActivity, (String? newValue) {
              setState(() {
                _selectedActivity = newValue!;
              });
            }),
            SizedBox(height: 32.0),
            Center(
              child: ElevatedButton(
                onPressed: _setReminder,
                child: Text('Set Reminder'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
                ),
              ),
            ),
            SizedBox(height: 32.0),
            Text('Stored Reminders:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Expanded(
              child: _reminders.isNotEmpty
                  ? ListView.builder(
                itemCount: _reminders.length,
                itemBuilder: (context, index) {
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 8.0),
                    child: ListTile(
                      title: Text(_reminders[index]),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          _deleteReminder(index);
                        },
                      ),
                    ),
                  );
                },
              )
                  : Center(child: Text('No reminders set yet.')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(String hint, List<String> items, String selectedItem, ValueChanged<String?> onChanged) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: DropdownButton<String>(
        value: selectedItem,
        items: items.map((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item),
          );
        }).toList(),
        onChanged: onChanged,
        underline: SizedBox(),
        isExpanded: true,
      ),
    );
  }
}
