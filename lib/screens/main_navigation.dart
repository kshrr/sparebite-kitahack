import 'package:flutter/material.dart';
import 'dashboard.dart';
import 'my_listings_page.dart';
import 'upload_food_page.dart';

// temporary placeholders (you can replace later)
class ImpactPage extends StatelessWidget {
  const ImpactPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text("Impact Page"));
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text("Profile Page"));
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int currentIndex = 0;

  final pages = const [
    Dashboard(),
    MyListingsPage(),
    UploadFoodPage(),
    ImpactPage(),
    ProfilePage(),
  ];

  void onTabTapped(int index) {
    setState(() => currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[currentIndex],

      // ⭐ FLOATING ADD BUTTON (center)
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        onPressed: () => onTabTapped(2),
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // ⭐ BOTTOM NAV BAR
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SizedBox(
          height: 65,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [

              navItem(Icons.dashboard_outlined, "Home", 0),
              navItem(Icons.inventory_2_outlined, "Listings", 1),

              const SizedBox(width: 40), // space for FAB

              navItem(Icons.bar_chart_outlined, "Impact", 3),
              navItem(Icons.person_outline, "Profile", 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget navItem(IconData icon, String label, int index) {
    final isActive = currentIndex == index;

    return GestureDetector(
      onTap: () => onTabTapped(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isActive ? Colors.green : Colors.grey,
          ),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.green : Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
