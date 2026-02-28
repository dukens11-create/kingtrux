import 'package:your_project/ui/map_screen.dart';

// Existing code for _AuthGate

// Modify the routing logic for authenticated users
if (isAuthenticated) {
  return MapScreen(); // Change from HomeScreen to MapScreen
}