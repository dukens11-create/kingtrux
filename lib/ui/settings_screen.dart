// Updated settings_screen.dart to remove outdated weigh station references.

// Other imports...

class SettingsScreen extends StatelessWidget {
  // Other members...

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        // Updated Weigh Station Alerts section
        Text('Weigh Station Alerts'),
        // Assuming enableAlerts is a toggle
        Switch(value: state.enableAlerts, onChanged: (value) { 
          // Code to handle alert enable/disable
        }),
        // Other configuration options
        Text('Alert Distance: ${state.alertDistanceMeters} meters'),
        // Other children use commas instead of Divider
      ],
    );
  }
}