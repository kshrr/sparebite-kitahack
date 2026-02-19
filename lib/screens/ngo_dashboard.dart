import 'package:flutter/material.dart';

class NgoDashboard extends StatelessWidget {
  const NgoDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SpareBite"),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {},
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            /// PAGE TITLE
            const Text(
              "NGO Dashboard",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            /// ===============================
            /// PENDING RECOMMENDATIONS
            /// ===============================
            const Text(
              "Pending Recommendations",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            const RecommendationCard(),

            const SizedBox(height: 25),

            /// ===============================
            /// ACCEPTED PICKUPS
            /// ===============================
            const Text(
              "Accepted Pickups",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            const PickupCard(
              title: "Spice Route",
              quantity: "30 meals",
              distance: "2.3 km",
            ),

            const PickupCard(
              title: "Sunrise Bakery",
              quantity: "40 items",
              distance: "1.8 km",
            ),
          ],
        ),
      ),
    );
  }
}

/// =======================================
/// AI RECOMMENDATION CARD
/// =======================================
class RecommendationCard extends StatelessWidget {
  const RecommendationCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    "https://images.unsplash.com/photo-1546069901-ba9599a7e63c",
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                  ),
                ),

                const SizedBox(width: 15),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Green Garden Bistro",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text("25 meals • Prepared Meals"),
                      SizedBox(height: 4),
                      Text("AI Match Score: 94%"),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 15),

            const Text(
              "Closest NGO with high demand for prepared meals. "
              "Can serve 25+ people today.",
              style: TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 15),

            Row(
              children: [

                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
                    child: const Text("Accept"),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    child: const Text("Decline"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// =======================================
/// ACCEPTED PICKUP CARD
/// =======================================
class PickupCard extends StatelessWidget {
  final String title;
  final String quantity;
  final String distance;

  const PickupCard({
    super.key,
    required this.title,
    required this.quantity,
    required this.distance,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        leading: const Icon(Icons.restaurant),
        title: Text(title),
        subtitle: Text("$quantity • $distance"),
        trailing: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text("Accepted"),
        ),
      ),
    );
  }
}
